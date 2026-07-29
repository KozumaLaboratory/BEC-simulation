#!/bin/bash
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=1:30:00
#$ -N test_ci
#$ -o /gs/bs/work/7/uk07267/logs/
#$ -e /gs/bs/work/7/uk07267/logs/
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
cd "${SPINORBEC_BENCH_ROOT:-/gs/bs/work/7/uk07267/bec-perf-itp}"

echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD)"
echo "tier=$SPINORBEC_TEST_TIER workers=$SPINORBEC_TEST_WORKERS"

$JULIA --project=. -e 'using Pkg; Pkg.test()' 2>&1
echo "TEST_RC=$?"
echo "ALL DONE $(date)"
