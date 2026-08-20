#!/usr/bin/env julia
# Klaus et al. 2022 (Nat. Phys. 18, 1453; arXiv:2206.12265) — type-C
# reproduction on the scalar eGPE path.
#
#   julia --project=. -t 10 scripts/klaus2022_reproduce.jl <arm> [--smoke]
#
#   arms:  ar-ramp    Fig. 1c — Ω_c from the aspect-ratio ramp
#          stripes    Fig. 4b — vortex stripes at Ω = 0.75 ω_⊥, θ = 35°
#          control    Fig. 4d — the SAME run spiralled to θ = 0°, which must
#                     turn the stripe peak into a ring. Without it the stripe
#                     signal has no negative control and proves nothing.
#
# The published parameters are in `docs/validation/klaus2022_primary_source.md`
# §1 (quoted from the paper, per figure). The accept/reject thresholds below
# are §6 of that document, written before the first launch; they are constants
# here because a criterion chosen after seeing the answer is not a criterion.
# `test/validation/test_klaus2022_vortex_stripes.jl` reads the JSON this
# writes and re-applies them.

using FFTW
using JSON
using JLD2
using Printf
using Dates

# `KLAUS_FFTW_THREADS` exists because job 8444494 SEGFAULTED on TSUBAME inside
# FFTW's threaded spawn loop (`FFTW/.../providers.jl:49` → `spawn_apply` →
# `n1bv_12`), on the dynamics step, after the ground state completed cleanly.
# The same commit, the same FFTW artifact (`8655261c…`) and the same Julia
# 1.12.6 run to completion locally at `-t 16` in 159 s, so the binary is not the
# variable and a local repro is not available to bisect against.
#
# This is a DIAGNOSTIC knob, not a fix, and its default is exactly the previous
# behaviour: unset ⇒ `Threads.nthreads()`. It exists so that one queue wait can
# discriminate FFTW-internal threading from Julia threading instead of three,
# which at a 2.5 h queue depth is the difference between answering this today
# and guessing. Passing an env var the script does not read is silent — that
# already cost a job on this campaign — so it is read here and echoed below.
const _FFTW_THREADS = let v = get(ENV, "KLAUS_FFTW_THREADS", "")
    isempty(v) ? Threads.nthreads() : parse(Int, v)
end
FFTW.set_num_threads(_FFTW_THREADS)
@info "FFTW threads" fftw=_FFTW_THREADS julia=Threads.nthreads()
using SpinorBEC

const ROOT = normpath(joinpath(@__DIR__, ".."))

# Every knob a cluster ensemble needs, and NOTHING that changes what a default
# invocation does: each default is the value the committed
# `klaus2022_results.json` was produced with, so re-running bare reproduces the
# same record rather than a differently-parameterised one.
#
# `KLAUS_RESULTS` exists because concurrent jobs must not share an output file.
# Three seeds writing one JSON is a read-modify-write race that would silently
# keep whichever finished last.
const RESULTS = get(ENV, "KLAUS_RESULTS",
    joinpath(ROOT, "docs", "validation", "klaus2022_results.json"))
const WIGNER_SEED = parse(Int, get(ENV, "KLAUS_SEED", "20260818"))
const RESULT_TAG = get(ENV, "KLAUS_TAG", "")
# Hold time in SECONDS of laboratory time. The paper reads its stripe structure
# over 700 ms - 1.1 s (Fig. 4c, 115 frames in the rotating frame); the committed
# 500 ms run under-ran that window, which is §6d's account of why the stripe arm
# reached 4.67x its null against a pre-registered 5x.
const HOLD_S = parse(Float64, get(ENV, "KLAUS_HOLD_S", "0.5"))
const CONTROL_HOLD_S = parse(Float64, get(ENV, "KLAUS_CONTROL_HOLD_S", "0.6"))

# --- Published values and the pre-registered verdict thresholds (§6) ---

# The published numbers come from `refs/klaus2022.toml` via `ref`, NOT from
# literals here. They were literals here until 2026-08-19, which is exactly the
# hand-typed authority `refs/` exists to prevent: a number retyped into a script
# has no locus, no schema and nothing that refuses it.
#
# Note what `ref` will NOT let this script do: every Klaus row is `read_off`
# (they ship no re-measurable record), so `arbitrates` is false for all of them
# and `Claim(:C, target=…)` is unconstructible. The comparison below is
# therefore a documented reproduction, not a type-C claim — and the registry is
# what makes that distinction checkable instead of a matter of wording.
const PUBLISHED = (
    omega_c_over_perp=ref(:klaus2022, :omega_c_over_omega_perp).value,
    ar_magnetostricted=ref(:klaus2022, :ar_magnetostricted).value,
    n_stripes=ref(:klaus2022, :n_vortex_stripes).value,
)

