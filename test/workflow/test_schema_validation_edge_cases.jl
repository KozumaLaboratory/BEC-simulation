# Schema validation edge-case probes.
#
# Pin the "do NOT silently accept" guards that production runs depend
# on. Each test designed so that a regression flips the validation
# from throwing to silently passing — and the user gets garbage results
# instead of an early ArgumentError.

using Test
using SpinorBEC
using SpinorBEC: load_config_from_string

@testset "Schema validation edge cases" begin
    @testset "c1_ratio at-or-below -1/F² singularity throws" begin
        # interaction_params_from_constraint: c0 = c_total / (1 + F²·r)
        # → c0 → ∞ as r → -1/F² from above; c0 ≤ 0 below.
        # Schema validation must catch r ≤ -1/F² + ε before workspace build.

        # F=6: bound = -1/36 ≈ -0.0278
        for r in (-0.03, -0.05, -1.0)
            yaml = """
            pipeline:
              - ground_state:
                  atom: Eu151
                  grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
                  potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
                  interactions: {N_atoms: 100, omega_ref: 1.0, c1_ratio: $r}
                  ddi: {enabled: false}
                  lhy: {kind: none}
                  B: {Bz: 0.0, q: 0.0}
                  initial_state: m_plus_F
                  init_sigma: 1.0
                  dt: 0.01
                  n_steps: 10
                  tol: 1.0e-6
            """
            @test_throws ArgumentError load_config_from_string(yaml; strict=true)
        end

        # F=1: bound = -1/1 = -1.0
        yaml_F1 = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [8], box: [4.0]}
              potential: {type: harmonic, omega: [1.0]}
              interactions: {N_atoms: 100, omega_ref: 1.0, c1_ratio: -1.5}
              ddi: {enabled: false}
              lhy: {kind: none}
              B: {Bz: 0.0, q: 0.0}
              initial_state: m_plus_F
              init_sigma: 1.0
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
        """
        @test_throws ArgumentError load_config_from_string(yaml_F1; strict=true)

        # Valid r just above bound passes
        yaml_ok = """
        pipeline:
          - ground_state:
              atom: Eu151
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 100, omega_ref: 1.0, c1_ratio: -0.02}
              ddi: {enabled: false}
              lhy: {kind: none}
              B: {Bz: 0.0, q: 0.0}
              initial_state: m_plus_F
              init_sigma: 1.0
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
        """
        cfg = load_config_from_string(yaml_ok; strict=true)
        @test cfg !== nothing
    end

    @testset "Unknown top-level key with strict=true throws" begin
        yaml = """
        bogus_top_level_key: 42
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [8], box: [4.0]}
              potential: {type: harmonic, omega: [1.0]}
              interactions: {N_atoms: 100, omega_ref: 1.0, c1_ratio: 0.0}
              ddi: {enabled: false}
              lhy: {kind: none}
              B: {Bz: 0.0, q: 0.0}
              initial_state: m_plus_F
              init_sigma: 1.0
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
        """
        @test_throws ArgumentError load_config_from_string(yaml; strict=true)
    end

    @testset "Pipeline must have at least one step" begin
        # Empty pipeline / missing pipeline key
        yaml_empty = """
        pipeline: []
        """
        # Empty pipeline is technically allowed by schema but run_pipeline
        # handles it as a no-op. The key check is that missing 'pipeline'
        # is an error.
        # The filler key has to be one the schema still RECOGNISES, or this
        # stops testing what it says. It was `metadata:` until the step-6
        # cutover deleted that key; the throw then came from "unknown top-level
        # key" and the assertion went on passing while no longer exercising the
        # missing-`pipeline` path at all.
        yaml_missing = """
        name: "no pipeline"
        """
        # load_config requires `pipeline` key — see pipeline_api.jl line 21
        @test_throws ArgumentError load_config_from_string(yaml_missing; strict=true)
    end

    @testset "DDI on with non-dipolar atom (c_dd=0) issues no error" begin
        # Rb87 has μ ≈ 0 → c_dd = 0. Workspace can still allocate DDI
        # buffers but the convolution is a no-op. Should not error
        # at config-load time.
        yaml = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              interactions: {N_atoms: 100, omega_ref: 1.0, c1_ratio: 0.0}
              ddi: {enabled: true}
              lhy: {kind: none}
              B: {Bz: 0.0, q: 0.0}
              initial_state: m_plus_F
              init_sigma: 1.0
              dt: 0.01
              n_steps: 10
              tol: 1.0e-6
        """
        cfg = load_config_from_string(yaml; strict=true)
        @test cfg !== nothing
    end
end
