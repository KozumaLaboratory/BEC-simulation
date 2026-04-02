@testset "Parameter Continuation" begin
    F = 1
    grid = make_grid(GridConfig((16,), (10.0,)))
    atom = Rb87

    @testset "Basic sweep returns results" begin
        param_values = [-2.0, -1.0, 0.0, 1.0, 2.0]
        make_ip = val -> InteractionParams(10.0, val)

        results = scan_continuation(;
            param_values,
            make_interactions=make_ip,
            grid, atom,
            n_steps_continuation=100,
            n_steps_fresh=500,
            dt=0.01,
            tol=1e-6,
        )

        @test length(results) == 5
        @test all(r -> haskey(r, :param), results)
        @test all(r -> haskey(r, :energy), results)
        @test all(r -> haskey(r, :phase), results)
        @test results[1].param == -2.0
        @test results[end].param == 2.0
    end

    @testset "Continuation uses previous psi" begin
        param_values = [1.0, 1.01]
        make_ip = val -> InteractionParams(10.0, val)

        results = scan_continuation(;
            param_values,
            make_interactions=make_ip,
            grid, atom,
            n_steps_continuation=100,
            n_steps_fresh=500,
            dt=0.01,
            tol=1e-6,
        )

        @test length(results) == 2
        # Nearby parameters should give similar energies
        @test abs(results[1].energy - results[2].energy) / abs(results[1].energy) < 0.1
    end

    @testset "All results have valid phase" begin
        param_values = [-5.0, -2.0, 2.0, 5.0]
        make_ip = val -> InteractionParams(10.0, val)

        results = scan_continuation(;
            param_values,
            make_interactions=make_ip,
            grid, atom,
            n_steps_continuation=200,
            n_steps_fresh=1000,
            dt=0.005,
            tol=1e-6,
        )

        phases = [r.phase for r in results]
        valid_phases = [:ferromagnetic, :polar, :nematic, :cyclic, :mixed, :vacuum]
        @test all(p -> p in valid_phases, phases)
        @test length(results) == 4
    end

    @testset "Bidirectional returns valid structure" begin
        param_values = [-2.0, -1.0, 0.0, 1.0, 2.0]
        make_ip = val -> InteractionParams(10.0, val)

        hr = scan_continuation_bidirectional(;
            param_values,
            make_interactions=make_ip,
            grid, atom,
            n_steps_continuation=100,
            n_steps_fresh=500,
            dt=0.01,
            tol=1e-6,
        )

        @test hr isa HysteresisResult
        @test length(hr.forward) == 5
        @test length(hr.backward) == 5
        @test hr.param_values == param_values
        @test hr.hysteresis_intervals isa Vector{Tuple{Float64,Float64}}
        @test hr.transition_points isa Vector{Float64}
    end

    @testset "Identical parameters → no hysteresis" begin
        param_values = [1.0, 1.0, 1.0]
        make_ip = val -> InteractionParams(10.0, val)

        hr = scan_continuation_bidirectional(;
            param_values,
            make_interactions=make_ip,
            grid, atom,
            n_steps_continuation=100,
            n_steps_fresh=500,
            dt=0.01,
            tol=1e-6,
        )

        @test isempty(hr.hysteresis_intervals)
        @test isempty(hr.transition_points)
    end

    @testset "Phase-crossing sweep detects hysteresis" begin
        param_values = collect(range(-5.0, 5.0; length=6))
        make_ip = val -> InteractionParams(10.0, val)

        hr = scan_continuation_bidirectional(;
            param_values,
            make_interactions=make_ip,
            grid, atom,
            n_steps_continuation=200,
            n_steps_fresh=1000,
            dt=0.005,
            tol=1e-6,
        )

        @test length(hr.forward) == 6
        @test length(hr.backward) == 6
        @test hr.hysteresis_intervals isa Vector{Tuple{Float64,Float64}}
        @test length(hr.transition_points) == length(hr.hysteresis_intervals)
    end
end
