# Calibration of the Klaus-2022 residual-image detector.
#
# A detector applied to a simulation cannot say "I looked and found nothing"
# differently from "I could not look" unless both are exercised, so every
# assertion below is paired: a pattern that MUST be found and a pattern that
# MUST NOT be. Same discipline as `test/helpers/calibrated_scan.jl`, applied to
# an image instead of a corpus.

using Test
using SpinorBEC
using Random

const NX = 128
const DX = 0.125

"Gaussian cloud with `holes` punched into it (each a Gaussian dip of width `w`)."
function _cloud_with_holes(holes::Vector{<:Tuple}; w::Float64=0.25, R::Float64=5.0)
    x = ((1:NX) .- (NX ÷ 2 + 0.5)) .* DX
    img = [exp(-(xi^2 + yj^2) / (2 * (R / 2)^2)) for xi in x, yj in x]
    for (hx, hy) in holes
        for j in 1:NX, i in 1:NX
            r2 = (x[i] - hx)^2 + (x[j] - hy)^2
            img[i, j] *= 1 - exp(-r2 / (2 * w^2))
        end
    end
    (img, x)
end

@testset "vortex stripe detector" begin
    @testset "hole count: positive and negative control" begin
        # NEGATIVE: a smooth cloud has no holes. If this fires, every count
        # below is noise.
        smooth, _ = _cloud_with_holes(Tuple{Float64, Float64}[])
        res0, mask0 = residual_image(smooth; sigma_px=5)
        @test isempty(detect_density_holes(res0, mask0;
            contrast_threshold=-0.02, min_distance=4))

        # POSITIVE: five well-separated holes, all inside the masked region.
        pos = [(-2.0, -1.0), (0.0, 0.0), (2.0, 1.0), (-1.0, 2.0), (1.5, -2.0)]
        img, x = _cloud_with_holes(pos)
        res, mask = residual_image(img; sigma_px=5)
        found = detect_density_holes(res, mask;
            contrast_threshold=-0.02, min_distance=4)
        @test length(found) == length(pos)
        # …and at the right places (within a blur width).
        for (hx, hy) in pos
            @test any(f -> abs(x[f[1]] - hx) < 0.5 && abs(x[f[2]] - hy) < 0.5, found)
        end
    end

    @testset "min_distance actually merges a close pair" begin
        # Two holes 3 px apart must collapse to one at min_distance=6 and stay
        # two at min_distance=2 — otherwise the knob is inert and the count
        # above proves nothing about double-counting.
        pair = [(0.0, 0.0), (3 * DX, 0.0)]
        img, _ = _cloud_with_holes(pair; w=0.12)
        res, mask = residual_image(img; sigma_px=5)
        n_far = length(detect_density_holes(res, mask;
            contrast_threshold=-0.005, min_distance=2))
        n_near = length(detect_density_holes(res, mask;
            contrast_threshold=-0.005, min_distance=6))
        @test n_far == 2
        @test n_near == 1
    end

    @testset "stripe FT: peak pair vs homogeneous ring" begin
        spacing = 2.0
        # POSITIVE: three vertical lines of holes ⇒ modulation along x ⇒ the
        # dominant wavevector points along x (angle 0) with k = 2π/spacing.
        striped = Tuple{Float64, Float64}[]
        for n in (-1, 0, 1), yy in (-2.5, -1.25, 0.0, 1.25, 2.5)
            push!(striped, (n * spacing, yy))
        end
        img, _ = _cloud_with_holes(striped)
        res, _ = residual_image(img; sigma_px=5)
        kx, ky, mag = stripe_spectrum(res, DX, DX)
        k_expect = 2π / spacing
        m = stripe_metrics(kx, ky, mag; k_lo=0.6 * k_expect, k_hi=1.6 * k_expect)
        @test m.n_k_points > 100
        @test min(m.angle, π - m.angle) < deg2rad(15)      # axis ≈ x̂
        @test m.k_peak ≈ k_expect rtol = 0.25
        aniso_stripes = m.axis_order
        @test aniso_stripes > 5 * m.axis_order_null   # measured 6.75×
        # The radial profile must have a genuine peak, at the stripe k.
        @test m.k_mode ≈ k_expect rtol = 0.3
        prom_stripes = m.radial_prominence
        @test prom_stripes > 1.5

        # NEGATIVE: the SAME number of holes at random positions must not give
        # a stripe axis. Without this the threshold above is unfalsifiable.
        rng = MersenneTwister(20260818)
        scattered = [
            (4 * (rand(rng) - 0.5) * 2, 4 * (rand(rng) - 0.5) * 2)
            for _ in 1:length(striped)
        ]
        img_r, _ = _cloud_with_holes(scattered)
        res_r, _ = residual_image(img_r; sigma_px=5)
        kxr, kyr, magr = stripe_spectrum(res_r, DX, DX)
        mr = stripe_metrics(kxr, kyr, magr; k_lo=0.6 * k_expect, k_hi=1.6 * k_expect)
        @test mr.axis_order < 0.6 * aniso_stripes     # measured 0.45×

        # NEGATIVE control for the RADIAL statistics specifically: an
        # elongated, hole-free cloud. Its residual carries envelope power, so
        # it has an anisotropy axis — which is exactly why anisotropy alone
        # cannot say "stripes". `radial_prominence` must separate them.
        x = ((1:NX) .- (NX ÷ 2 + 0.5)) .* DX
        smooth_elong = [exp(-(xi^2 / (2 * 3.0^2) + yj^2 / (2 * 2.0^2)))
                        for xi in x, yj in x]
        res_e, _ = residual_image(smooth_elong; sigma_px=5)
        kxe, kye, mage = stripe_spectrum(res_e, DX, DX)
        me = stripe_metrics(kxe, kye, mage;
            k_lo=0.6 * k_expect, k_hi=1.6 * k_expect)
        @test me.radial_prominence < prom_stripes
    end

    @testset "radial_prominence is ~1 on a featureless spectrum" begin
        # Calibration of the discriminator itself. White noise has no radial
        # structure, so mean-power-per-bin must be flat. Before the per-bin
        # population normalisation this returned the top of the annulus with
        # high "prominence" for any image at all.
        rng = MersenneTwister(7)
        noise = rand(rng, NX, NX)
        kx, ky, mag = stripe_spectrum(noise .- sum(noise) / length(noise), DX, DX)
        m = stripe_metrics(kx, ky, mag; k_lo=1.0, k_hi=6.0, n_radial=12)
        @test m.radial_prominence < 1.3
        # The order parameter must sit at its own null on isotropic power. The
        # binned max/mean this replaced read 6.8 here.
        @test m.axis_order < 4 * m.axis_order_null
        @test m.axis_order < 0.15
    end

    @testset "stripe axis tracks a rotation" begin
        # A stripe pattern rotated by θ must report an axis rotated by θ. This
        # is what turns "the stripes align with B̂" into a measurement rather
        # than a picture.
        spacing = 2.0
        for θ in (0.0, deg2rad(35), deg2rad(70))
            c, s = cos(θ), sin(θ)
            holes = Tuple{Float64, Float64}[]
            for n in (-1, 0, 1), t in (-2.5, -1.25, 0.0, 1.25, 2.5)
                # line n: offset n·spacing along the modulation axis (θ),
                # extended along the perpendicular.
                px = n * spacing * c - t * s
                py = n * spacing * s + t * c
                push!(holes, (px, py))
            end
            img, _ = _cloud_with_holes(holes)
            res, _ = residual_image(img; sigma_px=5)
            kx, ky, mag = stripe_spectrum(res, DX, DX)
            k_expect = 2π / spacing
            m = stripe_metrics(kx, ky, mag; k_lo=0.6 * k_expect, k_hi=1.6 * k_expect)
            Δ = abs(m.angle - θ)
            @test min(Δ, π - Δ) < deg2rad(15)
        end
    end

    @testset "empty annulus is an error, not a silent NaN" begin
        img, _ = _cloud_with_holes([(0.0, 0.0)])
        res, _ = residual_image(img; sigma_px=5)
        kx, ky, mag = stripe_spectrum(res, DX, DX)
        @test_throws ArgumentError stripe_metrics(kx, ky, mag; k_lo=1e4, k_hi=2e4)
    end
end
