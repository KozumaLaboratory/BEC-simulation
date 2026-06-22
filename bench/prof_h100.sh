#!/bin/bash
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=0:40:00
#$ -N prof_h100
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
set -e
GRP=tga-kozuma-kouhi
export JULIA_DEPOT_PATH=/gs/fs/$GRP/shared/.julia
JULIA=/gs/fs/$GRP/shared/.juliaup/bin/julia
cd /gs/fs/$GRP/uk07267/BEC-opt
mkdir -p logs
echo "host=$(hostname) date=$(date)"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader || true
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println(CUDA.name(CUDA.device()))'
echo "=== 128 f64 ==="
$JULIA --project=. bench/profile_1step_gpu.jl 128 f64
echo "ALLDONE"
