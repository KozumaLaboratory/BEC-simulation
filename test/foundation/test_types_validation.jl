using Test
using SpinorBEC

@testset "Type Constructors Validation" begin
    @testset "GridConfig validation" begin
        @test_throws ArgumentError GridConfig((0,), (10.0,))
        @test_throws ArgumentError GridConfig((3,), (10.0,))  # odd
        @test_throws ArgumentError GridConfig((64,), (-1.0,))
        @test_throws ArgumentError GridConfig((64,), (0.0,))

        gc = GridConfig(64, 10.0)
        @test gc.n_points == (64,)
        @test gc.box_size == (10.0,)
    end

    @testset "SpinSystem validation" begin
        @test_throws ArgumentError SpinSystem(-1)

        sys = SpinSystem(0)
        @test sys.n_components == 1

        sys1 = SpinSystem(1)
        @test sys1.n_components == 3
        @test sys1.m_values == [1, 0, -1]

        sys2 = SpinSystem(2)
        @test sys2.n_components == 5
    end

    @testset "SimParams validation" begin
        @test_throws ArgumentError SimParams(; dt=-0.1, n_steps=100)
        @test_throws ArgumentError SimParams(; dt=0.1, n_steps=-1)

        sp = SimParams(; dt=0.01, n_steps=100, imaginary_time=true)
        @test sp.normalize_every == 1
    end

    @testset "ZeemanParams default" begin
        z = ZeemanParams()
        @test z.p == 0.0
        @test z.q == 0.0
    end

    @testset "TimeDependentZeeman with Waveform fields" begin
        z = TimeDependentZeeman(t -> ZeemanParams(t, 0.0))
        @test zeeman_at(z, 1.0) == ZeemanParams(1.0, 0.0)
        @test z.p_wf isa FunctionWaveform
        @test z.q_wf isa FunctionWaveform
    end

    @testset "InteractionParams" begin
        ip = InteractionParams(Dict(0 => 1.0, 1 => 0.5))
        @test get_cn(ip, 0) == 1.0
        @test get_cn(ip, 1) == 0.5
        @test get_cn(ip, 2) == 0.0

        ip2 = InteractionParams(Dict(0 => 1.0, 1 => 0.5, 2 => 0.3))
        @test get_cn(ip2, 2) == 0.3
    end

    @testset "AdaptiveDtParams validation" begin
        @test_throws ArgumentError AdaptiveDtParams(; dt_init=-1.0)
        @test_throws ArgumentError AdaptiveDtParams(; dt_min=0.1, dt_max=0.01)
        @test_throws ArgumentError AdaptiveDtParams(; tol=-1.0)
        @test_throws ArgumentError AdaptiveDtParams(; error_mode=:invalid)
    end

    @testset "IntegratorConfig validation" begin
        @test_throws ArgumentError IntegratorConfig(:invalid)
        @test_throws ArgumentError IntegratorConfig(:adaptive, nothing)

        ic = IntegratorConfig(:strang)
        @test ic.method == :strang
    end

    @testset "HarmonicTrap construction" begin
        t1d = HarmonicTrap(1.0)
        @test t1d.omega == (1.0,)

        t2d = HarmonicTrap(1.0, 2.0)
        @test t2d.omega == (1.0, 2.0)

        t3d = HarmonicTrap(1.0, 2.0, 3.0)
        @test t3d.omega == (1.0, 2.0, 3.0)
    end

    @testset "GravityPotential validation" begin
        @test_throws ArgumentError GravityPotential{2}(9.8, 3)
        g = GravityPotential{2}(9.8, 2)
        @test g.g == 9.8
    end

    @testset "LossParams default" begin
        lp = LossParams(0.1)
        @test lp.gamma_dr == 0.1
        @test lp.L3 == 0.0
    end

    @testset "OverrideScan validation" begin
        @test_throws ArgumentError OverrideScan(Dict{String, Any}[])
        os = OverrideScan([Dict{String, Any}("a.b" => 1)])
        @test length(os.points) == 1
    end

    @testset "TOFParams validation" begin
        @test_throws ArgumentError TOFParams(-1.0, 0.0, 1)
        @test_throws ArgumentError TOFParams(1.0, 0.0, 4)
    end
end
