#!/bin/bash
#$ -cwd
#$ -N edh_quench
#$ -l gpu_1=1
#$ -l h_rt=3:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/edh_quench.log
# EdH via fast QUENCH: 10 mG -> 26 uG exponentially in 200 us, then hold at 26 uG.
# Compare to the parabolic par_T90 for the checkerboard-inversion (precession) study.
set -uo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
export FPE_RUNS_ROOT="$DATA/edh_quench_run"; mkdir -p "$FPE_RUNS_ROOT"
CFG=runs/eu151_edh_vs_flower/ramp_sweep/ramp_exp_quench.yaml
echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
echo "=== run quench (exp 10mG->26uG in 200us, hold) ==="
"$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl "$CFG" </dev/null || { echo FATAL; exit 1; }
RD=$(ls -dt "$FPE_RUNS_ROOT"/*/ | head -1)
RESULT=$(ls -S "$RD"*.jld2 | head -1)
echo "RD=$RD RESULT=$RESULT"
echo "=== extract psi13 (stride 2 -> 32^3, f32) ==="
"$JULIA" --project=. scripts/edh_vs_flower/extract_psi13.jl "$RESULT" "$DATA/quench_psi13.jld2" \
  --stride 2 --tstride 1 --box 18 --F 6 --dtype f32 </dev/null || { echo "extract FAILED"; exit 1; }
cp "$RD/mermin_ho_diag.jld2" "$DATA/quench_diag.jld2" 2>/dev/null || echo "no diag"
rm -f "$RD"/point_001.jld2 "$RD"/result.jld2
echo "=== done ==="; ls -la "$DATA/quench_psi13.jld2" "$DATA/quench_diag.jld2"
