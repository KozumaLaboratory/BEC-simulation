# Read a hysteresis loop width out of the ramp trajectories, by CONVERSION DEPTH.
#
# The metric is the acceptance criterion of #335, so state it plainly: a branch
# conversion moves ⟨F⊥⟩ by ≈ 2, while canting along a single branch moves it by
# ≤ 1. The detector is therefore the largest change in ⟨F⊥⟩ across any field
# window of width W along the leg, in the direction the branch change must go —
# an amplitude with the units of the order parameter, not a shape statistic.
#
# What it deliberately is NOT. A sharpness RATIO like peak ÷ median |dF⊥/dB|
# divides by the typical slope, so a nearly flat curve with one small feature
# outscores a real conversion: the κ = 0.8 crossover control scored 10.2 on a
# total span of 0.76 (a small bump at B = 5.7 µG, where the field nearly vanishes
# and the soft manifold dominates), ABOVE the genuine κ = 1.8 conversion's 8.0 on
# a span of 2.92. The ratio is still computed here, on the same curves, and
# printed beside the depth — a claim that the metric was fixed is worth more when
# the discarded metric is shown failing on the same data.
#
# Refuses to report anything until it has passed four controls on synthetic
# curves: a step it MUST see, and three it must NOT (whole-window canting, the
# small-bump ratio trap, pure noise). "I looked and found no conversion" and "I
# could not look" otherwise print the same number, and this project has shipped
# nine scans that could only return the verdict being hoped for.
#
# Usage:
#   julia --project=. scripts/eu_hysteresis/loop_width.jl --selftest
#   julia --project=. scripts/eu_hysteresis/loop_width.jl DIR [DIR...] \
#         [--window=8] [--depth=1.5] [--out=loop_width.csv]
#
# DIR is a ramp output dir holding manifest.csv + <label>.csv (+ <label>_pops.csv).
# Pure CSV post-processing: no SpinorBEC, no GPU.

using DelimitedFiles: readdlm, writedlm
using Printf
using Statistics: median

const DEFAULT_WINDOW = 8.0      # µG — the field scale a conversion must fit in
const DEFAULT_DEPTH = 1.5       # ⟨F⊥⟩ — above canting (≤1), below a conversion (≈2)

struct BlindMetric <: Exception
    msg::String
end
Base.showerror(io::IO, e::BlindMetric) = print(io, "BlindMetric: ", e.msg)

# ------------------------------------------------------------------- the metric

"""
    conversion(B, f; window, expect) -> NamedTuple

Largest change of `f` over any field window of width ≤ `window`, restricted to
the sign `expect` (+1 if the branch change must RAISE ⟨F⊥⟩, −1 if it must lower
it). Returns the depth, the field at which the steepest part of that window sits,
and the plateau levels either side.

`expect` is not decoration. On the falling leg a conversion takes the polarised
branch UP in ⟨F⊥⟩ and on the rising leg it takes the flower branch DOWN; taking
`|Δ|` instead would let a transient dip on the falling leg count as a conversion.
"""
function conversion(B::Vector{Float64}, f::Vector{Float64};
    window::Float64=DEFAULT_WINDOW, expect::Int)
    n = length(B)
    n >= 3 || throw(BlindMetric("trajectory has $n samples; need ≥ 3"))
    best = (depth=0.0, i=1, j=1)
    for i in 1:(n - 1)
        for j in (i + 1):n
            abs(B[j] - B[i]) <= window || break     # B is monotone along a leg
            d = expect * (f[j] - f[i])
            d > best.depth && (best = (depth=d, i=i, j=j))
        end
    end
    i, j = best.i, best.j
    # Steepest sample inside the winning window: the jump field. Reported as the
    # midpoint when the window is a single step.
    B_jump = if j > i + 1
        k = argmax([expect * (f[m + 1] - f[m]) / max(abs(B[m + 1] - B[m]), 1e-12)
                    for m in i:(j - 1)]) + i - 1
        (B[k] + B[k + 1]) / 2
    else
        (B[i] + B[j]) / 2
    end
    # Plateau levels over ±window either side of the winning interval, so an
    # overshoot-and-ring arrival (which the κ=1.8 conversion does: 3.58 with a
    # 3.72 excursion) is not read as extra depth.
    #
    # Sided by INDEX, not by comparing fields against `expect`: `expect` is the
    # sign of Δ⟨F⊥⟩, and using it to pick a side in B conflates the direction the
    # order parameter moves with the direction the ramp travels. The first version
    # did exactly that and returned the post-jump plateau as the pre-jump level on
    # a falling leg — the unit test's plateau assertion is what found it.
    step = median([abs(B[m + 1] - B[m]) for m in 1:(n - 1)])
    w = max(1, round(Int, window / max(step, 1e-12)))
    pre = f[max(1, i - w):i]
    post = f[j:min(n, j + w)]
    (; depth=best.depth, B_jump,
        level_before=isempty(pre) ? f[i] : median(pre),
        level_after=isempty(post) ? f[j] : median(post),
        span=maximum(f) - minimum(f), n=n)
