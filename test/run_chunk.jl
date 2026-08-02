# Runs test files in an independent process — the unit of work for the parallel
# runner in runtests.jl (SPINORBEC_TEST_WORKERS > 1). A clean session loads
# SpinorBEC exactly once, so there is no shared-worker module-identity hazard (a
# worker that reloads the package mid-run gets two copies of a type and
# `x isa T` flakes to false). Exits non-zero iff any file failed/errored, so the
# parent can tally via exit codes.
#
# Two argument forms:
#   run_chunk.jl <file>...       run exactly these files (manual / debugging)
#   run_chunk.jl --queue <dir>   pull work from the shared claim queue in <dir>
#
# The queue form is what the parallel runner uses. Each worker walks the same
# ordered file list and takes a file by atomically creating `claim_<i>`
# (O_CREAT|O_EXCL — the POSIX kernel does the mutual exclusion, no lock file, no
# IPC); losing the race just means another worker got there first. Work is
# therefore handed out on demand rather than pre-assigned, so a file that runs
# long steals nothing from its neighbours: no per-file cost estimate can be
# stale enough to unbalance the run. `done_<i>` is written after the file
# returns, and the parent verifies every index has one — a worker killed
# mid-file leaves its claim without a done marker, which surfaces as a loud
# failure rather than a silently-skipped test.
#
# The per-file run/fail/timing logic is shared verbatim with the serial path —
# see _run_files.jl.

using Test
using SpinorBEC

include(joinpath(@__DIR__, "_run_files.jl"))
# Tier lists + MANUAL_TESTS_ALLOWLIST, so a config meta-test (e.g.
# test_tier_membership.jl) that reads them works inside a chunk process too.
include(joinpath(@__DIR__, "_tiers.jl"))

"""
    claim(dir, i) -> Bool

Try to take work item `i`. Exactly one caller can win: `O_CREAT | O_EXCL` fails
for everyone but the process that creates the file.

The claim is TAKEN the instant that creation succeeds, so `close` is bookkeeping
and is handled separately. Wrapping both in one `try` (as this did until
2026-07-29) meant a `close` failure returned `false` *after* the claim file
existed: no other worker could ever take the item, and the worker that had taken
it skipped it — a silently unrun test, which is the single failure mode an
on-demand queue has that static assignment does not, and the reason `done_<i>`
exists at all.
"""
function claim(dir::AbstractString, i::Integer)
    flags = Base.Filesystem.JL_O_CREAT | Base.Filesystem.JL_O_EXCL |
            Base.Filesystem.JL_O_WRONLY
    fd = try
        Base.Filesystem.open(joinpath(dir, "claim_$i"), flags, 0o644)
    catch
        return false            # another worker got there first
    end
    try
        close(fd)
    catch e
        @warn "claim_$i taken but close failed; keeping the claim" exception = e
    end
    return true
end

"""
    serve_queue(qdir) -> (failed, timings)

Take files from the shared queue until none is left unclaimed. `done_<i>` is
written only after the file has actually returned, so the parent can tell a
finished file from a claimed-then-killed one. Its CONTENT is this file's
verdict (`PASS`/`FAIL` + seconds): the parent buffers each worker's stdout
until the worker exits, so without a per-file record a red run names the
worker, not the test. The mutation harness reads the same markers.
"""
function serve_queue(qdir::AbstractString)
    failed = false
    timings = Tuple{String, Float64}[]
    for (i, f) in enumerate(readlines(joinpath(qdir, "queue.txt")))
        claim(qdir, i) || continue
        f_failed, f_timings = run_test_files([f])
        failed |= f_failed
        append!(timings, f_timings)
        secs = isempty(f_timings) ? 0.0 : last(f_timings[end])
        write(joinpath(qdir, "done_$i"),
            string(f_failed ? "FAIL" : "PASS", " ", round(secs; digits=2), " ", f))
    end
    return failed, timings
end

failed, timings = if length(ARGS) == 2 && ARGS[1] == "--queue"
    serve_queue(ARGS[2])
else
    run_test_files(ARGS)
end

print_timing(timings, get(ENV, "SPINORBEC_TEST_TIER", "?"))
# Flag files whose measured time has drifted above the _COST estimate — the
# parent relays this worker's stdout to the CI log, so the ::warning annotation
# surfaces on the run. With on-demand scheduling a stale estimate no longer
# costs wall-clock, only the longest-first ordering, so this is now a slow-test
# signal rather than a balance alarm.
warn_cost_drift(timings)

exit(failed ? 1 : 0)
