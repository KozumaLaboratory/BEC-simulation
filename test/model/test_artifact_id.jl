# `artifact_id(::Stage)` and `code_tree_hash()` — cutover step 1.
#
# Invariant 1: identity is the WHOLE declaration, never a selection from it. The
# gate is therefore one assertion per field — `Stage`'s six, plus `model`'s
# fourteen slots enumerated from `fieldnames(Model)` — so a field that stops
# entering the digest names itself instead of hiding behind a sibling that still
# moves.
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
    GridSpec, InteractionSpec, DDISpec, LHYSpec, PotentialSpec, HarmonicSpec,
    ZeemanSpec, RamanSpec, LightShiftSpec, GradientSpec, FrameSpec, GeometrySpec,
    ReservoirSpec, LossParams, AbsorbingBoundary, AtomSpecies,
    PiecewiseLinearWaveform, resolve_atom, with, _speceq,
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

# `AtomSpecies` is a reused foundation type, not a `ModelValue`, so `with` does
# not reach it, and it has no all-positional form — `a_s` and `q_geometry` are
# DERIVED inside the constructor. Rebuilding by hand is the only way to move one
# of its fields.
heavier(a::AtomSpecies) = AtomSpecies(a.name, a.mass * 1.01, a.F, a.a0, a.a2,
    a.mu_mag, a.g_F, copy(a.scattering_lengths);
    a.Delta_E_hf, a.g_J, a.nuclear_I, a.electronic_J)

