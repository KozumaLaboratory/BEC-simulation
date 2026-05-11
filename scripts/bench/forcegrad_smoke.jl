using SpinorBEC
using Printf

# Track C Phase 0 smoke test — Force-Gradient 4A (Chin-Krotscheck 2005, eq 6.8)
# vs Strang, Yoshida-4-midpoint baselines.
#
# Setup: 1D Rb87 (F=1, D=3) harmonic + cubic c0 NLS. Diagonal-only
# (c1 = 0, no DDI, no Raman, no transverse Zeeman). This is the scope
# of v1 Force-Gradient (`split_step_forcegrad!`).
#
# Two test points:
#   (1) c0 = 0 (autonomous, linear quantum): Force-Gradient should give
#       clean order 4 (4A00 = Chin-Krotscheck 2005 algorithm, no MF
#       time-dependence so no Picard required).
#   (2) c0 ≠ 0 (nonlinear GP): Force-Gradient 4A00 has order-degraded
#       behavior due to mean-field time-dependence; full 4AWW with
#       Picard would recover order 4 (deferred). Compare to Strang
#       baseline.
#
# Run:
#   julia --project=. scripts/bench/forcegrad_smoke.jl

const N1D = 64
const T_FINAL = 0.04
const ATOM = Rb87

function _build_ws(dt::Float64, c0::Float64)
    grid = make_grid(GridConfig(N1D, 8.0))
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=ATOM,
        interactions=InteractionParams(c0, 0.0),  # c1 = 0 (diagonal-only)
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

function evolve_strang!(ws, n_steps)
    for _ in 1:n_steps
        SpinorBEC.split_step!(ws)
    end
end

function evolve_strang_mid!(ws, n_steps)
    for _ in 1:n_steps
        SpinorBEC.split_step_midpoint!(ws)
    end
end

function evolve_forcegrad!(ws, n_steps)
    for _ in 1:n_steps
        SpinorBEC.split_step_forcegrad!(ws)
    end
end

# Y4 over arbitrary V step (copied from midpoint_order_phase2a.jl)
const _Y4_W1 = 1.0 / (2.0 - 2.0^(1.0 / 3.0))
const _Y4_W0 = 1.0 - 2.0 * _Y4_W1
const _Y4_WM = (_Y4_W1 + _Y4_W0) / 2.0

function _y4_step!(ws::SpinorBEC.Workspace{N}, V_half!::Function) where {N}
    dt = ws.sim_params.dt
    n_comp = ws.spin_matrices.system.n_components
    omega = ws.sim_params.rotating_frame_omega
    t_base = ws.state.t
    w1 = _Y4_W1; w0 = _Y4_W0; wm = _Y4_WM
    V_half!(ws, w1 * dt / 2, n_comp, N, false; t_eval=t_base + w1 * dt / 4, t_start=t_base)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    t_v2 = t_base + w1 * dt / 2
    V_half!(ws, wm * dt, n_comp, N, false; t_eval=t_v2 + wm * dt / 2, t_start=t_v2)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w0 * dt / 2, false, ws.coriolis_cache)
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w0 * dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w0 * dt / 2, false, ws.coriolis_cache)
    t_v3 = t_base + w1 * dt / 2 + wm * dt
    V_half!(ws, wm * dt, n_comp, N, false; t_eval=t_v3 + wm * dt / 2, t_start=t_v3)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w1 * dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w1 * dt / 2, false, ws.coriolis_cache)
    V_half!(ws, w1 * dt / 2, n_comp, N, false; t_eval=t_base + dt - w1 * dt / 4, t_start=t_base + dt - w1 * dt / 2)
    ws.state.t += dt
    ws.state.step += 1
    nothing
end

evolve_y4_mid!(ws, n_steps) = for _ in 1:n_steps; _y4_step!(ws, SpinorBEC._half_potential_step_midpoint!); end

# --- Order verification ---

function run_scheme(label::String, c0::Float64, dt::Float64)
    n_steps = Int(round(T_FINAL / dt))
    if label == "Strang"
        ws = _build_ws(dt, c0); evolve_strang!(ws, n_steps); return ws.state.psi
    elseif label == "Strang-mid"
        ws = _build_ws(dt, c0); evolve_strang_mid!(ws, n_steps); return ws.state.psi
    elseif label == "Y4-mid"
        ws = _build_ws(dt, c0); evolve_y4_mid!(ws, n_steps); return ws.state.psi
    elseif label == "ForceGrad-4A00"
        ws = _build_ws(dt, c0); evolve_forcegrad!(ws, n_steps); return ws.state.psi
    else
        error("unknown scheme $label")
    end
end

function order_table(c0::Float64, label_for_problem::String)
    @printf("\n=== Force-Gradient 4A smoke (1D Rb87 F=1, c0=%.1f, %s) ===\n",
        c0, label_for_problem)
    @printf("N=%d, T_final=%.3f\n\n", N1D, T_FINAL)

    @printf("Building reference (split_step! at dt=2e-5)...\n")
    ws_ref = _build_ws(2e-5, c0)
    for _ in 1:Int(round(T_FINAL / 2e-5))
        SpinorBEC.split_step!(ws_ref)
    end
    psi_ref = copy(ws_ref.state.psi)
    @printf("Reference ‖ψ‖ = %.10f\n\n", sqrt(sum(abs2, psi_ref)))

    dts = (8e-3, 4e-3, 2e-3, 1e-3)

    @printf("%-18s  %-11s  %-11s  %-11s  %-11s  %-6s %-6s %-6s\n",
        "scheme", "err@h₁", "err@h₂", "err@h₃", "err@h₄",
        "o12", "o23", "o34")
    for label in ["Strang", "Strang-mid", "Y4-mid", "ForceGrad-4A00"]
        errs = Float64[]
        for h in dts
            psi = run_scheme(label, c0, h)
            push!(errs, sqrt(sum(abs2, psi - psi_ref)))
        end
        o12 = log2(errs[1] / errs[2])
        o23 = log2(errs[2] / errs[3])
        o34 = log2(errs[3] / errs[4])
        @printf("%-18s  %-11.3e  %-11.3e  %-11.3e  %-11.3e  %-6.2f %-6.2f %-6.2f\n",
            label, errs[1], errs[2], errs[3], errs[4], o12, o23, o34)
    end
end

order_table(0.0, "AUTONOMOUS — c0=0, linear quantum mechanics")
@printf("\nExpected (v2 with FFT spectral ∇V + midpoint + endpoint MF):\n")
@printf("  ForceGrad-4A00 ≈ order 4 (autonomous → no MF time-dep → exact 4A).\n")
@printf("  Observed: order ~3.9 in resolvable range, hits reference precision floor.\n")
@printf("  Strang ≈ 2, Y4-mid ≈ 4 (Track A1 baseline).\n")

order_table(50.0, "NONLINEAR — c0=50, GP equation")
@printf("\nExpected (v2 partial 4AWW: midpoint + endpoint MF via Strang predictors):\n")
@printf("  ForceGrad-4A00 ≈ order 3 (MF estimates O(dt²) accurate → V step output\n")
@printf("  O(dt³) per step → cumulative O(dt²) ≈ order 2-3 depending on constants).\n")
@printf("  Full order 4 would need Picard fixed-point on MFs — deferred to v3.\n")
@printf("  Strang ≈ 2, Y4-mid ≈ 4 (Track A1 baseline).\n")
