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
#   SPINORBEC_TEST_WORKERS=N|auto  (N>1)  start N independent julia processes
#       (run_chunk.jl) that take files ON DEMAND from a shared claim queue,
#       heaviest first (_COST as the ordering), then aggregate by exit code.
#       Independent processes — not Distributed workers — are deliberate: each
#       loads SpinorBEC exactly once in a clean session. A shared-worker pool
#       can reload the package mid-run (cache race), giving two copies of a type
#       so `x isa CheckResult` flakes to false; separate processes cannot.
#       `auto` = one worker per CPU THIS JOB MAY USE — the affinity mask or the
#       scheduler's grant, via host_budget.jl, NOT the machine's core count.
#       The distinction is the whole point: `Sys.CPU_THREADS` on a TSUBAME node
#       reports the node (384 on the cpu_16 hardware, per #407's own probe), so
#       `auto` there used to start an entire node's worth of julia processes
#       inside a 16-core allotment. Where the budget cannot be derived this
#       falls back to SERIAL and says so — the safe extreme, not a guess.
#       On-demand rather than pre-assigned: measured on CI, per-file times swing
#       ±30 % run to run, so static bin-packing left the makespan 8-21 % above
#       the perfect-balance floor no matter how well _COST was fitted.
#
# SPINORBEC_TEST_SKIP: comma-separated relative paths to omit (e.g. the
# CUDA-importing oracles on a machine whose driver probe crashes the
# precompiler). SPINORBEC_TEST_TIMING=quiet suppresses the per-file timing table.

# Deterministic FFT plans for the whole suite. `FFTW.MEASURE` (the production
# default) benchmarks candidate algorithms at plan time, so the summation order of
# every transform depends on machine load and every round-off-limited quantity
# stops being reproducible across processes. Measured on the L-BFGS gradient floor,
# four fresh processes: MEASURE gave 1.709e-8 / 2.130e-8 / 5.258e-8 / 1.709e-8,
# ESTIMATE gave 4.1453063004739704e-9 four times. See
# src/foundation/fft_planning.jl. Overridable, so a run can deliberately measure
# the production planner.
get!(ENV, "SPINORBEC_FFT_ESTIMATE", "1")

const _SKIP = Set(filter(!isempty, split(get(ENV, "SPINORBEC_TEST_SKIP", ""), ",")))

# Wrapped in a module so the runner's namespace stays clean: every test file
# does `using SpinorBEC`, which exports these same names.
module _HostBudget
include(joinpath(@__DIR__, "..", "src", "workflow", "io", "host_budget.jl"))
end

const _NWORKERS = let w = get(ENV, "SPINORBEC_TEST_WORKERS", "1")
    if w != "auto"
        parse(Int, w)
    else
        try
            _HostBudget.detect_host_budget().cpu_threads
        catch err
            err isa _HostBudget.BlindBudget || rethrow()
            @warn(
                "SPINORBEC_TEST_WORKERS=auto could not derive this job's CPU " *
                    "allotment; running SERIAL rather than guessing a worker count.",
                exception = err)
            1
        end
    end
end
# Per-worker wall-clock cap (seconds) under parallelism; 0 disables. Generous by
# default — catches a genuine hang, not a merely-slow file (cold F32 ≈ 600 s).
const _TIMEOUT = parse(Float64, get(ENV, "SPINORBEC_TEST_TIMEOUT", "1800"))

# _DEFAULT_COST / _COST / _cost (the per-file balance model) + warn_cost_drift
# live in _tiers.jl, shared with the chunk processes (run_chunk.jl) so the
# drift guard runs against the same numbers everywhere.

# Longest-processing-time ORDER: hand the heaviest files out first, so the tail
# of the run is short files that can pad any worker that finishes early. This is
# only an ordering heuristic — the workers take files on demand (see the claim
# queue in run_chunk.jl), so a wrong `_cost` costs a little ordering quality and
# never leaves one worker holding a chunk nobody can help with. Static LPT
# bin-packing did the latter: measured on CI, per-file times swing ±30 % run to
# run, which left the makespan 8-21 % above the perfect-balance floor however
# well the estimates were fitted.
_lpt_order(files) = sort(collect(files); by=_cost, rev=true)

const _FILES = filter(f -> !(f in _SKIP), select_tests(TEST_TIER))

# Shared per-file run/fail/timing logic — the SAME `run_test_files` that each
# parallel chunk uses (run_chunk.jl), so serial and parallel cannot disagree on
# what counts as a failure.
include(joinpath(@__DIR__, "_run_files.jl"))

if _NWORKERS <= 1
    failed, timings = run_test_files(_FILES)
    print_timing(timings, TEST_TIER)
    warn_cost_drift(timings)
    failed && error("SpinorBEC test suite (tier=$TEST_TIER): failures above")
    println("\nSpinorBEC ($(length(_FILES)) files, tier=$TEST_TIER): all passed")
