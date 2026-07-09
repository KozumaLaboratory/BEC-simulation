#!/bin/bash
#$ -cwd
#$ -N viz_v6
#$ -l cpu_40=1
#$ -l h_rt=10:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/viz_v6.log
# Render + tomography analysis of the FULL-GRID 96^3 v6 data, on a CPU node.
# Display grid == computational grid: 2D/tomography panels are 96x96 = compute
# pixels; FPE_DENSITY_FLOOR=0 shows every voxel. TOMOGRAPHY RUNS FIRST (the key
# deliverable + fast); 3D mp4 renders after, skipping any already produced.
set -uo pipefail   # NOT -e: one failing panel must not abort the rest
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
VIZPY=/gs/fs/tga-kozuma-kouhi/ue06186/conda_viz/bin/python
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load ffmpeg 2>/dev/null || true
export FPE_DENSITY_FLOOR=0.0                       # show ALL voxels (full compute grid)

EDIR=$(ls -dt "$DATA"/edh_quench_v6_*/ 2>/dev/null | head -1)
FDIR=$(ls -dt "$DATA"/flower_smooth_v6_*/ 2>/dev/null | head -1)
OUTD="$DATA/figures_v6"; mkdir -p "$OUTD"
EDH_PSI=$DATA/edh_v6_psi13.jld2; FL_PSI=$DATA/flower_v6_psi13.jld2
echo "EDIR=$EDIR  FDIR=$FDIR  OUTD=$OUTD"

# make sure goto.h5 exists for both (truth for texture_tomo)
for RD in "$EDIR" "$FDIR"; do
  [ -f "$RD/goto.h5" ] || "$VIZPY" scripts/edh_vs_flower/make_goto_tsubame.py "$RD/spin3d.jld2" "$RD/mermin_ho_diag.jld2" "$RD/goto.h5"
done

LASTFR=$("$VIZPY" -c "import h5py,numpy as np;print(np.asarray(h5py.File('$EDH_PSI','r')['psi_re_c13']).shape[0]-1)")
LASTFL=$("$VIZPY" -c "import h5py,numpy as np;print(np.asarray(h5py.File('$FL_PSI','r')['psi_re_c13']).shape[0]-1)")
echo "last frame: EdH=$LASTFR  Flower=$LASTFL"

echo "=============== TOMOGRAPHY (full grid, floor=0) FIRST ==============="
echo "--- EdH exact 3-image texture tomography (validate <F>(r) recon vs truth) ---"
PSI13=$EDH_PSI GOTO=$EDIR/goto.h5 OUT=$OUTD/edh_texture_tomography.png FRAME=$LASTFR \
  "$VIZPY" scripts/edh_vs_flower/texture_tomo.py || echo "(edh texture_tomo FAILED)"
echo "--- Flower exact 3-image texture tomography ---"
PSI13=$FL_PSI GOTO=$FDIR/goto.h5 OUT=$OUTD/flower_texture_tomography.png FRAME=$LASTFL \
  "$VIZPY" scripts/edh_vs_flower/texture_tomo.py || echo "(flower texture_tomo FAILED)"
echo "--- EdH vs Flower discrimination (5-setting tilt-SG) ---"
EDH=$EDH_PSI FLOWER=$FL_PSI OUT=$OUTD/edh_vs_flower_discrimination.png FRAME_EDH=$LASTFR FRAME_FL=$LASTFL \
  "$VIZPY" scripts/edh_vs_flower/flower_vs_edh_tomo.py || echo "(discrimination FAILED)"
echo "--- EdH reconstructed-vs-true dense compare suite ---"
PSI13=$EDH_PSI GOTO=$EDIR/goto.h5 FRAME=$LASTFR OUTDIR=$OUTD \
  "$VIZPY" scripts/edh_vs_flower/edh_compare_suite.py || echo "(compare_suite FAILED)"
echo "--- EdH time-resolved tomography video ---"
PSI13=$EDH_PSI GOTO=$EDIR/goto.h5 OUT=$OUTD/edh_texture_tomo_anim.mp4 DUR=16 FPS=20 \
  "$VIZPY" scripts/edh_vs_flower/texture_tomo_anim.py || echo "(tomo anim FAILED)"

render_leg () {  # $1=run_dir $2=tag   (skips outputs already present)
  local RDIR="$1" TAG="$2" NMAX THR
  NMAX=$("$VIZPY" -c "import h5py,numpy as np;print(float(np.asarray(h5py.File('$RDIR/goto.h5','r')['n_total_3d']).max()))")
  THR=$("$VIZPY" -c "print(0.02*$NMAX)")
  echo "[$TAG] n_max=$NMAX iso_abs=$THR"
  if [ ! -f "$OUTD/${TAG}_3d_spin_texture.mp4" ]; then
    echo "=== [$TAG] 3D spin texture mp4 (full grid; arrow_step=2) ==="
    RTP_H5=$RDIR/goto.h5 OUT_GIF=$OUTD/${TAG}_3d_spin_texture.mp4 \
      FPE_SPIN_COLOR=updown FPE_3D_SPIN_USE_ABS_THRESH=1 FPE_3D_SPIN_ABS_THRESH=$THR \
      FPE_3D_ARROW_STEP=2 FPE_3D_ARROW_LENGTH=1.4 FPE_FRAME_STRIDE=1 FPE_DURATION_S=40 FPE_FPS=30 \
      "$VIZPY" scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_spin.py || echo "([$TAG] spin_texture FAILED)"
  else echo "[$TAG] spin_texture exists, skip"; fi
  if [ ! -f "$OUTD/${TAG}_isosurface_m6m5m4_relphase.mp4" ]; then
    echo "=== [$TAG] isosurface m6m5m4 + rel phase mp4 ==="
    RTP_H5=$RDIR/goto.h5 OUT_GIF=$OUTD/${TAG}_isosurface_m6m5m4_relphase.mp4 \
      FPE_PHASE_MODE=rel FPE_DURATION_S=20 FPE_FPS=30 FRAME_START_FRAC=0.0 \
      "$VIZPY" scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6m5m4_second_half.py || echo "([$TAG] iso FAILED)"
  else echo "[$TAG] isosurface exists, skip"; fi
  if [ ! -f "$OUTD/${TAG}_3d_density_phase.mp4" ]; then
    echo "=== [$TAG] density+phase 3D mp4 ==="
    RTP_H5=$RDIR/goto.h5 OUT_GIF=$OUTD/${TAG}_3d_density_phase.mp4 FPE_DURATION_S=20 FPE_FPS=30 \
      "$VIZPY" scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_density_phase.py || echo "([$TAG] density_phase skipped)"
  else echo "[$TAG] density_phase exists, skip"; fi
}
echo "=============== 3D RENDERS (Flower first — EdH already done) ==============="
render_leg "$FDIR" flower
render_leg "$EDIR" edh

echo "=== done; outputs in $OUTD ==="; ls -la "$OUTD"
