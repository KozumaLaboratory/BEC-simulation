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
# v3 (2026-07-30). v2 still answered nothing, and this time the run had TOLD me
# why in a line I had filtered out of the log:
#
#     FullBdG LHY: mean field is dynamically unstable (max Im ω = 1040.0)
#
# `:full_bdg` tabulates ε_LHY from the peak-density spinor of the state the
# workspace is BUILT with, and the reference arm handed it a raw `:flower` seed.
# Where the mean field is dynamically unstable ε_LHY is scheme-dependent — the
# zero-point sum drops the complex branches while the counterterms still subtract
# all D of them — so the reference arm's ITP had no fixed point to converge to.
# Non-convergence was the CORRECT behaviour of a well-posed code on an ill-posed
# request. I read it as "unconverged", then as "blocked on issue #172", and both
# were wrong.
#
# So v3 changes what is asked, not the tolerances:
#
#   * TWO-STAGE relaxation. Stage 1 relaxes with no LHY at all; stage 2 rebuilds
#     the workspace from that RELAXED ψ, so the table is tabulated from a
#     physical state rather than a seed, and re-converges. Both stages run for
#     every arm, so the staging itself is not a confound between them.
#   * the stability is now ASKED, not inferred. `lhy_mean_field_max_growth` at the
#     relaxed peak spinor is printed per row, and a nonzero value marks the row
#     unusable — the honest verdict, and one that costs milliseconds instead of a
#     30000-step ITP that was never going to land.
#
# v4 (2026-07-31). Two defects the v3 run exposed in itself:
#
#   * THE dt/2 ARM WAS CONFOUNDED. Every arm got the same step cap, so halving dt
#     halved the imaginary time reached. Its `state sep` staying at 5e-2 where the
#     dt arm collapsed to 4e-5 therefore says "less relaxed", not "dt matters" —
#     the arm meant to measure the discretisation error was measuring its own
#     shorter run. Steps now scale as DT/dt, so all arms cover the same τ.
#   * 30000 STEPS DOES NOT CONVERGE THIS PROBLEM. Every arm finished at
#     dE ≈ 1e-6..1e-5 against a 1e-9 target, and a gap between two unconverged
#     runs is a gap between two points on two trajectories. The cap is raised.
#
# What v3 DID establish, and what to keep looking at: ΔE is not the usable
# observable here. The reference arm and its own dt/2 baseline disagree by ~7 at
# a B where ΔE itself is ~8-15, so the discretisation error is of order the
# observable. `state sep` — how far apart the two converged states are — moved
# monotonically and by four orders across the B scan, which is a signal. And the
# positive control fired: with the spin rotation removed, final dE ran 1e-1
# instead of 1e-6, so the instrument is not blind.
#
#   julia --project=. bench/phase_gap_error_budget.jl [n] [max_steps]

using Printf
import CUDA
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_ENABLED, SPIN_TAYLOR_DEGREE_CAP, spin_density_vector,
    _winding_vector, _extract_spinor, lhy_mean_field_max_growth
using LinearAlgebra: norm

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
const MAX_STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 120000
const ITP_TOL = 1.0e-9
# The DENSITY-based, gauge-invariant convergence gate. A texture carries a gauge
# orbit — a global U(1) phase and a spin rotation about z — that leaves ρ and the
# energy's physical content alone but keeps `dE/|E|` moving, which is why
# `tol_drho` exists at all. v2 used `tol` only and every one of 16 arms reported
# `converged = false` after 30000 steps at 32³, so nothing it measured was a gap.
const ITP_TOL_DRHO = 1.0e-7
const SEEDS = (:flower, :chiral_spin_vortex)
# Defined here rather than beside the arms: `relax` scales its step count by
# DT/dt, so the reference dt has to exist before the first arm runs.
const DT = 0.002

grid_of() = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))

"One ITP run at fixed knobs. `psi0` is a state, so a caller can chain stages."
function itp(; psi0, B::Float64, kind, dt, steps::Int)
    grid = grid_of()
    find_ground_state(;
        grid, atom=Eu151, interactions=eu_interaction_params(0.05),
        zeeman=ZeemanParams(linear_zeeman_p(Eu151, B, EU_ω_ref), 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)), psi_init=psi0,
        dt, n_steps=steps, tol=ITP_TOL, tol_drho=ITP_TOL_DRHO, save_every=200,
        enable_ddi=true, c_dd=EU_c_dd, ddi_padding=true, ddi_trunc_radius=-1.0,
        spinor_lhy=kind, backend=CUDABackend(), verbose=false,
    )
