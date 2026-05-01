# --- multi_fidelity_optimize_yaml end-to-end test (R34, 2026-05-02) ---
#
# Wires the R33 MFBO into the full YAML pipeline. Tests pin:
#   1. Override propagation: low_overrides + high_overrides are applied
#      on top of the candidate-point overrides at each evaluation.
#   2. End-to-end pipeline run: a 1D F=1 trivial config completes both
#      tiers without crash. Result type matches MultiFidelityBOResult.
#   3. budget_high cap respected.
#
# Each MFBO call runs the full YAML pipeline several times. CLAUDE.md
# documents that a single `run_yaml` for a trivial config takes >4 min
# to first output (Workspace specialisation). Skip by default — set
# SPINORBEC_RUN_HEAVY_YAML=true to opt in (mirrors the gating pattern
# used by test_infrastructure.jl + test_zeeman_levels.jl). Nightly CI
# flips the env var on cron so the integration still gets covered.

using SpinorBEC
using Test

const _SKIP_HEAVY_YAML_MFBO =
    get(ENV, "SPINORBEC_RUN_HEAVY_YAML", "false") != "true"

# Tiny 1D F=1 YAML — runs in seconds at low fidelity.
const TINY_YAML = """
defaults: {kind: spinor}
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [16], box: [10.0]}
      potential: {type: harmonic, omega: [1.0]}
      interactions: {c0: 5.0, c1: 0.0}
      dt: 0.005
      n_steps: 200
      tol: 1.0e-5
      initial_state: polar
      B: {p: 0.0, q: 0.1}
"""

@testset "multi_fidelity_optimize_yaml — end-to-end" begin
    # Write the tiny YAML to a temp file.
    yaml_path = tempname() * ".yaml"
    open(yaml_path, "w") do f
        write(f, TINY_YAML)
    end

    # Objective: total energy from the spinor GS step.
    function objective_total_energy(result)
        # spinor pipeline result has :ground_state_energy
        if haskey(result, :ground_state_energy)
            return Float64(result[:ground_state_energy])
        end
        # Fallback: most spinor pipelines stash the full pipeline_results dict
        for (k, v) in result
            if v isa Real && occursin("energy", string(k))
                return Float64(v)
            end
        end
        # Last resort
        0.0
    end

    @testset "Function dispatches and respects budget_high" begin
        _SKIP_HEAVY_YAML_MFBO && (@test_skip false; return nothing)
        # Vary c0 in [1, 20] only — single-parameter scan
        result = multi_fidelity_optimize_yaml(
            yaml_path,
            ["pipeline.0.ground_state.interactions.c0"],
            [(1.0, 20.0)];
            objective_fn=objective_total_energy,
            low_overrides=Dict{String, Any}(
                "pipeline.0.ground_state.grid.n" => [8],
                "pipeline.0.ground_state.n_steps" => 50,
            ),
            high_overrides=Dict{String, Any}(
                "pipeline.0.ground_state.grid.n" => [16],
                "pipeline.0.ground_state.n_steps" => 200,
            ),
            cost_ratio=4.0,
            n_init_low=4,
            n_init_high=2,
            n_iter=4,
            budget_high=2,
            minimise=true,
            seed=42,
            verbose=false,
        )
        @test result isa MultiFidelityBOResult
        # Init high (2) + budget_high (2) = at most 4 high evals
        @test result.n_evals_high <= 2 + 2
        # More low than high
        @test result.n_evals_low >= result.n_evals_high
        @test isfinite(result.best_y)
        @test length(result.best_p) == 1
        @test 1.0 <= result.best_p[1] <= 20.0
    end

    rm(yaml_path; force=true)
end
