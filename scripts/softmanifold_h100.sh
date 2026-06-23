#!/bin/bash
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=6:00:00
#$ -N sm_lambdamin
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
set -e
GRP=tga-kozuma-kouhi
export JULIA_DEPOT_PATH=/gs/fs/$GRP/shared/.julia
JULIA=/gs/fs/$GRP/shared/.juliaup/bin/julia
cd /gs/fs/$GRP/uk07267/BEC-opt
mkdir -p logs
echo "host=$(hostname) date=$(date)"
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader || true
# Production scale (override via env in the qsub -v line if needed).
export SM_GRID=${SM_GRID:-48}
export SM_BOX=${SM_BOX:-24.0}
export SM_B_UG=${SM_B_UG:-10.0}
export SM_DT=${SM_DT:-0.002}
export SM_ITP=${SM_ITP:-8000}
export SM_LBFGS=${SM_LBFGS:-1000}
export SM_NITER=${SM_NITER:-400}
export SM_SEEDS=${SM_SEEDS:-1,2,3}
$JULIA --project=. scripts/eu_softmanifold_lambdamin.jl
echo "ALLDONE"
