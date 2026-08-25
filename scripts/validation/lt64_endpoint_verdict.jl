# #424 — apply the rejection criterion that was fixed BEFORE the 20 arms launched.
#
# The criterion is written into `runs/klaus_quench_long_time_ensemble/README.md`
# and restated in code here so that it cannot be re-fitted to whatever landed:
#
#   ESTABLISHED  if |mean(static) - mean(baseline)| >= 2 * SE_diff
#   SE_diff      = sd_pooled * sqrt(2/n)          <- sd POOLED FROM THESE RUNS
#   NOT ESTABLISHED otherwise: the ledger row stays `open` and the measured SE
#                   is reported, together with the n it WOULD need.
#
# "A run that finishes and then has its interpretation chosen is not a
# measurement." The threshold is a constant in this file for exactly that reason.
#
# TWO THINGS THIS REFUSES TO DO
#
# 1. **It takes the hold-peak inside the hold.** An argmax over the whole
#    trajectory reads the pre-hold transient; at 10.4 nT that blinded 7 arms of
#    10 (§12.1). The endpoint needs no window, but the peak is reported beside it
#    and must not be wrong.
#
#    THE WINDOW CONSTANTS ARE THIS SUITE'S, AND GETTING THEM WRONG IS SILENT.
#    The hold step of `lt64_ens_*.yaml` is `duration: 100.0, dt: 0.005,
#    save.every: 1000`, so nhold = 100.0/(0.005*1000) = 20 frames. The first run
#    of this script used `save_every = 100`, which gives nhold = 200 — longer
#    than the array — so `lo` clamped to 1 and every "hold-peak" was really a
#    whole-trajectory argmax. It printed a baseline peak of 0.50571 at frame 20
#    against the 0.37973 the README records, and the static arms matched their
#    recorded 0.49081 exactly, so the disagreement was visible only because ONE
#    of the three groups had a stored number to check against.
#
#    That is why `peak_frame` is in the output. A peak at the first frame of the
#    window is a decaying transient; at the last, a truncation. Read it.
#
# 2. **It never silently drops an arm.** A missing or unfinished arm is named and
#    counted. n is what actually landed, and if n < 7 per arm the criterion
#    cannot be applied at all — the README says so — and this says so too rather
#    than computing a tighter-looking interval from fewer points.
#
# MIGRATED TO `reanalyze` (#483, 2026-08-26). The window and the reduction now
# come from two `ObservableDefinition`s and the numbers come off one read per arm,
# so the vintage of the points is recorded beside the verdict and the result says
# in machine-readable form that it has not been through the ancestor gate.
#
#   * **The pre-registered criterion did not move.** `K_SIGMA`, `N_MIN`, the
#     pooled-sd formula and the sizing calculation are untouched below. A
#     rejection criterion that rides along inside a refactor is no longer
#     pre-registered, so the refactor stops at the extraction.
#   * **`arm_values` is KEPT as the reference and differenced on every run.** It
#     states the window inline; `reanalyze` states it in an `ObservableDefinition`.
#     Two independent statements of one observable, compared on arms nobody can
#     re-run — the same discipline the Hamiltonian terms are under, and the only
#     safe way to change the path underneath a stored measurement.
#   * The window arithmetic this file's header warns about is now
#     `SpinorBEC.hold_window_frames`, one definition for the three drivers that
#     had a copy each. Its counterpart guard is in `reanalyze`: a hold window
#     LONGER than the array is refused per arm and named, where both this file
#     and the entry point used to clamp it silently to the whole trajectory —
#     which is the failure the header describes, and it was still live in the
#     entry point until this migration.
#
# USE
#   julia --project=. scripts/validation/lt64_endpoint_verdict.jl <runs-root>

using JLD2
using JSON
using Printf
using Statistics
using SpinorBEC

"Threshold in units of SE_diff, fixed before launch. Do not tune."
const K_SIGMA = 2.0

"Minimum arms per group the sizing calculation requires. Below this: no answer."
const N_MIN = 7

"""
    arm_values(dir; hold_duration, dt, save_every) -> NamedTuple | String

`(peak, endpoint)` P_adj for one run directory, or a String naming the failure.

THE REFERENCE, KEPT AND DIFFERENCED. This states the window and the reduction
inline; `reanalyze` states them in `OBS_PEAK` / `OBS_ENDPOINT`. Every run compares
the two and stops on a disagreement, which is what makes it safe to move the path
underneath numbers taken off arms nobody is going to re-run. Note its `max(1, …)`
clamp: that is the historical behaviour this file's header describes, deliberately
left in place here so a short arm makes the two definitions DISAGREE loudly
instead of both quietly widening the window.
"""
function arm_values(dir::AbstractString; hold_duration::Float64=100.0,
    dt::Float64=0.005, save_every::Int=1000)
    f = joinpath(dir, "point_001.jld2")
    isfile(f) || return "no point_001.jld2"
    JLD2.jldopen(f, "r") do g
        haskey(g, "dynamics") || return "no dynamics block"
        d = g["dynamics"]
        haskey(d, "component_populations") || return "no component_populations"
        P = d["component_populations"]
        P = P isa AbstractMatrix ? P : permutedims(reduce(hcat, P))
        adj = [P[i, 2] + P[i, 3] for i in axes(P, 1)]
        length(adj) >= 2 || return "only $(length(adj)) frame(s)"
        nhold = max(1, Int(floor(hold_duration / (dt * save_every))))
        lo = max(1, length(adj) - nhold + 1)
        w = @view adj[lo:end]
        k = lo - 1 + argmax(w)
        (; peak=adj[k], peak_frame=k, endpoint=adj[end],
            nframes=length(adj), hold_from=lo)
    end
