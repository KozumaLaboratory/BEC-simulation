using JLD2
using Dates: Date

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

    @testset "synthetic_dim analyzer" begin
        atom = AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0)
        cfg = GridConfig((12, 12), (6.0, 6.0))
        grid = make_grid(cfg)
        # Equal-population state across 3 components
        psi = zeros(ComplexF64, 12, 12, 3)
        for c in 1:3
            psi[:, :, c] .= 1.0 / sqrt(3 * length(psi[:, :, 1]))
        end
        r = SpinorBEC._run_analyzer(:synthetic_dim, psi, grid, atom, Dict{String,Any}())
        @test length(r.pop_per_m) == 3
        @test sum(r.pop_per_m) ≈ 1.0 atol=1e-8
        @test r.m_mean ≈ 0.0 atol=1e-10        # symmetric across m=±1
        @test r.edge_density ≈ 2/3 atol=1e-8   # m=±1 components
        @test r.bulk_density ≈ 1/3 atol=1e-8   # m=0 component
    end

    @testset "SGPE YAML knob smoke" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [10, 10], box: [5.0, 5.0]}
              interactions: {c0: 5.0, c1: 0.0}
              zeeman: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0, 1.0]}
              dt: 0.01
              n_steps: 30
              tol: 1.0e-4
              initial_state: ferromagnetic
          - dynamics:
              duration: 0.2
              dt: 0.005
              save_every: 100
              sgpe: {gamma: 0.05, T: 0.05, mu: 0.0, every: 1, seed: 11}
        """
        result = run_config(load_config_from_string(yaml_str); verbose=false)
        @test haskey(result, :dynamics_result)
        @test length(result.dynamics_result.energies) >= 2
        # SGPE noise injection means the norm grows from 1 — check it's finite
        @test isfinite(result.dynamics_result.norms[end])
    end

    @testset "Projected GP YAML knob smoke" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [12, 12], box: [6.0, 6.0]}
              interactions: {c0: 5.0, c1: 0.0}
              zeeman: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0, 1.0]}
              dt: 0.01
              n_steps: 30
              tol: 1.0e-4
              initial_state: ferromagnetic
          - dynamics:
              duration: 0.2
              dt: 0.005
              save_every: 100
              projected_gp: {k_cut: 4.0, every: 1}
        """
        # Should run without error; high-k modes get truncated each step
        result = run_config(load_config_from_string(yaml_str); verbose=false)
        @test haskey(result, :dynamics_result)
    end

    @testset "column_density_movie multi-step concat" begin
        mktempdir() do tmp
            frame_dir = joinpath(tmp, "frames")
            cfg_path = joinpath(tmp, "config.yaml")
            write(cfg_path, """
            pipeline:
              - ground_state:
                  atom: Rb87
                  grid: {n: [10, 10, 6], box: [5.0, 5.0, 4.0]}
                  interactions: {c0: 5.0, c1: 0.0}
                  zeeman: {p: 0.0, q: 0.0}
                  potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
                  dt: 0.01
                  n_steps: 20
                  tol: 1.0e-3
                  initial_state: ferromagnetic
              - dynamics:
                  duration: 0.1
                  dt: 0.01
                  save_every: 5
                  save_psi_snapshots: true
              - dynamics:
                  duration: 0.1
                  dt: 0.01
                  save_every: 5
                  save_psi_snapshots: true
              - analyze:
                  - column_density_movie:
                      axis: 3
                      output_dir: $frame_dir
                      multi_step: true
            """)
            run_yaml(cfg_path; base_dir = tmp, verbose = false)
            png_files = filter(p -> endswith(p, ".png"), readdir(frame_dir))
            # Each dynamics step has 0.1/0.01/5 = 2 frames, so multi_step
            # concat should give 4 frames total.
            @test length(png_files) >= 3
        end
    end

    @testset "loss SI-unit K3_per_m parsing" begin
        # Smoke: SI-unit K3 should parse, downstream applied as dimless rate
        atom = AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0)
        node = Dict{String,Any}(
            "gamma_dr" => 0.0,
            "K3_per_m_si" => ["1.5e-30 m^6/s", "1.5e-30 m^6/s", "1.5e-30 m^6/s"],
        )
        # N_atoms=10000, omega_ref=2π·100 → finite dimless K3
        loss = SpinorBEC._parse_loss_params(node;
            atom = atom, N_atoms = 10000, omega_ref = 2π * 100.0)
        @test loss isa LossParams
        @test length(loss.L3_per_m) == 3
        @test all(isfinite, loss.L3_per_m)
        @test all(loss.L3_per_m .>= 0.0)
    end

    @testset "CSV calibration loader" begin
        mktempdir() do tmp
            csv_path = joinpath(tmp, "drift.csv")
            write(csv_path, """
            date,coil_strong_gauss_per_mv,coil_strong_gauss_offset,fort_x_hz,fort_y_hz,fort_z_hz,microwave_rad_per_s_per_mw
            2026-04-01,0.40,0.05,400.0,400.0,600.0,1.20e6
            2026-04-15,0.42,0.04,395.0,395.0,590.0,1.18e6
            """)
            hist = load_calibration_csv(csv_path)
            @test hist isa CalibrationHistory
            @test length(hist.dates) == 2
            @test hist.entries[1].coil_strong.gauss_per_mv ≈ 0.40
            @test hist.entries[2].fort.sqrt_coeffs_hz[1] ≈ 395.0
            # Interpolate at midpoint
            mid = interpolate_calibration(hist, Date("2026-04-08"))
            @test 0.40 < mid.coil_strong.gauss_per_mv < 0.42
        end
    end

    @testset "run_yaml dry-run prints calibration-applied YAML" begin
        mktempdir() do tmp
            cfg_path = joinpath(tmp, "config.yaml")
            write(cfg_path, """
            calibration:
              coil_strong: {gauss_per_mv: 0.4, gauss_offset: 0.05}
            pipeline:
              - ground_state:
                  atom: Rb87
                  grid: {n: [8, 8], box: [4.0, 4.0]}
                  interactions: {c0: 5.0, c1: 0.0}
                  zeeman: {p_mv: 2.5, coil_mode: strong, q: 0.1}
                  potential: {type: harmonic, omega: [1.0, 1.0]}
                  dt: 0.01
                  n_steps: 5
                  tol: 1.0e-3
                  initial_state: ferromagnetic
            """)
            # dry_run should print expanded YAML and return "" — must NOT touch GPU
            buf = IOBuffer()
            redirect_stdout(buf) do
                run_yaml(cfg_path; base_dir = tmp, verbose = false, dry_run = true)
            end
            out = String(take!(buf))
            @test occursin("dry-run", out)
            @test occursin("Gauss", out)        # p_mv → "X Gauss" in expanded form
            @test !occursin("p_mv", out)        # lab key stripped
        end
    end

    @testset "calibration_history interpolation" begin
        cs1 = CalibrationSet(
            epoch = "w1", date = "2026-04-01",
            coil_strong = CoilCalibration(0.40, 0.05, (-Inf, Inf)),
            fort = FORTCalibration((400.0, 400.0, 600.0), (0.0, 0.0, 0.0)),
        )
        cs2 = CalibrationSet(
            epoch = "w2", date = "2026-04-15",
            coil_strong = CoilCalibration(0.50, 0.05, (-Inf, Inf)),
            fort = FORTCalibration((500.0, 500.0, 700.0), (0.0, 0.0, 0.0)),
        )
        hist = CalibrationHistory([Date("2026-04-01"), Date("2026-04-15")], [cs1, cs2])
        # Midpoint (April 8) → coil ≈ 0.45, fort_x ≈ 450
        mid = interpolate_calibration(hist, Date("2026-04-08"))
        @test 0.44 < mid.coil_strong.gauss_per_mv < 0.46
        @test 440 < mid.fort.sqrt_coeffs_hz[1] < 460
        # Outside window → clamps to nearest
        before = interpolate_calibration(hist, Date("2026-03-01"))
        @test before.coil_strong.gauss_per_mv ≈ 0.40
        after = interpolate_calibration(hist, Date("2026-05-01"))
        @test after.coil_strong.gauss_per_mv ≈ 0.50
    end

    @testset "vortex_detect returns positions" begin
        # 2D vortex synthesised at the centre of a (32,32) grid
        cfg = GridConfig((32, 32), (8.0, 8.0))
        grid = make_grid(cfg)
        psi = zeros(ComplexF64, 32, 32, 3)
        @inbounds for j in 1:32, i in 1:32
            x = grid.x[1][i]; y = grid.x[2][j]
            r = sqrt(x^2 + y^2)
            psi[i, j, 1] = 0.5 * r * cis(atan(y, x)) * exp(-r^2 / 4)
        end
        atom = AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0)
        r = SpinorBEC._run_analyzer(:vortex_detect, psi, grid, atom,
            Dict{String,Any}("component" => 1, "threshold" => 0.05))
        @test r.vortex_count >= 1
        @test haskey(r, :positions)
        @test r.positions isa AbstractVector
        @test !isempty(r.positions)
        # Each entry: (i, j, winding) for 2D
        @test length(r.positions[1]) == 3
        @test r.positions[1][3] == 1   # singly-charged
    end

    @testset "column_density_movie streamed snapshot path" begin
        # Mini dynamics smoke that exercises save_psi_snapshots: true →
        # streamed scratch JLD2 → column_density_movie reads it back and
        # produces PNG frames. Must not require save_psi_snapshots: false.
        mktempdir() do tmp
            frame_dir = joinpath(tmp, "frames")
            cfg_path = joinpath(tmp, "config.yaml")
            write(cfg_path, """
            pipeline:
              - ground_state:
                  atom: Rb87
                  grid: {n: [12, 12, 6], box: [6.0, 6.0, 4.0]}
                  interactions: {c0: 5.0, c1: 0.0}
                  zeeman: {p: 0.0, q: 0.0}
                  potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
                  dt: 0.01
                  n_steps: 30
                  tol: 1.0e-4
                  initial_state: ferromagnetic
              - dynamics:
                  duration: 0.2
                  dt: 0.01
                  save_every: 5
                  save_psi_snapshots: true
                  save_snapshot_precision: "f32"
              - analyze:
                  - column_density_movie:
                      axis: 3
                      output_dir: $frame_dir
                      colorscale: Viridis
            """)
            run_yaml(cfg_path; base_dir = tmp, verbose = false)
            png_files = filter(p -> endswith(p, ".png"), readdir(frame_dir))
            @test length(png_files) >= 3   # 0.2/dt(0.01)/save_every(5) = 4 frames
        end
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
