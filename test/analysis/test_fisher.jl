using Test
using LinearAlgebra
using Random
using SpinorBEC: fisher_jacobian, fisher_information, identifiable_directions

@testset "Fisher information utilities" begin
    @testset "Jacobian of analytic linear function recovers exact A" begin
        A = [1.0 2.0; 3.0 4.0; 5.0 6.0]
        forward = θ -> A * θ
        J = fisher_jacobian(forward, [1.0, 2.0], identity)
        @test J ≈ A atol = 1e-6
    end

    @testset "Jacobian of nonlinear y(θ) matches analytic gradient" begin
        # y = [θ_1², θ_1·θ_2, θ_2²] at θ=(1, 2) ⇒ J = [[2,0],[2,1],[0,4]]
        forward = θ -> [θ[1]^2, θ[1] * θ[2], θ[2]^2]
        J = fisher_jacobian(forward, [1.0, 2.0], identity)
        @test J ≈ [2.0 0.0; 2.0 1.0; 0.0 4.0] atol = 1e-5
    end

    @testset "Jacobian with custom summary fn (subset selection)" begin
        forward = θ -> Dict(:a => θ[1] + θ[2], :b => θ[1] - θ[2], :c => θ[1] * θ[2])
        summary = out -> [out[:a], out[:b]]   # drop :c
        J = fisher_jacobian(forward, [3.0, 4.0], summary)
        @test J ≈ [1.0 1.0; 1.0 -1.0] atol = 1e-5
    end

    @testset "FD step floor for zero nominal" begin
        # θ = 0 still gets a finite step via delta_floor
        forward = θ -> [θ[1]^3]
        J = fisher_jacobian(forward, [0.0], identity; delta_floor=1e-4)
        @test isapprox(J[1, 1], 0.0; atol=1e-6)  # ∂(θ³)/∂θ at 0 is 0
    end

    @testset "Fisher information of identity model" begin
        forward = θ -> collect(θ)
        J = fisher_jacobian(forward, [1.0, 2.0], identity)
        fish = fisher_information(J, [1.0, 1.0])
        @test fish.matrix ≈ Matrix{Float64}(I, 2, 2) atol = 1e-5
        @test sort(fish.eigenvalues) ≈ [1.0, 1.0] atol = 1e-5
    end

    @testset "Fisher information rejects bad inputs" begin
        J = rand(3, 2)
        @test_throws DimensionMismatch fisher_information(J, [1.0, 1.0])      # wrong length
        @test_throws ArgumentError fisher_information(J, [1.0, 1.0, 0.0])    # zero σ
        @test_throws ArgumentError fisher_information(J, [1.0, 1.0, -1.0])   # negative σ
    end

    @testset "SVD consistency: I = JᵀJ ⇒ eigvals(I) = svd(J).S²" begin
        rng = MersenneTwister(42)
        J = randn(rng, 5, 3)
        fish = fisher_information(J, ones(5))
        svals = svd(J).S
        @test sort(fish.eigenvalues) ≈ sort(svals .^ 2) atol = 1e-10
    end

    @testset "Degenerate direction → null eigenvector" begin
        # Only θ₁ + θ₂ is observed; θ₁ − θ₂ is unidentifiable.
        forward = θ -> [θ[1] + θ[2]]
        J = fisher_jacobian(forward, [0.5, 0.5], identity)
        fish = fisher_information(J, [1.0])
        ident = identifiable_directions(fish; cutoff_ratio=1e-6)
        @test ident.measurable_count == 1
        null_idx = findfirst(.!ident.is_identifiable)
        null_vec = ident.eigenvectors[:, null_idx]
        # null vector should be aligned with (1, -1)/√2 (up to global sign)
        @test abs(abs(null_vec[1]) - abs(null_vec[2])) < 1e-6
        @test sign(null_vec[1]) == -sign(null_vec[2])
        # posterior σ is Inf for the null direction
        @test ident.posterior_sigma[null_idx] == Inf
    end

    @testset "Full rank ⇒ all measurable + finite posterior σ" begin
        rng = MersenneTwister(7)
        J = randn(rng, 8, 3)
        fish = fisher_information(J, ones(8))
        ident = identifiable_directions(fish; cutoff_ratio=1e-6)
        @test ident.measurable_count == 3
        @test all(isfinite, ident.posterior_sigma)
        @test all(ident.is_identifiable)
    end

    @testset "Anisotropic noise rescales Fisher correctly" begin
        # If σ_y_i doubles, the corresponding row of (Σ⁻¹/²J) halves, so the
        # contribution to I drops by 4× — Fisher eigenvalues scale accordingly.
        forward = θ -> [θ[1], θ[2]]
        J = fisher_jacobian(forward, [1.0, 1.0], identity)
        f1 = fisher_information(J, [1.0, 1.0])
        f2 = fisher_information(J, [1.0, 2.0])
        # Sum of eigenvalues = trace = 1/σ_y_1² + 1/σ_y_2² = 1 + 0.25 = 1.25
        @test sum(f1.eigenvalues) ≈ 2.0 atol = 1e-5
        @test sum(f2.eigenvalues) ≈ 1.25 atol = 1e-5
    end

    @testset "Identifiable summary string respects param_names" begin
        # Single-parameter, fully identifiable model
        forward = θ -> [2.0 * θ[1]]
        J = fisher_jacobian(forward, [1.0], identity)
        fish = fisher_information(J, [1.0])
        ident = identifiable_directions(fish; param_names=["a_0"])
        @test occursin("measurable rank = 1 / 1", ident.summary)
        @test occursin("MEAS", ident.summary)
        @test occursin("a_0", ident.summary)
    end

    @testset "param_names length must match" begin
        forward = θ -> [θ[1] + θ[2]]
        J = fisher_jacobian(forward, [0.5, 0.5], identity)
        fish = fisher_information(J, [1.0])
        @test_throws DimensionMismatch identifiable_directions(fish;
            param_names=["only_one"])
    end

    @testset "Absolute cutoff rescues prior-conditioned subspace" begin
        # Synthetic: one giant direction (λ=1e6, like a prior-pinned axis)
        # plus a small but informative direction (λ=100, σ_post=0.1).
        # Relative cutoff 1e-4 rejects the small direction; absolute cutoff
        # at 1e-3 keeps it (1e-3 << 100). The script-level "rank=1" trap is
        # avoided.
        I_mat = Diagonal([1e6, 100.0])
        fish = (matrix=Matrix(I_mat),
            eigenvalues=[100.0, 1e6],
            eigenvectors=Matrix{Float64}(I, 2, 2))

        # Default: relative cutoff only ⇒ rank 1 (the trap)
        ident_rel = identifiable_directions(fish; cutoff_ratio=1e-4)
        @test ident_rel.measurable_count == 1

        # Absolute cutoff at 1e-3 ⇒ rank 2 (informative direction recovered)
        ident_abs = identifiable_directions(fish;
            cutoff_ratio=1e-4, cutoff_absolute=1e-3)
        @test ident_abs.measurable_count == 2
        @test all(isfinite, ident_abs.posterior_sigma)

        # posterior_sigma_absolute is always populated independently
        @test ident_rel.posterior_sigma_absolute ≈ [0.1, 1e-3] atol = 1e-12
        @test ident_abs.posterior_sigma_absolute ≈ [0.1, 1e-3] atol = 1e-12

        # Absolute cutoff above all eigenvalues ⇒ rank 0 (still backward-compat
        # if user wants stricter)
        ident_strict = identifiable_directions(fish;
            cutoff_ratio=10.0, cutoff_absolute=1e10)
        @test ident_strict.measurable_count == 0
    end
end
