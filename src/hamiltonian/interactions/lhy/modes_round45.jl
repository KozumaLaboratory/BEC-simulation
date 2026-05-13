# NOT GENERALIZABLE: each (F, point group) pairing has its own LHY closed form.
# Reason: math
# Why: F=2 BN / F=3 octa / F=4 cube / F=8 octa / F=10 dodec each carry a
#   distinct harmonic decomposition under the residual symmetry of their inert
#   state (different branch counts, channel coefficients, multiplicities).
#   Paper #3 §V provides one closed form per family — no single F-parametric
#   expression exists.
# See: docs/manuscript/papers/paper3_universal_theorem/main.md §V.A-§V.G
#
# Standalone LHY mode functions for the Round-4/Round-5 closed-form
# polyhedral verifications (F=2 BN, F=3 octa, F=4 cube, F=8 octa,
# F=10 dodec). NEW FILE; does NOT integrate into src/lhy.jl or the
# YAML schema. Final integration round will wire these into the
# TabulatedLHY subtype builders / make_workspace dispatch. Each (F, point group) pairing has its own
# harmonic decomposition under the residual symmetry of the inert
# state, producing a distinct closed-form set of stiffnesses (c_0,
# λ_α). The number of stiffness branches, the channel coefficients,
# and the multiplicity counts in the sum-of-powers formula all change
# F-by-F. Compare e.g. `lhy_F4_cube` (3 branches, O_h irreps) vs
# `lhy_F10_dodec` (4 branches, I_h irreps). These are derived by
# sympy from Paper #3 §V — the manuscript provides one closed form
# per family, not a unifying expression.
#
# Convention: dimensionless `M = hbar = 1` (SpinorBEC.jl default). The
# `M` positional argument and `hbar` keyword let callers override for
# SI-unit work; for the default settings the universal prefactor
# reduces to 8/(15·π²).
#
# Coefficient values are taken verbatim from
# `docs/manuscript/papers/paper3_universal_theorem/main.md` §V (Round 5
# Paper #3 v3) and the F=2 BN edge case in §VII.B.

module LHYModesRound45

export lhy_F2_BN, lhy_F3_octa, lhy_F4_cube, lhy_F8_octa, lhy_F10_dodec

@inline function _prefactor(M::Real, hbar::Real)::Float64
    8.0 * sqrt(Float64(M)^3) / (15.0 * π^2 * Float64(hbar)^3)
end

"""
    lhy_F2_BN(g0, g2, g4, n, M; hbar=1.0) -> Float64

F=2 biaxial-nematic LHY (modified theorem, T_1 → A_2 ⊕ E split under D_4).

    ε = (8√M³ / 15π²ℏ³) · n^(5/2) · (c_0^(5/2) + |λ_z|^(5/2) + 2|λ_⊥|^(5/2))

with stiffnesses

    c_0 = (1/5)g_0 + (2/7)g_2 + (18/35)g_4
    λ_z = -(1/5)g_0 - (2/7)g_2 + (17/35)g_4
    λ_⊥ = -(1/5)g_0 + (1/7)g_2 + (2/35)g_4

Scalar limit `g_S ≡ g`: c_0 = g, λ_z = 0, λ_⊥ = 0 (all coefficient sums
analytically verified in `test/test_lhy_modes_round45.jl`).
"""
function lhy_F2_BN(g0::Real, g2::Real, g4::Real, n::Real, M::Real;
    hbar::Real=1.0)::Float64
    c0 = (1 / 5) * g0 + (2 / 7) * g2 + (18 / 35) * g4
    λz = -(1 / 5) * g0 - (2 / 7) * g2 + (17 / 35) * g4
    λ⊥ = -(1 / 5) * g0 + (1 / 7) * g2 + (2 / 35) * g4
    n <= 0 && return 0.0
    _prefactor(M, hbar) * Float64(n)^2.5 *
    (c0^2.5 + abs(λz)^2.5 + 2 * abs(λ⊥)^2.5)
end

"""
    lhy_F3_octa(g0, g2, g4, g6, n, M; hbar=1.0) -> Float64

F=3 octahedral (O:A_2, sign rep) LHY closed form. `g_2` is a no-op
(O harmonic exclusion). Universal `c_0^(5/2) + 3|λ_spin|^(5/2)` form.

    c_0     = (1/7)g_0 + (6/11)g_4 + (24/77)g_6
    λ_spin  = -(1/7)g_0 - (1/11)g_4 + (18/77)g_6
"""
function lhy_F3_octa(g0::Real, g2::Real, g4::Real, g6::Real, n::Real, M::Real;
    hbar::Real=1.0)::Float64
    c0 = (1 / 7) * g0 + (6 / 11) * g4 + (24 / 77) * g6
    λspin = -(1 / 7) * g0 - (1 / 11) * g4 + (18 / 77) * g6
    n <= 0 && return 0.0
    _prefactor(M, hbar) * Float64(n)^2.5 *
    (c0^2.5 + 3 * abs(λspin)^2.5)
