using SpinorBEC: _elliptic_k
using FFTW

@testset "Diagnostics" begin
    @testset "Elliptic integral K(m)" begin
        @test _elliptic_k(0.0) ≈ π / 2 atol = 1e-14
        @test _elliptic_k(0.5) ≈ 1.8540746773013719 atol = 1e-10
        @test _elliptic_k(0.99) > 3.0
        @test _elliptic_k(0.999) > _elliptic_k(0.99)
        @test_throws DomainError _elliptic_k(1.0)
        @test_throws DomainError _elliptic_k(-0.1)
        @test_throws DomainError _elliptic_k(1.5)
    end

    @testset "Spin mixing period" begin
        @testset "q=0 gives T=π/|c̃₁|" begin
            for c1 in [-1.0, -0.5, 0.3]
                T = spin_mixing_period(c1, 0.0)
                @test T ≈ π / abs(c1) atol = 1e-12
            end
        end

        @testset "monotone increase with q" begin
            c1 = -1.0
            T_prev = spin_mixing_period(c1, 0.0)
            for q in [0.1, 0.3, 0.5, 0.8, 0.95]
                T = spin_mixing_period(c1, q)
                @test T > T_prev
                T_prev = T
            end
        end

        @test_throws ArgumentError spin_mixing_period(0.0, 0.1)
        @test_throws DomainError spin_mixing_period(1.0, 1.5)
    end

    @testset "Spin mixing period (SI)" begin
        c1_si = 1e-30
        q_si = 0.0
        T = spin_mixing_period_si(c1_si, q_si)
        @test T ≈ 2.0 * SpinorBEC.Units.HBAR / c1_si * (π / 2) atol = 1e-10 * T
        @test_throws ArgumentError spin_mixing_period_si(0.0, 1e-31)
    end

    @testset "Quadratic Zeeman (rigorous, g_J + q_geometry)" begin
        # Rb87: hyperfine known but q_geometry not provided in atom data,
        # so quadratic_zeeman_si throws.
        @test_throws ArgumentError quadratic_zeeman_si(Rb87, 1e-4)

        # Eu151: full data (g_J=1.9934, q_geometry=35/144, Δ_hf=121 MHz).
        # At B=1 G = 1e-4 T, expect q/h ≈ 15.6 kHz (per rigorous derivation).
        q_eu = quadratic_zeeman_si(Eu151, 1e-4)
        q_hz = q_eu / (2π * SpinorBEC.Units.HBAR)
        @test 15.0e3 < q_hz < 16.5e3   # 15.636 kHz/G² ± rounding

        # Dy164 (I=0, no hyperfine) → 0 by physics.
        @test quadratic_zeeman_si(Dy164, 1e-4) == 0.0

        # Dimensionless conversion roundtrips.
        ω = 2π * 50.0
        q_dl = quadratic_zeeman_dimless_si(Eu151, 1e-4, ω)
        @test q_dl ≈ q_eu / (SpinorBEC.Units.HBAR * ω)

        # AtomSpecies hyperfine data presence.
        @test Rb87.Delta_E_hf > 0
        @test Na23.Delta_E_hf > 0
        @test Eu151.Delta_E_hf > 0    # was 0 before 2026-04-30; now 121 MHz
        @test Eu151.q_geometry > 0
        @test Eu151.g_J > 0
    end

    @testset "Healing lengths" begin
        mass = 87 * SpinorBEC.Units.AMU
        n = 1e19  # density in m^-3

        @testset "contact" begin
            c0 = 1e-50
            xi = healing_length_contact(mass, c0, n)
            @test xi > 0
            @test xi ≈ SpinorBEC.Units.HBAR / sqrt(2 * mass * c0 * n)
            xi2 = healing_length_contact(mass, 4 * c0, n)
            @test xi2 ≈ xi / 2 atol = 1e-20
        end

        @testset "spin" begin
            c1 = -1e-52
            xi = healing_length_spin(mass, c1, n)
            @test xi > 0
            @test xi ≈ SpinorBEC.Units.HBAR / sqrt(2 * mass * abs(c1) * n)
            @test_throws ArgumentError healing_length_spin(mass, 0.0, n)
        end

        @testset "ddi" begin
            C_dd = 1e-51
            xi = healing_length_ddi(mass, C_dd, n)
            @test xi > 0
            @test_throws ArgumentError healing_length_ddi(mass, -1.0, n)
        end

        @testset "domain errors" begin
            @test_throws ArgumentError healing_length_contact(-1.0, 1e-50, 1e19)
            @test_throws ArgumentError healing_length_contact(mass, 1e-50, -1.0)
            @test_throws ArgumentError healing_length_contact(mass, -1e-50, 1e19)
        end
    end

    @testset "Thomas-Fermi radius" begin
        @testset "parabolic profile" begin
            R = 5.0
            x = collect(range(-10.0, 10.0, length=1001))
            density = [max(0.0, 1.0 - (xi / R)^2) for xi in x]
            r_tf = thomas_fermi_radius(density, x)
            @test r_tf ≈ R / sqrt(2) atol = 0.05
        end

        @testset "zero density" begin
            x = collect(range(-5.0, 5.0, length=101))
            density = zeros(101)
            @test thomas_fermi_radius(density, x) == 0.0
        end

        @testset "dimension mismatch" begin
            @test_throws DimensionMismatch thomas_fermi_radius([1.0, 2.0], [1.0])
        end
    end

    @testset "Thomas-Fermi radius (harmonic)" begin
        mu = 1.0
        omega = 1.0
        @test thomas_fermi_radius_harmonic(mu, omega) ≈ sqrt(2.0)
        @test thomas_fermi_radius_harmonic(2.0, 1.0) ≈ 2.0
        @test_throws ArgumentError thomas_fermi_radius_harmonic(-1.0, 1.0)
        @test_throws ArgumentError thomas_fermi_radius_harmonic(1.0, 0.0)
    end

    @testset "Phase diagram point" begin
        mass = 87 * SpinorBEC.Units.AMU
        n = 1e19
        c1 = -1e-52
        C_dd = 1e-51
        R_TF = 1e-5

        pt = phase_diagram_point(R_TF=R_TF, mass=mass, c1_density=c1, n=n, C_dd=C_dd)
        @test pt.R_TF_over_xi_sp > 0
        @test pt.R_TF_over_xi_dd > 0
        @test pt.xi_sp > 0
        @test pt.xi_dd > 0
        @test pt.R_TF == R_TF
        @test pt.R_TF_over_xi_sp ≈ R_TF / pt.xi_sp
        @test pt.R_TF_over_xi_dd ≈ R_TF / pt.xi_dd
    end

    @testset "Component populations" begin
        sys = SpinSystem(1)
        grid = make_grid(GridConfig(64, 20.0))
        n_pts = grid.config.n_points

        @testset "ferromagnetic (single component)" begin
            psi = zeros(ComplexF64, n_pts[1], 3)
            psi[:, 1] .= 1.0 / sqrt(n_pts[1])
            result = component_populations(psi, grid, sys)
            @test result.populations[1] ≈ 1.0 atol = 1e-10
            @test result.populations[2] ≈ 0.0 atol = 1e-10
            @test result.populations[3] ≈ 0.0 atol = 1e-10
            @test result.m_values == [1, 0, -1]
        end

        @testset "uniform across components" begin
            psi = ones(ComplexF64, n_pts[1], 3) / sqrt(3 * n_pts[1])
            result = component_populations(psi, grid, sys)
            @test all(p -> isapprox(p, 1.0 / 3; atol=1e-10), result.populations)
        end

        @testset "sum = 1" begin
            psi = randn(ComplexF64, n_pts[1], 3)
            result = component_populations(psi, grid, sys)
            @test sum(result.populations) ≈ 1.0 atol = 1e-12
        end

        @testset "2D grid" begin
            grid2 = make_grid(GridConfig((32, 32), (10.0, 10.0)))
            sys2 = SpinSystem(2)
            psi2 = randn(ComplexF64, 32, 32, 5)
            result = component_populations(psi2, grid2, sys2)
            @test length(result.populations) == 5
            @test sum(result.populations) ≈ 1.0 atol = 1e-12
            @test result.m_values == [2, 1, 0, -1, -2]
        end
    end

    @testset "Splitting error estimator" begin
        grid = make_grid(GridConfig(64, 10.0))
        interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5))
        trap = HarmonicTrap(1.0)

        sp1 = SimParams(; dt=0.01, n_steps=10, imaginary_time=false, save_every=10)
        ws1 = make_workspace(; grid, atom=Rb87, interactions, potential=trap,
            sim_params=sp1, fft_flags=FFTW.ESTIMATE)
        err1 = estimate_splitting_error(ws1)

        sp2 = SimParams(; dt=0.005, n_steps=10, imaginary_time=false, save_every=10)
        ws2 = make_workspace(; grid, atom=Rb87, interactions, potential=trap,
            sim_params=sp2, fft_flags=FFTW.ESTIMATE)
        err2 = estimate_splitting_error(ws2)

        @test err1 > 0
        @test err2 > 0
        @test err2 < err1
    end

    @testset "Conservation validation" begin
        grid = make_grid(GridConfig(64, 10.0))
        interactions = InteractionParams(Dict(0 => 10.0, 1 => -0.5))
        trap = HarmonicTrap(1.0)

        @testset "passes for reasonable dt" begin
            sp = SimParams(; dt=0.001, n_steps=100, imaginary_time=false, save_every=100)
            ws = make_workspace(; grid, atom=Rb87, interactions, potential=trap,
                sim_params=sp, fft_flags=FFTW.ESTIMATE)
            result = validate_conservation(ws; n_steps=50)
            @test result.passed
            @test result.norm_drift < 1e-12
        end

        @testset "restores state" begin
            sp = SimParams(; dt=0.001, n_steps=100, imaginary_time=false, save_every=100)
            ws = make_workspace(; grid, atom=Rb87, interactions, potential=trap,
                sim_params=sp, fft_flags=FFTW.ESTIMATE)
            psi_before = copy(ws.state.psi)
            validate_conservation(ws; n_steps=20)
            @test ws.state.psi ≈ psi_before
        end
    end

    @testset "Stability analysis" begin
        @testset "stable state has small growth rate" begin
            grid = make_grid(GridConfig(64, 10.0))
            interactions = InteractionParams(Dict(0 => 10.0, 1 => 0.0))
            trap = HarmonicTrap(1.0)
            sp = SimParams(; dt=0.001, n_steps=200, imaginary_time=false, save_every=200)
            ws = make_workspace(; grid, atom=Rb87, interactions, potential=trap,
                sim_params=sp, fft_flags=FFTW.ESTIMATE)
            result = analyze_stability(ws; n_steps=100, sample_every=10)
            @test isfinite(result.growth_rate)
            @test length(result.time_series) == 10
            @test length(result.sk_series) == 10
            @test isfinite(result.k_peak)
        end

        @testset "restores state after analysis" begin
            grid = make_grid(GridConfig(64, 10.0))
            interactions = InteractionParams(Dict(0 => 10.0, 1 => 0.0))
            trap = HarmonicTrap(1.0)
            sp = SimParams(; dt=0.001, n_steps=200, imaginary_time=false, save_every=200)
            ws = make_workspace(; grid, atom=Rb87, interactions, potential=trap,
                sim_params=sp, fft_flags=FFTW.ESTIMATE)
            psi_before = copy(ws.state.psi)
            t_before = ws.state.t
            analyze_stability(ws; n_steps=50, sample_every=10)
            @test ws.state.psi ≈ psi_before
            @test ws.state.t ≈ t_before
        end

        @testset "structure factor arrays have correct size" begin
            grid = make_grid(GridConfig(64, 10.0))
            interactions = InteractionParams(Dict(0 => 10.0, 1 => 0.0))
            sp = SimParams(; dt=0.001, n_steps=200, imaginary_time=false, save_every=200)
            ws = make_workspace(; grid, atom=Rb87, interactions,
                potential=HarmonicTrap(1.0),
                sim_params=sp, fft_flags=FFTW.ESTIMATE)
            result = analyze_stability(ws; n_steps=30, sample_every=10)
            for sk in result.sk_series
                @test size(sk) == grid.config.n_points
            end
        end

        @testset "growth-rate estimator = exact log-linear slope" begin
            # The saddle-rejection signal. Manufactured exponentials pin it
            # exactly: a sign flip or a per-sample-vs-per-time scale bug
            # shifts the fitted slope. (Pure function; no ITP.)
            dt = 0.05
            for γ in (0.37, -0.21, 0.0)
                ts = Float64[0.01 * exp(γ * (i - 1) * dt) for i in 1:20]
                @test isapprox(SpinorBEC._estimate_growth_rate(ts, dt), γ; atol=1e-9)
            end
            # same curve, doubled sample spacing ⇒ reported slope halves
            ts = Float64[0.01 * exp(0.37 * (i - 1) * dt) for i in 1:20]
            @test isapprox(SpinorBEC._estimate_growth_rate(ts, 2dt), 0.37 / 2; atol=1e-9)
        end
    end

    @testset "Phase classification" begin
        grid = make_grid(GridConfig(64, 10.0))
        sm = spin_matrices(1)
        sys = SpinSystem(1)

        @testset "ferromagnetic |F,+F⟩" begin
            psi = init_psi(grid, sys; state=:m_plus_F)
            r = classify_phase(psi, 1, grid, sm)
            @test r.phase == :ferromagnetic
            @test r.spin_order > 0.9
        end

        @testset "polar |m=0⟩ → :polar" begin
            psi = init_psi(grid, sys; state=:polar)
            r = classify_phase(psi, 1, grid, sm)
            @test r.phase == :polar
            @test r.nematic_order ≈ 1.0 rtol = 1e-10
            @test r.spin_order ≈ 0.0 atol = 1e-10
        end

        @testset "F=2 ferromagnetic" begin
            grid2 = make_grid(GridConfig(32, 10.0))
            sm2 = spin_matrices(2)
            sys2 = SpinSystem(2)
            psi2 = init_psi(grid2, sys2; state=:m_plus_F)
            r = classify_phase(psi2, 2, grid2, sm2)
            @test r.phase == :ferromagnetic
        end
    end

    @testset "Detailed phase classification" begin
        @testset "ferromagnetic F=1" begin
            grid = make_grid(GridConfig(64, 10.0))
            sm = spin_matrices(1)
            sys = SpinSystem(1)
            psi = init_psi(grid, sys; state=:m_plus_F)
            r = classify_phase_detailed(psi, 1, grid, sm)
            @test r.spin_order > 0.9
            @test r.biaxiality ≈ 0.0 atol = 0.1
            @test r.Q6 ≈ 0.0 atol = 1e-10
            @test isfinite(r.star_entropy)
            @test r.phase == :ferromagnetic
            @test haskey(r.channel_weights, 0) || haskey(r.channel_weights, 2)
            @test isfinite(r.magnetization_density)
        end

        @testset "polar F=1" begin
            grid = make_grid(GridConfig(64, 10.0))
            sm = spin_matrices(1)
            sys = SpinSystem(1)
            psi = init_psi(grid, sys; state=:polar)
            r = classify_phase_detailed(psi, 1, grid, sm)
            @test r.nematic_order ≈ 1.0 rtol = 1e-10
            @test r.spin_order ≈ 0.0 atol = 1e-10
            @test isfinite(r.biaxiality)
            @test isfinite(r.star_entropy)
            @test r.phase == :polar
        end

        @testset "all fields finite for F=2" begin
            grid = make_grid(GridConfig(32, 10.0))
            sm = spin_matrices(2)
            sys = SpinSystem(2)
            psi = init_psi(grid, sys; state=:m_plus_F)
            r = classify_phase_detailed(psi, 2, grid, sm)
            @test isfinite(r.spin_order)
            @test isfinite(r.nematic_order)
            @test isfinite(r.biaxiality)
            @test isfinite(r.Q6)
            @test isfinite(r.star_entropy)
            @test isfinite(r.magnetization_density)
        end

        @testset "vacuum returns zeros" begin
            grid = make_grid(GridConfig(32, 10.0))
            sm = spin_matrices(1)
            psi = zeros(ComplexF64, 32, 3)
            r = classify_phase_detailed(psi, 1, grid, sm)
            @test r.phase == :vacuum
            @test r.spin_order == 0.0
            @test r.biaxiality == 0.0
            @test r.Q6 == 0.0
        end
    end
end
