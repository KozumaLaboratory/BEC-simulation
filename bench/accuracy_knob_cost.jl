# What does each accuracy knob COST, on one footing?
#
# `ACCURACY_KNOBS` records what every knob is worth in ACCURACY, because that is
# what a config author needs in order not to trade it away by accident. It records
# the cost for exactly one of them. That asymmetry is why `:fast` has a single
# member: a knob may only enter it with a measured cost AND a defensible residual,
# and most knobs are missing the first half.
#
# This measures the first half for all of them, on one card, in one job, against
# one production shape — so "which knobs are even candidates" stops being a guess.
#
# It does NOT measure the second half. A knob needs both, and the accuracy side
# needs a reference and an observable (see bench/phase_gap_error_budget.jl), so a
# cheap knob here is a candidate and nothing more.
#
# Two of the rows are worth stating in advance because they are not intuitive:
#
#   * `spin_taylor = false` is what `:reference` DOES. Its cost is the price of
#     the reference profile, and nobody had written that down.
#   * `dealias_2_3 = true` is the ACCURATE direction and it adds work — six
#     complex FFTs per DDI call for the F filter, plus a ψ pre-filter. So this
#     row is the cost of being right, not of being fast.
#
#   julia --project=. bench/accuracy_knob_cost.jl [n] [reps]

using Printf
import CUDA
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_ENABLED, DEALIAS_2_3_ENABLED, accuracy_profile

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
const REPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 30

function build(; kind, pad_factor, secular, dtype=Float64)
    grid = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))
    psi0 = init_psi(grid, SpinSystem(6); state=:spin_coherent,
        init_theta=π / 4, init_phi=0.3)
    ws = make_workspace(;
        grid, atom=Eu151, interactions=eu_interaction_params(0.05),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        sim_params=SimParams(; dt=0.002, n_steps=1, imaginary_time=true,
            save_every=10^9),
        psi_init=psi0, enable_ddi=true, c_dd=EU_c_dd,
        ddi_padding=true, ddi_trunc_radius=-1.0, ddi_pad_factor=pad_factor,
        secular_ddi=secular, spinor_lhy=kind, backend=CUDABackend())
    dV = prod(grid.config.box_size ./ grid.config.n_points)
    ws.state.psi ./= sqrt(sum(abs2, ws.state.psi) * dV)
    ws
end

"One ITP step: the chain `_run_itp_loop!` actually executes."
function itp_step!(ws)
    dt = ws.sim_params.dt
    nc = ws.spin_matrices.system.n_components
    SpinorBEC._outer_potential_fwd!(ws, dt / 4, nc, 3, true)
    SpinorBEC._ddi_step!(ws, dt / 2, 3, true)
    SpinorBEC._outer_potential_bwd!(ws, dt / 4, nc, 3, true)
    SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), ws.state.psi, 0.0, false, ws)
    SpinorBEC._outer_potential_fwd!(ws, dt / 4, nc, 3, true)
    SpinorBEC._ddi_step!(ws, dt / 2, 3, true)
    SpinorBEC._outer_potential_bwd!(ws, dt / 4, nc, 3, true)
    SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, nc, 3)
end

function step_ms(ws)
    for _ in 1:5
        itp_step!(ws)
    end
    CUDA.synchronize()
    best = Inf
    for _ in 1:REPS
        CUDA.synchronize()
        t0 = time_ns()
        itp_step!(ws)
        CUDA.synchronize()
        best = min(best, (time_ns() - t0) * 1e-6)
    end
    best
end

"Time one ITP step with the given knob settings, restoring the globals."
function measure(; kind=nothing, pad_factor=2, secular=false,
    taylor=true, dealias=false)
    ot, od = SPIN_TAYLOR_ENABLED[], DEALIAS_2_3_ENABLED[]
    SPIN_TAYLOR_ENABLED[] = taylor
    DEALIAS_2_3_ENABLED[] = dealias
    try
        ws = build(; kind, pad_factor, secular)
        t = step_ms(ws)
        ws = nothing
        GC.gc(true)
        CUDA.reclaim()
        t
    finally
        SPIN_TAYLOR_ENABLED[] = ot
        DEALIAS_2_3_ENABLED[] = od
    end
end

println("="^80)
println("Accuracy-knob COST — Eu F=6 D=13, $(N_GRID)³, one ITP step, $(CUDA.name(CUDA.device()))")
println("(cost only. a cheap knob is a CANDIDATE; entering :fast also needs a")
println(" residual measured small against an error already accepted.)")
println("="^80)

base = measure()          # production: no LHY, pad 2, full DDI, Taylor on, dealias off
@printf("\n  %-46s %9s %8s\n", "setting", "ms/step", "vs prod")
@printf("  %-46s %9.3f %8s\n", "PRODUCTION (lhy none, pad 2, Taylor, no dealias)", base, "1.000")

rows = [
    ("spinor_lhy = :polar_contact", (; kind=:polar_contact)),
    ("spinor_lhy = :full_bdg   [:reference]", (; kind=:full_bdg)),
    ("ddi_pad_factor = 1.5     [:fast]", (; pad_factor=1.5)),
    ("ddi_pad_factor = 3.0     [:reference]", (; pad_factor=3.0)),
    ("secular_ddi = true", (; secular=true)),
    ("spin_taylor = false      [:reference]", (; taylor=false)),
    ("dealias_2_3 = true       [:reference]", (; dealias=true)),
]
for (label, kw) in rows
    t = measure(; kw...)
    @printf("  %-46s %9.3f %8.3f\n", label, t, t / base)
end

println("""

[read] `vs prod` above 1 means the setting is SLOWER than production. Several of
the accurate settings are — that is the price of `:reference`, and it belongs in
the profile report rather than in a reader's head. Settings below 1 are the only
ones `:fast` could ever contain, and each still needs its residual measured
against an already-accepted error before it may.""")
