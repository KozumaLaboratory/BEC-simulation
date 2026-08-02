#!/bin/bash
# RK4IP on GPU: parity, cost, memory. See scripts/validation/rk4ip_gpu_cost_probe.jl.
#
#   qsub -g tga-kozuma-kouhi runs/rk4ip_gpu/submit_probe.sh
#
#$ -cwd
#$ -N rk4ip_gpu
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -t 1-6
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

case "${SGE_TASK_ID:-1}" in
    1) "$JULIA" --project=. scripts/validation/rk4ip_gpu_cost_probe.jl ;;
    2) "$JULIA" --project=. scripts/validation/rk4ip_time_to_solution_gpu.jl 64 ;;
    3) "$JULIA" --project=. scripts/validation/rk4ip_time_to_solution_gpu.jl 128 ;;
    4) "$JULIA" --project=. scripts/validation/step_cost_ablation_gpu.jl 128 ;;
    5) "$JULIA" --project=. scripts/validation/step_cost_ablation_gpu.jl 64 ;;
    6) "$JULIA" --project=. scripts/validation/step_cost_ablation_gpu.jl 32 ;;
    *) echo "no task ${SGE_TASK_ID}"; exit 1 ;;
esac

echo "[done]"
