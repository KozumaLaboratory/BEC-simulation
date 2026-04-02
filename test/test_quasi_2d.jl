@testset "Quasi-2D dimensional reduction" begin
    @testset "parsing quasi_2d + l_z scales interactions" begin
        yaml_str = """
        experiment:
          type: dynamics
          name: "quasi2d test"
          system:
            atom: Rb87
            quasi_2d: true
            l_z: 1.5
            grid:
              n_points: [16, 16]
              box_size: [10.0, 10.0]
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """

        config = load_config_from_string(yaml_str)
        factor = 1.0 / (sqrt(2π) * 1.5)
        @test config.system.quasi_2d == true
        @test config.system.l_z == 1.5
        @test config.system.interactions.c0 ≈ 10.0 * factor
        @test config.system.interactions.c1 ≈ -0.5 * factor
    end

    @testset "c_total mode scales after splitting" begin
        yaml_str = """
        experiment:
          type: dynamics
          name: "quasi2d c_total"
          system:
            atom: Rb87
            quasi_2d: true
            l_z: 2.0
            grid:
              n_points: [16, 16]
              box_size: [10.0, 10.0]
            interactions:
              c_total: 100.0
              c1_ratio: -0.1
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """

        config = load_config_from_string(yaml_str)
        factor = 1.0 / (sqrt(2π) * 2.0)
        ip = config.system.interactions
        ip_3d = interaction_params_from_constraint(; c_total = 100.0, c1_ratio = -0.1, F = 1)
        @test ip.c0 ≈ ip_3d.c0 * factor
        @test ip.c1 ≈ ip_3d.c1 * factor
    end

    @testset "validation: 3D grid + quasi_2d → error" begin
        yaml_str = """
        experiment:
          type: dynamics
          name: "bad quasi2d"
          system:
            atom: Rb87
            quasi_2d: true
            l_z: 1.5
            grid:
              n_points: [16, 16, 16]
              box_size: [10.0, 10.0, 10.0]
            interactions:
              c0: 10.0
              c1: 0.0
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0, 1.0, 1.0]
          sequence: []
        """
        @test_throws ArgumentError load_config_from_string(yaml_str)
    end

    @testset "validation: l_z ≤ 0 → error" begin
        yaml_str = """
        experiment:
          type: dynamics
          name: "bad lz"
          system:
            atom: Rb87
            quasi_2d: true
            l_z: 0.0
            grid:
              n_points: [16, 16]
              box_size: [10.0, 10.0]
            interactions:
              c0: 10.0
              c1: 0.0
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """
        @test_throws ArgumentError load_config_from_string(yaml_str)
    end

    @testset "backward compat: no quasi_2d → interactions unchanged" begin
        yaml_str = """
        experiment:
          type: dynamics
          name: "no quasi2d"
          system:
            atom: Rb87
            grid:
              n_points: [16, 16]
              box_size: [10.0, 10.0]
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """

        config = load_config_from_string(yaml_str)
        @test config.system.quasi_2d == false
        @test config.system.l_z == 0.0
        @test config.system.interactions.c0 == 10.0
        @test config.system.interactions.c1 == -0.5
    end

    @testset "DDI inherits system-level quasi_2d/l_z" begin
        yaml_str = """
        experiment:
          type: dynamics
          name: "ddi inherit"
          system:
            atom: Rb87
            quasi_2d: true
            l_z: 1.5
            grid:
              n_points: [16, 16]
              box_size: [10.0, 10.0]
            interactions:
              c0: 10.0
              c1: 0.0
            ddi:
              enabled: true
              c_dd: 1.0
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """

        config = load_config_from_string(yaml_str)
        @test config.system.ddi.quasi_2d == true
        @test config.system.ddi.l_z == 1.5
    end

    @testset "DDI section overrides system-level" begin
        yaml_str = """
        experiment:
          type: dynamics
          name: "ddi override"
          system:
            atom: Rb87
            quasi_2d: true
            l_z: 1.5
            grid:
              n_points: [16, 16]
              box_size: [10.0, 10.0]
            interactions:
              c0: 10.0
              c1: 0.0
            ddi:
              enabled: true
              c_dd: 1.0
              quasi_2d: false
              l_z: 0.0
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """

        config = load_config_from_string(yaml_str)
        @test config.system.ddi.quasi_2d == false
        @test config.system.ddi.l_z == 0.0
    end

    @testset "no DDI section + quasi_2d → DDI gets defaults with quasi_2d/l_z" begin
        yaml_str = """
        experiment:
          type: dynamics
          name: "no ddi section"
          system:
            atom: Rb87
            quasi_2d: true
            l_z: 1.5
            grid:
              n_points: [16, 16]
              box_size: [10.0, 10.0]
            interactions:
              c0: 10.0
              c1: 0.0
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """

        config = load_config_from_string(yaml_str)
        @test config.system.ddi.enabled == false
        @test config.system.ddi.quasi_2d == true
        @test config.system.ddi.l_z == 1.5
    end

    @testset "end-to-end: run_config with quasi_2d" begin
        yaml_str = """
        experiment:
          type: dynamics
          name: "e2e quasi2d"
          system:
            atom: Rb87
            quasi_2d: true
            l_z: 2.0
            grid:
              n_points: [16, 16]
              box_size: [10.0, 10.0]
            interactions:
              c0: 10.0
              c1: -0.5
          ground_state:
            dt: 0.005
            n_steps: 100
            tol: 1.0e-4
            initial_state: polar
            zeeman:
              p: 0.0
              q: 0.0
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """

        config = load_config_from_string(yaml_str)
        result = run_config(config; verbose = false)
        @test result.ground_state_energy isa Float64
        @test result.ground_state_converged isa Bool
    end
end
