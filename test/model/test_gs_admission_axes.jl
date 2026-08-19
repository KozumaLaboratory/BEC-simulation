# Cutover step 3: the GS stage cache admits on `artifact_id`, and the id is at
# least as discriminating as the 19-entry key it replaced.
#
# `_gs_cache_key` is deleted, so this file cannot compare against it. The 19
# entries are therefore written out as LITERALS below (`OLD_KEY_ENTRIES`) and
# each one is an axis with its OWN assertion. That shape is the point: a single
# bundled assertion ("all these move the id") is how a 17-key list rots into a
# 15-key list, and this campaign has already watched a hand-written key list drop
# a field with every gate staying green (`_enc_atom` lost `g_F`).
#
# Five arms, none of which the other four can satisfy:
#
#   A. PARTITION. Every `GS_SCHEMA` key is in exactly one bucket — model, stage,
#      refused-as-dropped-physics, refused-as-uncacheable, destination, or
#      not-on-this-path. Total and disjoint, so a schema key added without a
#      decision is red rather than silently uncounted.
#
#   B. TEXTUAL. The keys claimed NOT to be on this path are not read from `p` in
#      either file that resolves a ground-state step, and — the other direction,
#      without which the arm is vacuous — every key claimed to BE on it is.
#
#   C. AXES. 31 knobs, one `@testset` each, each asserting the id MOVES. 19 from
#      the old key, 11 it was blind to, and the dealias globals, which no
#      step-params key can even name.
#
#   D. THE SITE. The runner lowers to a call to `_gs_artifact_id`, AND a real
#      `_run_step` reports the same id this file computes. Arm C alone would pass
#      against a function nothing calls.
#
#   E. FAIL-SAFE. A config that cannot build a `Model` has no id, therefore never
#      hits: it recomputes every time, writes nothing into the shared store, and
#      says so ONCE per distinct reason rather than once per scan point.
#
#   F. THE HIT REBUILDS THE SAME HAMILTONIAN. Step 1b marked a `[KNOWN-GAP]` at
#      the cache-hit `make_workspace`: it passed no `light_shift`, no
#      `spinor_lhy`, no `lhy_opts` and no `rotating_frame_omega`, so a hit handed
#      downstream analyzers a Hamiltonian missing three terms the fresh solve
#      had. It belongs to step 3 because step 3 is what makes it dangerous —
#      those are slots of the model the id is derived from, so a hit is by
#      construction a hit for a config that DECLARED them.

using Test
using JLD2
using SpinorBEC
# `Base.CoreLogging`, not `using Logging`: under `Pkg.test()` the sandbox
# environment has no `Logging` entry and the file errors on load (measured — it
# passed standalone and took worker 3 down in the fast tier). Every symbol needed
# lives in Base, and the tier runner requires each test file to be a
# dependency-free unit.
using Base.CoreLogging: with_logger, Warn
using SpinorBEC: GS_SCHEMA, GS_KEYS_DROPPED_PHYSICS, GroundStateStep, _run_step,
    resolve_gs, gs_stage, gs_model, artifact_id, _gs_artifact_id, _gs_stage_params,
    _reset_no_artifact_id_warnings!, code_tree_hash, _CODE_TREE_HASH_MEMO,
    _package_root, _enc_atom, AtomSpecies, Model,
    DEALIAS_2_3_ENABLED, DEALIAS_K_CUTOFF

# ---------------------------------------------------------------------------
# Arm A: where every GS_SCHEMA key goes
# ---------------------------------------------------------------------------

"Keys that reach a `Model` slot — the physics half of the id."
const AX_TO_MODEL = Set([
    "atom", "grid", "interactions", "ddi", "B", "potential", "lhy",
    "light_shift", "rotating_frame_omega",
])

"Keys that reach `Stage` — its `method` / `backend` fields or `_gs_stage_params`."
const AX_TO_STAGE = Set([
    "method", "backend", "dt", "n_steps", "tol", "tol_drho", "m_lbfgs",
    "newton_polish", "residual_polish", "initial_state", "init_state_params",
    "target_magnetization", "temperature_ratio", "noise_seed", "pin",
])

"""
Keys whose PRESENCE makes the step uncacheable rather than changing the id.

`seed_from` warm-starts from bytes at a path. `Stage.from` is the slot a
predecessor belongs in and `artifact_id` recurses into it, but the predecessor
here is a directory of point files, not a `Stage` — so the solve is refused
rather than mis-declared as from-scratch.
"""
const AX_REFUSED_UNCACHEABLE = Set(["seed_from"])

"Names WHERE the artifact goes, not WHAT it contains. `cache:` also disables the auto path outright."
const AX_DESTINATION = Set(["cache"])

