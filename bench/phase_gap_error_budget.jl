# How much accuracy does separating two ground-state phases actually need?
#
# Not answerable as a single number, and the reason matters. On a phase boundary
# the competing states are degenerate by construction, so ΔE → 0 and NO finite
# accuracy resolves the boundary exactly. The answerable question is how far the
# boundary MOVES:
#
#     δB_boundary ≈ δ(ΔE) / |∂(ΔE)/∂B|
#
# So the observable is the GAP between two competing states, not the total
# energy. That distinction is the whole point of this script. `SPIN_TAYLOR_TOL`
# was budgeted against the total energy (2.4e-13 out of E ≈ 10, i.e. 3e-11 of the
# splitting error) — but errors COMMON to both states cancel in ΔE and only the
# non-cancelling part decides a phase. A 1e-13 error on a total of 10 is a 1e-7
# relative error on a gap of 1e-6. The energy budget licenses an energy claim; it
# says nothing about a phase boundary.
#
# WHAT THIS MEASURES
#
#   cost   make_workspace time (which is where a tabulated LHY builds its table)
#          separately from per-step time. `FullBdGLHY <: TabulatedLHY` with
#          n_points = 200, so its documented "~100× dearer" is a ONE-TIME build,
#          not a per-step cost — worth confirming rather than repeating.
#   gap    ΔE = E(CSV seed) − E(FL seed) at fixed parameters, per arm.
#   slope  ∂(ΔE)/∂B from two B values, to turn δ(ΔE) into a boundary shift.
#
# THE DEGENERACY GUARD IS NOT OPTIONAL. ITP from a seed can leave that seed's
# basin and relax to the other state, in which case ΔE collapses to ~0 and the
# whole comparison is empty. This project has already read exactly that as
# physics once — seed gaps of 0 and 8.9e-16 taken for degeneracy when the real
# cause was that `method: lbfgs` had dropped the LHY term entirely. So each arm
# reports how far apart its two converged states actually are, and a gap quoted
# without that number should not be believed.
#
# v2 (2026-07-30). The first run answered nothing and said so: the arms were not
# converged (the dt/2 arm disagreed with the reference by 100×) and the
# degeneracy guard fired — two seeds relaxing to the same state, whose "gap" is a
# measure of nothing. Both are fixed here:
#
#   * each arm runs to its OWN fixed point (`tol` > 0, generous step cap) and
#     reports `converged` / `last_step`. A gap between unconverged runs is a gap
#     between two arbitrary points on two trajectories.
#   * states are classified by the per-component WINDING VECTOR — the observable
#     the claims actually rest on — and a gap is only reported when the two seeds
#     land in DIFFERENT classes. Same-class rows are printed as "no gap here",
#     which is information, not a failure.
#
#   julia --project=. bench/phase_gap_error_budget.jl [n] [max_steps]

using Printf
import CUDA
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_ENABLED, SPIN_TAYLOR_DEGREE_CAP, spin_density_vector,
    _winding_vector
using LinearAlgebra: norm

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
const MAX_STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 30000
const ITP_TOL = 1.0e-9
const SEEDS = (:flower, :chiral_spin_vortex)

grid_of() = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))

