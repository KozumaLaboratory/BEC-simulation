@testset "Pipeline" begin
    @testset "continuous ramp interpolators" begin
        # Linear
        f_lin = SpinorBEC._make_interpolator(Dict("from" => 100.0, "to" => 0.0))
        @test f_lin(0.0) == 100.0
        @test f_lin(0.5) == 50.0
        @test f_lin(1.0) == 0.0

        # Log scale — g(t) = log(1 + (e-1)*t) time-warp (dense at start),
        # not a geometric interpolator. At t=0.5: g ≈ log(1.859) ≈ 0.6200,
        # so value ≈ from + (to-from)*g(0.5) = 100 - 99*0.6200 ≈ 38.62.
        f_log = SpinorBEC._make_interpolator(Dict("from" => 100.0, "to" => 1.0, "scale" => "log"))
        @test f_log(0.0) ≈ 100.0
        @test f_log(1.0) ≈ 1.0
        @test f_log(0.5) ≈ 100.0 + (1.0 - 100.0) * log(1.0 + (ℯ - 1.0) * 0.5)

        # Sqrt scale
        f_sqrt = SpinorBEC._make_interpolator(Dict("from" => 100.0, "to" => 0.0, "scale" => "sqrt"))
        @test f_sqrt(0.0) ≈ 100.0
        @test f_sqrt(1.0) ≈ 0.0 atol=1e-10

        # Cosine scale (S-curve)
        f_cos = SpinorBEC._make_interpolator(Dict("from" => 0.0, "to" => 1.0, "scale" => "cosine"))
        @test f_cos(0.0) ≈ 0.0 atol=1e-15
        @test f_cos(1.0) ≈ 1.0 atol=1e-15
        @test f_cos(0.5) ≈ 0.5 atol=1e-15  # symmetric midpoint

        # Exponential scale
        f_exp = SpinorBEC._make_interpolator(Dict("from" => 100.0, "to" => 1.0, "scale" => "exponential"))
        @test f_exp(0.0) ≈ 100.0
        @test f_exp(1.0) ≈ 1.0 atol=1e-10

        # Scalar (constant)
        f_const = SpinorBEC._make_interpolator(42.0)
        @test f_const(0.0) == 42.0
        @test f_const(0.5) == 42.0
        @test f_const(1.0) == 42.0
    end

    @testset "c_dd ramp in ground state" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: [16]
                box: [12.0]
              interactions:
                c0: 10.0
                c1: -0.5
              ddi:
                enabled: true
                c_dd: {from: 0.0, to: 0.001, scale: linear}
              dt: 0.01
              n_steps: 50
              tol: 1.0e-4
              initial_state: polar
              zeeman: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0]}
        """
        config = load_config_from_string(yaml_str)
        @test config.steps[1] isa SpinorBEC.GroundStateStep
        p = config.steps[1].params
        @test p["ddi"]["c_dd"] isa Dict
        @test p["ddi"]["c_dd"]["from"] == 0.0
        @test p["ddi"]["c_dd"]["to"] == 0.001

        result = run_config(config; verbose=false)
        @test result.ground_state_energy isa Float64
        @test isfinite(result.ground_state_energy)
    end

    @testset "dynamics inherits from ground state" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: [16]
                box: [12.0]
              interactions:
                c0: 10.0
                c1: -0.5
              dt: 0.01
              n_steps: 50
              tol: 1e-4
              zeeman: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0]}
          - dynamics:
              duration: 0.02
              dt: 0.001
              save_every: 10
              zeeman: {p: 0.0, q: 0.1}
        """
        config = load_config_from_string(yaml_str)
        result = run_config(config; verbose=false)

        @test result.dynamics_result !== nothing
        @test length(result.dynamics_result.energies) > 0
        ws = result.dynamics_workspace
        @test ws.interactions.c0 ≈ 10.0
        @test ws.interactions.c1 ≈ -0.5
    end

    @testset "analyzer dispatch" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: [16]
                box: [12.0]
              interactions:
                c0: 10.0
                c1: -0.5
              dt: 0.01
              n_steps: 50
              tol: 1e-4
              zeeman: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0]}
          - analyze:
              - phase_classify: {}
        """
        config = load_config_from_string(yaml_str)
        result = run_config(config; verbose=false)

        @test haskey(result, :phase_classify)
        @test haskey(result.phase_classify, :spin_order)
        @test haskey(result.phase_classify, :phase)
    end

    @testset "auto_rotate_psi" begin
        # Construct a simple ferromagnetic psi (1D, F=1)
        grid = make_grid(GridConfig((16,), (10.0,)))
        sys = SpinSystem(1)
        psi = init_psi(grid, sys; state=:ferromagnetic)

        # No rotation when prev_mz is NaN
        psi_out = SpinorBEC.auto_rotate_psi(psi,
            Dict("pipeline" => [Dict("ground_state" => Dict("atom" => "Rb87", "target_magnetization" => 0.0))]),
            NaN)
        @test psi_out === psi  # identity, not a copy

        # No rotation when target_magnetization absent
        psi_out = SpinorBEC.auto_rotate_psi(psi,
            Dict("pipeline" => [Dict("ground_state" => Dict("atom" => "Rb87"))]),
            -1.0)
        @test psi_out === psi

        # Rotation when Mz changes
        psi_rot = SpinorBEC.auto_rotate_psi(psi,
            Dict("pipeline" => [Dict("ground_state" => Dict("atom" => "Rb87", "target_magnetization" => 0.0))]),
            -1.0)
        @test psi_rot !== psi  # different array
        @test size(psi_rot) == size(psi)
    end

    @testset "parse pipeline errors" begin
        @test_throws ArgumentError load_config_from_string("pipeline: []")
        @test_throws ArgumentError load_config_from_string("""
        pipeline:
          - unknown_step:
              foo: bar
        """)
    end

    @testset "scan parsing" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: 8, box: 6.0}
              interactions: {c0: 10.0, c1: 0.0}
              dt: 0.01
              n_steps: 50
              tol: 1e-4
              potential: {type: harmonic, omega: [1.0]}
        scan:
          zip:
            pipeline.0.interactions.c1: [-1.0, 0.0, 1.0]
          continuation: true
        """
        config = load_config_from_string(yaml_str)
        @test config.scan isa OverrideScan
        @test length(config.scan.points) == 3
        @test config.scan.continuation == true
        @test config.scan.auto_rotate_on_mz == false
    end
end
