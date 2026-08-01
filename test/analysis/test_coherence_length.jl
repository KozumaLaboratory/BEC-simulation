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

    # Synthetic field with BOTH a set condensate fraction and a set decay length:
    #   psi = sqrt(f)*env + sqrt(1-f)*env*ν,   ⟨ν⟩ = 0,  ⟨|ν|²⟩ = 1
    # so `f` IS the coherent fraction and ℓ IS the decay length of ν, both known
    # independently of the estimator. The normalisation is load-bearing: an
    # earlier version divided ν by its MAXIMUM, giving ⟨|ν|²⟩ ≈ 0.09, so the true
    # coherent fraction of a nominal f = 0.2 was 0.2/(0.2 + 0.8·0.09) = 0.74 — and
    # the estimator was blamed for reporting 0.74.
    function _field(f, ℓ; seed=11)
        ψk = zeros(ComplexF64, n, n, n)
        rng = MersenneTwister(seed)
        for I in CartesianIndices((n, n, n))
            ψk[I] = exp(-grid.k_squared[I] * ℓ^2 / 4) * (randn(rng) + im * randn(rng))
        end
        ψk[1, 1, 1] = 0                            # zero mean: no coherent part in ν
        plans.inverse * ψk
        ψk ./= sqrt(sum(abs2, ψk) / length(ψk))    # unit MEAN square, not unit max
        psi = zeros(ComplexF64, n, n, n, D)
        for I in CartesianIndices((n, n, n))
            x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
            env = exp(-(x^2 + y^2 + z^2) / 60)
            psi[I, D] = sqrt(f) * env + sqrt(1 - f) * env * ψk[I]
        end
        psi
    end

    @testset "fully coherent field: g₁ flat, no decay length" begin
        psi = zeros(ComplexF64, n, n, n, D)
        for I in CartesianIndices((n, n, n))
            x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
            psi[I, D] = exp(-(x^2 + y^2 + z^2) / 20)
        end
        r, g1 = first_order_correlation(psi, grid, plans)
        @test g1[1] ≈ 1.0 atol = 1e-10
        c = coherence_length(r, g1)
        @test c.f_inf > 0.5                 # plateau IS the field
        @test isnan(c.xi)                   # nothing left to fit
    end

    @testset "condensate fraction is recovered" begin
        for f in (0.2, 0.5, 0.8)
            psi = _field(f, 1.5)
            # The fixture states its own coherent fraction, so a failure below is
            # the estimator's and not the field's.
            coh = abs(sum(psi))^2 / (length(psi[:, :, :, D]) * sum(abs2, psi))
            @test coh > 0                          # non-degenerate
            r, g1 = first_order_correlation(psi, grid, plans)
            @test coherence_length(r, g1).f_inf ≈ f atol = 0.2
        end
    end

    @testset "ξ tracks the imposed length AT EVERY condensate fraction" begin
        # The gate the 1/e version failed. Its answer moved with f and barely with
        # ℓ — it was reporting where the plateau crossed 0.368. Here ℓ must be
        # recovered as ℓ is scaled, and the ANSWER MUST NOT DEPEND ON f.
        for f in (0.2, 0.5, 0.8)
            got = [
                coherence_length(first_order_correlation(_field(f, ℓ), grid, plans)...).xi
                for ℓ in (1.0, 2.0, 4.0)
            ]
            @test all(isfinite, got)
            @test issorted(got)
            @test got[3] / got[1] > 1.8      # tracks ℓ, does not saturate
        end
        # …and at fixed ℓ, changing f must not move ξ much.
        at_f = [
            coherence_length(first_order_correlation(_field(f, 2.0), grid, plans)...).xi
            for f in (0.2, 0.5, 0.8)
        ]
        @test all(isfinite, at_f)
        @test maximum(at_f) / minimum(at_f) < 2.0
    end
end
