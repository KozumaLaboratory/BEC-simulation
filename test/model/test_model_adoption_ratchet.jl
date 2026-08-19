using Test
# Not needed by the scan (this file reads source text), but required by
# `test_tier_membership.jl` so no test file depends on a sibling having loaded
# the package first. In-suite the load is already paid.
using SpinorBEC

# The config → `make_workspace` hand-mapping may SHRINK. It may not grow.
#
# WHY THIS FILE EXISTS
#
# `src/model.jl` has said "Still to come: `make_workspace(::Model)` and the
# retirement of the fifteen YAML normalisation passes" since the Model layer
# landed. That sentence has no date, no number, and no consequence, and a
# migration described that way does not finish — measured on this very tree:
# `COUPLING_TOL` shipped with "the bare values are kept available for legacy
# call sites" and lost 7 : 121 (CLAUDE.md commitment 11).
#
# The realisation layer now EXISTS (`src/model/realise.jl`, 2026-08-19) and
# `make_workspace(::Model)` works — gated against the resolver path by
# `test_realise_matches_resolver.jl`. So the obvious next move is to point the
# pipeline at it and watch this number fall.
#
# IT CANNOT FALL YET, AND THE REASON IS NOT THE CALL SITES.
#
# `gs_model` is not TOTAL over the corpus: measured 351 of 429 configs under
# `runs/` resolve to a `Model` (`test_corpus_resolves.jl`, which lists every
# exclusion by name and reason — a tabulated LHY with no resolved `n_max`, a step
# with no `N_atoms`, a dropped B tilt). The other 78 run fine today. Swapping the
# ground-state runner onto `make_workspace(::Model)` would refuse them, so the
# migration is blocked on MODEL COVERAGE, not on transcription discipline, and
# the work runs through that exclusion list rather than through this file.
#
# Naming that is the point of this comment. "Still to come" with no number is how
# the last migration stalled; "still to come, blocked on 78 configs, here is the
# list" is a work item.
#
# WHAT THIS RATCHET MEASURES, AND WHAT IT DELIBERATELY DOES NOT
#
# Only CONFIG TRANSCRIPTION: a site that turns a YAML block into kwargs by hand.
# The four solver entry points (`find_ground_state`, its adaptive and pinned
# variants, `find_ground_state_lbfgs`) are excluded BY NAME below, because they
# are the direct-Julia API — `find_ground_state(; grid, atom, …)` is the
# documented primitive, and forwarding one's own kwargs is not transcription.
# Forcing a `Model` on them would be the wrong shape.
#
# Their risk is real but different: a kwarg present in the signature and inert in
# the body, which is exactly the LBFGS `rotating_frame_omega` bug. That is gated
# BEHAVIOURALLY by `test_solver_forwards_every_knob.jl` — build twice, require a
# difference — which is a stronger check than a count, so counting them here as
# well would double-report one risk and understate the other.

const _RATCHET_PHYSICS_KWARGS = (
    "zeeman", "potential", "raman", "loss", "light_shift", "magnetic_gradient",
    "spatial_zeeman", "absorbing_boundary", "time_dep_interactions",
    "enable_ddi", "c_dd", "secular_ddi", "quasi_2d_ddi", "l_z_ddi",
    "ddi_padding", "ddi_pad_factor", "ddi_trunc_radius", "spinor_lhy",
    "lhy_opts", "quasi_2d", "l_z", "interactions",
)

# The direct-Julia solver API. Forwarding one's own kwargs is not config
# transcription, and `test_solver_forwards_every_knob.jl` gates the risk these
# sites DO carry (an accepted-but-inert knob) behaviourally. Excluded by name so
# the exclusion is a decision with a reason attached, not a threshold quietly
# fitted until the count passed.
const RATCHET_SOLVER_API = (
    "src/solvers/ground_state.jl",
    "src/solvers/ground_state/adaptive.jl",
    "src/solvers/ground_state/pinned.jl",
    "src/solvers/lbfgs/driver.jl",
)

# Measured 2026-08-19. Config-transcription sites only — the solver API above is
# excluded. Each is a place a YAML block becomes kwargs by hand.
#
#   19  workflow/.../pipeline/run_step_dynamics.jl     the dynamics handler
#    7  workflow/validation/accuracy_profiles.jl       accuracy-profile probe
#    6  workflow/.../run_step_rotating/dynamics.jl     rotating-basis dynamics
#
# `run_step_ground_state.jl` is absent because its three copies were collapsed
# into `gs_physics_kwargs` — that is what this ratchet looks like when it works.
# The dynamics handler is the one to do next: 19 kwargs, no resolver of its own,
# and the second LHY resolver (`_resolve_dyn_lhy!`) lives there because of it.
# Its `ddi: {secular}` was silently dropped until 2026-08-19 for the same reason.
const RATCHET_HAND_MAPPED_SITES = 3

