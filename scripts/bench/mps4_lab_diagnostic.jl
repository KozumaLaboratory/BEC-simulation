using SpinorBEC, Printf, BenchmarkTools

# Lab-path MPS-4 diagnostic — final state of Track A investigation.
#
# Background: MPS-4 (Chin-Geiser, IMA JNA 31, 1552, 2011) gives
# global order ~4 on rotating-basis F=1 with c1≠0 / c_dd≠0 (see
# scripts/bench/mps_smoke.jl). Same construction on the lab path
# (Workspace + split_step! / split_step_combined!) collapses to
# order ~1 — confirmed for both F=6 D=13 (Eu151) and F=1 D=3 (Rb87)
# with c1, c_dd ≠ 0. This file reproduces the F=1 isolation that
# rules out spinor-coupling matrix non-commutativity as the cause.
#
# Conclusion (recorded in docs/integrator_modernization_plan.md):
# the lab-path V-step is a NESTED Strang `diag · SM · DDI · SM · diag`
# where each SM/DDI substep evaluates the mean field (Φ_DDI, c1⟨F⟩)
# at substep ENTRY, not midpoint. The asymmetry between the
# evaluations on the left and right sides of the inner Strang
# breaks time-reversal symmetry of the outer V → introduces a τ²
# even-power local error that plain Strang iteration absorbs (still
# global order 2) but MPS-4's Richardson coefficients (-1/3, 4/3)
# fail to cancel, collapsing global order to 1.
#
# Decision: Track A (MPS-4) parked. Path forward = "midpoint-
# symmetrize lab Strang" (Track A1 in the plan), then re-run
# MPS-4 on top of that.
#
# Run:
#   julia --project=. scripts/bench/mps4_lab_diagnostic.jl

const N = 16
const T_FINAL = 0.04           # weaker DDI → can integrate longer
const ATOM = Rb87              # F=1 D=3 (was Eu151 F=6 D=13)
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
        g = exp(-(x*x + y*y + z*z) / 2)
        for c in 1:D
            psi[I, c] = g * cis(0.1*c)
        end
    end
    SpinorBEC._normalize_psi!(psi, ws.grid, D, 3)
    nothing
end

# Build a workspace pinned to a specific dt. SimParams is immutable, so
# the only way to vary dt for the same physical config is to construct
# separate Workspaces with separate batched_kinetic phase caches.
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

# MPS-4 step for the lab path. Needs three pre-built workspaces sharing
# the same grid/atom config but DIFFERENT dt — this is unavoidable
# because batched_kinetic's phase cache is tied to the dt at workspace
# construction.
#
# Inputs:
#   ws_h:    dt = h     (single full step)
#   ws_half: dt = h/2   (two half steps)
#   psi_in:  current state to evolve from
# Output: ψ → ψ + h-evolution by MPS-4 written into psi_out
function mps4_combined_step!(psi_out, ws_h, ws_half, psi_in)
    # Branch a: S(h)
    copyto!(ws_h.state.psi, psi_in)
    SpinorBEC.split_step_combined!(ws_h)
    # Branch b: S(h/2) twice
    copyto!(ws_half.state.psi, psi_in)
    SpinorBEC.split_step_combined!(ws_half)
    SpinorBEC.split_step_combined!(ws_half)
    # Linear combination
    @. psi_out = (4/3) * ws_half.state.psi - (1/3) * ws_h.state.psi
    nothing
end

# Strang baseline: just call split_step_combined! repeatedly.
function evolve_strang_combined!(ws, n_steps)
    for _ in 1:n_steps
        SpinorBEC.split_step_combined!(ws)
    end
end

# MPS-4 driver: alternates between ws_h and ws_half, parking the
# "current" state in ws_h.state.psi between calls.
function evolve_mps4_combined!(ws_h, ws_half, n_steps)
    psi_in = similar(ws_h.state.psi)
    for _ in 1:n_steps
        copyto!(psi_in, ws_h.state.psi)
        # We use ws_h.state.psi as the "output" location after each step.
        mps4_combined_step!(ws_h.state.psi, ws_h, ws_half, psi_in)
    end
end

@printf("=== Lab-path MPS-4 vs split_step_combined! (Eu151 F=6 D=13, 16³, CPU) ===\n")
@printf("c0=%.0f c1=%.1f c_dd=%.0f, T_final=%.2f\n\n", C0, C1, C_DD, T_FINAL)

# Reference: very fine SEQUENTIAL split_step! (the standard reference;
# split_step_combined! is what we're testing so cannot use it as ref).
@printf("Building reference (split_step! at dt=2e-5)...\n")
ws_ref = _build_ws(2e-5)
for _ in 1:Int(round(T_FINAL / 2e-5))
    SpinorBEC.split_step!(ws_ref)
