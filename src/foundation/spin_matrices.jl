export spin_matrices, fp_ladder_coeff, fp_ladder_coeffs, singlet_pair_sign
export spin_pair_eigenvalue

"""
    fp_ladder_coeff([T=Float64,] F, m) -> √(F(F+1) − m(m+1))

The F₊ raising-operator matrix element ⟨F,m+1|F₊|F,m⟩. **Single source** for every
spin-ladder coefficient in the codebase — c₁ spin mixing, Raman, spatial-Zeeman,
and the DDI/c₁ gradients all delegate here so a sign or algebra change can only
happen in one place. Matches the off-diagonal of `spin_matrices(F).Fp`.
"""
@inline fp_ladder_coeff(::Type{T}, F::Integer, m) where {T <: AbstractFloat} =
    sqrt(T(F * (F + 1)) - T(m) * (T(m) + one(T)))
@inline fp_ladder_coeff(F::Integer, m) = fp_ladder_coeff(Float64, F, m)

"""
    fp_ladder_coeffs([T=Float64,] F, ::Val{D}) -> NTuple{D,T}

Per-component F₊ coefficients for the spinor layout ψ[...,c] (c=1→m=F), with the
top component (c=1) set to 0. Built from [`fp_ladder_coeff`](@ref).
"""
@inline fp_ladder_coeffs(::Type{T}, F::Integer, ::Val{D}) where {T <: AbstractFloat, D} =
    ntuple(c -> c == 1 ? zero(T) : fp_ladder_coeff(T, F, F - (c - 1)), Val(D))
@inline fp_ladder_coeffs(F::Integer, ::Val{D}) where {D} =
    fp_ladder_coeffs(Float64, F, Val(D))

"""
    singlet_pair_sign(F, m) -> ±1.0

Sign factor σ_c = (−1)^{F−m} of the spin-singlet pair amplitude. **Single source**
for the c₂ singlet-pairing propagator and gradient.
"""
@inline singlet_pair_sign(F::Integer, m::Integer) = iseven(F - m) ? 1.0 : -1.0

"""
    spin_pair_eigenvalue(S, F) -> λ_S = (S(S+1) − 2F(F+1)) / 2

Eigenvalue of the two-body spin-pair operator F̂₁·F̂₂ on the total-spin-S
subspace. **Single source** for the c₀/c₁ → g_S channel algebra
(`g_S = c₀ + c₁·λ_S`, `hamiltonian/coefficients.jl`) and the Sign-Pattern
Goldstone-stiffness prefactor (`analysis/phases/sign_pattern.jl`). Anchored to
spec(F̂₁·F̂₂) by `test/oracles/test_cg_projection_oracle.jl`.
"""
@inline spin_pair_eigenvalue(S::Integer, F::Integer) =
    (S * (S + 1) - 2 * F * (F + 1)) / 2

function spin_matrices(F::Int)
    sys = SpinSystem(F)
    n = sys.n_components
    m = sys.m_values

    Fp_dense = zeros(ComplexF64, n, n)
    Fm_dense = zeros(ComplexF64, n, n)
    Fz_dense = zeros(ComplexF64, n, n)

    for i in 1:n
        Fz_dense[i, i] = m[i]
    end

    # F+ raises m by 1: F+|F,m⟩ = √(F(F+1)-m(m+1)) |F,m+1⟩
    # Matrix element: ⟨F,m'|F+|F,m⟩ = √(F(F+1)-m(m+1)) δ_{m',m+1}
    # Row index i corresponds to m[i], col j to m[j]
    # We need m[i] = m[j] + 1
    for j in 1:n, i in 1:n
        if m[i] == m[j] + 1
            Fp_dense[i, j] = fp_ladder_coeff(F, m[j])
        end
    end

    Fm_dense .= Fp_dense'

    Fx_dense = (Fp_dense .+ Fm_dense) ./ 2
    Fy_dense = (Fp_dense .- Fm_dense) ./ (2im)

    F_dot_F_dense = Fx_dense^2 + Fy_dense^2 + Fz_dense^2

    Fx = SMatrix{n, n, ComplexF64}(Fx_dense)
    Fy = SMatrix{n, n, ComplexF64}(Fy_dense)
    Fz = SMatrix{n, n, ComplexF64}(Fz_dense)
    Fp = SMatrix{n, n, ComplexF64}(Fp_dense)
    Fm = SMatrix{n, n, ComplexF64}(Fm_dense)
    FdF = SMatrix{n, n, ComplexF64}(F_dot_F_dense)

    eig_Fy = eigen(Hermitian(Fy_dense))
    # Euler angle recurrence in spinor_utils.jl assumes eigenvalues are -F, -F+1, ..., F.
    # eigen(Hermitian(...)) guarantees ascending order; verify unit spacing.
    @assert all(i -> abs(eig_Fy.values[i + 1] - eig_Fy.values[i] - 1.0) < 1e-10, 1:(n - 1)) (
        "Fy eigenvalues not uniformly spaced: $(eig_Fy.values)"
    )
    V_Fy = Matrix{ComplexF64}(eig_Fy.vectors)
    Vt_Fy = Matrix{ComplexF64}(eig_Fy.vectors')
    λ_Fy = SVector{n, Float64}(eig_Fy.values)

    M = typeof(Fx)
    SpinMatrices{n, M}(Fx, Fy, Fz, Fp, Fm, FdF, sys, V_Fy, Vt_Fy, λ_Fy)
end
