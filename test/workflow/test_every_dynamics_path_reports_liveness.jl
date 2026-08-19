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
const _NO_LIVENESS = Dict{String, String}(
# EMPTY as of 2026-08-07: all three dynamics paths report liveness. It was
# {BinaryDynamicsStep, RotatingBasisDynamicsStep} for one day, which is how long
# it took to notice that "declared" is a record of a gap, not a fix.
)

"Every `step isa XDynamicsStep` branch in the dispatcher, and whether it is handed `live_status_path`."
function dynamics_branches()
    src = read(_RUNNER, String)
    # Scope to `_step_dispatch!`. `runner.jl` has a SECOND if-chain over the same
    # step types further down, for results collection, and it has no business
    # carrying `live_status_path` — reading the whole file attributed that branch
    # to the same kind and reported a wired path as unwired. Narrowing the
    # extraction is the fix; loosening the assertion would have hidden a real
    # gap the next time.
    i = findfirst("function _step_dispatch!", src)
    i === nothing && return Dict{String, Bool}()
    tail = src[first(i):end]
    j = findfirst("\nend\n", tail)
    body = j === nothing ? tail : tail[1:first(j)]

    out = Dict{String, Bool}()
    for p in split(body, r"elseif step isa ")
        m = match(r"^([A-Za-z]*DynamicsStep)\b", p)
        m === nothing && continue
        branch = first(split(p, r"\n\s*elseif|\n\s*else\b"))
        # A DISPATCH branch is one that calls `_run_step`. `_step_dispatch!`
        # also carries a results-collection chain over the same step types, and
        # that one has no business passing `live_status_path` — counting it made
        # a wired path report as unwired. The discriminator is what the branch
        # DOES, not where it sits.
        occursin("_run_step(", branch) || continue
        out[m.captures[1]] = occursin("live_status_path", branch)
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
        # Every path reports, so each of these is `true` — if one were false the
        # extractor is broken, not the code.
        @test all(values(branches))

        # And the extractor must still be ABLE to say "no". This was asserted
        # against the real tree (`!all(values(branches))`) while two paths were
        # unwired, and wiring them killed it: **a calibration that depends on the
        # defect existing dies when you fix the defect.** Prove it on a synthetic
        # branch instead, which stays true either way.
        synthetic = """
            elseif step isa FakeWiredDynamicsStep
                _run_step(step, psi; verbose, live_status_path)
            elseif step isa FakeBareDynamicsStep
                _run_step(step, psi; verbose)
            end
            """
        probe = Dict{String, Bool}()
        for p in split(synthetic, r"elseif step isa ")
            m = match(r"^([A-Za-z]*DynamicsStep)\b", p)
            m === nothing && continue
            br = first(split(p, r"\n\s*elseif|\n\s*else\b"))
            occursin("_run_step(", br) || continue
            probe[m.captures[1]] = occursin("live_status_path", br)
        end
        @test probe["FakeWiredDynamicsStep"]
        @test !probe["FakeBareDynamicsStep"]
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
        # It is empty now. The bound stays as a ratchet: a future path may be
        # added here deliberately, but not three of them silently.
        @test length(_NO_LIVENESS) <= 1
        @test all(!isempty, values(_NO_LIVENESS))
        # every listed kind must still BE a branch — a stale entry would let a
        # newly-wired path look exempt
        for k in keys(_NO_LIVENESS)
            @test haskey(branches, k)
            @test !branches[k]
        end
    end
end
