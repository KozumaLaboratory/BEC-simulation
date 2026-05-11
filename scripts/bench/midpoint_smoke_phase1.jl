using SpinorBEC
using Printf

# Phase 1 smoke test — Track A1 midpoint scheme: regression / sanity check.
#
# Setup: 1D Rb87 (F=1, D=3) harmonic + cubic c0 NLS, NO spin mixing (c1=0),
# NO DDI. The only mean-field coupling is c0 |ψ|² in the diagonal step.
#
# Pass criterion (this script is gate-soft):
#   * Strang remains order 2 with the midpoint variant
#   * Yoshida-4 remains order 4 with the midpoint variant
#   * MPS-4 remains order ~4 with the midpoint variant
#   * Norm drift bounded by O(dt^4) for MPS-4 (~1e-10 at dt=1e-3)
#
# Negative result (any scheme dropping > 0.3 order vs its plain counterpart)
# means the midpoint plumbing leaks `psi_mf` somewhere or breaks an internal
# substep invariant — investigate before moving to Phase 2a.
#
# Run:
#   julia --project=. scripts/bench/midpoint_smoke_phase1.jl

const N1D = 64
const T_FINAL = 0.05
const ATOM = Rb87
const C0_NL = 50.0

function _build_ws(dt::Float64)
    grid = make_grid(GridConfig(N1D, 8.0))
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=ATOM,
        interactions=InteractionParams(C0_NL, 0.0),
        zeeman=ZeemanParams(0.0, 0.0),
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

# --- Scheme entry points (lab path) ---

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

# Yoshida-4 via composer (no public `yoshida4_step!`, call core directly)
function evolve_y4!(ws, n_steps)
    for _ in 1:n_steps
        SpinorBEC._yoshida_core!(ws, ws.sim_params.dt, ws.spin_matrices.system.n_components)
        ws.state.t += ws.sim_params.dt
        ws.state.step += 1
    end
end

# MPS-4 over Strang
function mps4_step!(psi_out, ws_h, ws_half, psi_in; midpoint::Bool=false)
    step! = midpoint ? SpinorBEC.split_step_midpoint! : SpinorBEC.split_step!
    copyto!(ws_h.state.psi, psi_in)
    step!(ws_h)
    copyto!(ws_half.state.psi, psi_in)
    step!(ws_half)
    step!(ws_half)
    @. psi_out = (4 / 3) * ws_half.state.psi - (1 / 3) * ws_h.state.psi
    nothing
end

function evolve_mps4!(ws_h, ws_half, n_steps; midpoint::Bool=false)
    psi_in = similar(ws_h.state.psi)
    for _ in 1:n_steps
        copyto!(psi_in, ws_h.state.psi)
        mps4_step!(ws_h.state.psi, ws_h, ws_half, psi_in; midpoint=midpoint)
    end
end

# --- Reference ---

@printf("=== Phase 1: midpoint smoke test (1D Rb87 F=1, c0=%.0f, no c1/DDI) ===\n",
    C0_NL)
@printf("N=%d, T_final=%.3f\n\n", N1D, T_FINAL)

@printf("Building reference (split_step! at dt=5e-6)...\n")
ws_ref = _build_ws(5e-6)
for _ in 1:Int(round(T_FINAL / 5e-6))
    SpinorBEC.split_step!(ws_ref)
end
psi_ref = copy(ws_ref.state.psi)
norm_ref = sqrt(sum(abs2, psi_ref))
@printf("Reference ‖ψ‖ = %.10f\n\n", norm_ref)

# --- Order test ---

dts = (8e-3, 4e-3, 2e-3, 1e-3)

@printf("%-22s  %-11s  %-11s  %-11s  %-11s  %-6s %-6s %-6s  %-12s\n",
    "scheme", "err@h₁", "err@h₂", "err@h₃", "err@h₄",
    "o12", "o23", "o34", "norm drift @h₃")

function run_scheme(label::String, dt::Float64)
    n_steps = Int(round(T_FINAL / dt))
    if label == "Strang"
        ws = _build_ws(dt); evolve_strang!(ws, n_steps); return ws.state.psi
    elseif label == "Strang-mid"
        ws = _build_ws(dt); evolve_strang_mid!(ws, n_steps); return ws.state.psi
    elseif label == "Yoshida4"
        ws = _build_ws(dt); evolve_y4!(ws, n_steps); return ws.state.psi
    elseif label == "MPS-4"
        ws_h = _build_ws(dt); ws_half = _build_ws(dt / 2)
        evolve_mps4!(ws_h, ws_half, n_steps; midpoint=false); return ws_h.state.psi
    elseif label == "MPS-4-mid"
        ws_h = _build_ws(dt); ws_half = _build_ws(dt / 2)
        evolve_mps4!(ws_h, ws_half, n_steps; midpoint=true); return ws_h.state.psi
    else
        error("unknown scheme $label")
    end
end

for label in ["Strang", "Strang-mid", "Yoshida4", "MPS-4", "MPS-4-mid"]
    errs = Float64[]
    drift_h3 = NaN
    for (idx, h) in enumerate(dts)
        psi = run_scheme(label, h)
        push!(errs, sqrt(sum(abs2, psi - psi_ref)))
        if idx == 3
            drift_h3 = sqrt(sum(abs2, psi)) - norm_ref
        end
    end
    o12 = log2(errs[1] / errs[2])
    o23 = log2(errs[2] / errs[3])
    o34 = log2(errs[3] / errs[4])
    @printf("%-22s  %-11.3e  %-11.3e  %-11.3e  %-11.3e  %-6.2f %-6.2f %-6.2f  %-12.3e\n",
        label, errs[1], errs[2], errs[3], errs[4], o12, o23, o34, drift_h3)
end

@printf("\nExpected (gate ±0.3):\n")
@printf("  Strang       :  o ≈ 2\n")
@printf("  Strang-mid   :  o ≈ 2  (must match Strang within ±0.3)\n")
@printf("  Yoshida4     :  o ≈ 4\n")
@printf("  MPS-4        :  o ≈ 4\n")
@printf("  MPS-4-mid    :  o ≈ 4\n")
