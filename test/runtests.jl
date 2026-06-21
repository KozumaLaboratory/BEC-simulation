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
#   SPINORBEC_TEST_WORKERS=N|auto  (N>1)  LPT-balance the files into N chunks
#       (by _COST, so the heavy poles spread out) and run each chunk in its OWN
#       independent julia process (run_chunk.jl), then aggregate by exit code.
#       Independent processes — not Distributed workers — are deliberate: each
#       loads SpinorBEC exactly once in a clean session. A shared-worker pool
#       can reload the package mid-run (cache race), giving two copies of a type
#       so `x isa CheckResult` flakes to false; separate processes cannot.
#       `auto` = one chunk per CPU thread.
#
# SPINORBEC_TEST_SKIP: comma-separated relative paths to omit (e.g. the
# CUDA-importing oracles on a machine whose driver probe crashes the
# precompiler). SPINORBEC_TEST_TIMING=quiet suppresses the per-file timing table.

const _SKIP = Set(filter(!isempty, split(get(ENV, "SPINORBEC_TEST_SKIP", ""), ",")))
const _NWORKERS = let w = get(ENV, "SPINORBEC_TEST_WORKERS", "1")
    w == "auto" ? max(1, Sys.CPU_THREADS) : parse(Int, w)
end

# Per-file cost estimate (seconds), measured on the full tier, used only to
# balance the parallel chunks. Only the heavy outliers need an entry; the long
# tail defaults to _DEFAULT_COST. A wrong estimate costs balance, never
# correctness.
#
# Note on rotating_basis F32: its first-time JIT is ~10 min, but it is cached
# afterwards (CLAUDE.md), and the depot cache persists across nightly runs, so
# the steady-state cost is small — estimate it modestly (30 s) so it leads
# without monopolising a whole chunk. Pinning it at the cold 600 s would idle an
# entire worker on every (warm) run.
const _DEFAULT_COST = 3.0
const _COST = Dict{String, Float64}(
    "workflow/test_multi_fidelity_bo.jl" => 161.0,
    "workflow/test_triple_point.jl" => 127.0,
    "test_dealias_2_3.jl" => 76.0,
    "solvers/test_continuation.jl" => 58.0,
    "test_quality.jl" => 40.0,
    "rotating_basis/test_rotating_basis_f32.jl" => 30.0,  # warm; ~10 min only on a cold cache
    "workflow/test_pipeline.jl" => 17.0,
    "workflow/test_infrastructure.jl" => 15.0,
    "workflow/test_active_learning.jl" => 15.0,
    "test_level4_general_F_phase_emergence.jl" => 13.0,
    "test_level10_hpsi_self_consistency.jl" => 12.0,
    "workflow/test_autopilot.jl" => 12.0,
    "oracles/test_propagator_references.jl" => 11.0,
    "oracles/test_master_oracle.jl" => 11.0,
    "oracles/test_path_coverage.jl" => 10.0,
    "analysis/test_tof_multiframe.jl" => 9.5,
    "gpu/test_mixed_precision.jl" => 9.0,
    "rotating_basis/test_rotating_basis_gpe.jl" => 9.0,
    "dynamics/test_tdhfb_f1_validation.jl" => 8.5,
    "analysis/test_physics_invariants.jl" => 8.0,
    "solvers/test_simulation.jl" => 8.0,
    "test_reference_rhs.jl" => 7.5,
    "solvers/test_lbfgs_sobolev_preconditioner.jl" => 6.5,
    "rotating_basis/test_rotating_basis_pipeline_parsing.jl" => 6.0,
    "hamiltonian/test_integrator_order_meanfield.jl" => 5.0,
    "solvers/test_3d.jl" => 5.0,
    "dynamics/test_twa.jl" => 5.0,
    "solvers/test_lbfgs.jl" => 5.0,
)

_cost(f) = get(_COST, f, _DEFAULT_COST)

# Greedy longest-processing-time bin-packing: assign each file (heaviest first)
# to the currently-lightest chunk. Minimises makespan for the skewed full-tier
# cost distribution (a 161 s BO test next to many ~3 s units), which plain
# round-robin handles poorly.
function _balance(files, n)
    chunks = [String[] for _ in 1:n]
    loads = zeros(Float64, n)
    for f in sort(collect(files); by=_cost, rev=true)
        i = argmin(loads)
        push!(chunks[i], f)
        loads[i] += _cost(f)
    end
    return chunks
end

const _FILES = filter(f -> !(f in _SKIP), select_tests(TEST_TIER))

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
    # LPT-balance the files into N chunks, then run each chunk in its own
    # process via run_chunk.jl. `--pkgimages=existing` reuses the already-built
    # image rather than racing N children to rebuild it; the package must be
    # precompiled beforehand (CI buildpkg / Pkg.test guarantees it). A stacked
    # JULIA_LOAD_PATH (local dev) is inherited by the children and still wins
    # over --project.
    chunks = _balance(_FILES, _NWORKERS)
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
