#!/bin/bash
# RK4IP on GPU: parity, cost, memory. See scripts/validation/rk4ip_gpu_cost_probe.jl.
#
#   qsub -g tga-kozuma-kouhi runs/rk4ip_gpu/submit_probe.sh
#
#$ -cwd
#$ -N rk4ip_gpu
#$ -l gpu_1=1
#$ -l h_rt=3:00:00
#$ -t 1-8
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/wt_matsui_fig4b
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail                       # re-arm: tsubame_setup runs `set +e`
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH}:/gs/fs/tga-kozuma-kouhi/shared/.julia:${HOME}/.julia"

# /gs/bs/work, not the group /gs/fs — and NOT the default `runs/`, which is
# inside the git worktree. Omitting this put a probe's scan output in the repo.
export SPINORBEC_STORE="${SPINORBEC_STORE:-/gs/bs/work/7/uk07267/runs}"
mkdir -p "$SPINORBEC_STORE"

echo "[src]   $(git rev-parse HEAD)  $(git status --porcelain -- src | wc -l) dirty src files"
nvidia-smi -L || true
echo "[t] startup done: $(date -Ins)"

case "${SGE_TASK_ID:-1}" in
    1) "$JULIA" --project=. scripts/validation/rk4ip_gpu_cost_probe.jl ;;
    2) "$JULIA" --project=. scripts/validation/rk4ip_time_to_solution_gpu.jl 64 ;;
    3) "$JULIA" --project=. scripts/validation/rk4ip_time_to_solution_gpu.jl 128 ;;
    4) "$JULIA" --project=. scripts/validation/step_cost_ablation_gpu.jl 128 ;;
    5) "$JULIA" --project=. scripts/validation/step_cost_ablation_gpu.jl 64 ;;
    6) "$JULIA" --project=. scripts/validation/step_cost_ablation_gpu.jl 32 ;;
    7) stdbuf -oL -eL "$JULIA" --project=. scripts/validation/scan_job_cost_breakdown.jl \
           runs/matsui_fig4b/fig4b_scan_n35k_n32.yaml 3 ;;
    8) stdbuf -oL -eL "$JULIA" --project=. scripts/build_sysimage_matsui.jl \
           /gs/bs/work/7/uk07267/spinor_sysimage_matsui.so ;;
    *) echo "no task ${SGE_TASK_ID}"; exit 1 ;;
esac

echo "[t] work done: $(date -Ins)"
echo "[done]"