end

"""Sharpness ratio peak ÷ median |df/dB| — the metric this script exists NOT to
use, computed so it can be shown scoring the controls wrongly on the same data."""
function slope_ratio(B::Vector{Float64}, f::Vector{Float64})
    s = [abs(f[i + 1] - f[i]) / max(abs(B[i + 1] - B[i]), 1e-12) for i in 1:(length(B) - 1)]
    m = median(s)
    m <= 0 ? Inf : maximum(s) / m
end

# ------------------------------------------------------------------- calibration

"""Synthetic controls. Returns `(name, B, f, expect, must_detect)`.

Chosen from the failure being guarded against, not for convenience: `canting` and
`bump` are the two shapes that have actually been misread in this project, and
`bump` reproduces the κ = 0.8 control's numbers (span 0.76, one small feature)
that the discarded ratio metric scored above a real conversion."""
function controls(; window::Float64)
    B = collect(range(200.0, 20.0; length=400))          # a falling leg
    out = Tuple{String, Vector{Float64}, Vector{Float64}, Int, Bool}[]

    # POSITIVE: a branch conversion — 2.4 in ⟨F⊥⟩ over ~3 µG at 27 µG, ON TOP OF
    # the canting the real falling leg shows before it converts. The background
    # matters: with a perfectly flat pre-jump the median slope is ~0, the ratio
    # metric scores Inf and would look fine, and the demo below would credit it
    # for a ranking it only gets from an unrealistically clean curve. With the
    # canting in, the span is 2.9 — the measured κ=1.8 conversion's 2.92.
    push!(out, ("step_conversion", B,
        0.8 .+ 0.5 .* (200.0 .- B) ./ 180.0 .+
        2.4 .* (1 .+ tanh.((27.0 .- B) ./ 1.5)) ./ 2, +1, true))

    # NEGATIVE: canting along ONE branch across the whole window. Accumulates
    # 0.9 overall but never inside a window, which is the distinction.
    push!(out, ("canting_whole_window", B,
        0.8 .+ 0.9 .* (200.0 .- B) ./ 180.0, +1, false))

    # NEGATIVE: the ratio trap. Flat-ish curve, span 0.76, one small sharp bump.
    let f = 0.9 .+ 0.5 .* (200.0 .- B) ./ 180.0
        f .+= 0.26 .* exp.(-((B .- 25.7) ./ 0.6) .^ 2)
        push!(out, ("small_bump_ratio_trap", B, f, +1, false))
    end

    # NEGATIVE: noise only. Deterministic, so the control cannot flake.
    push!(out, ("noise_only", B,
        1.2 .+ 0.05 .* sin.(collect(1:400) .* 2.3) .+
        0.03 .* cos.(collect(1:400) .* 7.1), +1, false))

    out
end

