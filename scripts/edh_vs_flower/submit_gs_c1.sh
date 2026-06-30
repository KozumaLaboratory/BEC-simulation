#!/bin/bash
#$ -cwd
#$ -N gs_traj_c1
#$ -l gpu_h=1
#$ -l h_rt=3:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_v3/gs_traj_c1.log
set -euo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
OUT=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_v3
mkdir -p "$OUT"; cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
echo "=== gs_trajectory c1=1/36 ==="
"$JULIA" --project=. scripts/edh_vs_flower/gs_trajectory.jl \
  "$OUT/gs_trajectory_c1_36.jld2" "$PROJECT_ROOT/runs/eu151_edh_vs_flower/cache/gs_10mG_c1_36.jld2" \
  --backend gpu --record_every 50 --itp_steps 20000 --lbfgs_steps 500 --c1_ratio 1/36
echo "=== done ==="
