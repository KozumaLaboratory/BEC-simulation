# TDHFB Hartree-Fock matrix kernel — generic F via CG channel decomposition.
#
# Computes h^HF_{m,m'}(r) from spinor mean-field φ_m(r), normal density ρ(r), and
# anomalous density κ(r) for the spinor BEC two-body interaction in the
# **channel-decomposed** form, as the BdG self-energy (second functional
# derivative δ²E_int / δφ_m* δφ_{m'}):
#
#   H_int = (1/2) Σ_S g_S Σ_M A_{S,M}^† A_{S,M}
#
# where A_{S,M} = Σ_{m1, m2} ⟨S M | F m1, F m2⟩ Ψ_{m1} Ψ_{m2} is the channel
# annihilation operator for total spin-S two-body interaction.
#
# This generalizes hf_matrix_F1!(...) (F=1 c_0/c_1 special case) to arbitrary F
# via Clebsch-Gordan coefficients.
#
# Reference: Kawaguchi-Ueda 2012 §3.2; CG factor X^{(S)} matches paper3 §III.

export hf_matrix_generic, hf_matrix_generic!, ku_c01_to_g_S, ku_to_g_S

"""
    hf_matrix_generic!(h_hf, phi, rho, F, g_S) -> h_hf

Compute Hartree-Fock matrix h^HF[φ, ρ] for spin-F spinor BEC, local approximation,
channel-decomposed form with arbitrary `g_S` couplings.

The HF self-energy matrix element formula (BdG convention, second derivative):

  h^HF_{m,m'}(r) = 2 Σ_S g_S Σ_M Σ_{m2, m2'}
                    ⟨F m, F m2 | S M⟩ ⟨S M | F m', F m2'⟩
                    × ( φ_{m2'}* φ_{m2}(r) + ρ_{m2',m2}(r) )

This is **NOT** the GP Hamiltonian acting on φ (= first derivative δE/δφ*_m / φ);
this is the **BdG self-energy** (second derivative δ²E/δφ*_m δφ_{m'}), used as
the diagonal block in the Bogoliubov-de Gennes matrix L(k) = ε_k I + h^HF - μ I.

The factor 2 arises from differentiating E_int twice: the symmetric structure
of A_{S,M} A†_{S,M} gives 4× from the two pairs of contractions, halved by the
overall 1/2 in H_int = (1/2) Σ_S g_S A†A.

To recover the GP Hamiltonian, divide h^HF · φ by φ (= the first-derivative
form used by `hf_matrix_F1!`). Both forms are equivalent for Bogoliubov physics
but differ by factor 2 in the diagonal matrix element where m₂ = m₂' (self-pair).

(Anomalous κ term is **not** included at this Phase 2 scope; that contributes
to ∂κ/∂t equations, not the diagonal Bogoliubov-Hartree-Fock kernel acting on φ.)

# Arguments
- `h_hf::Array{ComplexF64, N+2}`: output, shape (spatial..., D, D) with D = 2F+1
- `phi::Array{ComplexF64, N+1}`: mean field, shape (spatial..., D)
- `rho::Array{ComplexF64, N+2}`: normal density, shape (spatial..., D, D); set to
  `zeros` for pure mean-field limit (Phase 2 entry point)
- `F::Int`: spin quantum number (e.g. F=1, 3, 6)
- `g_S::AbstractDict{Int, Float64}`: channel couplings, key = total spin S
  (must be even non-negative integers, 0 ≤ S ≤ 2F by triangle inequality)

# Notes
- D = 2F+1.
- Indices in the spinor axis are 1-based with the convention `c = 1 ↔ m = +F`,
  `c = D ↔ m = -F` (consistent with SpinorBEC.jl `_get_spinor` indexing).
- Hermiticity: h^HF[r, m, m'] = conj(h^HF[r, m', m]) — verified in test.
- Local approximation: depends only on point r.
- Channel keys missing from `g_S` are treated as zero coupling.

# Returns
The h_hf array (for chaining).
"""
# NOT GENERALIZABLE: this kernel is the BdG self-energy, not the GP Hamiltonian.
# Reason: math
# Why: returns δ²E_int/δφ_m*δφ_{m'} (diagonal block of L(k) in
#   Bogoliubov-de Gennes). Factor-2 Bose symmetrisation here is deliberate
#   and absent from `hf_matrix_F1!`. Use this kernel for BdG spectra; use
#   `hf_matrix_F1!` for GP evolution (factor 2 would double-count).
# See: src/hamiltonian/tdhfb/hartree_fock_matrix.jl (GP-form twin), Paper #3 §III
function hf_matrix_generic!(
    h_hf::AbstractArray,
    phi::AbstractArray,
    rho::AbstractArray,
    F::Int,
    g_S::AbstractDict{Int, Float64},
)
    D = 2 * F + 1
    sz = size(phi)
    n_spatial = length(sz) - 1
    @assert sz[end] == D "phi last-axis dimension must be 2F+1 = $D"
    @assert size(h_hf, ndims(h_hf)) == D
    @assert size(h_hf, ndims(h_hf) - 1) == D

    # Rank-4 channel projector with factor-2 Bose symmetrization. Shared with
    # `pair_potential_generic!`, which uses the un-symmetrized form directly.
    P = channel_kernel_symmetrized(F, g_S)

    # Now apply to (φ, ρ) at every spatial point
    for idx in CartesianIndices(size(phi)[1:n_spatial])
        for c in 1:D, c_p in 1:D
            val = ComplexF64(0)
            for c2 in 1:D, c2_p in 1:D
                # ( φ_{m2'}* φ_{m2} + ρ_{m2', m2} )
                # NOTE: in our index convention with c indexing m=+F down to -F,
                # the ρ matrix is stored as rho[idx, c, c'] = ⟨m(c) | ρ̂ | m(c')⟩.
                # The HF formula uses ρ_{m2', m2} which is the matrix element
                # in the standard "physicist" convention.
                # We align: ρ_{m2', m2} = rho[idx, c2_p, c2].
                contrib = conj(phi[idx, c2_p]) * phi[idx, c2] + rho[idx, c2_p, c2]
                val += P[c, c_p, c2, c2_p] * contrib
            end
            h_hf[idx, c, c_p] = val
        end
    end

    return h_hf