"""Run the controls; throw `BlindMetric` naming the failure. A positive control
that cannot fail proves nothing, so the two failure modes are reported
separately: a missed step means the extractor is broken, a fired negative means
the threshold is too loose."""
function calibrate(; window::Float64, depth_min::Float64, verbose::Bool=true)
    bad = String[]
    verbose && println("calibration (window=$(window) µG, depth ≥ $(depth_min)):")
    for (name, B, f, expect, must) in controls(; window)
        c = conversion(B, f; window, expect)
        got = c.depth >= depth_min
        r = slope_ratio(B, f)
        ok = got == must
        ok || push!(bad, must ?
                          "POSITIVE control `$name` was MISSED (depth $(round(c.depth; digits=3)) < $depth_min) — the extractor cannot see a conversion" :
                          "NEGATIVE control `$name` FIRED (depth $(round(c.depth; digits=3)) ≥ $depth_min) — the threshold admits non-conversions")
        verbose && @printf("  %-24s depth=%.3f span=%.3f  ratio=%6.1f  %s → %s\n",
            name, c.depth, c.span, r, must ? "must detect" : "must not",
            ok ? "ok" : "FAIL")
    end
    isempty(bad) || throw(BlindMetric(join(bad, "\n  ")))
    verbose && println("  all controls passed\n")
    true
end

"""The discarded ratio metric, shown ranking the controls wrongly. This is the
evidence for the criterion, not a claim about it."""
function ratio_demo(; window::Float64)
    cs = controls(; window)
    rows = [(name, slope_ratio(B, f), maximum(f) - minimum(f),
        conversion(B, f; window, expect).depth, must)
            for (name, B, f, expect, must) in cs]
    println("the ratio metric on the same curves (why it is not used):")
    for (name, r, span, d, must) in sort(rows; by=x -> -x[2])
        @printf("  %-24s ratio=%7.1f  span=%.3f  depth=%.3f   (%s)\n",
            name, r, span, d, must ? "real conversion" : "not a conversion")
    end
    real_r = only(r for (n, r, s, d, m) in rows if m)
    worst_fake = maximum(r for (n, r, s, d, m) in rows if !m)
    if worst_fake > real_r
        @printf("  ⇒ a non-conversion outranks the real one (%.1f > %.1f). Ratio rejected.\n\n",
            worst_fake, real_r)
    else
        # Not a failure of this script, but the stated justification would no
        # longer hold on these curves and should not be repeated as if it did.
        @printf("  ⇒ on THESE curves the ratio happens to rank correctly (%.1f ≤ %.1f); the depth metric is still what is reported, since the ranking is curve-dependent and the amplitude is not.\n\n",
            worst_fake, real_r)
    end
end

# ------------------------------------------------------------------------ I/O

read_tsv(p) = let d = readdlm(p, '\t'; header=true)
    (d[1], Dict(strip(String(x)) => i for (i, x) in enumerate(vec(d[2]))))
end

"""Manifest rows of one ramp output dir, as NamedTuples keyed by column name."""
function manifest_rows(dir)
    p = joinpath(dir, "manifest.csv")
    isfile(p) || throw(BlindMetric("no manifest.csv in $dir — the ramp did not run, which is not the same as no loop"))
    A, ci = read_tsv(p)
    [(; (Symbol(k) => A[r, i] for (k, i) in ci)...) for r in 1:size(A, 1)]
end

"""Per-leg analysis of every arm in `dir`."""
function analyse_dir(dir; window, depth_min)
    out = NamedTuple[]
    for m in manifest_rows(dir)
        label = String(m.label)
        tp = joinpath(dir, label * ".csv")
        isfile(tp) || throw(BlindMetric("manifest lists $label but $tp is missing"))
        A, ci = read_tsv(tp)
        B = Float64.(A[:, ci["B_uG"]])
        f = Float64.(A[:, ci["fperp"]])
        tag = String(m.tag)
        # rise: the flower branch can only DIE (⟨F⊥⟩ falls). fall: the polarised
        # branch can only convert INTO the flower (⟨F⊥⟩ rises).
        expect = tag == "rise" ? -1 : +1
        c = conversion(B, f; window, expect)
        push!(out, (; dir, kappa=Float64(m.kappa), grid=Int(m.grid), tag, label,
            rate=Float64(m.rate_uG_per_ms), tau_ms=Float64(m.tau_ms),
            pin=Float64(m.pin), B_from=B[1], B_to=B[end],
            depth=c.depth, converted=c.depth >= depth_min, B_jump=c.B_jump,
            level_before=c.level_before, level_after=c.level_after,
            span=c.span, ratio=slope_ratio(B, f),
            norm_drift=Float64(m.norm_drift), Jz_drift=Float64(m.Jz_drift)))
    end
    out
