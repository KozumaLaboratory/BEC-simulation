# Probe: can `full_bdg` serve as the independent arm for the F=6 I_h closed form?
#
# The parity oracle covers polar (F=1,2,6), FM (F=6) and the scalar limit. It
# does NOT cover `icosahedral`, which is the one closed form the F=6 phase work
# depends on. Before writing that arm, measure whether the two sides CAN agree:
# the polar and FM spinors are mean-field stationary for any (c0, c1) by
# symmetry, and ZETA_F6_IH is not obviously stationary for a c0/c1-only ladder.
# If it is not, full_bdg expands around a non-stationary point and a mismatch
# would say nothing about either implementation.
#
# So three things are measured, not one:
#   1. the stationarity residual  ‖(Z + n·h_mf)ζ − μζ‖  from the production
#      mean-field matrix — whether the comparison is even well posed;
#   2. the two energy densities and their ratio;
#   3. a discrimination control — I_h vs polar at the SAME ladder. If they
#      agree, then "full_bdg == icosahedral" tests the shared prefactor and not
#      the I_h structure, and must not be sold as coverage of it.

using LinearAlgebra
using SpinorBEC
using SpinorBEC: _lhy_bdg_energy_density, _bdg_contact_matrices, _c0c1_to_gS,
    lhy_energy_polar, build_polar_lhy_coefs, lhy_energy_fm, build_fm_lhy_coefs

const KMAX = 60.0
const NK = 300
const C0 = 10.0

bdg_eps(spinor, F, c0, c1; n0=1.0) = _lhy_bdg_energy_density(
    spinor, n0, F, InteractionParams(Dict(0 => c0, 1 => c1)),
    ZeemanParams(), 0.0, KMAX, NK, 1)

# ‖(Z + n·h_mf)ζ − μζ‖ with μ = ⟨ζ|(Z + n·h_mf)|ζ⟩ — zero iff ζ is a uniform
# mean-field stationary state at this ladder. Uses the same matrix the BdG
# solver expands around, so a nonzero value is exactly the objection.
function stationarity_residual(spinor, F, c0, c1; n0=1.0)
    ip = InteractionParams(Dict(0 => c0, 1 => c1))
    h_mf, _, zee, _ = _bdg_contact_matrices(spinor, F, ip, ZeemanParams())
    H = Diagonal(zee) .+ n0 .* h_mf
    v = H * spinor
    mu = real(dot(spinor, v))
    norm(v .- mu .* spinor) / max(abs(mu), eps())
end

println("F=6, c0 = ", C0, ", n = 1")
println()
println("stationarity residual  ‖(Z+n·h_mf)ζ − μζ‖ / |μ|")
println(rpad("c1", 9), rpad("I_h", 14), rpad("polar", 14), "FM")
for c1 in (-0.2, -0.1, -0.05, 0.05, 0.1, 0.2)
    pol = ComplexF64[c == 7 ? 1.0 : 0.0 for c in 1:13]
    fm = ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:13]
    println(rpad(c1, 9),
        rpad(round(stationarity_residual(ZETA_F6_IH, 6, C0, c1); sigdigits=4), 14),
        rpad(round(stationarity_residual(pol, 6, C0, c1); sigdigits=4), 14),
        round(stationarity_residual(fm, 6, C0, c1); sigdigits=4))
end

println()
println("icosahedral: closed form vs full_bdg")
println(rpad("c1", 9), rpad("c_0", 13), rpad("lam_spin", 13),
    rpad("closed", 13), rpad("full_bdg", 13), "ratio")
for c1 in (-0.2, -0.1, -0.05, 0.05, 0.1, 0.2)
    g = _c0c1_to_gS(6, C0, c1)
    if !all(>(0), values(g))
        println(rpad(c1, 9), "g_S not all positive — skipped")
        continue
    end
    c0_st, lam = compute_c0_lambda_F6_Ih(g)
    closed = epsilon_LHY_F6_Ih(1.0, g)
    bdg = try
        bdg_eps(ZETA_F6_IH, 6, C0, c1)
    catch e
        println(rpad(c1, 9), "full_bdg threw: ", sprint(showerror, e))
        continue
    end
    println(rpad(c1, 9),
        rpad(round(c0_st; sigdigits=6), 13), rpad(round(lam; sigdigits=6), 13),
        rpad(round(closed; sigdigits=6), 13), rpad(round(bdg; sigdigits=6), 13),
        round(bdg / closed; sigdigits=6))
end

println()
println("discrimination control — three closed forms at the SAME ladder")
println(rpad("c1", 9), rpad("I_h", 13), rpad("polar", 13), rpad("FM", 13),
    "max rel spread vs I_h")
for c1 in (-0.1, 0.05, 0.1)
    g = _c0c1_to_gS(6, C0, c1)
    all(>(0), values(g)) || continue
    ih = epsilon_LHY_F6_Ih(1.0, g)
    pol = lhy_energy_polar(1.0, build_polar_lhy_coefs(6, g))
    fm = lhy_energy_fm(1.0, build_fm_lhy_coefs(6, g))
    spread = max(abs(1 - pol / ih), abs(1 - fm / ih))
    println(rpad(c1, 9), rpad(round(ih; sigdigits=6), 13),
        rpad(round(pol; sigdigits=6), 13), rpad(round(fm; sigdigits=6), 13),
        round(spread; sigdigits=4))
end

println()
println("scalar limit (c1 = 0): g_S ≡ g ⇒ c_0 = g, lam_spin = 0 exactly")
let g = _c0c1_to_gS(6, C0, 0.0)
    c0_st, lam = compute_c0_lambda_F6_Ih(g)
    println("  c_0 = ", round(c0_st; sigdigits=8), "   lam_spin = ", lam)
    println("  analytic (8/15π²)g^(5/2) = ", round(8 / (15π^2) * C0^2.5; sigdigits=8))
    println("  closed                   = ", round(epsilon_LHY_F6_Ih(1.0, g); sigdigits=8))
    println("  full_bdg                 = ", round(bdg_eps(ZETA_F6_IH, 6, C0, 0.0); sigdigits=8))
end
