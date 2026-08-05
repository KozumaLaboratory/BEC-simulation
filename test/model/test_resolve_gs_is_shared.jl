# `resolve_gs` is the ONE resolution of a `ground_state:` block, and BOTH
# consumers go through it.
#
# The failure this file exists to prevent is specific: a second reader of
# `potential:` / `B:` / `lhy:` / `ddi:` appearing beside the first. Two readers
# of one block are self-consistent individually and drift silently — that is the
# exact disease the Model layer was built to delete, and it has already happened
# here repeatedly (linear z-Zeeman once lived in 8 places).
#
# So the gate has three independent arms, because each catches a different way
# of losing the property, and NONE of them can be satisfied by the other two:
#
#   A. STRUCTURAL — `_run_step(::GroundStateStep, …)` lowers to a call to
#      `resolve_gs`. Fails the moment the runner stops consuming it.
#   B. TEXTUAL — `run_step_ground_state.jl` contains no call to any physics
#      parser or builder. Fails the moment a second parser is written back in,
#      even if `resolve_gs` is still called beside it.
#   C. VALUE — both consumers are run for real and checked against the SAME
#      literal numbers. Fails when the resolution moves.
#
# Arm C's pins are LITERAL, never recomputed from the resolver. A gate that
# derives its expectation from the declaration it checks moves both sides
# together and cannot fail; two of that shape's three canaries came back green
# earlier in this campaign.

using Test
using SpinorBEC
using SpinorBEC: resolve_gs, gs_model, yaml_to_model, GSResolved, GroundStateStep,
    _run_step, linear_p, quadratic_q, Model, to_toml

# The step params. Identical physics to `test_yaml_to_model.jl`'s YAML fixture,
# so the two files pin the same numbers from opposite ends of the layer.
rgs_params(; extra...) = begin
    p = Dict{String, Any}(
        "atom" => "Eu151",
        "grid" => Dict{String, Any}("n" => [8, 8, 8], "box" => [6.0, 6.0, 6.0]),
        "interactions" => Dict{String, Any}(
            "N_atoms" => 1000, "omega_ref" => 691.15, "c1_ratio" => -0.01),
        "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0, 1.0, 2.0]),
        "B" => Dict{String, Any}("Bz" => 0.01),
        "ddi" => Dict{String, Any}("secular" => true),
        "method" => "itp",
        "n_steps" => 1,
        "dt" => 0.002,
        "tol" => 1.0e-8,
        "backend" => "cpu",
    )
    for (k, v) in extra
        p[String(k)] = v
    end
    p
end

# PINNED. Read off a run, written here as literals.
const RGS_C0 = 146.47702987921934
const RGS_C1 = -1.4647702987921936
const RGS_CDD = 4.220427701805867
const RGS_P = -147.9552357253949
const RGS_Q = 0.001292251453530959
const RGS_OMEGA = (1.0, 1.0, 2.0)

# Every physics parser / builder. None may be called from the runner file.
const RGS_FORBIDDEN_IN_RUNNER = (
    "_parse_and_build_potential", "_build_potential",
    "_build_zeeman_from_b_block", "_parse_zeeman",
    "_parse_gs_ddi", "_parse_ddi_trunc_radius", "_parse_ddi_pad_factor",
    "_parse_gs_interactions", "_resolve_derived_params!", "_resolve_lhy_block!",
    "_parse_light_shift", "_setup_grid_from_params", "resolve_atom",
    "_resolve_gs_atom", "_resolve_gs_grid", "_resolve_gs_interactions",
    "_resolve_gs_ddi_inheritance", "_resolve_gs_potential",
)

# The subset the resolver calls DIRECTLY. `_parse_ddi_trunc_radius` and
# `_parse_ddi_pad_factor` are deliberately absent: they are reached through
# `_parse_gs_ddi`, one layer down in `schema/parsing_blocks.jl`, and asserting
# them here would be asserting an implementation detail of that function.
const RGS_CALLED_BY_RESOLVER = (
    "_parse_and_build_potential", "_build_zeeman_from_b_block", "_parse_zeeman",
    "_parse_gs_ddi", "_parse_gs_interactions", "_resolve_derived_params!",
    "_parse_light_shift", "_setup_grid_from_params", "resolve_atom",
    "_resolve_gs_atom", "_resolve_gs_grid", "_resolve_gs_interactions",
    "_resolve_gs_ddi_inheritance", "_resolve_gs_potential",
)

"Julia source with whole-line comments removed, so a name mentioned in prose is not read as a call."
rgs_code_only(path) = join(
    [l for l in eachline(path) if !startswith(lstrip(l), "#")], "\n")

"Every `GlobalRef` name reachable in a lowered method body."
function rgs_globals(m::Method)
    out = Set{Symbol}()
    walk(x) =
        if x isa GlobalRef
            push!(out, x.name)
        elseif x isa Expr
            foreach(walk, x.args)
        elseif x isa Core.ReturnNode
            isdefined(x, :val) && walk(x.val)
        elseif x isa Core.GotoIfNot
            walk(x.cond)
        end
    src = Base.uncompressed_ast(m)
    foreach(walk, src.code)
    out
end

"""
Every global named anywhere in `_run_step`'s ground-state chain.

A keyword method lowers to a thin wrapper that forwards to a gensym'd body
function (`#_run_step#1054`), so `methods(_run_step)` alone reaches only the
wrapper — a version of this that stopped there saw a two-element set and would
have reported `resolve_gs` absent whatever the body did. The walk follows the
`#`-prefixed forward, which is where the whole method actually lives.
"""
function rgs_runner_globals()
    out = Set{Symbol}()
    seen = Set{Method}()
    queue = Method[
        m for m in methods(_run_step)
              if endswith(String(m.file), "run_step_ground_state.jl")
    ]
    isempty(queue) && error("no _run_step method is defined in run_step_ground_state.jl")
    while !isempty(queue)
        m = pop!(queue)
        m in seen && continue
        push!(seen, m)
        for s in rgs_globals(m)
            push!(out, s)
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

