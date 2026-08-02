# Probe: is the |λ_spin| masking pattern shared by the polar and FM closed forms?
#
# Conclusion up front: NOT the same defect, but the FM form has a different one.
# Every row prints the stiffness it is claiming to test, so the label cannot drift
# from the condition — the first version of this script asserted "sigma_0 < 0"
# while sigma_0 was in fact positive, and read a healthy number as a pass.

using SpinorBEC
using SpinorBEC: build_polar_lhy_coefs, lhy_energy_polar, build_fm_lhy_coefs,
    lhy_energy_fm, phi_1_reg, _c0c1_to_gS

println("I_h — λ_spin is a STIFFNESS; |λ_spin| reported the stable-branch value")
for c1 in (0.1, -0.2)
    g = _c0c1_to_gS(6, 10.0, c1)
    c0s, lam = compute_c0_lambda_F6_Ih(g)
    println("  c1=", rpad(c1, 6), " c_0=", rpad(round(c0s; sigdigits=5), 9),
        " λ_spin=", rpad(round(lam; sigdigits=5), 9),
        " ε=", epsilon_LHY_F6_Ih(1.0, g))
end

println()
println("polar — κ_m = |δ_m| is an ANOMALOUS coupling; ω² = ξ² − |δ|² needs |δ|.")
println("        The instability shows up as t = ξ/κ − 1 < 0, and phi_1_reg")
println("        REGULARISES it (Petrov saturation) rather than masking it.")
for t in (-2.0, -1.0, -0.5, 0.0, 1.0)
    println("  t=", rpad(t, 6), " phi_1_reg=", phi_1_reg(t))
end
println("  φ₁^reg(−1) = 0.3177 is the documented droplet limit, not an accident.")

println()
println("polar — what actually happens to σ_0 when g_0 is driven negative:")
for g0 in (1.0, -1.0, -20.0)
    gd = Dict(S => (S == 0 ? g0 : 1.0) for S in 0:2:12)
    coefs = build_polar_lhy_coefs(6, gd)
    ok = coefs.sigma[1] > 0
    print("  g_0=", rpad(g0, 7), " σ_0=", rpad(round(coefs.sigma[1]; sigdigits=6), 12),
        ok ? " (still >0) " : " (NEGATIVE) ")
    try
        println("ε=", lhy_energy_polar(1.0, coefs))
    catch e
        println(typeof(e))
    end
end

println()
println("FM — DIFFERENT DEFECT of the same class, FIXED 2026-07-30. Its")
println("     `kappa < 1e-12 && return 0.0` meant \"negligible\" and also swallowed")
println("     NEGATIVE g_{2F}, so a negative stiffness reported NO LHY. It now")
println("     declines with NaN; the rows below are the fixed behaviour.")
for c1 in (0.1, -0.005, -0.0278, -0.05)
    g = _c0c1_to_gS(6, 10.0, c1 * 10.0)
    coefs = build_fm_lhy_coefs(6, g)
    g12 = g[12]
    println("  c1/c0=", rpad(c1, 8), " g_12=", rpad(round(g12; sigdigits=6), 12),
        " ε_fm=", lhy_energy_fm(1.0, coefs))
end
println("  Reachable at F=6 whenever c1/c0 < -1/36 = -0.0278 (g_2F = c0 + 36 c1).")
println("  Zero committed config uses fm_contact/fm_dipolar, so this one had no")
println("  blast radius — unlike the I_h guard, which errored five of them.")
println("  A silent zero also passed test_lhy_config_validity_domain.jl, whose")
println("  `isfinite(e) && e >= 0` both hold at 0.0; that gate now asserts e > 0.")
