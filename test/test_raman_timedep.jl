using Test
using SpinorBEC

@testset "TimeDependentRaman" begin
    @testset "raman_at dispatch" begin
        static = RamanCoupling(5.0, 0.1, (1.0,))
        @test raman_at(static, 0.5) === static
        @test raman_at(nothing, 0.0) === nothing

        td = TimeDependentRaman(
            RampWaveform(0.0, 10.0, 1.0, :linear),
            ConstantWaveform(0.5),
            (1.0,),
        )
        r0 = raman_at(td, 0.0)
        @test r0 isa RamanCoupling{1}
        @test r0.Omega_R ≈ 0.0
        @test r0.delta ≈ 0.5
        @test r0.k_eff == (1.0,)

        r1 = raman_at(td, 1.0)
        @test r1.Omega_R ≈ 10.0
        @test r1.delta ≈ 0.5
    end

    @testset "TimeDependentRaman in split_step" begin
        grid = make_grid(GridConfig(32, 10.0))
        atom = Rb87
        ip = InteractionParams(100.0, -0.5)
        raman = TimeDependentRaman(
            RampWaveform(0.0, 2.0, 0.05, :cosine),
            ConstantWaveform(0.0),
            (1.0,),
        )
        ws = make_workspace(;
            grid, atom, interactions = ip,
            zeeman = ZeemanParams(0.0, -0.01),
            potential = HarmonicTrap(1.0),
            sim_params = SimParams(dt = 0.001, n_steps = 50, save_every = 50),
            psi_init = init_psi(grid, SpinorBEC.SpinSystem(atom.F)),
            raman,
        )

        norm_before = total_norm(ws.state.psi, grid)

        for _ in 1:50
            split_step!(ws)
        end

        norm_after = total_norm(ws.state.psi, grid)
        @test abs(norm_after - norm_before) / norm_before < 1e-6
    end

    @testset "TimeDependentZeeman backward compat" begin
        f = t -> ZeemanParams(10.0 - t, t * 0.1)
        td = TimeDependentZeeman(f)
        @test td isa TimeDependentZeeman
        z = zeeman_at(td, 3.0)
        @test z.p ≈ 7.0
        @test z.q ≈ 0.3
    end
end
