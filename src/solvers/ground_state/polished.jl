# --- Polished ground state: ITP warm-up + LBFGS polish ---
#
# Two-stage ground-state driver: ITP via `find_ground_state` (Strang
# imaginary-time evolution) followed by an LBFGS polish via
# `find_ground_state_lbfgs(ws_init=...)`. Reusing the warmed Workspace
# (not just `psi`) is load-bearing — the rotating-frame Hamiltonian
# (Coriolis + Barnett + centrifugal) is encoded in the Workspace and
# must carry through to LBFGS, otherwise the polish runs against a
# different H than the seed converged under.
#
# Promoted from `scripts/lib/polished_sweep.jl::polished_ground_state`.

export find_ground_state_polished

"""
    find_ground_state_polished(preset, omega, zeeman; ...) → NamedTuple

Two-stage ground-state finder taking a `Preset` (atom + grid + interactions + c_dd):

  1. ITP warm-up at `rotating_frame_omega = omega`, `n_steps = n_itp`.
  2. LBFGS polish on the warmed Workspace (rotating-frame H carries
     over). `n_lbfgs == 0` skips this stage.

Returned NamedTuple:
  * `workspace`  — final `Workspace` (post-polish if LBFGS ran)
  * `energy`     — final total energy
  * `E_itp`      — energy at end of stage 1
  * `converged`  — convergence flag (LBFGS if it ran, else ITP)
  * `grad_norm`  — ‖∇E‖ from LBFGS, or `NaN` if LBFGS skipped
  * `t_itp`, `t_lbfgs` — wall-clock seconds per stage

Kwargs:
  * `psi_init`        — initial wavefunction. `nothing` ⇒ build from
                        `initial_state` and add `add_white_noise!` for
                        symmetry breaking.
  * `initial_state`   — seed kind for `init_psi` (`:polar`, `:fl_vortex`, …)
  * `noise_amp`, `noise_seed` — applied only when `psi_init === nothing`
  * `enable_ddi`, `secular_ddi` — DDI controls; `c_dd` is taken from `preset`
  * `n_itp`, `dt_itp`, `tol_itp` — ITP knobs
  * `n_lbfgs`, `tol_lbfgs`, `sobolev_alpha` — LBFGS polish knobs
  * `backend` — `CPUBackend()` or `CUDABackend()`
"""
function find_ground_state_polished(
    preset::Preset,
    omega::Float64,
    zeeman;
    psi_init::Union{Nothing, AbstractArray}=nothing,
    initial_state::Symbol=:polar,
    noise_amp::Float64=0.01,
    noise_seed::Int=1,
    enable_ddi::Bool=true,
    secular_ddi::Bool=false,
    n_itp::Int=2000,
    dt_itp::Float64=0.005,
    tol_itp::Float64=1e-7,
    n_lbfgs::Int=1000,
    tol_lbfgs::Float64=1e-5,
    sobolev_alpha::Float64=0.02,
    backend::AbstractBackend=CPUBackend(),
)
    if psi_init === nothing
        sys = SpinSystem(preset.F)
        psi_init = init_psi(preset.grid, sys; state=initial_state)
        add_white_noise!(psi_init, noise_amp, noise_seed, preset.grid)
    end

    t0 = time()
    r_itp = find_ground_state(;
        grid=preset.grid, atom=preset.atom,
        interactions=preset.interactions,
        zeeman=zeeman, potential=preset.potential,
        dt=dt_itp, n_steps=n_itp, tol=tol_itp,
        initial_state=initial_state, verbose=false,
        psi_init=psi_init,
        enable_ddi=enable_ddi, c_dd=preset.c_dd, secular_ddi=secular_ddi,
        rotating_frame_omega=omega, backend=backend,
    )
    t_itp = time() - t0
    ws_itp = r_itp.workspace
    E_itp = r_itp.energy

    if n_lbfgs > 0
        t0 = time()
        r_lbfgs = find_ground_state_lbfgs(;
            ws_init=ws_itp,
            n_steps=n_lbfgs, tol=tol_lbfgs,
            verbose=false, sobolev_alpha=sobolev_alpha,
        )
        t_lbfgs = time() - t0
        ws = r_lbfgs.workspace
        E = r_lbfgs.energy
        converged = r_lbfgs.converged
        grad_norm = r_lbfgs.grad_norm
    else
        ws = ws_itp
        E = E_itp
        converged = r_itp.converged
        grad_norm = NaN
        t_lbfgs = 0.0
    end

    return (
        workspace=ws,
        energy=E, E_itp=E_itp,
        converged=converged, grad_norm=grad_norm,
        t_itp=t_itp, t_lbfgs=t_lbfgs,
    )
end
