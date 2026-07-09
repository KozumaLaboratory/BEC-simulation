#!/bin/bash
#$ -cwd
#$ -N viz_dyn
#$ -l cpu_40=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/viz_dyn.log
set -uo pipefail
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
VIZPY=/gs/fs/tga-kozuma-kouhi/ue06186/conda_viz/bin/python
cd "$PROJECT_ROOT"
. /etc/profile.d/modules.sh; module load ffmpeg 2>/dev/null || true
EDH_PSI=$DATA/edh_v5_psi13.jld2;   EDH_GOTO=$DATA/edh_quench_v5_93484c68/goto.h5
FLO_PSI=/gs/fs/tga-kozuma-kouhi/ue06186/flower_v3_psi13.jld2
FLO_RUN=$DATA/flower_smooth_v3_b18d170f
OUTD=$DATA/dyn_figures; mkdir -p "$OUTD"
echo "=== build Flower goto (t from diag; B approx label) ==="
"$VIZPY" scripts/edh_vs_flower/make_goto_tsubame.py "$FLO_RUN/spin3d.jld2" "$FLO_RUN/mermin_ho_diag.jld2" "$FLO_RUN/goto.h5" --B0 0.01 --B1 1.2e-4 --quench_dur 0.14 || echo "(flower goto build failed; will fall back to frame index)"
run(){  # state psi goto tag plane out
  echo "=== render: $4 $5 ==="
  PSI13="$2" GOTO="$3" PLANE="$5" OUT="$6" DUR=16 FPS=20 TAG="$4" \
    "$VIZPY" scripts/edh_vs_flower/plane_dynamics_anim.py
}
run EdH    "$EDH_PSI" "$EDH_GOTO"      "EdH v5"    xy "$OUTD/edh_v5_xy_texture_truth_vs_recon.mp4"
run EdH    "$EDH_PSI" "$EDH_GOTO"      "EdH v5"    xz "$OUTD/edh_v5_xz_texture_truth_vs_recon.mp4"
run Flower "$FLO_PSI" "$FLO_RUN/goto.h5" "Flower v3" xy "$OUTD/flower_v3_xy_texture_truth_vs_recon.mp4"
run Flower "$FLO_PSI" "$FLO_RUN/goto.h5" "Flower v3" xz "$OUTD/flower_v3_xz_texture_truth_vs_recon.mp4"
echo "=== done; outputs ==="; ls -la "$OUTD"/*.mp4 2>/dev/null
