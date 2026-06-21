# test/oracles/test_spin_ladder_single_source.jl
#
# Single-source gate for two spinor primitives that used to be hand-written
# in many places (the exact "same physics in N locations" disease the
# sign-bug-proof architecture exists to kill):
#
#   1. The F₊ ladder coefficient √(F(F+1) − m(m+1)) — formerly re-derived
#      inline in c₁ spin-mixing, Raman, spatial-Zeeman, and the DDI/c₁
#      gradients, in two different algebraic forms.
#   2. The singlet-pair sign σ_c = (−1)^{F−m} — formerly re-stated in the
#      propagator and the gradient.
#
# These tests pin `fp_ladder_coeff` / `fp_ladder_coeffs` / `singlet_pair_sign`
# to the canonical references (the F₊ matrix built by `spin_matrices`, and the
# legacy index/m(m+1) forms) and prove the migration is bit-identical. A drift
# in the single source now breaks here loudly; a re-introduced inline copy that
# disagrees breaks the call sites' own oracles.

using Test
using SpinorBEC
using SpinorBEC: fp_ladder_coeff, fp_ladder_coeffs, singlet_pair_sign

@testset "Spin-ladder single source" begin
    @testset "fp_ladder_coeff == spin_matrices(F).Fp off-diagonal (F=$F)" for F in 1:6
        sm = spin_matrices(F)
        D = 2F + 1
        m = [Float64(F - (c - 1)) for c in 1:D]   # m[c]: c=1→+F … c=D→−F
        # Fp[i,j] is nonzero only for m[i] == m[j]+1, i.e. i == j-1.
        for j in 2:D
            i = j - 1
            @test sm.Fp[i, j] ≈ fp_ladder_coeff(F, m[j])
            @test real(sm.Fp[i, j]) == fp_ladder_coeff(F, m[j])  # exact
        end
    end

    @testset "fp_ladder_coeffs bit-identical to legacy forms (F=$F)" for F in 1:6
        D = 2F + 1
        coeffs = fp_ladder_coeffs(F, Val(D))
        @test length(coeffs) == D
        @test coeffs[1] == 0.0   # top component (c=1, m=F) has no F₊ partner
        for c in 2:D
            m = Float64(F - (c - 1))
            # m(m+1) form (c₁ mixing / Raman / spatial-Zeeman used this)
            legacy_mm = sqrt(Float64(F * (F + 1)) - m * (m + 1.0))
            # integer index form (DDI / c₁ gradient used this)
            legacy_idx = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
            @test coeffs[c] == legacy_mm
            @test coeffs[c] == legacy_idx
        end
    end

    @testset "fp_ladder_coeffs Float32 bit-identical to legacy F32 form (F=$F)" for F in 1:6
        D = 2F + 1
        coeffs32 = fp_ladder_coeffs(Float32, F, Val(D))
        @test eltype(coeffs32) == Float32
        Ff1 = Float32(F * (F + 1))
        for c in 2:D
            m = Float32(F - (c - 1))
            legacy32 = sqrt(Ff1 - m * (m + one(Float32)))
            @test coeffs32[c] === legacy32
        end
    end

    @testset "singlet_pair_sign == (−1)^{F−m} (F=$F)" for F in 1:6
        D = 2F + 1
        for c in 1:D
            m = F - (c - 1)
            @test singlet_pair_sign(F, m) == (-1.0)^(F - m)
            @test singlet_pair_sign(F, m) == (iseven(c - 1) ? 1.0 : -1.0)
        end
    end
end