end

"""
    hf_matrix_generic(phi, rho, F, g_S) -> h_hf

Allocating version of [`hf_matrix_generic!`](@ref).
"""
function hf_matrix_generic(
    phi::AbstractArray,
    rho::AbstractArray,
    F::Int,
    g_S::AbstractDict{Int, Float64},
)
    D = 2 * F + 1
    sz = size(phi)
    n_spatial = length(sz) - 1
    h_hf = zeros(ComplexF64, sz[1:n_spatial]..., D, D)
    return hf_matrix_generic!(h_hf, phi, rho, F, g_S)
end

"""
    ku_c01_to_g_S(F, c0, c1) → Dict{Int, Float64}

Convert Kawaguchi-Ueda (c_0, c_1) couplings to channel-decomposed
couplings `g_S` for arbitrary F via the physical spin-spin scalar form

    g_S = c_0 + c_1 · (S(S+1) − 2F(F+1)) / 2     for S ∈ 0:2:2F

This is the same closed-form used by the GP / BdG splitter (see
`_c0c1_to_gS` in `interactions.jl`); the public alias here is kept so
TDHFB callers don't reach into the underscored helper.

For F ≥ 2 the two parameters (c_0, c_1) constrain F+1 independent channels
to a one-parameter family — appropriate when higher scattering lengths
are unknown (e.g. Eu151 a_S for S ≥ 4). To inject independent g_S, layer
in `c_extra` via [`ku_to_g_S`](@ref) or build the tensor cache directly
with `_make_tensor_cache_from_channels`.

# Round-trip with `_gS_to_cn`
`_gS_to_cn(F, ku_c01_to_g_S(F, c_0, c_1))` returns the rank-k tensor
decomposition `{c₀, c₂, c₄, …}`; for F=1 this recovers
`c₀ → c_0 − (4/3) c_1`, `c₂ → (2/3) c_1` (the rank-2 KU form, which is
NOT the same as the `c_1` parameter — see KU 2012 §2 for the
distinction).
"""
function ku_c01_to_g_S(F::Int, c0::Float64, c1::Float64)
    _c0c1_to_gS(F, c0, c1)
end

"""
    ku_to_g_S(F, c0, c1, c_extra) → Dict{Int, Float64}

Full Kawaguchi-Ueda forward map for arbitrary F. Returns channel-decomposed
`g_S` (for S ∈ 0:2:2F) given the scalar/spin-spin couplings (c_0, c_1)
plus the even-rank tensor couplings in `c_extra` (index k ↔ c_{k+1}, so
`c_extra[1] = c₂`, `c_extra[3] = c₄`, …).

The combined formula is

    g_S = (c_0 + c_1 · ⟨F̂_1·F̂_2⟩_S)  +  Σ_{k even, k≥2} (2k+1) {F F k; F F S} c_k

For Eu151 (F=6) with seven independent channels (S=0,2,…,12), pass
`c_extra = even_c_extra(6; c2=…, c4=…, c6=…, c8=…, c10=…, c12=…)` to
specify all seven g_S at once.

Validated against `_gS_to_cn` for round-trip identity at F=1/2/3/6 in
`test/hamiltonian/test_tdhfb_ku_c01_to_g_S.jl`.
"""
function ku_to_g_S(F::Int, c0::Float64, c1::Float64, c_extra::Dict{Int, Float64})
    # Build the c_n Dict and route through the unified c_to_g.
    c = merge(Dict(0 => c0, 1 => c1), c_extra)
    c_to_g(F, InteractionParams(c))
end
