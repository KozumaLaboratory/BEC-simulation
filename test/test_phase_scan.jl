using FFTW

@testset "Phase Scan" begin
    @testset "Override primitive: apply_override!" begin
        d = Dict{String,Any}("a" => Dict{String,Any}("b" => 1))
        SpinorBEC.apply_override!(d, "a.b", 42)
        @test d["a"]["b"] == 42

        # Creates intermediate dicts
        SpinorBEC.apply_override!(d, "a.c.d", "x")
        @test d["a"]["c"]["d"] == "x"

        # Multi-key apply_overrides
        out = SpinorBEC.apply_overrides(d, Dict{String,Any}("a.b" => 7, "z" => true))
        @test out["a"]["b"] == 7
        @test out["z"] == true
        @test d["a"]["b"] == 42  # base unchanged
    end

    @testset "expand_scan_points: zip" begin
        scan = Dict{String,Any}(
            "zip" => Dict{String,Any}(
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
        @test_throws ArgumentError SpinorBEC.expand_scan_points(Dict{String,Any}(
            "zip" => Dict{String,Any}("a.b" => [1, 2], "c.d" => [1, 2, 3]),
        ))
    end

    @testset "expand_scan_points: product" begin
        scan = Dict{String,Any}(
            "product" => Dict{String,Any}(
                "system.interactions.c1_ratio" => [-0.01, 0.0],
                "ground_state.target_magnetization" => [-6.0, -3.0, 0.0],
            ),
        )
        pts = SpinorBEC.expand_scan_points(scan)
        @test length(pts) == 6
        # Each combination present exactly once
        combos = Set([(p["system.interactions.c1_ratio"], p["ground_state.target_magnetization"]) for p in pts])
        @test length(combos) == 6
    end

    @testset "expand_scan_points: zip and product mutually exclusive" begin
        @test_throws ArgumentError SpinorBEC.expand_scan_points(Dict{String,Any}(
            "zip" => Dict{String,Any}("a" => [1]),
            "product" => Dict{String,Any}("b" => [1]),
        ))
    end

    @testset "YAML parsing - override scan with zip" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test zip"
          system:
            atom: Rb87
            grid:
              n_points: 8
              box_size: 6.0
            interactions:
              c0: 100.0
              c1: -5.0
          ground_state:
            dt: 0.01
            n_steps: 100
            tol: 1e-6
            initial_state: polar
            zeeman:
              p: 0.0
              q: 0.0
            potential:
              type: harmonic
              omega: [1.0]
          scan:
            zip:
              ground_state.zeeman.p: [0.0, 0.5, 1.0]
            continuation: true
          output:
            dir: /tmp/test_phase_scan
            csv: true
        """
        config = load_config_from_string(yaml)
        @test config.spec.scan isa OverrideScan
        @test length(config.spec.scan.points) == 3
        @test config.spec.scan.points[1]["ground_state.zeeman.p"] == 0.0
        @test config.spec.scan.continuation == true
        @test config.spec.scan.auto_rotate_on_mz == false
    end

    @testset "YAML parsing - comparison_runs" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test comparison"
          system:
            atom: Rb87
            grid:
              n_points: 8
              box_size: 6.0
            interactions:
              c0: 100.0
              c1: -5.0
          ground_state:
            dt: 0.01
            n_steps: 100
            tol: 1e-6
            potential:
              type: harmonic
              omega: [1.0]
          scan:
            zip:
              system.interactions.c1: [-5.0, -1.0, 0.0]
            comparison_runs:
              - name: polar
                override:
                  ground_state.initial_state: polar
              - name: ferro
                override:
                  ground_state.initial_state: ferromagnetic
        """
        config = load_config_from_string(yaml)
        @test length(config.spec.scan.comparison_runs) == 2
        @test config.spec.scan.comparison_runs[1][1] == "polar"
        @test config.spec.scan.comparison_runs[2][2]["ground_state.initial_state"] == "ferromagnetic"
    end

    @testset "YAML parsing - constrained Jz scan" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test Jz"
          system:
            atom: Rb87
            grid:
              n_points: [8, 8]
              box_size: [6.0, 6.0]
            interactions:
              c0: 100.0
              c1: -5.0
          ground_state:
            dt: 0.01
            n_steps: 100
            tol: 1e-6
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          scan:
            type: constrained_jz
            target_values: [0.0, 1.0, 2.0]
            tolerance: 0.1
            max_iter: 5
            omega_range: [-5.0, 5.0]
        """
        config = load_config_from_string(yaml)
        @test config.spec.scan isa ConstrainedJzScan
        @test length(config.spec.scan.target_values) == 3
    end

    @testset "YAML parsing - stability" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test stability"
          system:
            atom: Rb87
            grid:
              n_points: 8
              box_size: 6.0
            interactions:
              c0: 100.0
              c1: -5.0
          ground_state:
            dt: 0.01
            n_steps: 100
            tol: 1e-6
            potential:
              type: harmonic
              omega: [1.0]
          scan:
            zip:
              system.interactions.c1: [-5.0, 0.0, 5.0]
          stability:
            enabled: true
            perturbation: 1.0e-3
            n_steps: 50
            sample_every: 5
        """
        config = load_config_from_string(yaml)
        @test config.spec.stability.enabled == true
        @test config.spec.stability.perturbation == 1e-3
    end

    @testset "Tiny end-to-end override scan" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "tiny scan"
          system:
            atom: Rb87
            grid:
              n_points: 8
              box_size: 6.0
            interactions:
              c0: 10.0
              c1: -1.0
          ground_state:
            dt: 0.01
            n_steps: 50
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0]
          scan:
            zip:
              ground_state.zeeman.q: [0.0, 0.5, 1.0]
          output:
            dir: /tmp/test_tiny_scan
            csv: true
            save_psi: false
        """
        config = load_config_from_string(yaml)
        results = run_config(config; verbose=false)

        @test length(results) == 3
        for r in results
            @test haskey(r, :energy)
            @test haskey(r, :phase_info)
            @test isfinite(r.energy)
        end

        csv_path = "/tmp/test_tiny_scan/scan.csv"
        @test isfile(csv_path)

        rm("/tmp/test_tiny_scan"; recursive=true, force=true)
    end

    @testset "OverrideScan validation" begin
        @test_throws ArgumentError OverrideScan(Dict{String,Any}[])
        os = OverrideScan([Dict{String,Any}("a.b" => 1)])
        @test length(os.points) == 1
        @test os.continuation == false
    end

    @testset "GroundStateConfig validation" begin
        pot = PotentialConfig(:harmonic, Dict{String,Any}("omega" => [1.0]))
        @test_throws ArgumentError GroundStateConfig(
            -0.01, 100, 1e-6, :polar, ZeemanParams(0.0, 0.0), pot, nothing, nothing, 0.0)
        @test_throws ArgumentError GroundStateConfig(
            0.01, 0, 1e-6, :polar, ZeemanParams(0.0, 0.0), pot, nothing, nothing, 0.0)
        @test_throws ArgumentError GroundStateConfig(
            0.01, 100, -1e-6, :polar, ZeemanParams(0.0, 0.0), pot, nothing, nothing, 0.0)
    end

    @testset "ConstrainedJzScan validation" begin
        @test_throws ArgumentError ConstrainedJzScan(Float64[], 0.05, 15, (-10.0, 10.0))
        @test_throws ArgumentError ConstrainedJzScan([0.0], -0.1, 15, (-10.0, 10.0))
        @test_throws ArgumentError ConstrainedJzScan([0.0], 0.05, 0, (-10.0, 10.0))
        @test_throws ArgumentError ConstrainedJzScan([0.0], 0.05, 15, (10.0, -10.0))
    end

    @testset "ScanStabilityConfig validation" begin
        @test_throws ArgumentError ScanStabilityConfig(true, -1.0, 300, 10)
        s = ScanStabilityConfig()
        @test s.enabled == false
    end
end
