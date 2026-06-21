# Runs one chunk of test files in an independent process — the unit of work
# for the parallel runner in runtests.jl (SPINORBEC_TEST_WORKERS > 1). A clean
# session loads SpinorBEC exactly once, so there is no shared-worker module-
# identity hazard (a worker that reloads the package mid-run gets two copies of
# a type and `x isa T` flakes to false). Exits non-zero iff any file
# failed/errored, so the parent can tally via exit codes.
#
# The per-file run/fail/timing logic is shared verbatim with the serial path —
# see _run_files.jl. ARGS = test-file paths relative to this directory.

using Test
using SpinorBEC

include(joinpath(@__DIR__, "_run_files.jl"))
# Tier lists + MANUAL_TESTS_ALLOWLIST, so a config meta-test (e.g.
# test_tier_membership.jl) that reads them works inside a chunk process too.
include(joinpath(@__DIR__, "_tiers.jl"))

failed, timings = run_test_files(ARGS)
print_timing(timings, get(ENV, "SPINORBEC_TEST_TIER", "?"))
# Flag files whose measured time has drifted above the _COST estimate — the
# parent relays this chunk's stdout to the CI log, so the ::warning annotation
# surfaces on the run (keeps the LPT balance honest as tests get heavier).
warn_cost_drift(timings)

exit(failed ? 1 : 0)