"""
Keys the spinor ground-state runner never reads.

`kind` selects WHICH runner (`binary` and `rotating_basis` have their own
`_run_step` methods), so this one only ever sees `spinor`. The rest belong to
those other paths: `dtype` is the rotating-basis mixed-precision switch,
`species_A`/`species_B` are the binary GP's two components, and `F` /
`gauge_fix` / `init_m_idx` / `init_sigma` are rotating-basis knobs. Including any
of them in the id would over-discriminate — safe, but a false statement about
what this computation depends on.
"""
const AX_NOT_ON_PATH = Set([
    "kind", "dtype", "species_A", "species_B", "F", "gauge_fix",
    "init_m_idx", "init_sigma",
])

const AX_BUCKETS = (
    "model" => AX_TO_MODEL,
    "stage" => AX_TO_STAGE,
    "dropped physics" => Set(GS_KEYS_DROPPED_PHYSICS),
    "uncacheable" => AX_REFUSED_UNCACHEABLE,
    "destination" => AX_DESTINATION,
    "not on this path" => AX_NOT_ON_PATH,
)

# ---------------------------------------------------------------------------
# The 19 entries `_gs_cache_key` hand-listed, verbatim from the deleted source.
# Each maps to the axis below that replaces it. Written out because the function
# is gone: a gate that regenerated this list from the thing it checks would move
# both sides together.
# ---------------------------------------------------------------------------
const OLD_KEY_ENTRIES = [
    "v" => "code_rev",                  # key-schema version -> the code hash
    "method" => "method",
    "atom" => "atom",
    "F" => "atom.F",
    "n_points" => "n_points",
    "box" => "box",
    "c" => "c",
    "c_lhy" => "c_lhy",
    "ddi" => "ddi",
    "tol" => "tol",
    "n_steps" => "n_steps",
    "dt" => "dt",
    "potential" => "potential",
    "B" => "B",
    "lhy" => "lhy",
    "initial_state" => "initial_state",
    "init_state_params" => "init_state_params",
    "target_magnetization" => "target_magnetization",
    "temperature_ratio" => "temperature_ratio",
]

"The eleven inputs `_gs_cache_key` did NOT read, measured one knob at a time before the flip."
const OLD_KEY_BLIND = [
    "m_lbfgs", "newton_polish", "residual_polish", "pin", "tol_drho",
    "noise_seed", "light_shift", "rotating_frame_omega", "backend", "code_rev",
    "seed_from",
]

# ---------------------------------------------------------------------------
# fixture
# ---------------------------------------------------------------------------

ax_base(; extra...) = begin
    p = Dict{String, Any}(
        "atom" => "Eu151",
        "grid" => Dict{String, Any}("n" => [8, 8, 8], "box" => [6.0, 6.0, 6.0]),
        "interactions" => Dict{String, Any}(
            "N_atoms" => 1000, "omega_ref" => 691.15, "c1_ratio" => -0.01),
        "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0, 1.0, 2.0]),
        "B" => Dict{String, Any}("Bz" => 0.01),
        "ddi" => Dict{String, Any}("secular" => true),
        "method" => "itp",
        "n_steps" => 20,
        "dt" => 0.002,
        "tol" => 1.0e-8,
        "backend" => "cpu",
    )
    for (k, v) in extra
        p[String(k)] = v
    end
    p
end

"""
The id of a step-params dict, THROUGH the function the runner calls.

`resolve_gs` mutates `p` (`_resolve_derived_params!` writes back `ddi.c_dd`,
`interactions.c_lhy`, `lhy_kind`, `lhy_opts`), so the dict handed to
`_gs_artifact_id` must be the same one that was resolved — and a fresh copy per
call, or axis N would inherit axis N-1's derived slots.
"""
function ax_id(p::Dict{String, Any})
    q = deepcopy(p)
    r = resolve_gs(q, nothing, nothing, nothing; verbose=false)
    _gs_artifact_id(r, q)
end

"Why the id is absent, for a diagnostic — never for an assertion."
function ax_why(p::Dict{String, Any})
    q = deepcopy(p)
    try
        artifact_id(gs_stage(resolve_gs(q, nothing, nothing, nothing; verbose=false), q))
        nothing
    catch err
        err isa ArgumentError ? err.msg : sprint(showerror, err)
    end
end

ax_with_code_rev(f, value) = begin
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

"Julia source with whole-line comments removed, so a name in prose is not read as a read."
ax_code_only(path) = join([l for l in eachline(path) if !startswith(lstrip(l), "#")], "\n")

