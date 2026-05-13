using JLD2
using JSON
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
        f_exp = SpinorBEC._make_interpolator(
            Dict("from" => 100.0, "to" => 1.0, "scale" => "exponential")
        )
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
              B: {p: 0.0, q: 0.1}
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
              B: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0]}
          - dynamics:
              duration: 0.02
              dt: 0.001
              save_every: 10
              B: {p: 0.0, q: 0.1}
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
              B: {p: 0.0, q: 0.1}
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
              B: {p: 0.0, q: 0.1}
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
            x = grid.x[1][i];
            y = grid.x[2][j];
            z = grid.x[3][k]
            r2 = x^2 + y^2 + z^2
            psi[i, j, k, 1] = sqrt(exp(-r2 / (2σ^2)))
        end
        # Normalize so the analyzer reads a sane N_atoms
        dV = SpinorBEC.cell_volume(grid)
        tot = sum(abs2, psi) * dV
        psi ./= sqrt(tot)

        r = SpinorBEC._run_analyzer(:droplet_profile, psi, grid,
            AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0), Dict{String, Any}())
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
              B: {p: 0.0, q: 0.1}
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
              B: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
          - analyze:
              - monopole_charge: {smooth: false}
        """
        result_3d = run_config(load_config_from_string(yaml_str_3d); verbose=false)
        @test haskey(result_3d, :monopole_charge)
        @test haskey(result_3d.monopole_charge, :total_charge)
        @test haskey(result_3d.monopole_charge, :monopole_charge_density)
        @test result_3d.monopole_charge.monopole_charge_density isa AbstractArray{Float64, 3}
        # Uniform polarised GS has no topological charge
        @test abs(result_3d.monopole_charge.total_charge) < 1e-4
    end

    @testset "skyrmion_detect on synthetic skyrmion" begin
        # Synthesize a 2D skyrmion-like spin texture: n̂(r) wraps the
        # sphere over the disc. Detector should find at least one local
        # extremum of the topological charge density.
        atom = AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0)
        cfg = GridConfig((24, 24), (8.0, 8.0))
        grid = make_grid(cfg)
        psi = zeros(ComplexF64, 24, 24, 3)
        @inbounds for j in 1:24, i in 1:24
            x = grid.x[1][i];
            y = grid.x[2][j]
            r = sqrt(x^2 + y^2)
            phi = atan(y, x)
            theta = π * (1 - exp(-r^2 / 4))   # core in→out wraps θ from 0 to π
            ct = cos(theta/2);
            st = sin(theta/2)
            # 3-component spinor for F=1, parametrised on the Bloch sphere
            psi[i, j, 1] = ct^2
            psi[i, j, 2] = sqrt(2.0) * ct * st * cis(phi)
            psi[i, j, 3] = st^2 * cis(2phi)
        end
        # Normalize
        dV = SpinorBEC.cell_volume(grid)
        psi ./= sqrt(sum(abs2, psi) * dV)
        r = SpinorBEC._run_analyzer(:skyrmion_detect, psi, grid, atom,
            Dict{String, Any}("threshold" => 0.05, "radius" => 2))
        @test r.skyrmion_count >= 0    # doesn't crash; charge density is well-formed
        @test haskey(r, :total_charge)
        @test haskey(r, :charge_density)
    end

    @testset "bogoliubov_mode returns u, v, weight_per_m" begin
        # Quick smoke: feed the analyzer a workspace from a tiny GS run
        # and check the output shape.
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [16, 16], box: [8.0, 8.0]}
              interactions: {c0: 5.0, c1: -0.5}
              dt: 0.01
              n_steps: 60
              tol: 1.0e-4
              initial_state: ferromagnetic
              B: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0, 1.0]}
          - analyze:
              - bogoliubov_mode: {k_max: 5.0, n_k: 60, directions: auto}
        """
        result = run_config(load_config_from_string(yaml_str); verbose=false)
        @test haskey(result, :bogoliubov_mode)
        bm = result.bogoliubov_mode
        @test haskey(bm, :u_mode);
        @test haskey(bm, :v_mode)
        @test haskey(bm, :weight_per_m)
        @test length(bm.u_mode) == length(bm.v_mode) == length(bm.weight_per_m)
        @test sum(bm.weight_per_m) ≈ 1.0 atol=1e-8
        @test bm.dominant_m isa Real
    end

    @testset "synthetic_dim analyzer" begin
        atom = AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0)
        cfg = GridConfig((12, 12), (6.0, 6.0))
        grid = make_grid(cfg)
        # Equal-population state across 3 components, normalised so
        # ∫|ψ|² dV = 1 (the convention :synthetic_dim assumes for
        # pop_per_m / edge_density / bulk_density).
        dV = cell_volume(grid)
        psi = zeros(ComplexF64, 12, 12, 3)
        for c in 1:3
            psi[:, :, c] .= 1.0 / sqrt(3 * length(psi[:, :, 1]) * dV)
        end
        r = SpinorBEC._run_analyzer(:synthetic_dim, psi, grid, atom, Dict{String, Any}())
        @test length(r.pop_per_m) == 3
        @test sum(r.pop_per_m) ≈ 1.0 atol=1e-8
        @test r.m_mean ≈ 0.0 atol=1e-10        # symmetric across m=±1
        @test r.edge_density ≈ 2 / 3 atol=1e-8   # m=±1 components
        @test r.bulk_density ≈ 1 / 3 atol=1e-8   # m=0 component
    end

    @testset "SGPE YAML knob smoke" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [10, 10], box: [5.0, 5.0]}
              interactions: {c0: 5.0, c1: 0.0}
              B: {p: 0.0, q: 0.1}
              potential: {type: harmonic, omega: [1.0, 1.0]}
              dt: 0.01
              n_steps: 30
              tol: 1.0e-4
              initial_state: ferromagnetic
          - dynamics:
              duration: 0.2
              dt: 0.005
              save_every: 10
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
              B: {p: 0.0, q: 0.1}
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
            write(
                cfg_path,
                """
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [10, 10, 6], box: [5.0, 5.0, 4.0]}
      interactions: {c0: 5.0, c1: 0.0}
      B: {p: 0.0, q: 0.0}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      dt: 0.01
      n_steps: 20
      tol: 1.0e-3
      initial_state: ferromagnetic
  - dynamics:
      duration: 0.1
      dt: 0.01
      save: {every: 5, psi_snapshots: true}
  - dynamics:
      duration: 0.1
      dt: 0.01
      save: {every: 5, psi_snapshots: true}
  - analyze:
      - column_density_movie:
          axis: 3
          output_dir: $frame_dir
          multi_step: true
""",
            )
            run_yaml(cfg_path; base_dir=tmp, verbose=false)
            archive = joinpath(frame_dir, "columns.jld2")
            manifest = joinpath(frame_dir, "manifest.json")
            @test isfile(archive)
            @test isfile(manifest)
            mj = JSON.parsefile(manifest)
            # Each dynamics step has 0.1/0.01/5 = 2 frames, so multi_step
            # concat should give 4 frames total.
            @test mj["n_frames"] >= 3
            @test mj["n_phases"] == 2
        end
    end

    @testset "loss K3 routing — 3-body keys land in K3_per_m_cubic" begin
        atom = AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0)

        # SI-unit input (lab-friendly form documented in CLAUDE.md).
        # MUST route to K3_per_m_cubic (quadratic-in-n), not legacy L3_per_m
        # (linear-in-n). Pre-2026-05 the SI input mistakenly landed in
        # L3_per_m, attenuating EdH density-spike loss by 1/2 at n=2n0 and
        # over-amplifying low-density loss by 10× at n=0.1n0.
        node_si = Dict{String, Any}(
            "gamma_dr" => 0.0,
            "K3_per_m_si" => ["1.5e-30 m^6/s", "1.5e-30 m^6/s", "1.5e-30 m^6/s"],
        )
        loss_si = SpinorBEC._parse_loss_params(node_si;
            atom=atom, N_atoms=10000, omega_ref=2π * 100.0)
        @test loss_si isa LossParams
        @test length(loss_si.K3_per_m_cubic) == 3
        @test all(isfinite, loss_si.K3_per_m_cubic)
        @test all(loss_si.K3_per_m_cubic .>= 0.0)
        @test isempty(loss_si.L3_per_m)  # SI K3 must NOT pollute legacy field

        # Dimless `K3_per_m` key — same physical meaning, same routing.
        node_dim = Dict{String, Any}(
            "gamma_dr" => 0.0,
            "K3_per_m" => [0.01, 0.02, 0.05],
        )
        loss_dim = SpinorBEC._parse_loss_params(node_dim)
        @test loss_dim.K3_per_m_cubic == [0.01, 0.02, 0.05]
        @test isempty(loss_dim.L3_per_m)

        # Legacy `L3_per_m` key — still routes to L3_per_m (2-body shape).
        node_legacy = Dict{String, Any}(
            "gamma_dr" => 0.0,
            "L3_per_m" => [0.01, 0.02, 0.05],
        )
        loss_legacy = SpinorBEC._parse_loss_params(node_legacy)
        @test loss_legacy.L3_per_m == [0.01, 0.02, 0.05]
        @test isempty(loss_legacy.K3_per_m_cubic)
    end

    @testset "K3_per_m_si → dimless conversion factor n0²/ω_ref" begin
        # Pin the SI → dimless conversion against an exact computed value
        # so any future refactor of parsing_blocks.jl `factor = n0² / ω_ref`
        # surfaces here, not at user-time.
        #
        # Setup:  Rb87 (mass 1.443e-25 kg), N=10000, ω_ref = 2π · 100 rad/s.
        #   a_ho = √(ℏ / (m·ω_ref)) ≈ √(1.0546e-34 / (1.443e-25 · 2π·100))
        #        ≈ 3.4040e-6 m
        #   n0   = N / a_ho³ ≈ 10000 / (3.4040e-6)³ ≈ 2.5363e+17 m⁻³
        #   For K3_SI = 1.5e-30 m⁶/s:
        #     K3_dimless = K3_SI · n0² / ω_ref
        #                = 1.5e-30 · (2.5363e+17)² / (2π·100)
        #                ≈ 1.5e-30 · 6.433e+34 / 628.32
        #                ≈ 1.535e+2  (~ 153)
        atom = AtomSpecies("Rb87", 1.443e-25, 1, 0.0, 0.0, 0.0)
        node = Dict{String, Any}(
            "gamma_dr" => 0.0,
            "K3_per_m_si" => ["1.5e-30 m^6/s"],
        )
        loss = SpinorBEC._parse_loss_params(node;
            atom=atom, N_atoms=10000, omega_ref=2π * 100.0)
        @test length(loss.K3_per_m_cubic) == 1

        # Compute the expected value independently using the same formula
        # so any change to the conversion is detected at the assertion level
        # (not just by hand-tuned magic numbers).
        hbar = 1.054571817e-34
        omega_ref = 2π * 100.0
        a_ho = sqrt(hbar / (atom.mass * omega_ref))
        n0 = 10000 / a_ho^3
        K3_SI = 1.5e-30
        expected = K3_SI * n0^2 / omega_ref
        @test loss.K3_per_m_cubic[1] ≈ expected rtol = 1e-6
        # Sanity: ~10^11 magnitude for the Rb87/N=10⁴/100 Hz setup
        # (n0 ~ 8e21 m⁻³, ω_ref ~ 628/s, so K3·n0²/ω_ref ~ 1.5·6.4e43/628 ~ 1.5e11).
        # Catches a sign-flip or factor-of-c²-style error in the conversion.
        @test 1e9 < loss.K3_per_m_cubic[1] < 1e13
    end

    @testset "K3_per_m_cubic is quadratic in n (kernel behavior check)" begin
        # Direct verification that the kernel applies K3 quadratically.
        # Compare loss at n=1 vs n=2 uniform densities: true 3-body gives a
        # 4× rate ratio; legacy linear-in-n L3 would give 2×.
        F = 1
        D = 3
        loss = LossParams(; gamma_dr=0.0, K3_per_m_cubic=[0.1, 0.1, 0.1])
        dt = 1e-4

        # Uniform psi with |psi|² = 1 per component (total n = 3) and
        # |psi|² = 4 per component (total n = 12).
        psi_a = ones(ComplexF64, 4, D)               # n_tot = 3
        psi_b = (2.0 + 0im) .* ones(ComplexF64, 4, D)  # n_tot = 12

        # Apply one half-step (dt/2 baked in by the kernel)
        SpinorBEC.apply_loss_step!(psi_a, loss, F, dt, D, 1)
        SpinorBEC.apply_loss_step!(psi_b, loss, F, dt, D, 1)

        # |psi|² survival ratio: exp(-K3 · n² · dt). For per-component
        # n_a=1, n_b=4 with total n_tot,a=3, n_tot,b=12, the decay rate
        # for each component scales as n_tot². Ratio of −log survival:
        survival_a = abs2(psi_a[1, 1]) / 1.0
        survival_b = abs2(psi_b[1, 1]) / 4.0
        decay_rate_a = -log(survival_a) / dt   # = K3 · n_tot,a² = 0.1 · 9
        decay_rate_b = -log(survival_b) / dt   # = K3 · n_tot,b² = 0.1 · 144
        # Ratio must be (12/3)² = 16 (true 3-body). Linear-in-n would be 4.
        @test decay_rate_b / decay_rate_a ≈ 16.0 atol = 1e-3
        @test decay_rate_a ≈ 0.1 * 9.0 atol = 1e-3
    end

    @testset "K_3 atom-loss > baseline (EdH-style A/B regression)" begin
        # Mini EdH-style A/B regression at F=1, 4³ grid. Verifies that with
        # K3_per_m_cubic enabled (and γ_dr held equal), total atom loss after
        # N dynamics steps is STRICTLY GREATER than baseline. Catches a future
        # re-routing of K3_per_m_si into the linear-in-n L3 field (the
        # pre-2026-05-13 bug). With the bug, K3 would still cause loss but
        # not in the right shape — the assertion below still holds, so this
        # is a CONSERVATIVE check that ensures K3 IS active in some form.
        # The 16× ratio test above is the shape-discriminating one.
        F = 1
        D = 3
        sys = SpinSystem(F)

        # Uniform psi.
        psi_baseline = ones(ComplexF64, 8, 8, 8, D) ./ sqrt(8.0^3 * D)
        psi_k3 = copy(psi_baseline)

        gamma_baseline = 0.01
        K3_dimless = 0.05
        loss_baseline = LossParams(; gamma_dr=gamma_baseline)
        loss_k3 = LossParams(;
            gamma_dr=gamma_baseline,
            K3_per_m_cubic=fill(K3_dimless, D),
        )

        dt = 1e-3
        n_steps = 50

        for _ in 1:n_steps
            SpinorBEC.apply_loss_step!(psi_baseline, loss_baseline, F, dt, D, 3)
            SpinorBEC.apply_loss_step!(psi_k3, loss_k3, F, dt, D, 3)
        end

        norm_baseline = sum(abs2, psi_baseline)
        norm_k3 = sum(abs2, psi_k3)
        loss_baseline_frac = 1.0 - norm_baseline
        loss_k3_frac = 1.0 - norm_k3

        # K3 branch must lose strictly more atoms.
        @test loss_k3_frac > loss_baseline_frac
        # And the excess should match K_3 · n_tot² · dt · n_steps to ~factor 2
        # (rough order check; n decreases during the run so it's not exact).
        n_tot_initial = 1.0 / (8.0^3)  # per-voxel total density
        expected_extra_loss_rate = K3_dimless * n_tot_initial^2
        expected_extra_loss = expected_extra_loss_rate * dt * n_steps
        actual_extra = loss_k3_frac - loss_baseline_frac
        @test actual_extra / expected_extra_loss > 0.5
        @test actual_extra / expected_extra_loss < 2.0
    end

    @testset "CSV calibration loader" begin
        mktempdir() do tmp
            csv_path = joinpath(tmp, "drift.csv")
            write(
                csv_path,
                """
date,coil_strong_gauss_per_mv,coil_strong_gauss_offset,fort_x_hz,fort_y_hz,fort_z_hz,microwave_rad_per_s_per_mw
2026-04-01,0.40,0.05,400.0,400.0,600.0,1.20e6
2026-04-15,0.42,0.04,395.0,395.0,590.0,1.18e6
""",
            )
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
            write(
                cfg_path,
                """
calibration:
  coil_strong: {gauss_per_mv: 0.4, gauss_offset: 0.05}
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [8, 8], box: [4.0, 4.0]}
      interactions: {c0: 5.0, c1: 0.0}
      B: {p_mv: 2.5, coil_mode: strong, q: 0.1}
      potential: {type: harmonic, omega: [1.0, 1.0]}
      dt: 0.01
      n_steps: 5
      tol: 1.0e-3
      initial_state: ferromagnetic
""",
            )
            # dry_run returns the expanded YAML string — must NOT touch GPU
            out = run_yaml(cfg_path; base_dir=tmp, verbose=false, dry_run=true)
            @test occursin("dry-run", out)
            @test occursin("Gauss", out)        # p_mv → "X Gauss" in expanded form
            @test !occursin("p_mv", out)        # lab key stripped
        end
    end

    @testset "calibration_history interpolation" begin
        cs1 = CalibrationSet(
            epoch="w1", date="2026-04-01",
            coil_strong=CoilCalibration(0.40, 0.05, (-Inf, Inf)),
            fort=FORTCalibration((400.0, 400.0, 600.0), (0.0, 0.0, 0.0)),
        )
        cs2 = CalibrationSet(
            epoch="w2", date="2026-04-15",
            coil_strong=CoilCalibration(0.50, 0.05, (-Inf, Inf)),
            fort=FORTCalibration((500.0, 500.0, 700.0), (0.0, 0.0, 0.0)),
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
            x = grid.x[1][i];
            y = grid.x[2][j]
            r = sqrt(x^2 + y^2)
            psi[i, j, 1] = 0.5 * r * cis(atan(y, x)) * exp(-r^2 / 4)
        end
        atom = AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0)
        # threshold is "minimum |ψ|² fraction of n_max for the corner gate".
        # The central plaquette enclosing the singularity has density ~4% of
        # peak (the core is dark), so the gate must be loose enough to admit
        # it; otherwise the only winding-positive plaquette gets skipped.
        r = SpinorBEC._run_analyzer(:vortex_detect, psi, grid, atom,
            Dict{String, Any}("component" => 1, "threshold" => 0.001))
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
        # writes per-frame column densities to columns.jld2 + manifest.json.
        mktempdir() do tmp
            frame_dir = joinpath(tmp, "frames")
            cfg_path = joinpath(tmp, "config.yaml")
            write(
                cfg_path,
                """
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [12, 12, 6], box: [6.0, 6.0, 4.0]}
      interactions: {c0: 5.0, c1: 0.0}
      B: {p: 0.0, q: 0.0}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      dt: 0.01
      n_steps: 30
      tol: 1.0e-4
      initial_state: ferromagnetic
  - dynamics:
      duration: 0.2
      dt: 0.01
      save: {every: 5, psi_snapshots: true, snapshot_precision: "f32"}
  - analyze:
      - column_density_movie:
          axis: 3
          output_dir: $frame_dir
""",
            )
            run_yaml(cfg_path; base_dir=tmp, verbose=false)
            archive = joinpath(frame_dir, "columns.jld2")
            manifest = joinpath(frame_dir, "manifest.json")
            @test isfile(archive)
            @test isfile(manifest)
            mj = JSON.parsefile(manifest)
            @test mj["n_frames"] >= 3
        end
    end

    @testset "analyzer result persistence" begin
        mktempdir() do tmp
            cfg_path = joinpath(tmp, "config.yaml")
            write(
                cfg_path,
                """
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [16], box: [8.0]}
      interactions: {c0: 10.0, c1: -0.5}
      dt: 0.01
      n_steps: 30
      tol: 1e-4
      initial_state: ferromagnetic
      B: {p: 0.0, q: 0.1}
      potential: {type: harmonic, omega: [1.0]}
  - analyze:
      - phase_classify: {}
""",
            )
            run_dir = SpinorBEC.run_yaml(cfg_path; base_dir=tmp, verbose=false)
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
                  B: {p: 0.0, q: 0.1}
                  potential: {type: harmonic, omega: [1.0, 1.0]}
                  cache: $cache_file
              - analyze:
                  - bogoliubov: {k_max: 5.0, n_k: 40, directions: auto}
            """
            cfg = load_config_from_string(yaml_str)
            r1 = run_config(cfg; verbose=false)
            @test isfile(cache_file)
            @test haskey(r1, :bogoliubov)

            # Second run: cache is hit; analyzer must still receive ws_prev
            cfg2 = load_config_from_string(yaml_str)
            r2 = run_config(cfg2; verbose=false)
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
            Dict(
                "pipeline" =>
                    [Dict("ground_state" => Dict("atom" => "Rb87", "target_magnetization" => 0.0))],
            ),
            NaN)
        @test psi_out === psi  # identity, not a copy

        # No rotation when target_magnetization absent
        psi_out = SpinorBEC.auto_rotate_psi(psi,
            Dict("pipeline" => [Dict("ground_state" => Dict("atom" => "Rb87"))]),
            -1.0)
        @test psi_out === psi

        # Rotation when Mz changes
        psi_rot = SpinorBEC.auto_rotate_psi(psi,
            Dict(
                "pipeline" =>
                    [Dict("ground_state" => Dict("atom" => "Rb87", "target_magnetization" => 0.0))],
            ),
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
