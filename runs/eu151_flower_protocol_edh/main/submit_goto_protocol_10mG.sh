#!/bin/bash
# UGE submission: full Goto Ch.6 Flower protocol from 10 mG ITP+LBFGS GS
# through B(t) trajectory to 0 G observation point.
#
# qsub -g tga-kozuma-kouhi runs/eu151_flower_protocol_edh/main/submit_goto_protocol_10mG.sh
#$ -cwd
#$ -N goto_10mG
#$ -l gpu_h=1
#$ -l h_rt=8:00:00
#$ -j n
#$ -o /gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/logs/
#$ -e /gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/logs/

set -euo pipefail
PROJECT_ROOT=$HOME/bec-simulation
mkdir -p /gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/logs
cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail
HOME_DEPOT=$HOME/.julia
export JULIA_DEPOT_PATH="$JULIA_DEPOT_PATH:$HOME_DEPOT"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
echo "[goto_10mG] on $(hostname)"
# Reuse cached ITP+LBFGS ψ — only re-run Phase 3 (RTP) to refresh 3D dumps.
export FPE_REUSE_LBFGS_ONLY=true
"$JULIA" --project=. scripts/flower_protocol_edh/goto_protocol_10mG.jl
echo "[goto_10mG] julia done — generating combined GIF"
python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto.py
echo "[goto_10mG] tilted diff GIF"
python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_tilted_diff.py
echo "[goto_10mG] 3-D density/phase GIF"
python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_density_phase.py
echo "[goto_10mG] 3-D spin GIF"
python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_spin.py
echo "[goto_10mG] m=-6 stricter isosurface time-lapse"
python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6.py
echo "[goto_10mG] 3-panel m=-6/-5/-4 second-half isosurface time-lapse"
python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6m5m4_second_half.py
echo "[goto_10mG] all done"
