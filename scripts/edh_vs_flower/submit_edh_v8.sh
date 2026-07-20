#!/bin/bash
#$ -cwd
#$ -N edh_v8
#$ -l node_q=1
#$ -l h_rt=12:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/edh_v8.log
# EdH v8 (2026-07-16): 96^3, f64, MODERATE ramp 10mG->26uG over 15 internal + hold.
# Reuses the existing 96^3 GS cache (gs_10mG_c1_36_96.jld2). Extracts full-grid
# spin3d (stride=1, all frames) -> goto.h5 for the CSS-ness renders, then prunes
# the raw psi snapshots (disk is tight: ~102 GB free). NO psi13 (tomography skipped).
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
echo "=== EdH v8 RTP + Mermin-Ho (96^3, f64, ramp->26uG) ==="
"$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl runs/eu151_edh_vs_flower/edh_ramp26_v8.yaml
RDIR=$(ls -dt "$DATA"/edh_ramp26_v8_*/ 2>/dev/null | head -1)
echo "RDIR=$RDIR"
echo "=== extract full-grid spin3d (stride=1, all frames) ==="
"$JULIA" --project=. scripts/edh_vs_flower/extract_3d.jl "$RDIR/point_001.jld2" "$RDIR/spin3d.jld2" --stride 1 --tstride 1 --box 18 --F 6
echo "=== build goto.h5 (linear ramp 10mG->26uG over 15 internal) ==="
"$VIZPY" scripts/edh_vs_flower/make_goto_tsubame.py "$RDIR/spin3d.jld2" "$RDIR/mermin_ho_diag.jld2" "$RDIR/goto.h5" \
  --quench_dur 15 --B0 0.01 --B1 2.6e-5 --omega 691.15
# prune raw ONLY after goto.h5 verified (> 50 MB)
if [ -f "$RDIR/goto.h5" ] && [ "$(stat -c%s "$RDIR/goto.h5")" -gt 52428800 ]; then
  echo "=== goto OK, pruning raw $RDIR/point_001.jld2 ==="; rm -f "$RDIR/point_001.jld2"
else echo "WARN: goto.h5 missing/small — keeping raw"; fi
echo "=== EdH v8 DONE RDIR=$RDIR ==="; ls -la "$RDIR"
