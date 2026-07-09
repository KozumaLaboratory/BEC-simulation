#!/bin/bash
#$ -cwd
#$ -N edh_v6
#$ -l node_q=1
#$ -l h_rt=12:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/edh_v6.log
# EdH v6: 96^3, f64 snapshots, c1=1/36, K3=2.1e-41. RTP + Mermin-Ho + FULL-GRID
# extraction (stride=1, psi13 in f64). Deletes the raw point_001 after a verified
# extraction to save group disk. Depends on cache/gs_10mG_c1_36_96.jld2 (gs_v6).
set -euo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
export FPE_RUNS_ROOT="$DATA"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
GS_CACHE="$PROJECT_ROOT/runs/eu151_edh_vs_flower/cache/gs_10mG_c1_36_96.jld2"
[ -f "$GS_CACHE" ] || { echo "FATAL: 96^3 GS cache missing ($GS_CACHE) — gs_v6 must finish first"; exit 1; }
echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
echo "=== EdH v6 RTP + Mermin-Ho diagnostic (96^3, f64, c1=1/36, K3=2.1e-41) ==="
"$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl runs/eu151_edh_vs_flower/edh_quench_v6.yaml
RDIR=$(ls -dt "$DATA"/edh_quench_v6_*/ 2>/dev/null | head -1)
echo "=== extract FULL GRID (stride=1) from $RDIR ==="
"$JULIA" --project=. scripts/edh_vs_flower/extract_slices.jl "$RDIR/point_001.jld2" "$RDIR/slices.jld2" --tstride 1
"$JULIA" --project=. scripts/edh_vs_flower/extract_3d.jl   "$RDIR/point_001.jld2" "$RDIR/spin3d.jld2"       --stride 1 --tstride 1 --box 18 --F 6
"$JULIA" --project=. scripts/edh_vs_flower/extract_psi13.jl "$RDIR/point_001.jld2" "$DATA/edh_v6_psi13.jld2" --stride 1 --tstride 1 --box 18 --F 6 --dtype f64
# prune the raw snapshots ONLY after a good extraction (psi13 > 100 MB)
if [ -f "$DATA/edh_v6_psi13.jld2" ] && [ "$(stat -c%s "$DATA/edh_v6_psi13.jld2")" -gt 104857600 ]; then
  echo "=== extraction OK, pruning raw $RDIR/point_001.jld2 ==="; rm -f "$RDIR/point_001.jld2"
fi
echo "=== done RDIR=$RDIR ==="; ls -la "$RDIR" "$DATA/edh_v6_psi13.jld2"
