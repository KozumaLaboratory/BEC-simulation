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
using TOML   # reads Project.toml for the import-availability gate below

# The runner include()s `_tiers.jl` into global scope before this file, so under
# `Pkg.test()` these are already bound. Pull them in when they are not, so the
# file that holds the "every test file is a dependency-free unit" contract
# satisfies it — it was the last one that did not.
isdefined(Main, :FAST_TESTS) || include(joinpath(@__DIR__, "_tiers.jl"))

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

    # Drift guard: flag a gross under-estimate, ignore the three ways of not
    # being one. The fixtures are SYNTHETIC names, which all resolve to
    # `_DEFAULT_COST`, and deliberately so: the previous version used
    # `solvers/test_3d.jl` at 60 s against its then-5 s entry, so correcting
    # that entry to its measured 60 s silently disarmed the positive control —
    # the assertion went 1 → 0 stale and the guard's own canary died of a data
    # edit. A control must not be reachable from the data it guards.
    #
    # All three predicates get a case, which the old fixture did not do: it had
    # no `abs_gap` arm at all.
    # `quiet=true`: these fixtures would otherwise print stale-cost annotations
    # into the CI log naming files that do not exist, in the same stream as the
    # real ones — which had already gone unread for weeks without help.
    stale = warn_cost_drift(
        [
            ("synthetic_gross.jl", 60.0),   # 60 > 8, > 3x3, gap 57 > 15 → STALE
            ("synthetic_ratio.jl", 8.5),    # over floor, but 8.5 ≤ 3x3 → not stale
            ("synthetic_gap.jl", 12.0),     # over floor and ratio, gap 9 ≤ 15 → not stale
            ("synthetic_tiny.jl", 4.0),     # below floor_s → not stale
        ]; quiet=true)
    @test length(stale) == 1
    @test stale[1].file == "synthetic_gross.jl"
    @test stale[1].estimate == _DEFAULT_COST

    # And the guard is one-directional: an OVER-estimate never flags. On-demand
    # scheduling makes an over-estimate free (a slot that frees early takes the
    # next item), while an under-estimate cannot be preempted — which is the
    # asymmetry the whole table exists to respect.
    @test isempty(warn_cost_drift([("synthetic_over.jl", 0.1)]; quiet=true))

    # And `quiet` must not change the VERDICT, only the printing — otherwise
    # silencing the fixtures would silence the guard.
    loud = warn_cost_drift([("synthetic_gross.jl", 60.0)]; quiet=true)
    @test length(loud) == 1
    @test loud[1].file == "synthetic_gross.jl"
end

# CLAUDE.md: "Parallel mode requires each test file to stay a dependency-free
# unit (own `using` / `@testset` / `@__DIR__` helpers)". It was not true of 45
# files, which relied on `_run_files.jl` leaking `Test` (and the other stdlibs)
# into `Main` from whichever file `using`d them first. Two consequences:
#
#   * the single-test command CLAUDE.md documents —
#     `julia --project=. -e 'using SpinorBEC; include("test/test_X.jl")'` —
#     died with `UndefVarError: @testset` on 13 % of the suite;
#   * the leak is order-dependent, so which files work standalone depends on
#     what the claim queue happened to hand out first.
#
# Static, so it costs nothing: a file that uses `@testset` must say so.
@testset "Every test file declares its own dependencies" begin
    test_root = @__DIR__
    missing_test, missing_pkg = String[], String[]
    for (root, _, files) in walkdir(test_root), f in files
        (startswith(f, "test_") && endswith(f, ".jl")) || continue
        rel = relpath(joinpath(root, f), test_root)
        src = read(joinpath(root, f), String)
        occursin(r"^\s*(?:using|import)\s+[^\n]*\bTest\b"m, src) || push!(missing_test, rel)
        # The PLAIN form. `using SpinorBEC: _elliptic_k` does not bring the
        # package's exports into scope, and `analysis/test_diagnostics.jl` had
        # exactly that while calling the exported `spin_mixing_period` — it ran
        # only because some other file in the worker had already `using`d the
        # package into `Main`. Selective imports are welcome ON TOP of this.
        occursin(r"^\s*using\s+SpinorBEC\s*(?:,|$)"m, src) || push!(missing_pkg, rel)
    end
    isempty(missing_test) ||
        @info "test files using @testset without `using Test`" missing_test
    isempty(missing_pkg) ||
        @info "test files without `using SpinorBEC`" missing_pkg
    @test isempty(missing_test)
    @test isempty(missing_pkg)
end

# The gate above asks whether the DECLARATIONS are present. It says nothing about
# whether what is declared can be RESOLVED, and the test environment is not the
# environment anyone develops in: an interactive `julia --project=.` session finds
# stdlibs that the `[targets] test` environment does not. So `using Logging` in
# test/oracles/test_itp_dt_limited_advisory.jl passed every local run and died on
# the runner with "Package Logging not found in current path" — 2.4 s into a job
# that had already spent five minutes getting there (2026-08-19).
#
# Availability is decidable statically: a package name is resolvable in the test
# environment iff it is SpinorBEC itself, `Test`, one of Project.toml's `[deps]`,
# or one of the `[targets] test` extras. `Base.…` / `Core.…` are not packages.
@testset "Every test file only imports what the test environment provides" begin
    proj = TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
    available = Set{String}(["SpinorBEC", "Test", "Base", "Core", "Main"])
    union!(available, keys(get(proj, "deps", Dict())))
    union!(available, get(get(proj, "targets", Dict()), "test", String[]))

    offenders = Dict{String, Vector{String}}()
    for (root, _, files) in walkdir(@__DIR__), f in files
        (startswith(f, "test_") && endswith(f, ".jl")) || continue
        rel = relpath(joinpath(root, f), @__DIR__)
        for m in eachmatch(r"(?m)^\s*(?:using|import)\s+([A-Za-z_][A-Za-z0-9_]*)",
            read(joinpath(root, f), String))
            pkg = m.captures[1]
            pkg in available && continue
            push!(get!(offenders, rel, String[]), pkg)
        end
    end
    isempty(offenders) || @info """
        test files importing packages absent from the test environment — these \
        resolve interactively and fail on a clean CI runner. Either add the \
        package to `[extras]` + `[targets] test` in Project.toml, or use the \
        `Base.…` form (e.g. `using Base.CoreLogging: with_logger, Warn` instead \
        of `using Logging`).""" offenders
    @test isempty(offenders)

    # Canary: the check must actually reject something. Without this, a typo in
    # the regex leaves a gate that passes because it matches nothing.
    @test !("Logging" in available)
    @test isempty(
        collect(
            eachmatch(r"(?m)^\s*(?:using|import)\s+Logging\b",
                "using SpinorBEC\nusing Base.CoreLogging: with_logger\n"),
        ),
    )
    @test !isempty(
        collect(
            eachmatch(r"(?m)^\s*(?:using|import)\s+([A-Za-z_][A-Za-z0-9_]*)",
                "using Logging\n"),
        ),
    )
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
