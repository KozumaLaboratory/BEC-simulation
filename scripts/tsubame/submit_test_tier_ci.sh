#!/bin/bash
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=1:30:00
#$ -N test_ci
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#
# See also submit_test_tier.sh, which takes the tier as a parameter and makes its
# own checkout. This one used to end with an `echo`, so `qacct` reported
# exit_status 0 for a red suite — the defect was written in this header and left
# unfixed for weeks, which is why the property is now gated
# (test/test_submit_scripts_fail_loudly.jl) rather than described.
#
# Full `ci` tier. Main's required checks are fast + oracles + formatter only, so
# a green PR says nothing about `ci` — run this before merging anything under
# solvers/ hamiltonian/ analysis/.
#   qsub -g tga-kozuma-kouhi -v SPINORBEC_BENCH_ROOT=<worktree> \
#        scripts/tsubame/submit_test_tier_ci.sh
set -u

export JULIA_DEPOT_PATH="$HOME/.julia"
export SPINORBEC_TEST_TIER="${SPINORBEC_TEST_TIER:-ci}"
export SPINORBEC_TEST_WORKERS="${SPINORBEC_TEST_WORKERS:-8}"

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-perf-itp}"

echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD)"
echo "tier=$SPINORBEC_TEST_TIER workers=$SPINORBEC_TEST_WORKERS"

# Instantiate first. The shared depot can lose a package between jobs -- a run
# on 2026-07-30 saw `Package CUDA ... does not seem to be installed` on main and
# on a branch minutes after both had used CUDA successfully, and the downstream
# symptom was a core parity gate reporting 14 errors. Without this, an
# environment fault is indistinguishable from a regression.
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -5

$JULIA --project=. -e 'using Pkg; Pkg.test()' 2>&1
RC=$?
echo "TEST_RC=$RC"
echo "ALL DONE $(date)"
# The job's exit status IS the suite's. `echo` last means qacct reports 0 for a
# red suite, and exit_status was the only signal available for job 8309102 until
# someone found its log.
exit "$RC"