_ratchet_code(txt) = join([split(l, "#")[1] for l in split(txt, "\n")], "\n")

"""Balanced-paren argument text of every `make_workspace(` call under `src/`,
excluding the definition's own file. Comments are stripped first — a call
QUOTED in a docstring is documentation, and counting it was a false positive
this scan produced on its first run."""
function _ratchet_call_sites()
    root = normpath(joinpath(@__DIR__, "..", "..", "src"))
    out = Tuple{String, Int, Int, Bool}[]
    for (dir, dirs, files) in walkdir(root)
        filter!(d -> !(d in (".git", "worktrees")), dirs)
        for f in files
            endswith(f, ".jl") || continue
            f == "make_workspace.jl" && continue
            path = joinpath(dir, f)
            rel = relpath(path, dirname(root))
            txt = _ratchet_code(read(path, String))
            for m in eachmatch(r"make_workspace\(", txt)
                i = m.offset + length(m.match)
                depth = 1
                while i <= lastindex(txt) && depth > 0
                    c = txt[i]
                    depth += (c == '(') - (c == ')')
                    i = nextind(txt, i)
                end
                arg = txt[(m.offset + length(m.match)):prevind(txt, i)]
                n = count(k -> occursin(Regex("(^|[\\s,;(])" * k * "\\s*(=[^=]|,|\\)|\$)"), arg),
                    _RATCHET_PHYSICS_KWARGS)
                push!(
                    out,
                    (rel, count("\n", txt[1:(m.offset)]) + 1, n,
                        occursin("gs_physics_kwargs", arg)),
                )
            end
        end
    end
    out
end

@testset "config→make_workspace hand-mapping does not grow" begin
    sites = _ratchet_call_sites()

    @testset "the scan can see call sites at all" begin
        # Positive control: the ITP entry point is a known hand-mapped site with
        # a large bundle. Without this, an extractor that matched nothing would
        # report a fully-migrated tree.
        @test any(s -> occursin("solvers/ground_state.jl", s[1]) && s[3] >= 10, sites)
        # …and the bundled form is recognised as bundled, or every migration
        # would still count as hand-mapped and the ratchet could never tighten.
        @test any(s -> s[4], sites)
        @test length(sites) >= 10
    end

    @testset "the solver-API exclusion is real and still needed" begin
        # Each excluded path must EXIST and must actually be a hand-mapped site,
        # or the exclusion is stale cover. A path that stopped qualifying should
        # be removed from the list, not left to excuse a future one.
        for p in RATCHET_SOLVER_API
            matching = [s for s in sites if s[1] == p && s[3] >= 6 && !s[4]]
            if isempty(matching)
                println("  stale RATCHET_SOLVER_API entry (no longer hand-mapped): $p")
            end
            @test !isempty(matching)
        end
    end

    @testset "count" begin
        hand = [s for s in sites if s[3] >= 6 && !s[4] && !(s[1] in RATCHET_SOLVER_API)]
        for s in sort(hand; by=x -> -x[3])
            println("  hand-mapped: $(s[3]) physics kwargs at $(s[1]):$(s[2])")
        end
        if length(hand) > RATCHET_HAND_MAPPED_SITES
            println("""
              A NEW hand-mapped make_workspace call site has appeared.
              Use `gs_physics_kwargs(r)` (or the resolver bundle for your step
              kind). If the site genuinely cannot use one, raise
              RATCHET_HAND_MAPPED_SITES with the reason — deliberately, in a
              diff someone reads. See CLAUDE.md commitment 11.""")
        end
        @test length(hand) <= RATCHET_HAND_MAPPED_SITES

        # The ratchet must also TIGHTEN. If a migration lands and nobody lowers
        # the constant, the next regression is free.
        if length(hand) < RATCHET_HAND_MAPPED_SITES
            println("""
              $(length(hand)) hand-mapped sites remain, but the ratchet is set to
              $(RATCHET_HAND_MAPPED_SITES). Lower it to $(length(hand)).""")
        end
        @test length(hand) == RATCHET_HAND_MAPPED_SITES
    end
end
