#!/bin/bash
#$ -cwd
#$ -N flower_v8
#$ -l node_q=1
#$ -l h_rt=12:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/flower_v8.log
# Flower v8 (2026-07-16): 96^3, f64, SLOW ramp 10mG->100uG over 100 internal + hold.
# Adiabatic control sibling of edh_v8. Same 96^3 GS cache. Full-grid spin3d -> goto.h5,
# then prune raw. NO psi13 (tomography skipped; disk tight).
set -euo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
VIZPY=/gs/fs/tga-kozuma-kouhi/ue06186/conda_viz/bin/python
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
export FPE_RUNS_ROOT="$DATA"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
GS_CACHE="$PROJECT_ROOT/runs/eu151_edh_vs_flower/cache/gs_10mG_c1_36_96.jld2"
[ -f "$GS_CACHE" ] || { echo "FATAL: 96^3 GS cache missing ($GS_CACHE)"; exit 1; }
echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
echo "=== Flower v8 RTP + Mermin-Ho (96^3, f64, slow ramp->100uG) ==="
"$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl runs/eu151_edh_vs_flower/flower_slow100_v8.yaml
RDIR=$(ls -dt "$DATA"/flower_slow100_v8_*/ 2>/dev/null | head -1)
echo "RDIR=$RDIR"
echo "=== extract full-grid spin3d (stride=1, all frames) ==="
"$JULIA" --project=. scripts/edh_vs_flower/extract_3d.jl "$RDIR/point_001.jld2" "$RDIR/spin3d.jld2" --stride 1 --tstride 1 --box 18 --F 6
echo "=== build goto.h5 (linear ramp 10mG->100uG over 100 internal) ==="
"$VIZPY" scripts/edh_vs_flower/make_goto_tsubame.py "$RDIR/spin3d.jld2" "$RDIR/mermin_ho_diag.jld2" "$RDIR/goto.h5" \
  --quench_dur 100 --B0 0.01 --B1 1.0e-4 --omega 691.15
if [ -f "$RDIR/goto.h5" ] && [ "$(stat -c%s "$RDIR/goto.h5")" -gt 52428800 ]; then
  echo "=== goto OK, pruning raw $RDIR/point_001.jld2 ==="; rm -f "$RDIR/point_001.jld2"
else echo "WARN: goto.h5 missing/small — keeping raw"; fi
echo "=== Flower v8 DONE RDIR=$RDIR ==="; ls -la "$RDIR"
