using SpinorBEC
using Printf

# Phase 2a — Track A1 HARD GATE.
#
# Re-runs the lab-path MPS-4 / Yoshida-4 / Yoshida-6 order check from
# `scripts/bench/mps4_lab_diagnostic.jl`, this time with the midpoint
# variant of the V step plumbed in. Setup is Rb87 F=1 D=3, 16³, with
# c0 + c1 + c_dd all non-zero — the same configuration that previously
# collapsed MPS-4 to order ~1.
#
# Gate criterion:
#   * Strang remains order 2 (unchanged baseline)
#   * MPS-4 (midpoint base) recovers order ≥ 3.5
#   * Yoshida-6 (midpoint base) ideally recovers to order ≥ 5; if it
#     stays ≤ 2 the cause is NOT just V-step asymmetry — re-open
#     diagnostics
#
# If MPS-4 fails to recover (still ~1):
#   * Verify `psi_mf` flows through every substep that reads MF —
#     re-check spin_mixing, ddi, ddi_padded, diagonal, nematic, tensor
#   * Add a round-trip τ² scaling test (S(h)·S(-h)·ψ - ψ) to confirm
#     the V step is truly symmetric
#
# Run:
#   julia --project=. scripts/bench/midpoint_order_phase2a.jl

const N = 16
const T_FINAL = 0.04
const ATOM = Rb87
const C0 = 50.0
const C1 = 1.0
const C_DD = 1.0

function _make_grid()
    make_grid(GridConfig((N, N, N), (8.0, 8.0, 8.0)))
end

function _seed_psi!(ws, grid)
    psi = ws.state.psi
    D = size(psi, 4)
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        g = exp(-(x * x + y * y + z * z) / 2)
        for c in 1:D
            psi[I, c] = g * cis(0.1 * c)
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
        interactions=InteractionParams(C0, C1),
        zeeman=ZeemanParams(0.5, 0.1),
        potential=HarmonicTrap(1.0, 1.0, 1.0),
        sim_params=sp,
        enable_ddi=true, c_dd=C_DD,
        backend=CPUBackend(),
    )
    _seed_psi!(ws, grid)
    ws
end

# --- Schemes ---

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

# MPS-4 driver factory: parameterised by base step
function _make_mps4_driver(base_step!)
    function step!(psi_out, ws_h, ws_half, psi_in)
        copyto!(ws_h.state.psi, psi_in)
        base_step!(ws_h)
        copyto!(ws_half.state.psi, psi_in)
        base_step!(ws_half)
        base_step!(ws_half)
        @. psi_out = (4 / 3) * ws_half.state.psi - (1 / 3) * ws_h.state.psi
        nothing
    end
    function evolve!(ws_h, ws_half, n_steps)
        psi_in = similar(ws_h.state.psi)
        for _ in 1:n_steps
            copyto!(psi_in, ws_h.state.psi)
            step!(ws_h.state.psi, ws_h, ws_half, psi_in)
        end
        nothing
    end
    return evolve!
end

const evolve_mps4_plain = _make_mps4_driver(SpinorBEC.split_step!)
const evolve_mps4_mid = _make_mps4_driver(SpinorBEC.split_step_midpoint!)

# Yoshida-4 over an arbitrary V step (drop-in for `_half_potential_step!`
# or `_half_potential_step_midpoint!`).
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
    V_half!(ws, wm * dt, n_comp, N, false;
        t_eval=t_v2 + wm * dt / 2, t_start=t_v2)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w0 * dt / 2, false, ws.coriolis_cache)
    SpinorBEC._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, w0 * dt)
    SpinorBEC.apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    SpinorBEC._apply_coriolis_step!(ws.state.psi, ws.grid, omega, w0 * dt / 2, false, ws.coriolis_cache)

    t_v3 = t_base + w1 * dt / 2 + wm * dt
    V_half!(ws, wm * dt, n_comp, N, false;
        t_eval=t_v3 + wm * dt / 2, t_start=t_v3)
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

evolve_y4_plain!(ws, n_steps) = for _ in 1:n_steps; _y4_step!(ws, SpinorBEC._half_potential_step!); end
evolve_y4_mid!(ws, n_steps)   = for _ in 1:n_steps; _y4_step!(ws, SpinorBEC._half_potential_step_midpoint!); end

# --- Reference (fine sequential split_step!) ---

@printf("=== Phase 2a: Track A1 hard gate (Rb87 F=1, c0=%.0f, c1=%.1f, c_dd=%.0f) ===\n",
    C0, C1, C_DD)
@printf("N=%d (3D), T_final=%.3f\n\n", N, T_FINAL)

