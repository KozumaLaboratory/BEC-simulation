using SpinorBEC
using Printf

# Phase 5 SMOKE: energy drift comparison of Y4-plain vs Y4-mid vs Y4-trap
# over a long real-time evolution.
#
# Setup: 1D Rb87 (F=1) cubic NLS, c0=50 + c1=1.0, no DDI. Light enough
# to run T_final ~ 100 ω⁻¹ in a few minutes on CPU; carries enough MF
# coupling to exercise the implicit-midpoint vs trap distinction.
#
# Why this exists: anko proposed AVF-style (trapezoidal MF) integrator
# as an alternative to my Y4-midpoint. Quispel-McLaren AVF preserves
# energy exactly for arbitrary Hamiltonians; the trapezoidal approximation
# preserves a modified Hamiltonian (bounded drift, secular ≠ 0 for
# quartic H). For our quartic GPE Hamiltonian, neither midpoint nor
# trapezoidal is exact-energy-preserving — only true 2pt-GL AVF would
# be. This smoke compares the *drift constants* between the two
# bounded-drift options.
#
# Eu DDI long-time (T_final ~ 1000 ω⁻¹, vortex dynamics, 32³) is the
# full Phase 5 target — defer to a separate session at production scale.
#
# Run:
#   julia --project=. scripts/bench/avf_drift_phase5_smoke.jl

const N1D = 64
const T_FINAL = 10.0
const DT = 0.001
const N_STEPS = Int(round(T_FINAL / DT))
const SAMPLE_EVERY = 100
const ATOM = Rb87
# Moderate nonlinearity so the integrator error stays well below the energy.
# Y4-trap is order 2 → accumulated error ~ dt² · n_steps = 1e-6 · 1e4 = 1e-2
# is the maximum tolerable; Y4-mid order 4 stays at ~1e-8. Going coarser
# than dt=0.001 makes Y4-trap explode; going stiffer than c0=5 amplifies
# the error constant. (Initial smoke at dt=0.01, c0=50 had all schemes
# diverge with ΔE/E₀ > 100 by t=20.)
const C0 = 5.0
const C1 = 0.5

# --- Y4 step (inline; same coefficients as scripts/bench/midpoint_order_phase2a.jl) ---

const _Y4_W1 = 1.0 / (2.0 - 2.0^(1.0 / 3.0))
const _Y4_W0 = 1.0 - 2.0 * _Y4_W1
const _Y4_WM = (_Y4_W1 + _Y4_W0) / 2.0

function _y4_step!(ws::SpinorBEC.Workspace{N}, V_half!::Function) where {N}
    dt = ws.sim_params.dt
    n_comp = ws.spin_matrices.system.n_components
    omega = ws.sim_params.rotating_frame_omega
    t_base = ws.state.t

    w1 = _Y4_W1;
    w0 = _Y4_W0;
    wm = _Y4_WM

    V_half!(ws, w1 * dt / 2, n_comp, N, false;
        t_eval=t_base + w1 * dt / 4, t_start=t_base)
    SpinorBEC._apply_coriolis_step!(
        ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache
    )
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(
        ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache
    )

    t_v2 = t_base + w1 * dt / 2
    V_half!(ws, wm * dt, n_comp, N, false;
        t_eval=t_v2 + wm * dt / 2, t_start=t_v2)
    SpinorBEC._apply_coriolis_step!(
        ws.state.psi, ws.grid, omega, w0 * dt / 2, false, ws.coriolis_cache
    )
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w0 * dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(
        ws.state.psi, ws.grid, omega, w0 * dt / 2, false, ws.coriolis_cache
    )

    t_v3 = t_base + w1 * dt / 2 + wm * dt
    V_half!(ws, wm * dt, n_comp, N, false;
        t_eval=t_v3 + wm * dt / 2, t_start=t_v3)
    SpinorBEC._apply_coriolis_step!(
        ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache
    )
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(
        ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache
    )

    V_half!(ws, w1 * dt / 2, n_comp, N, false;
        t_eval=t_base + dt - w1 * dt / 4, t_start=t_base + dt - w1 * dt / 2)

    ws.state.t += dt
    ws.state.step += 1
    nothing
end

# --- Setup ---