end

group_of(name) = occursin("baseline", name) ? "baseline" :
                 occursin("static", name) ? "static" :
                 occursin("rotating", name) ? "rotating" : "?"

"""
The hold window in FRAMES for THIS suite. `lt64_ens_*.yaml` holds for
`duration: 100.0` at `dt: 0.005` saving every `1000`, so 100.0/(0.005·1000) = 20.

Derived by `SpinorBEC.hold_window_frames` rather than spelled out, because this
file's own header records what the third hand-written copy of that expression
cost: `save_every = 100` instead of 1000 gave a 200-frame window over a 20-frame
array, and every "hold peak" printed was a whole-trajectory argmax.
"""
const HOLD_FRAMES = SpinorBEC.hold_window_frames(100.0; dt=0.005, save_every=1000)

"""
Per-frame `P_adj` for one stored point, or a String naming why it could not be
read. The window and the reduction are NOT here — that is the point of routing
through the entry point.
"""
function padj_series(path::AbstractString)
    JLD2.jldopen(path, "r") do g
        haskey(g, "dynamics") || return "no dynamics block"
        d = g["dynamics"]
        haskey(d, "component_populations") || return "no component_populations"
        P = d["component_populations"]
        P = P isa AbstractMatrix ? P : permutedims(reduce(hcat, P))
        adj = [P[i, 2] + P[i, 3] for i in axes(P, 1)]
        length(adj) >= 2 || return "only $(length(adj)) frame(s)"
        Dict("P_adj" => adj)
    end
end

"""
The peak, taken INSIDE the hold. `accept`, not `reject`: `peak_frame` is printed
beside every arm precisely so a peak at the window's first frame (a decaying
transient) or its last (a truncation) is READ rather than withheld — the header's
rule, unchanged by the migration.
"""
const OBS_PEAK = SpinorBEC.ObservableDefinition("peak P_adj in hold";
    series="P_adj", window=:last, window_frames=HOLD_FRAMES,
    reduction=:max, boundary="accept")

"The endpoint. No window — the last sample of the trajectory is the endpoint."
const OBS_ENDPOINT = SpinorBEC.ObservableDefinition("endpoint P_adj";
    series="P_adj", window=:all, reduction=:final, boundary="n/a")

"The label `reanalyze` gave this arm: the directory, or `dir/point_00N` if it has several."
function arm_label(ra, dir::AbstractString)
    b = basename(dir)
    haskey(ra.values, b) && return b
    ks = sort!([k for k in keys(ra.values) if startswith(k, b * "/")])
    isempty(ks) ? nothing : first(ks)
end

