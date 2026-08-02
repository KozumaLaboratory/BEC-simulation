#!/bin/bash
#$ -cwd
#$ -l cpu_4=1
#$ -l h_rt=0:30:00
#$ -N itp_fp
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#
# Runs the ITP fingerprint in BOTH worktrees from one job, so the comparison is
# on one node in one shot and cannot be confounded by the queue.
#   qsub -g tga-kozuma-kouhi \
#        -v SPINORBEC_FP_A=<baseline-worktree>,SPINORBEC_FP_B=<optimised-worktree> \
#        scripts/tsubame/submit_itp_fingerprint.sh
set -u

export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-4}"

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
A="${SPINORBEC_FP_A:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-itp-base}"
B="${SPINORBEC_FP_B:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-perf-itp}"

echo "host=$(hostname) date=$(date) threads=$JULIA_NUM_THREADS"

# ONE script file, two package versions: the baseline worktree predates the
# script, and running the same bytes against both `--project`s also removes the
# script itself as a variable.
SCRIPT="$B/bench/itp_state_fingerprint.jl"

for root in "$A" "$B"; do
    echo; echo "###### ROOT=$root  commit=$(cd "$root" && git rev-parse --short HEAD)"
    (cd "$root" && $JULIA --project=. "$SCRIPT" 16 40 2>&1 | tail -8)
done
echo "ALL DONE $(date)"
