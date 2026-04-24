using JLD2

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

    @testset "bogoliubov analyzer" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [16, 16], box: [8.0, 8.0]}
              interactions: {c0: 10.0, c1: -0.5}
              dt: 0.01
              n_steps: 50
              tol: 1e-4
              initial_state: ferromagnetic
              zeeman: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0, 1.0]}
          - analyze:
              - bogoliubov: {k_max: 5.0, n_k: 40, directions: auto}
        """
        config = load_config_from_string(yaml_str)
        result = run_config(config; verbose=false)

        @test haskey(result, :bogoliubov)
        r = result.bogoliubov
        @test haskey(r, :max_growth)
        @test haskey(r, :unstable)
        @test haskey(r, :k_peak)
        @test haskey(r, :pattern)
        @test r.max_growth >= 0.0
        @test r.unstable isa Bool
    end

    @testset "droplet_profile on synthetic Gaussian" begin
        # Synthetic 3D isotropic Gaussian: n(r) = n0 * exp(-r^2/(2σ^2))
        # FWHM (analytic) = 2 σ √(2 ln 2); RMS width = σ.
        cfg = GridConfig((32, 32, 32), (8.0, 8.0, 8.0))
        grid = make_grid(cfg)
        σ = 0.9
        psi = zeros(ComplexF64, 32, 32, 32, 3)
        @inbounds for k in 1:32, j in 1:32, i in 1:32
            x = grid.x[1][i]; y = grid.x[2][j]; z = grid.x[3][k]
            r2 = x^2 + y^2 + z^2
            psi[i, j, k, 1] = sqrt(exp(-r2 / (2σ^2)))
        end
        # Normalize so the analyzer reads a sane N_atoms
        dV = SpinorBEC.cell_volume(grid)
        tot = sum(abs2, psi) * dV
        psi ./= sqrt(tot)

        r = SpinorBEC._run_analyzer(:droplet_profile, psi, grid,
            AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0), Dict{String,Any}())
        @test r.N_atoms ≈ 1.0 atol=1e-10
        @test r.n_peak > 0
        fwhm_analytic = 2 * σ * sqrt(2 * log(2))
        for d in 1:3
            @test abs(r.fwhm[d] - fwhm_analytic) < 0.25  # coarse grid
            @test abs(r.sigma[d] - σ) < 0.15
        end
        @test r.surface_sharpness >= 0
    end

    @testset "topology analyzers (winding_field, monopole_charge, non_abelian_homotopy)" begin
        yaml_str_2d = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [16, 16], box: [8.0, 8.0]}
              interactions: {c0: 10.0, c1: -0.5}
              dt: 0.01
              n_steps: 40
              tol: 1e-4
              initial_state: ferromagnetic
              zeeman: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0, 1.0]}
          - analyze:
              - winding_field: {component: 1, threshold: 1.0e-6}
              - non_abelian_homotopy:
                  loop_pts: [[6, 8], [10, 8], [10, 10], [6, 10], [6, 8]]
                  component: 1
        """
        result_2d = run_config(load_config_from_string(yaml_str_2d); verbose=false)
        @test haskey(result_2d, :winding_field)
        @test haskey(result_2d.winding_field, :winding_field)
        @test haskey(result_2d.winding_field, :total_winding)
        @test result_2d.winding_field.winding_field isa AbstractMatrix{Int}
        @test haskey(result_2d, :non_abelian_homotopy)
        @test haskey(result_2d.non_abelian_homotopy, :holonomy)
        @test result_2d.non_abelian_homotopy.holonomy isa Complex
        # Uniform-phase ferromagnet: holonomy around any loop ≈ 1
        @test abs(result_2d.non_abelian_homotopy.holonomy) ≈ 1.0 atol=1e-8

        yaml_str_3d = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [10, 10, 10], box: [6.0, 6.0, 6.0]}
              interactions: {c0: 10.0, c1: -0.5}
              dt: 0.01
              n_steps: 30
              tol: 1e-4
              initial_state: ferromagnetic
              zeeman: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
          - analyze:
              - monopole_charge: {smooth: false}
        """
        result_3d = run_config(load_config_from_string(yaml_str_3d); verbose=false)
        @test haskey(result_3d, :monopole_charge)
        @test haskey(result_3d.monopole_charge, :total_charge)
        @test haskey(result_3d.monopole_charge, :monopole_charge_density)
        @test result_3d.monopole_charge.monopole_charge_density isa AbstractArray{Float64,3}
        # Uniform polarised GS has no topological charge
        @test abs(result_3d.monopole_charge.total_charge) < 1e-4
    end

    @testset "analyzer result persistence" begin
        mktempdir() do tmp
            cfg_path = joinpath(tmp, "config.yaml")
            write(cfg_path, """
            pipeline:
              - ground_state:
                  atom: Rb87
                  grid: {n: [16], box: [8.0]}
                  interactions: {c0: 10.0, c1: -0.5}
                  dt: 0.01
                  n_steps: 30
                  tol: 1e-4
                  initial_state: ferromagnetic
                  zeeman: {p: 0.0, q: 0.1}
                  potential: {type: harmonic, omega: [1.0]}
              - analyze:
                  - phase_classify: {}
            """)
            run_dir = SpinorBEC.run_yaml(cfg_path; base_dir = tmp, verbose = false)
            d = only(filter(p -> endswith(p, ".jld2"),
                            joinpath.(run_dir, readdir(run_dir))))
            loaded = JLD2.load(d)
            @test haskey(loaded, "analyze/phase_classify/spin_order")
            @test haskey(loaded, "analyze/phase_classify/phase")
            @test loaded["analyze/phase_classify/phase"] isa AbstractString
        end
    end

    @testset "cache hit feeds workspace to analyzers" begin
        mktempdir() do tmp
            cache_file = joinpath(tmp, "gs.jld2")
            yaml_str = """
            pipeline:
              - ground_state:
                  atom: Rb87
                  grid: {n: [16, 16], box: [8.0, 8.0]}
                  interactions: {c0: 10.0, c1: -0.5}
                  dt: 0.01
                  n_steps: 50
                  tol: 1e-4
                  initial_state: ferromagnetic
                  zeeman: {p: 0.0, q: 0.1}
                  potential: {type: harmonic, omega: [1.0, 1.0]}
                  cache: $cache_file
              - analyze:
                  - bogoliubov: {k_max: 5.0, n_k: 40, directions: auto}
            """
            cfg = load_config_from_string(yaml_str)
            r1 = run_config(cfg; verbose = false)
            @test isfile(cache_file)
            @test haskey(r1, :bogoliubov)

            # Second run: cache is hit; analyzer must still receive ws_prev
            cfg2 = load_config_from_string(yaml_str)
            r2 = run_config(cfg2; verbose = false)
            @test haskey(r2, :bogoliubov)
            @test r2.bogoliubov.max_growth ≈ r1.bogoliubov.max_growth atol=1e-8
        end
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
