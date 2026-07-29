#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:25:00
#$ -N bench_itp_ab
#$ -o /gs/bs/work/7/uk07267/logs/
#$ -e /gs/bs/work/7/uk07267/logs/
#
# Both arms of a GPU ITP A/B in ONE job, so the comparison is on one card in one
# allocation and cannot be confounded by the queue putting the arms on different
# nodes (or the same node in different thermal states).
#   qsub -g tga-kozuma-kouhi \
#        -v SPINORBEC_AB_A=<baseline-worktree>,SPINORBEC_AB_B=<changed-worktree> \
#        scripts/tsubame/submit_bench_itp_gpu_ab.sh
set -u

export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-8}"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
A="${SPINORBEC_AB_A:-/gs/bs/work/7/uk07267/bec-perf-itp}"
B="${SPINORBEC_AB_B:-/gs/bs/work/7/uk07267/bec-itp-norm}"
CFGS="${SPINORBEC_AB_CFGS:-32 64}"

echo "host=$(hostname) date=$(date)"
nvidia-smi --query-gpu=name --format=csv,noheader || true

# One script file against both `--project`s, so the bench itself is not a
# variable between the arms.
SCRIPT="$B/bench/bench_itp_step.jl"

for n in $CFGS; do
    for root in "$A" "$B"; do
        echo; echo "###### n=$n ROOT=$root commit=$(cd "$root" && git rev-parse --short HEAD)"
        (cd "$root" && $JULIA --project=. "$SCRIPT" gpu "$n" none 2>&1 |
            grep -vE "^│|^└|^┌" | tail -22)
    done
done
echo "ALL DONE $(date)"
