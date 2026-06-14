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

    @testset "pixel_bin" begin
        fine = ones(Float64, 12, 6)             # divisible by bin 3 ⇒ no crop
        fdx = (0.1, 0.1)
        pb = pixel_bin(fine, fdx, 0.3)          # bin factor 3 each axis
        @test pb.bin == (3, 3)
        @test size(pb.image) == (4, 2)
        @test all(pb.pixel_dx .≈ (0.3, 0.3))
        @test all(pb.image .≈ 1.0)               # :mean of a constant is the constant
        # number conserved: Σ image · pixel_area == Σ fine · cell_area
        @test sum(pb.image) * prod(pb.pixel_dx) ≈ sum(fine) * prod(fdx)
        # :sum gives counts; same conserved number with the fine cell area
        ps = pixel_bin(fine, fdx, 0.3; combine=:sum)
        @test all(ps.image .≈ 9.0)               # 3×3 block sum
        @test sum(ps.image) * prod(fdx) ≈ sum(fine) * prod(fdx)
        # anisotropic pixel pitch (12/2=6, 6/3=2 — both divide)
        pa = pixel_bin(fine, fdx, (0.2, 0.3))
        @test pa.bin == (2, 3)
        @test size(pa.image) == (6, 2)
        # non-divisible dim is cropped to whole pixels (documented behavior)
        pc = pixel_bin(fine, fdx, 0.4)           # bin 4: 12/4=3, 6/4=1 (rem 2 dropped)
        @test pc.bin == (4, 4)
        @test size(pc.image) == (3, 1)
    end

    @testset "imaging_forward (3D density → 2D camera image)" begin
        g = make_grid(GridConfig((32, 32, 32), (12.0, 12.0, 12.0)))
        wx = 1.2
        dens = Float64[exp(-(x^2 + y^2 + z^2) / wx^2)
                       for x in g.x[1], y in g.x[2], z in g.x[3]]
        Ntot = sum(dens) * cell_volume(g)

        @testset "column integration conserves number" begin
            r = imaging_forward(dens, g; imaging_axis=3)
            @test size(r.image) == (32, 32)
            @test sum(r.image) * prod(r.pixel_dx) ≈ Ntot rtol = 1e-10
        end

        @testset "PSF broadens by √(w²+σ²) in physical units" begin
            σpsf = 0.8
            r = imaging_forward(dens, g; imaging_axis=3, psf_sigma=σpsf)
            # column of a 3D Gaussian exp(-r²/w²) is a 2D Gaussian of the same w;
            # RMS width along x of exp(-x²/w²) is w/√2.
            function rms_x(im, xs)
                m = sum(im)
                xb = sum(xs[i] * im[i, j] for i in axes(im, 1), j in axes(im, 2)) / m
                sqrt(sum((xs[i] - xb)^2 * im[i, j]
                         for i in axes(im, 1), j in axes(im, 2)) / m)
            end
            w0 = rms_x(imaging_forward(dens, g; imaging_axis=3).image, g.x[1])
            wpsf = rms_x(r.image, g.x[1])
            @test wpsf ≈ sqrt(w0^2 + σpsf^2) rtol = 3e-2
            @test sum(r.image) * prod(r.pixel_dx) ≈ Ntot rtol = 1e-2  # PSF conserves N
        end

        @testset "pixel binning coarsens, conserves number" begin
            r = imaging_forward(dens, g; imaging_axis=3, pixel_size=0.75)
            bx = round(Int, 0.75 / g.dx[1])
            @test r.bin == (bx, bx)
            @test size(r.image, 1) == 32 ÷ bx
            @test sum(r.image) * prod(r.pixel_dx) ≈ Ntot rtol = 1e-10
            @test length(r.x) == size(r.image, 1)
        end

        @testset "optical depth = sigma_abs · column density" begin
            σabs = 0.3
            r0 = imaging_forward(dens, g; imaging_axis=3)
            r1 = imaging_forward(dens, g; imaging_axis=3, sigma_abs=σabs)
            @test r1.image ≈ σabs .* r0.image
        end
    end

    @testset "image_multiframe wires recombine_density → camera" begin
        # 3D skeleton TOF, no gradient (single co-expanding frame per m), imaged
        # along z. Number through the whole chain equals the cloud norm.
        ω = 1.0
        sys = SpinSystem(1)
        D = 3
        g = make_grid(GridConfig((24, 24, 24), (10.0, 10.0, 10.0)))
        psi0 = zeros(ComplexF64, 24, 24, 24, D)
        for c in 1:D, k in 1:24, j in 1:24, i in 1:24
            psi0[i, j, k, c] = exp(-ω * (g.x[1][i]^2 + g.x[2][j]^2 + g.x[3][k]^2) / 2)
        end
        psi0 ./= sqrt(sum(abs2, psi0) * cell_volume(g))
        state = simulate_tof_multiframe(psi0, g, sys;
            gradient=0.0, gradient_axis=3, t=0.5, omega=(ω, ω, ω))
        r = image_multiframe(state; imaging_axis=3, psf_sigma=0.4, pixel_size=0.8)
        @test ndims(r.image) == 2
        @test all(isfinite, r.image)
        @test all(r.image .>= 0)
        @test sum(r.image) * prod(r.pixel_dx) ≈ 1.0 rtol = 5e-2
    end
end
