#!/bin/bash
# RK4IP on GPU: parity, cost, memory. See scripts/validation/rk4ip_gpu_cost_probe.jl.
#
#   qsub -g tga-kozuma-kouhi runs/rk4ip_gpu/submit_probe.sh
#
#$ -cwd
#$ -N rk4ip_gpu
#$ -l gpu_1=1
#$ -l h_rt=1:00:00
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/wt_matsui_fig4b
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail                       # re-arm: tsubame_setup runs `set +e`
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH}:/gs/fs/tga-kozuma-kouhi/shared/.julia:${HOME}/.julia"

echo "[src]   $(git rev-parse HEAD)  $(git status --porcelain -- src | wc -l) dirty src files"
nvidia-smi -L || true

"$JULIA" --project=. scripts/validation/rk4ip_gpu_cost_probe.jl

echo "[done]"
