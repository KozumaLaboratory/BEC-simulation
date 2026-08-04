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
    function _field(f, ℓ; seed=11, shape=:exp)
        ψk = zeros(ComplexF64, n, n, n)
        rng = MersenneTwister(seed)
        for I in CartesianIndices((n, n, n))
            # exp(-r/ℓ) in 3D has power spectrum (1 + k²ℓ²)^-2, so this filter
            # gives the estimator EXACTLY its own model; :gauss gives it a shape
            # it does not model, and the bias that causes is pinned separately.
            filt = if shape === :exp
                1 / (1 + grid.k_squared[I] * ℓ^2)
            else
                exp(-grid.k_squared[I] * ℓ^2 / 4)
            end
            ψk[I] = filt * (randn(rng) + im * randn(rng))
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

    @testset "measured curve: a condensed cloud, plateau read by eye" begin
        # Real g₁ from an SPGPE quench held 200 time units at T_cold (τ_Q = 16,
        # μ = 15, R_TF = 5.48, N_C = 23471, zero vortices). The plateau is 0.835,
        # visible without any fit: the curve reaches it by r ≈ 0.65 and then
        # declines slowly — and THAT decline is cloud structure, not coherence.
        # Reading the plateau off the outer end of the measured range gave 0.120,
        # because the range ends at r = 10 and the cloud ends at 5.48. Bounding
        # the fit at R_TF is not the fix either: it returns ξ = 21.8 and
        # f_∞ = −1.36, an exponential eating the tail.
        r200 = [0.072826, 0.218478, 0.364130, 0.509783, 0.655435, 0.801087,
            0.946739, 1.092391, 1.238043, 1.383696, 1.529348, 1.675000,
            1.820652, 1.966304, 2.111957, 2.257609]
        g200 = [1.00000000, 0.96441488, 0.90867738, 0.85743086, 0.83531592,
            0.83533763, 0.83611797, 0.82979416, 0.82091744, 0.81478858,
            0.81109495, 0.80587674, 0.79777870, 0.78909914, 0.78205462,
            0.77516408]
        c = coherence_length(r200, g200)
        @test c.f_inf≈0.835 atol=0.06
        @test 0.1 < c.xi < 1.0                    # short-range, not the tail
        @test c.window < 3.0                      # tail excluded
        @test c.resid < 1e-2

        # Same quench measured at t_hold = 1 — where every Kibble-Zurek point was
        # taken. No plateau exists; the field has not condensed.
        r1 = [0.072826, 0.218478, 0.364130, 0.509783, 0.655435, 0.801087,
            0.946739, 1.092391, 1.238043, 1.383696, 1.529348, 1.675000,
            1.820652, 1.966304, 2.111957, 2.257609]
        g1r = [1.00000000, 0.83322050, 0.53055479, 0.22137743, 0.06673837,
            0.04706217, 0.05689333, 0.04522419, 0.02371328, 0.01488641,
            0.01875416, 0.01947243, 0.01156782, 0.00574727, 0.00568812,
            0.00679856]
        c1 = coherence_length(r1, g1r)
        @test abs(c1.f_inf) < 0.05                # uncondensed
        @test c1.xi < 1.0
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

    @testset "a non-exponential decay biases f_∞ LOW — pinned, not hidden" begin
        # The estimator assumes g₁ = f + A exp(−r/ξ). Gaussian-correlated noise
        # violates that, and the fit compensates by pushing the plateau down. The
        # bias is real and one-sided, so it is recorded here rather than papered
        # over with a loose tolerance on the main test: any result quoting f_∞ on
        # a curve that is not exponential is a LOWER bound.
        for f in (0.2, 0.5)
            got = coherence_length(
                first_order_correlation(_field(f, 1.5; shape=:gauss), grid, plans)...).f_inf
            @test got < f                          # one-sided
            @test got > f - 0.4                    # and bounded
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
