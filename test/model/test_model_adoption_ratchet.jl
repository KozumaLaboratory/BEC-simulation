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
# The Model layer is 4107 lines and genuinely correct; what it lacks is the
# Spec → runtime realisation (`GridSpec` → `Grid`, `PotentialSpec` → the eight
# trap terms, `ZeemanSpec` → `ZeemanParams`/`ZeemanField`, …) that
# `make_workspace(::Model)` needs. That is real work and building it in a hurry
# would produce exactly the half-finished second layer this whole campaign is
# about.
#
# So the interim commitment is a RATCHET rather than a promise. The count below
# is what the tree has today. A new hand-mapped call site — a sixth pipeline
# handler, a new solver entry point — turns this red and the author has to
# either use the bundle or argue the number up deliberately, in a diff someone
# reviews. It cannot drift.
#
# Lowering the number when a site is migrated is the point; the test says so and
# names the new value, so the ratchet tightens by itself.

const _RATCHET_PHYSICS_KWARGS = (
    "zeeman", "potential", "raman", "loss", "light_shift", "magnetic_gradient",
    "spatial_zeeman", "absorbing_boundary", "time_dep_interactions",
    "enable_ddi", "c_dd", "secular_ddi", "quasi_2d_ddi", "l_z_ddi",
    "ddi_padding", "ddi_pad_factor", "ddi_trunc_radius", "spinor_lhy",
    "lhy_opts", "quasi_2d", "l_z", "interactions",
)

# Measured 2026-08-19, after `run_step_ground_state.jl`'s three copies were
# collapsed into `gs_physics_kwargs`. Each entry is a place a config's physics
# is transcribed into kwargs by hand.
#
#   16  solvers/ground_state.jl                        ITP entry point
#   16  solvers/ground_state/adaptive.jl               adaptive-dt ITP
#   16  workflow/.../pipeline/run_step_dynamics.jl     the dynamics handler
#   14  solvers/lbfgs/driver.jl                        LBFGS entry point
#   14  solvers/ground_state/pinned.jl                 pinned-branch continuation
#    7  workflow/validation/accuracy_profiles.jl       profile probe
#    6  workflow/.../run_step_rotating/dynamics.jl     rotating-basis dynamics
const RATCHET_HAND_MAPPED_SITES = 7

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

    @testset "count" begin
        hand = [s for s in sites if s[3] >= 6 && !s[4]]
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