end

"""
    lhy_F4_cube(g0, g2, g4, g6, g8, n, M; hbar=1.0) -> Float64

F=4 cube (O_h:A_{1g}) LHY closed form. `g_2` excluded (O_h harmonic
selection).

    c_0     = (1/9)g_0 + (98/429)g_4 + (40/99)g_6 + (10/39)g_8
    λ_spin  = -(1/9)g_0 - (49/429)g_4 + (2/99)g_6 + (8/39)g_8
"""
function lhy_F4_cube(g0::Real, g2::Real, g4::Real, g6::Real, g8::Real,
    n::Real, M::Real; hbar::Real=1.0)::Float64
    c0 = (1 / 9) * g0 + (98 / 429) * g4 + (40 / 99) * g6 + (10 / 39) * g8
    λspin = -(1 / 9) * g0 - (49 / 429) * g4 + (2 / 99) * g6 + (8 / 39) * g8
    n <= 0 && return 0.0
    _prefactor(M, hbar) * Float64(n)^2.5 *
    (c0^2.5 + 3 * abs(λspin)^2.5)
end

"""
    lhy_F8_octa(g0, g2, g4, g6, g8, g10, g12, g14, g16, n, M; hbar=1.0) -> Float64

F=8 cube-like octahedral (O:A_1) LHY closed form, Dy-relevant.
`g_2` excluded (O harmonic selection); all other 8 channels contribute.

    c_0 = (1/17)g_0 + (1372/12597)g_4 + (64/22287)g_6 + (330/5681)g_8
        + (40768/200583)g_10 + (1651420/5816907)g_12
        + (37856/365769)g_14 + (1714570/9490743)g_16

    λ_spin = -(1/17)g_0 - (10633/113373)g_4 - (8/3933)g_6 - (165/5681)g_8
           - (5096/106191)g_10 + (412855/17450721)g_12
           + (52052/1097307)g_14 + (13716560/85416687)g_16
"""
function lhy_F8_octa(g0::Real, g2::Real, g4::Real, g6::Real, g8::Real,
    g10::Real, g12::Real, g14::Real, g16::Real,
    n::Real, M::Real; hbar::Real=1.0)::Float64
    c0 =
        (1 / 17) * g0 +
        (1372 / 12597) * g4 +
        (64 / 22287) * g6 +
        (330 / 5681) * g8 +
        (40768 / 200583) * g10 +
        (1651420 / 5816907) * g12 +
        (37856 / 365769) * g14 +
        (1714570 / 9490743) * g16
    λspin =
        -(1 / 17) * g0 -
        (10633 / 113373) * g4 -
        (8 / 3933) * g6 -
        (165 / 5681) * g8 -
        (5096 / 106191) * g10 +
        (412855 / 17450721) * g12 +
        (52052 / 1097307) * g14 +
        (13716560 / 85416687) * g16
    n <= 0 && return 0.0
    _prefactor(M, hbar) * Float64(n)^2.5 *
    (c0^2.5 + 3 * abs(λspin)^2.5)
end

"""
    lhy_F10_dodec(g0, g6, g10, g12, g16, g18, g20, n, M; hbar=1.0) -> Float64

F=10 dodecahedral (I_h:A_{1g}) LHY closed form. Only the 7 contributing
channels are accepted as arguments; g_2, g_4, g_8, g_14 are excluded by
I_h harmonic selection.

    c_0 = (1/21)g_0 + (2299/24633)g_6 + (586625/3163581)g_10
        + (3135/20677)g_12 + (349448/1554777)g_16
        + (131648/736281)g_18 + (15895/134199)g_20

    λ_spin = -(1/21)g_0 - (18601/246330)g_6 - (586625/6327162)g_10
           - (912/20677)g_12 + (412984/7773885)g_16
           + (365024/3681405)g_18 + (14450/134199)g_20
"""
function lhy_F10_dodec(g0::Real, g6::Real, g10::Real, g12::Real,
    g16::Real, g18::Real, g20::Real,
    n::Real, M::Real; hbar::Real=1.0)::Float64
    c0 =
        (1 / 21) * g0 +
        (2299 / 24633) * g6 +
        (586625 / 3163581) * g10 +
        (3135 / 20677) * g12 +
        (349448 / 1554777) * g16 +
        (131648 / 736281) * g18 +
        (15895 / 134199) * g20
    λspin =
        -(1 / 21) * g0 -
        (18601 / 246330) * g6 -
        (586625 / 6327162) * g10 -
        (912 / 20677) * g12 +
        (412984 / 7773885) * g16 +
        (365024 / 3681405) * g18 +
        (14450 / 134199) * g20
    n <= 0 && return 0.0
    _prefactor(M, hbar) * Float64(n)^2.5 *
    (c0^2.5 + 3 * abs(λspin)^2.5)
end

end # module LHYModesRound45
