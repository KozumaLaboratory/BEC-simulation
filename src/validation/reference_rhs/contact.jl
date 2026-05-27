# --- Reference Hψ: spinor contact (c₁ spin, c₂ singlet pair, c_n tensors) ---
#
# Conventions (matched to src/analysis/energy.jl):
#   c₁:  ε = (c₁/2) |F(r)|²        → (H_c₁ ψ)_c(r) = c₁ Σ_α f_α(r) (F_α ψ)_c
#   c₂:  ε = (c₂/2) |A_{00}(r)|²   → (H_c₂ ψ)_c(r) = (c₂/√D) σ_c A_{00}(r) ψ_{c_pair}*(r)
#                                    where σ_c = (-1)^{F-m_c}, c_pair = D-c+1.
#   c_n (n ≥ 4): general tensor channel, currently NOT included here.
#         Production routes these through `tensor_cache`; reference
#         coverage for c_n ≥ 4 is deferred until a need surfaces.
#         (Eu requires c_4, c_6, …; the c_n=0 case used in scalar /
#         spin-1 / spin-2 tests is fully covered.)

export reference_spin_apply!, reference_spin_energy
export reference_singlet_pair_apply!, reference_singlet_pair_energy

"""
    reference_spin_apply!(out, psi, sm, c1)

Write the c₁ spin GP nonlinear term:
`(H_c₁ ψ)_c(r) = c₁ Σ_α f_α(r) (F_α ψ)_c(r)`
where `f_α(r) = ⟨ψ(r)|F_α|ψ(r)⟩` is the local spin density.

Propagator shape (no 1/2). The corresponding energy
`reference_spin_energy` carries the 1/2.
"""
function reference_spin_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    c1::Real,
) where {D}
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    Fx = sm.Fx
    Fy = sm.Fy
    Fz = sm.Fz
    @inbounds for I in CartesianIndices(n_pts)
        fxI = fx[I]
        fyI = fy[I]
        fzI = fz[I]
        for c in 1:D
            s = zero(ComplexF64)
            for cp in 1:D
                s += (fxI * Fx[c, cp] + fyI * Fy[c, cp] + fzI * Fz[c, cp]) * psi[I, cp]
            end
            out[I, c] = c1 * s
        end
    end
    out
end

"""
    reference_spin_energy(psi, sm, c1, grid) → Float64

`E_c₁ = (c₁/2) ∫ |F(r)|² dV`. Matches `_spin_interaction_energy`.
"""
function reference_spin_energy(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    c1::Real,
    grid::Grid{N},
) where {D, N}
    fx, fy, fz = spin_density_vector(psi, sm, N)
    dV = cell_volume(grid)
    s = 0.0
    @inbounds for i in eachindex(fx, fy, fz)
        s += fx[i]^2 + fy[i]^2 + fz[i]^2
    end
    0.5 * c1 * s * dV
end

"""
    reference_singlet_pair_apply!(out, psi, F, c2)

Write the c₂ singlet-pair GP nonlinear term:
`(H_c₂ ψ)_c(r) = (c₂/√D) σ_c A_{00}(r) conj(ψ_{c_pair}(r))`
where `σ_c = (-1)^{F-m_c}`, `c_pair = D - c + 1`,
`A_{00}(r) = (1/√D) Σ_m (-1)^{F-m} ψ_m(r) ψ_{-m}(r)`,
`D = 2F+1`.

Note the conj(ψ): the c₂ term is "anomalous" — its functional
derivative δE/δψ_c* picks ψ_{c_pair}* rather than ψ. Verified via
⟨ψ|H_c₂|ψ⟩ = c₂ ∫|A_{00}|² dV = 2 E_c₂ (energy carries 1/2).
"""
function reference_singlet_pair_apply!(
    out::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    F::Int,
    c2::Real,
)
    D = 2F + 1
    ndim = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    A = singlet_pair_amplitude(psi, F, ndim)
    inv_sqrt_D = 1.0 / sqrt(Float64(D))
    coeff = c2 * inv_sqrt_D
    @inbounds for I in CartesianIndices(n_pts)
        AI = A[I]
        for c in 1:D
            m_c = F - (c - 1)
            sgn = iseven(F - m_c) ? 1.0 : -1.0
            c_pair = D - c + 1
            out[I, c] = coeff * sgn * AI * conj(psi[I, c_pair])
        end
    end
    out
end

"""
    reference_singlet_pair_energy(psi, F, c2, grid) → Float64

`E_c₂ = (c₂/2) ∫ |A_{00}(r)|² dV`. Matches `_singlet_pair_energy`.
"""
function reference_singlet_pair_energy(
    psi::AbstractArray{<:Complex},
    F::Int,
    c2::Real,
    grid::Grid{N},
) where {N}
    A = singlet_pair_amplitude(psi, F, N)
    dV = cell_volume(grid)
    0.5 * c2 * sum(abs2, A) * dV
end
