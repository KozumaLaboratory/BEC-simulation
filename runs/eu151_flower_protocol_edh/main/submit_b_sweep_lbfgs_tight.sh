#!/bin/bash
# UGE submission: tightened LBFGS B-sweep, 200 μG → -10 μG, 28 control pts,
# tol=1e-4 / cap=10000 iter / m=15, chain warm-start.
#
# Resume-friendly: re-running the same submit just continues from where the
# last job left off (per-B cache skip on grad_norm ≤ 1.5e-4).
#
# qsub -g tga-kozuma-kouhi runs/eu151_flower_protocol_edh/main/submit_b_sweep_lbfgs_tight.sh
#$ -cwd
#$ -N b_sweep_tight
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
echo "[b_sweep_tight] on $(hostname)"
"$JULIA" --project=. scripts/flower_protocol_edh/b_sweep_lbfgs_tight.jl
echo "[b_sweep_tight] done"
