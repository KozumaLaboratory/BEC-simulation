# The magnetostricted aspect ratio, as a SENSITIVITY TABLE (#406 step 2/3).
#
# The one type-C disagreement left in the Klaus 2022 reproduction is
# AR = 1.16 against a published 1.03 — a factor ~5 in (AR − 1) — and #406's
# order is deliberate: read the primary source, THEN build a sensitivity table,
# THEN scan. Step 1 is done and is recorded in
# `docs/validation/klaus2022_primary_source.md` §6g; what it settled is what the
# published number IS (see that section), not why ours differs.
#
# This is step 2 and step 3, and it is a table rather than a scan because
# CLAUDE.md's gate 2 says so: two points per (parameter, observable) cell,
# normalised by that parameter's published systematic. Most cells will be
# ~zero, and knowing WHICH is the result — "AR does not move with N" means the
# disagreement is robust to not knowing N, and also that scanning N cannot
# close it.
#
# The axes and why each is here:
#
#   a_s      111(9) a₀ — an ±8 % systematic, and the ONLY one the paper hands us
#            with an error bar. But a_s there is a FITTED parameter (fitted to
#            simulations of this same family), so agreement bought by moving it
#            is not evidence. The column is here to bound, not to tune.
#   N        the paper's theory uses N_c = 15000; the EXPERIMENT is ≈ 2×10⁴ and
#            decaying, and the bimodal fit "breaks down" after 700 ms so late N
#            is not measured at all.
#   λ=ω_z/ω_⊥  the paper states TWO traps: theory (50, 130) Hz ⇒ λ = 2.6, which
#            is what we ran, and experiment (50.8, 140) Hz ⇒ λ = 2.756. The
#            Methods sentence that carries AR = 1.03 is in the EXPERIMENT's
#            section ("for all our measurements, the measured trap AR_trap …"),
#            so the experimental trap is the one that number belongs to. This
#            column is the first thing to look at.
#   θ        35°, stated repeatedly and with no error bar.
#   LHY      the paper's eGPE carries γ_QF (Lima–Pelster 𝒬₅). Ours does too, so
#            this column is not a fix — it is the MAGNITUDE of a term whose
#            effect on AR nobody in this repo has measured, which is #406's
#            third item.
#   box      §6b measured a 1.3 % move from box 16 → 20 a_ho. Carried so the
#            periodic-image systematic sits in the same table as the physics.
#
# ONE AT A TIME from the baseline, plus one arm that sets EVERY published
# EXPERIMENTAL value simultaneously — because a table of one-at-a-time
# derivatives cannot see a product of two 20 % effects, and that arm is the only
# cheap thing that can.
#
# Env:
#   AS_GRID=64          in-plane points (z gets half). §6b: AR is grid-converged
#                       at 64²×32 to five digits against 128²×64.
#   AS_STEPS=8000       ITP steps
#   AS_OUT=figs/klaus2022/ar_sensitivity
#   AS_ARMS=            `;`-separated subset of arm names ("" = all)

import CUDA
using SpinorBEC
using DelimitedFiles: writedlm
using Printf

const GRID_N = parse(Int, get(ENV, "AS_GRID", "64"))
const STEPS = parse(Int, get(ENV, "AS_STEPS", "8000"))
const OUT = get(ENV, "AS_OUT", "figs/klaus2022/ar_sensitivity")
mkpath(OUT)

const THETA35 = deg2rad(35)

# The published value this table exists to explain, and the band §6's
# pre-registered null asked for. Neither is moved here.
const AR_PUBLISHED = 1.03
const AR_BAND = (1.02, 1.04)

"""One ground-state cell. Every knob the table sweeps is a keyword with the
baseline as its default, so an arm is a one-line override and cannot silently
change two things at once."""
function gs_spec(; a_s=111.0, N=15000, lambda=2.6, theta=THETA35, lhy="scalar",
    box=16.0, omega_ref_hz=50.0, B_gauss=5.333)
    nz = max(4, GRID_N ÷ 2)
    Dict("ground_state" => Dict(
        "kind" => "scalar_egpe", "atom" => "Dy162", "a_s" => a_s,
        "grid" => Dict("n" => [GRID_N, GRID_N, nz],
            "box" => [box, box, box / 2]),
        "interactions" => Dict("N_atoms" => N, "omega_ref" => 2π * omega_ref_hz),
        "ddi" => Dict("enabled" => true),
        "lhy" => Dict("kind" => lhy),
        "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, lambda]),
        "B_direction" => Dict("theta" => theta),
        "B_magnitude_gauss" => B_gauss,
        "dt" => 0.004, "n_steps" => STEPS,
    ))
end

function run_gs(spec)
    data = Dict{Any, Any}("pipeline" => [spec])
    SpinorBEC._normalize_and_validate!(data; strict=true)
    cfg = SpinorBEC.parse_pipeline(data)
    t0 = time()
    res = run_config(cfg; verbose=false)
    (res[:scalar_egpe_ground_state], time() - t0)
end

