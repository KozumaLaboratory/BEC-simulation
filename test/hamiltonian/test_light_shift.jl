using Test
using LinearAlgebra
using SpinorBEC

@testset "LightShift" begin
    @testset "diagonal case: ε ∥ ẑ" begin
        F = 1
        D = 2F + 1
        grid = make_grid(GridConfig((32,), (10.0,)))
        profile = ones(Float64, 32)
        ls = make_light_shift(; F, polarization=(0, 0, 1), alpha_tensor=1.0, profile)
        @test ls.is_diagonal
        # For ε∥ẑ, (ε̂·F̂)² = Fz², tensor = (3Fz² - F(F+1))/(F(2F-1))
        # F=1: eigenvalues should be (3m² - 2)/(1·1) for m = 1, 0, -1
        # m=1: (3-2)/1 = 1, m=0: (0-2)/1 = -2, m=-1: (3-2)/1 = 1
        @test ls.eigvals ≈ [1.0, -2.0, 1.0]
    end

    @testset "off-diagonal case: tilted polarization" begin
        F = 1
        D = 2F + 1
        grid = make_grid(GridConfig((32,), (10.0,)))
        profile = ones(Float64, 32)
        ls = make_light_shift(; F, polarization=(1, 0, 1), alpha_tensor=1.0, profile)
        @test !ls.is_diagonal
        @test length(ls.eigvals) == D
        # Eigenvectors should be unitary
        @test ls.U' * ls.U ≈ I(D)
    end

    @testset "vector light shift: σ+ like linear Zeeman" begin
        F = 1
        D = 2F + 1
        grid = make_grid(GridConfig((32,), (10.0,)))
        profile = ones(Float64, 32)
        # σ+ polarization: (1, i, 0)/√2
        ls = make_light_shift(;
            F, polarization=(1, im, 0), alpha_vector=1.0, alpha_tensor=0.0, profile
        )
        @test ls.is_diagonal
        # (iε̂*×ε̂) for σ+ = (0,0,1), so M_v = α_v/F × Fz
        # Diagonal: eigvals ordered by component (m=1,0,-1), ∝ m
        @test ls.eigvals ≈ [-1.0, 0.0, 1.0]
    end

    @testset "norm preservation (off-diagonal, RTP)" begin
        F = 1
        grid = make_grid(GridConfig((32,), (10.0,)))
        sys = SpinSystem(F)
        psi = init_psi(grid, sys; state=:uniform)
        dV = SpinorBEC.cell_volume(grid)
        norm_before = sum(abs2, psi) * dV
        profile = ones(Float64, 32)
        ls = make_light_shift(; F, polarization=(1, 0, 1), alpha_tensor=1.0, profile)
        @test !ls.is_diagonal
        for _ in 1:100
            apply_light_shift_step!(psi, ls, 0.01, 1; imaginary_time=false)
        end
        norm_after = sum(abs2, psi) * dV
        @test norm_after ≈ norm_before rtol=1e-10
    end

    @testset "energy decomposition includes light_shift" begin
        F = 1
        grid = make_grid(GridConfig((32,), (10.0,)))
        atom = Rb87
        interactions = InteractionParams(1.0, 0.0)
        sp = SimParams(; dt=0.001, n_steps=10, imaginary_time=true)
        V_trap = evaluate_potential(HarmonicTrap(1.0), grid)
        ls = make_light_shift_from_trap(V_trap, F, 0.05)
        ws = make_workspace(;
            grid, atom, interactions, sim_params=sp, potential=HarmonicTrap(1.0), light_shift=ls
        )
        ed = energy_decomposition(ws)
        @test haskey(pairs(ed), :light_shift)
        @test ed.light_shift != 0.0
        @test ed.total ≈
            ed.kinetic + ed.trap + ed.zeeman + ed.density + ed.spin +
              ed.ddi + ed.lhy + ed.tensor + ed.raman + ed.light_shift
    end

    @testset "ITP with tensor LS redistributes populations" begin
        F = 1
        D = 2F + 1
        grid = make_grid(GridConfig((32,), (10.0,)))
        atom = Rb87
        interactions = InteractionParams(1.0, 0.0)
        profile = evaluate_potential(HarmonicTrap(1.0), grid)
        # Strong tensor LS: favors m=0 (negative eigenvalue for ε∥ẑ)
        ls = make_light_shift(; F, polarization=(0, 0, 1), alpha_tensor=5.0, profile=abs.(profile))
        ws = make_workspace(;
            grid, atom, interactions,
            sim_params=SimParams(; dt=0.005, n_steps=500, imaginary_time=true),
            potential=HarmonicTrap(1.0),
            light_shift=ls,
        )
        for _ in 1:ws.sim_params.n_steps
            split_step!(ws)
        end
        # m=0 component should have significant population
        n_pts = grid.config.n_points
        pop = [sum(abs2, view(ws.state.psi, :, c)) for c in 1:D]
        pop ./= sum(pop)
        @test pop[2] > 0.3  # m=0 component should be enhanced
    end

    @testset "regression: light_shift=nothing matches existing" begin
        F = 1
        grid = make_grid(GridConfig((32,), (10.0,)))
        atom = Rb87
        interactions = InteractionParams(1.0, 0.1)
        sp = SimParams(; dt=0.001, n_steps=10)
        psi0 = init_psi(grid, SpinSystem(F); state=:uniform)
        ws1 = make_workspace(; grid, atom, interactions, sim_params=sp, psi_init=copy(psi0))
        ws2 = make_workspace(;
            grid, atom, interactions, sim_params=sp, psi_init=copy(psi0), light_shift=nothing
        )
        for _ in 1:10
            split_step!(ws1)
            split_step!(ws2)
        end
        @test ws1.state.psi ≈ ws2.state.psi
    end

    @testset "make_light_shift_from_trap" begin
        F = 1
        V_trap = Float64[1.0, 2.0, 3.0, 4.0]
        ls = make_light_shift_from_trap(V_trap, F, 0.1)
        @test ls.is_diagonal  # default ε∥ẑ
        @test ls.profile ≈ abs.(V_trap)
    end

    @testset "F=6 Eu151 diagonal light shift" begin
        F = 6
        D = 2F + 1
        profile = ones(Float64, 16)
        ls = make_light_shift(; F, polarization=(0, 0, 1), alpha_tensor=1.0, profile)
        @test ls.is_diagonal
        @test length(ls.eigvals) == D
        # m-dependent eigenvalues: (3m² - F(F+1)) / (F(2F-1))
        for c in 1:D
            m = F - (c - 1)
            expected = (3 * m^2 - F * (F + 1)) / (F * (2F - 1))
            @test ls.eigvals[c] ≈ expected atol=1e-12
        end
    end
end
