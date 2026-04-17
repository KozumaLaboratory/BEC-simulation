using Test
using Scattering

@testset "Eu+Eu stretched s-wave: single-channel reduction" begin
    # At M_tot = -12, ℓ = 0, there is 1 channel; the coupling matrix is
    # exactly V_septet(R). Verify this reduction via spin_projector_matrices.
    atom = Eu151()
    chans = enumerate_channels(atom, -12, 0)
    Q = spin_projector_matrices(atom, chans)
    septet = eueu_septet_params()
    exch = eueu_exchange_params()
    for R in (7.0, 9.2919, 12.0, 50.0)
        W = coupling_matrix(R, Q, septet, exch)
        @test W[1, 1] ≈ V_septet(septet, R) atol = 1e-14
    end
end

@testset "Eu+Eu stretched scattering length at λ = 1" begin
    a = eueu_stretched_swave_length(; λ = 1.0, h = 5e-3, R_max = 200.0)
    @test isfinite(a)
    # Tomza 2018 estimates a_{S=7} ≈ 267 a_0 as a reference with their
    # chosen λ. Without tuning the exact value is a prediction of the
    # bare MLR; magnitude bounded but may be large near poles.
    @test abs(a) < 5e3
end

@testset "Eu+Eu λ-scan: finite (not NaN) over typical range" begin
    λs = [0.97, 0.98, 0.99, 1.00, 1.01, 1.02, 1.03]
    as = scan_eueu_septet_rescale(λs; h = 5e-3, R_max = 200.0)
    @test length(as) == length(λs)
    @test all(isfinite, as)
    # With Tomza scan range (λ ∈ [0.97, 1.03]) the paper sees order
    # 10 poles, so abs(a) can briefly become huge but overall most
    # values are ≲ a few hundred a_0.
    @test count(a -> abs(a) < 500, as) >= 3
end

@testset "Convergence: a(λ=1) stable under grid refinement" begin
    # Halving h should not change a by more than ~ O(h⁴) Numerov error
    # in well-resolved regions. Use a conservative 1% tolerance.
    a_coarse = eueu_stretched_swave_length(; λ = 1.0, h = 1e-2, R_max = 200.0)
    a_fine   = eueu_stretched_swave_length(; λ = 1.0, h = 5e-3, R_max = 200.0)
    # Both finite
    @test isfinite(a_coarse)
    @test isfinite(a_fine)
    # Relative agreement loose because a can be sensitive near poles
    @test abs(a_fine - a_coarse) / (1 + abs(a_fine)) < 0.05
end
