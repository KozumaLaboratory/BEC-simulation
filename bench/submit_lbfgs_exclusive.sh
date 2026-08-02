#!/bin/bash
# UGE submission (uk07267 / tga-kozuma-kouhi): the L-BFGS A/B and thread scan
# on an EXCLUSIVE node.
#
#   qsub -g tga-kozuma-kouhi -N lbfgs_excl bench/submit_lbfgs_exclusive.sh
#
# Why node_f and not node_q or gpu_h: the two-loop recursion is memory-bandwidth
# bound, and `gpu_h` / `node_q` are a half / a quarter of a node — the other
# tenants share the socket and its memory controllers. A bandwidth-bound
# measurement on a shared allocation is not a measurement of the code.
#
# Evidence that this matters (2026-07-30): a thread scan on node_q returned the
# two-loop cost as 8.3 / 15.7 / 14.2 / 11.4 / 8.3 / 12.3 ms at 1 / 2 / 4 / 8 /
# 16 / 32 threads — non-monotonic, i.e. all noise, and no faster at 32 threads
# than at 1. The four earlier A/B rounds all ran on `gpu_h`, so their
# attribution of a 4x two-loop speedup to threading is not safe.
#
# CPU only: the GPU column of the A/B was never claimed (its run-to-run scatter
# was as large as the effect), so paying for it here buys nothing.
#$ -cwd
#$ -l node_f=1
#$ -l h_rt=1:30:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/lbfgs-excl/uge.log

set -euo pipefail

FS=/gs/fs/tga-kozuma-kouhi/uk07267
BASE=${SBEC_BASE:-$FS/wt-lbfgs-base}
OPT=${SBEC_OPT:-$FS/wt-lbfgs}
GRID=${SBEC_GRID:-24}
AB_THREADS=${SBEC_AB_THREADS:-8}
SCAN_THREADS=${SBEC_SCAN_THREADS:-"1 4 16 48"}
OUT=$FS/lbfgs-excl
mkdir -p "$OUT"

. /etc/profile.d/modules.sh
module load cuda/12.8.0 2>/dev/null || module load cuda 2>/dev/null || true
[[ -n "${CUDA_HOME:-}" ]] && export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

export JULIA_DEPOT_PATH="${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/shared/.julia"
mkdir -p "${T4_TMPDIR:-/tmp}/.julia"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
export SPINORBEC_SCRATCH_DIR="${T4_TMPDIR:-/tmp}/spinorbec_snaps"
mkdir -p "$SPINORBEC_SCRATCH_DIR"

echo "[excl] host=$(hostname) cores=$(nproc) grid=${GRID}"
echo "[excl] base=$(git -C "$BASE" rev-parse --short HEAD)  opt=$(git -C "$OPT" rev-parse --short HEAD)"
diff -q "$BASE/bench/bench_lbfgs.jl" "$OPT/bench/bench_lbfgs.jl" \
    && echo "[excl] bench file identical in both arms" \
    || { echo "[excl] ABORT: bench file differs between arms"; exit 1; }

# ── A/B at a fixed thread count, both arms back to back ──────────────
for entry in "base:$BASE" "opt:$OPT"; do
    tag=${entry%%:*}; root=${entry#*:}
    echo "########## A/B revision=$tag threads=$AB_THREADS ##########"
    cd "$root"
    JULIA_NUM_THREADS=$AB_THREADS "$JULIA" --project=. bench/bench_lbfgs.jl cpu "$GRID" \
        2>&1 | tee "$OUT/ab_${tag}.out"
done

# ── thread scan on each arm: is the threading doing anything at all? ──
for entry in "base:$BASE" "opt:$OPT"; do
    tag=${entry%%:*}; root=${entry#*:}
    cd "$root"
    for n in $SCAN_THREADS; do
        echo "########## scan revision=$tag threads=$n ##########"
        JULIA_NUM_THREADS=$n "$JULIA" --project=. bench/bench_lbfgs.jl cpu "$GRID" \
            2>&1 | tee "$OUT/scan_${tag}_${n}.out"
    done
done

echo "[excl] done"
