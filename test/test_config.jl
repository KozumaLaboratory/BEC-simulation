@testset "Unified Config" begin
    @testset "parsing - ground_state type" begin
        yaml = """
        experiment:
          
          name: "gs only"
          type: ground_state
          system:
            atom: Rb87
            grid:
              n_points: [32]
              box_size: [20.0]
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 100
            tol: 1.0e-8
            initial_state: polar
            zeeman:
              p: 0.0
              q: 0.1
            potential:
              type: harmonic
              omega: [1.0]
          output:
            dir: results/gs_test
            csv: false
            save_psi: true
        """
        cfg = load_config_from_string(yaml)
        @test cfg isa UnifiedConfig{GroundStateExperiment}
        
        @test cfg.name == "gs only"
        @test cfg.system.atom_name == :Rb87
        @test cfg.system.grid_n_points == [32]
        @test cfg.system.interactions.c0 == 10.0
        @test cfg.ground_state.dt == 0.005
        @test cfg.ground_state.n_steps == 100
        @test cfg.ground_state.zeeman.q == 0.1
        @test cfg.output.dir == "results/gs_test"
        @test cfg.output.csv == false
        @test cfg.output.save_psi == true
    end

    @testset "parsing - dynamics type" begin
        yaml = """
        experiment:
          
          name: "dynamics test"
          type: dynamics
          system:
            atom: Rb87
            grid:
              n_points: [32]
              box_size: [20.0]
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 100
            tol: 1.0e-8
            initial_state: polar
            zeeman:
              p: 0.0
              q: 0.1
            potential:
              type: harmonic
              omega: [1.0]
          perturbation:
            amplitude: 0.001
            seed: 42
          sequence:
            - name: evolve
              duration: 0.1
              dt: 0.01
              save_every: 5
              zeeman:
                p: 0.0
                q:
                  from: 0.1
                  to: -0.5
              potential:
                type: harmonic
                omega: [1.0]
          output:
            dir: results/dynamics_test
            seed: 123
        """
        cfg = load_config_from_string(yaml)
        @test cfg isa UnifiedConfig{DynamicsExperiment}
        @test cfg.spec.perturbation !== nothing
        @test cfg.spec.perturbation.amplitude == 0.001
        @test cfg.spec.perturbation.seed == 42
        @test length(cfg.spec.sequence) == 1
        @test cfg.spec.sequence[1].name == "evolve"
        @test cfg.spec.sequence[1].zeeman_q isa LinearRamp
        @test cfg.output.seed == 123
    end

    @testset "parsing - dynamics without perturbation" begin
        yaml = """
        experiment:
          type: dynamics
          name: "no perturb"
          system:
            atom: Rb87
            grid:
              n_points: [32]
              box_size: [20.0]
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 100
            tol: 1.0e-8
            potential:
              type: harmonic
              omega: [1.0]
          sequence: []
        """
        cfg = load_config_from_string(yaml)
        @test cfg isa UnifiedConfig{DynamicsExperiment}
        @test cfg.spec.perturbation === nothing
        @test isempty(cfg.spec.sequence)
    end

    @testset "parsing - phase_scan type" begin
        yaml = """
        experiment:
          
          name: "scan test"
          type: phase_scan
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
                  n_points: 5
            continuation:
              enabled: true
              n_steps: 50
              energy_jump_threshold: 0.2
          stability:
            enabled: true
            perturbation: 1e-3
            n_steps: 50
            sample_every: 5
          output:
            dir: results/scan_test
            csv: true
        """
        cfg = load_config_from_string(yaml)
        @test cfg isa UnifiedConfig{<:ScanExperiment}
        @test cfg.spec.scan isa ParameterScan
        @test length(cfg.spec.scan.axes) == 1
        @test cfg.spec.scan.axes[1].parameter == :c1_ratio
        @test cfg.spec.scan.continuation.n_steps == 50
        @test cfg.spec.stability.enabled == true
        @test cfg.spec.stability.perturbation == 1e-3
    end

    @testset "parsing - output defaults" begin
        yaml = """
        experiment:
          type: ground_state
          name: "defaults"
          system:
            atom: Rb87
            grid:
              n_points: 32
              box_size: 20.0
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 100
            tol: 1.0e-8
            potential:
              type: harmonic
              omega: [1.0]
        """
        cfg = load_config_from_string(yaml)
        @test cfg.output.dir == "results"
        @test cfg.output.csv == true
        @test cfg.output.save_psi == false
        @test cfg.output.checkpoint_enabled == false
        @test cfg.output.checkpoint_interval == 1000
        @test cfg.output.seed === nothing
    end

    @testset "parsing - checkpoint" begin
        yaml = """
        experiment:
          type: ground_state
          name: "checkpoint"
          system:
            atom: Rb87
            grid:
              n_points: 32
              box_size: 20.0
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 100
            tol: 1.0e-8
            potential:
              type: harmonic
              omega: [1.0]
          output:
            checkpoint:
              enabled: true
              interval: 500
        """
        cfg = load_config_from_string(yaml)
        @test cfg.output.checkpoint_enabled == true
        @test cfg.output.checkpoint_interval == 500
    end

    @testset "parsing - c_total/c1_ratio" begin
        yaml = """
        experiment:
          type: ground_state
          name: "c_total"
          system:
            atom: Eu151
            grid:
              n_points: 8
              box_size: 6.0
            interactions:
              c_total: 4689.0
              c1_ratio: 0.02778
            ddi:
              enabled: true
              c_dd: 7647.0
          ground_state:
            dt: 0.005
            n_steps: 100
            tol: 1.0e-8
            potential:
              type: harmonic
              omega: [1.0]
        """
        cfg = load_config_from_string(yaml)
        @test cfg.system.atom_name == :Eu151
        @test cfg.system.ddi.enabled == true
        @test cfg.system.ddi.c_dd == 7647.0
        c_total = cfg.system.interactions.c0 + 6^2 * cfg.system.interactions.c1
        @test c_total ≈ 4689.0 rtol=1e-10
    end

    @testset "parsing - unknown type error" begin
        yaml = """
        experiment:
          type: unknown_type
          name: "bad"
          system:
            atom: Rb87
            grid:
              n_points: 32
              box_size: 20.0
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 100
            tol: 1.0e-8
            potential:
              type: harmonic
              omega: [1.0]
        """
        @test_throws ArgumentError load_config_from_string(yaml)
    end

    @testset "ObservablesConfig defaults" begin
        yaml = """
        experiment:
          type: ground_state
          name: "obs defaults"
          system:
            atom: Rb87
            grid:
              n_points: 32
              box_size: 20.0
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 100
            tol: 1.0e-8
            potential:
              type: harmonic
              omega: [1.0]
        """
        cfg = load_config_from_string(yaml)
        obs = cfg.observables
        @test obs isa ObservablesConfig
        @test obs.always == [:norm, :magnetization]
        @test obs.on_save == [:energy]
        @test obs.final_only == Symbol[]
        @test obs.spatial_sampling == 1.0
    end

    @testset "ObservablesConfig parsing" begin
        yaml = """
        experiment:
          type: ground_state
          name: "obs custom"
          system:
            atom: Rb87
            grid:
              n_points: 32
              box_size: 20.0
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 100
            tol: 1.0e-8
            potential:
              type: harmonic
              omega: [1.0]
          observables:
            always: [norm]
            on_save: [energy, populations]
            final_only: [phase_classification, structure_factor]
            spatial_sampling: 0.01
        """
        cfg = load_config_from_string(yaml)
        obs = cfg.observables
        @test obs.always == [:norm]
        @test obs.on_save == [:energy, :populations]
        @test obs.final_only == [:phase_classification, :structure_factor]
        @test obs.spatial_sampling == 0.01
    end

    @testset "ObservablesConfig validation" begin
        @test_throws ArgumentError ObservablesConfig(Symbol[], Symbol[], Symbol[], 0.0)
        @test_throws ArgumentError ObservablesConfig(Symbol[], Symbol[], Symbol[], -0.1)
        @test_throws ArgumentError ObservablesConfig(Symbol[], Symbol[], Symbol[], 1.5)
        oc = ObservablesConfig()
        @test oc.spatial_sampling == 1.0
    end

    @testset "PerturbationConfig validation" begin
        @test_throws ArgumentError PerturbationConfig(-0.001, nothing)
        @test_throws ArgumentError PerturbationConfig(0.0, 42)
        pc = PerturbationConfig(0.01, 42)
        @test pc.amplitude == 0.01
        @test pc.seed == 42
    end

    @testset "OutputConfig defaults" begin
        oc = OutputConfig()
        @test oc.dir == "results"
        @test oc.csv == true
        @test oc.save_psi == false
        @test oc.checkpoint_enabled == false
        @test oc.checkpoint_interval == 1000
        @test oc.seed === nothing
    end

    @testset "run_config - ground_state" begin
        yaml = """
        experiment:
          type: ground_state
          name: "run gs"
          system:
            atom: Rb87
            grid:
              n_points: [32]
              box_size: [20.0]
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 200
            tol: 1.0e-6
            initial_state: polar
            zeeman:
              p: 0.0
              q: 0.1
            potential:
              type: harmonic
              omega: [1.0]
        """
        cfg = load_config_from_string(yaml)
        result = run_config(cfg; verbose=false)
        @test result.ground_state_energy isa Float64
        @test isfinite(result.ground_state_energy)
        @test result.ground_state_converged isa Bool
        @test result.psi isa AbstractArray
    end

    @testset "run_config - dynamics" begin
        yaml = """
        experiment:
          type: dynamics
          name: "run dynamics"
          system:
            atom: Rb87
            grid:
              n_points: [32]
              box_size: [20.0]
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 200
            tol: 1.0e-6
            initial_state: polar
            zeeman:
              p: 0.0
              q: 0.1
            potential:
              type: harmonic
              omega: [1.0]
          sequence:
            - name: evolve
              duration: 0.05
              dt: 0.001
              save_every: 25
              zeeman:
                p: 0.0
                q: 0.1
              potential:
                type: harmonic
                omega: [1.0]
        """
        cfg = load_config_from_string(yaml)
        result = run_config(cfg; verbose=false)
        @test result.ground_state_energy isa Float64
        @test length(result.phase_results) == 1
        @test result.phase_names == ["evolve"]
        @test length(result.phase_results[1].times) > 1
    end

    @testset "run_config - dynamics with perturbation" begin
        yaml = """
        experiment:
          type: dynamics
          name: "run perturbed"
          system:
            atom: Rb87
            grid:
              n_points: [32]
              box_size: [20.0]
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 200
            tol: 1.0e-6
            initial_state: polar
            zeeman:
              p: 0.0
              q: 0.1
            potential:
              type: harmonic
              omega: [1.0]
          perturbation:
            amplitude: 0.01
            seed: 42
          sequence:
            - name: evolve
              duration: 0.05
              dt: 0.001
              save_every: 25
              zeeman:
                p: 0.0
                q: 0.1
              potential:
                type: harmonic
                omega: [1.0]
        """
        cfg = load_config_from_string(yaml)
        result = run_config(cfg; verbose=false)
        @test length(result.phase_results) == 1
        @test all(n -> n > 0, result.phase_results[1].norms)
    end

    @testset "run_config - phase_scan" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "run scan"
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
                values: [0.0, 0.5]
            continuation:
              enabled: false
              n_steps: 30
              energy_jump_threshold: 0.5
          output:
            dir: /tmp/test_scan
            csv: true
            save_psi: false
        """
        cfg = load_config_from_string(yaml)
        results = run_config(cfg; verbose=false)
        @test length(results) == 2
        for r in results
            @test haskey(r, :energy)
            @test isfinite(r.energy)
        end
        rm("/tmp/test_scan"; recursive=true, force=true)
    end

    @testset "parsing - per_point_overrides in scan" begin
        yaml = """
        experiment:
          
          name: "override test"
          type: phase_scan
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
                n_steps: 5000
                tol: 1.0e-10
                dt: 0.005
              - parameter: c1_ratio
                range:
                  from: 0.02
                  to: 0.03
                initial_state: ferromagnetic
        """
        cfg = load_config_from_string(yaml)
        @test cfg.spec.scan isa ParameterScan
        @test length(cfg.spec.scan.per_point_overrides) == 2
        ov1 = cfg.spec.scan.per_point_overrides[1]
        @test ov1.parameter == :c1_ratio
        @test ov1.range == (-0.005, 0.005)
        @test ov1.overrides[:n_steps] == 5000
        @test ov1.overrides[:tol] == 1e-10
        @test ov1.overrides[:dt] == 0.005
        ov2 = cfg.spec.scan.per_point_overrides[2]
        @test ov2.overrides[:initial_state] == :ferromagnetic
    end

    @testset "parsing - constrained_jz scan" begin
        yaml = """
        experiment:
          type: phase_scan
          name: "jz scan"
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
            tolerance: 0.1
            max_iter: 5
            omega_range: [-5.0, 5.0]
        """
        cfg = load_config_from_string(yaml)
        @test cfg isa UnifiedConfig{<:ScanExperiment}
        @test cfg.spec.scan isa ConstrainedJzScan
        @test cfg.spec.scan.tolerance == 0.1
    end
end
