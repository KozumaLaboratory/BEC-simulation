# Sign Pattern Theorem (Paper #3 §VI) — runtime API
# =================================================
#
# Closed-form expressions for the channel-resolved Goldstone stiffness
# `λ_spin` and its sign-change boundary, for polyhedral inert states
# (the regime where the Universal Structure Theorem of Paper #3 applies).
#
# Paper #3 reference:
# `docs/manuscript/papers/paper3_universal_theorem/main.md` §VI.
# `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md`
# (Eq. boxed at line 282 of the derivation).
#
# Closed form (Lemma 1 General-S):
#
#     β_S^(λ_spin) = [S(S+1) − 2F(F+1)] / [2F(F+1)] · β_S^(c_0)
#
# where:
#   - β_S^(c_0) is the channel weight of the anomalous overlap
#     |⟨S, M | ζ⊗ζ⟩|² summed over M (the projector to total-spin-S
#     two-body state).
#   - β_S^(λ_spin) is the per-channel contribution to the Goldstone
#     stiffness: λ_spin = Σ_S g_S · β_S^(λ_spin).
#
# Sign-change boundary (Sign Pattern Lemma 2, unique sign change):
#
#     S_bd(F) = √(2F(F+1)) ≈ √2 · F
#
# β_S^(λ_spin) changes sign exactly once as S sweeps from 0 to 2F:
# negative for S < S_bd(F), zero at S = S_bd(F) (formally), positive
# for S > S_bd(F).
#
# Status: verified rigorously for the polyhedral inert states (Paper #3
# §V.A-F): F=2 cyclic (T_d), F=3 octahedral (O:A_2), F=4 cube (O_h),
# F=6 icosahedral (I_h), F=8 cube-like octahedral (O:A_1), F=10
# dodecahedral (I_h). Coverage extends to non-polyhedral cases per
# Paper #3 §VII (D_n axial states), but with multiplet splittings —
# this module currently exposes only the polyhedral closed form.

export sign_pattern_beta_lambda_spin, sign_change_boundary_S_bd
export sign_pattern_beta_lambda_spin_table, predict_lambda_spin_sign
export polyhedral_op_character

"""
    sign_pattern_beta_lambda_spin(S::Int, F::Int, beta_c0::Real) → Float64

Sign Pattern Lemma 1 General-S closed form (Paper #3 §VI):

    β_S^(λ_spin) = [S(S+1) − 2F(F+1)] / [2F(F+1)] · β_S^(c_0)

Applies to polyhedral inert states (the regime of the Paper #3
Universal Structure Theorem). For non-polyhedral states the rank-2
cross-channel correction is non-zero and the formula doesn't apply
directly — caller is responsible.

# Arguments
- `S`: total-spin channel, must be even and in `0..2F`.
- `F`: spinor F (≥ 1).
- `beta_c0`: channel weight β_S^(c_0) = Σ_M |⟨S, M|ζ⊗ζ⟩|².
"""
function sign_pattern_beta_lambda_spin(S::Int, F::Int, beta_c0::Real)
    F >= 1 || throw(ArgumentError("F must be ≥ 1 (got F=$F)"))
    0 <= S <= 2F || throw(ArgumentError("S=$S must be in 0..2F=$(2F)"))
    iseven(S) || throw(ArgumentError("S=$S must be even (bosonic Bogoliubov)"))
    prefactor = spin_pair_eigenvalue(S, F) / (F * (F + 1))
    Float64(prefactor) * Float64(beta_c0)
end

"""
    sign_change_boundary_S_bd(F::Int) → Float64

Sign Pattern Lemma 2 (Paper #3 §VI) — sign-change boundary of
β_S^(λ_spin) along S ∈ [0, 2F]:

    S_bd(F) = √(2F(F+1))

For S < S_bd(F): β_S^(λ_spin) < 0 (attractive Goldstone stiffness from
this channel). For S > S_bd(F): β_S^(λ_spin) > 0 (repulsive).
The boundary itself is irrational so β_S^(λ_spin) typically does not
land exactly on zero; the inequality side switches as S crosses S_bd.

Approximation: S_bd(F) ≈ √2 · F, exact at large F.
"""
function sign_change_boundary_S_bd(F::Int)::Float64
    F >= 1 || throw(ArgumentError("F must be ≥ 1 (got F=$F)"))
    sqrt(2.0 * F * (F + 1))