"""ITP from one seed, run to its OWN fixed point. Returns the energy, the
convergence state (a gap between unconverged runs means nothing) and the
per-component winding vector that classifies the state."""
function relax(; seed::Symbol, B::Float64, kind, dt, taylor::Bool, cap::Int)
    old_t, old_c = SPIN_TAYLOR_ENABLED[], SPIN_TAYLOR_DEGREE_CAP[]
    SPIN_TAYLOR_ENABLED[] = taylor
    SPIN_TAYLOR_DEGREE_CAP[] = cap
    try
        grid = grid_of()
        psi0 = init_psi(grid, SpinSystem(6); state=seed)
        gs = find_ground_state(;
            grid, atom=Eu151, interactions=eu_interaction_params(0.05),
            zeeman=ZeemanParams(linear_zeeman_p(Eu151, B, EU_ω_ref), 0.0),
            potential=HarmonicTrap((1.0, 1.0, EU_λ_z)), psi_init=psi0,
            dt, n_steps=MAX_STEPS, tol=ITP_TOL, save_every=200,
            enable_ddi=true, c_dd=EU_c_dd, ddi_padding=true, ddi_trunc_radius=-1.0,
            spinor_lhy=kind, backend=CUDABackend(), verbose=false,
        )
        psi_h = Array(gs.workspace.state.psi)
        _, _, fz = spin_density_vector(psi_h, gs.workspace.spin_matrices, 3)
        w = _winding_vector(psi_h, gs.workspace.grid, 13)
        (E=gs.energy, fz=fz, converged=gs.converged,
            steps=hasproperty(gs, :last_step) ? gs.last_step : -1,
            wind=w)
    finally
        SPIN_TAYLOR_ENABLED[] = old_t
        SPIN_TAYLOR_DEGREE_CAP[] = old_c
    end
end

"""ΔE between the two seeds at one B — plus everything needed to know whether
that number is a gap between PHASES at all."""
function gap(; B, kind, dt, taylor, cap)
    a = relax(; seed=SEEDS[1], B, kind, dt, taylor, cap)
    b = relax(; seed=SEEDS[2], B, kind, dt, taylor, cap)
    sep = norm(vec(a.fz) .- vec(b.fz)) / max(norm(vec(a.fz)), eps())
    # `isequal`, not `!=`: `_winding_vector` returns `missing` for a depopulated
    # component, and `!=` on vectors carrying missing yields `missing` rather than
    # a Bool — which is a TypeError the moment it reaches an `if`. `isequal`
    # treats missing as equal to missing and always returns Bool, so "the same
    # component is empty in both" reads as the same class, which is what it is.
    distinct = !isequal(a.wind, b.wind)   # the classification the claims rest on
    (dE=b.E - a.E, sep=sep, distinct=distinct,
        conv=a.converged && b.converged,
        steps=max(a.steps, b.steps), wa=a.wind, wb=b.wind)
end

# --- cost: table build vs per step -----------------------------------------
function cost(kind)
    grid = grid_of()
    psi0 = init_psi(grid, SpinSystem(6); state=:flower)
    sp = SimParams(; dt=0.002, n_steps=1, imaginary_time=true, save_every=10^9)
    build() = make_workspace(;
        grid, atom=Eu151, interactions=eu_interaction_params(0.05),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)), sim_params=sp, psi_init=psi0,
        enable_ddi=true, c_dd=EU_c_dd, ddi_padding=true, ddi_trunc_radius=-1.0,
        spinor_lhy=kind, backend=CUDABackend())
    build()                            # warm
    t0 = time();
    ws = build();
    t_build = time() - t0
    for _ in 1:5
        SpinorBEC.split_step!(ws)
    end
    CUDA.synchronize()
    best = Inf
    for _ in 1:20
        CUDA.synchronize();
        s = time_ns()
        SpinorBEC.split_step!(ws);
        CUDA.synchronize()
        best = min(best, (time_ns() - s) * 1e-9)
    end
    (build=t_build, step=best)
end

println("="^78)
println("Phase-gap error budget — Eu F=6 D=13, $(N_GRID)³, tol=$(ITP_TOL), cap $(MAX_STEPS) steps")
println("device: $(CUDA.name(CUDA.device()))   seeds: $(SEEDS)")
println("="^78)

println("\n[cost] make_workspace (tabulation) vs per RTP step")
@printf("  %-16s %12s %12s\n", "spinor_lhy", "build (s)", "step (ms)")
for kind in (nothing, :polar_contact, :full_bdg)
    c = cost(kind)
    @printf("  %-16s %12.2f %12.3f\n", repr(kind), c.build, c.step * 1e3)
    GC.gc(true);
    CUDA.reclaim()
end

