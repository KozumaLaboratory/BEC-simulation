#!/bin/bash
# Ensemble over noise seeds (m=-6 floor, unitary): ell in {0,-1}, M seeds each.
# SMOKE=1: M=2, ell=0, DUR=2 (~sanity: do seeds differ? does reap work?).
#$ -cwd
#$ -N eu_m6_ens
#$ -l gpu_1=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o logs/tsubame/m6ens.log
set -euo pipefail
REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
export RB_BOX="20.0, 20.0, 10.0"; export RB_N="80, 80, 40"; export RB_DT="0.0004"
if [ "${SMOKE:-0}" = "1" ]; then
  export RB_GS_STEPS="400"; export RB_DUR="8.0"; export RB_M="2"; export RB_ELLS="0"; export RB_SAVE_EVERY="500"
else
  export RB_GS_STEPS="2500"; export RB_DUR="50.0"; export RB_M="8"; export RB_ELLS="0,-1"; export RB_SAVE_EVERY="2500"
fi
source scripts/tsubame_setup.sh
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== M6ENS node $(hostname) $(date) M=$RB_M ells=$RB_ELLS dur=$RB_DUR SMOKE=${SMOKE:-0} ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional()'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_m6_ensemble.jl
echo "=== done $(date) ==="
