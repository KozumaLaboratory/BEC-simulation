# The `kind: scalar_egpe` YAML surface.
#
# A solver reachable only from Julia is a solver production cannot run — that
# was the state of `src/solvers/scalar_egpe.jl` for two months ("Not yet
# integrated with Workspace / YAML / dashboard"), and it is why the Klaus type-C
# gap could not be closed. This file gates the wiring: the parse, the step
# types, the refusals, and one end-to-end run.

using Test
using SpinorBEC

const _GS_YAML = """
pipeline:
  - ground_state:
      kind: scalar_egpe
      atom: Dy162
      a_s: 110
      grid: {n: [24, 24, 12], box: [10.0, 10.0, 5.0]}
      interactions: {N_atoms: 2000, omega_ref: 314.1592653589793}
      ddi: {enabled: true}
      lhy: {kind: scalar}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.6]}
      B_direction: {theta: 0.6108652}
      B_magnitude_gauss: 5.333
      dt: 0.005
      n_steps: 200
  - dynamics:
      kind: scalar_egpe
      duration: 0.5
      dt: 0.005
      B_direction: {theta: 0.6108652, omega: 0.75}
      wigner_seed: {kT: 4.0, seed: 3}
      save: {every: 5, column_density: true}
"""

@testset "scalar_egpe YAML surface" begin
    @testset "parses to its own step types" begin
        cfg = load_config_from_string(_GS_YAML)
        @test cfg.steps[1] isa SpinorBEC.ScalarEGPEGroundStateStep
        @test cfg.steps[2] isa SpinorBEC.ScalarEGPEDynamicsStep
        # Calibration: the same YAML without `kind` must NOT produce these —
        # otherwise the assertion above is about the parser existing, not about
        # `kind` selecting anything.
        plain = replace(_GS_YAML, "      kind: scalar_egpe\n" => "")
        cfg2 = load_config_from_string(plain; strict=false)
        @test !(cfg2.steps[1] isa SpinorBEC.ScalarEGPEGroundStateStep)
    end

    @testset "inspect names the path" begin
        cfg = load_config_from_string(_GS_YAML)
        @test SpinorBEC._step_path(cfg.steps[1]) == :scalar_egpe
        @test SpinorBEC._step_path(cfg.steps[2]) == :scalar_egpe
        @test occursin("scalar_egpe", SpinorBEC._step_name(cfg.steps[1]))
        @test SpinorBEC._is_dynamics(cfg.steps[2])
        @test !SpinorBEC._is_dynamics(cfg.steps[1])
    end

    @testset "strict schema still applies to this path" begin
        bad = replace(
            _GS_YAML,
            "      dt: 0.005\n      n_steps: 200" => "      dt: 0.005\n      n_stepss: 200",
        )
        @test_throws ArgumentError load_config_from_string(bad)
    end

    @testset "refusals that would otherwise be silent" begin
        cfg = load_config_from_string(_GS_YAML)
        # A spinor LHY closed form on a path that has eliminated the spinor.
        p = copy(cfg.steps[1].params)
        p["lhy"] = Dict{String, Any}("kind" => "full_bdg")
        @test_throws ArgumentError SpinorBEC._scalar_egpe_couplings(p)
        # `theta_final` with no ramp window: the tilt would never happen and the
        # run would quietly be a different protocol.
        @test_throws ArgumentError SpinorBEC.StirProtocol(
            Dict("theta" => 0.6, "theta_final" => 0.0))
        # 2D is not supported, and must say so rather than index off the end.
        p2 = copy(cfg.steps[1].params)
        p2["grid"] = Dict{String, Any}("n" => [16, 16], "box" => [8.0, 8.0])
        @test_throws ArgumentError SpinorBEC._scalar_egpe_grid_and_trap(p2)
    end

    @testset "the stir protocol integrates φ exactly" begin
        s = SpinorBEC.StirProtocol(Dict("theta" => 0.5, "omega" => 1.0,
            "ramp_rate" => 0.01))
        # Before the ramp completes: φ = ½·rate·t².
        @test SpinorBEC.stir_phi(s, 10.0) ≈ 0.5 * 0.01 * 100
        @test SpinorBEC.stir_omega(s, 10.0) ≈ 0.1
        # After: Ω saturates and φ continues linearly.
        t_r = 1.0 / 0.01
        @test SpinorBEC.stir_omega(s, 2 * t_r) ≈ 1.0
        @test SpinorBEC.stir_phi(s, 2 * t_r) ≈ 0.5 * t_r + 1.0 * t_r
        # θ is constant unless a ramp window was declared.
        @test SpinorBEC.stir_theta(s, 1e6) == 0.5
        sp = SpinorBEC.StirProtocol(
            Dict("theta" => 0.6, "omega" => 0.75,
                "theta_final" => 0.0, "theta_ramp_start" => 10.0,
                "theta_ramp_time" => 5.0),
        )
        @test SpinorBEC.stir_theta(sp, 9.0) == 0.6
        @test SpinorBEC.stir_theta(sp, 12.5) ≈ 0.3
        @test SpinorBEC.stir_theta(sp, 100.0) == 0.0
        @test SpinorBEC.stir_axis(sp, 100.0)[3] ≈ 1.0     # B̂ ∥ ẑ at the end
    end

    @testset "end to end" begin
        cfg = load_config_from_string(_GS_YAML)
        res = run_config(cfg; verbose=false)
        @test haskey(res, :scalar_gs)
        @test isfinite(res[:scalar_gs].mu)
        d = res[:scalar_egpe_dynamics]
        @test length(d.times) > 1
        @test length(d.column_density) == length(d.times)
        @test size(d.column_density[1]) == (24, 24)
        # Norm is conserved by the real-time Strang split to machine precision;
        # anything else means a substep is not unitary.
        @test abs(d.norms[end] - d.norms[1]) / d.norms[1] < 1e-9
        # The seed went in and is reported.
        @test d.wigner_seed !== nothing
        @test 0 < d.wigner_seed[2] < 1
        # The model-selection report rode along with the ground state.
        @test recommend_spin_treatment(res[:spin_treatment]) == :scalar_adiabatic
    end
end
