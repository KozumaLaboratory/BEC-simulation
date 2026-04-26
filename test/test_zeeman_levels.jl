# YAML run_config blocks below trip the same JIT inference cascade
# documented in CLAUDE.md ("Type stability boundaries") on Julia 1.11+.
# Skip them by default — set SPINORBEC_RUN_HEAVY_YAML=true to opt in.
const _SKIP_HEAVY_YAML_ZEEMAN =
    get(ENV, "SPINORBEC_RUN_HEAVY_YAML", "false") != "true"

@testset "Phase 1.5: Zeeman level dispatch" begin
    @testset "Level detection" begin
        @test SpinorBEC._detect_zeeman_level(Dict{String, Any}()) == 0
        @test SpinorBEC._detect_zeeman_level(Dict{String, Any}("p" => 0.5)) == 0
        @test SpinorBEC._detect_zeeman_level(Dict{String, Any}("Bz" => 1.0)) == 1
        @test SpinorBEC._detect_zeeman_level(Dict{String, Any}("Bx" => 0.1, "By" => 0.2)) == 1
        @test SpinorBEC._detect_zeeman_level(
            Dict{String, Any}("B_mag" => 1.0, "theta_deg" => 30)
        ) == 2
        @test SpinorBEC._detect_zeeman_level(Dict{String, Any}("level" => 2, "B_mag" => 1.0)) == 2

        # Mixing levels rejected
        @test_throws ArgumentError SpinorBEC._detect_zeeman_level(
            Dict{String, Any}("p" => 1.0, "Bz" => 1.0))
        @test_throws ArgumentError SpinorBEC._detect_zeeman_level(
            Dict{String, Any}("Bz" => 1.0, "B_mag" => 1.0))
    end

    @testset "Gauss → dimensionless scalar" begin
        # Dy164 F=8, g_F ≈ 1.24 (approximate — exact value in atoms.jl)
        # 1 Gauss at ω_ref = 2π·50 Hz should give p ≈ 3.5e4
        p = SpinorBEC._gauss_to_dimless(1.0, 1.24, 2π * 50.0)
        @test p ≈ 34710.68 atol=1.0
        # Linearity: 0.5 G → half
        @test SpinorBEC._gauss_to_dimless(0.5, 1.24, 2π * 50.0) ≈ p / 2
        # Scaling with g_F
        p2 = SpinorBEC._gauss_to_dimless(1.0, 2.48, 2π * 50.0)
        @test p2 ≈ 2 * p
        # Scaling with 1/omega_ref
        p3 = SpinorBEC._gauss_to_dimless(1.0, 1.24, 2π * 100.0)
        @test p3 ≈ p / 2
    end

    @testset "Level 1: Bz scalar → TimeDependentZeeman" begin
        atom = Dy164
        omega_ref = 2π * 50.0
        z = Dict{String, Any}("Bz" => 1.0)
        p_step = Dict{String, Any}("interactions" => Dict("omega_ref" => omega_ref))
        tdz = SpinorBEC._build_zeeman_dispatched(z, 1.0, atom, p_step)
        @test tdz isa TimeDependentZeeman
        # Constant Bz → ConstantWaveform p
        @test tdz.p_wf isa ConstantWaveform
        expected_p = SpinorBEC._gauss_to_dimless(1.0, atom.g_F, omega_ref)
        @test evaluate(tdz.p_wf, 0.0) ≈ expected_p
        @test evaluate(tdz.p_wf, 0.5) ≈ expected_p
    end

    @testset "Level 1: Bx linear ramp" begin
        atom = Dy164
        omega_ref = 2π * 50.0
        z = Dict{String, Any}("Bx" => Dict("from" => 0.0, "to" => 0.574))
        p_step = Dict{String, Any}("interactions" => Dict("omega_ref" => omega_ref))
        tdz = SpinorBEC._build_zeeman_dispatched(z, 0.020, atom, p_step)
        @test tdz.bx_wf isa PiecewiseLinearWaveform
        # Endpoints
        p_at_0 = evaluate(tdz.bx_wf, 0.0)
        p_at_end = evaluate(tdz.bx_wf, 0.020)
        @test abs(p_at_0) < 1.0
        expected_end = SpinorBEC._gauss_to_dimless(0.574, atom.g_F, omega_ref)
        @test p_at_end ≈ expected_end rtol=1e-3
        # Midpoint ≈ half
        p_mid = evaluate(tdz.bx_wf, 0.010)
        @test p_mid ≈ expected_end / 2 rtol=1e-2
    end

    @testset "Level 2: theta ramp projects correctly" begin
        atom = Dy164
        omega_ref = 2π * 50.0
        # B_mag=1 G fixed, theta 0 → 90 deg: B rotates from z-axis to x-axis
        z = Dict{String, Any}(
            "B_mag" => 1.0,
            "theta_deg" => Dict("from" => 0.0, "to" => 90.0),
            "phi_deg" => 0.0,
        )
        p_step = Dict{String, Any}("interactions" => Dict("omega_ref" => omega_ref))
        tdz = SpinorBEC._build_zeeman_dispatched(z, 1.0, atom, p_step)
        unit_p = SpinorBEC._gauss_to_dimless(1.0, atom.g_F, omega_ref)

        # t=0: pure z
        @test evaluate(tdz.p_wf, 0.0) ≈ unit_p rtol=1e-2
        @test abs(evaluate(tdz.bx_wf, 0.0)) < unit_p * 1e-2
        # t=1: pure x
        @test abs(evaluate(tdz.p_wf, 1.0)) < unit_p * 1e-2
        @test evaluate(tdz.bx_wf, 1.0) ≈ unit_p rtol=1e-2
        # by always zero (phi=0)
        @test abs(evaluate(tdz.by_wf, 0.5)) < unit_p * 1e-6
    end

    @testset "Unitful string: Level 1 Bz" begin
        atom = Dy164
        omega_ref = 2π * 50.0
        # String with explicit Gauss — note: "G" alone is gravitational constant
        # in Unitful's namespace, use "Gauss" or SI prefix (mT, μT, T).
        z = Dict{String, Any}("Bz" => "0.819 Gauss")
        p_step = Dict{String, Any}("interactions" => Dict("omega_ref" => omega_ref))
        tdz = SpinorBEC._build_zeeman_dispatched(z, 1.0, atom, p_step)
        expected = SpinorBEC.Units.bfield_to_p(0.819, atom.g_F, omega_ref)
        @test evaluate(tdz.p_wf, 0.0) ≈ expected rtol=1e-10

        # μT prefix should give the same result: 0.819 Gauss = 81.9 μT
        z2 = Dict{String, Any}("Bz" => "81.9 μT")
        tdz2 = SpinorBEC._build_zeeman_dispatched(z2, 1.0, atom, p_step)
        @test evaluate(tdz2.p_wf, 0.0) ≈ expected rtol=1e-6

        # Bogus unit (not magnetic field) rejected
        z_bad = Dict{String, Any}("Bz" => "1.0 m")
        @test_throws ArgumentError SpinorBEC._build_zeeman_dispatched(z_bad, 1.0, atom, p_step)

        # Bogus string rejected by regex before reaching uparse
        z_evil = Dict{String, Any}("Bz" => "1.0 rm(\"/\")")
        @test_throws ArgumentError SpinorBEC._build_zeeman_dispatched(z_evil, 1.0, atom, p_step)
    end

    @testset "Unitful string: Level 2 B_mag" begin
        atom = Dy164
        omega_ref = 2π * 50.0
        z = Dict{String, Any}(
            "B_mag" => "0.819 Gauss",
            "theta_deg" => 90.0,
            "phi_deg" => 0.0,
        )
        p_step = Dict{String, Any}("interactions" => Dict("omega_ref" => omega_ref))
        tdz = SpinorBEC._build_zeeman_dispatched(z, 1.0, atom, p_step)
        expected = SpinorBEC.Units.bfield_to_p(0.819, atom.g_F, omega_ref)
        # At theta=90, B is pure x → bx = full p, p (z) ≈ 0
        @test evaluate(tdz.bx_wf, 0.5) ≈ expected rtol=1e-6
        @test abs(evaluate(tdz.p_wf, 0.5)) < expected * 1e-6
    end

    @testset "omega_ref resolution priority" begin
        atom = Dy164
        # Explicit in zeeman takes priority (50 Hz linear → 2π·50)
        z = Dict{String, Any}("Bz" => 1.0, "omega_ref_hz" => 50.0)
        p_step = Dict{String, Any}("interactions" => Dict("omega_ref" => 2π * 100.0))
        tdz = SpinorBEC._build_zeeman_dispatched(z, 1.0, atom, p_step)
        expected = SpinorBEC._gauss_to_dimless(1.0, atom.g_F, 2π * 50.0)
        @test evaluate(tdz.p_wf, 0.0) ≈ expected rtol=1e-6

        # Falls back to interactions.omega_ref
        z2 = Dict{String, Any}("Bz" => 1.0)
        tdz2 = SpinorBEC._build_zeeman_dispatched(z2, 1.0, atom, p_step)
        expected2 = SpinorBEC._gauss_to_dimless(1.0, atom.g_F, 2π * 100.0)
        @test evaluate(tdz2.p_wf, 0.0) ≈ expected2 rtol=1e-6

        # Missing omega_ref raises
        @test_throws ArgumentError SpinorBEC._resolve_omega_ref(
            Dict{String, Any}(), Dict{String, Any}())
    end

    @testset "YAML round-trip: Level 1 in ground_state" begin
        _SKIP_HEAVY_YAML_ZEEMAN && (@test_skip false; return nothing)
        # Tiny Bz to avoid ITP exp-V underflow at large dimensionless p.
        # Real experimental values (e.g. Klaus 2022 Bz=0.819G) give p≈3e4 which
        # requires matching small dt and physics-aware setup — not a plumbing test.
        cfg = SpinorBEC.load_config_from_string("""
pipeline:
  - ground_state:
      atom: Dy164
      grid: {n: 16, box: 8.0}
      interactions: {c0: 50.0, c1: -0.2, omega_ref: 314.159}
      zeeman: {Bz: 1.0e-4}
      dt: 0.01
      n_steps: 5
      tol: 1e-3
""")
        result = SpinorBEC.run_config(cfg)
        @test isfinite(result.ground_state_energy)
    end

    @testset "YAML round-trip: Level 2 dynamics (tilt ramp)" begin
        _SKIP_HEAVY_YAML_ZEEMAN && (@test_skip false; return nothing)
        cfg = SpinorBEC.load_config_from_string("""
pipeline:
  - ground_state:
      atom: Dy164
      grid: {n: 16, box: 8.0}
      interactions: {c0: 50.0, c1: -0.2, omega_ref: 314.159}
      zeeman: {Bz: 1.0e-4}
      dt: 0.01
      n_steps: 5
      tol: 1e-3
  - dynamics:
      duration: 0.01
      dt: 0.001
      interactions: {omega_ref: 314.159}
      zeeman:
        B_mag: 1.0e-4
        theta_deg: {from: 0.0, to: 35.0}
""")
        result = SpinorBEC.run_config(cfg)
        @test result.dynamics_result !== nothing
    end
end
