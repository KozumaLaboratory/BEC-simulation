#!/bin/bash
#$ -cwd
#$ -l cpu_4=1
#$ -l h_rt=0:25:00
#$ -N tol_sweep
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#
# Is SPIN_TAYLOR_TOL a decision or a derived quantity? Measures the cost of the
# tolerance and, next to it, the splitting error the caller already accepted by
# choosing dt.
#   qsub -g tga-kozuma-kouhi -v SPINORBEC_BENCH_ROOT=<worktree> \
#        scripts/tsubame/submit_taylor_tol_sweep.sh
set -u
export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-4}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-itp-norm}"
echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD) threads=$JULIA_NUM_THREADS"
$JULIA --project=. bench/taylor_tolerance_sweep.jl "${SPINORBEC_SWEEP_N:-32}" "${SPINORBEC_SWEEP_STEPS:-200}" 2>&1
echo "ALL DONE $(date)"
