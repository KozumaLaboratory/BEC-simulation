using Test
using SpinorBEC

include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

# The instrument that exists so instruments stop breaking silently must itself
# be shown to break loudly. Every arm below is one of the nine real failures
# from 2026-08-05/06, reproduced against this helper.

@testset "calibrated_scan refuses a blind scan" begin
    @testset "a predicate that matches nothing is refused, not returned as 0" begin
        # The `--no-ext-diff`, `occursin(f)` and `r.warnings` failures: the scan
        # ran, saw nothing, and the caller read zero as a clean result.
        blind = _ -> false
        @test_throws BlindScan calibrated_scan(["a", "b"];
            match=blind, present="a", absent="zzz")
        e = try
            calibrated_scan(["a"]; match=blind, present="a", absent="zzz")
        catch err
            err
        end
        @test e isa BlindScan
        @test e.which === :present
        @test occursin("positive control", sprint(showerror, e))
    end

    @testset "a predicate that matches everything is refused too" begin
        # The analyzer-name gate's first version: it flagged parameter names and
        # enum values, so a non-zero result was not evidence either.
        wide = _ -> true
        e = try
            calibrated_scan(["a"]; match=wide, present="a", absent="zzz")
        catch err
            err
        end
        @test e isa BlindScan
        @test e.which === :absent
        @test occursin("Narrow the predicate", sprint(showerror, e))
    end

    @testset "a working scan returns its hits" begin
        corpus = ["alpha", "beta", "gamma"]
        hits = calibrated_scan(corpus;
            match=x -> startswith(x, "a"), present="alpha", absent="beta")
        @test hits == ["alpha"]
    end

    # The probes must be able to FAIL. A positive control chosen for convenience
    # (one the predicate matches by construction) proves nothing — this is the
    # degenerate-knob trap, twice in this project's history.
    @testset "the probes are load-bearing, not decoration" begin
        # if `present` were ignored, this would return [] instead of throwing
        @test_throws BlindScan calibrated_scan(String[];
            match=x -> false, present="x", absent="y")
        # if `absent` were ignored, this would return the corpus
        @test_throws BlindScan calibrated_scan(["p", "q"];
            match=x -> true, present="p", absent="q")
    end
end

@testset "count_matches counts matches, not lines" begin
    # The no-second-atom-table gate walked past its own canary because the
    # planted defect was three pairs on ONE line.
    one_line = """const T = Dict("Na23" => 1, "Rb87" => 1, "Eu151" => 6)"""
    pat = r"\"[A-Z][a-z]?[0-9]{1,3}\"\s*=>\s*[0-9]+"
    @test count_matches(pat, one_line) == 3
    @test count(l -> occursin(pat, l), [one_line]) == 1     # the wrong way, pinned
    @test count_matches(pat, [one_line, one_line]) == 6
    @test count_matches(pat, String[]) == 0
end

@testset "tree_files is one definition of scope" begin
    root = normpath(joinpath(@__DIR__, "..", "src"))
    files = tree_files(root)
    # Population floor: a walk that returns nothing makes every "not found"
    # vacuous, which is exactly how two scans reported absences this session.
    @test length(files) >= 300
    @test all(f -> endswith(f, ".jl"), files)
    @test any(f -> occursin("hamiltonian", f), files)
    @test !any(f -> occursin(".git", f), files)
    # relative to the parent, so paths read like `src/...` and compare against
    # what documents actually cite
    @test all(f -> startswith(f, "src/"), files)
    # and it sees the directories a hand-written regex forgot
    figs = normpath(joinpath(@__DIR__, "..", "figs"))
    if isdir(figs)
        @test !isempty(tree_files(figs; ext=".png"))
    end
end
