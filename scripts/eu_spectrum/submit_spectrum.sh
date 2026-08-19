#!/bin/bash
# TSUBAME (UGE) submit: branch-spectrum certification (#339 → docs/guides/eu_spinodal_spectrum.md).
#
#   qsub -g tga-kozuma-kouhi -N sp18 -v SP_CELLS=...,SP_CELLS_N=8 \
#     scripts/eu_spectrum/submit_spectrum.sh
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o logs/tsubame/
# Shares #335's preamble: same tree, same julia, same CUDA assertion, same
# refusal to run from a dirty src/. The campaigns read the SAME cells, so a
# second copy of that environment is a second thing to drift.
source "${EU335_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu335}/scripts/eu_hysteresis/_preamble.sh"

export SP_KAPPA="${SP_KAPPA:-1.8}"
export SP_GRID="${SP_GRID:-32}"
export SP_PIN="${SP_PIN:-0.002}"
export SP_NEV="${SP_NEV:-6}"
export SP_MAXITER="${SP_MAXITER:-40}"
export SP_OUT="${SP_OUT:-$EU335_OUT/spectrum_k${SP_KAPPA}_g${SP_GRID}}"
# `;`-separated, like SB_CELLS: `qsub -v` cuts a value at the first comma, and a
# one-cell run is indistinguishable from one that was asked for. SP_CELLS_N is
# cross-checked by the driver.
for v in SP_CELLS SP_CELLS_N SP_BLOCK SP_HESS_TOL SP_FD_EPS SP_FD_EPS2 \
         SP_STATIONARY_TOL SP_FIT_BMIN SP_BSP_REF SP_BSP_TOL SP_PADDING \
         SP_DEALIAS SP_SKIP_CONTROLS; do
    [ -n "${!v:-}" ] && export "$v"
done

echo "=== branch spectrum κ=$SP_KAPPA grid=$SP_GRID nev=$SP_NEV max_iter=$SP_MAXITER ==="
"$JULIA" --project=. scripts/eu_spectrum/branch_spectrum.jl
echo "=== done $(date) → $SP_OUT ==="
