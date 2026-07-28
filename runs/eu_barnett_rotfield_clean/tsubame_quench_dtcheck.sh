#!/bin/bash
# Fast quench-only dt-check (~13 min): quench at dt=2e-4 from the SAME box+-14/n80
# +Omega stir end-state (rb_stir_8315c9e8) that fed the existing dt=4e-4 quench.
# Compare Jz(t)/Fz(t) vs rebuild_box14_tsubame/traj_box14n80_quench.csv (dt=4e-4).
#
#$ -cwd
#$ -N eu_barnett_qdt
#$ -l gpu_1=1
#$ -l h_rt=1:00:00
#$ -j y
#$ -o logs/tsubame/quench_dtcheck.log
set -euo pipefail

REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup

export RB_STIR_SRC="runs/rb_stir_8315c9e8/point_001.jld2"
export RB_BOX="28.0, 28.0, 14.0"
export RB_N="80, 80, 40"
export RB_DT="0.0002"          # HALF the reference dt (4e-4)
export RB_QUENCH="20.0"        # 20 units -> ~100k steps -> ~13 min
export RB_SAVE_EVERY="500"
export RB_TAG="dtcheck"

source scripts/tsubame_setup.sh

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== QUENCH-DTCHECK node $(hostname) $(date) src=$RB_STIR_SRC dt=$RB_DT quench=$RB_QUENCH SCRATCH=$SPINORBEC_SCRATCH_DIR ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_quench_dtcheck.jl
echo "=== done $(date) ==="
