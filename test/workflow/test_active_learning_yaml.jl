# --- active_learn_phase_scan_yaml regression (R38, 2026-05-02) ---
#
# YAML wrapper for R36 AL. Tests pin:
#   1. `default_phase_classifier_extractor` correctly pulls `ranking`
#      from typical pipeline result shapes.
#   2. End-to-end pipeline run on a minimal F=1 YAML with
#      `phase_classify_distance` analyzer (heavy, gated).
#
# Heavy test gate matches `test_multi_fidelity_yaml.jl`: each AL call
# runs the full YAML pipeline several times, and CLAUDE.md documents
# that a single `run_yaml` for a trivial config takes >4 min to first
# output (Workspace specialisation). Skip by default; nightly CI sets
# SPINORBEC_RUN_HEAVY_YAML=true.

using SpinorBEC
using Test

const _SKIP_HEAVY_YAML_AL =
    get(ENV, "SPINORBEC_RUN_HEAVY_YAML", "false") != "true"

@testset "default_phase_classifier_extractor" begin
    @testset "Reads :phase_classify_distance.ranking (NamedTuple shape)" begin
        # Pipeline result with the typical analyzer output
        scores = [(name=:a, distance=0.1), (name=:b, distance=0.5)]
        result = Dict{Symbol, Any}(
            :phase_classify_distance => (
                phase=:a, distance=0.1, ranking=scores,
                spin_order=0.5, nematic_order=0.0,
            ),
        )
        out = default_phase_classifier_extractor(result)
        @test out === scores
    end

    @testset "Reads :phase_classify_distance ranking (Dict shape)" begin
        scores = [(name=:a, distance=0.1)]
        result = Dict{Symbol, Any}(
            :phase_classify_distance => Dict(:ranking => scores)
        )
        @test default_phase_classifier_extractor(result) === scores
    end

    @testset "Falls back to :phase_classify when :phase_classify_distance missing" begin
        scores = [(name=:a, distance=0.1), (name=:b, distance=0.2)]
        result = Dict{Symbol, Any}(
            :phase_classify => (ranking=scores,)
        )
        @test default_phase_classifier_extractor(result) === scores
    end

    @testset "Throws when neither field present" begin
        result = Dict{Symbol, Any}(:something_else => 1)
        @test_throws ArgumentError default_phase_classifier_extractor(result)
    end
end

@testset "active_learn_phase_scan_yaml — heavy YAML end-to-end" begin
    _SKIP_HEAVY_YAML_AL && (@test_skip false; return nothing)

    # Tiny 1D F=1 YAML with phase_classify_distance analyzer at the end.
    yaml_str = """
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
      - analyze:
          - phase_classify_distance: {threshold: 0.5}
    """
    yaml_path = tempname() * ".yaml"
    open(yaml_path, "w") do f
        write(f, yaml_str)
    end

    result = active_learn_phase_scan_yaml(
        yaml_path,
        ["pipeline.0.ground_state.interactions[1]"],
        [(-1.0, 1.0)];
        n_init=3, n_iter=4,
        temperature=0.1,
        seed=42, verbose=false,
    )

    @test hasproperty(result, :best_p)
    @test hasproperty(result, :best_y)
    @test length(result.best_p) == 1
    @test result.best_y >= 0    # entropy is non-negative

    rm(yaml_path; force=true)
end
