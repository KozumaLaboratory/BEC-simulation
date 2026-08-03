using Test, SpinorBEC, YAML
using SpinorBEC: Model, Stage, artifact_id, content_id, GridSpec, InteractionSpec,
    PotentialSpec, HarmonicSpec, resolve_atom

# Prose must not move the identity — and physics must.
#
# Measured 2026-08-03 on `runs/barnett_week1/scalar_rotation_om0p0.yaml`:
#
#     content_id(with metadata:)    = be787f554832dd43
#     content_id(without metadata:) = 2d33445c54b918d3
#
# `metadata:` is read by no code path. `_canonical_bytes!`
# (`workflow/experiment.jl:61`) hashes every key of the spec dict without
# exception, so deleting a comment block moves the name of the computation and
# orphans whatever was cached under the old one. That is the over-invalidation
# arm of the trilemma the model layer exists to close, and it is not
# hypothetical: harvesting the 302 `metadata:` blocks out of `runs/` moved 302
# ids at once.
#
# `artifact_id` closes it by construction rather than by exclusion list: it
# hashes a resolved `Stage` (model, kind, method, backend, params, from,
# code_rev), and a documentary key never becomes any of those. There is nothing
# to remember to skip, so there is nothing to forget.
#
# BOTH ARMS ARE REQUIRED. The prose arm alone passes for a constant function —
# `artifact_id(_) = "same"` satisfies it perfectly. The physics arm is the
# positive control that says the instrument can still read.

@testset "prose does not move identity; physics does" begin
    base = Dict{String, Any}(
        "atom" => "Eu151",
        "grid" => Dict("n" => [16, 16, 16], "L" => [8.0, 8.0, 8.0]),
        "interactions" => Dict("c0" => 10.0, "c1" => 0.1, "omega_ref" => 100.0),
        "trap" => Dict("kind" => "harmonic", "omega" => [1.0, 1.0, 1.2]),
    )

    # ---- arm 1: the old spec-text id is prose-sensitive (the defect) --------
    @testset "content_id(spec) IS moved by a documentary key" begin
        _with(note) = merge(base, Dict("metadata" => Dict("notes" => note)))
        bare = content_id(base)
        prosed = content_id(_with("validation target: no L_z response"))
        @test bare != prosed          # this is the behaviour being fixed, pinned
        # …and it is the KEY that matters, not the value: any edit to the prose
        # moves it again, so a config whose comment is reworded loses its cache.
        reworded = content_id(_with("validation target: no Lz response"))
        @test reworded != prosed
    end

    # ---- arm 2: artifact_id is not ------------------------------------------
    # Same construction as `test_artifact_id.jl`'s `probe_model`: `Model` holds
    # SPECS, not evaluated objects — `GridSpec` rather than `Grid`.
    _model(; n=(16, 16, 16), c1=-0.3, omega=(1.0, 1.0, 1.0)) = Model(;
        grid=GridSpec(; ndim=3, n_points=n, box=(8.0, 8.0, 8.0)),
        atom=resolve_atom(:Eu151),
        interactions=InteractionSpec(; n_atoms=5000, omega_ref=691.15, c0=10.0, c1),
        potential=PotentialSpec(; harmonic=[HarmonicSpec(; omega)]))

    model = _model()
    stage = Stage(:relax, model, :itp, nothing,
        (; dt=1.0e-3, n_steps=2000, tol=1.0e-8), :cpu)

    @testset "artifact_id has no prose to be sensitive to" begin
        # A `Stage` has six fields and none of them can hold a comment. The
        # claim is structural, so state it structurally rather than by
        # constructing two Stages that differ in a field that does not exist.
        @test fieldnames(Stage) == (:kind, :model, :method, :from, :params, :backend)
        @test !any(f -> occursin("meta", String(f)) || occursin("note", String(f)),
            fieldnames(Stage))
        @test !any(f -> occursin("meta", String(f)) || occursin("note", String(f)),
            fieldnames(Model))
        # Same Stage, rebuilt: same id. (Not a tautology — `code_rev` is read
        # from disk on each call, so this also pins that it is stable within a
        # session.)
        again = Stage(:relax, _model(), :itp, nothing,
            (; dt=1.0e-3, n_steps=2000, tol=1.0e-8), :cpu)
        @test artifact_id(stage) == artifact_id(again)
    end

    # ---- arm 3: POSITIVE CONTROL — physics still moves it -------------------
    # Without this the two arms above are satisfied by a constant.
    @testset "positive control: every physics axis moves artifact_id" begin
        id0 = artifact_id(stage)
        base = (; dt=1.0e-3, n_steps=2000, tol=1.0e-8)
        moved = [
            "c1" => Stage(:relax, _model(; c1=-0.6), :itp, nothing, base, :cpu),
            "grid" => Stage(:relax, _model(; n=(32, 32, 32)), :itp, nothing, base, :cpu),
            "trap" => Stage(:relax, _model(; omega=(1.0, 1.0, 1.5)), :itp, nothing, base, :cpu),
            "n_steps" => Stage(:relax, model, :itp, nothing, (; base..., n_steps=4000), :cpu),
            "tol" => Stage(:relax, model, :itp, nothing, (; base..., tol=1.0e-10), :cpu),
            "method" => Stage(:relax, model, :lbfgs, nothing, base, :cpu),
            "kind" => Stage(:evolve, model, :itp, nothing, base, :cpu),
        ]
        ids = String[]
        for (axis, st) in moved
            id = artifact_id(st)
            push!(ids, id)
            @test id != id0        # named, so a failure says WHICH axis went blind
        end
        @test length(unique(ids)) == length(ids)   # and no two collide
    end

    # ---- arm 4: the harvested configs really are prose-only -----------------
    # The deletion is only safe because `metadata:` reaches no physics. Assert
    # that on the real files rather than trusting the harvest script: load a
    # sample of the configs as they stood BEFORE the harvest and confirm the
    # only key that left is `metadata`.
    @testset "harvest removed prose and nothing else" begin
        root = normpath(joinpath(@__DIR__, "..", ".."))
        blocks = joinpath(root, "docs", "validation", "config_metadata_blocks.toml")
        if !isfile(blocks)
            @test_skip "config_metadata_blocks.toml not present"
        else
            gitdir = joinpath(root, ".git")
            if !ispath(gitdir)
                @test_skip "not a git checkout"
            else
                sample = filter(p -> endswith(p, ".yaml"),
                    readlines(`git -C $root diff --name-only HEAD -- runs/`))
                @test !isempty(sample)
                checked = 0
                for rel in first(sample, 12)
                    old_txt = try
                        read(`git -C $root show HEAD:$rel`, String)
                    catch
                        continue
                    end
                    new_path = joinpath(root, rel)
                    isfile(new_path) || continue
                    old = YAML.load(old_txt)
                    new = YAML.load_file(new_path)
                    old isa AbstractDict && new isa AbstractDict || continue
                    @test setdiff(keys(old), keys(new)) ⊆ Set(["metadata"])
                    @test isempty(setdiff(keys(new), keys(old)))
                    # every surviving key is byte-identical
                    for k in keys(new)
                        @test new[k] == old[k]
                    end
                    checked += 1
                end
                @test checked > 0
            end
        end
    end
end
