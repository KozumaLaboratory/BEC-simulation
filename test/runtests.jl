using Test
using SpinorBEC

# ── Test tier system ──────────────────────────────────────────────
# SPINORBEC_TEST_TIER controls which tests run:
#   fast     ~30s   lightweight unit tests only (no ITP/RTP)
#   ci       ~3min  fast + core integration (split_step, simulation, ground_state)
#   full     ~6min  everything (default)
#   physics  validation-only subset (analytic + physics levels)
#
# Usage:
#   SPINORBEC_TEST_TIER=fast julia --project=. -e 'using Pkg; Pkg.test()'
#   SPINORBEC_TEST_TIER=ci   julia --project=. -e 'using Pkg; Pkg.test()'
#
# Layout: test/ mirrors src/ subdirs (foundation, hamiltonian, solvers,
# workflow, analysis, rotating_basis, dynamics, gpu). Each entry below
# is a relative path from this file.

const TEST_TIER = lowercase(get(ENV, "SPINORBEC_TEST_TIER", "full"))

# Tier lists + select_tests live in _tiers.jl (shared with run_chunk.jl so the
# tier-membership meta-test sees them in any process).
include(joinpath(@__DIR__, "_tiers.jl"))

# ── Test runner ────────────────────────────────────────────────────
# Each file is a dependency-free unit (own `using`, own `@testset`, helpers
# pulled via `@__DIR__`). Both modes run every file under its own testset, run
# ALL files (one failure never hides another), and exit non-zero iff anything
# failed — via the SAME `run_test_files` in _run_files.jl, so they cannot drift
# on what counts as a failure.
#
#   SPINORBEC_TEST_WORKERS=1  (default)  serial, in-process — easiest to debug.
#   SPINORBEC_TEST_WORKERS=N|auto  (N>1)  partition the files into N chunks and
#       run each chunk in its OWN independent julia process (run_chunk.jl), then
#       aggregate by exit code. Independent processes — not Distributed workers —
#       are deliberate: each loads SpinorBEC exactly once in a clean session. A
#       shared-worker pool can reload the package mid-run (cache race), giving
#       two copies of a type so `x isa CheckResult` flakes to false; separate
#       processes cannot. `auto` = one chunk per CPU thread.
#
# SPINORBEC_TEST_SKIP: comma-separated relative paths to omit (e.g. the
# CUDA-importing oracles on a machine whose driver probe crashes the
# precompiler). SPINORBEC_TEST_TIMING=quiet suppresses the per-file timing table.

const _SKIP = Set(filter(!isempty, split(get(ENV, "SPINORBEC_TEST_SKIP", ""), ",")))
const _NWORKERS = let w = get(ENV, "SPINORBEC_TEST_WORKERS", "1")
    w == "auto" ? max(1, Sys.CPU_THREADS) : parse(Int, w)
end

# Slow files (measured on the fast tier) lead the list so round-robin chunking
# spreads them across chunks instead of piling onto one. Pure load-balancing
# hint; correctness-neutral.
const _SLOW_FIRST = [
    "test_quality.jl",
    "workflow/test_active_learning.jl",
    "test_level10_hpsi_self_consistency.jl",
    "workflow/test_autopilot.jl",
    "dynamics/test_tdhfb_f1_validation.jl",
    "test_reference_rhs.jl",
    "workflow/test_vtk_export.jl",
    "hamiltonian/test_ddi_padded.jl",
    "validation/test_L5_operator_rhs_compare.jl",
    "manuscript/test_f12_icosahedral.jl",
]

function _ordered_files()
    files = filter(f -> !(f in _SKIP), select_tests(TEST_TIER))
    _NWORKERS <= 1 && return files
    lead = filter(in(Set(files)), _SLOW_FIRST)
    rest = filter(f -> !(f in Set(lead)), files)
    vcat(lead, rest)
end

const _FILES = _ordered_files()

# Shared per-file run/fail/timing logic — the SAME `run_test_files` that each
# parallel chunk uses (run_chunk.jl), so serial and parallel cannot disagree on
# what counts as a failure.
include(joinpath(@__DIR__, "_run_files.jl"))

if _NWORKERS <= 1
    failed, timings = run_test_files(_FILES)
    print_timing(timings, TEST_TIER)
    failed && error("SpinorBEC test suite (tier=$TEST_TIER): failures above")
    println("\nSpinorBEC ($(length(_FILES)) files, tier=$TEST_TIER): all passed")
else
    # Round-robin the slow-first list into N chunks (balances the long poles),
    # then run each chunk in its own process via run_chunk.jl. `--pkgimages=
    # existing` reuses the already-built image rather than racing N children to
    # rebuild it; the package must be precompiled beforehand (CI buildpkg /
    # Pkg.test guarantees it). A stacked JULIA_LOAD_PATH (local dev) is
    # inherited by the children and still wins over --project.
    chunks = [String[] for _ in 1:_NWORKERS]
    for (i, f) in enumerate(_FILES)
        push!(chunks[mod1(i, _NWORKERS)], f)
    end
    runner = joinpath(@__DIR__, "run_chunk.jl")
    jl = Base.julia_cmd()
    proj = Base.active_project()
    println("Running $(length(_FILES)) files in $_NWORKERS parallel chunks (tier=$TEST_TIER)…")

    results = asyncmap(eachindex(chunks); ntasks=_NWORKERS) do k
        files = chunks[k]
        isempty(files) && return (k, 0, "")
        cmd = `$jl --startup-file=no --project=$proj --pkgimages=existing $runner $files`
        buf = IOBuffer()
        p = run(pipeline(ignorestatus(cmd); stdout=buf, stderr=buf); wait=true)
        (k, p.exitcode, String(take!(buf)))
    end

    for (k, code, out) in results
        println("\n──── chunk $k ($(length(chunks[k])) files, exit $code) ────")
        print(out)
    end
    nfail = count(r -> r[2] != 0, results)
    nfail > 0 &&
        error("SpinorBEC test suite: $nfail/$_NWORKERS chunks had failures (tier=$TEST_TIER)")
    println(
        "\nSpinorBEC ($(length(_FILES)) files in $_NWORKERS chunks, tier=$TEST_TIER): all passed"
    )
end