@printf("Building reference (split_step! at dt=2e-5)...\n")
ws_ref = _build_ws(2e-5)
for _ in 1:Int(round(T_FINAL / 2e-5))
    SpinorBEC.split_step!(ws_ref)
end
psi_ref = copy(ws_ref.state.psi)
norm_ref = sqrt(sum(abs2, psi_ref))
@printf("Reference ‖ψ‖ = %.10f\n\n", norm_ref)

# --- Order test ---

dts = (4e-3, 2e-3, 1e-3)

@printf("%-23s  %-11s  %-11s  %-11s  %-6s %-6s  %-12s\n",
    "scheme", "err@h₁", "err@h₂", "err@h₃", "o12", "o23", "norm drift @h₂")

function run_scheme(label::String, dt::Float64)
    n_steps = Int(round(T_FINAL / dt))
    if label == "Strang"
        ws = _build_ws(dt); evolve_strang!(ws, n_steps); return ws.state.psi
    elseif label == "Strang-mid"
        ws = _build_ws(dt); evolve_strang_mid!(ws, n_steps); return ws.state.psi
    elseif label == "Yoshida4 (plain)"
        ws = _build_ws(dt); evolve_y4_plain!(ws, n_steps); return ws.state.psi
    elseif label == "Yoshida4 (midpoint)"
        ws = _build_ws(dt); evolve_y4_mid!(ws, n_steps); return ws.state.psi
    elseif label == "MPS-4 (plain)"
        ws_h = _build_ws(dt); ws_half = _build_ws(dt / 2)
        evolve_mps4_plain(ws_h, ws_half, n_steps); return ws_h.state.psi
    elseif label == "MPS-4 (midpoint)"
        ws_h = _build_ws(dt); ws_half = _build_ws(dt / 2)
        evolve_mps4_mid(ws_h, ws_half, n_steps); return ws_h.state.psi
    else
        error("unknown scheme $label")
    end
end

results = Dict{String, Tuple{Float64, Float64, Float64}}()

for label in ["Strang", "Strang-mid",
              "Yoshida4 (plain)", "Yoshida4 (midpoint)",
              "MPS-4 (plain)", "MPS-4 (midpoint)"]
    errs = Float64[]
    drift_h2 = NaN
    for (idx, h) in enumerate(dts)
        psi = run_scheme(label, h)
        push!(errs, sqrt(sum(abs2, psi - psi_ref)))
        if idx == 2
            drift_h2 = sqrt(sum(abs2, psi)) - norm_ref
        end
    end
    o12 = log2(errs[1] / errs[2])
    o23 = log2(errs[2] / errs[3])
    results[label] = (o12, o23, errs[end])
    @printf("%-23s  %-11.3e  %-11.3e  %-11.3e  %-6.2f %-6.2f  %-12.3e\n",
        label, errs[1], errs[2], errs[3], o12, o23, drift_h2)
end

@printf("\n--- Gate evaluation ---\n")
strang_o = results["Strang"][2]
strang_mid_o = results["Strang-mid"][2]
mps_plain_o = results["MPS-4 (plain)"][2]
mps_mid_o = results["MPS-4 (midpoint)"][2]

strang_ok = abs(strang_o - 2.0) < 0.3
strang_mid_ok = abs(strang_mid_o - 2.0) < 0.3
mps_plain_collapse = mps_plain_o < 1.5
mps_mid_pass = mps_mid_o >= 3.5

@printf("  Strang order at finest dt:           %.2f  (expect ≈ 2)  %s\n",
    strang_o, strang_ok ? "OK" : "FAIL")
@printf("  Strang-midpoint order at finest dt:  %.2f  (expect ≈ 2)  %s\n",
    strang_mid_o, strang_mid_ok ? "OK" : "FAIL")
@printf("  MPS-4 (plain) order at finest dt:    %.2f  (expect collapse to ~1)  %s\n",
    mps_plain_o, mps_plain_collapse ? "OK (collapse reproduced)" : "WARN (unexpected non-collapse)")
@printf("  MPS-4 (midpoint) order at finest dt: %.2f  (gate: ≥ 3.5)  %s\n",
    mps_mid_o, mps_mid_pass ? "PASS" : "FAIL")

if mps_mid_pass
    @printf("\n✅  Track A1 hard gate PASSED. Proceed to Phase 2b (Eu151 F=6 full order table).\n")
else
    @printf("\n❌  Track A1 hard gate FAILED. MPS-4 midpoint did not recover to order ≥ 3.5.\n")
    @printf("   Next: round-trip τ² scaling test, audit `psi_mf` plumbing in each substep.\n")
end