end

"""Pair the legs by (κ, grid, pin, rate) and report the loop width. A leg that did
not convert inside its window makes the width a LOWER BOUND, and which end is
open is named — that is exactly the defect this campaign exists to close, so it
must never be reported as a width."""
function loops(legs; depth_min)
    key(r) = (r.kappa, r.grid, round(r.pin; sigdigits=6), round(r.rate; sigdigits=6))
    ks = unique(key.(legs))
    out = NamedTuple[]
    for k in ks
        arms = filter(r -> key(r) == k, legs)
        ri = findfirst(r -> r.tag == "rise", arms)
        fi = findfirst(r -> r.tag == "fall", arms)
        rise = ri === nothing ? nothing : arms[ri]
        fall = fi === nothing ? nothing : arms[fi]
        both = rise !== nothing && fall !== nothing
        open_ends = String[]
        both || push!(open_ends, rise === nothing ? "rise leg absent" : "fall leg absent")
        both && !rise.converted && push!(open_ends, "rise did not convert below $(rise.B_to) µG")
        both && !fall.converted && push!(open_ends, "fall did not convert above $(fall.B_to) µG")
        width = both && rise.converted && fall.converted ?
                rise.B_jump - fall.B_jump : NaN
        push!(out, (; kappa=k[1], grid=k[2], pin=k[3], rate=k[4],
            tau_ms_rise=rise === nothing ? NaN : rise.tau_ms,
            tau_ms_fall=fall === nothing ? NaN : fall.tau_ms,
            B_jump_rise=rise === nothing ? NaN : rise.B_jump,
            B_jump_fall=fall === nothing ? NaN : fall.B_jump,
            depth_rise=rise === nothing ? NaN : rise.depth,
            depth_fall=fall === nothing ? NaN : fall.depth,
            loop_width=width,
            is_lower_bound=!isempty(open_ends),
            open_ends=join(open_ends, "; ")))
    end
    sort(out; by=r -> (r.kappa, r.grid, -r.rate))
end

"""The verdict from the rate scan, named from the table in #335 rather than read
off one ramp:

    width shrinks toward 0 as the ramp slows   → dynamical lag
    width saturates                            → bistability (spinodal separation)
    no conversion at any rate                  → crossover

Two converged minima with a barrier are bistability and not by themselves a
first-order transition; ferromagnet coercivity is the counter-example."""
function verdict(ls; sat_tol=0.10)
    conv = filter(r -> !r.is_lower_bound, ls)
    if isempty(conv)
        anyconv = any(r -> r.depth_rise >= DEFAULT_DEPTH || r.depth_fall >= DEFAULT_DEPTH, ls)
        return (; verdict=anyconv ? "indeterminate" : "crossover",
            reason=anyconv ?
                   "one leg converts and the other does not at every rate, so no rate yields a width — the open end must be closed before a verdict" :
                   "no leg converted at any rate: no loop, which is what a crossover must show",
            width=NaN, rel_change=NaN)
    end
    length(conv) < 2 && return (; verdict="indeterminate",
        reason="only one rate produced a closed loop; saturation needs at least two",
        width=conv[1].loop_width, rel_change=NaN)
    s = sort(conv; by=r -> r.rate)          # slowest first
    w1, w2 = s[1].loop_width, s[2].loop_width
    rel = abs(w1 - w2) / max(abs(w1), 1e-12)
    if rel <= sat_tol
        (; verdict="bistable", width=w1, rel_change=rel,
            reason=@sprintf("width changes %.1f %% between the two slowest rates (%.3g and %.3g µG/ms) — saturated, so the width is the mean-field spinodal separation",
                100rel, s[1].rate, s[2].rate))
    elseif w1 < w2
        (; verdict="dynamical_lag", width=w1, rel_change=rel,
            reason=@sprintf("width still falling as the ramp slows (%.2f → %.2f µG from %.3g to %.3g µG/ms) — not yet saturated; extrapolate or run slower",
                w2, w1, s[2].rate, s[1].rate))
    else
        (; verdict="indeterminate", width=w1, rel_change=rel,
            reason=@sprintf("width GROWS as the ramp slows (%.2f → %.2f µG) — neither lag nor saturation; suspect the seed or the window",
                w2, w1))
    end
