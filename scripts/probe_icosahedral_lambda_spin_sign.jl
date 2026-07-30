# Probe: which g_S ladders put the F=6 I_h spin-Goldstone stiffness λ_spin
# negative, and how far?
#
# λ_spin = −g₀/13 − 121g₆/646 + 91g₁₀/782 + 840g₁₂/5681 is a signed combination,
# so it goes negative for perfectly positive ladders. `epsilon_LHY_F6_Ih` took
# |λ_spin|^(5/2) and so returned a real energy wherever that happened; it now
# refuses. This survey is what set the guard's round-off band and what corrected
# the premise of `test_icosahedral_lhy.jl`'s positivity testset.
#
# WHAT THIS PROBE CANNOT DO, recorded because the first version tried and
# produced garbage: it cannot compare an arbitrary ladder against `full_bdg`.
# `InteractionParams(Dict(...))` is keyed by **c-coefficient rank**, not by spin
# channel S, and `_bdg_contact_matrices` applies `c_to_g` itself. Feeding a g_S
# ladder into those slots double-converts — it read a ratio of 5.16 in the
# scalar limit, where `probe_icosahedral_lhy_parity.jl` measures agreement to
# 1.1e-4. Hitting a target ladder exactly needs the g→c inversion (`c_to_g` is
# `_c0c1_to_gS` plus a non-diagonal δg from the higher ranks), which is a linear
# solve nobody has written. So the full_bdg comparison lives in the sibling
# probe, restricted to the c₀/c₁ family it can construct exactly.

using SpinorBEC
using SpinorBEC: _c0c1_to_gS

ladders = [
    ("ones(7)  [scalar limit]", ones(7)),
    ("positivity row 2", [1.0, 0.5, 1.5, 0.9, 1.1, 1.0, 1.0]),
    ("positivity row 3", [2.0, 0.0, 0.0, 1.0, 0.0, 0.5, 0.5]),
    ("positivity row 4", [1.0, 1.05, 0.98, 1.02, 0.97, 1.01, 0.99]),
    ("wrapper ladder (old)", [1.0, 1.05, 0.98, 1.02, 0.97, 1.01, 0.99]),
    ("g_ih (g12-dominated)", [5.0, 2.0, 2.0, 5.0, 2.0, 10.0, 50.0]),
    ("c0=100 c1=+5", [_c0c1_to_gS(6, 100.0, 5.0)[2k] for k in 0:6]),
    ("c0=10 c1=+0.1", [_c0c1_to_gS(6, 10.0, 0.1)[2k] for k in 0:6]),
    ("c0=10 c1=0", [_c0c1_to_gS(6, 10.0, 0.0)[2k] for k in 0:6]),
    ("c0=10 c1=-0.05", [_c0c1_to_gS(6, 10.0, -0.05)[2k] for k in 0:6]),
    ("c0=10 c1=-0.1", [_c0c1_to_gS(6, 10.0, -0.1)[2k] for k in 0:6]),
    ("c0=10 c1=-0.2", [_c0c1_to_gS(6, 10.0, -0.2)[2k] for k in 0:6]),
    ("Eu production sign (c1/c0=-0.005)",
        [_c0c1_to_gS(6, 100.0, -0.5)[2k] for k in 0:6]),
]

println(rpad("ladder", 36), rpad("c_0", 13), rpad("lam_spin", 14),
    rpad("lam/c_0", 13), rpad("verdict", 9), "epsilon(n=1)")
for (name, g) in ladders
    gg = collect(Float64, g)
    c0, lam = compute_c0_lambda_F6_Ih(gg)
    rel = lam / c0
    # Same band the guard uses: negative beyond round-off, not merely negative.
    verdict = lam < -1e-12 * c0 ? "REFUSES" : "answers"
    eps = epsilon_LHY_F6_Ih(1.0, gg)
    println(rpad(name, 36), rpad(round(c0; sigdigits=6), 13),
        rpad(round(lam; sigdigits=5), 14), rpad(round(rel; sigdigits=4), 13),
        rpad(verdict, 9), isnan(eps) ? "NaN" : string(round(eps; sigdigits=6)))
end

println()
println("Why the band is relative rather than a bare `λ_spin < 0`:")
let gu = ones(7), gc = [_c0c1_to_gS(6, 10.0, 0.0)[2k] for k in 0:6]
    _, lam_u = compute_c0_lambda_F6_Ih(gu)
    _, lam_c = compute_c0_lambda_F6_Ih(gc)
    println("  λ_spin is 0 on paper at uniform g_S, and the literal ladder")
    println("  ones(7) does land on ", lam_u, ".")
    println("  But the same limit reached through _c0c1_to_gS(6, 10.0, 0.0)")
    println("  lands on ", lam_c, " — the cancellation is not exact once the")
    println("  ladder comes from c₀/c₁, so a bare `λ_spin < 0` refuses the")
    println("  scalar limit, which matches Lima-Pelster to 1e-12.")
end
