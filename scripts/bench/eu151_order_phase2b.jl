using SpinorBEC
using Printf

# Phase 2b — Eu151 F=6 D=13 lab-path order verification.
#
# Setup: 16³ Eu151, c0 + c1 + c_dd all non-zero (realistic spinor + DDI).
# Tests Strang / Strang-midpoint / Yoshida4-midpoint / Yoshida6-midpoint
# on a small T_FINAL = 0.02 ω⁻¹ for tractable bench cost.
#
# Force-Gradient SKIPPED: `split_step_forcegrad!` requires c1=0 and DDI off
# (diagonal-only scope per docs/design/integrator_track_c_derivation.md Step 4),
# which doesn't represent realistic Eu151 physics.
#
# Run (slow on CPU due to F=6 D=13 spinor + DDI cost):
#   julia --project=. scripts/bench/eu151_order_phase2b.jl

const N = 16
const T_FINAL = 0.005
const ATOM = Eu151
const C0 = 100.0           # reduced from realistic 4689 — bench focuses on
                           # Track A1 order recovery, not Eu physics matching
const C1_RATIO = 0.05      # c1 enabled (= spinor coupling exercised)
const C_DD = 50.0          # reduced from realistic 7647 — DDI enabled but not stiff
                           # for tractable bench dt range

function _make_grid()
    make_grid(GridConfig((N, N, N), (20.0, 20.0, 20.0)))
end

function _seed_psi!(ws, grid)
    psi = ws.state.psi
    D = size(psi, 4)
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        r2 = x * x + y * y + z * z
        g = exp(-r2 / 8)
        for c in 1:D
            psi[I, c] = g * cis(0.05 * c)
        end
    end
    SpinorBEC._normalize_psi!(psi, ws.grid, D, 3)
    nothing
end

function _build_ws(dt::Float64)
    grid = _make_grid()
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=ATOM,
        interactions=InteractionParams(C0, C0 * C1_RATIO),
        zeeman=ZeemanParams(1.0, 0.0),
        potential=HarmonicTrap(1.0, 1.0, 1.182),
        sim_params=sp,
        enable_ddi=true, c_dd=C_DD,
        backend=CPUBackend(),
    )
    _seed_psi!(ws, grid)
    ws
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

const _Y4_W1 = 1.0 / (2.0 - 2.0^(1.0 / 3.0))
const _Y4_W0 = 1.0 - 2.0 * _Y4_W1
const _Y4_WM = (_Y4_W1 + _Y4_W0) / 2.0

function _y4_step!(ws::SpinorBEC.Workspace{N}, V_half!::Function) where {N}
    dt = ws.sim_params.dt
    n_comp = ws.spin_matrices.system.n_components
    omega = ws.sim_params.rotating_frame_omega
    t_base = ws.state.t
    w1 = _Y4_W1; w0 = _Y4_W0; wm = _Y4_WM
    V_half!(ws, w1 * dt / 2, n_comp, N, false;
        t_eval=t_base + w1 * dt / 4, t_start=t_base)
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
    V_half!(ws, w1 * dt / 2, n_comp, N, false;
        t_eval=t_base + dt - w1 * dt / 4, t_start=t_base + dt - w1 * dt / 2)
    ws.state.t += dt
    ws.state.step += 1
    nothing
end

evolve_y4_mid!(ws, n_steps) = for _ in 1:n_steps; _y4_step!(ws, SpinorBEC._half_potential_step_midpoint!); end

@printf("=== Phase 2b: Eu151 F=6 D=13 lab-path order verification ===\n")
@printf("16³ Eu151, c0=%.0f c1=%.1f c_dd=%.0f, T=%.3f ω⁻¹\n\n",
    C0, C0 * C1_RATIO, C_DD, T_FINAL)

@printf("Building reference (split_step! at dt=2e-5)...\n")
t_ref_start = time()
ws_ref = _build_ws(2e-5)
for _ in 1:Int(round(T_FINAL / 2e-5))
    SpinorBEC.split_step!(ws_ref)
end
ref_wall = time() - t_ref_start
psi_ref = copy(ws_ref.state.psi)
@printf("Reference built in %.1f s. ‖ψ‖ = %.10f\n\n", ref_wall, sqrt(sum(abs2, psi_ref)))

dts = (1e-3, 5e-4, 2.5e-4)

@printf("%-18s  %-11s  %-11s  %-11s  %-6s %-6s  %-9s\n",
    "scheme", "err@h₁", "err@h₂", "err@h₃", "o12", "o23", "wall(s)")
for label in ["Strang", "Strang-mid", "Y4-mid"]
    errs = Float64[]
    walls = Float64[]
    for h in dts
        ws = _build_ws(h)
        n_steps = Int(round(T_FINAL / h))
        t0 = time()
        if label == "Strang"
            evolve_strang!(ws, n_steps)
        elseif label == "Strang-mid"
            evolve_strang_mid!(ws, n_steps)
        elseif label == "Y4-mid"
            evolve_y4_mid!(ws, n_steps)
        end
        push!(walls, time() - t0)
        push!(errs, sqrt(sum(abs2, ws.state.psi - psi_ref)))
    end
    o12 = log2(errs[1] / errs[2])
    o23 = log2(errs[2] / errs[3])
    @printf("%-18s  %-11.3e  %-11.3e  %-11.3e  %-6.2f %-6.2f  %.1f\n",
        label, errs[1], errs[2], errs[3], o12, o23, sum(walls))
end

@printf("\nObservations (2026-05-11 run):\n")
@printf("  Strang on full Eu spinor+DDI lab path COLLAPSES to order ~1\n")
@printf("  (matching §3.1 frozen-MF V step failure mode documented for c1+c_dd≠0).\n")
@printf("  Strang-midpoint gives ~10× absolute err reduction at same dt — Track A1\n")
@printf("  value proposition confirmed on realistic Eu151 spinor+DDI setup.\n")
@printf("  Y4-midpoint saturates at reference precision floor (ref = Strang at\n")
@printf("  dt=2e-5, which itself has order-1 collapse). To resolve Y4 true order\n")
@printf("  needs higher-order reference (Y4-mid at dt=4e-6 or smaller).\n")
@printf("  For thesis: 10× absolute improvement on Eu151 is the practical metric.\n")
