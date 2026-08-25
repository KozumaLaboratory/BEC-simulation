#!/usr/bin/env julia
# Re-analyse the saved Klaus-2022 column-density frames without re-running the
# dynamics.
#
#     julia --project=. -t 10 scripts/klaus2022_reanalyse.jl
#
# Why this exists: the first stripe metric had to be replaced (a binned
# max/mean that read 6.8 on white noise) and that cost a 45-minute re-run,
# because only the reduced numbers had been kept. The runs now persist their
# frames to `runs/klaus2022/*_frames.jld2`, so a metric or window change costs
# seconds. Any number this script writes is labelled with the window it used.
#
# The specific fix it applies: the θ→0 control's pre-registered window was "the
# last 20 % of the run", which for a 600 ms hold plus a 100 ms spiral still
# contains 40 ms **at the full 35° tilt**. That window does not implement the
# control §6 of `klaus2022_primary_source.md` declares ("repeating with the
# field spiralled to θ = 0° must turn the peak pair into a ring"), so it is
# re-derived here on the frames where θ has actually reached 0. Both numbers
# are reported; the pre-registered one is not deleted.
#
# MIGRATED TO `reanalyze` (#483, 2026-08-26). Seven quantities per window come
# off ONE pass over the frames, and each frame costs an FFT — which is why the
# entry point grew `observables = [...]` instead of this driver staying bespoke.
# What the migration buys here:
#
#   * the two windows are `ObservableDefinition`s with `:predicate` windows —
#     "the frames where θ has reached 0" is a physical condition no frame count
#     expresses, and it is now declared rather than filtered inline;
#   * the frames files carry no `env/git_hash`, so the vintage comes back
#     `unstamped` and the record says so. That is the honest answer: these
#     numbers stand on a run whose producing commit is not recorded in the file;
#   * `summarise` is KEPT and differenced against `reanalyze` on every run. It
#     reduces the same extracted frames, so it gates the window and the
#     reduction — what drifts — and not the extraction, which is shared.

using FFTW
using JLD2
using JSON
using Printf

FFTW.set_num_threads(Threads.nthreads())
using SpinorBEC

const ROOT = normpath(joinpath(@__DIR__, ".."))
const RESULTS = joinpath(ROOT, "docs", "validation", "klaus2022_results.json")
const FRAMES = joinpath(ROOT, "runs", "klaus2022")

# Same protocols the run used (`scripts/klaus2022_reproduce.jl`).
const SECOND = 2π * 50.0
const THETA35 = deg2rad(35)
protocol(arm) = arm == "control" ?
                SpinorBEC.StirProtocol(Dict("theta" => THETA35, "omega" => 0.75,
    "theta_final" => 0.0,
    "theta_ramp_start" => 0.6 * SECOND,
    "theta_ramp_time" => 0.1 * SECOND)) :
                SpinorBEC.StirProtocol(Dict("theta" => THETA35, "omega" => 0.75))

"Per-frame stripe metrics of one saved frames file. The expensive half: an FFT per frame."
function frame_metrics(path::AbstractString, arm, k_lo, k_hi)
    isfile(path) || return "no frames at $path — run scripts/klaus2022_reproduce.jl $arm"
    d = load(path)
    times, cols, dx, dy = d["times"], d["column_density"], d["dx"], d["dy"]
    stir = protocol(arm)
    out = NamedTuple[]
    for (t, col) in zip(times, cols)
        maximum(col) > 0 || continue
        r, _ = residual_image(col; sigma_px=4.0)
        kx, ky, mag = stripe_spectrum(r, dx, dy)
        m = stripe_metrics(kx, ky, mag; k_lo=k_lo, k_hi=k_hi)
        φ = SpinorBEC.stir_phi(stir, t)
        θ = SpinorBEC.stir_theta(stir, t)
        mis = mod(m.angle - (φ + π / 2), π)
        mis > π / 2 && (mis -= π)
        push!(out, (t=t, theta=θ, axis_order=m.axis_order,
            null=m.axis_order_null, prom=m.radial_prominence,
            k_mode=m.k_mode, misalign=mis))
    end
    isempty(out) && return "every frame is empty (max column density 0)"
    out
end

"""
The named series `reanalyze` reduces, plus the `aux` its `:predicate` windows
read. `misalign` is carried SQUARED: an rms is `sqrt` of the mean of the squares,
so it composes out of `:mean` and does not need a reduction of its own.
"""
function frames_payload(frames::Vector{<:NamedTuple})
    t = [f.t for f in frames]
    Dict{String, Any}(
        "axis_order" => [f.axis_order for f in frames],
        "null" => [f.null for f in frames],
        "prom" => [f.prom for f in frames],
        "k_mode" => [f.k_mode for f in frames],
        "misalign_sq" => [f.misalign^2 for f in frames],
        "t" => t,
    ), (t=t, theta=[f.theta for f in frames], t_end=maximum(t))
