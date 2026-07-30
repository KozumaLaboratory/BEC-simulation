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
#$ -cwd
#$ -l node_f=1
#$ -l h_rt=1:30:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/lbfgs-blas/uge.log

set -euo pipefail

FS=/gs/fs/tga-kozuma-kouhi/uk07267
BASE=${SBEC_BASE:-$FS/wt-lbfgs-base}
OPT=${SBEC_OPT:-$FS/wt-lbfgs}
GRID=${SBEC_GRID:-24}
OUT=$FS/lbfgs-blas
mkdir -p "$OUT"

. /etc/profile.d/modules.sh
module load cuda/12.8.0 2>/dev/null || module load cuda 2>/dev/null || true
[[ -n "${CUDA_HOME:-}" ]] && export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

export JULIA_DEPOT_PATH="${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/shared/.julia"
mkdir -p "${T4_TMPDIR:-/tmp}/.julia"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
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

# The decisive pair: baseline with Julia single-threaded, BLAS left at the
# machine default vs pinned to 1. If the two-loop collapses on the second, the
# cost was the thread team, not the memory traffic.
run_one base "$BASE" 1 default
run_one base "$BASE" 1 1
run_one opt "$OPT" 1 default
run_one opt "$OPT" 1 1
# Then with Julia threading on, to see what it adds once BLAS is pinned.
run_one base "$BASE" 16 1
run_one opt "$OPT" 16 1

echo "[blas] done"
