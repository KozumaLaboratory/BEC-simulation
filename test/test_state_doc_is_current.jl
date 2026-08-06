using Test
using SpinorBEC

# `docs/STATE.md` is DERIVED from the code. This asserts the committed copy still
# matches what the code says today.
#
# The point is not tidiness. In AI-assisted development every session writes a
# delta and none integrates, so after a few hundred deltas nothing states the
# present — and the tree proved it: `CLAUDE.md`'s split-step operator list said
# five, was corrected to seven, and the true number is nine. Two sessions each
# appended to a hand-copied list, and each was right about its own delta.
#
# A generated state document breaks that loop only if drift is a FAILURE rather
# than something a later reader discovers by being misled. That is this file.
#
# The generator is `scripts/generate_state.jl`; regenerate with
#     julia --project=. scripts/generate_state.jl

const GEN = normpath(joinpath(@__DIR__, "..", "scripts", "generate_state.jl"))
const STATE = normpath(joinpath(@__DIR__, "..", "docs", "STATE.md"))

# The generator guards its own `main()` on PROGRAM_FILE, so including it here
# defines `render()` without writing anything.
module StateGen
include(normpath(joinpath(@__DIR__, "..", "scripts", "generate_state.jl")))
end

@testset "docs/STATE.md is current" begin
    @testset "the generator and its output both exist" begin
        @test isfile(GEN)
        @test isfile(STATE)
        @test isdefined(StateGen, :render)
    end

    derived = StateGen.render()

    # CALIBRATION. A renderer that returns "" or a stub would make the comparison
    # below pass for an empty committed file, and an empty file is exactly what a
    # broken generator produces. Assert the derivation actually derived something
    # before comparing, and assert the facts that were WRONG in prose are present
    # — otherwise this gate could go green while covering nothing.
    @testset "the derivation produced real content" begin
        @test length(derived) > 3000
        @test occursin("## Split-step", derived)
        @test occursin("## Hamiltonian terms in the registry", derived)
        # the nine substeps, which prose got wrong twice
        for op in ("diagonal", "spin_mixing", "spatial_lhy_spin", "singlet_pair",
            "tensor", "transverse_zeeman", "spatial_zeeman", "raman")
            @test occursin("`$op`", derived)
        end
        # all fourteen registry terms, by their real struct names
        for t in ("KineticTerm", "ZeemanTerm", "DDITerm", "LHYTerm", "TensorTerm",
            "SpatialZeemanTerm", "LossTerm")
            @test occursin(t, derived)
        end
        @test !occursin("(struct not found)", derived)
        @test !occursin("NOT FOUND anywhere under test/", derived)
        # The gaps must stay visible. A generated document whose coverage list
        # vanished would read as complete, which is the failure the staleness
        # comparison cannot see: committed == derived is satisfied by two copies
        # that have BOTH narrowed.
        # The B → p section must state the PROPERTY, not enumerate sites. A
        # derived list cannot rot but only describes; the gate refuses.
        @test occursin("Declared **once**", derived)
        @test occursin("test_bfield_sign_declared_once.jl", derived)
        # the two sections whose value is an equality / a disagreement, not a list
        @test occursin("## `src/solvers/` — what is actually there", derived)
        # the two omissions that proved both hand-written restatements wrong
        @test occursin("evaporation/", derived)
        @test occursin("trapped_bdg.jl", derived)
        @test occursin("## Ground-state exit contract", derived)
        # the rendered criterion must BE the code's condition
        @test occursin("dE < tol", derived)
        # and `dpsi` must be absent from it — the derived form of "diagnostic only"
        @test !occursin("dpsi <", derived)
        @test occursin("## Cache admission", derived)
        # the RATIO is the fact; a list of sites without it says nothing
        @test occursin(r"\*\*\d+ sites admit a cached payload; \d+ re-derives", derived)
        # a comment mentioning the call must not be counted as a call site
        @test !occursin("run_registry.jl:1002", derived)
        @test occursin("## Artifact identity", derived)
        @test occursin("`fieldnames(Stage)` plus `code_rev`", derived)
        @test occursin("## Ground-state knob defaults", derived)
        @test occursin("`m_lbfgs` is the live trap", derived)
        @test occursin("## What this document does NOT cover", derived)
        @test occursin("| subtree | files cited | of |", derived)
        # per-FILE, not per-subtree: a boolean would read as full coverage
        # from a single citation
        @test occursin(r"\| `src/\w+/` \| \d+ \| \d+ \|", derived)
    end

    committed = read(STATE, String)
    if committed != derived
        # Name WHAT moved. "run the generator" alone sends the next reader to a
        # 200-line diff; the first differing line is usually the whole answer.
        a, b = split(committed, '\n'), split(derived, '\n')
        for i in 1:max(length(a), length(b))
            x = i <= length(a) ? a[i] : "<eof>"
            y = i <= length(b) ? b[i] : "<eof>"
            if x != y
                println("\ndocs/STATE.md is stale — first difference at line $i:")
                println("  committed: ", x)
                println("  derived  : ", y)
                println("\nRegenerate: julia --project=. scripts/generate_state.jl")
                break
            end
        end
    end
    # A Bool, not the two strings: `@test a == b` on 6 kB of markdown dumps both
    # copies into the failure and buries the first-difference report above, which
    # is the part that says what moved.
    matches = committed == derived
    @test matches
end
