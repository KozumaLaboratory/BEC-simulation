# test/oracles/test_light_shift_analytic.jl
#
# The LightShiftTerm is the AC-Stark / light-shift operator
#   H_LS(r) = I(r) · M ,   M = M_vector + M_tensor   (D×D Hermitian, r-independent)
#     M_vector = (α_v/F) · (i ε̂*×ε̂)·F̂
#     M_tensor = (α_t / (F(2F−1))) · (3 (ε̂·F̂)² − F(F+1) I)
# where I(r) = ls.profile is the spatial intensity and ε̂ the (unit) polarization.
#
# apply_operator! is a REAL implementation (the Trinity gradient face):
#   δE/δψ̄_c(r) = profile(r) · Σ_{c'} M[c,c'] ψ_{c'}(r)   — i.e. (M·ψ) scaled voxel-wise.
# energy_contribution is the closed form
#   E_LS = ∫ I(r) ⟨ψ(r)|M|ψ(r)⟩ dV = Σ_r profile(r) · Re(ψ† M ψ) · dV.
#
# Non-tautology guard: M here is rebuilt FROM THE PHYSICS FORMULA in the test
# (vector + tensor closed forms), NOT read back from ls.U / ls.eigvals. A wrong
# sign/factor/index in the src eigendecomposition or the M·ψ broadcast fails this.
# A polarization with both circular and tensor content is chosen so M is genuinely
# OFF-DIAGONAL (is_diagonal == false), exercising the U·Λ·U† path of _grad_light_shift!.

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC:
    LightShiftTerm, apply_operator!, energy_contribution,
    spin_matrices, make_light_shift

@testset "LightShiftTerm = profile·M·ψ, E = ∫ I ⟨ψ|M|ψ⟩" begin
    for (atom, F) in ((Rb87, 1), (Eu151, 6))
        npts = (6, 6, 6)
        grid = make_grid(GridConfig(npts, (4.0, 4.0, 4.0)))
        D = 2F + 1
        dV = cell_volume(grid)
        sm = spin_matrices(F)
        Fx = Matrix{ComplexF64}(sm.Fx)
        Fy = Matrix{ComplexF64}(sm.Fy)
        Fz = Matrix{ComplexF64}(sm.Fz)

        # Polarization with both σ⁺ circular content (→ vector part, off-diagonal)
        # and a non-axial component (→ tensor part). Normalize as src does.
        eps = ComplexF64[1.0, 0.5im, 0.3]
        eps ./= norm(eps)
        alpha_v = 0.37
        alpha_t = -0.21

        # Independent M from the physics closed forms (the non-tautology anchor).
        cross_vec = im .* cross(conj.(eps), eps)
        Mv = real(cross_vec[1]) * Fx + real(cross_vec[2]) * Fy + real(cross_vec[3]) * Fz
        eFhat = eps[1] * Fx + eps[2] * Fy + eps[3] * Fz
        eFhat_sq = eFhat' * eFhat
        Mt = 3.0 .* eFhat_sq .- F * (F + 1) * Matrix{ComplexF64}(I, D, D)
        denom = Float64(F * (2F - 1))
        M = (alpha_v / F) .* Mv .+ (alpha_t / denom) .* Mt   # D×D Hermitian

        # Spatially-varying real intensity profile I(r).
        profile = Array{Float64}(undef, npts...)
        @inbounds for I in CartesianIndices(npts)
            profile[I] = 0.5 + 0.1 * (I[1] + 2 * I[2] - I[3])
        end

        ls = make_light_shift(;
            F, polarization=Tuple(eps),
            alpha_vector=alpha_v, alpha_tensor=alpha_t,
            profile,
        )

        ws = make_workspace(;
            grid, atom,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            light_shift=ls,
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            fft_flags=FFTW.ESTIMATE,
        )

        psi = randn(ComplexF64, npts..., D)

        @testset "F=$F (off-diagonal path active: $(!ls.is_diagonal))" begin
            # The chosen polarization must yield a genuine off-diagonal operator,
            # otherwise the U·Λ·U† branch of _grad_light_shift! is never tested.
            @test !ls.is_diagonal

            # apply_operator! = profile · M · ψ, voxel-wise.
            expected = similar(psi)
            E_expected = 0.0
            @inbounds for I in CartesianIndices(npts)
                v = psi[I, :]
                expected[I, :] = profile[I] .* (M * v)
                E_expected += profile[I] * real(v' * M * v)
            end
            E_expected *= dV

            out = zero(psi)
            apply_operator!(out, LightShiftTerm(), ws, psi)
            @test isapprox(out, expected; rtol=1e-10, atol=1e-12)

            E = energy_contribution(LightShiftTerm(), psi, ws)
            @test isapprox(E, E_expected; rtol=1e-10, atol=1e-12)

            # Hermiticity sanity of the rebuilt operator (sign/factor structural check).
            @test isapprox(M, M'; rtol=1e-12, atol=1e-12)
        end
    end
end
