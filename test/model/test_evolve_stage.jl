# The `:evolve` Stage: does it exist, is its key partition total, and do the
# real-time switches finally reach an artifact id?
#
# `STAGE_KINDS` has held `:evolve` since the model layer landed with nothing
# producing one, and `test_ambient_refs_vs_artifact_id.jl` pinned three ambient
# globals as `:blind` for exactly that reason. They change real-time physics —
# 2.4e-4 in ψ over 200 steps for the meanfield midpoint — while leaving the id
# alone, so two different computations share one address.
#
# This file holds the three properties that make the producer worth having:
#
#   1. the DYNAMICS_SCHEMA partition is TOTAL, so a new dynamics key is red here
#      until someone decides whether it changes the model;
#   2. a model-level key is REFUSED (no id) rather than silently dropped;
#   3. flipping a real-time switch MOVES the id — which is the whole point, and
#      is asserted against a base id that must be restored afterwards.

using Test
using SpinorBEC
using SpinorBEC: DYNAMICS_SCHEMA, DYN_KEYS_MODEL_LEVEL, DYN_KEYS_STAGE,
    DYN_KEYS_OFF_PATH, evolve_stage, dyn_artifact_id, Stage, stage, Model,
    GridSpec, InteractionSpec, DDISpec, ATOM_REGISTRY,
    MEANFIELD_MIDPOINT_ENABLED, COMBINED_SPIN_STEP_ENABLED,
    SPIN_CHAIN_FUSION_ENABLED, SPIN_TAYLOR_ENABLED, DEALIAS_2_3_ENABLED

_gs() = stage(:relax;
    model=Model(; grid=GridSpec(; ndim=3, n_points=(8, 8, 8), box=(6.0, 6.0, 6.0)),
        atom=ATOM_REGISTRY[:Eu151],
        interactions=InteractionSpec(; n_atoms=1000, omega_ref=691.15,
            c0=10.0, c1=-0.1),
        ddi=DDISpec(; c_dd=1.0)),
    method=:itp, dt=0.002, n_steps=20)

_dyn(extra::Pair...) = Dict{String, Any}("duration" => 1.0, "dt" => 0.001, extra...)

@testset ":evolve Stage" begin
    @testset "the partition over DYNAMICS_SCHEMA is total" begin
        # Same discipline as `test_gs_admission_axes.jl` on the other path:
        # written out, not computed, because the classification IS the decision
        # — and adding a schema key without making it must be red.
        buckets = ("model-level" => Set(DYN_KEYS_MODEL_LEVEL),
            "stage" => Set(DYN_KEYS_STAGE),
            "off-path" => Set(DYN_KEYS_OFF_PATH))
        all_keys = Set(keys(DYNAMICS_SCHEMA))

        unclassified = setdiff(all_keys, union((s for (_, s) in buckets)...))
        stale = setdiff(union((s for (_, s) in buckets)...), all_keys)
        isempty(unclassified) || println("  DYNAMICS_SCHEMA keys with no bucket: ",
            sort!(collect(unclassified)))
        isempty(stale) || println("  classified keys not in DYNAMICS_SCHEMA: ",
            sort!(collect(stale)))
        @test isempty(unclassified)
        @test isempty(stale)

        # …and no key in two buckets, or "total" is satisfied by listing
        # everything everywhere.
        for (n1, s1) in buckets, (n2, s2) in buckets
            n1 < n2 || continue
            @test isempty(intersect(s1, s2))
        end
        @test sum(length(s) for (_, s) in buckets) == length(all_keys)
    end

    @testset "a plain dynamics block gets a Stage, and it chains" begin
        gs = _gs()
        s = evolve_stage(gs, _dyn())
        @test s isa Stage
        @test s.kind === :evolve
        @test s.from === gs                 # the chain, so the id recurses
        @test s.model === gs.model          # inherited, which is why the refusal exists
        id = dyn_artifact_id(gs, _dyn())
        @test id isa String
        @test length(id) == 16
        @test occursin(r"^[0-9a-f]{16}$", id)
        # Different from the ground state's own id: a stage that returned its
        # parent's address would be worse than none.
        @test id != SpinorBEC.artifact_id(gs)
    end

    @testset "a model-level key is REFUSED, not dropped" begin
        gs = _gs()
        # Every one of them, so the refusal cannot be true of `B` alone.
        for k in DYN_KEYS_MODEL_LEVEL
            @test evolve_stage(gs, _dyn(k => Dict{String, Any}())) === nothing
            @test dyn_artifact_id(gs, _dyn(k => Dict{String, Any}())) === nothing
        end
        # CALIBRATION: the same call WITHOUT the key does produce one, so the
        # `nothing`s above are about the key and not about the helper.
        @test evolve_stage(gs, _dyn()) !== nothing
        # No `from` ⇒ no id, the other half of the fail-safe.
        @test dyn_artifact_id(nothing, _dyn()) === nothing
    end

    @testset "the stage knobs move the id" begin
        gs = _gs()
        base = dyn_artifact_id(gs, _dyn())
        for (k, v) in ("dt" => 0.002, "duration" => 2.0, "integrator" => "yoshida",
            "seed_amplitude" => 0.1, "noise_seed" => 7,
            "temperature_ratio" => 0.2, "spin_step" => "combined")
            @test dyn_artifact_id(gs, _dyn(k => v)) != base
        end
        # `save` names what is written, not what is computed — it must NOT move
        # the id, or every snapshot cadence becomes a different computation.
        @test dyn_artifact_id(gs, _dyn("save" => Dict{String, Any}("every" => 5))) == base
    end

    @testset "the real-time switches move the id — the point of this file" begin
        # These were `:blind` in `test_ambient_refs_vs_artifact_id.jl` with the
        # reason "no `:evolve` Stage exists — run_step_dynamics.jl declares
        # none". It does now.
        gs = _gs()
        base = dyn_artifact_id(gs, _dyn())
        @test base isa String

        for (name, ref) in (("meanfield_midpoint", MEANFIELD_MIDPOINT_ENABLED),
            ("combined_spin_step", COMBINED_SPIN_STEP_ENABLED),
            ("spin_chain_fusion", SPIN_CHAIN_FUSION_ENABLED),
            ("spin_taylor", SPIN_TAYLOR_ENABLED),
            ("dealias_two_thirds", DEALIAS_2_3_ENABLED))
            @testset "$name" begin
                was = ref[]
                try
                    ref[] = !was
                    @test ref[] != was          # the flip flipped
                    @test dyn_artifact_id(gs, _dyn()) != base
                finally
                    ref[] = was
                end
                @test ref[] == was              # …and is back
                @test dyn_artifact_id(gs, _dyn()) == base
            end
        end
    end
end
