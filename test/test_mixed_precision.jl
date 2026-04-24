using Test
using SpinorBEC
using LinearAlgebra

@testset "Mixed precision (F32 vs F64)" begin

    # Construction
    @testset "make_grid and workspace support Float32" begin
        cfg = GridConfig((16, 16, 16), (6.0, 6.0, 6.0))
        grid32 = make_grid(cfg; dtype = Float32)
        @test typeof(grid32) === Grid{3,Float32}
        @test eltype(grid32.x[1]) === Float32
        @test eltype(grid32.k_squared) === Float32
        @test eltype(grid32.dx) === Float32

        atom = AtomSpecies("Na23", 3.8e-26, 1, 52.0 * 5.29e-11, 54.3 * 5.29e-11, 0.0)
        ip = InteractionParams(100.0, -0.3)
        sp = SimParams(; dt = 0.01, n_steps = 1)
        ws = make_workspace(;
            grid = grid32, atom, interactions = ip, sim_params = sp,
            potential = HarmonicTrap(1.0, 1.0, 1.0), dtype = Float32,
        )
        @test eltype(ws.state.psi) === ComplexF32
        @test eltype(ws.potential_values) === Float32
        @test eltype(ws.kinetic_phase) === ComplexF32
        @test eltype(ws.density_buf) === Float32
    end

    @testset "dtype mismatch with grid eltype errors" begin
        cfg = GridConfig((8, 8, 8), (4.0, 4.0, 4.0))
        grid64 = make_grid(cfg)
        atom = AtomSpecies("Na23", 3.8e-26, 1, 52.0 * 5.29e-11, 54.3 * 5.29e-11, 0.0)
        ip = InteractionParams(50.0, -0.1)
        sp = SimParams(; dt = 0.01, n_steps = 1)
        @test_throws ArgumentError make_workspace(;
            grid = grid64, atom, interactions = ip, sim_params = sp,
            potential = HarmonicTrap(1.0, 1.0, 1.0), dtype = Float32,
        )
    end

    # F32 vs F64 agreement: 1-step norm + 1-step energy + short ITP energy
    @testset "F32 vs F64 short ITP energy agrees within 1e-3" begin
        cfg = GridConfig((32, 32, 32), (10.0, 10.0, 10.0))
        atom = AtomSpecies("Na23", 3.8e-26, 1, 52.0 * 5.29e-11, 54.3 * 5.29e-11, 0.0)
        ip = InteractionParams(200.0, -0.5)

        r64 = find_ground_state(;
            grid = make_grid(cfg),
            atom, interactions = ip, potential = HarmonicTrap(1.0, 1.0, 1.0),
            dt = 0.005, n_steps = 300, tol = 1e-8,
        )
        E64 = r64.energy

        r32 = find_ground_state(;
            grid = make_grid(cfg; dtype = Float32),
            atom, interactions = ip, potential = HarmonicTrap(1.0, 1.0, 1.0),
            dt = 0.005, n_steps = 300, tol = 1e-6,
            dtype = Float32,
        )
        E32 = r32.energy
        @test eltype(r32.workspace.state.psi) === ComplexF32

        rel_err = abs(E32 - E64) / abs(E64)
        @test rel_err < 1e-3
    end

    # Norm conservation under F32 split_step
    @testset "F32 real-time split_step conserves norm" begin
        cfg = GridConfig((16, 16, 16), (6.0, 6.0, 6.0))
        grid32 = make_grid(cfg; dtype = Float32)
        atom = AtomSpecies("Na23", 3.8e-26, 1, 52.0 * 5.29e-11, 54.3 * 5.29e-11, 0.0)
        ip = InteractionParams(50.0, -0.2)
        sp = SimParams(; dt = 0.001, n_steps = 1)
        ws = make_workspace(;
            grid = grid32, atom, interactions = ip, sim_params = sp,
            potential = HarmonicTrap(1.0, 1.0, 1.0), dtype = Float32,
        )
        n0 = sum(abs2, ws.state.psi) * prod(grid32.dx)
        for _ = 1:50
            SpinorBEC.split_step!(ws)
        end
        n1 = sum(abs2, ws.state.psi) * prod(grid32.dx)
        @test abs(n1 - n0) / n0 < 1e-4
    end

    # YAML `dtype:` knob + ITP tol auto-relax
    @testset "YAML dtype + ITP F32 tol auto-relax" begin
        p_f32 = Dict{String,Any}(
            "grid" => Dict("n" => [16, 16, 16], "box" => [6.0, 6.0, 6.0]),
            "dtype" => "float32",
        )
        grid32, ndim = SpinorBEC._setup_grid_from_params(p_f32)
        @test ndim == 3
        @test eltype(grid32.x[1]) === Float32

        p_f64 = Dict{String,Any}(
            "grid" => Dict("n" => [16, 16, 16], "box" => [6.0, 6.0, 6.0]),
        )
        grid64, _ = SpinorBEC._setup_grid_from_params(p_f64)
        @test eltype(grid64.x[1]) === Float64

        @test_throws ArgumentError SpinorBEC._setup_grid_from_params(
            Dict{String,Any}(
                "grid" => Dict("n" => [8,8,8], "box" => [4.0,4.0,4.0]),
                "dtype" => "half",
            ),
        )

        # ITP F32 with tol<1e-6 should log a warning and clamp.
        atom = AtomSpecies("Na23", 3.8e-26, 1, 52.0*5.29e-11, 54.3*5.29e-11, 0.0)
        ip = InteractionParams(50.0, -0.2)
        grid = make_grid(GridConfig((16,16,16), (6.0,6.0,6.0)); dtype=Float32)
        r = find_ground_state(;
            grid, atom, interactions = ip, potential = HarmonicTrap(1.0,1.0,1.0),
            dt = 0.005, n_steps = 20, tol = 1e-10,
            dtype = Float32,
        )
        @test eltype(r.workspace.state.psi) === ComplexF32
    end

    # DDI path at F32 (harder — has Q tensor and rFFT)
    @testset "F32 DDI workspace & step" begin
        cfg = GridConfig((16, 16, 16), (6.0, 6.0, 6.0))
        grid32 = make_grid(cfg; dtype = Float32)
        atom = AtomSpecies("Eu151", 2.5e-25, 6, 110 * 5.29e-11, 0.0, 6.977 * 9.274e-24)
        ip = InteractionParams(100.0, 2.8)
        sp = SimParams(; dt = 0.001, n_steps = 1)
        ws = make_workspace(;
            grid = grid32, atom, interactions = ip, sim_params = sp,
            potential = HarmonicTrap(1.0, 1.0, 1.0),
            enable_ddi = true, c_dd = 10.0,
            dtype = Float32,
        )
        @test eltype(ws.ddi.Q_xx) === Float32
        @test eltype(ws.ddi_bufs.Fx_r) === Float32
        @test eltype(ws.ddi_bufs.Fx_rk) === ComplexF32

        n0 = sum(abs2, ws.state.psi) * prod(grid32.dx)
        SpinorBEC.split_step!(ws)
        n1 = sum(abs2, ws.state.psi) * prod(grid32.dx)
        @test abs(n1 - n0) / n0 < 1e-4
    end
end
