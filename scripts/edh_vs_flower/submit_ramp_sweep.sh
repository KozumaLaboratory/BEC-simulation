#!/bin/bash
#$ -cwd
#$ -N ramp_sweep
#$ -l gpu_1=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/ramp_sweep.log
# EdH magnetic-field RAMP-RATE sweep (user 2026-07-02): quench -> gentle linear
# -> smooth parabolic, NO long hold (descent + 40-internal observation only).
# 64^3 / f64 compute (physics trend, not tomography), f32 snapshots. Reuses the
# proven run_edh_v4.jl (run_yaml + Mermin-Ho diagnostic, now incl. orbital <Lz>).
# gpu_1 (one full H100, ~94GB) — 64^3/f64 (~12-15GB) fits with margin, no MIG
# 12GB hang risk (the 96^3 lesson) and far cheaper than a full node_q. Keeps
# only the small *_diag.jld2 per ramp; deletes the big results.
set -uo pipefail       # NOT -e: one failing ramp must not kill the rest
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
SWEEP=$DATA/ramp_sweep
mkdir -p "$SWEEP"; cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
GS64="$PROJECT_ROOT/runs/eu151_edh_vs_flower/cache/gs_10mG_c1_36_64.jld2"
export FPE_RUNS_ROOT="$SWEEP/runs"; mkdir -p "$FPE_RUNS_ROOT"

echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

if [ ! -f "$GS64" ]; then
  echo "=== GS 64^3 c1=1/36 @ 10 mG (random->ITP->LBFGS sobolev0.5) ==="
  "$JULIA" --project=. scripts/edh_vs_flower/gs_trajectory.jl \
    "$SWEEP/gs_trajectory_c1_36_64.jld2" "$GS64" \
    --backend gpu --n 64 --record_every 100 --itp_steps 20000 --lbfgs_steps 800 --c1_ratio 1/36
fi
[ -f "$GS64" ] || { echo "FATAL: GS cache missing"; exit 1; }

while read -r CFG; do
  [ -z "$CFG" ] && continue
  TAG=$(basename "$CFG" .yaml)
  echo "=============== RAMP $TAG ($CFG) ==============="
  "$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl "$CFG" || { echo "($TAG run FAILED)"; continue; }
  DIAG=$(ls -t "$FPE_RUNS_ROOT"/*/mermin_ho_diag.jld2 2>/dev/null | head -1)
  if [ -n "$DIAG" ]; then
    cp "$DIAG" "$SWEEP/${TAG}_diag.jld2"
    RD=$(dirname "$DIAG"); rm -f "$RD"/point_001.jld2 "$RD"/result.jld2
    echo "[$TAG] kept $SWEEP/${TAG}_diag.jld2 ; pruned big result in $RD"
  else
    echo "($TAG: no diag found)"
  fi
done < runs/eu151_edh_vs_flower/ramp_sweep/MANIFEST.txt

echo "=== done ==="; ls -la "$SWEEP"/*_diag.jld2
