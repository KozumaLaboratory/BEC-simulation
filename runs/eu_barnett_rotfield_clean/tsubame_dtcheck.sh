#!/bin/bash
# dt-convergence check: box+-14 / n80 (SAME grid as the existing dt=4e-4 box14n80
# reference) at RB_DT=2e-4 (half). Isolates the TIME-discretisation contribution
# to the residual Jz. n112 fine-GRID is infeasible on one GPU (66x slower/step,
# GS alone 6.5h) -> the dt axis is the feasible way to answer numeric-vs-physical:
#   residual Jz dt-INDEPENDENT -> not time-discretisation -> spatial-grid texture
#     of the decaying vortices -> numeric (finer dx would reduce it) -> efficiency
#     is ~pure conversion.
#   residual Jz dt-DEPENDENT -> time-discretisation -> still numeric (finer dt
#     converges it).
# Either branch => numeric, not physical dissipation. Compare Jz(t) vs
# rebuild_box14_tsubame/traj_box14n80_quench.csv (dt=4e-4).
#
# ~1h expected (dt=4e-4 box14n80 was ~33min; 2x dynamics steps).
#
# Usage: qsub -g tga-kozuma-kouhi runs/eu_barnett_rotfield_clean/tsubame_dtcheck.sh
#
#$ -cwd
#$ -N eu_barnett_dtcheck
#$ -l gpu_1=1
#$ -l h_rt=3:00:00
#$ -j y
#$ -o logs/tsubame/dtcheck.log
set -euo pipefail

REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup

export RB_BOX="28.0, 28.0, 14.0"     # box+-14 (same as the dt=4e-4 reference)
export RB_N="80, 80, 40"             # dx = 0.35, same grid -> isolates dt
export RB_DT="0.0002"                # HALF the reference dt (4e-4)
export RB_SAVE_EVERY="600"           # 2x steps -> 2x save_every keeps ~same #frames
export RB_TAG="dtcheck"
# +Omega (headline sense); RB_STIR_BXPHASE default +pi/2

source scripts/tsubame_setup.sh

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== DTCHECK node $(hostname) $(date) box=$RB_BOX n=$RB_N dt=$RB_DT save=$RB_SAVE_EVERY tag=$RB_TAG SCRATCH=$SPINORBEC_SCRATCH_DIR ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_rebuild.jl
echo "=== done $(date) ==="
