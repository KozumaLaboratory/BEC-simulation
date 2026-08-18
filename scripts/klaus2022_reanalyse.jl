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

function metrics_for(arm, res)
    path = joinpath(FRAMES, "$(arm)_frames.jld2")
    isfile(path) || error("no frames at $path — run scripts/klaus2022_reproduce.jl $arm")
    d = load(path)
    times, cols, dx, dy = d["times"], d["column_density"], d["dx"], d["dy"]
    stir = protocol(arm)
    k_lo = Float64(res[arm]["k_lo"]);
    k_hi = Float64(res[arm]["k_hi"])
    D = Float64(res[arm]["cloud_diameter_aho"])
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
    (frames=out, D=D)
end

"Reduce a set of frames to the summary the verdict reads."
function summarise(fr, baseline, D)
    isempty(fr) && return nothing
    n = length(fr)
    mean(f) = sum(f, fr) / n
    (
        n_frames=n,
        t_range=(first(fr).t, last(fr).t),
        axis_order=mean(f -> f.axis_order),
        over_null=mean(f -> f.axis_order) / mean(f -> f.null),
        over_baseline=mean(f -> f.axis_order) / baseline,
        radial_prominence=mean(f -> f.prom),
        misalign_deg=rad2deg(sqrt(sum(f -> f.misalign^2, fr) / n)),
        n_stripes=mean(f -> f.k_mode) * D / 2π,
    )
end

res = JSON.parsefile(RESULTS)
report = Dict{String, Any}()

for arm in ("stripes", "control")
    haskey(res, arm) || continue
    m = metrics_for(arm, res)
    fr = m.frames
    baseline = first(fr).axis_order          # t = 0: elongated, vortex-free
    t_end = maximum(f -> f.t, fr)

    # The pre-registered window, recomputed here as a cross-check that this
    # script reproduces the run's own reduction.
    pre = summarise(filter(f -> f.t >= 0.8 * t_end, fr), baseline, m.D)
    # The window that implements what §6 declares.
    win = arm == "control" ?
          filter(f -> f.theta < deg2rad(5), fr) :
          filter(f -> f.t >= 0.8 * t_end, fr)
    fix = summarise(win, baseline, m.D)

    report[arm] = Dict(
        "baseline_axis_order" => baseline,
        "pre_registered_window" => pre === nothing ? nothing : Dict(pairs(pre)),
        "declared_window" => fix === nothing ? nothing : Dict(pairs(fix)),
    )
    @printf("\n=== %s ===\n", arm)
    for (label, s) in (("pre-registered window", pre), ("declared window", fix))
        s === nothing && continue
        @printf("  %-22s t=[%.1f, %.1f]  n=%3d  axis_order=%.4f  ×null=%.2f  ×baseline=%.2f  prom=%.2f  misalign=%.1f°  stripes=%.2f\n",
            label, s.t_range[1], s.t_range[2], s.n_frames, s.axis_order,
            s.over_null, s.over_baseline, s.radial_prominence,
            s.misalign_deg, s.n_stripes)
    end
end

res["reanalysis"] = report
res["reanalysis"]["note"] =
    "Recomputed from runs/klaus2022/*_frames.jld2. `declared_window` restricts " *
    "the θ→0 control to frames where θ has reached 0; the pre-registered " *
    "\"last 20 %\" window still contained 40 ms at the full 35° tilt. Both are " *
    "reported; neither replaces the other."
open(RESULTS, "w") do f
    JSON.print(f, res, 2)
end
println("\nwritten to ", RESULTS)
