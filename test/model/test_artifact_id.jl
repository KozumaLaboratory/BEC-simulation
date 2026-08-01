# `artifact_id(::Stage)` and `code_tree_hash()` — cutover step 1.
#
# Invariant 1: identity is the WHOLE declaration, never a selection from it. The
# gate is therefore one assertion per field, so a field that stops entering the
# digest names itself instead of hiding behind a sibling that still moves.
#
# Invariant 3: code identity is one tree hash of `src/` and `ext/`. It is a
# CONTENT hash, not a git revision — the autopilot rsyncs code to TSUBAME with
# `--exclude=.git/` (`workflow/autopilot/ssh_transport.jl:72`), so on the compute
# node there is no repository to ask, and `git rev-parse HEAD:src` does not move
# for the uncommitted edits and untracked-but-loaded files that a live research
# tree is full of.

using Test
using SHA
using SpinorBEC
using SpinorBEC: Model, Stage, stage, artifact_id, code_tree_hash, content_id,
    GridSpec, InteractionSpec, DDISpec, PotentialSpec, HarmonicSpec, resolve_atom,
    model_toml_dict, _enc, _package_root, _code_tree_paths, _CODE_TREE_HASH_MEMO,
    STAGE_KINDS

probe_model() = Model(;
    grid=GridSpec(; ndim=3, n_points=(16, 16, 16), box=(8.0, 8.0, 8.0)),
    atom=resolve_atom(:Eu151),
    interactions=InteractionSpec(; n_atoms=5000, omega_ref=691.15, c0=10.0, c1=-0.3),
    potential=PotentialSpec(; harmonic=[HarmonicSpec(; omega=(1.0, 1.0, 1.0))]))

probe_stage(; model=probe_model(), kind=:relax, method=:itp, backend=:cpu,
    from=nothing, params=(dt=1.0e-3, n_steps=2000, tol=1.0e-8)) =
    Stage(kind, model, method, from, params, backend)

# The Eu F=6 channel set, and the same keys in a table grown to a different
# capacity: equal contents, different iteration order.
const EU_CHANNELS = (0 => 1.0, 2 => 2.0, 4 => 3.0, 6 => 4.0, 8 => 5.0,
    10 => 6.0, 12 => 7.0)

function grown_dict(pairs)
    d = Dict{Int, Float64}()
    sizehint!(d, 1000)
    for (k, v) in pairs
        d[k] = v
    end
    d
end

