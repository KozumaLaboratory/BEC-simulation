#!/bin/bash
#$ -cwd
#$ -N resim_gs
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_resim/resim_gs.log
# Recompute the 64^3 10 mG ground state with the FIXED Hamiltonian, now with the
# AUTO-DERIVED quadratic Zeeman q (gs_trajectory.jl no longer hard-codes q=0).
# Writes a NEW cache (…_resim.jld2) so the old q=0 cache is kept for comparison.
set -euo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_resim
CACHE=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation/runs/eu151_edh_vs_flower/cache/gs_10mG_c1_36_64_resim.jld2
mkdir -p "$DATA" "$(dirname "$CACHE")"; cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
echo "=== fixed-Hamiltonian check ==="
"$JULIA" --project=. -e 'using SpinorBEC; using SpinorBEC: Eu151; println("g_F=",Eu151.g_F,"  q_geometry=",Eu151.q_geometry)'
echo "=== GS 64^3 c1=1/36 @10mG, AUTO q (fixed geometry) ==="
"$JULIA" --project=. scripts/edh_vs_flower/gs_trajectory.jl \
  "$DATA/gs_trajectory_c1_36_64_resim.jld2" "$CACHE" \
  --backend gpu --n 64 --record_every 100 --itp_steps 20000 --lbfgs_steps 800 --c1_ratio 1/36
echo "=== done ==="; ls -la "$CACHE"
