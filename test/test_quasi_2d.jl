@testset "Quasi-2D dimensional reduction" begin
    @testset "parsing quasi_2d + l_z in pipeline" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              quasi_2d: true
              l_z: 1.5
              grid:
                n: [16, 16]
                box: [10.0, 10.0]
              interactions:
                c0: 10.0
                c1: -0.5
              ddi:
                enabled: true
                c_dd: 1.0
                quasi_2d: true
                l_z: 1.5
              dt: 0.01
              n_steps: 10
              tol: 1e-4
              trap: [1.0, 1.0]
        """

        config = load_config_from_string(yaml_str)
        @test config isa PipelineConfig
        p = config.steps[1].params
        @test p["quasi_2d"] == true
        @test p["l_z"] == 1.5
        @test p["ddi"]["quasi_2d"] == true
        @test p["ddi"]["l_z"] == 1.5
    end

    @testset "end-to-end: run_config ground_state 2D" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: [16, 16]
                box: [10.0, 10.0]
              interactions:
                c0: 10.0
                c1: -0.5
              dt: 0.005
              n_steps: 100
              tol: 1.0e-4
              initial_state: polar
              zeeman:
                p: 0.0
                q: 0.0
              trap: [1.0, 1.0]
        """

        config = load_config_from_string(yaml_str)
        result = run_config(config; verbose = false)
        @test result.ground_state_energy isa Float64
        @test result.ground_state_converged isa Bool
    end
end