# name => (override NamedTuple, axis, the value being varied, the published
# systematic on that axis as a string). `axis == ""` marks the baseline and the
# all-experimental arm, which are not derivative points.
const ARMS = [
    ("baseline", (;), "", "theory trap, N=15000, a_s=111", "—"),

    # a_s: the one published error bar. TWO points either side, so the column is
    # a derivative and not a single displacement.
    ("a_s=102", (; a_s=102.0), "a_s", "102 a₀", "111(9) a₀, i.e. ±8 %"),
    ("a_s=120", (; a_s=120.0), "a_s", "120 a₀", "111(9) a₀, i.e. ±8 %"),

    # N: theory 15000, experiment ≈ 2e4 and unmeasured after 700 ms.
    ("N=10000", (; N=10000), "N", "10000", "theory 15000; experiment ≈2e4, not measured late"),
    ("N=20000", (; N=20000), "N", "20000", "theory 15000; experiment ≈2e4, not measured late"),

    # λ: the paper states two traps and AR = 1.03 belongs to the experimental one.
    ("lambda=2.756", (; lambda=140.0 / 50.8, omega_ref_hz=50.8), "lambda",
        "2.756 (50.8,140) Hz", "paper states BOTH 2.6 (theory) and 2.756 (experiment)"),
    ("lambda=2.4", (; lambda=2.4), "lambda", "2.4", "—"),

    # θ: stated with no error bar, so ±2° is a plausibility probe, not a systematic.
    ("theta=33", (; theta=deg2rad(33)), "theta", "33°", "35°, no error bar published"),
    ("theta=37", (; theta=deg2rad(37)), "theta", "37°", "35°, no error bar published"),

    # LHY: #406 item 3. Not a fix — a magnitude nobody measured.
    ("lhy=none", (; lhy="none"), "lhy", "off", "the paper's eGPE has γ_QF; so does ours"),

    # box: the periodic-image systematic, in the same table as the physics.
    ("box=20", (; box=20.0), "box", "20 a_ho", "§6b measured 1.3 % from 16 → 20"),

    # The product term. A one-at-a-time table cannot see two 20 % effects
    # multiplying, and this is the only cheap arm that can.
    ("all-experimental", (; lambda=140.0 / 50.8, omega_ref_hz=50.8, N=20000, a_s=111.0),
        "", "every published EXPERIMENTAL value at once", "—"),
]

wanted = let s = get(ENV, "AS_ARMS", "")
    isempty(s) ? nothing : Set(String.(split(s, r"[,;]")))
end

@printf("""
Klaus 2022 magnetostriction sensitivity — #406 steps 2 and 3
  grid %d²×%d, %d ITP steps, %s
  published AR = %.2f (Methods/Magnetostirring); §6 null band [%.2f, %.2f]
  baseline: a_s=111 a₀, N=15000, λ=2.6, θ=35°, LHY scalar, box 16 a_ho
""", GRID_N, max(4, GRID_N ÷ 2), STEPS, CUDA.functional() ? "CUDA" : "CPU",
    AR_PUBLISHED, AR_BAND[1], AR_BAND[2])
flush(stdout)

rows = NamedTuple[]
base_ar = NaN
for (name, ov, axis, value, systematic) in ARMS
    wanted === nothing || name in wanted || continue
    gs, wall = run_gs(gs_spec(; ov...))
    ar = gs.aspect_ratio_xy
    name == "baseline" && (base_ar = ar)
    # (AR − 1) is the physical quantity: AR = 1 is "no magnetostriction", so a
    # ratio of ARs would compress the very effect being compared.
    d_excess = isnan(base_ar) ? NaN : (ar - 1) / (base_ar - 1) - 1
    @printf("  %-18s AR = %.5f   Δ(AR−1) vs baseline = %+7.2f %%   [%s = %s]  %.1f s\n",
        name, ar, 100 * d_excess, isempty(axis) ? "—" : axis, value, wall)
    flush(stdout)
    push!(rows, (; name, axis, value, systematic, ar,
        excess=ar - 1, d_excess_pct=100 * d_excess, wall))
end

open(joinpath(OUT, "ar_sensitivity.csv"), "w") do io
    writedlm(io, vcat(["arm" "axis" "value" "published_systematic" "AR" "AR_minus_1" "d_excess_pct" "wall_s"],
            [getfield(r, f) for r in rows,
                f in (:name, :axis, :value, :systematic, :ar, :excess,
                    :d_excess_pct, :wall)]), '\t')
end

# ---------------------------------------------------------------- the verdict

println("\n=== what would have to move, and by how much ===")
if isnan(base_ar)
    println("  baseline not run (AS_ARMS excluded it) — no derivative is quotable.")
else
    need = (AR_PUBLISHED - 1) / (base_ar - 1) - 1
    @printf("  to reach AR = %.2f from %.5f, (AR−1) must fall by %.1f %%\n",
        AR_PUBLISHED, base_ar, -100 * need)
    println("  per-axis, the largest excursion this table produced:")
    for ax in unique([r.axis for r in rows if !isempty(r.axis)])
        arms = [r for r in rows if r.axis == ax]
        big = argmax(r -> abs(r.d_excess_pct), arms)
        covers = abs(big.d_excess_pct) >= abs(100 * need)
        @printf("    %-8s %+7.2f %%  (%s; published systematic: %s)  %s\n",
            ax, big.d_excess_pct, big.value, big.systematic,
            covers ? "<= COULD CLOSE THE GAP ALONE" : "cannot close it alone")
    end
    allx = findfirst(r -> r.name == "all-experimental", rows)
    if allx !== nothing
        r = rows[allx]
        @printf("  all published experimental values at once: AR = %.5f (%+.2f %%) — %s\n",
            r.ar, r.d_excess_pct,
            AR_BAND[1] <= r.ar <= AR_BAND[2] ? "INSIDE the null band" :
            "still outside [$(AR_BAND[1]), $(AR_BAND[2])]")
    end
    println("""
  READ THIS AS A BOUND, NOT A FIT. `a_s` was fitted by the paper against
  simulations of this same family, so an agreement obtained by moving it is
  not evidence — the column is here to say how much of the gap it COULD
  account for, which is a different question from whether it does.""")
end

println("\nwrote ", joinpath(OUT, "ar_sensitivity.csv"))
