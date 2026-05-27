using SpinorBEC
using Printf

# Phase 5 long-time energy drift bench: Y4-midpoint vs Force-Gradient vs Strang.
#
# Setup: 1D Rb87 (F=1, D=3) harmonic + cubic c0 NLS, c1 = 0 (diagonal-only
# to satisfy Force-Gradient v3 scope). T_final long enough for drift to
# accumulate.
#
# Each scheme advances ψ in real time; energy E(t) = ⟨ψ|H|ψ⟩ is sampled
# at regular intervals. Drift ΔE(t)/|E₀| is reported.
#
# Run:
#   julia --project=. scripts/bench/forcegrad_phase5.jl

const N1D = 64
const T_FINAL = 20.0
const DT = 0.005
const N_STEPS = Int(round(T_FINAL / DT))
const SAMPLE_EVERY = 100
const ATOM = Rb87
const C0 = 5.0
const C1 = 0.0  # diagonal-only for Force-Gradient compatibility

function _build_ws(dt::Float64)
    grid = make_grid(GridConfig(N1D, 8.0))
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=ATOM,
        interactions=InteractionParams(C0, C1),
        zeeman=ZeemanParams(0.0, 0.0),  # no Zeeman for cleanest test
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

# Y4 step (inline; same coefficients as midpoint_order_phase2a.jl)
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

# --- Drift trace ---

function run_drift(label::String, evolver::Function)
    println("Running $label ...")
    ws = _build_ws(DT)
    E0 = SpinorBEC.total_energy(ws)
    drifts = Float64[0.0]
    times = Float64[0.0]
    t_start = time()
    for step in 1:N_STEPS
        evolver(ws)
        if step % SAMPLE_EVERY == 0
            E = SpinorBEC.total_energy(ws)
            push!(times, ws.state.t)
            push!(drifts, (E - E0) / abs(E0))
        end
    end
    wall = time() - t_start
    @printf("  %-22s done %.1fs  E0=%.6f  E_final=%.6f  relΔE=%+.3e\n",
        label, wall, E0, E0 * (1 + drifts[end]), drifts[end])
    return (label, times, drifts, wall)
end

# --- Schemes ---

evolve_strang!(ws) = SpinorBEC.split_step!(ws)
evolve_y4_mid!(ws) = _y4_step!(ws, SpinorBEC._half_potential_step_midpoint!)
evolve_fg_p1!(ws) = SpinorBEC.split_step_forcegrad!(ws; n_picard=1)
evolve_fg_p2!(ws) = SpinorBEC.split_step_forcegrad!(ws; n_picard=2)

# --- Run ---

@printf("=== Phase 5 long-time energy drift bench ===\n")
@printf("1D Rb87 F=1, c0=%.1f c1=%.1f, T_final=%.0f ω⁻¹, dt=%.3f, N_steps=%d\n\n",
    C0, C1, T_FINAL, DT, N_STEPS)

results = [
    run_drift("Strang", evolve_strang!),
    run_drift("Y4-mid", evolve_y4_mid!),
    run_drift("ForceGrad p=1", evolve_fg_p1!),
    run_drift("ForceGrad p=2", evolve_fg_p2!),
]

# --- Summary table ---

@printf("\nRelative energy drift ΔE/|E₀| (signed) sampled at t = 5, 10, 20 ω⁻¹:\n\n")
@printf("%-20s  %-13s  %-13s  %-13s  %-9s\n",
    "scheme", "drift@t=5", "drift@t=10", "drift@t=20", "wall(s)")
function _at(times, drifts, t)
    idx = findfirst(τ -> τ >= t, times)
    idx === nothing ? drifts[end] : drifts[idx]
end
for (label, times, drifts, wall) in results
    d5 = _at(times, drifts, 5.0)
    d10 = _at(times, drifts, 10.0)
    d20 = _at(times, drifts, 20.0)
    @printf("%-20s  %+.4e   %+.4e   %+.4e   %.1f\n",
        label, d5, d10, d20, wall)
end
