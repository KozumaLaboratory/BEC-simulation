#!/bin/bash
# TSUBAME (UGE) submit: one static branch continuation (#335 stage A).
#
#   qsub -g tga-kozuma-kouhi -N hb_up18 \
#     -v HB_KAPPA=1.8,HB_DIR=up,HB_BMIN=20,HB_BMAX=200,HB_DB=5,HB_OUT=... \
#     scripts/eu_hysteresis/submit_branch.sh
#
# `-o` must name an EXISTING directory or the job never starts.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=24:00:00
#$ -j y
#$ -o logs/tsubame/
source "$(dirname "$0")/_preamble.sh"

export HB_KAPPA="${HB_KAPPA:-1.8}"
export HB_GRID="${HB_GRID:-32}"
export HB_BOX="${HB_BOX:-24.0}"
export HB_DIR="${HB_DIR:-up}"
export HB_BMIN="${HB_BMIN:-20}"
export HB_BMAX="${HB_BMAX:-200}"
export HB_DB="${HB_DB:-5}"
export HB_PIN="${HB_PIN:-0.002}"
export HB_LADDER="${HB_LADDER:-0.008,0.004,0.002}"
export HB_LADDER_ANCHOR="${HB_LADDER_ANCHOR:-0.02,0.01,0.005,0.002}"
export HB_LBFGS="${HB_LBFGS:-400}"
export HB_TOL="${HB_TOL:-1e-5}"
export HB_CERT="${HB_CERT:-1}"
export HB_PADDING="${HB_PADDING:-0}"
export HB_OUT="${HB_OUT:-$EU335_OUT/branch_k${HB_KAPPA}_${HB_DIR}_g${HB_GRID}}"
[ -n "${HB_ANCHOR_FILE:-}" ] && export HB_ANCHOR_FILE
[ -n "${HB_ANCHOR_STATE:-}" ] && export HB_ANCHOR_STATE
[ -n "${HB_RESIDUAL:-}" ] && export HB_RESIDUAL
[ -n "${HB_SMOKE:-}" ] && export HB_SMOKE

echo "=== branch continuation κ=$HB_KAPPA dir=$HB_DIR grid=$HB_GRID B=$HB_BMIN..$HB_BMAX ΔB=$HB_DB pin=$HB_PIN ==="
"$JULIA" --project=. scripts/eu_hysteresis/branch_continuation.jl
echo "=== done $(date) → $HB_OUT ==="
