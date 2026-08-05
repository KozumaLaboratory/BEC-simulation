#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=1:00:00
#$ -N bench_itp
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#
# Per-kernel ITP step breakdown on an H100. Submit from the worktree root:
#   qsub -g tga-kozuma-kouhi scripts/tsubame/submit_bench_itp.sh
#
# Depot lives under $HOME (25 GB quota of its own) — /gs/fs is at 98 % and a
# precompile there dies as EDQUOT/SIGBUS rather than "disk full".
set -u

export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-8}"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-perf-itp}"

echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD)"
nvidia-smi --query-gpu=name --format=csv,noheader || true
echo "threads=$JULIA_NUM_THREADS"

for cfg in "gpu 32 none" "gpu 64 none" "gpu 32 polar_contact" "cpu 32 none"; do
    echo; echo "###### CONFIG: $cfg"
    $JULIA --project=. bench/bench_itp_step.jl $cfg 2>&1
    echo "###### rc=$?"
done
echo "ALL DONE $(date)"