const ACCEPT = (
    omega_c_lo=0.68, omega_c_hi=0.86,   # 0.74 ± the paper's own theory/exp gap
    ar_peak_min=1.3,                    # below this there is no instability
    ar_collapse_max=1.1,
    ar_static_lo=1.02, ar_static_hi=1.04,
    # Stripe thresholds, re-registered 2026-08-18 after the first metric was
    # found defective by a SYNTHETIC control, not by a production number: the
    # binned `max(S)/mean(S)` read 6.8 on white noise, because a few-hundred-
    # point annulus over 180 angular bins leaves ~2 counts per bin. The
    # replacement is the unbinned axis order parameter |Σ w e^{2iφ}|/Σ w, whose
    # null is 1/√N. The numbers below come from the synthetic fixtures in
    # `test/analysis/test_vortex_stripes.jl` (stripes 6.75× null, scattered
    # 3.06×), not from any Klaus run.
    axis_order_over_null_min=5.0,       # a real axis, not shot noise
    axis_order_over_baseline_min=1.6,   # …and more than the vortex-free cloud
    stripe_axis_tol_deg=20.0,           # alignment with B̂'s in-plane projection
    radial_prominence_min=1.5,          # a peak in |k|, not a flat annulus
    n_stripes_lo=2, n_stripes_hi=4,     # 3 ± 1
    control_axis_order_ratio_max=0.6,   # θ→0 must lose the axis
    norm_drift_max=1e-6,
)

const THETA35 = deg2rad(35)
const OMEGA_REF = 2π * 50.0
# Ω̇ = 2π×50 Hz/s in units of ω_ref²; reaches Ω = ω_⊥ in exactly 1 s.
const RAMP_RATE = 1 / (2π * 50.0)
const SECOND = OMEGA_REF          # 1 s in units of 1/ω_ref

smoke = "--smoke" in ARGS
arm = isempty(ARGS) ? "" : first(ARGS)

grid_block(smoke) = smoke ? Dict("n" => [48, 48, 24], "box" => [16.0, 16.0, 8.0]) :
                    Dict("n" => [128, 128, 64], "box" => [16.0, 16.0, 8.0])

function gs_step(; N, a_s, smoke)
    Dict("ground_state" => Dict(
        "kind" => "scalar_egpe", "atom" => "Dy162", "a_s" => a_s,
        "grid" => grid_block(smoke),
        "interactions" => Dict("N_atoms" => N, "omega_ref" => OMEGA_REF),
        "ddi" => Dict("enabled" => true),
        "lhy" => Dict("kind" => "scalar"),
        "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 2.6]),
        "B_direction" => Dict("theta" => THETA35),
        "B_magnitude_gauss" => 5.333,
        "dt" => 0.004, "n_steps" => smoke ? 1500 : 8000,
    ))
end

"Run one arm and hand back `(results, elapsed_seconds)`.

Goes through `_normalize_and_validate!` rather than constructing a
`PipelineConfig` directly, so these runs are checked by the same strict schema
as any YAML on disk. Bypassing it would let a typo'd key sit inert for the
whole 1.5 h — which is the failure the strict mode exists for."
function run_arm(steps)
    data = Dict{Any, Any}("pipeline" => steps)
    SpinorBEC._normalize_and_validate!(data; strict=true)
    cfg = SpinorBEC.parse_pipeline(data)
    t0 = time()
    res = run_config(cfg; verbose=true)
    (res, time() - t0)
end

# --- Arm A: Ω_c from the aspect-ratio ramp (Fig. 1c) ---

