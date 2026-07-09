#!/bin/bash
#$ -cwd
#$ -N viz_v5
#$ -l cpu_40=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/viz_v5.log
set -euo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
RDIR=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/edh_quench_v5_93484c68
OUTD=$RDIR/figures
VIZPY=/gs/fs/tga-kozuma-kouhi/ue06186/conda_viz/bin/python
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load ffmpeg 2>/dev/null || true
mkdir -p "$OUTD"
echo "=== build goto.h5 from spin3d ==="
"$VIZPY" scripts/edh_vs_flower/make_goto_tsubame.py "$RDIR/spin3d.jld2" "$RDIR/mermin_ho_diag.jld2" "$RDIR/goto.h5"
NMAX=$("$VIZPY" -c "import h5py,numpy as np;print(float(np.asarray(h5py.File('$RDIR/goto.h5','r')['n_total_3d']).max()))")
THR=$("$VIZPY" -c "print(0.08*$NMAX)")
echo "n_total max=$NMAX  abs_thresh=$THR"
echo "=== 3D spin texture mp4 ==="
RTP_H5=$RDIR/goto.h5 OUT_GIF=$OUTD/edh_v5_3d_spin_texture.mp4 \
 FPE_SPIN_COLOR=updown FPE_3D_SPIN_USE_ABS_THRESH=1 FPE_3D_SPIN_ABS_THRESH=$THR \
 FPE_3D_ARROW_STEP=3 FPE_3D_ARROW_LENGTH=1.4 FPE_FRAME_STRIDE=1 FPE_DURATION_S=40 FPE_FPS=30 \
 "$VIZPY" scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_spin.py
echo "=== isosurface m6m5m4 + relative phase mp4 ==="
RTP_H5=$RDIR/goto.h5 OUT_GIF=$OUTD/edh_v5_isosurface_m6m5m4_relphase.mp4 \
 FPE_PHASE_MODE=rel FPE_DURATION_S=20 FPE_FPS=30 FRAME_START_FRAC=0.0 \
 "$VIZPY" scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6m5m4_second_half.py
echo "=== density+phase 3D mp4 (if present) ==="
RTP_H5=$RDIR/goto.h5 OUT_GIF=$OUTD/edh_v5_3d_density_phase.mp4 FPE_DURATION_S=20 FPE_FPS=30 \
 "$VIZPY" scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_density_phase.py 2>/dev/null || echo "(density_phase skipped)"
echo "=== done; outputs in $OUTD ==="; ls -la "$OUTD"/*.mp4 2>/dev/null
