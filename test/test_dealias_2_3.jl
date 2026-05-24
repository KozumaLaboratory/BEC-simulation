# Regression test for the Orszag 2/3-rule pseudospectral filter
# (src/hamiltonian/integrator/dealias.jl).
#
# Verifies (CPU-only, no GPU dependency):
#   1. Default toggle is OFF (no behaviour change for existing callers).
#   2. Filter zeros Fourier modes with |k_d_idx| > n_d ÷ 3 per axis.
#   3. Filter preserves modes within the kept band (low-k, |k| ≤ n_d ÷ 3).
#   4. Mask cache key by n_pts (different grids get distinct masks).
#   5. Idempotent: applying twice = applying once.
#
# Does NOT cover (deferred to physics validation suite):
#   - End-to-end L4 grid convergence (GPU run; lives under
#     runs/verification_suite/yamls/L4dealiasv4_*).

using Test
using FFTW
using Random
using SpinorBEC

@testset "Orszag 2/3 dealiasing filter" begin
    @testset "toggle defaults OFF" begin
        @test SpinorBEC.DEALIAS_2_3_ENABLED[] == false
    end

    @testset "mask geometry" begin
        # n=16: cutoff = 16 ÷ 3 = 5. Modes with |k_abs_idx| > 5 zeroed.
        # FFT-order: index i ↔ k_idx (i-1); |k_abs_idx| = min(i-1, n-(i-1)).
        # Kept: i ∈ {1,2,3,4,5,6} (k_abs 0..5) ∪ {12,...,16} (k_abs 5..1)
        # Zeroed: i ∈ {7,8,9,10,11} (k_abs 6,7,8,7,6)
        mask = SpinorBEC._get_orszag_mask((16,))
        @test size(mask) == (16,)
        kept = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0,  # i=1..6, k_abs=0..5
            0.0, 0.0, 0.0, 0.0, 0.0,           # i=7..11, k_abs=6,7,8,7,6
            1.0, 1.0, 1.0, 1.0, 1.0]           # i=12..16, k_abs=5,4,3,2,1
        @test mask == kept
    end

    @testset "filter zeros high-k, preserves low-k" begin
        n = 16
        D = 3
        plans = SpinorBEC.make_fft_plans((n,))
        # Inject plane waves at k_idx=1 (low, kept) and k_idx=7 (high, zeroed)
        psi = zeros(ComplexF64, n, D)
        for c in 1:D, i in 1:n
            psi[i, c] = cis(2π * (i - 1) * 1 / n) + cis(2π * (i - 1) * 7 / n)
        end

        # Pre-filter k-space content
        buf = copy(psi[:, 1])
        plans.forward * buf
        @test abs(buf[2]) > 0.5 * n   # k_idx=1 has the full plane-wave amplitude
        @test abs(buf[8]) > 0.5 * n   # k_idx=7 also present

        SpinorBEC.apply_orszag_2_3_filter!(psi, plans, D, 1)

        # Post-filter
        buf2 = copy(psi[:, 1])
        plans.forward * buf2
        @test abs(buf2[2]) > 0.5 * n        # low-k preserved
        @test abs(buf2[8]) < 1e-12          # high-k zeroed
    end

    @testset "idempotent (applying twice = once)" begin
        n = 16
        D = 3
        plans = SpinorBEC.make_fft_plans((n,))
        rng = MersenneTwister(20260524)
        psi_a = randn(rng, ComplexF64, n, D)
        psi_b = copy(psi_a)
        SpinorBEC.apply_orszag_2_3_filter!(psi_a, plans, D, 1)
        SpinorBEC.apply_orszag_2_3_filter!(psi_b, plans, D, 1)
        SpinorBEC.apply_orszag_2_3_filter!(psi_b, plans, D, 1)
        @test maximum(abs, psi_a .- psi_b) < 1e-13
    end

    @testset "different grid sizes get distinct masks" begin
        m16 = SpinorBEC._get_orszag_mask((16,))
        m32 = SpinorBEC._get_orszag_mask((32,))
        @test size(m16) == (16,)
        @test size(m32) == (32,)
        @test sum(m16) == 11.0   # 6 + 5 = 11 modes kept
        @test sum(m32) == 21.0   # n=32, cutoff=10, kept i ∈ {1..11} ∪ {23..32}
    end

    @testset "3D mask: per-axis cutoff" begin
        # 8³ grid: cutoff = 8÷3 = 2 per axis. Kept per axis: |k_abs| ≤ 2 →
        # i ∈ {1,2,3} ∪ {7,8} → 5 indices. Cube: 5³ = 125 modes kept.
        m = SpinorBEC._get_orszag_mask((8, 8, 8))
        @test size(m) == (8, 8, 8)
        @test sum(m) == 125.0
    end

    @testset "safe_k_cut_boundary formula" begin
        # k_Nyq = π·N/L; safe = 2·k_Nyq/3
        @test SpinorBEC.safe_k_cut_boundary(64, 12.0) ≈ 2 * (π * 64 / 12.0) / 3
        @test SpinorBEC.safe_k_cut_boundary(96, 12.0) ≈ 2 * (π * 96 / 12.0) / 3
        @test SpinorBEC.safe_k_cut_boundary(128, 12.0) ≈ 2 * (π * 128 / 12.0) / 3
        # Values match the L4 k-scan analysis comment in the docstring
        @test isapprox(SpinorBEC.safe_k_cut_boundary(96, 12.0), 16.755; atol=1e-3)
        @test isapprox(SpinorBEC.safe_k_cut_boundary(128, 12.0), 22.34; atol=1e-2)
    end

    @testset "DEALIAS_K_CUTOFF override (fixed physical k_cut)" begin
        # Default behaviour: cutoff = n÷3 per axis.
        @test SpinorBEC.DEALIAS_K_CUTOFF[] === nothing
        m_default = SpinorBEC._get_orszag_mask((16,))
        # 16-grid box L=12 (assumed). dk = 2π/12 ≈ 0.524. n÷3=5
        # → physical cutoff = 5·0.524 = 2.62.
        # Set DEALIAS_K_CUTOFF = 2.62 should give same mask.
        SpinorBEC.DEALIAS_K_CUTOFF[] = 5 * 2π / 12.0
        m_kcut_match = SpinorBEC._get_orszag_mask((16,))
        SpinorBEC.DEALIAS_K_CUTOFF[] = nothing  # reset
        @test m_default == m_kcut_match

        # Tighter cutoff zeros more modes.
        SpinorBEC.DEALIAS_K_CUTOFF[] = 1.0  # k ≤ 1.0 → idx ≤ ~1.9 → 2 modes
        m_tight = SpinorBEC._get_orszag_mask((16,))
        SpinorBEC.DEALIAS_K_CUTOFF[] = nothing  # reset
        @test sum(m_tight) < sum(m_default)

        # Looser cutoff keeps more modes (capped by grid Nyquist).
        SpinorBEC.DEALIAS_K_CUTOFF[] = 100.0  # well above any Nyq
        m_loose = SpinorBEC._get_orszag_mask((16,))
        SpinorBEC.DEALIAS_K_CUTOFF[] = nothing  # reset
        @test sum(m_loose) == 16.0  # all modes kept
    end
end
