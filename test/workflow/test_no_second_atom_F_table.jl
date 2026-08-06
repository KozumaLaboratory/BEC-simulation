using Test
using SpinorBEC
using SpinorBEC: ATOM_REGISTRY

include(joinpath(@__DIR__, "..", "helpers", "calibrated_scan.jl"))

# `ATOM_REGISTRY` is the ONE declaration of F per species. No other file may
# carry its own atom→F map.
#
# Two were found on 2026-08-06, both feeding resource estimates:
#
#   autopilot/profile_recommend.jl   7 of 23 atoms, `Cs133` wrong in-table,
#                                    fallback F=1 → UNDER-sized up to 5.67x
#                                    → OOM on TSUBAME → :killed_bug → retry
#                                    escalates → the queue is paid for twice
#   io/budget.jl                     5 of 23 atoms, fallback F=6 → wrong for
#                                    15 of 23: Ca40/Sr/Yb (F=0) sized 13x too
#                                    LARGE, Dy162 (F=8) 1.31x too small
#
# Finding the second one hours after fixing the first is the argument for a gate
# over a fix: the same table can be written again in a third file tomorrow, and
# nothing would notice until a job died.
#
# This is deliberately a search over the tree rather than a check of two known
# files — the failure being prevented is a NEW copy, and a two-file check cannot
# see one.

const _SRC = normpath(joinpath(@__DIR__, "..", "..", "src"))

"""
Files declaring a literal map from an atom name to a small integer.

Matched as an atom-like string key (`Xx123`) pointing at a bare integer, at
least three in one file — two could be an unrelated pair, and requiring three
keeps the rule from firing on, say, a mass table with two entries. The
registry's own file is exempt: it IS the declaration.
"""
function atom_int_maps()
    pat = r"\"[A-Z][a-z]?[0-9]{1,3}(?:star)?\"\s*=>\s*[0-9]+"
    hits = Tuple{String, Int}[]
    for (root, _, files) in walkdir(_SRC)
        for f in files
            endswith(f, ".jl") || continue
            path = joinpath(root, f)
            rel = relpath(path, dirname(_SRC))
            occursin("initialization/atoms.jl", rel) && continue   # the registry itself
            # Count MATCHES, not lines. A first version counted lines and its
            # own canary walked straight through it: the planted table was
            # `Dict("Na23" => 1, "Rb87" => 1, "Eu151" => 6)` on ONE line, which
            # is 1 line and 3 pairs. Canarying is what caught it — the gate had
            # looked correct and passed on the real tree.
            n = sum(
                length(collect(eachmatch(pat, l)))
                for l in readlines(path) if !startswith(strip(l), "#"); init=0)
            n >= 3 && push!(hits, (rel, n))
        end
    end
    hits
end

@testset "no second atom→F table" begin
    # CALIBRATION. A pattern that matches nothing reports a clean tree in the
    # same words a clean tree uses. Prove it fires on the shape it is looking
    # for before believing an empty result.
    @testset "the pattern recognises the shape" begin
        probe = """
            const F_map = Dict("Na23" => 1, "Rb87" => 1, "Cr52" => 3,
                               "Dy164" => 8, "Eu151" => 6)
            """
        pat = r"\"[A-Z][a-z]?[0-9]{1,3}(?:star)?\"\s*=>\s*[0-9]+"
        @test count_matches(pat, split(probe, '\n')) >= 5
        # three pairs on ONE line must count as three — the canary's blind spot
        one_line = "const T = Dict(\"Na23\" => 1, \"Rb87\" => 1, \"Eu151\" => 6)"
        @test count_matches(pat, one_line) == 3
        # and the registry is big enough for a copy of it to be wrong about
        @test length(ATOM_REGISTRY) >= 20
    end

    @testset "no file outside the registry carries one" begin
        hits = atom_int_maps()
        if !isempty(hits)
            println("\nFiles with a literal atom→integer map beside ATOM_REGISTRY:")
            for (f, n) in hits
                println("  $f  ($n lines)")
            end
            println("\nATOM_REGISTRY is the one declaration of F per species. Two such")
            println("tables were found on 2026-08-06, both feeding resource estimates,")
            println("and both were wrong — one under-sized VRAM by up to 5.67x, which")
            println("OOMs on TSUBAME and is then paid for twice through retry")
            println("escalation.")
        end
        @test isempty(hits)
    end

    # Both consumers, by name, so a revert is loud.
    @testset "the two known consumers read the registry" begin
        for f in ("workflow/autopilot/profile_recommend.jl", "workflow/io/budget.jl")
            src = read(joinpath(_SRC, f), String)
            @test occursin("ATOM_REGISTRY", src)
        end
    end
end
