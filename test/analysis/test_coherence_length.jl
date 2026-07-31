using Test
using FFTW
using Random
using SpinorBEC

# g₁(r) and the coherence length, gated against states whose answer is known in
# closed form. This is the KZ observable that replaces defect counting, so it
# needs its own instrument gate — counting was abandoned precisely because
# `extract_vortex_lines_per_m` turned out to invent defects below dx = 0.8ξ and to
# be basis-dependent for a spinor.

@testset "first-order correlation + coherence length" begin
    n, L = 48, 12.0
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    plans = make_fft_plans((n, n, n); flags=FFTW.ESTIMATE)
    D = SpinSystem(1).n_components

    @testset "fully coherent field: g₁ ≈ 1 out to the box" begin
        # A single-mode condensate is coherent everywhere, so g₁ must not decay
        # and the coherence length is undefined (NaN), not silently the box size.
        psi = zeros(ComplexF64, n, n, n, D)
        for I in CartesianIndices((n, n, n))
            x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
            psi[I, D] = exp(-(x^2 + y^2 + z^2) / 20)
        end
        r, g1 = first_order_correlation(psi, grid, plans)
        @test g1[1] ≈ 1.0 atol = 1e-10
        @test minimum(g1[1:max(1, length(g1) ÷ 3)]) > 0.5   # no fast decay
        @test isnan(coherence_length(r, g1))                # never reaches 1/e
    end

    @testset "white-noise field: g₁ collapses within a cell" begin
        # Uncorrelated per-site phase ⇒ correlation dies at the first bin, so the
        # coherence length is at most a grid spacing. This is the limit a KZ
        # measurement must NOT mistake for a real length.
        psi = zeros(ComplexF64, n, n, n, D)
        rng = MersenneTwister(4242)
        for I in CartesianIndices((n, n, n))
            psi[I, D] = cis(2π * rand(rng))
        end
        r, g1 = first_order_correlation(psi, grid, plans)
        ℓ = coherence_length(r, g1)
        @test g1[1] ≈ 1.0 atol = 1e-10
        @test g1[2] < 0.2
        @test isnan(ℓ) || ℓ < 2 * (L / n)
    end

    @testset "imposed correlation length is recovered" begin
        # Gaussian-correlated phase with a set length ℓ_set: g₁ of a field whose
        # Fourier amplitudes have width 1/ℓ_set decays on ℓ_set. The measurement
        # must track ℓ_set as it is varied — the point is the SCALING, since a KZ
        # exponent is read off how the length moves, not its absolute value.
        got = Float64[]
        for ℓ_set in (1.0, 2.0, 3.0)
            ψk = zeros(ComplexF64, n, n, n)
            rng = MersenneTwister(7)
            for I in CartesianIndices((n, n, n))
                k2 = grid.k_squared[I]
                ψk[I] = exp(-k2 * ℓ_set^2 / 4) * (randn(rng) + im * randn(rng))
            end
            plans.inverse * ψk
            psi = zeros(ComplexF64, n, n, n, D)
            psi[:, :, :, D] .= ψk
            r, g1 = first_order_correlation(psi, grid, plans)
            push!(got, coherence_length(r, g1))
        end
        @test all(isfinite, got)
        @test issorted(got)                       # longer imposed ⇒ longer measured
        @test got[3] / got[1] > 2.0               # and it tracks, not saturates
    end
end
