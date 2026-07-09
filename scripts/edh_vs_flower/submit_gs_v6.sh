#!/bin/bash
#$ -cwd
#$ -N gs_v6
#$ -l node_q=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/gs_v6.log
# 96^3 c1=1/36 ground state at 10 mG (random -> ITP -> LBFGS Sobolev 0.5).
# Writes the cache both v6 configs load: cache/gs_10mG_c1_36_96.jld2
set -euo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
mkdir -p "$DATA"; cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
echo "=== GS trajectory 96^3 c1=1/36 ==="
"$JULIA" --project=. scripts/edh_vs_flower/gs_trajectory.jl \
  "$DATA/gs_trajectory_c1_36_96.jld2" \
  "$PROJECT_ROOT/runs/eu151_edh_vs_flower/cache/gs_10mG_c1_36_96.jld2" \
  --backend gpu --n 96 --record_every 100 --itp_steps 20000 --lbfgs_steps 800 --c1_ratio 1/36
echo "=== done: cache/gs_10mG_c1_36_96.jld2 ==="
ls -la "$PROJECT_ROOT/runs/eu151_edh_vs_flower/cache/gs_10mG_c1_36_96.jld2"
