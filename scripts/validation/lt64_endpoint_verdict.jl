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
# USE
#   julia --project=. scripts/validation/lt64_endpoint_verdict.jl <runs-root>

using JLD2
using Printf
using Statistics

"Threshold in units of SE_diff, fixed before launch. Do not tune."
const K_SIGMA = 2.0

"Minimum arms per group the sizing calculation requires. Below this: no answer."
const N_MIN = 7

"""
    arm_values(dir; hold_duration, dt, save_every) -> NamedTuple | String

`(peak, endpoint)` P_adj for one run directory, or a String naming the failure.
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

function main(args)
    root = args[1]
    dirs = sort(filter(d -> isdir(d) && occursin("lt64_ens", basename(d)),
        readdir(root; join=true)))
    isempty(dirs) && error("no lt64_ens run directories under $root")

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
        r = arm_values(d)
        if r isa String
            push!(failures, "  $b : $r")
            continue
        end
        @printf("%-34s %-9s %9.5f %9.5f %7d\n", b, g, r.peak, r.endpoint, r.peak_frame)
        haskey(vals, g) || continue
        push!(vals[g], r.endpoint)
        push!(peaks[g], r.peak)
    end

    if !isempty(failures)
        println("\nARMS THAT DID NOT LAND (named, not dropped):")
        foreach(println, failures)
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
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
