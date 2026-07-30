# NOT GENERALIZABLE: F=6 I_h closed form is unique to its harmonic decomposition.
# Reason: math
# Why: g_2, g_4, g_8 cancel ONLY because the icosahedron has no symmetric
#   rank-2/4/8 invariant aligned with the I_h spinor; other (F, point-group)
#   pairings have different cancellations and different stiffness branches.
# See: docs/manuscript/papers/paper3_universal_theorem/main.md §V.D
#
# icosahedral_lhy.jl
# =================================================================
# Closed-form contact LHY for the F=6 icosahedral (I_h) phase
# (Stage D, parallel-session derivation 2026-05-07).
#
# The 7 stiffness coefficients (c_0, λ_spin) here
# are specific to the F=6 I_h harmonic decomposition: g_2, g_4, g_8
# cancel because the icosahedron has no symmetric rank-2/4/8 invariant
# aligned with the I_h state. Different polyhedral inert states (e.g.
# F=10 I:A dodec, F=12 I:A) have different closed forms — see
# `lhy_F10_dodec` (Paper #3 §V.F) and the FM/polar §V.E entries. Each
# F-point-group pairing requires its own sympy derivation; there is no
# single closed form that covers all F at the I_h symmetry.
#
# The F=6 I_h ground state spinor lives in the m=±5 / m=0 doublet:
#
#     ζ_{I_h} = (0, √7/5, 0, 0, 0, 0, √11/5, 0, 0, 0, 0, -√7/5, 0)
#
# (component order m=+6,+5,...,-6, normalised to ⟨ζ|ζ⟩ = 1).
# Block-diagonalising the 26×26 BdG operator under the symmetry
# (mod-5 invariance + parity) gives one phonon block + a triple of
# spin-Goldstone blocks, all dressed by the same closed-form
# stiffness coefficients:
#
#     c_0       = g_0/13 + 121 g_6/323 + 147 g_10/391 + 980 g_12/5681
#     λ_spin    = -g_0/13 - 121 g_6/646 + 91 g_10/782 + 840 g_12/5681
#
# (g_2, g_4, g_8 cancel exactly under I_h harmonic decomposition —
# the icosahedron has no symmetric rank-2/4/8 invariant aligned with
# the I_h state, so those S-channel couplings drop out of LHY at
# this order.)
#
# The spinor LHY energy density follows the universal structure:
#
#     ε_LHY^{F=6,I_h}(n)
#         = (8 √M³ / (15 π² ℏ³)) · n^(5/2) · (c_0^(5/2) + 3 |λ_spin|^(5/2))
#
# The factor "3" counts the three independent spin-Goldstone blocks
# with stiffness λ_spin (the SO(3) breaking pattern for I_h is
# generic-rotation: 3 broken generators).
#
# Convention (CRITICAL):
# - g_S indexes by the *total* spin channel S ∈ {0, 2, 4, 6, 8, 10, 12}
#   for an F=6 boson pair. The coefficient table below uses the
#   `S=2k` slot — not the "even-only count" 0..6.
# - Scalar limit (uniform g_S = g): c_0 = g, λ_spin = 0; LHY collapses
#   to (8/15π²)(g·n)^(5/2) which is identical to the scalar Lima-Pelster
#   form at coupling g.

# ---------------------------------------------------------------------------
# F=6 I_h ground state spinor (component order m=+6, +5, ..., -6).
# Normalisation: ⟨ζ|ζ⟩ = 7/25 + 11/25 + 7/25 = 25/25 = 1.
# ---------------------------------------------------------------------------
const ZETA_F6_IH = ComplexF64[
    0,                          # m=+6
    sqrt(7.0) / 5,              # m=+5
    0, 0, 0, 0,                 # m=+4..+1
    sqrt(11.0) / 5,             # m=0
    0, 0, 0, 0,                 # m=-1..-4
    -sqrt(7.0) / 5,             # m=-5
    0,                          # m=-6
]

