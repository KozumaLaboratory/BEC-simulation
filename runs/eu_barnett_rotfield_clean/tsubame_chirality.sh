#!/bin/bash
# Chirality (-Omega) run of the two-stage Barnett rebuild. Mirror of the +2.08
# headline (box+-10/n80, SAME grid/dt) with the stir rotation reversed
# (RB_STIR_BXPHASE=-pi/2 -> B(0)=+y unchanged, only the rotation sense flips CW).
# Test: -Omega -> -Fz (Barnett is Omega-odd). Also compare |F|(t) (Fmag column)
# vs the +Omega run for the chiral-depolarisation-symmetry check (P2/P3: CW
# depolarised catastrophically while CCW stayed polarised -> if that leaks into
# the two-stage quench, +Omega/-Omega |F| won't mirror cleanly).
#
# Env fixes are all inherited from run_rebuild.jl + tsubame_setup.sh (see
# tsubame_rebuild_template.sh header). box+-10/n80 needs no RB_SAVE_EVERY bump.
#
# Usage:
#   qsub -g tga-kozuma-kouhi runs/eu_barnett_rotfield_clean/tsubame_chirality.sh
#
#$ -cwd
#$ -N eu_barnett_chir
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -j y
#$ -o logs/tsubame/chir.log
set -euo pipefail

REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup

export RB_BOX="${RB_BOX:-20.0, 20.0, 10.0}"
export RB_N="${RB_N:-80, 80, 40}"
export RB_DT="${RB_DT:-0.0004}"
export RB_SAVE_EVERY="${RB_SAVE_EVERY:-300}"
export RB_TAG=chir
export RB_STIR_BXPHASE=-1.5707963267948966   # -pi/2 -> reverse Omega (CW)

source scripts/tsubame_setup.sh    # node-local NVMe SPINORBEC_SCRATCH_DIR (mmap-OK) — KEEP IT.

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== CHIRALITY node $(hostname) $(date) box=$RB_BOX n=$RB_N dt=$RB_DT bxphase=$RB_STIR_BXPHASE SCRATCH=$SPINORBEC_SCRATCH_DIR ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_rebuild.jl
echo "=== done $(date) ==="