else
    # Publish the ordered file list, then start N independent worker processes
    # that pull from it on demand (run_chunk.jl `--queue`). `--pkgimages=existing`
    # reuses the already-built image rather than racing N children to rebuild it;
    # the package must be precompiled beforehand (CI buildpkg / Pkg.test
    # guarantees it). A stacked JULIA_LOAD_PATH (local dev) is inherited by the
    # children and still wins over --project.
    ordered = _lpt_order(_FILES)
    qdir = mktempdir()
    write(joinpath(qdir, "queue.txt"), join(ordered, "\n"))
    runner = joinpath(@__DIR__, "run_chunk.jl")
    jl = Base.julia_cmd()
    proj = Base.active_project()
    println("Running $(length(_FILES)) files across $_NWORKERS parallel workers (tier=$TEST_TIER)…")

    results = asyncmap(1:_NWORKERS; ntasks=_NWORKERS) do k
        cmd = `$jl --startup-file=no --project=$proj --pkgimages=existing $runner --queue $qdir`
        buf = IOBuffer()
        p = run(pipeline(ignorestatus(cmd); stdout=buf, stderr=buf); wait=false)
        # Per-worker wall-clock guard: a hung test (non-converging ITP, deadlock)
        # would otherwise stall the whole suite until the CI job timeout. Kill
        # the worker and report it as failed (exit 124) instead.
        t0 = time()
        timed_out = false
        while process_running(p)
            if _TIMEOUT > 0 && time() - t0 > _TIMEOUT
                kill(p)
                sleep(1.0)
                process_running(p) && kill(p, Base.SIGKILL)
                timed_out = true
                break
            end
            sleep(0.5)
        end
        wait(p)
        out = String(take!(buf))
        timed_out && (out *= "\n⏱  worker $k TIMED OUT after $(_TIMEOUT)s — killed\n")
        # `p.exitcode` is 0 for a process that died on a SIGNAL — the signal lands
        # in `p.termsignal`. Reading only the exit code reported an OOM-killed
        # worker as a clean exit, so the suite blamed the file it happened to be
        # running: `oracles/test_continuity_equation.jl` came up "never completed"
        # three times with every worker "exit 0", while `dmesg` showed four julia
        # processes killed at 14-21 GB RSS. Report 128+signal (the shell
        # convention), so SIGKILL surfaces as 137 and reads as OOM at a glance.
        code = timed_out ? 124 : (p.termsignal != 0 ? 128 + p.termsignal : p.exitcode)
        (k, code, out)
    end

    for (k, code, out) in results
        sig = code == 137 ? "  ← SIGKILL, almost certainly the OOM killer: lower \
                             SPINORBEC_TEST_WORKERS (full-tier peak ≈ 2.7 GB/process)" : ""
        println("\n──── worker $k (exit $code)$sig ────")
        print(out)
    end

    # A worker killed (timeout) or crashed between claiming a file and finishing
    # it leaves a claim with no `done_` marker. Without this check that file
    # would simply not have run — a silently-skipped test, the one failure mode
    # an on-demand queue can have that static assignment cannot.
    # Distinguish the two ways an index can lack a `done_` marker, because they
    # have different causes and only one is dangerous:
    #   CLAIMED   a worker took the item and never finished it — it died, or it
    #             returned from `claim` without running (the hole fixed in
    #             d7c8517b). The test did not run and nothing else noticed.
    #   UNCLAIMED nobody ever took it, i.e. parent and workers disagree about the
    #             index space or the queue file.
    # `oracles/test_continuity_equation.jl` has come up unrun three times with
    # every worker exiting 0, no duplicate in the file list, and an 8 s runtime
    # standalone — so the next occurrence needs to say WHICH of these it is.
    unrun = Tuple{String, Bool}[]
    for (i, f) in enumerate(ordered)
        isfile(joinpath(qdir, "done_$i")) && continue
        push!(unrun, (f, isfile(joinpath(qdir, "claim_$i"))))
    end
    nfail = count(r -> r[2] != 0, results)

    # Name the red FILES, not just the red workers. Worker stdout is buffered
    # until the worker exits, so on a long run the only thing visible for
    # minutes is "worker k (exit 1)"; the per-file verdict markers written by
    # serve_queue turn that into a list you can act on.
    redfiles = [
        f for (i, f) in enumerate(ordered)
        if isfile(joinpath(qdir, "done_$i")) &&
        startswith(read(joinpath(qdir, "done_$i"), String), "FAIL")
    ]
    isempty(redfiles) || println("\n✗ $(length(redfiles)) file(s) FAILED:\n    ",
        join(redfiles, "\n    "))
    if !isempty(unrun)
        println("\n✗ $(length(unrun)) file(s) never completed:")
        for (f, claimed) in unrun
            println(
                "    ",
                rpad(f, 60),
                if claimed
                    "CLAIMED (a worker took it and did not finish)"
                else
                    "UNCLAIMED (nobody took it — index-space bug)"
                end,
            )
        end
        error("SpinorBEC test suite: unrun files (tier=$TEST_TIER) — see above")
    end
    nfail > 0 &&
        error("SpinorBEC test suite: $nfail/$_NWORKERS workers had failures (tier=$TEST_TIER)")
    println(
        "\nSpinorBEC ($(length(_FILES)) files across $_NWORKERS workers, tier=$TEST_TIER): all passed"
    )
end
