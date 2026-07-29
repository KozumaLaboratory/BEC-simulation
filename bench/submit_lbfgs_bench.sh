#!/bin/bash
# UGE submission (uk07267 / tga-kozuma-kouhi): L-BFGS solver benchmark.
#
#   qsub -g tga-kozuma-kouhi -N lbfgs_base \
#        -v SBEC_TAG=baseline,SBEC_ROOT=/gs/bs/work/7/uk07267/bec-perf-lbfgs \
#        bench/submit_lbfgs_bench.sh
#
# -g is a qsub CLI flag, never a #$ directive. node_q = 1 H100 + 48 cores
# (exclusive quarter node) so the CPU timings are not shared-node noise.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=1:00:00
#$ -j y
#$ -o /gs/bs/work/7/uk07267/lbfgs-bench/uge.log

set -euo pipefail

ROOT=${SBEC_ROOT:-/gs/bs/work/7/uk07267/bec-perf-lbfgs}
TAG=${SBEC_TAG:-run}
GRIDS=${SBEC_GRIDS:-}
OUT=/gs/bs/work/7/uk07267/lbfgs-bench
mkdir -p "$OUT"
cd "$ROOT"

. /etc/profile.d/modules.sh
module load cuda/12.8.0 2>/dev/null || module load cuda 2>/dev/null || true
[[ -n "${CUDA_HOME:-}" ]] && export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

# Writable depot first, shared precompiled depot second (/gs/fs is ~98% full,
# so nothing new is written there).
export JULIA_DEPOT_PATH=/gs/bs/work/7/uk07267/perf-lbfgs-depot:/gs/fs/tga-kozuma-kouhi/shared/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia

# Fixed thread count so before/after numbers are comparable.
export JULIA_NUM_THREADS=8
export SPINORBEC_SCRATCH_DIR="${T4_TMPDIR:-/tmp}/spinorbec_snaps"
mkdir -p "$SPINORBEC_SCRATCH_DIR"

echo "[lbfgs_bench] host=$(hostname) tag=$TAG root=$ROOT commit=$(git -C "$ROOT" rev-parse --short HEAD)"
nvidia-smi --query-gpu=name --format=csv,noheader || true

for be in cpu gpu; do
    echo "########## backend=$be ##########"
    "$JULIA" --project=. bench/bench_lbfgs.jl "$be" $GRIDS \
        2>&1 | tee "$OUT/lbfgs_${TAG}_${be}.out"
done

echo "[lbfgs_bench] done"
