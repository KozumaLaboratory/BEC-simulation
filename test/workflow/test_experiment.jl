using Test
using SpinorBEC

@testset "Experiment" begin
    @testset "interpolate_value" begin
        c = ConstantValue(3.0)
        @test interpolate_value(c, 0.0) == 3.0
        @test interpolate_value(c, 0.5) == 3.0
        @test interpolate_value(c, 1.0) == 3.0

        r = LinearRamp(1.0, 5.0)
        @test interpolate_value(r, 0.0) == 1.0
        @test interpolate_value(r, 0.5) == 3.0
        @test interpolate_value(r, 1.0) == 5.0
        @test interpolate_value(r, -0.1) == 1.0  # clamped
        @test interpolate_value(r, 1.5) == 5.0   # clamped
    end

    @testset "YAML parsing" begin
        yaml_str = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0],
                "n" => [64],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-8,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => Dict{String, Any}(
                    "from" => 0.0,
                    "to" => 0.5,
                ),
                "q" => 0.0,
            ),
            "dt" => 0.01,
            "duration" => 1.0,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "save" => Dict{String, Any}(
                "every" => 10,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.5,
                "q" => 0.0,
            ),
            "dt" => 0.01,
            "duration" => 2.0,
            "save" => Dict{String, Any}(
                "every" => 20,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.0,
            ),
            "dt" => 0.005,
            "duration" => 0.5,
            "save" => Dict{String, Any}(
                "every" => 10,
            ),
        ),
    )],
)
"""

        config = load_config_from_string(yaml_str)

        @test config isa PipelineConfig
        @test length(config.steps) == 4
        @test config.steps[1] isa SpinorBEC.GroundStateStep

        gp = config.steps[1].params
        @test gp["atom"] == "Rb87"
        @test gp["grid"]["n"] == [64]
        @test gp["grid"]["box"] == [20.0]
        @test gp["interactions"]["c0"] == 10.0
        @test gp["interactions"]["c1"] == -0.5
        @test gp["dt"] == 0.005
        @test gp["n_steps"] == 100
        @test gp["tol"] == 1.0e-8
        @test gp["initial_state"] == "polar"
        @test gp["B"]["p"] == 0.0
        @test gp["B"]["q"] == 0.1

        @test config.steps[2] isa SpinorBEC.DynamicsStep
        ramp = config.steps[2].params
        @test ramp["duration"] == 1.0
        @test ramp["dt"] == 0.01
        @test ramp["save"]["every"] == 10
        @test ramp["B"]["p"] isa Dict
        @test ramp["B"]["p"]["from"] == 0.0
        @test ramp["B"]["p"]["to"] == 0.5
        @test ramp["B"]["q"] == 0.0

        hold = config.steps[3].params
        @test hold["duration"] == 2.0

        release = config.steps[4].params
        @test release["duration"] == 0.5
    end

    @testset "YAML parsing - DDI" begin
        yaml_str = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "c_dd" => 1.5e-5,
                "enabled" => true,
            ),
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => [10.0],
                "n" => [32],
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 5.0,
                "c1" => 0.0,
            ),
            "n_steps" => 10,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 0.0001,
        ),
    )],
)
"""

        config = load_config_from_string(yaml_str)
        p = config.steps[1].params
        @test p["atom"] == "Eu151"
        @test p["ddi"]["enabled"] == true
        @test p["ddi"]["c_dd"] == 1.5e-5
    end

    @testset "YAML parsing - minimal" begin
        yaml_str = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Na23",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => 10.0,
                "n" => 32,
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 1.0,
                "c1" => 0.1,
            ),
            "n_steps" => 10,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 0.0001,
        ),
    )],
)
"""

        config = load_config_from_string(yaml_str)
        @test config isa PipelineConfig
        p = config.steps[1].params
        @test p["atom"] == "Na23"
        @test p["grid"]["n"] == 32
    end

    @testset "YAML parsing - phase temperature_ratio" begin
        yaml_with_noise = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => [10.0],
                "n" => [32],
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 1.0,
                "c1" => 0.0,
            ),
            "n_steps" => 10,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 0.0001,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.0,
            ),
            "dt" => 0.01,
            "duration" => 1.0,
            "noise_seed" => 42,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "temperature_ratio" => 0.1,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.0,
            ),
            "dt" => 0.01,
            "duration" => 1.0,
        ),
    )],
)
"""
        config = load_config_from_string(yaml_with_noise)
        @test config.steps[2].params["temperature_ratio"] == 0.1
        @test config.steps[2].params["noise_seed"] == 42
        @test get(config.steps[3].params, "temperature_ratio", nothing) === nothing
    end

    @testset "run_pipeline integration" begin
        yaml_str = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0],
                "n" => [32],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 200,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => Dict{String, Any}(
                    "from" => 0.0,
                    "to" => 0.1,
                ),
                "q" => 0.1,
            ),
            "dt" => 0.001,
            "duration" => 0.1,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "save" => Dict{String, Any}(
                "every" => 50,
            ),
        ),
    )],
)
"""

        config = load_config_from_string(yaml_str)
        result = run_pipeline(config; verbose=false)

        @test result.ground_state_energy !== nothing
        @test result.ground_state_energy isa Float64
        @test result.ground_state_converged isa Bool
        @test result.dynamics_result !== nothing
    end

    @testset "run_pipeline integration - phase temperature_ratio" begin
        yaml_str = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0],
                "n" => [32],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 200,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "dt" => 0.001,
            "duration" => 0.1,
            "noise_seed" => 42,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "save" => Dict{String, Any}(
                "every" => 50,
            ),
            "temperature_ratio" => 0.05,
        ),
    )],
)
"""

        config = load_config_from_string(yaml_str)
        @test config.steps[2].params["temperature_ratio"] == 0.05
        result = run_pipeline(config; verbose=false)
        @test result.dynamics_result !== nothing
    end

    @testset "run_pipeline integration - composite potential" begin
        yaml_str = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.1,
            ),
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [20.0],
                "n" => [32],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 200,
            "potential" => [Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ), Dict{String, Any}(
                "axis" => 1,
                "g" => 0.1,
                "type" => "gravity",
            )],
            "tol" => 1.0e-6,
        ),
    )],
)
"""

        config = load_config_from_string(yaml_str)
        result = run_pipeline(config; verbose=false)
        @test result.ground_state_energy !== nothing
        @test result.ground_state_energy isa Float64
    end
end
