#!/bin/bash
#$ -cwd
#$ -N viz_v8
#$ -l cpu_40=1
#$ -l h_rt=8:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/viz_v8.log
# Render the CSS-ness analysis of the full-grid 96^3 v8 data (CPU node, conda_viz).
# PRIMARY (user request): CSS-ness 3D volume + orthogonal slices + quantitative stills.
# SECONDARY: the proven v6 3D spin-texture mp4 per leg. NOT set -e: a failing panel
# must not abort the rest. Time-aligned side-by-side (EdH vs Flower) throughout.
set -uo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
VIZPY=/gs/fs/tga-kozuma-kouhi/ue06186/conda_viz/bin/python
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load ffmpeg 2>/dev/null || true
EDIR=$(ls -dt "$DATA"/edh_ramp26_v8_*/ 2>/dev/null | head -1)
FDIR=$(ls -dt "$DATA"/flower_slow100_v8_*/ 2>/dev/null | head -1)
GE="$EDIR/goto.h5"; GF="$FDIR/goto.h5"
OUTD="$DATA/figures_v8"; mkdir -p "$OUTD"
echo "EDIR=$EDIR  FDIR=$FDIR  OUTD=$OUTD"
[ -f "$GE" ] || { echo "FATAL: EdH goto.h5 missing"; exit 1; }
[ -f "$GF" ] || { echo "FATAL: Flower goto.h5 missing"; exit 1; }

echo "=============== PRIMARY: CSS-ness analysis ==============="
echo "--- (1) CSS-ness quantitative stills ---"
GOTO_EDH="$GE" GOTO_FL="$GF" OUT="$OUTD/css_analysis_v8.png" \
  LABEL_EDH="EdH ramp->26µG" LABEL_FL="Flower slow->100µG" \
  "$VIZPY" scripts/edh_vs_flower/css_analysis.py || echo "(css_analysis FAILED)"

echo "--- (2) CSS-ness 3D volume (non-CSS region shape), time-aligned side-by-side ---"
GOTO_EDH="$GE" GOTO_FL="$GF" OUT="$OUTD/css_volume_v8.mp4" FRAMES_DIR="$OUTD/_vol_frames" \
  N_FRAMES=140 S_THR=0.9 FPS=15 SMOOTH=1.0 \
  LABEL_EDH="EdH  ramp->26µG" LABEL_FL="Flower  slow->100µG" \
  "$VIZPY" scripts/edh_vs_flower/css_volume.py || echo "(css_volume FAILED)"

echo "--- (3) CSS-ness orthogonal slices, time-aligned side-by-side ---"
GOTO_EDH="$GE" GOTO_FL="$GF" OUT="$OUTD/css_slices_v8.mp4" FRAMES_DIR="$OUTD/_sl_frames" \
  N_FRAMES=140 FPS=15 \
  LABEL_EDH="EdH ramp->26µG" LABEL_FL="Flower slow->100µG" \
  "$VIZPY" scripts/edh_vs_flower/css_slices.py || echo "(css_slices FAILED)"

echo "=============== SECONDARY: proven v6 3D spin-texture ==============="
for pair in "edh $GE" "flower $GF"; do
  set -- $pair; TAG=$1; RH=$2
  NMAX=$("$VIZPY" -c "import h5py,numpy as np;print(float(np.asarray(h5py.File('$RH','r')['n_total_3d']).max()))" 2>/dev/null)
  THR=$("$VIZPY" -c "print(0.02*$NMAX)" 2>/dev/null)
  echo "--- [$TAG] 3D spin texture (n_max=$NMAX thr=$THR) ---"
  RTP_H5="$RH" OUT_GIF="$OUTD/${TAG}_v8_3d_spin_texture.mp4" \
    FPE_SPIN_COLOR=updown FPE_3D_SPIN_USE_ABS_THRESH=1 FPE_3D_SPIN_ABS_THRESH=$THR \
    FPE_3D_ARROW_STEP=2 FPE_3D_ARROW_LENGTH=1.4 FPE_FRAME_STRIDE=1 FPE_DURATION_S=30 FPE_FPS=30 \
    "$VIZPY" scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_spin.py || echo "([$TAG] spin_texture FAILED)"
done

echo "=== viz v8 DONE; outputs in $OUTD ==="; ls -la "$OUTD"