end

"""TWO-STAGE ITP from one seed.

Stage 1 relaxes with NO LHY, so stage 2 can tabulate ε_LHY from a relaxed state
rather than from the seed. That ordering is the whole point: a tabulated LHY is
built once, at `make_workspace` time, from the peak-density spinor it is handed,
and a seed's peak spinor is not a physical mean field. Both stages run for every
arm so the staging cannot differ between them.

Returns the energy, the convergence state, the winding vector that classifies the
state — and `growth`, the `max Im ω` of the mean field the table was built from.
`growth > 0` means ε_LHY is scheme-dependent for this row and the row is not a
measurement of anything, whatever its ΔE says."""
function relax(; seed::Symbol, B::Float64, kind, dt, taylor::Bool, cap::Int)
    old_t, old_c = SPIN_TAYLOR_ENABLED[], SPIN_TAYLOR_DEGREE_CAP[]
    SPIN_TAYLOR_ENABLED[] = taylor
    SPIN_TAYLOR_DEGREE_CAP[] = cap
    try
        grid = grid_of()
        seed_psi = init_psi(grid, SpinSystem(6); state=seed)
        # Steps scale INVERSELY with dt, so every arm covers the same imaginary
        # time. Without this the dt/2 arm reaches half the τ of the others and
        # its "smaller error" is just a shorter run — which is exactly what v3
        # measured and nearly reported as a dt effect.
        nsteps = round(Int, MAX_STEPS * (DT / dt))
        # Stage 1: mean field only. Half the step budget — it starts from a seed
        # and only has to reach a physical texture, not the final fixed point.
        pre = itp(; psi0=seed_psi, B, kind=nothing, dt, steps=nsteps ÷ 2)
        psi_pre = Array(pre.workspace.state.psi)

        # Ask, before spending the second stage, whether a reference is even
        # defined at the state stage 2 would tabulate from.
        ip = eu_interaction_params(0.05)
        zee = ZeemanParams(linear_zeeman_p(Eu151, B, EU_ω_ref), 0.0)
        n_peak = maximum(sum(abs2, psi_pre; dims=4))
        growth = try
            lhy_mean_field_max_growth(; F=6, spinor=_extract_spinor(psi_pre),
                n0=n_peak, interactions=ip, zeeman=zee, c_dd=EU_c_dd)
        catch
            NaN
        end

        # Stage 2: the arm's own LHY, tabulated from the relaxed ψ.
        gs = itp(; psi0=psi_pre, B, kind, dt, steps=nsteps)
        psi_h = Array(gs.workspace.state.psi)
        _, _, fz = spin_density_vector(psi_h, gs.workspace.spin_matrices, 3)
        w = _winding_vector(psi_h, gs.workspace.grid, 13)
        (E=gs.energy, fz=fz, converged=gs.converged, growth=growth,
            # The final dE VALUE, not just the boolean. Without it "not
            # converged" cannot be told apart from "converged, but this
            # criterion never fires" — which is the whole question when a gauge
            # orbit is in play.
            dE_final=hasproperty(gs, :dE) ? gs.dE : NaN,
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
        # The WORSE of the two, because a reference is only defined where BOTH
        # states have one.
        growth=max(a.growth, b.growth),
        dEf=max(a.dE_final, b.dE_final), steps=max(a.steps, b.steps),
        wa=a.wind, wb=b.wind)
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

arms = [
    ("reference (Euler, full_bdg)", (kind=:full_bdg, dt=DT, taylor=false,
        cap=SpinorBEC.SPIN_TAYLOR_RK_MAX)),
    ("production (Taylor, polar_contact)", (kind=:polar_contact, dt=DT, taylor=true,
        cap=SpinorBEC.SPIN_TAYLOR_RK_MAX)),
    ("baseline probe: dt/2, reference", (kind=:full_bdg, dt=DT / 2, taylor=false,
        cap=SpinorBEC.SPIN_TAYLOR_RK_MAX)),
    ("control: rotation removed", (kind=:full_bdg, dt=DT, taylor=true, cap=0)),
]

