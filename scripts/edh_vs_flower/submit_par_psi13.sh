#!/bin/bash
#$ -cwd
#$ -N par_psi13
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/par_psi13.log
# Re-run the cleanest-EdH parabolic ramp (par_T90) KEEPING psi, and extract the
# FULL 13-component complex spinor (psi13) so we can apply a quantization-axis
# rotation R=exp(-i b F_a) (RF tilt) that mixes ALL m, then re-render with isoviz.
# 64^3 dynamics, psi13 extracted at stride 2 (32^3) / f32 to keep it small.
set -uo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
export FPE_RUNS_ROOT="$DATA/par_psi13_run"; mkdir -p "$FPE_RUNS_ROOT"
CFG=runs/eu151_edh_vs_flower/ramp_sweep/ramp_par_T90.yaml

echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
echo "=== run par_T90 (keep psi) ==="
"$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl "$CFG" </dev/null || { echo FATAL; exit 1; }
RD=$(ls -dt "$FPE_RUNS_ROOT"/*/ | head -1)
RESULT=$(ls -S "$RD"*.jld2 | head -1)
echo "RD=$RD RESULT=$RESULT"
echo "=== extract full 13-component psi13 (stride 2 -> 32^3, f32) ==="
"$JULIA" --project=. scripts/edh_vs_flower/extract_psi13.jl "$RESULT" "$DATA/par_T90_psi13.jld2" \
  --stride 2 --tstride 1 --box 18 --F 6 --dtype f32 </dev/null || { echo "extract FAILED"; exit 1; }
rm -f "$RD"/point_001.jld2 "$RD"/result.jld2
echo "=== done ==="; ls -la "$DATA/par_T90_psi13.jld2"
