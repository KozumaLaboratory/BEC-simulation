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
# v5 (2026-07-31). At 120000 steps every arm CONVERGES (dE ≈ 9.5e-10 against a
# 1e-9 target) and every arm reports the two seeds landing in the SAME winding
# class, with `state sep` at 1e-3 (reference) to 1e-7 (production) against 1.09
# for the broken control. So the bistability v3 appeared to show was
# under-convergence: the seeds had simply not merged yet at 30000 steps.
#
# BUT THAT MAY BE MY OWN DESIGN AND NOT THE PHYSICS. Two-stage relaxation runs
# both seeds through a COMMON LHY-free stage 1 first. If stage 1 already collapses
# them onto one state, stage 2 only refines it and "0 distinct" says nothing about
# whether two minima exist — the comparison would have been destroyed by the fix
# that made the reference well-posed. So v5 records `state sep` at the END OF
# STAGE 1 as well. The FIRST version of that check compared sep@1 to the final
# sep and flagged "merged" when they were close — which is wrong, and the smoke
# said so: at 40 steps both are ≈ 0.43, i.e. nothing merged and stage 2 simply had
# no time to act, yet the rule fired on all 16 points. Closeness of the two says
# stage 2 did nothing; it does not say stage 1 did everything.
#
# So the separation is recorded at all THREE points — seed, end of stage 1, end of
# stage 2 — and the question becomes which leg of that trajectory did the
# collapsing. That is readable directly from the printed numbers, so the rule is a
# convenience rather than the evidence.
#
# Also worth an explanation, and NOT yet explained: the reference arm reports
# ΔE = 43.4 between two states that agree to 1.6e-3, where the production arm
# reports 6.1e-3. Each seed builds its OWN full_bdg table from its own stage-1
# state, and those tables are individually scheme-dependent, so the suspicion is
# that ΔE there is a difference of TABLES rather than of states. `sep_1` plus the
# per-seed ε_LHY now printed makes that checkable instead of suspected.
#
#   julia --project=. bench/phase_gap_error_budget.jl [n] [max_steps]

# ITERATION COST. Four runs of this bench, 40 min of H100 each, and TWO of them
# changed no physics at all — one added a recorded column, one fixed a line of
# verdict logic. That is the wrong shape for a loop meant to answer questions.
# Three changes fix it:
#
#   * MEASURE AND JUDGE ARE SEPARATE. Every cell is appended to a JSONL as soon as
#     it finishes; `bench/phase_gap_report.jl` reads that file and prints every
#     verdict. Changing how a result is READ now costs a second and no GPU.
#   * CELLS ARE CACHED, keyed on the tree hash of `src/` plus the cell's own
#     parameters. A run that changes only reporting reuses everything; a run that
#     changes `src/` reuses nothing. The cache REFUSES to load when `src/` is
#     dirty and says so — a cache silently serving results from other code is the
#     exact bug class this file exists to catch.
#   * ROWS STREAM. Each row prints and flushes when done, so the first cell is
#     readable at ~2 min instead of the whole grid at ~40, and a run that has
#     already answered the question can be killed.
#
using Printf
using Serialization: serialize, deserialize
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

# --- cell cache -------------------------------------------------------------
# Keyed on the tree hash of `src/`, so reporting-only edits reuse every cell and a
# physics edit reuses none. Disabled outright when `src/` is dirty: a cache that
# serves results computed by code you have since changed is worse than no cache,
# and this file exists to catch exactly that kind of silent mismatch.
const CACHE_DIR = get(ENV, "SPINORBEC_GAP_CACHE",
    joinpath(@__DIR__, "..", ".gap_cache"))
# Keyed on `src/` AND on this file: the measurement half lives HERE, so a cache
# that watched only `src/` would happily serve cells produced by a different
# `relax`. It nearly did — the winding-at-stage-1 field below is a bench-only
# change that src/'s tree hash cannot see.
const SRC_REV = try
    isempty(strip(read(`git status --porcelain -- src`, String))) ?
    string(strip(read(`git rev-parse HEAD:src`, String)), "-",
        string(hash(read(@__FILE__, String)); base=16)) : nothing
catch
    nothing
end
# One JSONL PER src key, not one shared file. It is appended to, so a shared name
# would silently interleave rows from different revisions of the code and the
# report would average over them — the same corruption the smoke/production split
# already guards against, one level up.
const RESULTS_JSONL = get(ENV, "SPINORBEC_GAP_JSONL",
    joinpath(CACHE_DIR, "rows_$(SRC_REV === nothing ? "dirty" : SRC_REV[1:12]).jsonl"))

