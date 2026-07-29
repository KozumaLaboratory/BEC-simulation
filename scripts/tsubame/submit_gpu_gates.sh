#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:30:00
#$ -N gpu_gates
#$ -o /gs/bs/work/7/uk07267/logs/
#$ -e /gs/bs/work/7/uk07267/logs/
#
# GPU-only gates for the DDI / spin-rotation hot path. Nothing on a CPU node
# exercises these kernels, so a green `ci` tier says nothing about them.
#   qsub -g tga-kozuma-kouhi -v SPINORBEC_BENCH_ROOT=<worktree> \
#        scripts/tsubame/submit_gpu_gates.sh
set -u

export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-8}"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/bs/work/7/uk07267/bec-perf-itp}"

echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD)"
nvidia-smi --query-gpu=name --format=csv,noheader || true

for t in gpu/test_gpu_padded_corner_parity.jl \
    gpu/test_gpu_spin_rotation_taylor_parity.jl \
    oracles/test_gpu_cpu_per_term_parity.jl \
    oracles/test_spin_chain_fusion_parity.jl \
    test_level0_gpu_cpu_consistency.jl; do
    echo; echo "###### $t"
    $JULIA --project=. -e "using Test; import CUDA; using SpinorBEC; include(\"test/$t\")" 2>&1 |
        grep -vE "^│|^└|^┌" | tail -25
done
echo "ALL DONE $(date)"