# One perturbation per `Model` slot, keyed by slot name, with the key set pinned
# to `fieldnames(Model)` by the testset below.
#
# What this replaces: a single nudge of `interactions.c1`, which put all fourteen
# slots on one assertion. Adding `f === :light_shift && continue` to
# `model_toml_dict` — i.e. removing that slot from the digest ENTIRELY — left
# this file 57/57 green. `light_shift` is one of exactly two slots the cutover
# exists to stop losing: `_gs_cache_key` omitted `light_shift` and
# `rotating_frame_omega` while passing both to the solver.
#
# Each entry maps a slot's OLD value to a new one and can see nothing else, so a
# perturbation cannot reach a sibling and let a dropped slot ride on it.
#
# The set-equality assertion is the load-bearing half. Without it, a slot added
# in 2029 would simply go unperturbed and this enumeration would rot exactly like
# the hand-listed key set it replaces; with it, adding a slot without deciding
# how to perturb it is RED.
#
# `grid`, `atom` and `interactions` have no inactive value and `potential` is
# populated in `probe_model`, so those four are perturbed in place. The other ten
# are switched ON: inactive → active is the difference an omitted slot hides,
# since an inactive slot is legitimately absent from the serialised form.
const MODEL_SLOT_PERTURBATION = Dict{Symbol, Function}(
    :grid => g -> with(g; dealias_two_thirds=true),
    :atom => heavier,
    :interactions => i -> with(i; c1=-0.31),
    :potential => _ -> PotentialSpec(; harmonic=[HarmonicSpec(; omega=(1.0, 1.0, 2.0))]),
    :zeeman => _ -> ZeemanSpec(; p=0.1),
    :ddi => _ -> DDISpec(; c_dd=0.4),
    :lhy => _ -> LHYSpec(; kind=:scalar, c_lhy=0.05),
    :raman => _ -> RamanSpec(; omega_r=0.5),
    :light_shift => _ -> LightShiftSpec(; eta_vector=0.2),
    :magnetic_gradient => _ -> GradientSpec(; gradient=0.1, axis=3, g_F=1.163),
    :frame => _ -> FrameSpec(; rotating_omega=0.3),
    :geometry => _ -> GeometrySpec(; absorbing=AbsorbingBoundary(0.5, 1.0, 4)),
    :reservoir => _ -> ReservoirSpec(; sgpe_gamma=0.01),
    :loss => _ -> LossParams(; L3=1.0e-4),
)

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

    # `AtomSpecies` is not a `ModelValue`, so the `fieldnames(Model)` enumeration
    # above stops at the `atom` slot boundary and everything inside it used to
    # ride on one fixture. Measured before this was written: dropping "g_F" from
    # `_enc_atom` left this file fully green while the round-trip suite errored —
    # the identical asymmetry the Model hole had, for 12 of 13 keys.
    @testset "atom fields — the enumeration continues past the slot boundary" begin
        # PINNED, not read from the source. Deriving `encoded` from
        # `_ATOM_DERIVED` and then checking the encoder against it is CIRCULAR —
        # editing `_ATOM_DERIVED` moves both sides together and nothing fails.
        # Measured: with the circular form, declaring `mu_mag` derived, and
        # un-declaring `a_s`, both left this file fully green. Moving a field
        # into or out of "derived" is a decision about the physics and must cost
        # a deliberate edit here.
        const_derived = Set([:a_s, :q_geometry])
        @test Set(SpinorBEC._ATOM_DERIVED) == const_derived

        # A declared-derived field must actually BE derived: the constructor has
        # to reproduce it from the rest, or "derived" is just a licence to drop.
        @testset "declared-derived is really derived" begin
            a = SpinorBEC.resolve_atom(:Eu151)
            rebuilt = SpinorBEC.resolve_atom(:Eu151)
            for f in const_derived
                @test getfield(a, f) == getfield(rebuilt, f)
            end
        end

        derived = const_derived
        encoded = setdiff(Set(fieldnames(SpinorBEC.AtomSpecies)), derived)

        # The guard: every AtomSpecies field is either encoded or DECLARED
        # derived. A 15th field cannot be silently dropped from the digest.
        @testset "coverage is total" begin
            enc = SpinorBEC._enc_atom(SpinorBEC.resolve_atom(:Eu151))
            named = setdiff(Set(Symbol.(keys(enc))), Set([:channel_S, :channel_a]))
            @test named == setdiff(encoded, Set([:scattering_lengths]))
            @test Set(SpinorBEC._ATOM_KEYS) == Set(keys(enc))
            # Derived fields must NOT be written — a value the reader recomputes
            # and ignores is a drift surface the file could disagree with.
            for f in derived
                @test !haskey(enc, String(f))
            end
        end

        # And each encoded field must actually reach the digest.
        base = SpinorBEC.resolve_atom(:Eu151)
        for f in sort!(collect(encoded))
            @testset "$f" begin
                enc = SpinorBEC._enc_atom(base)
                ks = f === :scattering_lengths ? ("channel_S", "channel_a") : (String(f),)
                for k in ks
                    @test haskey(enc, k)
                end
            end
        end
    end

    # One assertion per field. A field silently dropped from the digest fails
    # here alone; it cannot be masked by a sibling that still moves the id.
    @testset "sensitivity — one field at a time" begin
        # `model` is FOURTEEN fields, so it gets fourteen assertions. The
        # enumeration is `fieldnames(Model)` — the compiler's answer, which
        # cannot drift from the struct — and never a list written here.
        @testset "model" begin
            @testset "every slot has a perturbation, and every perturbation a slot" begin
                # The part that stops the enumeration rotting: adding a slot
                # without deciding how to perturb it reddens HERE, rather than
                # silently leaving the new slot untested.
                absent = setdiff(fieldnames(Model), keys(MODEL_SLOT_PERTURBATION))
                extra = setdiff(keys(MODEL_SLOT_PERTURBATION), fieldnames(Model))
                isempty(absent) || println("  Model slots with no perturbation: ", absent)
                isempty(extra) || println("  perturbations naming no Model slot: ", extra)
                @test Set(keys(MODEL_SLOT_PERTURBATION)) == Set(fieldnames(Model))
            end
            for f in fieldnames(Model)
                @testset "$f" begin
                    v = MODEL_SLOT_PERTURBATION[f](getfield(m, f))
                    m2 = with(m; NamedTuple{(f,)}((v,))...)
                    # The fixture must BE one. A value the constructor normalises
                    # straight back (invariant 3 does exactly that to an inactive
                    # spec's secondary fields) would make the id assertion vacuous
                    # and green.
                    @test !_speceq(getfield(m2, f), getfield(m, f))
                    # ... and it must move ONLY this slot. `Model`'s constructor
                    # rewrites two of them (`_trim_pad_factor`, the `LossParams`
                    # rebuild), and a perturbation that reached a sibling would let
                    # a slot dropped from the digest ride on that sibling — which
                    # is precisely the failure the single-assertion `model` arm had.
                    also = [
                        g for g in fieldnames(Model)
                        if g !== f && !_speceq(getfield(m2, g), getfield(m, g))
                    ]
                    isempty(also) || println("  perturbing $f also moved: ", also)
                    @test isempty(also)
                    @test artifact_id(probe_stage(; model=m2)) != artifact_id(s)
                end
            end
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
        flat = PiecewiseLinearWaveform([0.0, 1.0], [10.0, 10.0])
        m_flat = with(m; interactions=with(m.interactions; c0=flat))
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
        a1 = AtomSpecies("probe", 1.0e-25, 6, 1.0e-9, 1.1e-9, 0.0, 0.5, d1)
        a2 = AtomSpecies("probe", 1.0e-25, 6, 1.0e-9, 1.1e-9, 0.0, 0.5, d2)
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
