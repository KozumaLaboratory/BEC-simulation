#!/bin/bash
#$ -cwd
#$ -N linsweep
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/linsweep.log
# Linear ramp-speed sweep: 10 mG -> 26 uG LINEARLY over T (0.14,2,8,30,90 internal
# = 0.2,2.9,11.6,43,130 ms), then hold 58 ms. Extract psi13 for each to study the
# checkerboard-inversion in Goto difference imaging vs ramp speed.
set -uo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
for T in T0p14 T2 T8 T30 T90; do
  echo "=== run lin_$T ==="
  export FPE_RUNS_ROOT="$DATA/linsweep_run_$T"; mkdir -p "$FPE_RUNS_ROOT"
  CFG=runs/eu151_edh_vs_flower/ramp_sweep/ramp_lin_$T.yaml
  "$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl "$CFG" </dev/null || { echo "FATAL $T"; continue; }
  RD=$(ls -dt "$FPE_RUNS_ROOT"/*/ | head -1); RESULT=$(ls -S "$RD"*.jld2 | head -1)
  "$JULIA" --project=. scripts/edh_vs_flower/extract_psi13.jl "$RESULT" "$DATA/lin_${T}_psi13.jld2" \
    --stride 2 --tstride 1 --box 18 --F 6 --dtype f32 </dev/null || { echo "extract FAIL $T"; continue; }
  cp "$RD/mermin_ho_diag.jld2" "$DATA/lin_${T}_diag.jld2" 2>/dev/null || true
  rm -f "$RD"/point_001.jld2 "$RD"/result.jld2
  echo "=== done lin_$T ==="; ls -la "$DATA/lin_${T}_psi13.jld2"
done
echo "=== ALL LINSWEEP DONE ==="