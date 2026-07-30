#!/bin/bash
# UGE submission (uk07267 / tga-kozuma-kouhi): how many Julia threads the
# L-BFGS iteration actually wants.
#
#   qsub -g tga-kozuma-kouhi -N lbfgs_tscan bench/submit_lbfgs_thread_scan.sh
#
# The two-loop recursion is memory-bandwidth bound, so it saturates well below
# the core count and the answer is not "as many as you have". Julia fixes its
# thread count at startup, so each point is a separate process.
#
# node_q = 1 H100 + 48 cores (exclusive quarter node): needed to give 32
# threads real cores rather than measuring oversubscription.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o /gs/bs/work/7/uk07267/lbfgs-tscan/uge.log

set -euo pipefail

ROOT=${SBEC_ROOT:-/gs/bs/work/7/uk07267/bec-perf-lbfgs}
GRID=${SBEC_GRID:-24}
THREADS=${SBEC_THREADS:-"1 2 4 8 16 32"}
OUT=/gs/bs/work/7/uk07267/lbfgs-tscan
mkdir -p "$OUT"
cd "$ROOT"

. /etc/profile.d/modules.sh
module load cuda/12.8.0 2>/dev/null || module load cuda 2>/dev/null || true
[[ -n "${CUDA_HOME:-}" ]] && export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

export JULIA_DEPOT_PATH=/gs/bs/work/7/uk07267/perf-lbfgs-depot:/gs/fs/tga-kozuma-kouhi/shared/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
export SPINORBEC_SCRATCH_DIR="${T4_TMPDIR:-/tmp}/spinorbec_snaps"
mkdir -p "$SPINORBEC_SCRATCH_DIR"

echo "[tscan] host=$(hostname) cores=$(nproc) commit=$(git -C "$ROOT" rev-parse --short HEAD) grid=${GRID}"

for n in $THREADS; do
    echo "########## threads=$n ##########"
    JULIA_NUM_THREADS=$n "$JULIA" --project=. bench/bench_lbfgs.jl cpu "$GRID" \
        2>&1 | tee "$OUT/tscan_${n}.out"
done

echo "[tscan] done"
