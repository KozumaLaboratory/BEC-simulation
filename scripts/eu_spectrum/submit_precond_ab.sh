#!/bin/bash
# TSUBAME (UGE) submit: preconditioner A/B on the eu335 cells — #397 + #399.
#
#   qsub -g tga-kozuma-kouhi -N pab -v SP_CELLS='...;...',SP_CELLS_N=6 \
#     scripts/eu_spectrum/submit_precond_ab.sh
#$ -cwd
# gpu_1, not node_q: this is one GPU eigensolve per (cell × arm) and 8 cores is
# plenty, so node_q's 48 slots cost 25 % more (type coefficient 0.250 against
# 0.200) for nothing — same reasoning as eu334/submit_bifurcation.sh.
#$ -l gpu_1=1
#$ -l h_rt=8:00:00
#$ -j y
#$ -o logs/tsubame/
# Same preamble as #335/#383: same tree, same julia, same CUDA assertion, same
# refusal to run from a dirty src/. These are the SAME cells, so a second copy
# of that environment is a second thing to drift.
source "${EU335_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu335}/scripts/eu_hysteresis/_preamble.sh"

export SP_KAPPA="${SP_KAPPA:-1.8}"
export SP_GRID="${SP_GRID:-32}"
export SP_PIN="${SP_PIN:-0.002}"
export PA_OUT="${PA_OUT:-$EU335_OUT/precond_ab}"
# `;`-separated, like SP_CELLS: `qsub -v` cuts a value at the first comma, and a
# one-arm run is indistinguishable from one that was asked for.
for v in SP_CELLS SP_CELLS_N SP_BOX SP_PADDING SP_DEALIAS \
         PA_PRECONDS PA_MAXITERS PA_NEV PA_BLOCK PA_TOL PA_FD_EPS \
         PA_ALPHA_V PA_LANCZOS_NITER PA_SKIP_GAPPED PA_SKIP_CONSUMER_PROBE; do
    [ -n "${!v:-}" ] && export "$v"
done

echo "=== precond A/B  κ=$SP_KAPPA grid=$SP_GRID  preconds=${PA_PRECONDS:-default} maxiters=${PA_MAXITERS:-default} ==="
"$JULIA" --project=. scripts/eu_spectrum/precond_ab.jl
echo "=== done $(date) → $PA_OUT ==="
