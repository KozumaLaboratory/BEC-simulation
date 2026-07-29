#!/bin/bash
# Efficiency / residual-Jz grid-convergence run: box+-14 / n112 (dx=0.25) — the
# FINE-grid partner to box+-14/n80 (dx=0.35). Distinguishes whether the residual
# Jz (grew 3.26->5.16 going 80->coarse) converges to 0 (numeric) or floors
# (physical dissipation -> efficiency = conversion/(conversion+dissipation)).
# Conversion itself is box/grid-ROBUST (Fz -> +1.9..2.1); only the residual moves.
#
# NVMe gotcha: 112^3 f32 ~= 146 MB/frame; node-local NVMe scratch overflows ->
# tmp->Lustre EXDEV. FIX = keep NVMe (Lustre mmap SIGBUSes) and SHRINK snapshot
# volume via RB_SAVE_EVERY=2000 (see gotcha tsubame_nvme_scratch_overflow_exdev).
# Do NOT move scratch to Lustre.
#
# Pair with a dt-check: resubmit with RB_DT=0.0002 RB_TAG=eff_dt2e4 (same grid)
# to separate time-discretisation from spatial-grid residual.
#
# Usage (SMOKE FIRST on TSUBAME before the full run):
#   qsub -g tga-kozuma-kouhi -v SMOKE=1 runs/eu_barnett_rotfield_clean/tsubame_efficiency.sh   # ~2 min sanity
#   qsub -g tga-kozuma-kouhi runs/eu_barnett_rotfield_clean/tsubame_efficiency.sh              # full
#
#$ -cwd
#$ -N eu_barnett_eff
#$ -l gpu_1=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o logs/tsubame/eff.log
set -euo pipefail

REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup

export RB_BOX="${RB_BOX:-28.0, 28.0, 14.0}"     # box+-14
export RB_N="${RB_N:-112, 112, 56}"             # dx = 0.25
export RB_DT="${RB_DT:-0.0004}"
export RB_SAVE_EVERY="${RB_SAVE_EVERY:-2000}"    # fit 112^3 f32 jld2 in node NVMe
export RB_TAG="${RB_TAG:-eff}"
# +Omega (headline sense); RB_STIR_BXPHASE default +pi/2

source scripts/tsubame_setup.sh    # node-local NVMe SPINORBEC_SCRATCH_DIR (mmap-OK) — KEEP IT.

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== EFFICIENCY node $(hostname) $(date) box=$RB_BOX n=$RB_N dt=$RB_DT save=$RB_SAVE_EVERY tag=$RB_TAG SMOKE=${SMOKE:-0} SCRATCH=$SPINORBEC_SCRATCH_DIR ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_rebuild.jl
echo "=== done $(date) ==="
