using Test
using SpinorBEC
using FFTW

@testset "Phase Scan" begin
    @testset "Override primitive: apply_override!" begin
        d = Dict{String, Any}("a" => Dict{String, Any}("b" => 1))
        SpinorBEC.apply_override!(d, "a.b", 42)
        @test d["a"]["b"] == 42

        # Creates intermediate dicts
        SpinorBEC.apply_override!(d, "a.c.d", "x")
        @test d["a"]["c"]["d"] == "x"

        # Multi-key apply_overrides
        out = SpinorBEC.apply_overrides(d, Dict{String, Any}("a.b" => 7, "z" => true))
        @test out["a"]["b"] == 7
        @test out["z"] == true
        @test d["a"]["b"] == 42  # base unchanged
    end

    @testset "expand_scan_points: zip" begin
        scan = Dict{String, Any}(
            "zip" => Dict{String, Any}(
                "system.ddi.c_dd" => [0.0, 1000.0, 4000.0],
                "ground_state.zeeman.p" => [100.0, 10.0, 1.0],
            ),
        )
        pts = SpinorBEC.expand_scan_points(scan)
        @test length(pts) == 3
        @test pts[1]["system.ddi.c_dd"] == 0.0
        @test pts[1]["ground_state.zeeman.p"] == 100.0
        @test pts[3]["system.ddi.c_dd"] == 4000.0

        # Length mismatch errors
        @test_throws ArgumentError SpinorBEC.expand_scan_points(
            Dict{String, Any}(
                "zip" => Dict{String, Any}("a.b" => [1, 2], "c.d" => [1, 2, 3])
            ),
        )
    end

    @testset "expand_scan_points: product" begin
        scan = Dict{String, Any}(
            "product" => Dict{String, Any}(
                "system.interactions[1]_ratio" => [-0.01, 0.0],
                "ground_state.target_magnetization" => [-6.0, -3.0, 0.0],
            ),
        )
        pts = SpinorBEC.expand_scan_points(scan)
        @test length(pts) == 6
        # Each combination present exactly once
        combos = Set([
            (p["system.interactions[1]_ratio"], p["ground_state.target_magnetization"]) for p in pts
        ])
        @test length(combos) == 6
    end

    @testset "expand_scan_points: zip × product combination" begin
        pts = SpinorBEC.expand_scan_points(
            Dict{String, Any}(
                "zip" => Dict{String, Any}("a" => [1, 2, 3]),
                "product" => Dict{String, Any}("b" => [10, 20]),
            ),
        )
        @test length(pts) == 6  # 3 zip × 2 product
        combos = Set([(p["a"], p["b"]) for p in pts])
        @test length(combos) == 6
    end

    @testset "YAML parsing - override scan with zip" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "p" => 0.0,
                "q" => 0.0,
            ),
            "atom" => "Rb87",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => 6.0,
                "n" => 8,
            ),
            "initial_state" => "polar",
            "interactions" => Dict{String, Any}(
                "c0" => 100.0,
                "c1" => -5.0,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    )],
    "scan" => Dict{String, Any}(
        "continuation" => true,
        "zip" => Dict{String, Any}(
            "pipeline.0.zeeman.p" => [0.0, 0.5, 1.0],
        ),
    ),
)
"""
        config = load_config_from_string(yaml)
        @test config.scan isa OverrideScan
        @test length(config.scan.points) == 3
        @test config.scan.points[1]["pipeline.0.zeeman.p"] == 0.0
        @test config.scan.continuation == true
        @test config.scan.auto_rotate_on_mz == false
    end

    @testset "YAML parsing - comparison_runs" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => 6.0,
                "n" => 8,
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 100.0,
                "c1" => -5.0,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    )],
    "scan" => Dict{String, Any}(
        "comparison_runs" => [Dict{String, Any}(
            "name" => "polar",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "polar",
            ),
        ), Dict{String, Any}(
            "name" => "ferro",
            "override" => Dict{String, Any}(
                "pipeline.0.initial_state" => "m_plus_F",
            ),
        )],
        "zip" => Dict{String, Any}(
            "pipeline.0.interactions[1]" => [-5.0, -1.0, 0.0],
        ),
    ),
)
"""
        config = load_config_from_string(yaml)
        @test length(config.scan.comparison_runs) == 2
        @test config.scan.comparison_runs[1][1] == "polar"
        @test config.scan.comparison_runs[2][2]["pipeline.0.initial_state"] == "m_plus_F"
    end

    @testset "YAML parsing - constrained Jz scan" begin
        yaml = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => [6.0, 6.0],
                "n" => [8, 8],
            ),
            "interactions" => Dict{String, Any}(
                "c0" => 100.0,
                "c1" => -5.0,
            ),
            "n_steps" => 100,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    )],
    "scan" => Dict{String, Any}(
        "max_iter" => 5,
        "omega_range" => [-5.0, 5.0],
        "target_values" => [0.0, 1.0, 2.0],
        "tolerance" => 0.1,
        "type" => "constrained_jz",
    ),
)
"""
        config = load_config_from_string(yaml)
        @test config.scan isa ConstrainedJzScan
        @test length(config.scan.target_values) == 3
    end

    @testset "OverrideScan validation" begin
        @test_throws ArgumentError OverrideScan(Dict{String, Any}[])
        os = OverrideScan([Dict{String, Any}("a.b" => 1)])
        @test length(os.points) == 1
        @test os.continuation == false
    end

    @testset "ConstrainedJzScan validation" begin
        @test_throws ArgumentError ConstrainedJzScan(Float64[], 0.05, 15, (-10.0, 10.0))
        @test_throws ArgumentError ConstrainedJzScan([0.0], -0.1, 15, (-10.0, 10.0))
        @test_throws ArgumentError ConstrainedJzScan([0.0], 0.05, 0, (-10.0, 10.0))
        @test_throws ArgumentError ConstrainedJzScan([0.0], 0.05, 15, (10.0, -10.0))
    end
end
