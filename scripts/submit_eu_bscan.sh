#!/bin/bash
# TSUBAME (UGE) submit for the pinned Eu+DDI B-scan continuation (64³).
# Bakes in the environment fixes learned 2026-07-08 (do not hand-write again):
#   1. julia not on compute-node PATH  -> explicit $JULIA.
#   2. julialauncher needs JULIAUP_DEPOT_PATH (login env only) -> export.
#   3. node-local JULIA_DEPOT_PATH is empty each job -> shared depot (precompiled).
#   4. GPU jobs silently fall back to CPU if CUDA driver missing -> hard guard.
# No large dynamics snapshots here (GS states, ~55 MB/frame jld2 written directly
# to figs/ on Lustre via IOStream, not the mmap snapshot path) — no scratch tweak.
#
# Submit:
#   qsub -g tga-kozuma-kouhi scripts/submit_eu_bscan.sh
# Override run size:
#   qsub -g tga-kozuma-kouhi -v BS_NB=51,BS_LBFGS_CELL=100 scripts/submit_eu_bscan.sh
#
#$ -cwd
#$ -N eu_bscan_pin
#$ -l node_q=1
#$ -l h_rt=24:00:00
#$ -j y
#$ -o logs/tsubame/eu_bscan.log
set -euo pipefail

REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"
mkdir -p logs/tsubame

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia

source scripts/tsubame_setup.sh    # threads + CUDA module + node-local scratch

# --- run parameters (override via `qsub -v`) ---
export BS_GRID="${BS_GRID:-64}"
export BS_BOX="${BS_BOX:-24.0}"
export BS_NB="${BS_NB:-46}"          # 0..90 µG, ΔB=2 µG (≥90 µG not needed)
export BS_BMIN="${BS_BMIN:-0.0}"
export BS_BMAX="${BS_BMAX:-90.0}"
export BS_PIN_EPS="${BS_PIN_EPS:-2e-3}"
export BS_TOL="${BS_TOL:-1e-5}"      # grad-norm early-stop (4 orders below Goldstone floor)
export BS_ITP="${BS_ITP:-1500}"
export BS_NEWTON_ANCHOR="${BS_NEWTON_ANCHOR:-0}"   # Newton = 336 s/iter at 64³, useless on soft manifold
export BS_LBFGS_ANCHOR="${BS_LBFGS_ANCHOR:-400}"   # cap; early-stops ~340 at |∇E|<1e-5
export BS_LBFGS_CELL="${BS_LBFGS_CELL:-150}"       # cap; warm cells early-stop sooner
export BS_SAVE_PSI="${BS_SAVE_PSI:-1}"
export BS_OUT="${BS_OUT:-figs/eu_bscan_pinned}"

echo "=== node $(hostname) $(date) grid=$BS_GRID box=$BS_BOX NB=$BS_NB B=$BS_BMAX..$BS_BMIN µG pin=$BS_PIN_EPS ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional — would silently run on CPU"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. scripts/eu_bscan_pinned_continuation.jl
echo "=== done $(date) — frames in $BS_OUT ==="
