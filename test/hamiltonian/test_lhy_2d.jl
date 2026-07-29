@testset "LHY abstraction and Quasi-2D LHY" begin
    @testset "_lhy_V dispatch" begin
        @test SpinorBEC._lhy_V(1.0, nothing) == 0.0
        @test SpinorBEC._lhy_V(0.0, nothing) == 0.0

        sl = ScalarLHY(2.5)
        @test SpinorBEC._lhy_V(4.0, sl) ≈ 2.5 * 4.0 * sqrt(4.0)
        @test SpinorBEC._lhy_V(0.0, sl) == 0.0

        @test SpinorBEC._lhy_V(4.0, 2.5) ≈ 2.5 * 4.0 * sqrt(4.0)
    end

    @testset "Quasi2DLHY construction" begin
        lhy = compute_lhy_2d_params(10.0, 1.5)
        @test lhy isa Quasi2DLHY
        # c₀²/(8π) — the prefactor of the beyond-mean-field term in Petrov &
        # Astrakharchik PRL 117, 100401 (2016) Eq. (5), read in the
        # single-component reduction. It was c₀²/(4π) with a compensating 0.5
        # written into the energy face only, so `_lhy_V` — and therefore the
        # propagator — was exactly 2× too large. See `compute_lhy_2d_params`.
        @test lhy.c_lhy_2d ≈ 100.0 / (8π)
        @test lhy.a_2d_sq ≈ 1.5^2
        γ_E = 0.5772156649015329
        @test lhy.log_const ≈ 2γ_E - 1 - log(2)
    end

    @testset "Quasi2DLHY _lhy_V" begin
        lhy = compute_lhy_2d_params(10.0, 1.5)
        @test SpinorBEC._lhy_V(0.0, lhy) == 0.0
        @test SpinorBEC._lhy_V(1e-31, lhy) == 0.0

        n = 1.0
        V = SpinorBEC._lhy_V(n, lhy)
        @test isfinite(V)
        @test V != 0.0

        # V == dε/dn, analytically. ε = c n²(ln(n a²) + L) differentiates to
        # c n (2(ln(n a²) + L) + 1) — the closed form is checked here so the
        # tie between the two faces does not rest on a numerical derivative
        # alone. This is what the old c₀²/(4π) + energy-side 0.5 violated.
        for nn in (0.5, 1.0, 3.7, 12.0)
            want = lhy.c_lhy_2d * nn *
                   (2.0 * (log(nn * lhy.a_2d_sq) + lhy.log_const) + 1.0)
            @test SpinorBEC._lhy_V(nn, lhy) ≈ want rtol = 1e-14
            # ...and against a finite difference of the energy face itself.
            h = 1e-6
            eps_of(x) = lhy.c_lhy_2d * x^2 * (log(x * lhy.a_2d_sq) + lhy.log_const)
            @test isapprox((eps_of(nn + h) - eps_of(nn - h)) / (2h),
                SpinorBEC._lhy_V(nn, lhy); rtol=1e-6)
        end
    end

    @testset "ScalarLHY reproduces old behavior" begin
        grid = make_grid(GridConfig((16,), (10.0,)))
        atom = Rb87
        c_lhy = 0.5
        interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5); c_lhy=c_lhy)

        sp = SimParams(; dt=0.01, n_steps=10, save_every=10)
        ws = make_workspace(;
            grid, atom, interactions,
            zeeman=ZeemanParams(),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )

        @test ws.lhy isa ScalarLHY
        @test ws.lhy.c_lhy == c_lhy
    end

    @testset "No LHY → lhy=nothing" begin
        grid = make_grid(GridConfig((16,), (10.0,)))
        atom = Rb87
        interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5))

        sp = SimParams(; dt=0.01, n_steps=10, save_every=10)
        ws = make_workspace(;
            grid, atom, interactions,
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )
        @test ws.lhy === nothing
    end

    @testset "LHY energy dispatch" begin
        grid = make_grid(GridConfig((16,), (10.0,)))
        atom = Rb87
        c_lhy = 0.5
        interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5); c_lhy=c_lhy)
        sp = SimParams(; dt=0.01, n_steps=1, save_every=1)
        ws = make_workspace(;
            grid, atom, interactions,
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )
        ed = energy_decomposition(ws)
        @test ed.lhy != 0.0
        @test isfinite(ed.lhy)
    end
end
