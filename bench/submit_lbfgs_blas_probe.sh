#!/bin/bash
# UGE submission (uk07267 / tga-kozuma-kouhi): is the L-BFGS two-loop's cost
# OpenBLAS thread-team overhead on level-1 calls?
#
#   qsub -g tga-kozuma-kouhi -N lbfgs_blas bench/submit_lbfgs_blas_probe.sh
#
# The observation that prompted this (2026-07-30, node_f, 24^3 x D=13, m=20):
# the pre-branch two-loop measured 31.5 ms on a 4-core allocation, ~205 ms on a
# 384-core one. Same code, same array size, monotonic in the MACHINE's core
# count. 205 ms over 40 dots + 40 axpys on 2.87 MB arrays is ~1.1 GB/s, about
# 15x below one core's streaming bandwidth — far too slow to be memory.
#
# OpenBLAS sizes its thread team from the machine, and `dot` on a
# ComplexF64 array dispatches to `zdotc`. A level-1 call on a few-MB array is
# all team spawn/barrier and no work, and that overhead grows with the core
# count. If that is the mechanism, `OPENBLAS_NUM_THREADS=1` collapses the
# baseline's two-loop on its own — meaning a one-line BLAS setting reaches most
# of what the branch's hand-written reduction reached, which is worth knowing
# before defending the rewrite.
#
# JULIA_NUM_THREADS is pinned to 1 for the first four runs so Julia-level
# threading cannot confound the BLAS axis; the last two re-check at 16.
#
# node_q, not node_f: 48 cores is the autopilot's `default` profile, so it is
# the configuration production actually runs in. The BLAS effect scales with
# the machine's core count and is still plainly visible there.
#
# SBEC_BENCH_SECONDS=300 per point. The previous 4-vs-20-step estimator put ~1 s
# on each arm and differenced two minima, which measured startup: the baseline
# cells moved up to 20 % between jobs on that.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=3:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/lbfgs-blas5/uge.log

set -euo pipefail

FS=/gs/fs/tga-kozuma-kouhi/uk07267
BASE=${SBEC_BASE:-$FS/wt5-lbfgs-base}
OPT=${SBEC_OPT:-$FS/wt5-lbfgs}
GRID=${SBEC_GRID:-24}
OUT=$FS/lbfgs-blas5
mkdir -p "$OUT"

. /etc/profile.d/modules.sh
module load cuda/12.8.0 2>/dev/null || module load cuda 2>/dev/null || true
[[ -n "${CUDA_HOME:-}" ]] && export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

export JULIA_DEPOT_PATH="${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/shared/.julia"
mkdir -p "${T4_TMPDIR:-/tmp}/.julia"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
export SBEC_BENCH_SECONDS=${SBEC_BENCH_SECONDS:-300}
# One cell: the BLAS question is about a CPU reduction, and the DDI cell would
# double a 6-point matrix into a 12-measurement one (~2.3 h, measured).
export SBEC_BENCH_CELLS=${SBEC_BENCH_CELLS:-contact}
export SPINORBEC_SCRATCH_DIR="${T4_TMPDIR:-/tmp}/spinorbec_snaps"
mkdir -p "$SPINORBEC_SCRATCH_DIR"

echo "[blas] host=$(hostname) cores=$(nproc) grid=${GRID}"
echo "[blas] base=$(git -C "$BASE" rev-parse --short HEAD)  opt=$(git -C "$OPT" rev-parse --short HEAD)"

run_one() {  # tag root julia_threads blas_threads|"default"
    local tag=$1 root=$2 jt=$3 bt=$4
    local -a E=("JULIA_NUM_THREADS=$jt")
    if [ "$bt" != "default" ]; then
        E+=("OPENBLAS_NUM_THREADS=$bt")
    fi
    echo "########## arm=$tag julia_threads=$jt blas_threads=$bt ##########"
    cd "$root"
    env "${E[@]}" "$JULIA" --project=. -e 'using LinearAlgebra; println("reported: blas=", BLAS.get_num_threads(), " julia=", Threads.nthreads())'
    env "${E[@]}" "$JULIA" --project=. bench/bench_lbfgs.jl cpu "$GRID" \
        2>&1 | tee "$OUT/${tag}_j${jt}_b${bt}.out"
}

# Points as `arm:julia_threads:blas_threads`, whitespace separated. Each one is
# a full measurement budget, so trim the list rather than paying for points the
# question does not need.
POINTS=${SBEC_POINTS:-"base:1:default base:1:1 opt:1:default opt:1:1 base:16:1 opt:16:1"}
for pt in $POINTS; do
    IFS=: read -r arm jt bt <<< "$pt"
    case "$arm" in
        base) root=$BASE ;;
        opt) root=$OPT ;;
        *) echo "unknown arm $arm"; exit 1 ;;
    esac
    run_one "$arm" "$root" "$jt" "$bt"
done

echo "[blas] done"