@testset "resolve_gs is genuinely shared" begin
    runner_file = joinpath(pkgdir(SpinorBEC), "src", "workflow", "experiments",
        "pipeline", "run_step_ground_state.jl")
    resolver_file = joinpath(pkgdir(SpinorBEC), "src", "workflow", "experiments",
        "pipeline", "resolve_gs.jl")

    @testset "A. the runner lowers to a call to resolve_gs" begin
        g = rgs_runner_globals()
        # The positive control: the walk must actually be seeing this method's
        # calls, or "resolve_gs is absent" and "the walk found nothing" are
        # indistinguishable — and the first version of this file measured
        # exactly that, a 2-element set from the keyword wrapper alone.
        @test :make_workspace in g
        @test :find_ground_state in g
        @test :find_ground_state_lbfgs in g
        @test length(g) > 30
        @test :resolve_gs in g
    end

    @testset "B. the runner file parses no physics block" begin
        @test isfile(runner_file)
        @test isfile(resolver_file)
        src = rgs_code_only(runner_file)
        present = [f for f in RGS_FORBIDDEN_IN_RUNNER if occursin(f, src)]
        isempty(present) ||
            println("  physics parsers called from the runner: ", join(present, ", "))
        @test isempty(present)
        # ... and they are in the resolver, so this is a statement about WHERE
        # they live rather than about them having been deleted. Without it,
        # deleting the whole resolution would leave arm B green.
        rsrc = rgs_code_only(resolver_file)
        absent = [f for f in RGS_CALLED_BY_RESOLVER if !occursin(f, rsrc)]
        isempty(absent) || println("  parsers in neither file: ", join(absent, ", "))
        @test isempty(absent)
        # The scanner must be reading CODE, not prose: the runner's header names
        # the resolvers it no longer calls, and a raw `occursin` over the file
        # reported all five of them as present.
        @test occursin("_resolve_gs_atom", read(runner_file, String))
        @test !occursin("_resolve_gs_atom", src)
    end

    @testset "C. both consumers produce the pinned physics" begin
        # --- consumer 1: yaml_to_model, through gs_model ---
        m = gs_model(resolve_gs(rgs_params(), nothing, nothing, nothing; verbose=false))
        @test m isa Model
        @test m.interactions.c0 ≈ RGS_C0 atol = 1e-10
        @test m.interactions.c1 ≈ RGS_C1 atol = 1e-12
        @test m.ddi.c_dd ≈ RGS_CDD atol = 1e-12
        @test m.zeeman.p ≈ RGS_P atol = 1e-9
        @test m.zeeman.q ≈ RGS_Q atol = 1e-15
        @test m.potential.harmonic[1].omega == RGS_OMEGA
        @test m.grid.n_points == (8, 8, 8)
        @test m.ddi.secular == true

        # --- consumer 2: _run_step, observed through the workspace it built ---
        _, grid, atom, ws, _ = _run_step(GroundStateStep(rgs_params()),
            nothing, nothing, nothing, nothing; verbose=false)
        @test ws.interactions.c[0] ≈ RGS_C0 atol = 1e-10
        @test ws.interactions.c[1] ≈ RGS_C1 atol = 1e-12
        @test ws.ddi !== nothing
        @test ws.ddi.C_dd ≈ RGS_CDD atol = 1e-12
        @test linear_p(ws.zeeman) ≈ RGS_P atol = 1e-9
        @test quadratic_q(ws.zeeman) ≈ RGS_Q atol = 1e-15
        @test ws.potential.omega == RGS_OMEGA
        @test grid.config.n_points == (8, 8, 8)
        @test atom.F == 6

        # The two consumers agree on every pin ABOVE against literals, which is
        # what makes this non-circular. This last check is the weaker
        # cross-consumer one, kept because it also covers slots with no pin.
        @test m.grid.box == Float64.(grid.config.box_size)
        @test m.atom.name == atom.name
    end

    @testset "the resolver is idempotent on the params it mutates" begin
        # `_resolve_derived_params!` WRITES `ddi.c_dd`, `interactions.c_lhy`,
        # `lhy_kind` and `lhy_opts` back into `p`. If that were not idempotent,
        # resolving a step twice would produce two models — and therefore two
        # content ids — for one config, which is a store miss nobody would
        # attribute to this.
        p = rgs_params(; lhy=Dict{String, Any}("kind" => "scalar"))
        a = gs_model(resolve_gs(p, nothing, nothing, nothing; verbose=false))
        b = gs_model(resolve_gs(p, nothing, nothing, nothing; verbose=false))
        @test a == b
        @test to_toml(a) == to_toml(b)
    end

    @testset "GSResolved carries every slot gs_model needs" begin
        r = resolve_gs(rgs_params(), nothing, nothing, nothing; verbose=false)
        @test r isa GSResolved
        # The model-only reads really are done in the resolver, not deferred to
        # a second pass over `p`.
        @test r.n_atoms == 1000
        @test r.omega_ref == 691.15
        @test r.dealias_two_thirds isa Bool
        @test r.dealias_k_cut isa Float64
        @test isempty(r.dropped_physics)
        # And the solver-side faces are the ones `make_workspace` takes.
        @test r.enable_ddi == true
        @test r.secular == true
        @test r.ddi_padded == true
        @test r.ddi_trunc == -1.0            # the YAML auto sentinel, unchanged
        @test r.method === :itp
    end
end
