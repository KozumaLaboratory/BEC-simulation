#!/bin/bash
# UGE submission (uk07267 / tga-kozuma-kouhi): L-BFGS solver benchmark, A/B.
#
#   qsub -g tga-kozuma-kouhi -N lbfgs_ab bench/submit_lbfgs_bench.sh
#
# The revisions default to the two standing worktrees below. Override with
# SBEC_ROOTS, but note UGE's `-v` splits on commas AND on whitespace, so a
# multi-root override has to be exported by an outer wrapper, not passed as
# a single -v value.
#
# Both revisions run back-to-back in ONE job on ONE node, so the comparison
# carries no node-to-node or queue-epoch confound — and it costs one queue
# wait instead of two. -g is a qsub CLI flag, never a #$ directive.
#
# node_q = 1 H100 + 48 cores (exclusive quarter node): the CPU half of this
# benchmark must not be sharing cores with someone else's job.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o /gs/bs/work/7/uk07267/lbfgs-bench/uge.log

set -euo pipefail

ROOTS=${SBEC_ROOTS:-"base:/gs/bs/work/7/uk07267/bec-perf-lbfgs-base opt:/gs/bs/work/7/uk07267/bec-perf-lbfgs"}
GRIDS=${SBEC_GRIDS:-}
BACKENDS=${SBEC_BACKENDS:-"cpu gpu"}
OUT=/gs/bs/work/7/uk07267/lbfgs-bench
mkdir -p "$OUT"

. /etc/profile.d/modules.sh
module load cuda/12.8.0 2>/dev/null || module load cuda 2>/dev/null || true
[[ -n "${CUDA_HOME:-}" ]] && export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

# Writable depot first, shared precompiled depot second (/gs/fs sits at ~98%
# of the group quota, so nothing new is written there).
export JULIA_DEPOT_PATH=/gs/bs/work/7/uk07267/perf-lbfgs-depot:/gs/fs/tga-kozuma-kouhi/shared/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia

# Fixed thread count so the two revisions are compared like for like.
export JULIA_NUM_THREADS=8
export SPINORBEC_SCRATCH_DIR="${T4_TMPDIR:-/tmp}/spinorbec_snaps"
mkdir -p "$SPINORBEC_SCRATCH_DIR"

echo "[lbfgs_bench] host=$(hostname)"
nvidia-smi --query-gpu=name --format=csv,noheader || true

for entry in $ROOTS; do
    tag=${entry%%:*}
    root=${entry#*:}
    echo "================ revision=$tag  root=$root  commit=$(git -C "$root" rev-parse --short HEAD) ================"
    cd "$root"
    for be in $BACKENDS; do
        echo "########## revision=$tag backend=$be ##########"
        "$JULIA" --project=. bench/bench_lbfgs.jl "$be" $GRIDS \
            2>&1 | tee "$OUT/lbfgs_${tag}_${be}.out"
    done
done

echo "[lbfgs_bench] done"
