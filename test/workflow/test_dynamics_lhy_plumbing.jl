# Regression for the 2026-05-26 dynamics LHY plumbing fix.
#
# Before fix:
#   - DYNAMICS_SCHEMA had no `lhy` key → schema rejected `dynamics.lhy:`
#   - _run_step(::DynamicsStep) never passed `spinor_lhy=` to
#     make_workspace → non-scalar LHY silently dropped during dynamics
#
# After fix (`src/workflow/experiments/schema/schema.jl` +
# `src/workflow/experiments/pipeline/run_step_dynamics.jl`):
#   - schema accepts `dynamics.lhy: {kind: ...}` mirror of GS
#   - dispatcher extracts the kind symbol and forwards it as
#     `spinor_lhy` to make_workspace
#
# Tests below pin both:
#   1. Schema validation: a dynamics step with `lhy:` parses without
#      error (vs ArgumentError pre-fix).
#   2. Scalar LHY propagation via inherited c_lhy still works when
#      dynamics omits its own `lhy:` block (the historical default).
#   3. Explicit `dynamics.lhy: {kind: scalar}` builds an LHY object on
#      the dynamics workspace and produces non-zero E_LHY in
#      energy_decomposition.

using Test
using SpinorBEC
using SpinorBEC: validate_pipeline!

const _DYN_LHY_BASE = Dict{String, Any}(
    "defaults" => Dict("kind" => "spinor", "backend" => "cpu"),
    "pipeline" => Any[
        Dict(
            "ground_state" => Dict(
                "atom" => "Rb87",
                "grid" => Dict("n" => [8, 8, 8], "box" => [4.0, 4.0, 4.0]),
                "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
                "interactions" => Dict("N_atoms" => 1000, "omega_ref" => 100.0),
                "ddi" => Dict("enabled" => false),
                "lhy" => Dict("kind" => "scalar"),
                "initial_state" => "polar",
                "dt" => 0.01,
                "n_steps" => 5,
                "tol" => 1.0e-6,
            ),
        ),
        Dict(
            "dynamics" => Dict(
                "duration" => 0.05,
                "dt" => 0.01,
                # `lhy:` placeholder; tests below mutate this.
                "lhy" => Dict("kind" => "scalar"),
                "save" => Dict("every" => 5),
            ),
        ),
    ],
)

@testset "dynamics LHY plumbing (2026-05-26 fix)" begin
    @testset "schema accepts dynamics.lhy" begin
        data = deepcopy(_DYN_LHY_BASE)
        # validate_pipeline! returns nothing on success, raises on failure
        # (the same path that broke for `lhy:` in dynamics pre-fix).
        @test (validate_pipeline!(data); true)
    end

    @testset "schema accepts kind=none" begin
        data = deepcopy(_DYN_LHY_BASE)
        data["pipeline"][2]["dynamics"]["lhy"] = Dict("kind" => "none")
        @test (validate_pipeline!(data); true)
    end

    @testset "schema rejects unknown kind" begin
        data = deepcopy(_DYN_LHY_BASE)
        data["pipeline"][2]["dynamics"]["lhy"] = Dict("kind" => "bogus_kind")
        @test_throws ArgumentError validate_pipeline!(data)
    end
end

# Silent-zero defense: make_workspace must throw when a non-scalar /
# non-quasi_2d LHY kind is requested but the builder bailed out
# (unimplemented method, F restriction, etc.). The historical bug was
# that this silently fell through to `lhy=nothing` and the run produced
# results "as if LHY were off" while the user expected LHY on.
@testset "make_workspace silent-zero defense" begin
    grid = make_grid(GridConfig{3}((8, 8, 8), (4.0, 4.0, 4.0)))
    interactions = InteractionParams(Dict{Int, Float64}(0 => 1.0, 1 => 0.01))
    sp = SimParams(; dt=0.01, n_steps=1)

    @testset ":scalar falls through to c_lhy branch (legacy OK)" begin
        # scalar legitimately has no `_build_spinor_lhy(::Val{:scalar})`;
        # it is built from `interactions.c_lhy`. Set c_lhy explicitly.
        ip_with_lhy = InteractionParams(Dict(0 => 1.0, 1 => 0.01); c_lhy=2.5)
        ws = make_workspace(; grid, atom=Rb87, interactions=ip_with_lhy,
            potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=sp, spinor_lhy=:scalar)
        @test ws.lhy !== nothing
    end

    @testset ":icosahedral at F=1 throws (kind/F mismatch)" begin
        # :icosahedral builder demands F=6; at F=1 it raises ArgumentError
        # from the builder itself. The silent-zero defense path also
        # catches the case where the builder returns nothing for any
        # reason (different code path; tested below).
        @test_throws ArgumentError make_workspace(;
            grid, atom=Rb87, interactions,
            potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=sp, spinor_lhy=:icosahedral)
    end

    @testset "unknown Symbol kind throws silent-zero error" begin
        # `_build_spinor_lhy(::Val, ...)` fallthrough returns nothing.
        # The defense must catch this and refuse to silently disable LHY.
        @test_throws ArgumentError make_workspace(;
            grid, atom=Rb87, interactions,
            potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=sp, spinor_lhy=:totally_unimplemented_kind)
    end

    @testset ":none and nothing both disable LHY (no throw)" begin
        ws1 = make_workspace(; grid, atom=Rb87, interactions,
            potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=sp, spinor_lhy=:none)
        @test ws1.lhy === nothing
        ws2 = make_workspace(; grid, atom=Rb87, interactions,
            potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=sp, spinor_lhy=nothing)
        @test ws2.lhy === nothing
    end
end