end
psi_ref = copy(ws_ref.state.psi)
norm_ref = sqrt(sum(abs2, psi_ref))
@printf("Reference ‖ψ‖ = %.10f\n\n", norm_ref)

# Order test: 3 step sizes — relax to larger dt now that c_dd=1 (less stiff)
dts = (4e-3, 2e-3, 1e-3)

@printf("%-21s  %-12s  %-12s  %-12s  %-7s %-7s  %-12s\n",
    "scheme", "err@h₁", "err@h₂", "err@h₃", "ord_ab", "ord_bc", "norm drift @h₂")

function evolve_strang_split!(ws, n_steps)
    for _ in 1:n_steps
        SpinorBEC.split_step!(ws)
    end
end

# MPS-4 on top of sequential split_step! — rules out the frozen-MF
# asymmetry hypothesis if order ≥ 3 emerges
function mps4_split_step!(psi_out, ws_h, ws_half, psi_in)
    copyto!(ws_h.state.psi, psi_in)
    SpinorBEC.split_step!(ws_h)
    copyto!(ws_half.state.psi, psi_in)
    SpinorBEC.split_step!(ws_half)
    SpinorBEC.split_step!(ws_half)
    @. psi_out = (4/3) * ws_half.state.psi - (1/3) * ws_h.state.psi
    nothing
end

function evolve_mps4_split!(ws_h, ws_half, n_steps)
    psi_in = similar(ws_h.state.psi)
    for _ in 1:n_steps
        copyto!(psi_in, ws_h.state.psi)
        mps4_split_step!(ws_h.state.psi, ws_h, ws_half, psi_in)
    end
end

for (label, _) in [
        ("split_step!",          :split_step),
        ("split_step_combined!", :combined),
        ("MPS-4 (combined)",     :mps4_combined),
        ("MPS-4 (split_step!)",  :mps4_split),
    ]
    errs = Float64[]
    drift_at_h2 = NaN
    for (idx, h) in enumerate(dts)
        if label == "split_step!"
            ws = _build_ws(h)
            evolve_strang_split!(ws, Int(round(T_FINAL / h)))
            psi = ws.state.psi
        elseif label == "split_step_combined!"
            ws = _build_ws(h)
            evolve_strang_combined!(ws, Int(round(T_FINAL / h)))
            psi = ws.state.psi
        elseif label == "MPS-4 (combined)"
            ws_h    = _build_ws(h)
            ws_half = _build_ws(h/2)
            evolve_mps4_combined!(ws_h, ws_half, Int(round(T_FINAL / h)))
            psi = ws_h.state.psi
        else  # MPS-4 (split_step!)
            ws_h    = _build_ws(h)
            ws_half = _build_ws(h/2)
            evolve_mps4_split!(ws_h, ws_half, Int(round(T_FINAL / h)))
            psi = ws_h.state.psi
        end
        push!(errs, sqrt(sum(abs2, psi - psi_ref)))
        if idx == 2
            drift_at_h2 = sqrt(sum(abs2, psi)) - norm_ref
        end
    end
    @printf("%-21s  %-12.3e  %-12.3e  %-12.3e  %-7.2f %-7.2f  %-12.3e\n",
        label, errs[1], errs[2], errs[3],
        log2(errs[1]/errs[2]), log2(errs[2]/errs[3]), drift_at_h2)
end

@printf("\n=== Cost per outer step (single MPS-4 call vs split_step_combined!) ===\n")
ws_h    = _build_ws(2e-3)
ws_half = _build_ws(1e-3)
psi_in = similar(ws_h.state.psi)

# Warmup
for _ in 1:3
    copyto!(psi_in, ws_h.state.psi)
    mps4_combined_step!(ws_h.state.psi, ws_h, ws_half, psi_in)
    SpinorBEC.split_step_combined!(ws_h)
end

b_strang = @benchmark SpinorBEC.split_step_combined!($ws_h) samples=50 evals=1
b_mps    = @benchmark begin
    copyto!($psi_in, $ws_h.state.psi)
    mps4_combined_step!($ws_h.state.psi, $ws_h, $ws_half, $psi_in)
end samples=50 evals=1
t_strang = time(minimum(b_strang)) / 1e3
t_mps    = time(minimum(b_mps)) / 1e3
@printf("Strang (split_step_combined!): %.1f µs/step\n", t_strang)
@printf("MPS-4 (1×S(h) + 2×S(h/2)):     %.1f µs/step (%.2f× Strang, expected ~3×)\n",
    t_mps, t_mps / t_strang)
