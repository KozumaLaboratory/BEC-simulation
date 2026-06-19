#!/bin/bash
# UGE submission: two-phase b_sweep_all.jl (Phase 1 ITP → Phase 2 LBFGS polish).
#
# qsub -g tga-kozuma-kouhi runs/eu151_flower_protocol_edh/main/submit_b_sweep_all.sh
#$ -cwd
#$ -N b_sweep_all
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
echo "[b_sweep_all] on $(hostname)"
"$JULIA" --project=. scripts/flower_protocol_edh/b_sweep_all.jl
echo "[b_sweep_all] done"
