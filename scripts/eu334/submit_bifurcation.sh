#!/bin/bash
# TSUBAME (UGE) submit: one condensate-number branch continuation (#334 stage A).
#
#   qsub -g tga-kozuma-kouhi -N nb32 -l h_rt=8:00:00 \
#     -v NB_GRID=32,NB_NF=25,NB_OUT=... scripts/eu334/submit_bifurcation.sh
#
# `-o` must name an EXISTING directory or the job never starts.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=12:00:00
#$ -j y
#$ -o logs/tsubame/
source "${EU334_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu334}/scripts/eu334/_preamble.sh"

export NB_KAPPA="${NB_KAPPA:-1.8}"
export NB_B="${NB_B:-20.0}"
export NB_GRID="${NB_GRID:-32}"
export NB_BOX="${NB_BOX:-24.0}"
export NB_PIN="${NB_PIN:-0.002}"
export NB_FMIN="${NB_FMIN:-0.02}"
export NB_FMAX="${NB_FMAX:-1.0}"
export NB_NF="${NB_NF:-25}"
export NB_LBFGS="${NB_LBFGS:-400}"
export NB_ITP="${NB_ITP:-2000}"
export NB_TOL="${NB_TOL:-1e-5}"
export NB_SEEDS="${NB_SEEDS:-$EU334_SEEDS}"
export NB_OUT="${NB_OUT:-$EU334_OUT/bifurcation_k${NB_KAPPA}_g${NB_GRID}}"
[ -n "${NB_LADDER:-}" ] && export NB_LADDER NB_LADDER_N
[ -n "${NB_ANCHOR_FLOWER:-}" ] && export NB_ANCHOR_FLOWER
[ -n "${NB_ANCHOR_POLAR:-}" ] && export NB_ANCHOR_POLAR
[ -n "${NB_SMOKE:-}" ] && export NB_SMOKE

echo "=== bifurcation κ=$NB_KAPPA B=$NB_B grid=$NB_GRID f=$NB_FMIN..$NB_FMAX ($NB_NF cells) ==="
"$JULIA" --project=. scripts/eu334/nucleation_bifurcation.jl
echo "=== done $(date) → $NB_OUT ==="
