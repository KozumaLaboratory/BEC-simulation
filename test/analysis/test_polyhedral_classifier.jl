using Test
using SpinorBEC: polyhedral_fingerprint, polyhedral_candidate_spinors,
    classify_polyhedral, direct_eff_coupling, direct_eff_coupling_delta

@testset "Polyhedral σ_S fingerprint classifier (F=6)" begin
    F = 6
    candidates = polyhedral_candidate_spinors(F)

    @testset "Required canonical states present" begin
        for label in (:polar, :FM, :cyclic, :biaxial_nematic, :I_h)
            @test haskey(candidates, label)
        end
    end

    @testset "Fingerprint normalisation Σ_S σ_S = ⟨ζ|ζ⟩²" begin
        # For normalised ζ, channel completeness gives Σ_S σ_S = 1
        for (label, ζ) in candidates
            fp = polyhedral_fingerprint(ζ, F)
            total = sum(values(fp))
            @test total ≈ 1.0 atol = 1e-10
            @test all(σ -> σ >= -1e-12, values(fp))
        end
    end

    @testset "FM σ_{S=2F} = 1, others = 0" begin
        # Stretched pair |F,+F⟩|F,+F⟩ has total spin S=2F exclusively.
        fp = polyhedral_fingerprint(candidates[:FM], F)
        @test fp[2F] ≈ 1.0 atol = 1e-10
        for S in 0:2:(2F - 2)
            @test fp[S] ≈ 0.0 atol = 1e-10
        end
    end

    @testset "polar σ_{S=0} = 1/(2F+1)" begin
        # Two atoms at m=0: |F,0⟩|F,0⟩ in singlet channel has CG² = 1/(2F+1).
        fp = polyhedral_fingerprint(candidates[:polar], F)
        @test fp[0] ≈ 1 / (2F + 1) atol = 1e-10
    end

    @testset "Cyclic and biaxial fingerprints are distinct" begin
        fp_cyc = polyhedral_fingerprint(candidates[:cyclic], F)
        fp_bi = polyhedral_fingerprint(candidates[:biaxial_nematic], F)
        # Both have ⟨F⟩=0 (the failure of the v1 classifier) but their σ_S
        # vectors are clearly different.
        dist = sqrt(sum((fp_cyc[S] - fp_bi[S])^2 for S in 0:2:(2F)))
        @test dist > 0.05
    end

    @testset "classify_polyhedral self-identifies canonical inputs" begin
        for (label, ζ) in candidates
            result = classify_polyhedral(ζ, F; tol=1e-6)
            @test result.best === label
            @test result.score < 1e-10
        end
    end

    @testset "classify_polyhedral rejects with :unknown on far state" begin
        D = 2F + 1
        ζ_random = randn(ComplexF64, D)
        # generic random not normalised matches no candidate within tight tol
        result = classify_polyhedral(ζ_random, F; tol=1e-6)
        @test result.best === :unknown
    end

    @testset "direct_eff_coupling matches g_S · σ_S inner product" begin
        # Sanity: at uniform g_S = 1, all g_eff = 1 (by Σ_S σ_S = 1).
        g_S = Dict{Int, Float64}(S => 1.0 for S in 0:2:(2F))
        for (label, ζ) in candidates
            g_eff = direct_eff_coupling(ζ, F, g_S)
            @test g_eff ≈ 1.0 atol = 1e-10
        end
        # At non-uniform g_S, g_eff distinguishes candidates.
        g_S_S2 = Dict{Int, Float64}(S => (S == 2 ? 5.0 : 0.0) for S in 0:2:(2F))
        ge_polar = direct_eff_coupling(candidates[:polar], F, g_S_S2)
        ge_FM = direct_eff_coupling(candidates[:FM], F, g_S_S2)
        @test ge_polar > ge_FM   # polar weights non-zero in S=2, FM does not
    end

    @testset "direct_eff_coupling_delta avoids subtracting independent E" begin
        g_S = Dict{Int, Float64}(2 => 5.0, 4 => 3.0, 10 => -2.0)
        Δ = direct_eff_coupling_delta(candidates[:cyclic],
            candidates[:biaxial_nematic], F, g_S)
        # Compare with the explicit subtraction (should match)
        Δ_explicit =
            direct_eff_coupling(candidates[:cyclic], F, g_S) -
            direct_eff_coupling(candidates[:biaxial_nematic], F, g_S)
        @test Δ ≈ Δ_explicit atol = 1e-12
    end
end
