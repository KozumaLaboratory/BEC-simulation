#!/bin/bash
#$ -cwd
#$ -N ramp_iso
#$ -l gpu_1=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/ramp_iso.log
# Re-run the 6 ramp-sweep dynamics KEEPING psi, then render the canonical
# m=-6/-5/-4 density-isosurface + relative-phase mp4 for EACH ramp so the
# "wobbly" (gunya-gunya) dynamics can be compared across descent rates.
# Pipeline per ramp = run_yaml + diagnostic (run_edh_v4) -> extract_3d ->
# make_goto_tsubame -> plot_rtp_10mG_goto_isosurface_m6m5m4_second_half.py
# (the proven v6 viz path). 64^3, reuses the cached 64^3 GS. gpu_1 (1 H100).
set -uo pipefail          # NOT -e: one failing ramp must not kill the rest
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
SWEEP=$DATA/ramp_sweep
mkdir -p "$SWEEP"; cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load cuda/12.8.0; module load ffmpeg 2>/dev/null || true
export JULIA_DEPOT_PATH=${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
VIZPY=/gs/fs/tga-kozuma-kouhi/ue06186/conda_viz/bin/python
GS64="$PROJECT_ROOT/runs/eu151_edh_vs_flower/cache/gs_10mG_c1_36_64.jld2"
export FPE_RUNS_ROOT="$SWEEP/iso_runs"; mkdir -p "$FPE_RUNS_ROOT"

echo "=== warmup ==="; "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
[ -f "$GS64" ] || { echo "FATAL: 64^3 GS cache missing ($GS64)"; exit 1; }

# Read the manifest into an ARRAY (not a `while read` loop): a child process
# in the loop body (julia/CUDA init) can steal bytes from the loop's stdin,
# corrupting the NEXT manifest line (observed: every other config path lost its
# "ru" prefix -> file-not-found). mapfile + </dev/null on every child is immune.
MANIFEST="${RAMP_MANIFEST:-runs/eu151_edh_vs_flower/ramp_sweep/MANIFEST.txt}"
mapfile -t CFGS < "$MANIFEST"
for CFG in "${CFGS[@]}"; do
  [ -z "$CFG" ] && continue
  TAG=$(basename "$CFG" .yaml)
  T=$(echo "$TAG" | sed 's/.*_T//; s/p/./')          # descent duration (for B annotation)
  echo "=============== ISO $TAG (T=$T) ==============="
  "$JULIA" --project=. scripts/edh_vs_flower/run_edh_v4.jl "$CFG" </dev/null || { echo "($TAG run FAILED)"; continue; }
  RD=$(ls -dt "$FPE_RUNS_ROOT"/*/ 2>/dev/null | head -1)
  RESULT=$(ls -S "$RD"*.jld2 2>/dev/null | head -1)
  [ -z "$RESULT" ] && { echo "($TAG: no result)"; continue; }
  echo "[$TAG] RD=$RD RESULT=$RESULT"
  # stride 2 -> 32^3 isosurface grid: marching_cubes + 3D matplotlib render is
  # ~8x faster and fits the 12GB slice comfortably; smooth enough to SEE the
  # wobble (dynamics themselves stay full 64^3 — only the movie is decimated).
  "$JULIA" --project=. scripts/edh_vs_flower/extract_3d.jl "$RESULT" "$RD/spin3d.jld2" \
    --stride 2 --tstride 1 --box 18 --F 6 </dev/null || { echo "($TAG extract_3d FAILED)"; continue; }
  "$VIZPY" scripts/edh_vs_flower/make_goto_tsubame.py "$RD/spin3d.jld2" "$RD/mermin_ho_diag.jld2" \
    "$RD/goto.h5" --quench_dur "$T" </dev/null || { echo "($TAG make_goto FAILED)"; continue; }
  RTP_H5="$RD/goto.h5" OUT_GIF="$SWEEP/${TAG}_isosurface_m6m5m4_relphase.mp4" \
    FPE_PHASE_MODE=rel FPE_DURATION_S=16 FPE_FPS=30 FRAME_START_FRAC=0.0 \
    "$VIZPY" scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6m5m4_second_half.py </dev/null \
    || echo "($TAG isosurface FAILED)"
  rm -f "$RD"/point_001.jld2 "$RD"/result.jld2         # keep spin3d+goto+mp4, prune big psi
  echo "[$TAG] mp4 -> $SWEEP/${TAG}_isosurface_m6m5m4_relphase.mp4"
done

echo "=== done ==="; ls -la "$SWEEP"/*_isosurface_m6m5m4_relphase.mp4 2>/dev/null
