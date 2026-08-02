# Lane A item A4 — the F=6 LHY oracle.
#
# Five papers ride on the closed forms agreeing with `full_bdg`, so this is the
# one place worth redundancy. The campaign plan asks for "1e-4 rel". That number
# cannot simply be asserted: test/oracles/test_lhy_full_bdg_closed_form_parity.jl
# already gates the same comparison at `_RTOL = 2e-3` with the note that the
# 2e-3 is "quadrature + φ₁^reg spline, not method error (~1e-4 typ.)". Demanding
# 1e-4 without checking would be demanding better than the instrument.
#
# So this MEASURES rather than asserts, and it separates the two error sources
# by sweeping the BdG quadrature at fixed physics:
#
#   * If the residual keeps falling as (k_max, n_k) grow, what we were seeing
#     was quadrature error and the closed form is better than 2e-3.
#   * If it plateaus, the plateau IS the closed form's own approximation error,
#     and that plateau — not 1e-4 — is the honest gate.
#
# That is the "derive tolerances, gate the RELATIONSHIP" rule: quote the
# dominant error source, and hold the expansion parameter fixed while varying
# the thing under test.
#
# Contact only, no DDI: `full_bdg` has no mean-field-stable point in the Eu
# dipolar regime (c_dd = 0 gives exactly 0; every nonzero c_dd is unstable at
# every c1/q/n), and ε_LHY is scheme-dependent wherever Im ω ≠ 0. A parity
# number taken at an unstable point would not mean anything. Every (F, c₀, c₁)
# below is on the stable side of its own ansatz, matching the existing gate.
#
# Usage:  julia --project=. bench/a4_lhy_closed_form_residual.jl [smoke|full]

using SpinorBEC
using SpinorBEC: _lhy_bdg_energy_density, _c0c1_to_gS,
    lhy_energy_polar, lhy_energy_fm, build_polar_lhy_coefs, build_fm_lhy_coefs,
    epsilon_LHY_F6_Ih, ZETA_F6_IH, compute_c0_lambda_F6_Ih
using Printf
using Statistics

const MODE = length(ARGS) >= 1 ? ARGS[1] : "smoke"

_polar_spinor(F) = ComplexF64[c == F + 1 ? 1.0 : 0.0 for c in 1:(2F + 1)]
_fm_spinor(F) = ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:(2F + 1)]

_bdg(spinor, F, c0, c1, n0, k_max, n_k) = _lhy_bdg_energy_density(
    spinor, n0, F, InteractionParams(Dict(0 => c0, 1 => c1)),
    ZeemanParams(), 0.0, k_max, n_k, 1)

# ---------------------------------------------------------------------------
# The cases. Each is (label, F, c0, c1, spinor, closed-form ε at n0 = 1).
# ---------------------------------------------------------------------------
function cases()
    out = Tuple{String, Int, Float64, Float64, Vector{ComplexF64}, Float64}[]
    # polar_contact — the ansatz is exact at F=1 and is the F≥2 polar path.
    for (F, c1) in ((1, 0.1), (1, 0.5), (2, 0.1), (2, 0.5), (6, 0.1))
        g = _c0c1_to_gS(F, 10.0, c1)
        all(>(0), values(g)) || continue
        push!(out, ("polar_contact F=$F c1=$c1", F, 10.0, c1, _polar_spinor(F),
            lhy_energy_polar(1.0, build_polar_lhy_coefs(F, g))))
    end
    # fm_contact — any F since 2026-07-27; c1 < 0 is the FM-stable side.
    for (F, c1) in ((1, -0.1), (2, -0.1), (6, -0.2), (6, -0.1), (6, -0.05))
        g = _c0c1_to_gS(F, 10.0, c1)
        all(>(0), values(g)) || continue
        push!(out, ("fm_contact F=$F c1=$c1", F, 10.0, c1, _fm_spinor(F),
            lhy_energy_fm(1.0, build_fm_lhy_coefs(F, g))))
    end
    # icosahedral — genuinely F=6, and only λ_spin > 0 (i.e. c1 > 0); the
    # closed form returns NaN on the c1 < 0 branch by construction, which is
    # the sign Eu production uses, so those points are skipped rather than
    # coerced. ζ_Ih is not a single-|m⟩ state, so unlike polar/FM its
    # stationarity is not free — the existing gate measured it at ≤1.5e-15.
    for c1 in (0.05, 0.1, 0.2)
        g = _c0c1_to_gS(6, 10.0, c1)
        all(>(0), values(g)) || continue
        c0_st, lam = compute_c0_lambda_F6_Ih(g)
        (c0_st > 0 && lam > 0) || continue
        e = epsilon_LHY_F6_Ih(1.0, g)
        isfinite(e) || continue
        push!(out, ("icosahedral F=6 c1=$c1", 6, 10.0, c1, ZETA_F6_IH, e))
    end
    out