println("\n[gap] ΔE = E($(SEEDS[2])) − E($(SEEDS[1])), tol=$(ITP_TOL), " *
        "tol_drho=$(ITP_TOL_DRHO), cap $(MAX_STEPS) steps")
println("  `final dE` is the last dE/|E| reached. If it is far below `tol` while")
println("  `conv` says NO, the run IS at its fixed point and the criterion is the")
println("  thing that did not fire — read it before believing 'not converged'.")
println("  `distinct` = the two seeds ended in DIFFERENT winding classes. Only")
println("  those rows are gaps between phases; the rest say there is no second")
println("  minimum there, which is information rather than a failed measurement.")
println("  `max Imω` is the mean field the LHY table was built from. Nonzero ⇒")
println("  ε_LHY is scheme-dependent for that row and its ΔE is not a gap.")
@printf("\n  %-36s %8s %13s %6s %9s %6s %9s %9s\n",
    "arm", "B", "ΔE", "conv", "final dE", "dist", "state sep", "max Imω")
results = Dict{Tuple{String, Float64}, Any}()
for (label, a) in arms, B in BS
    g = gap(; B, a.kind, a.dt, a.taylor, a.cap)
    results[(label, B)] = g
    @printf("  %-36s %8.2e %13.6e %6s %9.2e %6s %9.3e %9.3g\n",
        label, B, g.dE, g.conv ? "yes" : "NO", g.dEf,
        g.distinct ? "yes" : "no", g.sep, g.growth)
    GC.gc(true);
    CUDA.reclaim()
end

# --- verdict --------------------------------------------------------------
#
# The classification, not ΔE, is what the claims rest on — so the first thing to
# report is whether the ARMS AGREE about it. If two accuracy settings put the
# same (B, seeds) in different winding classes, that disagreement IS the accuracy
# requirement, stated in the units the claim is made in, and it does not need a
# converged ΔE or a slope to be meaningful.
println("\n[classification] does the accuracy setting change the ANSWER?")
@printf("  %-36s %s\n", "arm", join((@sprintf("%9.2e", B) for B in BS), " "))
for (label, _) in arms
    @printf("  %-36s %s\n", label,
        join((results[(label, B)].distinct ? "  distinct" : "      same" for B in BS), " "))
end
let base = [results[(arms[1][1], B)].distinct for B in BS]
    dis = [(label, B) for (label, _) in arms[2:end], B in BS
           if results[(label, B)].distinct != base[findfirst(==(B), BS)]]
    if isempty(dis)
        println("  All arms agree on every point — so no setting tested here changes")
        println("  the classification, and the requirement is looser than the coarsest.")
    else
        println("  DISAGREEMENT at $(length(dis)) point(s): " *
                join(("$(l) @ B=$(b)" for (l, b) in dis), "; "))
        println("  Each is a setting that changes the answer, i.e. an accuracy floor —")
        println("  but read it against `state sep` in the table: a pair that is already")
        println("  4 orders closer at that B is a near-degenerate crossover, where any")
        println("  setting can flip the label and none of them is wrong.")
    end
end

println()
ref = [results[("reference (Euler, full_bdg)", B)] for B in BS]
usable = [i for i in eachindex(BS)
          if ref[i].conv && ref[i].distinct && (ref[i].growth == 0)]
if length(usable) < 2
    nconv = count(r -> r.conv, ref)
    ndist = count(r -> r.distinct, ref)
    nstab = count(r -> r.growth == 0, ref)
    println("""[verdict] The reference arm has $(length(usable)) usable B point(s) — a point is
usable only if BOTH seeds converged, ended in DIFFERENT winding classes, AND the
mean field the LHY table came from is dynamically stable. Of $(length(BS)) points:
$(nconv) converged, $(ndist) distinct, $(nstab) stable. Fewer than two usable means
the boundary cannot be located here and no δB can be quoted — and the breakdown
says WHICH of the three is missing, so the next run changes that one rather than
the tolerances.""")
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
