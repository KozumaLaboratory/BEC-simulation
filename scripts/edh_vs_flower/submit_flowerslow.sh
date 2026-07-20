#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=8:00:00
#$ -j y
# VERY SLOW (adiabatic) flower-method parabolic ramps: 10mG -> {0, -60uG} over
# TDESC=2400 internal (~3.5 s), then hold 600 internal (~0.87 s). NO 3-body loss
# (clean adiabaticity study). Same fixed-Hamiltonian resim GS cache. save every
# 20000 steps (~75 frames). RUN=fl0slow | flm60slow. Output edh_vs_flower_slow.
set -uo pipefail
RUN="${RUN:?set -v RUN=fl0slow|flm60slow}"
case "$RUN" in
  fl0slow)   CFG=runs/eu151_edh_vs_flower/ramp_sweep/ramp_par_fl0_slow.yaml;   OUT=fl0slow ;;
  flm60slow) CFG=runs/eu151_edh_vs_flower/ramp_sweep/ramp_par_flm60_slow.yaml; OUT=flm60slow ;;
  *) echo "bad RUN=$RUN"; exit 2 ;;
esac
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_slow
mkdir -p "$DATA"; cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
export FPE_RUNS_ROOT="$DATA/${OUT}_run"; mkdir -p "$FPE_RUNS_ROOT"
echo "=== [$RUN] warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
echo "=== [$RUN] run $CFG (VERY SLOW, no loss) ==="
"$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl "$CFG" </dev/null || { echo "FATAL $RUN"; exit 1; }
RD=$(ls -dt "$FPE_RUNS_ROOT"/*/ | head -1); RESULT=$(ls -S "$RD"*.jld2 | head -1)
echo "RD=$RD RESULT=$RESULT"
echo "=== [$RUN] extract psi13 ==="
"$JULIA" --project=. scripts/edh_vs_flower/extract_psi13.jl "$RESULT" "$DATA/${OUT}_psi13.jld2" \
  --stride 2 --tstride 1 --box 18 --F 6 --dtype f32 </dev/null || { echo "extract FAILED $RUN"; exit 1; }
cp "$RD/mermin_ho_diag.jld2" "$DATA/${OUT}_diag.jld2" 2>/dev/null || true
rm -f "$RD"/point_001.jld2 "$RD"/result.jld2
echo "=== [$RUN] done ==="; ls -la "$DATA/${OUT}_psi13.jld2"