if SRC_REV === nothing
    println("[cache] DISABLED — src/ is dirty or not a git tree. Every cell recomputes.")
else
    mkpath(CACHE_DIR)
    println("[cache] $(CACHE_DIR)  src=$(SRC_REV[1:12])")
end

_cell_key(nt) = string(hash((SRC_REV, N_GRID, MAX_STEPS, ITP_TOL, ITP_TOL_DRHO,
        SEEDS, nt)); base=16)

"Run `f()` unless this cell is already on disk for this exact `src/` tree."
function cached(f, nt)
    SRC_REV === nothing && return f()
    path = joinpath(CACHE_DIR, "cell_$(_cell_key(nt)).jls")
    if isfile(path)
        try
            return deserialize(path)
        catch e
            @warn "cache entry unreadable, recomputing" path exception = e
        end
    end
    v = f()
    serialize(path, v)
    v
end

"One ITP run at fixed knobs. `psi0` is a state, so a caller can chain stages."
function itp(; psi0, B::Float64, kind, dt, steps::Int, pad::Float64)
    grid = grid_of()
    find_ground_state(;
        grid, atom=Eu151, interactions=eu_interaction_params(0.05),
        zeeman=ZeemanParams(linear_zeeman_p(Eu151, B, EU_ω_ref), 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)), psi_init=psi0,
        dt, n_steps=steps, tol=ITP_TOL, tol_drho=ITP_TOL_DRHO, save_every=200,
        enable_ddi=true, c_dd=EU_c_dd, ddi_padding=true, ddi_trunc_radius=-1.0,
        ddi_pad_factor=pad, spinor_lhy=kind, backend=CUDABackend(), verbose=false,
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
function relax(; seed::Symbol, B::Float64, kind, dt, taylor::Bool, cap::Int,
    pad::Float64)
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
        pre = itp(; psi0=seed_psi, B, kind=nothing, dt, steps=nsteps ÷ 2, pad)
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
        gs = itp(; psi0=psi_pre, B, kind, dt, steps=nsteps, pad)
        psi_h = Array(gs.workspace.state.psi)
        sm = gs.workspace.spin_matrices
        _, _, fz = spin_density_vector(psi_h, sm, 3)
        _, _, fz1 = spin_density_vector(psi_pre, sm, 3)
        _, _, fz0 = spin_density_vector(Array(seed_psi), sm, 3)
        w = _winding_vector(psi_h, gs.workspace.grid, 13)
        # The winding class at the END OF STAGE 1 — the same observable the
        # verdict classifies by. A separation RATIO cannot answer "did the
        # scaffolding produce this answer", because absolute and relative give
        # opposite verdicts on the same data: stage 1 closes ~0.94 of the gap
        # (so it "did most of it") while stage 2 closes 5 further orders (so it
        # "did most of it"). Both readings are true and neither is the question.
        # The question is whether the arm still had two classes to choose
        # between when it took over, and that is this.
        w1 = _winding_vector(psi_pre, gs.workspace.grid, 13)
        (E=gs.energy, fz=fz, fz1=fz1, fz0=fz0, wind1=w1, converged=gs.converged, growth=growth,
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
function gap(; B, kind, dt, taylor, cap, pad)
    a = cached((; seed=SEEDS[1], B, kind, dt, taylor, cap, pad)) do
        relax(; seed=SEEDS[1], B, kind, dt, taylor, cap, pad)
    end
    b = cached((; seed=SEEDS[2], B, kind, dt, taylor, cap, pad)) do
        relax(; seed=SEEDS[2], B, kind, dt, taylor, cap, pad)
    end
    sep = norm(vec(a.fz) .- vec(b.fz)) / max(norm(vec(a.fz)), eps())
    # The same measure at the two earlier points of the trajectory: the raw seeds,
    # and the end of the common LHY-free stage 1. `sep0 → sep1 → sep` says WHERE
    # the two seeds stopped being different — and if that is the first leg, the
    # two-stage scaffolding merged them and the arm's `distinct` verdict is about
    # my design rather than about whether two minima exist.
    sep1 = norm(vec(a.fz1) .- vec(b.fz1)) / max(norm(vec(a.fz1)), eps())
    sep0 = norm(vec(a.fz0) .- vec(b.fz0)) / max(norm(vec(a.fz0)), eps())
    # `isequal`, not `!=`: `_winding_vector` returns `missing` for a depopulated
    # component, and `!=` on vectors carrying missing yields `missing` rather than
    # a Bool — which is a TypeError the moment it reaches an `if`. `isequal`
    # treats missing as equal to missing and always returns Bool, so "the same
    # component is empty in both" reads as the same class, which is what it is.
    distinct = !isequal(a.wind, b.wind)   # the classification the claims rest on
    # Were they ALREADY in one class when the arm took over? If so the arm never
    # had a choice and its `distinct` says nothing about whether two minima exist.
    distinct1 = !isequal(a.wind1, b.wind1)
    (dE=b.E - a.E, sep=sep, sep1=sep1, sep0=sep0, distinct=distinct, distinct1=distinct1,
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

# THE ARM THIS WHOLE EXERCISE WAS FOR was missing from six runs of this bench.
# `ddi_pad_factor = 1.5` is the ONLY measured speedup among the accuracy knobs
# (0.906x at 32^3; every other knob is free or costs), and the question that
# decides it is "does it change the winding classification". That question needs
# the `[classification]` section only — arms agreeing or disagreeing with each
# other — and NOT the reference arm, which `bench/lhy_stability_scan.jl` has since
# shown can never be dynamically stable for a dipolar gas. So it is answerable
# here even though the boundary verdict is not.
const RK = SpinorBEC.SPIN_TAYLOR_RK_MAX
arms = [
    ("reference (Euler, full_bdg)", (kind=:full_bdg, dt=DT, taylor=false, cap=RK, pad=2.0)),
    ("production (Taylor, polar_contact)", (kind=:polar_contact, dt=DT, taylor=true,
        cap=RK, pad=2.0)),
    ("candidate: ddi_pad_factor 1.5", (kind=:polar_contact, dt=DT, taylor=true,
        cap=RK, pad=1.5)),
    ("baseline probe: dt/2, reference", (kind=:full_bdg, dt=DT / 2, taylor=false,
        cap=RK, pad=2.0)),
    ("control: rotation removed", (kind=:full_bdg, dt=DT, taylor=true, cap=0, pad=2.0)),
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
println("  `sep@0 → sep@1 → sep` is the separation at the raw seeds, at the end of")
println("  the common LHY-free stage 1, and at the end of the arm. If the collapse")
println("  happens on the FIRST leg the scaffolding merged the seeds, not the arm —")
println("  read that before reading `dist`.")
@printf("\n  %-36s %8s %13s %6s %9s %6s %9s %9s %9s %9s\n",
    "arm", "B", "ΔE", "conv", "final dE", "dist", "sep@0", "sep@1", "sep", "max Imω")
results = Dict{Tuple{String, Float64}, Any}()
for (label, a) in arms, B in BS
    g = gap(; B, a.kind, a.dt, a.taylor, a.cap, a.pad)
    results[(label, B)] = g
    @printf("  %-36s %8.2e %13.6e %6s %9.2e %6s %9.3e %9.3e %9.3e %9.3g\n",
        label, B, g.dE, g.conv ? "yes" : "NO", g.dEf,
        g.distinct ? "yes" : "no", g.sep0, g.sep1, g.sep, g.growth)
    # Stream: the row is readable NOW, not when the grid finishes. Piped through
    # a filter stdout block-buffers otherwise, which is why four runs showed
    # nothing for 40 minutes and could not be killed early.
    flush(stdout)
    open(RESULTS_JSONL, "a") do io
        println(io, "{\"arm\":\"$(label)\",\"B\":$(B),\"dE\":$(g.dE)," *
                    "\"conv\":$(g.conv),\"dEf\":$(g.dEf),\"distinct\":$(g.distinct)," *
                    "\"sep0\":$(g.sep0),\"sep1\":$(g.sep1),\"sep\":$(g.sep)," *
                    "\"distinct1\":$(g.distinct1)," *
                    "\"growth\":$(g.growth),\"n\":$(N_GRID),\"steps\":$(MAX_STEPS)," *
                    "\"src\":\"$(SRC_REV === nothing ? "dirty" : SRC_REV)\"}")
    end
    GC.gc(true);
    CUDA.reclaim()
end

# --- verdict --------------------------------------------------------------
# The judgement lives in `phase_gap_report.jl` and is CALLED from here, not
# duplicated. That file also runs standalone over the JSONL, so re-reading a
# finished measurement costs a second and no GPU — which is the point: two of the
# first four runs of this bench changed nothing but the judgement.
include(joinpath(@__DIR__, "phase_gap_report.jl"))
report([merge((arm=label, B=B), results[(label, B)]) for (label, _) in arms, B in BS])