function arm_ar_ramp(smoke)
    dur = smoke ? 0.25 * SECOND : 1.02 * SECOND
    steps = [
        gs_step(; N=15000, a_s=110, smoke=smoke),
        Dict("dynamics" => Dict(
            "kind" => "scalar_egpe", "duration" => dur, "dt" => 0.002,
            "B_direction" => Dict("theta" => THETA35, "omega" => 1.0,
                "ramp_rate" => RAMP_RATE),
            "wigner_seed" => Dict("kT" => 8.33, "seed" => WIGNER_SEED),
            "save" => Dict("every" => 100))),
    ]
    res, secs = run_arm(steps)
    d = res[:scalar_egpe_dynamics]
    gs = res[:scalar_gs]

    ar = d.aspect_ratio;
    Ω = d.omega
    i_peak = argmax(ar)
    ar_peak = ar[i_peak]
    # Ω_c: the first Ω after the peak at which AR has collapsed below the
    # threshold. Declared this way in §6 — "the AR maximum followed by collapse".
    i_c = findfirst(i -> ar[i] < ACCEPT.ar_collapse_max, i_peak:length(ar))
    omega_c = i_c === nothing ? NaN : Ω[i_peak+i_c-1]

    verdict = if !isfinite(omega_c) || ar_peak < ACCEPT.ar_peak_min
        "REJECT_MODEL"
    elseif ACCEPT.omega_c_lo <= omega_c <= ACCEPT.omega_c_hi
        "ACCEPT"
    else
        "REJECT"
    end
    Dict(
        "arm" => "ar-ramp", "smoke" => smoke, "verdict" => verdict,
        "duration_s" => dur / SECOND,
        "omega_c_over_perp" => omega_c, "ar_peak" => ar_peak,
        "ar_at_peak_omega" => Ω[i_peak],
        "ar_static_magnetostricted" => gs.aspect_ratio_xy,
        "ar_static_verdict" =>
            (ACCEPT.ar_static_lo <= gs.aspect_ratio_xy <= ACCEPT.ar_static_hi) ?
            "PASS" : "FAIL",
        "mu" => gs.mu,
        "norm_drift" => abs(d.norms[end] - d.norms[1]) / d.norms[1],
        "times" => d.times, "omega" => Ω, "aspect_ratio" => ar, "Lz" => d.Lz,
        "seconds" => secs,
    )
end

# --- Arms B/C: vortex stripes, and the θ→0 control (Fig. 4b / 4d) ---

"Per-frame stripe metrics, each frame taken on its own.

Klaus average the FT over frames *after* rotating them into a common B̂
direction. Averaging |FT| over LAB-frame frames would smear the peak into a
ring — the exact signature of the negative control — so the co-rotation is not
cosmetic. Doing it per frame and asking whether the axis TRACKS B̂ is the same
statement without the rotation step, and it is the stronger one: it measures
the alignment rather than assuming it."
function stripe_frames(cols, times, stir, dx, dy; k_lo, k_hi, sigma_px)
    out = NamedTuple[]
    for (t, col) in zip(times, cols)
        maximum(col) > 0 || continue
        res, _ = residual_image(col; sigma_px=sigma_px)
        kx, ky, mag = stripe_spectrum(res, dx, dy)
        m = stripe_metrics(kx, ky, mag; k_lo=k_lo, k_hi=k_hi)
        φ = SpinorBEC.stir_phi(stir, t)
        θ = SpinorBEC.stir_theta(stir, t)
        # B̂'s in-plane projection points along φ. A stripe *pattern* aligned
        # with the field is modulated ACROSS it, so the wavevector axis is
        # φ + π/2; `misalign` is the residual after removing that.
        misalign = mod(m.angle - (φ + π / 2), π)
        misalign > π / 2 && (misalign -= π)
        push!(out, (t=t, phi=φ, theta=θ, angle=m.angle, misalign=misalign,
            axis_order=m.axis_order, axis_order_null=m.axis_order_null,
            k_peak=m.k_peak, k_mode=m.k_mode,
            radial_prominence=m.radial_prominence))
    end
    out
end

