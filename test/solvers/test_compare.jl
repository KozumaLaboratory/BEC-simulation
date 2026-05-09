# --- Generic compare(observed, simulated) API tests ---

using SpinorBEC
using Test

@testset "compare API" begin
    @testset "shape mismatch → DimensionMismatch" begin
        @test_throws DimensionMismatch compare(rand(4, 4), rand(4, 5))
        @test_throws DimensionMismatch compare(rand(4, 4), rand(4, 4); mask=trues(3, 3))
    end

    @testset "self-comparison loss = 0 (every metric, every normaliser)" begin
        x = randn(8, 8)
        for m in (:l2, :l1, :linf, :relative_l2, :cosine, :correlation, :chi_squared)
            for n in (:none, :unit, :max, :integral)
                # :integral with a signed input can produce 0/0 when sum=0; skip
                n === :integral && sum(x) ≈ 0 && continue
                loss = compare(x, x; metric=m, normalize=n)
                @test isfinite(loss)
                @test loss < 1e-10
            end
        end
    end

    @testset "L²: scale-invariant under :unit normalisation" begin
        x = rand(6, 6)
        # Scaling x by 7 leaves the L² loss after :unit normalisation unchanged.
        @test compare(x, 7 .* x; metric=:l2, normalize=:unit) < 1e-10
    end

    @testset "cosine: orthogonal arrays = 1.0" begin
        x = Float64[1, 0, 0, 0]
        y = Float64[0, 1, 0, 0]
        @test compare(x, y; metric=:cosine, normalize=:none) ≈ 1.0
    end

    @testset "correlation: anti-correlated arrays = 2.0" begin
        x = Float64[1, 2, 3, 4, 5]
        y = -x
        # 1 - corr = 1 - (-1) = 2
        @test compare(x, y; metric=:correlation, normalize=:none) ≈ 2.0 atol=1e-12
    end

    @testset "linf: returns max absolute deviation" begin
        x = zeros(5)
        y = Float64[0, 0, 3, 0, 0]
        # :none — max diff = 3
        @test compare(x, y; metric=:linf, normalize=:none) ≈ 3.0
    end

    @testset "wasserstein_1d: shifted gaussians" begin
        # Two probability densities shifted by `s` in 1D. The exact W1
        # distance equals the absolute shift on a fine grid.
        x = collect(-5.0:0.1:5.0)
        gauss(σ, μ) = exp.(-(x .- μ) .^ 2 ./ (2σ^2))
        a = gauss(1.0, 0.0)
        b = gauss(1.0, 0.5)
        # The metric returns sum |F_a - F_b| · Δ-implicit (multiply by dx
        # to get the physical distance — we just check ordering and scaling).
        d_small = compare(a, b; metric=:wasserstein_1d, normalize=:integral)
        c = gauss(1.0, 1.0)
        d_large = compare(a, c; metric=:wasserstein_1d, normalize=:integral)
        @test d_small > 0
        @test d_large > d_small      # larger shift ⇒ larger EMD
    end

    @testset "mask restricts comparison to cloud support" begin
        # 4×4 image with one bright pixel and a different "noise" pixel.
        target = zeros(4, 4);
        target[2, 2] = 1.0
        sim = zeros(4, 4);
        sim[2, 2] = 1.0;
        sim[4, 4] = 5.0   # bright + outlier
        # Without mask: outlier dominates the L² loss.
        full_loss = compare(target, sim; metric=:l2, normalize=:none)
        # Mask out the outlier → loss collapses to 0.
        mask = trues(4, 4);
        mask[4, 4] = false
        masked_loss = compare(target, sim; metric=:l2, normalize=:none, mask)
        @test masked_loss < full_loss
        @test masked_loss < 1e-10
    end

    @testset "normalize_field: handles zero-norm input gracefully" begin
        z = zeros(5)
        for m in (:unit, :max, :integral)
            out = SpinorBEC.normalize_field(z; method=m)
            @test all(out .== 0)
        end
    end

    @testset "unknown metric / normalisation throw" begin
        @test_throws ArgumentError compare(rand(3), rand(3); metric=:bogus)
        @test_throws ArgumentError SpinorBEC.normalize_field(rand(3); method=:bogus)
    end
end
