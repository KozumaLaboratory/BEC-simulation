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
            )
        )
    end

    @testset "expand_scan_points: product" begin
        scan = Dict{String, Any}(
            "product" => Dict{String, Any}(
                "system.interactions.c1_ratio" => [-0.01, 0.0],
                "ground_state.target_magnetization" => [-6.0, -3.0, 0.0],
            ),
        )
        pts = SpinorBEC.expand_scan_points(scan)
        @test length(pts) == 6
        # Each combination present exactly once
        combos = Set([
            (p["system.interactions.c1_ratio"], p["ground_state.target_magnetization"]) for p in pts
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
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: 8
                box: 6.0
              interactions:
                c0: 100.0
                c1: -5.0
              dt: 0.01
              n_steps: 100
              tol: 1e-6
              initial_state: polar
              zeeman:
                p: 0.0
                q: 0.0
              potential: {type: harmonic, omega: [1.0]}
        scan:
          zip:
            pipeline.0.zeeman.p: [0.0, 0.5, 1.0]
          continuation: true
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
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: 8
                box: 6.0
              interactions:
                c0: 100.0
                c1: -5.0
              dt: 0.01
              n_steps: 100
              tol: 1e-6
              potential: {type: harmonic, omega: [1.0]}
        scan:
          zip:
            pipeline.0.interactions.c1: [-5.0, -1.0, 0.0]
          comparison_runs:
            - name: polar
              override:
                pipeline.0.initial_state: polar
            - name: ferro
              override:
                pipeline.0.initial_state: ferromagnetic
        """
        config = load_config_from_string(yaml)
        @test length(config.scan.comparison_runs) == 2
        @test config.scan.comparison_runs[1][1] == "polar"
        @test config.scan.comparison_runs[2][2]["pipeline.0.initial_state"] == "ferromagnetic"
    end

    @testset "YAML parsing - constrained Jz scan" begin
        yaml = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: [8, 8]
                box: [6.0, 6.0]
              interactions:
                c0: 100.0
                c1: -5.0
              dt: 0.01
              n_steps: 100
              tol: 1e-6
              potential: {type: harmonic, omega: [1.0, 1.0]}
        scan:
          type: constrained_jz
          target_values: [0.0, 1.0, 2.0]
          tolerance: 0.1
          max_iter: 5
          omega_range: [-5.0, 5.0]
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