"Every `GlobalRef` name reachable from `_run_step`'s ground-state chain."
function ax_runner_globals()
    out = Set{Symbol}()
    seen = Set{Method}()
    walk(x, acc) =
        if x isa GlobalRef
            push!(acc, x.name)
        elseif x isa Expr
            foreach(a -> walk(a, acc), x.args)
        elseif x isa Core.ReturnNode
            isdefined(x, :val) && walk(x.val, acc)
        elseif x isa Core.GotoIfNot
            walk(x.cond, acc)
        end
    queue = Method[
        m for m in methods(_run_step)
              if endswith(String(m.file), "run_step_ground_state.jl")
    ]
    isempty(queue) && error("no _run_step method is defined in run_step_ground_state.jl")
    while !isempty(queue)
        m = pop!(queue)
        m in seen && continue
        push!(seen, m)
        names = Set{Symbol}()
        foreach(x -> walk(x, names), Base.uncompressed_ast(m).code)
        for s in names
            push!(out, s)
            # A keyword method lowers to a wrapper forwarding to a gensym'd body;
            # stopping at the wrapper sees a handful of names and would report
            # anything absent.
            startswith(String(s), "#_run_step#") || continue
            isdefined(SpinorBEC, s) || continue
            v = getfield(SpinorBEC, s)
            v isa Function || continue
            for mm in methods(v)
                endswith(String(mm.file), "run_step_ground_state.jl") && push!(queue, mm)
            end
        end
    end
    out
end

