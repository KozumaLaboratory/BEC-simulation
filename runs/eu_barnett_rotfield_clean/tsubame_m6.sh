#!/bin/bash
# Floor-rectification test: m=-6 axial GS + imprinted +-1/0 orbital vortex -> quench
# -> N_m populations. box+-10/n80. SMOKE=1 shrinks for a ~2min sanity pass first.
#
#$ -cwd
#$ -N eu_barnett_m6
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -j y
#$ -o logs/tsubame/m6.log
set -euo pipefail

REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup

export RB_BOX="20.0, 20.0, 10.0"
export RB_N="80, 80, 40"
export RB_DT="0.0004"
if [ "${SMOKE:-0}" = "1" ]; then
  export RB_GS_STEPS="50"; export RB_DUR="2.0"; export RB_SAVE_EVERY="50"
else
  export RB_GS_STEPS="2500"; export RB_DUR="50.0"; export RB_SAVE_EVERY="1000"
fi

source scripts/tsubame_setup.sh
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== M6 node $(hostname) $(date) box=$RB_BOX n=$RB_N dur=$RB_DUR gs=$RB_GS_STEPS SMOKE=${SMOKE:-0} SCRATCH=$SPINORBEC_SCRATCH_DIR ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_m6_imprint.jl
echo "=== done $(date) ==="