function _build_ws(dt::Float64)
    grid = make_grid(GridConfig(N1D, 8.0))
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=ATOM,
        interactions=InteractionParams(Dict(0 => C0, 1 => C1)),
        zeeman=ZeemanParams(0.5, 0.1),
        potential=HarmonicTrap(1.0),
        sim_params=sp,
        enable_ddi=false,
        backend=CPUBackend(),
    )
    _seed_psi!(ws, grid)
    ws
end

function _seed_psi!(ws, grid)
    psi = ws.state.psi
    D = size(psi, 2)
    @inbounds for i in 1:N1D
        x = grid.x[1][i]
        g = exp(-x * x / 2)
        for c in 1:D
            psi[i, c] = g * cis(0.1 * c)
        end
    end
    SpinorBEC._normalize_psi!(psi, ws.grid, D, 1)
    nothing
end

# --- Drift trace ---

function run_drift(label::String, V_half!::Function)
    println("Running $label ...")
    ws = _build_ws(DT)
    E0 = SpinorBEC.total_energy(ws)
    times = [0.0]
    drifts = [0.0]
    t_start = time()
    for step in 1:N_STEPS
        _y4_step!(ws, V_half!)
        if step % SAMPLE_EVERY == 0
            E = SpinorBEC.total_energy(ws)
            push!(times, ws.state.t)
            push!(drifts, (E - E0) / abs(E0))
        end
    end
    wall = time() - t_start
    @printf("  %-12s done in %.1f s  E0=%.6f  E_final=%.6f  relΔE=%.3e\n",
        label, wall, E0, E0 * (1 + drifts[end]), drifts[end])
    return (label, times, drifts, wall)
end

# --- Run ---

@printf("=== Phase 5 smoke: energy drift (Y4-plain vs Y4-mid vs Y4-trap) ===\n")
@printf("1D Rb87 F=1, c0=%.0f c1=%.1f, T_final=%.0f ω⁻¹, dt=%.3f, N_steps=%d\n\n",
    C0, C1, T_FINAL, DT, N_STEPS)

# Trap needs n_picard ≥ 4 to recover order 4 (diagnosed via
# scripts/bench/trap_picard_diag.jl: trap Picard residual at p=2 is ~50000x
# larger than midpoint's because trap iterates the full-duration V step
# instead of the half-duration midpoint predictor). With n_picard=4 the
# trap residual drops below the Y4 order-4 error.
const _trap_p4 = function (w, dt, n, nd, it; kwargs...)
    SpinorBEC._half_potential_step_trap!(w, dt, n, nd, it; kwargs..., n_picard=4)
end

results = [
    run_drift("Y4-plain", SpinorBEC._half_potential_step!),
    run_drift("Y4-mid", SpinorBEC._half_potential_step_midpoint!),
    run_drift("Y4-trap", _trap_p4),
]

# --- Summary table ---

@printf("\nRelative energy drift ΔE/|E₀| (signed) sampled at t = 2, 5, 10 ω⁻¹:\n\n")
@printf("%-12s  %-13s  %-13s  %-13s  %-9s\n",
    "scheme", "drift@t=2", "drift@t=5", "drift@t=10", "wall(s)")
function _at(times, drifts, t)
    idx = findfirst(τ -> τ >= t, times)
    idx === nothing ? drifts[end] : drifts[idx]
end
for (label, times, drifts, wall) in results
    d2 = _at(times, drifts, 2.0)
    d5 = _at(times, drifts, 5.0)
    d10 = _at(times, drifts, 10.0)
    @printf("%-12s  %+.4e   %+.4e   %+.4e   %.1f\n",
        label, d2, d5, d10, wall)
end

# --- Interpretation hint ---

ratio_mid_plain = abs(results[2][3][end]) / abs(results[1][3][end])
ratio_trap_mid = abs(results[3][3][end]) / abs(results[2][3][end])
@printf("\nDrift reduction ratios at t=%.0f:\n", T_FINAL)
@printf("  |Y4-mid / Y4-plain|  = %.3f\n", ratio_mid_plain)
@printf("  |Y4-trap / Y4-mid|   = %.3f  (< 1 → trap improves over mid)\n", ratio_trap_mid)