@testset "GS admission keys on artifact_id, one axis at a time" begin
    # ---------------------------------------------------------------
    # Arm A: the partition is total and disjoint
    # ---------------------------------------------------------------
    @testset "A. every GS_SCHEMA key is classified exactly once" begin
        all_keys = Set(keys(GS_SCHEMA))
        classified = union((s for (_, s) in AX_BUCKETS)...)

        unclassified = sort!(collect(setdiff(all_keys, classified)))
        isempty(unclassified) || println(
            "  GS_SCHEMA keys with no bucket (decide where each goes): ",
            join(unclassified, ", "))
        @test isempty(unclassified)

        stale = sort!(collect(setdiff(classified, all_keys)))
        isempty(stale) || println("  bucketed keys not in GS_SCHEMA: ", join(stale, ", "))
        @test isempty(stale)

        # Disjoint: a key in two buckets makes the totality check pass while the
        # counts below silently disagree.
        dupes = String[]
        for (n1, s1) in AX_BUCKETS, (n2, s2) in AX_BUCKETS
            n1 < n2 || continue
            for k in intersect(s1, s2)
                push!(dupes, "$k in both $n1 and $n2")
            end
        end
        isempty(dupes) || println("  keys in two buckets: ", join(dupes, "; "))
        @test isempty(dupes)

        @test sum(length(s) for (_, s) in AX_BUCKETS) == length(all_keys)
        # The bucket the SOURCE owns, pinned so moving a key out of it costs a
        # deliberate edit here as well. `a_s`, `ddi_pad` and `B_magnitude_gauss`
        # joined 2026-08-18 with `kind: scalar_egpe` — declared in GS_SCHEMA and
        # read only by that path, so the spinor runner drops them silently.
        @test Set(GS_KEYS_DROPPED_PHYSICS) == Set(["quasi_2d", "l_z", "raman",
            "B_direction", "a_s", "ddi_pad", "B_magnitude_gauss"])
    end

    # ---------------------------------------------------------------
    # Arm B: the "not on this path" claim is a fact about the source
    # ---------------------------------------------------------------
    @testset "B. the runner reads exactly the keys claimed to be on this path" begin
        root = pkgdir(SpinorBEC)
        files = [
            joinpath(root, "src", "workflow", "experiments", "pipeline",
                "run_step_ground_state.jl"),
            joinpath(root, "src", "workflow", "experiments", "pipeline", "resolve_gs.jl"),
        ]
        @test all(isfile, files)
        src = join(ax_code_only.(files), "\n")

        # `get(p, "k", …)`, `haskey(p, "k")` and `p["k"]` are the three forms in
        # which a step-params key is read.
        reads(k) = occursin("p, \"$k\"", src) || occursin("p[\"$k\"]", src)

        wrongly_read = [k for k in AX_NOT_ON_PATH if reads(k)]
        isempty(wrongly_read) || println(
            "  claimed off this path but READ from p: ", join(sort!(wrongly_read), ", "))
        @test isempty(wrongly_read)

        # The other direction. Without it the arm passes against a runner that
        # reads nothing at all.
        #
        # `lhy` is the one declared exception and it is real: the block is
        # normalised into `lhy_kind` / `lhy_opts` by `_resolve_derived_params!`
        # (`schema/parsing_blocks.jl`), one layer up, so neither file names it.
        expect_read = setdiff(
            union(AX_TO_MODEL, AX_TO_STAGE, AX_REFUSED_UNCACHEABLE, AX_DESTINATION),
            Set(["lhy"]))
        missing_read = [k for k in expect_read if !reads(k)]
        isempty(missing_read) || println(
            "  claimed on this path but never read from p: ", join(sort!(missing_read), ", "))
        @test isempty(missing_read)
        # ... and the exception is an exception, not a typo.
        @test occursin("p, \"lhy_kind\"", src) || occursin("p[\"lhy_kind\"]", src)
        @test occursin("p, \"lhy_opts\"", src) || occursin("p[\"lhy_opts\"]", src)
    end

    # ---------------------------------------------------------------
    # Arm C: the axes. One assertion each.
    # ---------------------------------------------------------------
    base_id = ax_id(ax_base())

    # Carried forward from `test/workflow/test_gs_stage_cache.jl`, whose
    # `_gs_cache_key` fixtures died with the function in cutover step 3. The
    # PROPERTY they were protecting did not: reusing ONE ground state across
    # several `analyze` blocks is the entire purpose of this cache, so an
    # `analyze` block must not move the id. That row was added on main
    # (2026-07-30) with the note that the testset's NAME had promised `analyze`
    # since before its body checked it — "analyze / metadata / cache" while the
    # body added only `cache` — so folding `analyze` into the key escaped the
    # mutation harness. Losing it in a merge would reopen exactly that gap.
    @testset "C0b. an analyze block does not move the id" begin
        p1 = ax_base()
        p1["analyze"] = Any[Dict("column_density_movie" => Dict("axis" => 3))]
        @test ax_id(p1) == base_id

        p2 = ax_base()
        p2["analyze"] = Any[Dict("vortex_extraction" => Dict())]
        @test ax_id(p2) == base_id

        # POSITIVE CONTROL. The two blocks must actually differ, or both
        # equalities above hold for the trivial reason and gate nothing. This is
        # main's control, kept verbatim in spirit.
        @test p1["analyze"] != p2["analyze"]
    end

    @testset "C0. the base resolves, and the id is a deterministic 16-hex string" begin
        why = ax_why(ax_base())
        why === nothing || println("  base fixture does not resolve: ", why)
        @test base_id !== nothing
        @test base_id isa AbstractString
        @test length(base_id) == 16
        @test all(c -> c in "0123456789abcdef", base_id)
        # Determinism across two independent resolutions of the same declaration.
        # Without it every inequality below could be satisfied by an id that is
        # simply random.
        @test ax_id(ax_base()) == base_id
    end

    "Assert one knob moves the id, and say which one when it does not."
    function axis(name, p)
        id = ax_id(p)
        if id === nothing
            println("  axis $name: NO ID — ", ax_why(p))
        elseif id == base_id
            println("  axis $name: id did NOT move (", id, ")")
        end
        @test id !== nothing
        @test id != base_id
    end

    # --- the 19 the old key hand-listed ------------------------------
    @testset "C1. method" begin
        axis("method", ax_base(; method="lbfgs"))
    end
    @testset "C2. atom (same F, different species)" begin
        # Er166 is also F=6, so this moves the ATOM without moving F — the two
        # were separate entries in the old key and are separate axes here.
        axis("atom", ax_base(; atom="Er166"))
    end
    @testset "C3. atom.F" begin
        # There is no way to move F through a config without moving the species,
        # so the claim is made where it lives: the atom encoder that feeds the
        # model carries `F`, and two atoms differing only in it encode differently.
        a1 = AtomSpecies("probe", 1.0e-25, 1, 100.0, 100.0, 1.0)
        a2 = AtomSpecies("probe", 1.0e-25, 2, 100.0, 100.0, 1.0)
        @test _enc_atom(a1) != _enc_atom(a2)
        @test haskey(_enc_atom(a1), "F")
        # Positive control on the comparison itself.
        @test _enc_atom(a1) == _enc_atom(AtomSpecies("probe", 1.0e-25, 1, 100.0, 100.0, 1.0))
    end
    @testset "C4. n_points" begin
        axis(
            "n_points",
            ax_base(;
                grid=Dict{String, Any}("n" => [16, 16, 16], "box" => [6.0, 6.0, 6.0])),
        )
    end
    @testset "C5. box" begin
        axis("box", ax_base(;
            grid=Dict{String, Any}("n" => [8, 8, 8], "box" => [7.0, 7.0, 7.0])))
    end
    @testset "C6. c (the resolved couplings)" begin
        axis(
            "c",
            ax_base(;
                interactions=Dict{String, Any}(
                    "N_atoms" => 1000, "omega_ref" => 691.15, "c1_ratio" => -0.02),
            ),
        )
    end
    @testset "C7. c_lhy" begin
        a = ax_base(; lhy=Dict{String, Any}("kind" => "scalar", "c_lhy" => 3.0))
        b = ax_base(; lhy=Dict{String, Any}("kind" => "scalar", "c_lhy" => 4.0))
        ia, ib = ax_id(a), ax_id(b)
        @test ia !== nothing && ib !== nothing
        @test ia != ib
    end
    @testset "C8. ddi" begin
        axis("ddi", ax_base(; ddi=Dict{String, Any}("secular" => false)))
    end
    @testset "C9. tol" begin
        axis("tol", ax_base(; tol=1.0e-9))
    end
    @testset "C10. n_steps" begin
        axis("n_steps", ax_base(; n_steps=21))
    end
    @testset "C11. dt" begin
        axis("dt", ax_base(; dt=0.003))
    end
    @testset "C12. potential" begin
        axis(
            "potential",
            ax_base(;
                potential=Dict{String, Any}("type" => "harmonic", "omega" => [1.0, 1.0, 2.5])),
        )
    end
    @testset "C13. B" begin
        axis("B", ax_base(; B=Dict{String, Any}("Bz" => 0.02)))
    end
    @testset "C14. lhy" begin
        axis("lhy", ax_base(;
            lhy=Dict{String, Any}("kind" => "full_bdg", "n_max" => 12.0)))
    end
    @testset "C15. initial_state" begin
        axis("initial_state", ax_base(; initial_state="m_plus_F"))
    end
    @testset "C16. init_state_params" begin
        a = ax_base(; initial_state="spin_coherent",
            init_state_params=Dict{String, Any}("theta" => 0.3))
        b = ax_base(; initial_state="spin_coherent",
            init_state_params=Dict{String, Any}("theta" => 0.4))
        ia, ib = ax_id(a), ax_id(b)
        @test ia !== nothing && ib !== nothing
        @test ia != ib
    end
    @testset "C17. target_magnetization" begin
        axis("target_magnetization", ax_base(; target_magnetization=0.3))
    end
    @testset "C18. temperature_ratio" begin
        axis("temperature_ratio", ax_base(; temperature_ratio=0.2))
    end

    # --- the eleven the old key was blind to -------------------------
    @testset "C19. m_lbfgs" begin
        axis("m_lbfgs", ax_base(; m_lbfgs=20))
    end
    @testset "C20. newton_polish" begin
        axis("newton_polish", ax_base(; newton_polish=true))
    end
    @testset "C21. residual_polish" begin
        axis("residual_polish", ax_base(; residual_polish=true))
    end
    @testset "C22. pin" begin
        # Two claims: a pin at all, and WHICH ramp. `config_c1kappa_B0` / `B10`
        # carry a pin and `B60` does not, and the ramp selects the branch.
        pinned(eps) = ax_base(; pin=Dict{String, Any}(
            "kind" => "transverse", "epsilon_ramp" => eps))
        axis("pin", pinned([1.0e-3]))
        i1, i2 = ax_id(pinned([1.0e-3])), ax_id(pinned([2.0e-3]))
        @test i1 !== nothing && i2 !== nothing
        @test i1 != i2
    end
    @testset "C23. tol_drho" begin
        axis("tol_drho", ax_base(; tol_drho=1.0e-5))
    end
    @testset "C24. noise_seed" begin
        axis("noise_seed", ax_base(; noise_seed=7))
    end
    @testset "C25. light_shift" begin
        axis("light_shift", ax_base(;
            light_shift=Dict{String, Any}("eta_tensor" => 0.2)))
    end
    @testset "C26. rotating_frame_omega" begin
        axis("rotating_frame_omega", ax_base(; rotating_frame_omega=0.3))
    end
    @testset "C27. backend" begin
        axis("backend", ax_base(; backend="gpu"))
    end
    @testset "C28. code_rev" begin
        # THE axis step 1 explicitly forbade and step 3 decides the other way:
        # `_gs_cache_key` was gated NOT to move with the code revision, because
        # admitting on it would have invalidated the store on every commit. It
        # now does, which is invariant 3 and §7's open question 1.
        moved = ax_with_code_rev("0"^64) do
            ax_id(ax_base())
        end
        @test moved !== nothing
        @test moved != base_id
        # ... and the poke really is a poke: restoring gives the base id back.
        @test ax_id(ax_base()) == base_id
    end

    # --- beyond both lists -------------------------------------------
    @testset "C29. the dealias globals" begin
        # No step-params key can name these: they are module `Ref`s popped from a
        # TOP-LEVEL `dealias:` block, 75 committed configs set them, and
        # dealiasing is an exact spectral projector — two runs differing in it
        # differ in their answer. `_gs_cache_key` could not see them either.
        e0, k0 = DEALIAS_2_3_ENABLED[], DEALIAS_K_CUTOFF[]
        try
            DEALIAS_2_3_ENABLED[] = !e0
            moved = ax_id(ax_base())
            @test moved !== nothing
            @test moved != base_id
        finally
            DEALIAS_2_3_ENABLED[] = e0
            DEALIAS_K_CUTOFF[] = k0
        end
        @test ax_id(ax_base()) == base_id
    end

    @testset "C30. every entry of the old key has an axis above" begin
        # Bookkeeping, not physics: the enumeration is only a replacement for the
        # deleted 19-key list if the counts line up, and the count is what rots.
        @test length(OLD_KEY_ENTRIES) == 19
        @test length(unique(first.(OLD_KEY_ENTRIES))) == 19
        @test length(OLD_KEY_BLIND) == 11
        @test isempty(intersect(Set(first.(OLD_KEY_ENTRIES)), Set(OLD_KEY_BLIND)))
    end

    # ---------------------------------------------------------------
    # Arm D: the site really uses this id
    # ---------------------------------------------------------------
    @testset "D. the runner calls _gs_artifact_id, and reports the same value" begin
        g = ax_runner_globals()
        # Positive control on the walk: without it, "the name is absent" and "the
        # walk saw nothing" are indistinguishable.
        @test :make_workspace in g
        @test :resolve_gs in g
        @test length(g) > 30
        @test :_gs_artifact_id in g
        # The deleted key is not reachable from the runner under any name.
        @test !(:_gs_cache_key in g)

        mktempdir() do dir
            (_, _, _, _, res) = withenv("SPINORBEC_STAGE_CACHE" => "1",
                "SPINORBEC_STAGE_DIR" => dir) do
                _run_step(GroundStateStep(ax_base()), nothing, nothing, nothing, nothing;
                    verbose=false)
            end
            # BY VALUE, not by name: arm C would pass against a function nothing
            # calls, and the structural arm above would pass against a call whose
            # result was discarded.
            @test res[:gs_stage_ref] == base_id
            @test isfile(joinpath(dir, base_id * ".jld2"))
            d = JLD2.load(joinpath(dir, base_id * ".jld2"))
            # The artifact records the id that named it, under that name. Step 1
            # spelled this `gs_cache_key`; the function it named is gone.
            @test d["artifact_id"] == base_id
            @test !haskey(d, "gs_cache_key")
            @test d["code_rev"] == code_tree_hash()
        end
    end

    # ---------------------------------------------------------------
    # Arm E: the fail-safe
    # ---------------------------------------------------------------
    # Bare c0/c1 and no N_atoms — 16 committed configs are this shape, and they
    # RUN today. `gs_model` refuses rather than substituting a default.
    unresolvable() = Dict{String, Any}(
        "atom" => "Rb87",
        "method" => "itp",
        "grid" => Dict{String, Any}("n" => [16], "box" => [8.0]),
        "interactions" => Dict{String, Any}("omega_ref" => 100.0, "c0" => 1.0, "c1" => 0.0),
        "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0]),
        "initial_state" => "polar",
        "n_steps" => 20,
        "dt" => 1.0e-3,
        "tol" => 1.0e-6,
    )

    @testset "E1. no Model -> no id -> never a hit, and nothing is written" begin
        @test ax_id(unresolvable()) === nothing
        @test occursin("N_atoms", ax_why(unresolvable()))

        mktempdir() do dir
            run1 = withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => dir) do
                _run_step(GroundStateStep(unresolvable()), nothing, nothing, nothing, nothing;
                    verbose=false)
            end
            @test run1[5][:gs_stage_ref] === nothing
            # It RAN — the fail-safe costs a recomputation, not the answer.
            @test isfinite(run1[5][:ground_state_energy])
            @test isempty(readdir(dir))

            # ... and a second run recomputes rather than hitting. The energies
            # agree, so "no hit" is a statement about admission and not about the
            # solve having changed.
            run2 = withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => dir) do
                _run_step(GroundStateStep(unresolvable()), nothing, nothing, nothing, nothing;
                    verbose=false)
            end
            @test run2[5][:gs_stage_ref] === nothing
            @test isempty(readdir(dir))
            @test run2[5][:ground_state_energy] ≈ run1[5][:ground_state_energy] rtol = 1e-10
            # A cache hit sets this; a recomputation cannot.
            @test !haskey(run2[5], :ground_state_provenance)

            # POSITIVE CONTROL, and it goes last so it cannot be confused with
            # the arm above: the same env, same store, a config that DOES
            # resolve, and now the store grows. Without it "nothing was written"
            # would also pass against a stage cache that was never switched on.
            withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => dir) do
                _run_step(GroundStateStep(ax_base()), nothing, nothing, nothing, nothing;
                    verbose=false)
            end
            @test any(f -> endswith(f, ".jld2"), readdir(dir))
        end
    end

    @testset "E2. the warning is once per REASON, not once per point" begin
        _reset_no_artifact_id_warnings!()
        logger = Test.TestLogger(; min_level=Warn)
        with_logger(logger) do
            for _ in 1:4
                ax_id(unresolvable())
            end
        end
        hits = [r for r in logger.logs if occursin("has no artifact id", r.message)]
        length(hits) == 1 ||
            println("  expected 1 warning, got ", length(hits), " over 4 identical configs")
        @test length(hits) == 1

        # A DIFFERENT reason warns again — otherwise "once" would be "once ever",
        # and the second gap would be silent. `ax_why` rather than `ax_id`,
        # because calling `ax_id` here would register the warning outside the
        # logger and the arm below would measure zero for the wrong reason
        # (it did, on the first run of this file).
        other = ax_base(; lhy=Dict{String, Any}("kind" => "full_bdg"))   # no n_max
        why_other = ax_why(other)
        @test why_other !== nothing        # else `occursin` errors on `nothing`
        @test why_other !== nothing && occursin("n_max", why_other)
        logger2 = Test.TestLogger(; min_level=Warn)
        with_logger(logger2) do
            ax_id(unresolvable())        # already warned: silent
            ax_id(other)                 # new reason: warns
            ax_id(other)                 # same reason again: silent
        end
        hits2 = [r for r in logger2.logs if occursin("has no artifact id", r.message)]
        @test length(hits2) == 1
        _reset_no_artifact_id_warnings!()
    end

    @testset "E3. seed_from is refused rather than cached from-scratch" begin
        # `psi_prev === nothing` was the whole guard, and a `seed_from` solve
        # satisfies it while being warm-started from bytes at a path. 19
        # committed configs use `seed_from`.
        mktempdir() do seeddir
            # One matching point, in the shape `_resolve_seed_from` looks for.
            # 3-D on purpose: the cell signature's third component is ω_z, and a
            # 1-D config makes it NaN on BOTH sides — where `isapprox` is false,
            # so nothing would ever match and the arm would pass on a throw.
            psi_seed = fill(ComplexF64(1.0 / sqrt(8^3 * 3)), 8, 8, 8, 3)
            jldopen(joinpath(seeddir, "point_001.jld2"), "w") do f
                f["psi"] = psi_seed
                f["override"] = Dict{String, Any}(
                    "pipeline.0.interactions.c1_ratio" => 0.0,
                    "pipeline.0.B.Bz" => "0.0 Gauss",
                    "pipeline.0.potential.omega.2" => 1.0,
                    "pipeline.0.initial_state" => "polar")
            end
            p = Dict{String, Any}(
                "atom" => "Rb87",
                "method" => "itp",
                "grid" => Dict{String, Any}("n" => [8, 8, 8], "box" => [8.0, 8.0, 8.0]),
                "interactions" => Dict{String, Any}(
                    "N_atoms" => 100, "omega_ref" => 100.0, "c1_ratio" => 0.0),
                "potential" => Dict{String, Any}(
                    "type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
                "initial_state" => "polar",
                "n_steps" => 20,
                "dt" => 1.0e-3,
                "tol" => 1.0e-6,
            )
            # It HAS an id — the refusal is about the warm start, not about the
            # physics being unrepresentable. Without this the assertion below
            # would pass for the wrong reason.
            @test ax_id(p) !== nothing

            mktempdir() do dir
                p_seed = deepcopy(p)
                p_seed["seed_from"] = Dict{String, Any}("run" => seeddir, "upsample" => false)
                (_, _, _, _, res) = withenv("SPINORBEC_STAGE_CACHE" => "1",
                    "SPINORBEC_STAGE_DIR" => dir) do
                    _run_step(GroundStateStep(p_seed), nothing, nothing, nothing, nothing;
                        verbose=false)
                end
                # It really was warm-started — otherwise "refused" would be
                # indistinguishable from "the seed was never found and the run
                # threw", which is what a mismatched fixture produces.
                @test isfinite(res[:ground_state_energy])
                @test res[:gs_stage_ref] === nothing
                @test isempty(readdir(dir))
            end
            # POSITIVE CONTROL: the same config WITHOUT `seed_from` caches.
            mktempdir() do dir
                (_, _, _, _, res) = withenv("SPINORBEC_STAGE_CACHE" => "1",
                    "SPINORBEC_STAGE_DIR" => dir) do
                    _run_step(GroundStateStep(deepcopy(p)), nothing, nothing, nothing, nothing;
                        verbose=false)
                end
                @test res[:gs_stage_ref] isa AbstractString
                @test !isempty(readdir(dir))
            end
        end
    end

    # ---------------------------------------------------------------
    # Arm F: the [KNOWN-GAP] step 1b left for step 3
    # ---------------------------------------------------------------
    @testset "F. a cache HIT rebuilds the same Hamiltonian the solve had" begin
        # All three terms at once, because the hit path either passes all four
        # kwargs or none and a one-term fixture would not say which.
        #
        # `n_max` is EXPLICIT and that is load-bearing rather than incidental:
        # a tabulated LHY without it resolves to `n_max = NaN` ("3 x
        # max|psi_init|^2"), `LHYSpec` refuses that, and the config then has no
        # id and can never reach this branch at all. So every artifact a hit can
        # serve has a seed-independent table — which is what makes rebuilding it
        # from the CACHED ψ rather than from the seed a legitimate thing to do.
        p = ax_base(;
            n_steps=5,
            lhy=Dict{String, Any}("kind" => "polar_contact", "n_max" => 12.0),
            rotating_frame_omega=0.3,
            light_shift=Dict{String, Any}("eta_tensor" => 0.2))
        mktempdir() do dir
            run() = withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => dir) do
                _run_step(GroundStateStep(deepcopy(p)), nothing, nothing, nothing, nothing;
                    verbose=false)
            end
            (_, _, _, ws_fresh, r1) = run()
            (_, _, _, ws_hit, r2) = run()

            # The premise: the second run really was served from the store. If it
            # solved again, every equality below would hold for the wrong reason.
            @test r1[:gs_stage_ref] isa AbstractString
            @test r2[:gs_stage_ref] == r1[:gs_stage_ref]
            @test String(get(r2, :ground_state_provenance, "")) == "marked"

            # The fresh workspace HAS all three, or the comparison is vacuous.
            @test ws_fresh.lhy !== nothing
            @test ws_fresh.light_shift !== nothing
            @test ws_fresh.coriolis_cache !== nothing
            @test ws_fresh.sim_params.rotating_frame_omega == 0.3

            # ... and the one a hit hands to the analyzers matches it.
            @test typeof(ws_hit.lhy) === typeof(ws_fresh.lhy)
            @test ws_hit.lhy !== nothing
            @test ws_hit.light_shift !== nothing
            @test ws_hit.coriolis_cache !== nothing
            @test ws_hit.sim_params.rotating_frame_omega == 0.3
        end
    end