end

"""
    predict_lambda_spin_sign(F::Int, S::Int) → Symbol

Predict the sign of β_S^(λ_spin) from the Sign Pattern boundary:
- `:negative` if S(S+1) < 2F(F+1) (i.e. S < S_bd)
- `:positive` if S(S+1) > 2F(F+1)
- `:zero` if S(S+1) = 2F(F+1) (exact equality, rare)

Useful for Feshbach-engineering channel selection (Paper #3 abstract):
target S > S_bd(F) channels for positive λ_spin contribution.
"""
function predict_lambda_spin_sign(F::Int, S::Int)::Symbol
    F >= 1 || throw(ArgumentError("F must be ≥ 1 (got F=$F)"))
    discriminant = spin_pair_eigenvalue(S, F)
    discriminant > 0 ? :positive : (discriminant < 0 ? :negative : :zero)
end

"""
    sign_pattern_beta_lambda_spin_table(F::Int, beta_c0::AbstractDict) → Dict{Int, Float64}

Tabulate β_S^(λ_spin) over all even S ∈ 0..2F given the channel weights
β_S^(c_0). Convenience for plotting / Feshbach-engineering scans.

`beta_c0` is a dict `S => β_S^(c_0)`; missing channels default to 0.
"""
function sign_pattern_beta_lambda_spin_table(
    F::Int, beta_c0::AbstractDict{Int, <:Real}
)::Dict{Int, Float64}
    Dict{Int, Float64}(
        S => sign_pattern_beta_lambda_spin(S, F, get(beta_c0, S, 0.0))
        for S in 0:2:(2F)
    )
end

"""
    polyhedral_op_character(zeta::Vector{ComplexF64}, F::Int;
                            axis=(0.0, 0.0, 1.0), angle::Real) → ComplexF64

Compute the character `⟨ζ | U(n̂, θ) | ζ⟩` of a normalised spinor `ζ`
under the spin rotation `U(n̂, θ) = exp(-i θ n̂·F̂)`. Used to distinguish
1-dimensional irreps of a polyhedral group when Majorana geometry alone
is ambiguous (e.g. A_1 vs A_2 of O at F=7 — both give identical
β_S^(c_0); only group-action signs differ).

For polyhedral inert states, common diagnostic operations:
- C_4z (axis=(0,0,1), angle=π/2): A_1 vs A_2 under O group character;
  particularly relevant for F=3 / F=8 octahedral states.
- C_3 around body diagonal (axis=(1,1,1)/√3, angle=2π/3): tetrahedral
  vs trivial discrimination.
- C_5z (axis=(0,0,1), angle=2π/5): icosahedral discriminant.

Returns the complex character ⟨ζ | U | ζ⟩. For 1-dim irreps this equals
exactly ±1 (or e^{ikπ/n} for C_n irreps); deviations from these values
indicate the spinor is NOT in a 1-dim irrep of the chosen group operation.

**Scope caveat**: this is a low-level diagnostic. A full A_1 vs A_2
classifier requires applying all group generators and matching characters
against the rep table — that infrastructure is Paper #3 §VI scope and
not implemented here. Callers requiring rigorous irrep identification
should use the character output to disambiguate manually against the
expected ±1 value for the target irrep.
"""
function polyhedral_op_character(
    zeta::AbstractVector{ComplexF64}, F::Int;
    axis::Tuple{<:Real, <:Real, <:Real}=(0.0, 0.0, 1.0),
    angle::Real,
)
    D = 2F + 1
    length(zeta) == D ||
        throw(DimensionMismatch("zeta length $(length(zeta)) != 2F+1 = $D"))
    ax = collect(Float64, axis)
    norm_ax = sqrt(sum(x -> x*x, ax))
    norm_ax > 1e-12 || throw(ArgumentError("axis must be non-zero"))
    ax ./= norm_ax
    theta = Float64(angle)
    U = spin_rotation_matrix(F, ax[1] * theta, ax[2] * theta, ax[3] * theta)
    dot(zeta, U * Vector{ComplexF64}(zeta))
end
