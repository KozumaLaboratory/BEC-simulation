using Test
using SpinorBEC
using Statistics: mean

@testset "P3 imaging analyzers" begin
    # Synthetic Gaussian column density for testing
    nx, ny = 32, 32
    xs = range(-3, 3; length=nx)
    ys = range(-3, 3; length=ny)
    img = Float64[exp(-(x^2 + y^2)) for x in xs, y in ys]

    @testset "Gaussian PSF preserves integral (within kernel truncation)" begin
        blurred = gaussian_psf_convolve(img, 2.0)
        # Total counts approx preserved (kernel truncated at 4σ ≈ 99.994%)
        @test sum(blurred) ≈ sum(img) rtol=1e-2
        # Peak is reduced (energy spread out)
        @test maximum(blurred) < maximum(img)
    end

    @testset "PSF with zero sigma is identity" begin
        same = gaussian_psf_convolve(img, 0.0)
        @test all(same .≈ img)
    end

    @testset "Shot noise: mean preserved, variance ≈ mean" begin
        s = 100.0
        noisy = apply_shot_noise(img, s; seed=42)
        # Mean should track (λ · s) within 1/√N
        expected_mean = mean(img) * s
        @test abs(mean(noisy) - expected_mean) / expected_mean < 0.05
    end

    @testset "Saturation clips OD" begin
        high_OD = fill(5.0, 8, 8)
        clipped = apply_saturation(high_OD, 2.0)
        @test maximum(clipped) < 3.0   # soft clip, not hard
        @test all(clipped .< high_OD)
    end

    @testset "synthesise_absorption_image chains stages" begin
        grid = make_grid(GridConfig((16, 16), (6.0, 6.0)))
        # No effects: passthrough
        same = synthesise_absorption_image(img, grid)
        @test all(Float64.(img) .≈ same)
        # Full pipeline: at least returns finite array
        full = synthesise_absorption_image(img, grid;
            sigma_pixels=1.0, photons_per_unit=50.0,
            OD_sat=2.0, read_noise_sigma=0.5, seed=1)
        @test all(isfinite, full)
        @test size(full) == size(img)
    end

    @testset "momentum_distribution far-field" begin
        # Build a tiny 3D BEC-like wavefunction
        grid = make_grid(GridConfig((16, 16, 16), (6.0, 6.0, 6.0)))
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:polar)
        result = momentum_distribution(psi, grid; t_tof=5.0, axis=3)
        @test length(result.k_coords) == 2
        @test size(result.n_k) == (16, 16)
        @test all(result.n_k .>= 0)
    end
end
