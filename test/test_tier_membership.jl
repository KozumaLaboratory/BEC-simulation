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
# It also holds the other two harness-contract gates: the parallel-balance
# cost model, and the export-shadowing check that the shared worker process
# makes load-bearing (see that testset).
#
# Mostly file-glob + set comparison; lives in FAST so every push enforces it.
# The tier-list constants, MANUAL_TESTS_ALLOWLIST and the _COST balance model
# are defined in _tiers.jl, include()d in global scope before this file runs.

using Test
using SpinorBEC

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
    seen = Dict{String, Int}()
    for tier in run_tiers, f in tier
        seen[f] = get(seen, f, 0) + 1
    end
    double_listed = sort([f for (f, n) in seen if n > 1])
    @test isempty(double_listed)
    isempty(double_listed) ||
        @info "DOUBLE-LISTED across FAST/CI/FULL — would run twice" double_listed
end

# The parallel-balance cost model + its degradation guard. Pinned here so the
# guard that keeps CI wall-time honest cannot itself silently break.
@testset "Cost model + drift guard" begin
    # Every _COST key must reference a real, accounted-for test file — a stale
    # key (renamed/deleted file) silently stops weighting anything.
    test_root = @__DIR__
    for f in keys(_COST)
        @test isfile(joinpath(test_root, f))
    end

    @test _cost("test_dealias_2_3.jl") == _COST["test_dealias_2_3.jl"]
    @test _cost("file_with_no_entry.jl") == _DEFAULT_COST

    # Drift guard: flag a gross under-estimate, ignore near-estimate and sub-floor.
    stale = warn_cost_drift([
        ("solvers/test_3d.jl", 60.0),   # 60s vs 5s estimate → stale
        ("test_quality.jl", 42.0),      # 42s vs 40s estimate → within factor
        ("tiny.jl", 4.0),               # below floor_s → ignored
    ])
    @test length(stale) == 1
    @test stale[1].file == "solvers/test_3d.jl"
end

# Test files share a worker process (SPINORBEC_TEST_WORKERS > 1) and which files
# land together is decided at run time by the claim queue, so a top-level name
# in one file is visible to every file that runs after it in that process. If
# that name is also a SpinorBEC export, the local definition wins in `Main` and
# the package's binding is shadowed — silently, and only for whichever files
# happened to share the process. That is how `result isa CheckResult` evaluated
# false in workflow/validation/test_specs_and_check.jl: L5's own
# `struct CheckResult` (now `L5TermCheck`) had run first.
@testset "No test file shadows a SpinorBEC export" begin
    exported = Set(String.(names(SpinorBEC)))
    # `function` is in the list because leaving it out is what let
    # `run_chunk.jl:40`'s `claim` sit here undetected: that file does
    # `using SpinorBEC` and then defines `claim` at top level, so `Main.claim`
    # shadowed `SpinorBEC.claim` for every test file the chunk process included.
    # `validation/test_matsui2025_ref.jl` was green run directly and red under
    # `SPINORBEC_TEST_WORKERS=auto`, which is the worst shape a collision can
    # take. Scanning `test/` for the extended pattern returns exactly one hit
    # today (that one), so this costs nothing beyond closing the class.
    pattern = r"^(?:struct|mutable struct|abstract type|const|function)\s+([A-Za-z_][A-Za-z0-9_!]*)"
    collisions = Tuple{String, String, Int}[]
    test_root = @__DIR__
    for (root, _, files) in walkdir(test_root), f in files
        endswith(f, ".jl") || continue
        path = joinpath(root, f)
        for (i, line) in enumerate(eachline(path))
            m = match(pattern, line)
            m === nothing && continue
            m.captures[1] in exported &&
                push!(collisions, (relpath(path, test_root), m.captures[1], i))
        end
    end
    isempty(collisions) ||
        @info "Top-level test definitions shadowing a SpinorBEC export" collisions
    @test isempty(collisions)
end

# The per-PR required checks must, between them, run the whole `ci` tier.
#
# `oracles` exists because the `ci` tier is nightly-only, so a PR could break an
# oracle gate and merge green (5 gates sat RED for weeks, 2026-06-21). Cutting
# that pseudo-tier fixed the oracle half and left the other half: CI_EXTRA's
# non-oracle files — ground state, split-step, simulation, config/experiment
# plumbing — were still gated only by the nightly run.
#
# Splitting `ci` across three jobs is only equivalent to running `ci` if the
# three actually cover it, and if the workflow actually runs all three. Asserting
# the set identity over the tier lists alone would not catch someone deleting the
# job, so this reads the tiers back out of `.github/workflows/ci.yml` — delete a
# job or rename a tier and this test goes red, rather than the coverage quietly
# shrinking.
@testset "Per-PR CI jobs cover the ci tier" begin
    workflow = joinpath(@__DIR__, "..", ".github", "workflows", "ci.yml")
    @test isfile(workflow)

    pr_tiers = Set{String}()
    for line in eachline(workflow)
        m = match(r"^\s*SPINORBEC_TEST_TIER:\s*([A-Za-z_]+)\s*$", line)
        m === nothing || push!(pr_tiers, m.captures[1])
    end
    # Guard against the regex silently matching nothing after a formatting change.
    @test !isempty(pr_tiers)

    covered = union((Set(select_tests(t)) for t in pr_tiers)...)
    ci_tier = Set(select_tests("ci"))
    uncovered = sort(collect(setdiff(ci_tier, covered)))

    isempty(uncovered) || @info string(
        "ci-tier files no per-PR job runs (add them to a gated tier, or add a ",
        "job for the tier they live in)",
    ) uncovered
    @test isempty(uncovered)
end