@testset "artifact_id" begin
    m = probe_model()
    s = probe_stage()

    @testset "determinism" begin
        @test artifact_id(s) == artifact_id(s)
        @test artifact_id(probe_stage()) == artifact_id(probe_stage())
        id = artifact_id(s)
        @test id isa AbstractString
        @test length(id) == 16
        @test all(c -> c in "0123456789abcdef", id)
        # Equal-by-value stages built from separately-constructed models: the
        # id must be a function of the VALUE, not of object identity.
        @test artifact_id(probe_stage(; model=probe_model())) == artifact_id(s)
    end

    # One assertion per field. A field silently dropped from the digest fails
    # here alone; it cannot be masked by a sibling that still moves the id.
    @testset "sensitivity — one field at a time" begin
        @testset "model" begin
            m2 = SpinorBEC.with(m; interactions=SpinorBEC.with(m.interactions; c1=-0.31))
            @test artifact_id(probe_stage(; model=m2)) != artifact_id(s)
        end
        @testset "kind" begin
            @test artifact_id(probe_stage(; kind=:evolve)) != artifact_id(s)
        end
        @testset "method" begin
            @test artifact_id(probe_stage(; method=:lbfgs)) != artifact_id(s)
        end
        @testset "backend" begin
            @test artifact_id(probe_stage(; backend=:gpu)) != artifact_id(s)
        end
        @testset "params" begin
            @test artifact_id(probe_stage(; params=(dt=2.0e-3, n_steps=2000, tol=1.0e-8))) !=
                artifact_id(s)
            # The save-cadence hole this design closes: an extra numeric knob
            # moves the id BY CONSTRUCTION, with no list to add it to.
            @test artifact_id(
                probe_stage(;
                    params=(dt=1.0e-3, n_steps=2000, tol=1.0e-8, save_every=10)),
            ) !=
                artifact_id(s)
        end
        @testset "from" begin
            parent = probe_stage(; kind=:relax, method=:lbfgs)
            @test artifact_id(probe_stage(; kind=:evolve, from=parent)) !=
                artifact_id(probe_stage(; kind=:evolve))
            # ... and a DIFFERENT predecessor gives a different child, i.e. the
            # edge carries the ancestor's identity rather than just its presence.
            other = probe_stage(; kind=:relax, method=:itp)
            @test artifact_id(parent) != artifact_id(other)
            @test artifact_id(probe_stage(; kind=:evolve, from=parent)) !=
                artifact_id(probe_stage(; kind=:evolve, from=other))
        end
        @testset "code_rev" begin
            # Poking the memo is the only way to move the code revision without
            # editing the tree under a running test. Without this assertion the
            # code_rev field could be dropped from the digest unnoticed.
            key = abspath(_package_root())
            saved = get(_CODE_TREE_HASH_MEMO, key, nothing)
            try
                id0 = artifact_id(s)
                _CODE_TREE_HASH_MEMO[key] = "0"^64
                @test artifact_id(s) != id0
                _CODE_TREE_HASH_MEMO[key] = saved === nothing ? code_tree_hash() : saved
                @test artifact_id(s) == id0
            finally
                if saved === nothing
                    delete!(_CODE_TREE_HASH_MEMO, key)
                else
                    (_CODE_TREE_HASH_MEMO[key] = saved)
                end
            end
        end
    end

    # `Stage` has SIX fields and every one of them is identity — that is the
    # design's point, so there is no non-physics Stage field to be insensitive
    # to. What must not move the id is a difference of REPRESENTATION inside the
    # model, and there are exactly two ways to write one.
    @testset "representation-only differences do not move the id" begin
        @test fieldcount(Stage) == 6
        # A constant trace and a bare number are the same static knob;
        # `canonical_waveform` collapses the trace so they cannot take two ids.
        flat = SpinorBEC.PiecewiseLinearWaveform([0.0, 1.0], [10.0, 10.0])
        m_flat = SpinorBEC.with(m;
            interactions=SpinorBEC.with(m.interactions; c0=flat))
        @test artifact_id(probe_stage(; model=m_flat)) == artifact_id(s)
        # Dict iteration order in `AtomSpecies.scattering_lengths` — the one
        # hash-ordered field reachable from a Model. Reordering the CONSTRUCTOR
        # ARGUMENTS is not a fixture: iteration order is a function of the key
        # set and the TABLE CAPACITY, not of insertion order, so two 3-key
        # literals over the same keys iterate identically and the version of
        # this assertion that used them stayed green with `_enc_atom`'s `sort!`
        # deleted. One side is therefore grown to a different capacity.
        d1 = Dict(EU_CHANNELS)
        d2 = grown_dict(EU_CHANNELS)
        @test collect(keys(d1)) != collect(keys(d2))   # the fixture must BE one
        @test d1 == d2
        a1 = SpinorBEC.AtomSpecies("probe", 1.0e-25, 6, 1.0e-9, 1.1e-9, 0.0, 0.5, d1)
        a2 = SpinorBEC.AtomSpecies("probe", 1.0e-25, 6, 1.0e-9, 1.1e-9, 0.0, 0.5, d2)
        mk(a) = probe_stage(;
            model=Model(;
                grid=GridSpec(; ndim=1, n_points=(8,), box=(4.0,)), atom=a,
                interactions=InteractionSpec(; n_atoms=1, omega_ref=1.0)),
        )
        @test artifact_id(mk(a1)) == artifact_id(mk(a2))
    end

    @testset "the digest is over the whole declaration" begin
        # Restating §2.3's dict and asserting it reproduces the id: a field
        # added to `Stage` but not to `artifact_id` reddens here.
        expected = content_id(
            Dict{String, Any}(
                "model" => model_toml_dict(s.model),
                "kind" => String(s.kind),
                "method" => String(s.method),
                "backend" => String(s.backend),
                "params" => _enc(s.params),
                "from" => nothing,
                "code_rev" => code_tree_hash()),
        )
        @test artifact_id(s) == expected
        @test Set(fieldnames(Stage)) ==
            Set((:kind, :model, :method, :from, :params, :backend))
    end

    @testset "Stage validates what the tree actually accepts" begin
        @test STAGE_KINDS == (:relax, :evolve, :measure)
        @test_throws ArgumentError stage(:solve; model=m, method=:itp)
        # `:cuda` LOOKS admissible and is not — `_resolve_backend`
        # (`foundation/backend.jl:101`) throws on it, and a check that
        # hand-listed the backends would have let it through.
        @test_throws ArgumentError stage(:relax; model=m, method=:itp, backend=:cuda)
        @test_throws ArgumentError stage(:relax; model=m, method=:itp, backend=:opencl)
        @test stage(:relax; model=m, method=:itp, backend=:gpu).backend === :gpu
        # An empty params set is a legitimate declaration, not a fieldless value
        # the encoder should refuse.
        @test artifact_id(stage(:measure; model=m, method=:bdg)) isa AbstractString
    end

    @testset "the encoder refuses what it cannot represent" begin
        # `_enc`'s generic arm reflects a struct into its fields, and a FIELDLESS
        # value reflected into `Dict()` — laundering an unencodable value past
        # `_canonical_bytes!`, which is the enforcement invariant 1 rests on.
        @test_throws ArgumentError _enc(nothing)
        @test_throws ArgumentError _enc(sin)
        @test_throws ArgumentError artifact_id(
            stage(:relax; model=m, method=:itp, objective=sin))
        @test _enc(NamedTuple()) == Dict{String, Any}()
    end
