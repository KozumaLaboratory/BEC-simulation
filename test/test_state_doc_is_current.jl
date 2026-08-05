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
