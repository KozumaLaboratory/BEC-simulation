#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:12:00
#$ -N gpu_gates
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
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
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-perf-itp}"

echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD)"
nvidia-smi --query-gpu=name --format=csv,noheader || true

# `SPINORBEC_GPU_GATES` overrides the list. The default is the minimum that
# covers a change to the DDI / spin-rotation kernels; a 12-minute h_rt backfills
# where a 30-minute one waits out a saturated gpu_1 pool.
GATES="${SPINORBEC_GPU_GATES:-gpu/test_gpu_padded_corner_parity.jl gpu/test_gpu_spin_rotation_taylor_parity.jl oracles/test_gpu_cpu_per_term_parity.jl}"

# Instantiate first: the shared depot can lose a package between jobs, and the
# downstream symptom is a gate reporting errors that read exactly like a
# regression in whatever is under test (2026-07-30: 156/156 -> 2 passed /
# 14 errored, cause was a missing CUDA in the depot).
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -5

for t in $GATES; do
    echo; echo "###### $t"
    # NOT piped through `tail`. Truncating to the last N lines keeps the test
    # SUMMARY and throws away the exception HEADER, which is the one line that
    # says what went wrong — it cost a whole diagnosis round on 2026-07-30.
    $JULIA --project=. -e "using Test; import CUDA; using SpinorBEC; include(\"test/$t\")" 2>&1 |
        grep -vE "^│|^└|^┌"
done
echo "ALL DONE $(date)"