# --- gap: a small B scan, so the boundary can be located rather than assumed ---
const BS = (2.6e-9, 3.5e-9, 4.4e-9, 5.2e-9)
const DT = 0.002

arms = [
    ("reference (Euler, full_bdg)", (kind=:full_bdg, dt=DT, taylor=false,
        cap=SpinorBEC.SPIN_TAYLOR_RK_MAX)),
    ("production (Taylor, polar_contact)", (kind=:polar_contact, dt=DT, taylor=true,
        cap=SpinorBEC.SPIN_TAYLOR_RK_MAX)),
    ("baseline probe: dt/2, reference", (kind=:full_bdg, dt=DT / 2, taylor=false,
        cap=SpinorBEC.SPIN_TAYLOR_RK_MAX)),
    ("control: rotation removed", (kind=:full_bdg, dt=DT, taylor=true, cap=0)),
]

println("\n[gap] ΔE = E($(SEEDS[2])) − E($(SEEDS[1])), tol=$(ITP_TOL), cap $(MAX_STEPS) steps")
println("  `distinct` = the two seeds ended in DIFFERENT winding classes. Only")
println("  those rows are gaps between phases; the rest say there is no second")
println("  minimum there, which is information rather than a failed measurement.")
@printf("\n  %-36s %8s %13s %6s %6s %9s\n",
    "arm", "B", "ΔE", "conv", "dist", "state sep")
results = Dict{Tuple{String, Float64}, Any}()
for (label, a) in arms, B in BS
    g = gap(; B, a.kind, a.dt, a.taylor, a.cap)
    results[(label, B)] = g
    @printf("  %-36s %8.2e %13.6e %6s %6s %9.3e\n",
        label, B, g.dE, g.conv ? "yes" : "NO", g.distinct ? "yes" : "no", g.sep)
    GC.gc(true);
    CUDA.reclaim()
end

# --- verdict --------------------------------------------------------------
println()
ref = [results[("reference (Euler, full_bdg)", B)] for B in BS]
usable = [i for i in eachindex(BS) if ref[i].conv && ref[i].distinct]
if length(usable) < 2
    println("""[verdict] The reference arm has $(length(usable)) usable B point(s) — a point is
usable only if BOTH seeds converged AND ended in different winding classes.
Fewer than two means the boundary cannot be located here and no δB can be
quoted. That is the honest outcome, not a number to report.""")
else
    dEs = [ref[i].dE for i in usable]
    Bs = [BS[i] for i in usable]
    signs = sign.(dEs)
    bracketed = any(signs[1:(end - 1)] .!= signs[2:end])
    slope = (dEs[end] - dEs[1]) / (Bs[end] - Bs[1])
    @printf("[verdict] usable B points: %d   ∂(ΔE)/∂B = %.4e   boundary %s\n",
        length(usable), slope, bracketed ? "BRACKETED" : "NOT bracketed")
    if !bracketed
        println("""  Not bracketed ⇒ this is a local rate on one side, and any δB from it is an
  extrapolation. Widen the scan before quoting a boundary shift.""")
    end
    if slope != 0
        println("  δB = δ(ΔE)/|∂(ΔE)/∂B|, each arm against the reference at the same B:")
        i0 = usable[1]
        for (label, _) in arms
            label == "reference (Euler, full_bdg)" && continue
            g = results[(label, BS[i0])]
            d = abs(g.dE - ref[i0].dE)
            @printf("    %-36s δ(ΔE) %10.3e → δB %10.3e  (conv %s)\n",
                label, d, d / abs(slope), g.conv ? "yes" : "NO")
        end
        println("""
  The dt/2 row is the BASELINE: the boundary shift already accepted by choosing
  dt. An approximation whose δB sits well under it is not what limits the
  boundary. And note the direction that helps — a SMALL |∂(ΔE)/∂B| is the bad
  case: it means the phases stay near-degenerate over a wide range of B, so any
  energy error moves the apparent boundary a long way, and far enough that way
  there is a crossover there and not a boundary at all.""")
    end
end
