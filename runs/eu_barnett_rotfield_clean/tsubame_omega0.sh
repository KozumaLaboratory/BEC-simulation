#!/bin/bash
# Omega=0 chirality CONTROL (two-stage, box+-10/n80, matches the +-Omega runs).
# LARMOR-FREE: RB_STIR_AMP=0 -> NO stir field (B=0 through the whole dynamics; the
# GS still uses its transverse field to prepare |F|=6, F_z=0). No field -> no Larmor
# precession, no vortex -> F_z stays ~0. This is the correct "no rotation" control
# (a static Omega=0 field would instead Larmor-precess the transverse spin). Completes
# fig3 to 3 points (+Omega +2.10 / 0 flat / -Omega -0.42): "no rotation -> no axial
# magnetisation; reverse rotation -> reverse sign" = mechanical Barnett in one panel.
# ~38 min (same as the box+-10 headline).
#
#$ -cwd
#$ -N eu_barnett_om0
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o logs/tsubame/omega0.log
set -euo pipefail

REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup

export RB_BOX="20.0, 20.0, 10.0"     # box+-10 (same as +-Omega runs)
export RB_N="80, 80, 40"
export RB_DT="0.0004"
export RB_SAVE_EVERY="1500"          # coarse frames: control only needs a flat F_z(t); avoids node-NVMe overflow SIGBUS (gotcha nvme_scratch)
export RB_STIR_AMP="0.0"              # NO stir field -> B=0 throughout -> Larmor-free control
export RB_TAG="omega0"

source scripts/tsubame_setup.sh

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== OMEGA0 node $(hostname) $(date) box=$RB_BOX n=$RB_N stir_amp=$RB_STIR_AMP tag=$RB_TAG SCRATCH=$SPINORBEC_SCRATCH_DIR ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_rebuild.jl
echo "=== done $(date) ==="
