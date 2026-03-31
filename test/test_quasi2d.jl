@testset "Quasi-2D Dimensional Reduction" begin
    @testset "rescale_interactions_quasi2d" begin
        ip = InteractionParams(100.0, -5.0, 10.0, [3.0])
        l_z = 0.5
        ip2d = rescale_interactions_quasi2d(ip, l_z)
        factor = quasi2d_interaction_factor(l_z)

        @test ip2d.c0 ≈ ip.c0 * factor
        @test ip2d.c1 ≈ ip.c1 * factor
        @test ip2d.c_lhy ≈ ip.c_lhy * factor
        @test ip2d.c_extra[1] ≈ ip.c_extra[1] * factor
    end

    @testset "quasi2d_interaction_factor" begin
        l_z = 1.0
        @test quasi2d_interaction_factor(l_z) ≈ 1.0 / sqrt(2π) rtol = 1e-10
        @test quasi2d_interaction_factor(2.0) ≈ 1.0 / (sqrt(2π) * 2.0) rtol = 1e-10
    end

    @testset "rescale_interactions_quasi2d throws for l_z <= 0" begin
        ip = InteractionParams(100.0, -5.0)
        @test_throws ArgumentError rescale_interactions_quasi2d(ip, 0.0)
        @test_throws ArgumentError rescale_interactions_quasi2d(ip, -1.0)
    end

    @testset "make_workspace with quasi_2d_rescale" begin
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=10)
        ip = InteractionParams(100.0, -5.0)
        l_z = 0.847

        # Without rescaling
        ws_no = make_workspace(;
            grid, atom=Rb87,
            interactions=ip,
            potential=HarmonicTrap(1.0, 1.0),
            sim_params=sp,
        )
        @test ws_no.interactions.c0 == 100.0

        # With rescaling
        ws_yes = make_workspace(;
            grid, atom=Rb87,
            interactions=ip,
            potential=HarmonicTrap(1.0, 1.0),
            sim_params=sp,
            quasi_2d_rescale=true,
            l_z_ddi=l_z,
        )
        factor = quasi2d_interaction_factor(l_z)
        @test ws_yes.interactions.c0 ≈ 100.0 * factor rtol = 1e-10
        @test ws_yes.interactions.c1 ≈ -5.0 * factor rtol = 1e-10
    end

    @testset "YAML rescale_interactions parsing" begin
        yaml = """
        experiment:
          type: dynamics
          name: quasi2d_test
          system:
            atom: Rb87
            grid:
              n_points: [32, 32]
              box_size: [10.0, 10.0]
            interactions:
              c0: 100.0
              c1: -5.0
            ddi:
              enabled: true
              c_dd: 50.0
              quasi_2d: true
              l_z: 0.847
              rescale_interactions: true
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """
        cfg = load_config_from_string(yaml)
        @test cfg.system.ddi.rescale_interactions == true
        @test cfg.system.ddi.quasi_2d == true
        @test cfg.system.ddi.l_z ≈ 0.847
    end

    @testset "YAML default rescale_interactions=false" begin
        yaml = """
        experiment:
          type: dynamics
          name: quasi2d_default_test
          system:
            atom: Rb87
            grid:
              n_points: [32, 32]
              box_size: [10.0, 10.0]
            interactions:
              c0: 100.0
              c1: -5.0
            ddi:
              enabled: true
              c_dd: 50.0
              quasi_2d: true
              l_z: 0.847
          ground_state:
            dt: 0.01
            n_steps: 10
            tol: 1e-4
            potential:
              type: harmonic
              omega: [1.0, 1.0]
          sequence: []
        """
        cfg = load_config_from_string(yaml)
        @test cfg.system.ddi.rescale_interactions == false
    end
end