end

# --- Arm G: within-build deduplication (A5:R-BSALC-03) -------------------
#
# The design listed this as "asserted to be one lookup; nothing enforces it
# yet". Measured 2026-08-04: it already holds. Two steps with identical
# declarations inside one build resolve to the same `artifact_id`, and the
# second is served from the store rather than re-solved — 10.57 s then 3.13 s,
# provenance `marked`.
#
# It is worth a gate rather than a note because the frontier releases up to 64
# stages: if dedup silently stopped, a sweep whose points share a ground state
# would re-solve it per point and nothing would say so except the wall clock.
# The real corpus has that shape — 59 configs under `runs/klaus_quench/` share
# one `artifact_id`.
@testset "G. identical declarations inside one build are ONE computation" begin
    p = ax_base(; n_steps=3)
    mktempdir() do dir
        run() = withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => dir) do
            _run_step(GroundStateStep(deepcopy(p)), nothing, nothing, nothing, nothing;
                verbose=false)
        end
        (_, _, _, _, r1) = run()
        (_, _, _, _, r2) = run()

        # Same name...
        @test r1[:gs_stage_ref] isa AbstractString
        @test r2[:gs_stage_ref] == r1[:gs_stage_ref]
        # ...and the second one was SERVED, not recomputed. Provenance is the
        # discriminator: a fresh solve leaves it unset.
        @test String(get(r2, :ground_state_provenance, "")) == "marked"
        @test String(get(r1, :ground_state_provenance, "")) == ""
        # The energies agree exactly, which is the point of serving it at all.
        @test r2[:ground_state_energy] == r1[:ground_state_energy]
    end

    # POSITIVE CONTROL: a declaration that DIFFERS must not be deduplicated,
    # or the arm above is satisfied by a cache that serves everything.
    mktempdir() do dir
        runp(q) = withenv("SPINORBEC_STAGE_CACHE" => "1", "SPINORBEC_STAGE_DIR" => dir) do
            _run_step(GroundStateStep(deepcopy(q)), nothing, nothing, nothing, nothing;
                verbose=false)
        end
        (_, _, _, _, a) = runp(ax_base(; n_steps=3))
        (_, _, _, _, b) = runp(ax_base(; n_steps=4))
        @test b[:gs_stage_ref] != a[:gs_stage_ref]
        @test String(get(b, :ground_state_provenance, "")) == ""
    end
end
