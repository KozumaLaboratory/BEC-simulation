using Test
using SpinorBEC

@testset "Quasi-2D dimensional reduction" begin
    @testset "parsing quasi_2d + l_z in pipeline" begin
        yaml_str = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87",
            "ddi" => Dict{String, Any}(
                "c_dd" => 1.0,
                "enabled" => true,
                "l_z" => 1.5,
                "quasi_2d" => true,
            ),
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => [10.0, 10.0],
                "n" => [16, 16],
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "l_z" => 1.5,
            "n_steps" => 10,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0],
                "type" => "harmonic",
            ),
            "quasi_2d" => true,
            "tol" => 0.0001,
        ),
    )],
)
"""

        config = load_config_from_string(yaml_str)
        @test config isa PipelineConfig
        p = config.steps[1].params
        @test p["quasi_2d"] == true
        @test p["l_z"] == 1.5
        @test p["ddi"]["quasi_2d"] == true
        @test p["ddi"]["l_z"] == 1.5
    end

    @testset "end-to-end: run_pipeline ground_state 2D" begin
        yaml_str = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.0,
            ),
            "atom" => "Rb87",
            "dt" => 0.005,
            "grid" => Dict{String, Any}(
                "box" => [10.0, 10.0],
                "n" => [16, 16],
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 10.0,
                "c1" => -0.5,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 0.0001,
        ),
    )],
)
"""

        config = load_config_from_string(yaml_str)
        result = run_pipeline(config; verbose=false)
        @test result.ground_state_energy isa Float64
        @test result.ground_state_converged isa Bool
    end
end