end

@testset "code_tree_hash" begin
    @testset "shape and determinism" begin
        h = code_tree_hash()
        @test h isa AbstractString
        @test length(h) == 64
        @test all(c -> c in "0123456789abcdef", h)
        @test code_tree_hash() == h
        @test code_tree_hash(; refresh=true) == h
    end

    @testset "path set matches the repository, where git exists" begin
        # Cross-check of the two definitions: the walk's skip list is
        # hand-maintained, and this is what says so the day it stops matching.
        # `--others --exclude-standard` includes untracked-but-loaded files —
        # `src/model/` itself was exactly that while this was written.
        root = _package_root()
        ours = _code_tree_paths(root)
        gitp = try
            out = read(
                Cmd(`git ls-files --cached --others --exclude-standard -- src ext`;
                    dir=root), String)
            sort!(filter(!isempty, split(out, '\n')))
        catch
            nothing
        end
        if gitp === nothing
            @info "git unavailable here; the cross-check is skipped, not passed"
            @test_skip false
        else
            extra = setdiff(ours, gitp)
            missed = setdiff(gitp, ours)
            isempty(extra) || println("  hashed but not in git: ", extra)
            isempty(missed) || println("  in git but not hashed: ", missed)
            @test isempty(extra)
            @test isempty(missed)
            @test length(ours) > 300
        end
    end

    @testset "canary: content, additions, deletions and renames all move it" begin
        # In a throwaway tree, never the repository. Each arm is a real edit
        # followed by a real recomputation.
        mktempdir() do d
            mkpath(joinpath(d, "src", "sub"))
            mkpath(joinpath(d, "ext"))
            write(joinpath(d, "src", "a.jl"), "x = 1\n")
            write(joinpath(d, "src", "sub", "b.jl"), "y = 2\n")
            write(joinpath(d, "ext", "c.jl"), "z = 3\n")
            h0 = code_tree_hash(d; refresh=true)

            write(joinpath(d, "src", "a.jl"), "x = 2\n")          # content
            h1 = code_tree_hash(d; refresh=true)
            @test h1 != h0
            write(joinpath(d, "src", "a.jl"), "x = 1\n")
            @test code_tree_hash(d; refresh=true) == h0

            write(joinpath(d, "src", "new.jl"), "w = 4\n")         # addition
            @test code_tree_hash(d; refresh=true) != h0
            rm(joinpath(d, "src", "new.jl"))
            @test code_tree_hash(d; refresh=true) == h0

            write(joinpath(d, "src", "table.toml"), "k = 1\n")     # non-.jl addition
            @test code_tree_hash(d; refresh=true) != h0
            rm(joinpath(d, "src", "table.toml"))

            rm(joinpath(d, "ext", "c.jl"))                          # deletion
            @test code_tree_hash(d; refresh=true) != h0
            write(joinpath(d, "ext", "c.jl"), "z = 3\n")
            @test code_tree_hash(d; refresh=true) == h0

            mv(joinpath(d, "src", "a.jl"), joinpath(d, "src", "a2.jl"))  # rename
            @test code_tree_hash(d; refresh=true) != h0
            mv(joinpath(d, "src", "a2.jl"), joinpath(d, "src", "a.jl"))
            @test code_tree_hash(d; refresh=true) == h0

            # `test/` and `docs/` are deliberately out of scope.
            mkpath(joinpath(d, "test"))
            write(joinpath(d, "test", "t.jl"), "@test true\n")
            @test code_tree_hash(d; refresh=true) == h0

            # Skipped droppings do not move it.
            write(joinpath(d, "src", "a.jl.cov"), "        - x = 1\n")
            write(joinpath(d, "src", "a.jl~"), "x = 1\n")
            @test code_tree_hash(d; refresh=true) == h0
        end
    end

    @testset "path and content cannot be confused for one another" begin
        # Two trees with the SAME FILE COUNT are not a fixture for the length
        # prefix: the `0x00` after each path already separates them, and the
        # `ab.jl`/`a.jl` pair this testset used to hold stayed green with
        # `hton(UInt64(length(bytes)))` deleted from `_code_tree_hash_uncached`.
        # The prefix earns its keep only when a whole `"path\0"` can migrate
        # across the boundary, and that needs the file COUNTS to differ: with it
        # removed, the one-file and two-file trees below hash alike (both
        # 26a415b2…d6d68d4c, i.e. one stream "src/a.jl\0hellosrc/b.jl\0world").
        mktempdir() do d1
            mktempdir() do d2
                mkpath(joinpath(d1, "src"))
                mkpath(joinpath(d2, "src"))
                write(joinpath(d1, "src", "a.jl"), "hello" * "src/b.jl" * "\0" * "world")
                write(joinpath(d2, "src", "a.jl"), "hello")
                write(joinpath(d2, "src", "b.jl"), "world")
                @test code_tree_hash(d1; refresh=true) != code_tree_hash(d2; refresh=true)
            end
        end
        # Same-file-count sibling, kept for the plain path/content shuffle.
        mktempdir() do d1
            mktempdir() do d2
                mkpath(joinpath(d1, "src"))
                mkpath(joinpath(d2, "src"))
                write(joinpath(d1, "src", "ab.jl"), "c")
                write(joinpath(d2, "src", "a.jl"), "bc")
                @test code_tree_hash(d1; refresh=true) != code_tree_hash(d2; refresh=true)
            end
        end
    end

    @testset "independent of location and mtime" begin
        # This is what makes it usable across the repo's many worktrees, where
        # the same commit sits at different paths with different mtimes.
        mktempdir() do d1
            mktempdir() do d2
                for d in (d1, d2)
                    mkpath(joinpath(d, "src"))
                    write(joinpath(d, "src", "a.jl"), "x = 1\n")
                end
                touch(joinpath(d2, "src", "a.jl"))
                @test code_tree_hash(d1; refresh=true) == code_tree_hash(d2; refresh=true)
            end
        end
    end

    @testset "a missing ext/ is not an error" begin
        mktempdir() do d
            mkpath(joinpath(d, "src"))
            write(joinpath(d, "src", "a.jl"), "x = 1\n")
            @test code_tree_hash(d; refresh=true) isa AbstractString
        end
    end
end