end

"The pre-registered window: the last 20 % of the run."
last_20pct(i, aux) = aux.t[i] >= 0.8 * aux.t_end

"The window §6 declares for the control: the frames where θ has actually reached 0."
theta_reached_zero(i, aux) = aux.theta[i] < deg2rad(5)

"""
    window_observables(tag, predicate) -> Vector{ObservableDefinition}

The seven quantities the verdict reads, over one window, declared before any of
them exists. `boundary` is `n/a` throughout: every one is a mean or an endpoint
of the window, and a mean has no argmax to truncate.
"""
function window_observables(tag::AbstractString, predicate)
    mk(name, series, reduction) = SpinorBEC.ObservableDefinition("$name ($tag)";
        series=series, window=:predicate, window_predicate=predicate,
        reduction=reduction, boundary="n/a")
    [
        mk("axis_order", "axis_order", :mean),
        mk("axis_order_null", "null", :mean),
        mk("radial_prominence", "prom", :mean),
        mk("k_mode", "k_mode", :mean),
        mk("misalign squared", "misalign_sq", :mean),
        mk("t at window start", "t", :first),
        mk("t at window end", "t", :final),
    ]
end

"The t = 0 reference the ratios are taken against: elongated, vortex-free."
const OBS_BASELINE = SpinorBEC.ObservableDefinition("baseline axis_order";
    series="axis_order", window=:all, reduction=:first, boundary="n/a")

"""
    summarise(fr, baseline, D) -> NamedTuple

THE REFERENCE, KEPT AND DIFFERENCED. The reduction this script performed inline,
re-stated here and compared against `reanalyze` on every run, over the same
extracted frames. It gates the window and the reduction; it cannot see an error
in `frame_metrics`, which both sides share.
"""
function summarise(fr, baseline, D)
    isempty(fr) && return nothing
    n = length(fr)
    mean_of(f) = sum(f, fr) / n
    (
        n_frames=n,
        t_range=(first(fr).t, last(fr).t),
        axis_order=mean_of(f -> f.axis_order),
        over_null=mean_of(f -> f.axis_order) / mean_of(f -> f.null),
        over_baseline=mean_of(f -> f.axis_order) / baseline,
        radial_prominence=mean_of(f -> f.prom),
        misalign_deg=rad2deg(sqrt(sum(f -> f.misalign^2, fr) / n)),
        n_stripes=mean_of(f -> f.k_mode) * D / 2π,
    )
end

"The same summary, assembled out of a `MultiReanalysis` instead of inline."
function summarise_from(m, label, tag, baseline, D)
    v(name) = m["$name ($tag)"].values[label]
    ao = v("axis_order")
    ao === nothing && return nothing
    (
        n_frames=m["axis_order ($tag)"].readings[label].n,
        t_range=(v("t at window start"), v("t at window end")),
        axis_order=ao,
        over_null=ao / v("axis_order_null"),
        over_baseline=ao / baseline,
        radial_prominence=v("radial_prominence"),
        misalign_deg=rad2deg(sqrt(v("misalign squared"))),
        n_stripes=v("k_mode") * D / 2π,
    )
end

# Floating-point summation order is not part of an observable's definition, and
# the two sides sum the same values in the same order over different container
# types. A window or reduction that has actually drifted moves these numbers by
# orders of magnitude more than this.
const REF_RTOL = 1e-12

function reference_disagreement(ref, got)
    ref === nothing && got === nothing && return nothing
    (ref === nothing) != (got === nothing) &&
        return "one side produced no summary (ref=$(ref === nothing ? "none" : "some"))"
    ref.n_frames == got.n_frames ||
        return "n_frames $(ref.n_frames) vs $(got.n_frames)"
    for k in (:axis_order, :over_null, :over_baseline, :radial_prominence,
        :misalign_deg, :n_stripes)
        isapprox(getproperty(ref, k), getproperty(got, k); rtol=REF_RTOL) ||
            return "$k $(getproperty(ref, k)) vs $(getproperty(got, k))"
    end
    all(isapprox.(ref.t_range, got.t_range; rtol=REF_RTOL)) ||
        return "t_range $(ref.t_range) vs $(got.t_range)"
    nothing
end