end

# ε_LHY ∝ n^(5/2) exactly, so the closed form at n0 is ε(1) * n0^2.5.
const DENSITIES = MODE == "smoke" ? (1.0,) : (0.3, 1.0, 3.0)
const QUAD = MODE == "smoke" ? ((60.0, 300),) :
             ((40.0, 200), (60.0, 300), (90.0, 600), (140.0, 1200))

function main()
    cs = cases()
    @printf("A4 — closed-form vs full_bdg residual   mode=%s cases=%d densities=%d quad=%d\n",
        MODE, length(cs), length(DENSITIES), length(QUAD))
    println("contact only (c_dd = 0): full_bdg has no mean-field-stable point in the dipolar regime")
    println()
    @printf("%-26s %7s %8s %6s %14s %14s %11s\n",
        "case", "n0", "k_max", "n_k", "full_bdg", "closed", "rel")
    worst = Dict{String, Float64}()
    rows = 0
    for (label, F, c0, c1, spinor, e1) in cs
        for n0 in DENSITIES
            closed = e1 * n0^2.5
            for (k_max, n_k) in QUAD
                bdg = _bdg(spinor, F, c0, c1, n0, k_max, n_k)
                rel = abs(bdg - closed) / abs(closed)
                @printf("%-26s %7.2f %8.1f %6d %14.6e %14.6e %11.3e\n",
                    label, n0, k_max, n_k, bdg, closed, rel)
                key = "$(split(label)[1])@k$(k_max)"
                worst[key] = max(get(worst, key, 0.0), rel)
                rows += 1
            end
        end
    end
    println()
    println("=== worst relative residual per (family, quadrature) ===")
    println("A FALLING column with k_max ⇒ quadrature-limited; a FLAT one ⇒ that is the")
    println("closed form's own error, and is the honest gate.")
    for k in sort(collect(keys(worst)))
        @printf("  %-34s %11.3e\n", k, worst[k])
    end
    println()
    # The max over a CONVERGENCE SWEEP is dominated by the deliberately-coarse
    # arm, so it is not a verdict — quoting it would fail the run on the arm
    # that exists precisely to be bad. Judge at the finest quadrature only, and
    # let the sweep speak through the fitted order instead.
    ks = sort(unique(q[1] for q in QUAD))
    fams = sort(unique(split(k, "@")[1] for k in keys(worst)))
    if length(ks) >= 2
        println("=== fitted convergence order  (residual ∝ k_max^-p) ===")
        for f in fams
            vs = [get(worst, "$f@k$(k)", NaN) for k in ks]
            ps = [log(vs[i] / vs[i + 1]) / log(ks[i + 1] / ks[i]) for i in 1:(length(ks) - 1)]
            @printf("  %-16s p = %s\n", f, join((@sprintf("%.2f", p) for p in ps), "  "))
        end
        println("  a clean p ≈ 3 across families ⇒ ONE shared UV-truncation error,")
        println("  i.e. full_bdg converging TO the closed form, not a method gap.")
        println()
    end
    kfin = last(ks)
    fine = maximum(get(worst, "$f@k$(kfin)", 0.0) for f in fams)
    @printf("worst at the FINEST quadrature (k_max = %.0f): %.3e over %d rows\n",
        kfin, fine, rows)
    @printf("campaign criterion 1e-4: %s\n", fine <= 1e-4 ? "MET" : "NOT MET")
    println("(coarse arms are convergence probes, not candidate answers)")
    println("existing gate contract (_RTOL in test_lhy_full_bdg_closed_form_parity.jl): 2.0e-3")
end

main()
