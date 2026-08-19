using Test
# This file needs nothing from the package — it is a regex over source text —
# but `test_tier_membership.jl` requires the plain form in every test file, and
# it is right to: a file that runs only because a sibling happened to load the
# package first is order-dependent, and which files work standalone then depends
# on what the claim queue handed out first. In-suite the load is already paid.
using SpinorBEC

include(joinpath(@__DIR__, "catalog.jl"))

# Every mutant's anchor matches its file exactly once.
#
# WHY THIS IS A PER-PR GATE AND NOT PART OF THE NIGHTLY
#
# `check_anchors` already existed, and the catalog's docstring already promised
# that a refactor moving a site "must surface here, not as a mutant that quietly
# tests nothing". It was called from exactly one place: `test/mutation/run.jl`,
# the hour-scale nightly harness — which, per `fix(nightly): the mutation job
# timed out every night and produced nothing (#275)`, was producing nothing.
#
# Result, measured 2026-08-19: THREE mutants had rotted and no one had been
# told. One had merely moved file (`resolve_gs.jl`) and was repaired; two
# targeted `_gs_cache_key`, deleted in the `artifact_id(::Stage)` cutover, and
# were retired with a pointer to the stronger gate that replaced them.
#
# The scan is a regex over ~40 files and takes milliseconds. Putting the
# self-check of an instrument behind the expensive run of that instrument is
# the same mistake as a monitor that only reports when the job succeeds: the
# case you need it for is the case where it does not run.

@testset "mutation catalog anchors resolve" begin
    root = normpath(joinpath(@__DIR__, "..", ".."))

    @testset "the catalog is non-empty and reaches src/" begin
        @test !isempty(MUTANTS)
        @test all(m -> startswith(m.file, "src/"), MUTANTS)
        @test allunique([m.id for m in MUTANTS])
    end

    @testset "check_anchors can actually fail" begin
        # Negative control. Without this, a `check_anchors` that returned an
        # empty vector unconditionally — because it silently swallowed a missing
        # file, say — would read exactly like a clean catalog.
        bogus = Mutant(:_canary, "src/foundation/wick.jl",
            r"this string is not in any source file", "x",
            :sign, :subtle, "canary", "canary")
        saved = copy(MUTANTS)
        try
            push!(MUTANTS, bogus)
            @test any(t -> t[1].id === :_canary, check_anchors(root))
        finally
            empty!(MUTANTS)
            append!(MUTANTS, saved)
        end
    end

    @testset "no stale anchors" begin
        stale = check_anchors(root)
        for (m, n) in stale
            @info "STALE mutant — matched $(n) times, must be exactly 1" id=m.id file=m.file
        end
        @test isempty(stale)
    end

    # The vocabulary is READ OFF the catalog, not restated here. The struct
    # docstring lists four classes and three severities; the catalog actually
    # uses six and four (`:missing_gate`, `:off_by_one`, `:major` grew in
    # without the comment following). Hard-coding the docstring's list would
    # have made this gate red on 17 correct entries — which is the same "a
    # prose copy of a fact" defect one level up, in the test that exists to
    # catch it.
    @testset "class and severity vocabularies stay small" begin
        classes = unique(m.class for m in MUTANTS)
        severities = unique(m.severity for m in MUTANTS)
        # A typo'd class would show up as a singleton bucket; the bound is what
        # makes that visible without pinning the exact set.
        @test length(classes) <= 8
        @test length(severities) <= 5
        @test :sign in classes
        @test :fatal in severities
    end

    @testset "every mutant carries a reason" begin
        for m in MUTANTS
            @test !isempty(strip(m.incident))
            @test !isempty(strip(m.note))
        end
    end
end