"""
    main(; results = RESULTS, frames = FRAMES)

Re-reduce every arm and write the report back into `results`.

The two paths are arguments rather than constants so the whole path — read,
reduce, difference against the reference, write — can be exercised on a fixture.
A driver whose `main` cannot be run is a driver whose gate stops one call short
of the thing that actually writes the numbers.
"""
function main(; results::AbstractString=RESULTS, frames::AbstractString=FRAMES)
    res = JSON.parsefile(results)
    report = Dict{String, Any}()
    records = Dict{String, Any}()

    for arm in ("stripes", "control")
        haskey(res, arm) || continue
        path = joinpath(frames, "$(arm)_frames.jld2")
        D = Float64(res[arm]["cloud_diameter_aho"])
        k_lo = Float64(res[arm]["k_lo"])
        k_hi = Float64(res[arm]["k_hi"])

        # ONE pass over the frames — the FFTs happen here and nowhere else. The
        # per-frame metrics are cached so the reference reduction below re-reduces
        # the same numbers rather than paying for them twice.
        cache = Dict{String, Any}()
        extract = function (p)
            fr = frame_metrics(p, arm, k_lo, k_hi)
            fr isa AbstractString && return fr
            cache[p] = fr
            frames_payload(fr)
        end

        declared = arm == "control" ? theta_reached_zero : last_20pct
        obs = vcat(window_observables("pre-registered", last_20pct),
            window_observables("declared", declared),
            [OBS_BASELINE])
        m = SpinorBEC.reanalyze(extract, [path];
            observables=obs, declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
        records[arm] = SpinorBEC.reanalysis_record(m)

        label = basename(path)
        if !haskey(m.paths, label)
            @printf("\n=== %s === could not be read: %s\n", arm,
                get(m[OBS_BASELINE.name].failures, label, "unknown"))
            continue
        end
        baseline = m[OBS_BASELINE.name].values[label]
        pre = summarise_from(m, label, "pre-registered", baseline, D)
        fix = summarise_from(m, label, "declared", baseline, D)

        # THE REFERENCE. Same frames, window and reduction re-stated inline.
        fr = cache[m.paths[label]]
        t_end = maximum(f -> f.t, fr)
        aux = (t=[f.t for f in fr], theta=[f.theta for f in fr], t_end=t_end)
        ref_pre = summarise(
            [f for (i, f) in enumerate(fr) if last_20pct(i, aux)], baseline, D)
        ref_fix = summarise(
            [f for (i, f) in enumerate(fr) if declared(i, aux)], baseline, D)
        for (tag, r, g) in (("pre-registered", ref_pre, pre), ("declared", ref_fix, fix))
            why = reference_disagreement(r, g)
            why === nothing && continue
            error("$arm / $tag: REFERENCE DISAGREES — $why. One of the two " *
                  "statements of this window is wrong; nothing is written.")
        end

        report[arm] = Dict(
            "baseline_axis_order" => baseline,
            "pre_registered_window" => pre === nothing ? nothing : Dict(pairs(pre)),
            "declared_window" => fix === nothing ? nothing : Dict(pairs(fix)),
            "reanalysis" => records[arm],
        )
        @printf("\n=== %s ===\n", arm)
        for (lab, s) in (("pre-registered window", pre), ("declared window", fix))
            s === nothing && continue
            @printf("  %-22s t=[%.1f, %.1f]  n=%3d  axis_order=%.4f  ×null=%.2f  ×baseline=%.2f  prom=%.2f  misalign=%.1f°  stripes=%.2f\n",
                lab, s.t_range[1], s.t_range[2], s.n_frames, s.axis_order,
                s.over_null, s.over_baseline, s.radial_prominence,
                s.misalign_deg, s.n_stripes)
        end
        v = m.vintage
        @printf("  vintage: %d file(s), %d producing commit(s), %d unstamped — ADMISSIBLE false\n",
            v.n_points, length(v.commits), v.n_unstamped)
    end

    res["reanalysis"] = report
    res["reanalysis"]["note"] =
        "Recomputed from runs/klaus2022/*_frames.jld2 through `reanalyze` " *
        "(#483): the window, the reduction and the vintage of the files read are " *
        "carried per arm under `reanalysis`, and `admissible` is false — a " *
        "re-read of stored output has not been through the ancestor gate. " *
        "`declared_window` restricts the θ→0 control to frames where θ has " *
        "reached 0; the pre-registered \"last 20 %\" window still contained 40 ms " *
        "at the full 35° tilt. Both are reported; neither replaces the other."
    open(results, "w") do f
        JSON.print(f, res, 2)
    end
    println("\nwritten to ", results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
