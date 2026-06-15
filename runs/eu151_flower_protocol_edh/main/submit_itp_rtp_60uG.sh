#!/bin/bash
# UGE submission: ITP @ 60μG → RTP @ 60μG (50ms hold), with per-frame slice
# extraction (xy/xz + tilted ±16° y-integrated) for GIF generation.
#
# qsub -g tga-kozuma-kouhi runs/eu151_flower_protocol_edh/main/submit_itp_rtp_60uG.sh
#$ -cwd
#$ -N fpe_itp_rtp
#$ -l gpu_h=1
#$ -l h_rt=4:00:00
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
echo "[itp_rtp_60uG] on $(hostname)"
"$JULIA" --project=. scripts/flower_protocol_edh/itp_rtp_60uG.jl
echo "[itp_rtp_60uG] julia done — generating GIF"
python3 scripts/flower_protocol_edh/plot_rtp_60uG.py
echo "[itp_rtp_60uG] all done"
