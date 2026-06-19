#!/bin/bash
# [DEPRECATED 2026-06-19] use `submit_b_sweep_all.sh` — polish is now
# Phase 2 of the unified b_sweep_all pipeline.
#
# UGE submission: parallel POLISH pass for already-cached B points.
# Runs alongside primary `b_sweep_lbfgs_tight` (different node, no shared writes).
#
# qsub -g tga-kozuma-kouhi runs/eu151_flower_protocol_edh/main/submit_b_sweep_polish.sh
#$ -cwd
#$ -N b_sweep_polish
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
echo "[polish] on $(hostname)"
"$JULIA" --project=. scripts/flower_protocol_edh/b_sweep_polish.jl
echo "[polish] done"