end

# ---------------------------------------------------------------------- driver

function main(args)
    window = DEFAULT_WINDOW
    depth_min = DEFAULT_DEPTH
    outfile = ""
    dirs = String[]
    selftest = false
    for a in args
        if a == "--selftest"
            selftest = true
        elseif startswith(a, "--window=")
            window = parse(Float64, split(a, '=')[2])
        elseif startswith(a, "--depth=")
            depth_min = parse(Float64, split(a, '=')[2])
        elseif startswith(a, "--out=")
            outfile = split(a, '='; limit=2)[2]
        elseif startswith(a, "--")
            error("unknown flag $a")
        else
            push!(dirs, a)
        end
    end

    # Calibration ALWAYS runs, before any data is touched. An uncalibrated pass
    # reports a number that looks exactly like a calibrated one.
    calibrate(; window, depth_min)
    ratio_demo(; window)
    if selftest
        println("SELFTEST OK")
        return 0
    end
    isempty(dirs) && error("give at least one ramp output dir (or --selftest)")

    legs = NamedTuple[]
    for d in dirs
        append!(legs, analyse_dir(d; window, depth_min))
    end
    isempty(legs) && throw(BlindMetric("no arms found in $(join(dirs, ", "))"))

    println("per-leg conversion depth (window=$(window) µG, threshold $(depth_min)):")
    println(rpad("label", 22), rpad("κ", 6), rpad("grid", 6), rpad("rate", 10),
        rpad("τ[ms]", 10), rpad("depth", 9), rpad("B_jump", 9),
        rpad("before→after", 16), rpad("span", 8), rpad("ratio", 8), "conv")
    for r in sort(legs; by=x -> (x.kappa, x.grid, -x.rate, x.tag))
        @printf("%-22s%-6.2f%-6d%-10.4g%-10.1f%-9.3f%-9.2f%-16s%-8.3f%-8.1f%s\n",
            r.label, r.kappa, r.grid, r.rate, r.tau_ms, r.depth,
            r.converted ? r.B_jump : NaN,
            @sprintf("%.2f→%.2f", r.level_before, r.level_after),
            r.span, r.ratio, r.converted ? "YES" : "no")
    end

    ls = loops(legs; depth_min)
    println("\nloop width per (κ, grid, pin, rate):")
    for r in ls
        @printf("  κ=%.2f g=%d pin=%.4g rate=%-8.4g  rise@%-8.2f fall@%-8.2f  width=%-8s %s\n",
            r.kappa, r.grid, r.pin, r.rate, r.B_jump_rise, r.B_jump_fall,
            isnan(r.loop_width) ? "—" : @sprintf("%.2f µG", r.loop_width),
            r.is_lower_bound ? "LOWER BOUND ONLY: " * r.open_ends : "")
    end

    println("\nverdict per (κ, grid, pin):")
    for k in unique([(r.kappa, r.grid, r.pin) for r in ls])
        sub = filter(r -> (r.kappa, r.grid, r.pin) == k, ls)
        v = verdict(sub)
        @printf("  κ=%.2f g=%d pin=%.4g → %s\n", k[1], k[2], k[3], uppercase(v.verdict))
        println("      ", v.reason)
        isnan(v.width) || @printf("      loop width at the slowest rate: %.2f µG\n", v.width)
    end

    if !isempty(outfile)
        ks = collect(keys(ls[1]))
        open(outfile, "w") do io
            writedlm(io, reshape(String.(ks), 1, :))
            for r in ls
                writedlm(io, reshape(Any[getfield(r, k) for k in ks], 1, :))
            end
        end
        println("\nwrote $outfile")
    end
    0
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    exit(main(ARGS))
end