function arm_stripes(smoke; control::Bool)
    hold = smoke ? 0.15 * SECOND :
           (control ? CONTROL_HOLD_S * SECOND : HOLD_S * SECOND)
    dyn = Dict(
        "kind" => "scalar_egpe", "dt" => 0.002,
        "wigner_seed" => Dict("kT" => 8.33, "seed" => WIGNER_SEED),
        "save" => Dict("every" => smoke ? 100 : 500, "column_density" => true),
    )
    bdir = Dict("theta" => THETA35, "omega" => 0.75)
    if control
        # Fig. 4d: after the hold, spiral θ → 0 over 100 ms while still rotating.
        spiral = smoke ? 0.05 * SECOND : 0.1 * SECOND
        dyn["duration"] = hold + spiral
        bdir["theta_final"] = 0.0
        bdir["theta_ramp_start"] = hold
        bdir["theta_ramp_time"] = spiral
    else
        dyn["duration"] = hold
    end
    dyn["B_direction"] = bdir

    steps = [gs_step(; N=10000, a_s=109, smoke=smoke), Dict("dynamics" => dyn)]
    res, secs = run_arm(steps)
    d = res[:scalar_egpe_dynamics]
    stir = res[:scalar_stir]
    grid = res[:grid]

    # Cloud diameter from the GROUND STATE — fixed before the dynamics being
    # judged, so neither the annulus nor the stripe-count conversion can be
    # chosen from the spectrum they are applied to. For a Thomas-Fermi profile
    # the rms half-width is R/√7, so D = 2R = 2√7·σ.
    D = 2 * sqrt(7) * res[:scalar_gs].sigma_max
    k_lo = 2π / D * 1.2      # above the envelope: ≥ 1.2 modulations across D
    k_hi = 2π / D * 6.0      # below the noise floor: ≤ 6 modulations across D
    frames = stripe_frames(d.column_density, d.times, stir,
        grid.dx[1], grid.dx[2]; k_lo=k_lo, k_hi=k_hi, sigma_px=smoke ? 2.0 : 4.0)

    # IN-RUN NEGATIVE CONTROL. Frame 1 is t = 0: the magnetostricted ground
    # state plus the Wigner seed — elongated along B̂, and vortex-free. Its
    # residual therefore carries the cloud's own envelope anisotropy, which is
    # aligned with B̂ exactly like a stripe pattern would be. Judging the late
    # frames against THIS rather than against zero is what separates "the
    # vortices are arranged in stripes" from "the cloud is an ellipse".
    baseline = first(frames)

    # Judge the last 20 % of the hold, where the paper reads its stripes.
    late = filter(f -> f.t >= 0.8 * maximum(d.times), frames)
    mean_of(f) = isempty(late) ? NaN : sum(f, late) / length(late)
    order = mean_of(f -> f.axis_order)
    null = mean_of(f -> f.axis_order_null)
    prom = mean_of(f -> f.radial_prominence)
    mis = isempty(late) ? NaN :
          rad2deg(sqrt(sum(f -> f.misalign^2, late) / length(late)))
    kbar = mean_of(f -> f.k_mode)
    n_stripes = kbar * D / 2π
    over_null = order / null
    over_base = order / baseline.axis_order

    verdict = if control
        over_base <= ACCEPT.control_axis_order_ratio_max ? "ACCEPT" : "REJECT"
    else
        (over_null >= ACCEPT.axis_order_over_null_min &&
         over_base >= ACCEPT.axis_order_over_baseline_min &&
         prom >= ACCEPT.radial_prominence_min &&
         mis <= ACCEPT.stripe_axis_tol_deg &&
         ACCEPT.n_stripes_lo <= n_stripes <= ACCEPT.n_stripes_hi) ? "ACCEPT" : "REJECT"
    end
    Dict(
        "arm" => control ? "control" : "stripes", "smoke" => smoke,
        # The hold ACTUALLY PROPAGATED, not the knob it was read from. Until
        # 2026-08-19 this was written once more at the bottom of the file as
        # `out["hold_s"] = ... HOLD_S`, i.e. the env default — so every `--smoke`
        # record claimed 1.1 s while the run was 0.15 s. One quantity, two
        # declarations, and only one of them knew about `smoke`. Recorded here
        # because this is where the value is decided.
        "hold_s" => hold / SECOND,
        "duration_s" => dyn["duration"] / SECOND,
        "verdict" => verdict,
        "axis_order" => order, "axis_order_null" => null,
        "axis_order_over_null" => over_null,
        "axis_order_baseline" => baseline.axis_order,
        "axis_order_over_baseline" => over_base,
        "radial_prominence" => prom,
        "radial_prominence_baseline" => baseline.radial_prominence,
        "stripe_misalign_deg" => mis,
        "k_mode" => kbar, "n_stripes" => n_stripes,
        "cloud_diameter_aho" => D, "k_lo" => k_lo, "k_hi" => k_hi,
        "n_frames_judged" => length(late), "n_frames" => length(frames),
        "wigner_seed_fraction" => d.wigner_seed === nothing ? nothing : d.wigner_seed[2],
        "norm_drift" => abs(d.norms[end] - d.norms[1]) / d.norms[1],
        "times" => [f.t for f in frames],
        "axis_order_t" => [f.axis_order for f in frames],
        "radial_prominence_t" => [f.radial_prominence for f in frames],
        "misalign_deg_t" => [rad2deg(f.misalign) for f in frames],
        "aspect_ratio" => d.aspect_ratio, "Lz" => d.Lz,
        "seconds" => secs,
        # Frames on disk so a metric change never costs another 45 min run.
        "frames_path" => _save_frames(control ? "control" : "stripes", smoke,
            d.times, d.column_density, grid),
    )