"""
    compute_c0_lambda_F6_Ih(g_S) -> (c_0, λ_spin)

Stiffness coefficients for the F=6 I_h closed-form LHY. `g_S` is a
length-7 vector indexed `[g_0, g_2, g_4, g_6, g_8, g_10, g_12]` (one
entry per even-S channel). Returns the phonon stiffness `c_0` and the
spin-Goldstone stiffness `λ_spin` (signed; LHY uses `|λ_spin|`).

In the scalar limit `g_S ≡ g`, `c_0 = g` and `λ_spin = 0` exactly.
g_2, g_4, g_8 contribute zero by I_h harmonic decomposition.
"""
function compute_c0_lambda_F6_Ih(g_S::AbstractVector{<:Real})
    length(g_S) == 7 ||
        throw(ArgumentError("g_S must have length 7 (S=0,2,4,6,8,10,12), got $(length(g_S))"))
    g0, _g2, _g4, g6, _g8, g10, g12 = g_S
    c0 = g0 / 13 + 121 * g6 / 323 + 147 * g10 / 391 + 980 * g12 / 5681
    lambda_spin = -g0 / 13 - 121 * g6 / 646 + 91 * g10 / 782 + 840 * g12 / 5681
    return (c0, lambda_spin)
end

"""
    compute_c0_lambda_F6_Ih(g_dict::AbstractDict) -> (c_0, λ_spin)

Convenience overload: extracts `g_dict[S]` for S ∈ {0,2,4,6,8,10,12},
defaulting missing channels to 0. Accepts the same `g_dict` shape as
`build_polar_lhy_coefs` etc.
"""
function compute_c0_lambda_F6_Ih(g_dict::AbstractDict)
    g_vec = Float64[Float64(get(g_dict, 2k, 0.0)) for k in 0:6]
    return compute_c0_lambda_F6_Ih(g_vec)
end

"""
    epsilon_LHY_F6_Ih(n, g_S; M_mass=1.0, hbar=1.0) -> Float64

LHY energy density for the F=6 icosahedral (I_h) phase at density `n`.

    ε = (8 √M³ / (15 π² ℏ³)) · n^(5/2) · (c_0^(5/2) + 3 |λ_spin|^(5/2))

Returns 0 for `n ≤ 0` or when both stiffnesses vanish. Returns NaN, and
so refuses to answer, in the two regimes where the closed form does not
apply — `_tabulate_lhy` turns that into a loud error rather than a NaN
table:

- `c_0 < 0` — the I_h state is not the ground state of the contact
  Hamiltonian.
- `λ_spin < 0` — the spin-Goldstone branch is dynamically unstable. The
  `|λ_spin|` below would otherwise make ε exactly symmetric under
  `λ_spin → −λ_spin` and report a real energy for a state whose BdG
  branches are complex. Measured against `full_bdg` at F=6, c₀=10:
  0.4 % / 2.1 % / 11.0 % high at c₁ = −0.05 / −0.1 / −0.2, growing with
  the instability (`full_bdg` reports max Im ω = 2.8 at c₁ = −0.2 and
  warns that ε_LHY is scheme-dependent there). Gated by
  `test/oracles/test_lhy_full_bdg_closed_form_parity.jl`.

Both cases want `full_bdg`, which diagonalises rather than assuming the
branch structure. `c₁ < 0` is the sign Eu F=6 production uses, so this
guard changes live configurations from a wrong number to an error.
"""
function epsilon_LHY_F6_Ih(n::Real, g_S::Union{AbstractVector{<:Real}, AbstractDict};
    M_mass::Real=1.0, hbar::Real=1.0)::Float64
    n <= 0 && return 0.0
    c0, lambda_spin = compute_c0_lambda_F6_Ih(g_S)
    c0 < 0 && return NaN            # I_h not the GS
    # Round-off band, not a physics band: at uniform g_S the cancellation
    # −g₀/13 − 121g₆/646 + 91g₁₀/782 + 840g₁₂/5681 leaves λ_spin at −2.2e-16
    # rather than exactly 0, and the scalar limit must not be refused.
    lambda_spin < -1e-12 * c0 && return NaN   # spin-Goldstone branch unstable
    prefactor = (8.0 * sqrt(Float64(M_mass)^3)) / (15.0 * π^2 * Float64(hbar)^3)
    return prefactor * Float64(n)^2.5 *
           (c0^2.5 + 3 * abs(Float64(lambda_spin))^2.5)
end

export ZETA_F6_IH, compute_c0_lambda_F6_Ih, epsilon_LHY_F6_Ih
