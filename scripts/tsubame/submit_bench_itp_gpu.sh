#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:25:00
#$ -N bench_itp_gpu
#$ -o /gs/bs/work/7/uk07267/logs/
#$ -e /gs/bs/work/7/uk07267/logs/
#
# GPU ITP kernel breakdown, short h_rt so UGE backfills it.
#   qsub -g tga-kozuma-kouhi [-v SPINORBEC_BENCH_ROOT=<worktree>] \
#        scripts/tsubame/submit_bench_itp_gpu.sh
set -u

export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-8}"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/bs/work/7/uk07267/bec-perf-itp}"

echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD)"
nvidia-smi --query-gpu=name --format=csv,noheader || true

for cfg in "gpu 32 none" "gpu 64 none"; do
    echo; echo "###### CONFIG: $cfg"
    $JULIA --project=. bench/bench_itp_step.jl $cfg 2>&1
    echo "###### rc=$?"
done
echo "ALL DONE $(date)"