end

"Persist the column-density frames so the analysis can be redone without the run."
function _save_frames(arm, smoke, times, cols, grid)
    isempty(cols) && return nothing
    dir = joinpath(ROOT, "runs", "klaus2022")
    mkpath(dir)
    # RESULT_TAG, for the same reason KLAUS_RESULTS exists and in the same
    # words the submit wrapper already uses about the JSON: one seed per job so
    # that concurrent jobs do not share a file. The JSON got that treatment and
    # THIS DID NOT, so three seeds would all have written `stripes_frames.jld2`
    # and kept whichever finished last — while each seed's JSON recorded that
    # shared path as its own `frames_path`. A record saying "seed 1" pointing at
    # seed 3's frames is worse than no frames: `klaus2022_reanalyse.jl` re-derives
    # the verdicts from exactly this file, so the re-analysis would have been
    # silently about a different run than the one it was labelled with.
    path = joinpath(dir, "$(arm)$(smoke ? "_smoke" : RESULT_TAG)_frames.jld2")
    JLD2.jldsave(path; times=times, column_density=cols,
        dx=grid.dx[1], dy=grid.dx[2])
    path
end

# --- Driver ---

out = if arm == "ar-ramp"
    arm_ar_ramp(smoke)
elseif arm == "stripes"
    arm_stripes(smoke; control=false)
elseif arm == "control"
    arm_stripes(smoke; control=true)
else
    println("usage: klaus2022_reproduce.jl {ar-ramp|stripes|control} [--smoke]")
    exit(2)
end

out["published"] = Dict(string(k) => v for (k, v) in pairs(PUBLISHED))
out["accept"] = Dict(string(k) => v for (k, v) in pairs(ACCEPT))
out["wigner_seed"] = WIGNER_SEED
# NOT set here — each arm records the time it actually propagated. This line
# used to restate `hold_s` from the env default and was wrong for every
# `--smoke` run; see the comment beside the stripes arm's own entry.
#
# The assertion is on `duration_s` and NOT on `hold_s`, because `ar-ramp` has no
# hold: it is a ramp, and giving its `dur` the name `hold_s` would make the
# record read as a quantity the arm does not have. The first version of this
# guard did demand `hold_s` from every arm and would have failed `ar-ramp` —
# a gate reddening on correct work, forty minutes after writing that down as
# the failure mode to avoid.
haskey(out, "duration_s") ||
    error("arm $(out["arm"]) did not record the duration it propagated")
out["git_hash"] = strip(read(`git rev-parse HEAD`, String))
out["dirty"] = !isempty(strip(read(`git status --porcelain`, String)))
out["timestamp"] = string(now())

all_results = isfile(RESULTS) ? JSON.parsefile(RESULTS) : Dict{String, Any}()
key = out["smoke"] ? out["arm"] * "_smoke" : out["arm"] * RESULT_TAG
all_results[key] = out
open(RESULTS, "w") do f
    JSON.print(f, all_results, 2)
end

@printf("\n=== %s: %s ===\n", out["arm"], out["verdict"])
for k in ("omega_c_over_perp", "ar_peak", "ar_static_magnetostricted",
    "ar_static_verdict", "axis_order", "axis_order_over_null",
    "axis_order_over_baseline", "radial_prominence", "stripe_misalign_deg",
    "n_stripes", "wigner_seed_fraction", "norm_drift", "seconds", "frames_path")
    haskey(out, k) && println("  ", rpad(k, 28), out[k])
end
println("  written to ", RESULTS)
