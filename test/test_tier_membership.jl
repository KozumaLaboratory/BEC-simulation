# Meta-test: tier membership is total and exact.
#
# CLAUDE.md commitment #7: "Tier membership is explicit in
# test/runtests.jl — every test belongs to exactly one list. New tests
# get added to a list, not auto-discovered." Historically this drifted:
# files landed under test/ without ever being added to a tier, so they
# silently never ran (the 2026-05-25 orphan audit found 28; a later one
# found 6 more that had fallen through). This meta-test makes that drift
# impossible to commit unnoticed.
#
# It asserts, over every `test_*.jl` file discoverable under test/:
#   1. NO ORPHANS  — each file is in exactly one tier list
#      (FAST/CI/FULL/PHYSICS) OR the documented MANUAL allowlist.
#   2. NO DANGLING — every path listed in a tier / the allowlist exists
#      on disk.
#   3. NO DOUBLE-LISTING across the run-tiers (FAST/CI/FULL) — a file in
#      two run-tiers would execute twice (PHYSICS is a deliberate
#      re-selection for the physics-only tier, so it is exempt from this
#      check).
#
# Runs as a pure file-glob + set comparison (no SpinorBEC needed); lives
# in FAST so every push enforces it. The tier-list constants and
# MANUAL_TESTS_ALLOWLIST are defined in runtests.jl, which include()s
# this file in global scope.

using Test

@testset "Tier membership is total and exact" begin
    test_root = @__DIR__

    # Discover every test_*.jl under test/, as paths relative to test/.
    discovered = Set{String}()
    for (root, _dirs, files) in walkdir(test_root)
        for fn in files
            (startswith(fn, "test_") && endswith(fn, ".jl")) || continue
            rel = relpath(joinpath(root, fn), test_root)
            push!(discovered, replace(rel, '\\' => '/'))
        end
    end

    run_tiers = (FAST_TESTS, CI_EXTRA, FULL_EXTRA)
    listed = Set{String}()
    for tier in run_tiers
        union!(listed, tier)
    end
    # PHYSICS_TESTS + MANUAL allowlist also "account for" a file.
    accounted = union(listed, Set(PHYSICS_TESTS), Set(MANUAL_TESTS_ALLOWLIST))

    # 1. No orphans.
    orphans = sort(collect(setdiff(discovered, accounted)))
    @test isempty(orphans)
    isempty(orphans) ||
        @info "ORPHAN test files — add to a tier list in runtests.jl or to MANUAL_TESTS_ALLOWLIST" orphans

    # 2. No dangling references.
    dangling = sort(collect(setdiff(accounted, discovered)))
    @test isempty(dangling)
    isempty(dangling) ||
        @info "DANGLING test paths — listed but absent on disk" dangling

    # 3. No file in more than one run-tier (would execute twice).
    seen = Dict{String,Int}()
    for tier in run_tiers, f in tier
        seen[f] = get(seen, f, 0) + 1
    end
    double_listed = sort([f for (f, n) in seen if n > 1])
    @test isempty(double_listed)
    isempty(double_listed) ||
        @info "DOUBLE-LISTED across FAST/CI/FULL — would run twice" double_listed
end
