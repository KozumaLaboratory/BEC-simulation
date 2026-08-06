using Test
using SpinorBEC

include(joinpath(@__DIR__, "..", "helpers", "calibrated_scan.jl"))

# Which dynamics paths report liveness, and which do not — declared, not
# discovered.
#
# The autopilot's divergence kill reads `_live_status.json`: the reaper watches
# it, cancels a diverging run and files it `:killed_data`. On 2026-08-04 that
# mechanism was found never to have fired at all, because the writer and the
# reader shared no keys. That was fixed — **for one of three dynamics paths.**
#
# `_step_dispatch!` (`pipeline/runner.jl`) passes `live_status_path` to
# `DynamicsStep` and to nothing else. `BinaryDynamicsStep` and
# `RotatingBasisDynamicsStep` never receive it, so they write no status file, so
# a run on either path that blows up runs to completion and bills for it. On
# TSUBAME that is the whole allocation for a job whose answer is NaN.
#
# Wiring the callback into both handlers is a real change in three files — the
# binary path goes through a different solver entirely — and a half-wired
# monitor is worse than none, because it looks present. So this file does the
# thing that is correct today: it makes the gap DECLARED. A new dynamics step
# kind must either report liveness or be added to `_NO_LIVENESS` on purpose,
# with a reason. An invisible gap reads as coverage; a listed one is a decision.

const _RUNNER = normpath(
    joinpath(@__DIR__, "..", "..", "src", "workflow",
        "experiments", "pipeline", "runner.jl"),
)

# Step kinds that do NOT report liveness, and why. Shrinking this list is the
# fix; growing it silently is the regression.
const _NO_LIVENESS = Dict(
    "BinaryDynamicsStep" =>
        "goes through `_run_binary_dynamics_step`, a separate solver path with " *
        "its own callback assembly; never received `live_status_path`",
    "RotatingBasisDynamicsStep" =>
        "dispatches through `run_step_rotating/dispatch.jl`; never received " *
        "`live_status_path`",
)

"Every `step isa XDynamicsStep` branch in the dispatcher, and whether it is handed `live_status_path`."
function dynamics_branches()
    src = read(_RUNNER, String)
    out = Dict{String, Bool}()
    # split on the branch heads so each body is attributed to its own kind
    parts = split(src, r"elseif step isa ")
    for p in parts
        m = match(r"^([A-Za-z]*DynamicsStep)\b", p)
        m === nothing && continue
        body = first(split(p, r"\n\s*elseif|\n\s*else\b"))
        out[m.captures[1]] = occursin("live_status_path", body)
    end
    out
end

@testset "every dynamics path's liveness reporting is declared" begin
    branches = dynamics_branches()

    # CALIBRATION. An extractor that finds no branches makes every assertion
    # below vacuous, and an extractor that marks everything `true` would hide
    # exactly the gap this file exists for. Pin both.
    @testset "the dispatcher is being read" begin
        @test length(branches) >= 3
        @test haskey(branches, "DynamicsStep")
        @test haskey(branches, "BinaryDynamicsStep")
        @test haskey(branches, "RotatingBasisDynamicsStep")
        # the one that DOES report — if this were false the extractor is broken,
        # not the code
        @test branches["DynamicsStep"]
        # and the extractor must be able to say "no"
        @test !all(values(branches))
    end

    @testset "no path is silently without liveness" begin
        undeclared = [k for (k, wired) in branches
                            if !wired && !haskey(_NO_LIVENESS, k)]
        if !isempty(undeclared)
            println("\nDynamics step kinds that write no `_live_status.json` and are")
            println("not declared in `_NO_LIVENESS`:")
            foreach(k -> println("  ", k), undeclared)
            println("\nThe autopilot's divergence kill reads that file. A path without")
            println("it runs a diverging job to completion and bills for it. Wire the")
            println("callback, or add the kind to `_NO_LIVENESS` with a reason.")
        end
        @test isempty(undeclared)
    end

    # The list must shrink, never quietly grow into a description of everything.
    @testset "the exception list is an exception" begin
        @test length(_NO_LIVENESS) <= 2
        @test all(!isempty, values(_NO_LIVENESS))
        # every listed kind must still BE a branch — a stale entry would let a
        # newly-wired path look exempt
        for k in keys(_NO_LIVENESS)
            @test haskey(branches, k)
            @test !branches[k]
        end
    end
end