function main(args)
    root = args[1]
    dirs = sort(filter(d -> isdir(d) && occursin("lt64_ens", basename(d)),
        readdir(root; join=true)))
    isempty(dirs) && error("no lt64_ens run directories under $root")

    # ONE read per arm, both observables off it, one shared vintage.
    m = SpinorBEC.reanalyze(padj_series, dirs;
        observables=[OBS_PEAK, OBS_ENDPOINT],
        declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
    peak_ra, end_ra = m[OBS_PEAK.name], m[OBS_ENDPOINT.name]

    vals = Dict("baseline" => Float64[], "static" => Float64[], "rotating" => Float64[])
    peaks = Dict("baseline" => Float64[], "static" => Float64[], "rotating" => Float64[])
    failures = String[]

    println("\nPER-ARM")
    println("="^78)
    @printf("%-34s %-9s %9s %9s %7s\n", "arm", "group", "peak", "endpoint", "pk_fr")
    println("-"^78)
    for d in dirs
        b = basename(d)
        g = group_of(b)
        label = arm_label(peak_ra, d)
        if label === nothing
            push!(failures, "  $b : no stored point file under this target")
            continue
        end
        pk, ep = peak_ra.values[label], end_ra.values[label]
        if pk === nothing || ep === nothing
            why = get(peak_ra.failures, label, get(end_ra.failures, label,
                "no value (block absent or value withheld)"))
            push!(failures, "  $b : $why")
            continue
        end

        # THE REFERENCE. `arm_values` states the window itself; the two must agree
        # exactly, and a disagreement means one of the definitions is wrong — do
        # not quote either number until they do.
        r = arm_values(d)
        pk_frame = Int(peak_ra.readings[label].argmax)
        if r isa String || r.peak != pk || r.endpoint != ep || r.peak_frame != pk_frame
            push!(failures,
                "  $b : REFERENCE DISAGREES — arm_values=" *
                (r isa String ? r :
                 @sprintf("(peak %.6f, end %.6f, frame %d)", r.peak, r.endpoint,
                    r.peak_frame)) *
                @sprintf(" vs reanalyze=(peak %.6f, end %.6f, frame %d)", pk, ep,
                    pk_frame) *
                ". One of the two window definitions is wrong; this arm is NOT counted.")
            continue
        end

        @printf("%-34s %-9s %9.5f %9.5f %7d\n", b, g, pk, ep, pk_frame)
        haskey(vals, g) || continue
        push!(vals[g], ep)
        push!(peaks[g], pk)
    end

    if !isempty(failures)
        println("\nARMS THAT DID NOT LAND (named, not dropped):")
        foreach(println, failures)
    end

    # The vintage of the arms this verdict stands on, and the machine-readable
    # statement that a re-read has not been through the ancestor gate.
    v = m.vintage
    println("\nVINTAGE OF THE POINTS READ")
    @printf("  %d point(s), %d producing commit(s), %d dirty, %d unstamped\n",
        v.n_points, length(v.commits), v.n_dirty, v.n_unstamped)
    isempty(v.commits) ||
        println("  " * join(("$c×$(v.counts[c])" for c in v.commits), "  "))
    println("  ADMISSIBLE false — " * join(m.inadmissible_because, "; "))
    # The machine-readable form of the same thing, written LAST: an unwritable
    # runs root must not cost the verdict that has already been computed.
    write_record = () -> begin
        rec_path = joinpath(root, "lt64_endpoint_verdict_reanalysis.json")
        try
            open(rec_path, "w") do io
                JSON.print(io, SpinorBEC.reanalysis_record(m), 2)
            end
            println("\nrecord: $rec_path")
        catch err
            @warn "could not write the reanalysis record" path = rec_path exception = err
        end
    end

    nb, ns, nr = length(vals["baseline"]), length(vals["static"]), length(vals["rotating"])
    println("\nGROUPS")
    println("="^78)
    for g in ("baseline", "static", "rotating")
        v = vals[g]
        isempty(v) && continue
        @printf("%-9s n=%d  endpoint mean=%.5f  sd=%.5f   |  peak mean=%.5f  sd=%.5f\n",
            g, length(v), mean(v), length(v) > 1 ? std(v) : NaN,
            mean(peaks[g]), length(peaks[g]) > 1 ? std(peaks[g]) : NaN)
    end

    # ---- the criterion, exactly as committed ---------------------------------
    println("\nVERDICT — criterion fixed before launch, not re-fitted")
    println("="^78)

    if nb < N_MIN || ns < N_MIN
        @printf("NOT APPLICABLE: baseline n=%d, static n=%d, and the sizing needs n>=%d\n",
            nb, ns, N_MIN)
        println("per arm. A cheaper version of this run is not a cheaper answer.")
        println("Ledger row `edh-longtime-endpoint-ordering-unresolved` stays `open`.")
        write_record()
        return
    end

    b, s = vals["baseline"], vals["static"]
    # Pooled sd across the two compared groups, one estimate of the common
    # spread, as the README specifies -- NOT the n=2 pre-run estimate of 0.0658.
    sd_pool = sqrt(((nb - 1) * var(b) + (ns - 1) * var(s)) / (nb + ns - 2))
    se_diff = sd_pool * sqrt(1 / nb + 1 / ns)
    diff = mean(s) - mean(b)
    nsig = abs(diff) / se_diff

    @printf("  mean(static)   = %.5f   (n=%d)\n", mean(s), ns)
    @printf("  mean(baseline) = %.5f   (n=%d)\n", mean(b), nb)
    @printf("  difference     = %+.5f\n", diff)
    @printf("  pooled sd      = %.5f   (pre-run n=2 estimate was 0.0658)\n", sd_pool)
    @printf("  SE_diff        = %.5f\n", se_diff)
    @printf("  |diff| / SE    = %.2f sigma   (threshold %.1f)\n", nsig, K_SIGMA)

    if nsig >= K_SIGMA
        println("\n  ESTABLISHED: the static arm's endpoint differs from baseline.")
        @printf("  Direction: static is %s baseline by %.5f (%+.1f %%).\n",
            diff > 0 ? "ABOVE" : "BELOW", abs(diff), 100 * diff / mean(b))
    else
        println("\n  NOT ESTABLISHED at this n. Row stays `open`.")
        # The n it WOULD need, per the README, rather than a re-fitted threshold.
        n_need = ceil(Int, 2 * (K_SIGMA * sd_pool / abs(diff))^2)
        @printf("  n needed per arm for %.1f sigma at this sd and difference: %d\n",
            K_SIGMA, n_need)
        println("  Do not quote the difference without the SE beside it.")
    end

    # The rotating arm's own scatter -- checked, not assumed (README).
    if nr >= 2
        r = vals["rotating"]
        @printf("\n  rotating: n=%d  mean=%.5f  sd=%.5f  (%.2f %% of mean)\n",
            nr, mean(r), std(r), 100 * std(r) / mean(r))
        println("  The README's n=2 figure was 0.85 %; this is the check, not the assumption.")
    end

    write_record()
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
