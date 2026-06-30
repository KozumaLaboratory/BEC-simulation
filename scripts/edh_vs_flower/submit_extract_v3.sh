#!/bin/bash
#$ -cwd
#$ -N extract_v3j
#$ -l gpu_h=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_v3/extract.log
set -euo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh
module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
for leg in edh_quench_v3_70ba707a flower_smooth_v3_b18d170f; do
  echo "=== extract $leg ==="
  "$JULIA" --project=. scripts/edh_vs_flower/extract_3d.jl \
    "$DATA/$leg/point_001.jld2" "$DATA/$leg/spin3d.jld2" \
    --stride 2 --tstride 2 --box 18 --F 6
done
echo "=== done ==="
