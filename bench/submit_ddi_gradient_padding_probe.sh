#!/bin/bash
# UGE submission (uk07267 / tga-kozuma-kouhi): how far the DDI gradient-padding
# fix moves a ground state.
#
#   qsub -g tga-kozuma-kouhi -N ddipad_probe bench/submit_ddi_gradient_padding_probe.sh
#
# Both revisions in ONE job on ONE node: the quantity is a difference between
# two solves, and a difference measured across two jobs carries a node-to-node
# confound into the only number the decision rests on.
#
# `before` is plain `origin/main` (padded energy, unpadded gradient); `after` is
# the fix. Everything else — spec, solver, seed — is identical, and the probe
# script is the SAME FILE in both worktrees.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=1:30:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/ddi-pad-probe/uge.log

set -euo pipefail

FS=/gs/fs/tga-kozuma-kouhi/uk07267
BEFORE=${SBEC_BEFORE:-$FS/wt-ddi-before}
AFTER=${SBEC_AFTER:-$FS/wt-ddi-pad}
OUT=$FS/ddi-pad-probe
mkdir -p "$OUT"

. /etc/profile.d/modules.sh
module load cuda/12.8.0 2>/dev/null || module load cuda 2>/dev/null || true
[[ -n "${CUDA_HOME:-}" ]] && export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

export JULIA_DEPOT_PATH="${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/shared/.julia"
mkdir -p "${T4_TMPDIR:-/tmp}/.julia"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
export JULIA_NUM_THREADS=${JULIA_NUM_THREADS:-8}
export SPINORBEC_SCRATCH_DIR="${T4_TMPDIR:-/tmp}/spinorbec_snaps"
mkdir -p "$SPINORBEC_SCRATCH_DIR"

echo "[ddipad] host=$(hostname)"
echo "[ddipad] before=$(git -C "$BEFORE" rev-parse --short HEAD)  after=$(git -C "$AFTER" rev-parse --short HEAD)"
diff -q "$BEFORE/bench/probe_ddi_gradient_padding.jl" \
        "$AFTER/bench/probe_ddi_gradient_padding.jl" \
    && echo "[ddipad] probe script identical in both arms" \
    || { echo "[ddipad] ABORT: probe script differs between arms"; exit 1; }

for entry in "before:$BEFORE" "after:$AFTER"; do
    tag=${entry%%:*}; root=${entry#*:}
    echo "########## $tag ##########"
    cd "$root"
    "$JULIA" --project=. bench/probe_ddi_gradient_padding.jl solve "$OUT/$tag.jld2" \
        2>&1 | tee "$OUT/$tag.out"
done

echo "########## comparison ##########"
cd "$AFTER"
"$JULIA" --project=. bench/probe_ddi_gradient_padding.jl compare \
    "$OUT/before.jld2" "$OUT/after.jld2" 2>&1 | tee "$OUT/compare.out"

echo "[ddipad] done"
