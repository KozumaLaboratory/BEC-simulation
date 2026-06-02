# scripts/lib/polished_sweep.jl
#
# Reusable polished-ground-state pipeline for sweep scripts:
# ITP warm-up (Strang) → optional LBFGS polish (on the warmed workspace, so
# rotating-frame physics carries through) → observable extraction.
#
# Companion to scripts/lib/eu_digital_twin.jl. Typical use:
#
#     include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))
#     include(joinpath(@__DIR__, "lib", "polished_sweep.jl"))
#     const TW = eu_digital_twin()
#     r = polished_ground_state(
#         TW, omega, zeeman;
#         psi_init=psi, enable_ddi=true,
#         n_itp=2000, n_lbfgs=1000, sobolev_alpha=0.02,
#         backend=CUDABackend(),
#     )
#     # r.E, r.grad_norm, r.fz_total, r.Lz, r.m_dist, ...
#
# Returns a NamedTuple with: workspace, energy E (post-polish), E_itp,
# converged (LBFGS), grad_norm, observables (⟨F_x⟩, ⟨F_y⟩, ⟨F_z⟩,
# f_max, m_dist, ⟨L_z⟩), and wall-clock timings (time_itp, time_lbfgs).

using SpinorBEC
using LinearAlgebra

"""
    polished_ground_state(twin, omega, zeeman; ...) → NamedTuple

Run an ITP warm-up at `rotating_frame_omega=omega` then (optionally)
LBFGS polish on the same workspace. Returns a NamedTuple of converged
energy + standard observables.

Required positional args:
  * `twin` — output of `eu_digital_twin(...)` (provides grid, atom, …).
  * `omega` — rotating-frame Ω (rad/ω_ref).
  * `zeeman` — Zeeman block (`ZeemanParams` or `TimeDependentZeeman`).

Kwargs:
  * `psi_init` — initial wavefunction (default: noisy polar).
  * `noise_amp`, `noise_seed` — symmetry-breaking noise on default seed.
  * `enable_ddi`, `secular_ddi` — DDI controls.
  * `n_itp`, `dt_itp`, `tol_itp` — ITP warm-up knobs.
  * `n_lbfgs` — LBFGS polish step cap. `0` skips LBFGS.
  * `tol_lbfgs`, `sobolev_alpha` — LBFGS polish knobs.
  * `backend` — CPU or CUDA.
"""
function polished_ground_state(
    twin,
    omega::Float64,
    zeeman;
    psi_init=nothing,
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
    backend=CPUBackend(),
)
    if psi_init === nothing
        sys = SpinSystem(twin.F)
        psi_init = init_psi(twin.grid, sys; state=initial_state)
        add_noise!(psi_init, noise_amp, noise_seed, twin.grid)
    end

    # Stage 1: ITP warm-up
    t0 = time()
    r_itp = find_ground_state(;
        grid=twin.grid, atom=twin.atom, interactions=twin.interactions,
        zeeman=zeeman, potential=twin.potential,
        dt=dt_itp, n_steps=n_itp, tol=tol_itp,
        initial_state=initial_state, verbose=false,
        psi_init=psi_init,
        enable_ddi=enable_ddi, c_dd=twin.c_dd, secular_ddi=secular_ddi,
        rotating_frame_omega=omega, backend=backend,
    )
    t_itp = time() - t0
    ws_itp = r_itp.workspace
    E_itp = r_itp.energy

    # Stage 2: LBFGS polish on the warmed workspace (reuses ws_init so the
    # rotating-frame H — Coriolis, Barnett, centrifugal — carries over).
    if n_lbfgs > 0
        t0 = time()
        r_lbfgs = SpinorBEC.find_ground_state_lbfgs(;
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

    obs = _gather_observables(ws, twin)

    return (
        workspace=ws,
        E=E, E_itp=E_itp,
        converged=converged, grad_norm=grad_norm,
        fx_total=obs.fx_total, fy_total=obs.fy_total, fz_total=obs.fz_total,
        f_max=obs.f_max,
        Lz=obs.Lz, m_dist=obs.m_dist,
        time_itp=t_itp, time_lbfgs=t_lbfgs,
    )
end

function _gather_observables(ws, twin)
    psi = Array(ws.state.psi)
    sm = ws.spin_matrices
    ndim = length(twin.n_pts)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    f_max = maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
    dV = SpinorBEC.cell_volume(twin.grid)
    fz_total = sum(fz) * dV
    fx_total = sum(fx) * dV
    fy_total = sum(fy) * dV
    m_dist = zeros(twin.D)
    for c in 1:(twin.D)
        slice = ntuple(d -> d == ndim + 1 ? c : Colon(), ndim + 1)
        m_dist[c] = sum(abs2, view(psi, slice...)) * dV
    end
    Lz = orbital_angular_momentum(psi, ws.grid, ws.fft_plans)
    (fx_total=fx_total, fy_total=fy_total, fz_total=fz_total,
        f_max=f_max, Lz=Lz, m_dist=m_dist)
end
