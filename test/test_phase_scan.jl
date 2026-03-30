using FFTW

@testset "Phase Scan" begin
    @testset "YAML parsing - 1D parameter scan" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test 1D"
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
            type: parameter
            axes:
              - parameter: c1_ratio
                values:
                  from: -0.01
                  to: 0.03
                  n_points: 5
            continuation:
              enabled: true
              n_steps: 50
              energy_jump_threshold: 0.2
          output:
            dir: /tmp/test_phase_scan
            csv: true
            save_psi: false
        """
        config = load_config_from_string(yaml)
        @test config.name == "test 1D"
        @test config.spec.scan isa ParameterScan
        @test length(config.spec.scan.axes) == 1
        @test config.spec.scan.axes[1].parameter == :c1_ratio
        @test config.spec.scan.axes[1].values isa ScanValues
        @test config.spec.scan.axes[1].values.n_points == 5
        @test config.spec.scan.continuation.enabled == true
        @test config.spec.scan.continuation.n_steps == 50
        @test config.spec.stability.enabled == false
        @test config.output.dir == "/tmp/test_phase_scan"
        @test config.ground_state.rotating_frame_omega == 0.0
        @test config.ground_state.enable_ddi === nothing
    end

    @testset "YAML parsing - 2D parameter scan" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test 2D"
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
            type: parameter
            axes:
              - parameter: c1_ratio
                values:
                  from: -0.01
                  to: 0.03
                  n_points: 3
              - parameter: zeeman_q
                values: [0.0, 1.0, 2.0]
          output:
            dir: /tmp/test_phase_scan_2d
            csv: false
        """
        config = load_config_from_string(yaml)
        @test config.spec.scan isa ParameterScan
        @test length(config.spec.scan.axes) == 2
        @test config.spec.scan.axes[1].parameter == :c1_ratio
        @test config.spec.scan.axes[2].parameter == :zeeman_q
        @test config.spec.scan.axes[2].values isa Vector{Float64}
        @test length(config.spec.scan.axes[2].values) == 3
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
        @test config.spec.scan.tolerance == 0.1
        @test config.spec.scan.max_iter == 5
        @test config.spec.scan.omega_range == (-5.0, 5.0)
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
            type: parameter
            axes:
              - parameter: c1_ratio
                values: [-0.01, 0.0, 0.01]
          stability:
            enabled: true
            perturbation: 1.0e-3
            n_steps: 50
            sample_every: 5
        """
        config = load_config_from_string(yaml)
        @test config.spec.stability.enabled == true
        @test config.spec.stability.perturbation == 1e-3
        @test config.spec.stability.n_steps == 50
        @test config.spec.stability.sample_every == 5
    end

    @testset "YAML parsing - multistart in scan" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test multistart"
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
            target_magnetization: 0.5
          scan:
            type: parameter
            axes:
              - parameter: zeeman_p
                values: [0.0, 1.0]
            multistart:
              enabled: true
              initial_states: [polar, ferromagnetic]
              n_random: 2
        """
        config = load_config_from_string(yaml)
        @test config.spec.scan.multistart.enabled == true
        @test config.spec.scan.multistart.initial_states == [:polar, :ferromagnetic]
        @test config.spec.scan.multistart.n_random == 2
        @test config.ground_state.target_magnetization == 0.5
    end

    @testset "YAML parsing - quasi_2d DDI" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test quasi-2d"
          system:
            atom: Eu151
            grid:
              n_points: [8, 8]
              box_size: [6.0, 6.0]
            interactions:
              c_total: 4689.0
              c1_ratio: 0.0
            ddi:
              enabled: true
              c_dd: 7647.0
              quasi_2d: true
              l_z: 0.847
          ground_state:
            dt: 0.01
            n_steps: 100
            tol: 1e-6
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          scan:
            type: parameter
            axes:
              - parameter: c1_ratio
                values: [0.0, 0.01]
        """
        config = load_config_from_string(yaml)
        @test config.system.ddi.enabled == true
        @test config.system.ddi.quasi_2d == true
        @test config.system.ddi.l_z ≈ 0.847
    end

    @testset "YAML parsing - rotating_frame_omega" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test rotating"
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
            rotating_frame_omega: 0.5
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          scan:
            type: parameter
            axes:
              - parameter: rotating_frame_omega
                values: [0.0, 0.5, 1.0]
        """
        config = load_config_from_string(yaml)
        @test config.ground_state.rotating_frame_omega == 0.5
        @test config.spec.scan.axes[1].parameter == :rotating_frame_omega
    end

    @testset "YAML parsing - default scan options" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test defaults"
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
            type: parameter
            axes:
              - parameter: c1_ratio
                values: [0.0, 0.01]
        """
        config = load_config_from_string(yaml)
        @test config.spec.scan.continuation.enabled == true
        @test config.spec.scan.continuation.n_steps == 1000
        @test config.spec.scan.multistart.enabled == false
    end

    @testset "YAML parsing - constrained_jz defaults" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test Jz defaults"
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
            target_values: [0.0, 1.0]
        """
        config = load_config_from_string(yaml)
        @test config.spec.scan isa ConstrainedJzScan
        @test config.spec.scan.tolerance == 0.05
        @test config.spec.scan.max_iter == 15
        @test config.spec.scan.omega_range == (-10.0, 10.0)
    end

    @testset "YAML parsing - enable_ddi override" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test enable_ddi"
          system:
            atom: Rb87
            grid:
              n_points: 8
              box_size: 6.0
            interactions:
              c0: 100.0
              c1: -5.0
            ddi:
              enabled: true
              c_dd: 100.0
          ground_state:
            dt: 0.01
            n_steps: 100
            tol: 1e-6
            enable_ddi: false
            potential:
              type: harmonic
              omega: [1.0]
          scan:
            type: parameter
            axes:
              - parameter: c1_ratio
                values: [0.0, 0.01]
        """
        config = load_config_from_string(yaml)
        @test config.system.ddi.enabled == true
        @test config.ground_state.enable_ddi == false
    end

    @testset "Unified GroundStateConfig" begin
        yaml_exp = """
        experiment:
          type: dynamics
          name: unified_gs_test
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
            n_steps: 100
            tol: 1.0e-6
            target_magnetization: 0.5
            rotating_frame_omega: 0.3
            potential:
              type: harmonic
              omega: [1.0]
          sequence: []
        """
        cfg = load_config_from_string(yaml_exp)
        gs = cfg.ground_state
        @test gs isa GroundStateConfig
        @test gs.target_magnetization == 0.5
        @test gs.rotating_frame_omega == 0.3
        @test gs.enable_ddi === nothing

        yaml_scan = """
        experiment:
          type: phase_scan
          name: unified_gs_scan
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
            n_steps: 100
            tol: 1e-6
            target_magnetization: 0.5
            rotating_frame_omega: 0.3
            potential:
              type: harmonic
              omega: [1.0]
          scan:
            type: parameter
            axes:
              - parameter: c1_ratio
                values: [0.0, 0.01]
        """
        cfg2 = load_config_from_string(yaml_scan)
        @test cfg2.ground_state isa GroundStateConfig
        @test cfg2.ground_state.target_magnetization == 0.5
        @test cfg2.ground_state.rotating_frame_omega == 0.3
    end

    @testset "_sweep_values" begin
        sv = ScanValues(0.0, 1.0, 5)
        vals = collect(SpinorBEC._sweep_values(sv))
        @test length(vals) == 5
        @test vals[1] ≈ 0.0
        @test vals[end] ≈ 1.0

        v = [1.0, 2.0, 3.0]
        @test SpinorBEC._sweep_values(v) === v
    end

    @testset "_apply_sweep_param" begin
        # Rb87: F=1, c_total = c0 + F^2*c1 = 100 + 1*(-5) = 95
        state = (interactions=InteractionParams(100.0, -5.0),
                 zeeman=ZeemanParams(1.0, 0.5),
                 c_dd_override=nothing,
                 rotating_frame_omega=0.0)

        r = SpinorBEC._apply_sweep_param(state, :zeeman_p, 2.0; c_total=95.0, F=1)
        @test r.zeeman.p == 2.0
        @test r.zeeman.q == 0.5
        @test r.interactions === state.interactions

        r = SpinorBEC._apply_sweep_param(state, :zeeman_q, 3.0; c_total=95.0, F=1)
        @test r.zeeman.p == 1.0
        @test r.zeeman.q == 3.0

        r = SpinorBEC._apply_sweep_param(state, :c_dd, 500.0; c_total=95.0, F=1)
        @test r.c_dd_override == 500.0
        @test r.interactions === state.interactions

        r = SpinorBEC._apply_sweep_param(state, :c1_ratio, 0.0; c_total=95.0, F=1)
        @test r.interactions.c0 ≈ 95.0
        @test r.interactions.c1 ≈ 0.0

        r = SpinorBEC._apply_sweep_param(state, :rotating_frame_omega, 1.5; c_total=95.0, F=1)
        @test r.rotating_frame_omega == 1.5
        @test r.interactions === state.interactions

        @test_throws ArgumentError SpinorBEC._apply_sweep_param(
            state, :unknown, 1.0; c_total=95.0, F=1)
    end

    @testset "_apply_sweep_param chaining (2D)" begin
        state = (interactions=InteractionParams(100.0, -5.0),
                 zeeman=ZeemanParams(1.0, 0.5),
                 c_dd_override=nothing,
                 rotating_frame_omega=0.0)

        s1 = SpinorBEC._apply_sweep_param(state, :c1_ratio, 0.0; c_total=95.0, F=1)
        s2 = SpinorBEC._apply_sweep_param(s1, :zeeman_q, 2.0; c_total=95.0, F=1)

        @test s2.interactions.c0 ≈ 95.0
        @test s2.interactions.c1 ≈ 0.0
        @test s2.zeeman.p == 1.0
        @test s2.zeeman.q == 2.0
        @test s2.rotating_frame_omega == 0.0
    end

    @testset "Tiny 1D scan" begin
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
            type: parameter
            axes:
              - parameter: zeeman_q
                values: [0.0, 0.5, 1.0]
            continuation:
              enabled: false
              n_steps: 30
              energy_jump_threshold: 0.5
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

        csv_path = "/tmp/test_tiny_scan/scan_1d.csv"
        @test isfile(csv_path)
        lines = readlines(csv_path)
        @test length(lines) == 4  # header + 3 data rows
        @test startswith(lines[1], "zeeman_q,")

        rm("/tmp/test_tiny_scan"; recursive=true, force=true)
    end

    @testset "YAML parsing - per_point_overrides" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "test overrides"
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
            type: parameter
            axes:
              - parameter: c1_ratio
                values:
                  from: -0.02
                  to: 0.03
                  n_points: 5
            per_point_overrides:
              - parameter: c1_ratio
                range:
                  from: -0.005
                  to: 0.005
                n_steps: 10000
                tol: 1.0e-10
        """
        config = load_config_from_string(yaml)
        @test length(config.spec.scan.per_point_overrides) == 1
        ov = config.spec.scan.per_point_overrides[1]
        @test ov.parameter == :c1_ratio
        @test ov.range == (-0.005, 0.005)
        @test ov.overrides[:n_steps] == 10000
        @test ov.overrides[:tol] == 1e-10
    end

    @testset "ScanPointOverride validation" begin
        @test_throws ArgumentError ScanPointOverride(:c1_ratio, (0.0, 1.0), Dict{Symbol,Any}())
        @test_throws ArgumentError ScanPointOverride(:c1_ratio, (0.0, 1.0),
            Dict{Symbol,Any}(:unknown_key => 1))
        @test_throws ArgumentError ScanPointOverride(:c1_ratio, (1.0, 0.0),
            Dict{Symbol,Any}(:n_steps => 100))
        ov = ScanPointOverride(:c1_ratio, (0.0, 1.0),
            Dict{Symbol,Any}(:n_steps => 500, :tol => 1e-10))
        @test ov.overrides[:n_steps] == 500
    end

    @testset "_resolve_overrides" begin
        pot = PotentialConfig(:harmonic, Dict{String,Any}("omega" => [1.0]))
        gs = GroundStateConfig(0.01, 100, 1e-6, :polar, ZeemanParams(0.0, 0.0),
                               pot, nothing, nothing, 0.0)

        ov = ScanPointOverride(:c1_ratio, (-0.005, 0.005),
            Dict{Symbol,Any}(:n_steps => 5000, :tol => 1e-10))

        # In range
        r = SpinorBEC._resolve_overrides(gs, [ov], Dict{Symbol,Float64}(:c1_ratio => 0.001))
        @test r.n_steps == 5000
        @test r.tol == 1e-10
        @test r.dt == 0.01
        @test r.initial_state == :polar

        # Out of range
        r2 = SpinorBEC._resolve_overrides(gs, [ov], Dict{Symbol,Float64}(:c1_ratio => 0.02))
        @test r2.n_steps == 100
        @test r2.tol == 1e-6

        # No overrides
        r3 = SpinorBEC._resolve_overrides(gs, ScanPointOverride[], Dict{Symbol,Float64}(:c1_ratio => 0.0))
        @test r3.n_steps == 100
    end

    @testset "ParameterScan with default overrides" begin
        axis = ScanAxis(:c1_ratio, ScanValues(0.0, 1.0, 3))
        ps = ParameterScan([axis])
        @test isempty(ps.per_point_overrides)
    end

    @testset "Type constructors" begin
        @test_throws ArgumentError ScanValues(0.0, 1.0, 1)
        @test_throws ArgumentError ContinuationConfig(true, 0, 0.1)
        @test_throws ArgumentError ContinuationConfig(true, 100, -0.1)
        @test_throws ArgumentError ScanStabilityConfig(true, -1.0, 300, 10)

        # ParameterScan validation
        @test_throws ArgumentError ParameterScan(ScanAxis[])
        axis = ScanAxis(:c1_ratio, ScanValues(0.0, 1.0, 3))
        @test ParameterScan([axis]).axes[1].parameter == :c1_ratio
        @test_throws ArgumentError ParameterScan([axis, axis, axis])

        # ConstrainedJzScan validation
        @test_throws ArgumentError ConstrainedJzScan(Float64[], 0.05, 15, (-10.0, 10.0))
        @test_throws ArgumentError ConstrainedJzScan([0.0], -0.1, 15, (-10.0, 10.0))
        @test_throws ArgumentError ConstrainedJzScan([0.0], 0.05, 0, (-10.0, 10.0))
        @test_throws ArgumentError ConstrainedJzScan([0.0], 0.05, 15, (10.0, -10.0))

        c = ContinuationConfig()
        @test c.enabled == true
        @test c.n_steps == 1000

        s = ScanStabilityConfig()
        @test s.enabled == false

        ms = MultiStartConfig()
        @test ms.enabled == false
        @test ms.n_random == 0

        # GroundStateConfig validation
        pot = PotentialConfig(:harmonic, Dict{String,Any}("omega" => [1.0]))
        @test_throws ArgumentError GroundStateConfig(
            -0.01, 100, 1e-6, :polar, ZeemanParams(0.0, 0.0), pot, nothing, nothing, 0.0)
        @test_throws ArgumentError GroundStateConfig(
            0.01, 0, 1e-6, :polar, ZeemanParams(0.0, 0.0), pot, nothing, nothing, 0.0)
        @test_throws ArgumentError GroundStateConfig(
            0.01, 100, -1e-6, :polar, ZeemanParams(0.0, 0.0), pot, nothing, nothing, 0.0)
    end
end
