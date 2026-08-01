# Cutover step 1's whole promise: the NEW id is recorded, the OLD key still
# decides. That is what makes the step revertable on a live research tree, and
# it is testable directly rather than by reading the diff.
#
# Four arms, and the last is what stops the others from passing for the wrong
# reason:
#
#   1. RECORD — the artifact admission serves carries both ids.
#   2. HIT — a fixture placed at the path the OLD key names is served, so the
#      returned energy is one no solver produced.
#   3. NULL — moving the new id (`code_tree_hash`, and through it `artifact_id`)
#      moves neither `_gs_cache_key` nor the hit.
#   4. POSITIVE CONTROL — moving an input the OLD key reads (`tol`) DOES miss.
#      Without it, arm 3 is an `isfile` on a path that never changes and would
#      pass even if admission had been rewired to the new id.
#
# The key is taken from the step's own `:gs_stage_ref` rather than recomputed
# here. Restating `_gs_cache_key`'s 18 inputs in a test is a second declaration
# of the thing under test, and it drifts: the step mutates its params dict
# (`_resolve_derived_params!`) and derives its DDI tuple before hashing.

using Test
using JLD2
using SpinorBEC
using SpinorBEC: _gs_cache_key, _gs_stage_dir, _run_step, GroundStateStep,
    code_tree_hash, _code_rev_or_nothing, _package_root, _CODE_TREE_HASH_MEMO,
    make_grid, GridConfig, InteractionParams, resolve_atom

probe_gs_params(; tol=1.0e-6) = Dict{String, Any}(
    "atom" => "Rb87",
    "method" => "itp",
    "grid" => Dict{String, Any}("n" => [16], "box" => [8.0]),
    "interactions" => Dict{String, Any}("N_atoms" => 100, "omega_ref" => 100.0,
        "c0" => 1.0, "c1" => 0.0),
    "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0]),
    "initial_state" => "polar",
    "n_steps" => 20,
    "dt" => 1.0e-3,
    "tol" => tol,
)

probe_with_code_rev(f, value) = begin
    k = abspath(_package_root())
    saved = get(_CODE_TREE_HASH_MEMO, k, nothing)
    try
        _CODE_TREE_HASH_MEMO[k] = value
        f()
    finally
        saved === nothing ? delete!(_CODE_TREE_HASH_MEMO, k) :
        (_CODE_TREE_HASH_MEMO[k] = saved)
    end
end

const PROBE_SENTINEL_E = -12345.678

@testset "admission still uses the old key (cutover step 1)" begin
    @testset "the old key does not read the new id" begin
        # An arbitrary but FIXED argument set — the claim is about the key
        # function's inputs, not about this particular cell.
        args = (:itp, resolve_atom(:Rb87), make_grid(GridConfig((16,), (8.0,))),
            InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            (false, NaN, false, false, 0.0, NaN, false, 2.0),
            1.0e-6, 20, 1.0e-3, probe_gs_params())
        k0 = _gs_cache_key(args...)
        k1 = probe_with_code_rev("0"^64) do
            _gs_cache_key(args...)
        end
        # If the code revision had leaked into `_gs_cache_key`, every commit
        # would invalidate the GS store — step 3's decision, not step 1's, and
        # exactly what "admit on the old one" forbids.
        @test k1 == k0
        # Positive control on the key function itself: it is not a constant.
        @test _gs_cache_key(args[1:5]..., 1.0e-7, args[7:end]...) != k0
    end

    mktempdir() do dir
        probe_run_gs(pp) = withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => dir) do
            _run_step(GroundStateStep(pp), nothing, nothing, nothing, nothing; verbose=false)
        end

        local stage_ref, real_E
        @testset "RECORD: a solved artifact carries BOTH ids" begin
            (_, _, _, _, res) = probe_run_gs(probe_gs_params())
            stage_ref = res[:gs_stage_ref]
            real_E = res[:ground_state_energy]
            @test stage_ref isa AbstractString
            @test isfile(joinpath(dir, stage_ref * ".jld2"))
            d = JLD2.load(joinpath(dir, stage_ref * ".jld2"))
            @test d["gs_cache_key"] == stage_ref            # the id that admits
            @test d["code_rev"] == code_tree_hash()          # the new one, recorded only
            @test length(d["code_rev"]) == 64
            # ... beside the payload the loader reads, unchanged.
            @test haskey(d, "psi") && haskey(d, "energy") && haskey(d, "converged")
            @test d["energy"] == real_E
        end

        # Replace the payload with a value no solver produces. From here on, a
        # returned energy of PROBE_SENTINEL_E means "admission served this file".
        @testset "HIT: the file the old key names is what gets served" begin
            path = joinpath(dir, stage_ref * ".jld2")
            psi_fake = JLD2.load(path)["psi"]
            jldopen(path, "w") do f
                f["psi"] = psi_fake
                f["energy"] = PROBE_SENTINEL_E
                f["converged"] = true
                f["gs_cache_key"] = stage_ref
                f["code_rev"] = code_tree_hash()
            end
            (_, _, _, _, res) = probe_run_gs(probe_gs_params())
            @test res[:ground_state_energy] == PROBE_SENTINEL_E
            @test res[:gs_stage_ref] == stage_ref
            @test length(readdir(dir)) == 1
        end

        @testset "NULL: moving the new id does not change admission" begin
            (_, _, _, _, res) = probe_with_code_rev("0"^64) do
                probe_run_gs(probe_gs_params())
            end
            @test res[:ground_state_energy] == PROBE_SENTINEL_E
            @test res[:gs_stage_ref] == stage_ref
            @test length(readdir(dir)) == 1     # no second artifact was written
        end

        @testset "POSITIVE CONTROL: moving an input the old key reads DOES miss" begin
            (_, _, _, _, res) = probe_run_gs(probe_gs_params(; tol=1.0e-7))
            @test res[:gs_stage_ref] != stage_ref
            @test res[:ground_state_energy] != PROBE_SENTINEL_E
            @test isfile(joinpath(dir, res[:gs_stage_ref] * ".jld2"))
            @test length(readdir(dir)) == 2
            d = JLD2.load(joinpath(dir, res[:gs_stage_ref] * ".jld2"))
            @test d["gs_cache_key"] == res[:gs_stage_ref]
            @test d["code_rev"] == code_tree_hash()
        end

        @testset "the extra datasets do not disturb the loader" begin
            # The load branch reads three keys by name; nothing enumerates.
            d = JLD2.load(joinpath(dir, stage_ref * ".jld2"))
            @test get(d, "energy", NaN) == PROBE_SENTINEL_E
            @test get(d, "converged", true) === true
            @test d["psi"] isa AbstractArray
        end
    end

    @testset "a record writer cannot acquire a new way to fail" begin
        # `code_tree_hash` reads the disk, and TSUBAME re-syncs `src/` under
        # running jobs. A record write must degrade, not throw — and must not
        # substitute a plausible-looking wrong revision.
        @test _code_rev_or_nothing() == code_tree_hash()
        @test _code_rev_or_nothing() !== nothing
    end
end
