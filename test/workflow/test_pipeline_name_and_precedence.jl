# test/workflow/test_pipeline_name_and_precedence.jl
#
# Two pipeline claims that 64 workflow test files did not cover (mutation
# harness, TSUBAME job 8314739). Neither is arithmetic; both are about WHICH
# code runs, and both produce a complete, plausible run when they are wrong.
#
#   1. a YAML analyzer name must be the real implementation. CLAUDE.md calls
#      aliased dispatch a silent-bug factory: the run succeeds and writes data
#      labelled `phase_classify` that a different analyzer produced.
#
#   2. a ground-state step's OWN `interactions:` block outranks whatever the
#      previous workspace carried. Inverting that precedence is the defect
#      that voided the Matsui Fig. 4B GS-variant arm — a `c1_ratio` written in
#      a `ground_state` step never reached c0, every run completed, and every
#      scan point differed from its neighbours along an axis nobody asked for.
#
# Both are checked without running any physics, which is the point: the claim
# is about routing and precedence, so the cheapest layer that can express it is
# a direct call.

using Test
using SpinorBEC
using SpinorBEC: _run_analyzer, _resolve_gs_interactions, resolve_atom, make_grid,
    GridConfig, init_psi, SpinSystem, InteractionParams

@testset "pipeline: names and precedence" begin
    @testset "an analyzer name dispatches to its own implementation" begin
        grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
        atom = resolve_atom(:Rb87)
        psi = init_psi(grid, SpinSystem(1); state=:polar)

        # `phase_classify` and `phase_classify_distance` are neighbours in the
        # dispatch chain and both are real analyzers, so a mis-route produces a
        # valid result under the wrong name. They are distinguished by their
        # RESULT SHAPE, not by whether they throw.
        a = _run_analyzer(:phase_classify, psi, grid, atom, Dict{Any, Any}())
        b = _run_analyzer(:phase_classify_distance, psi, grid, atom, Dict{Any, Any}())
        @test a isa NamedTuple
        @test b isa NamedTuple

        # `phase_classify_distance` returns a SUPERSET of `phase_classify`'s
        # fields — same classification plus the distance and the ranking. So
        # "not the same analyzer" has to be said in terms of the fields only
        # the second one has; a mis-route puts them on the first.
        for k in (:phase_distance, :distance, :ranking)
            @test k ∈ keys(b)
            @test k ∉ keys(a)
        end

        # And an unknown name must not quietly resolve to anything at all.
        @test_throws Exception _run_analyzer(
            :not_an_analyzer, psi, grid, atom, Dict{Any, Any}())
    end

    @testset "a step's own interactions: outrank the inherited ones" begin
        atom = resolve_atom(:Rb87)
        # A workspace-like carrier is all `_resolve_gs_interactions` reads.
        prev = (interactions=InteractionParams(Dict(0 => 111.0, 1 => -1.0)),)
        own = Dict{String, Any}("interactions" => Dict{String, Any}("c0" => 222.0,
            "c1" => -2.0))

        # 1. explicit block present AND a previous workspace: the block wins.
        got = _resolve_gs_interactions(own, prev, atom)
        @test got[0] ≈ 222.0
        @test got[0] != prev.interactions[0]        # the inherited value, named

        # 2. no block: inherit. This is the row that makes (1) meaningful —
        # without it, (1) could pass because inheritance never happens.
        @test _resolve_gs_interactions(Dict{String, Any}(), prev, atom)[0] ≈ 111.0

        # 3. neither: defaults, and no exception.
        @test _resolve_gs_interactions(
            Dict{String, Any}(), nothing, atom) isa InteractionParams
    end
end
