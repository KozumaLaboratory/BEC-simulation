#!/bin/bash
# UGE submission: ITP trace at B=60 μG with on_step snapshot capture.
# Outputs itp_trace_60uG.h5 → plot_itp_trace.py turns it into a GIF.
#
# qsub -g tga-kozuma-kouhi runs/eu151_flower_protocol_edh/main/submit_itp_trace_60uG.sh
#$ -cwd
#$ -N fpe_itp_trace
#$ -l gpu_h=1
#$ -l h_rt=2:00:00
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
echo "[itp_trace_60uG] on $(hostname)"
"$JULIA" --project=. scripts/flower_protocol_edh/itp_trace_60uG.jl
echo "[itp_trace_60uG] julia done — generating GIF"
python3 scripts/flower_protocol_edh/plot_itp_trace.py
echo "[itp_trace_60uG] all done"
