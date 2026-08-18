#!/bin/bash
# TSUBAME (UGE) submit: branch-stability certification (#335).
#
#   qsub -g tga-kozuma-kouhi -N sb18 -v SB_CELLS=...,SB_CONTROL_FLOWER=...,SB_CONTROL_POLAR=... \
#     scripts/eu_hysteresis/submit_stability.sh
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=12:00:00
#$ -j y
#$ -o logs/tsubame/
source "${EU335_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu335}/scripts/eu_hysteresis/_preamble.sh"

export SB_KAPPA="${SB_KAPPA:-1.8}"
export SB_GRID="${SB_GRID:-32}"
export SB_PIN="${SB_PIN:-0.002}"
export SB_ETA="${SB_ETA:-0.01}"
export SB_HOLD_TAU="${SB_HOLD_TAU:-60}"
export SB_REMIN="${SB_REMIN:-600}"
export SB_OUT="${SB_OUT:-$EU335_OUT/stability_k${SB_KAPPA}_g${SB_GRID}}"
# SB_CELLS is `;`-separated: qsub -v cuts a value at the first comma, so a
# comma-joined cell list would arrive as its first cell only — and a one-cell
# stability run is indistinguishable from one that was asked for. SB_CELLS_N is
# cross-checked by the driver.
for v in SB_CELLS SB_CELLS_N SB_CONTROL_FLOWER SB_CONTROL_UNSTABLE_B \
         SB_CONTROL_STABLE_B SB_HOLD_B SB_DEPART SB_FRAMES SB_DT SB_PADDING \
         SB_ETA SB_HOLD_TAU SB_SKIP_CONTROLS; do
    [ -n "${!v:-}" ] && export "$v"
done

echo "=== branch stability κ=$SB_KAPPA grid=$SB_GRID η=$SB_ETA hold=$SB_HOLD_TAU ==="
"$JULIA" --project=. scripts/eu_hysteresis/branch_stability.jl
echo "=== done $(date) → $SB_OUT ==="
