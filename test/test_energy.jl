using Test
using SpinorBEC

@testset "Energy" begin
    @testset "energy_decomposition returns all fields" begin
        grid = make_grid(GridConfig(64, 20.0))
        atom = Rb87
        interactions = InteractionParams(1.0, 0.1)
        sp = SimParams(; dt=0.001, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, sim_params=sp,
                            potential=HarmonicTrap(1.0))

        E = energy_decomposition(ws)
        @test haskey(E, :kinetic)
        @test haskey(E, :trap)
        @test haskey(E, :zeeman)
        @test haskey(E, :density)
        @test haskey(E, :spin)
        @test haskey(E, :ddi)
        @test haskey(E, :lhy)
        @test haskey(E, :tensor)
        @test haskey(E, :raman)
        @test haskey(E, :total)

        @test E.total ≈ E.kinetic + E.trap + E.zeeman + E.density +
                         E.spin + E.ddi + E.lhy + E.tensor + E.raman
    end

    @testset "total_energy matches decomposition sum" begin
        grid = make_grid(GridConfig(64, 20.0))
        atom = Rb87
        interactions = InteractionParams(1.0, 0.1)
        sp = SimParams(; dt=0.001, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, sim_params=sp,
                            potential=HarmonicTrap(1.0))

        @test total_energy(ws) ≈ energy_decomposition(ws).total
    end

    @testset "kinetic energy positive for non-uniform state" begin
        grid = make_grid(GridConfig(64, 20.0))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        sp = SimParams(; dt=0.001, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, sim_params=sp)

        E = energy_decomposition(ws)
        @test E.kinetic > 0.0
    end

    @testset "trap energy positive with harmonic trap" begin
        grid = make_grid(GridConfig(64, 20.0))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        sp = SimParams(; dt=0.001, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, sim_params=sp,
                            potential=HarmonicTrap(1.0))

        E = energy_decomposition(ws)
        @test E.trap > 0.0
    end

    @testset "density interaction energy with c0" begin
        grid = make_grid(GridConfig(64, 20.0))
        atom = Rb87
        sp = SimParams(; dt=0.001, n_steps=1)

        ws_pos = make_workspace(; grid, atom, interactions=InteractionParams(10.0, 0.0),
                                 sim_params=sp)
        ws_neg = make_workspace(; grid, atom, interactions=InteractionParams(-10.0, 0.0),
                                 sim_params=sp)

        E_pos = energy_decomposition(ws_pos).density
        E_neg = energy_decomposition(ws_neg).density
        @test E_pos > 0.0
        @test E_neg < 0.0
    end

    @testset "zero interactions give zero interaction energies" begin
        grid = make_grid(GridConfig(64, 20.0))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        sp = SimParams(; dt=0.001, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, sim_params=sp)

        E = energy_decomposition(ws)
        @test abs(E.density) < 1e-14
        @test abs(E.spin) < 1e-14
        @test abs(E.ddi) < 1e-14
        @test abs(E.lhy) < 1e-14
    end

    @testset "Raman energy nonzero with coupling" begin
        grid = make_grid(GridConfig(32, 10.0))
        atom = Rb87
        interactions = InteractionParams(1.0, 0.1)
        sp = SimParams(; dt=0.001, n_steps=1)
        rc = RamanCoupling{1}(2.0, 0.5, (1.0,))
        psi = init_psi(grid, SpinSystem(1); state=:uniform)
        ws = make_workspace(; grid, atom, interactions, sim_params=sp, raman=rc,
                             psi_init=psi)

        E = energy_decomposition(ws)
        @test abs(E.raman) > 1e-10
    end

    @testset "Zeeman energy with linear Zeeman" begin
        grid = make_grid(GridConfig(64, 20.0))
        atom = Rb87
        interactions = InteractionParams(0.0, 0.0)
        sp = SimParams(; dt=0.001, n_steps=1)

        psi_ferro = init_psi(grid, SpinSystem(1); state=:ferromagnetic)
        ws = make_workspace(; grid, atom, interactions, sim_params=sp,
                            zeeman=ZeemanParams(1.0, 0.0), psi_init=psi_ferro)

        E = energy_decomposition(ws)
        @test abs(E.zeeman) > 0.0
    end

    @testset "energy conservation after ITP" begin
        grid = make_grid(GridConfig(64, 20.0))
        atom = Rb87
        interactions = InteractionParams(5.0, 0.3)
        sp = SimParams(; dt=0.001, n_steps=100, imaginary_time=false, save_every=100)

        r = find_ground_state(; grid, atom, interactions,
                               potential=HarmonicTrap(1.0), dt=0.005, n_steps=2000)

        sp_rt = SimParams(; dt=0.001, n_steps=200, imaginary_time=false, save_every=200)
        ws = make_workspace(; grid, atom, interactions, sim_params=sp_rt,
                            potential=HarmonicTrap(1.0),
                            psi_init=copy(r.workspace.state.psi))

        E0 = total_energy(ws)
        for _ in 1:200
            split_step!(ws)
        end
        E1 = total_energy(ws)
        @test abs(E1 - E0) / abs(E0) < 1e-4
    end
end
