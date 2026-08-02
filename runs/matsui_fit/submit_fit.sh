#!/bin/bash
# FIT TO EXPERIMENT — c1_ratio scan. See any arm's header for the reasoning.
#
#   qsub -g tga-kozuma-kouhi runs/matsui_fit/submit_fit.sh
#
#$ -cwd
#$ -N matsui_fit
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -t 1-18
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/wt_matsui_fig4b
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH}:/gs/fs/tga-kozuma-kouhi/shared/.julia:${HOME}/.julia"
export SPINORBEC_STORE="${SPINORBEC_STORE:-/gs/bs/work/7/uk07267/runs}"
mkdir -p "$SPINORBEC_STORE"

# Measured -12% on this exact config family (UGE 8318964); the ground state is
# identical across the 45 scan points, which vary only the dynamics B target.
export SPINORBEC_STAGE_CACHE=1

case "${SGE_TASK_ID:-1}" in
    1) CONFIG=runs/matsui_fit/fit_c1ratio_m0139.yaml ;;
    2) CONFIG=runs/matsui_fit/fit_c1ratio_0.yaml ;;
    3) CONFIG=runs/matsui_fit/fit_c1ratio_00069.yaml ;;
    4) CONFIG=runs/matsui_fit/fit_c1ratio_00278.yaml ;;
    5) CONFIG=runs/matsui_fit/fit_c1ratio_01111.yaml ;;
    6) CONFIG=runs/matsui_fit/fit_c1ratio_0p15.yaml ;;
    7) CONFIG=runs/matsui_fit/fit_c1ratio_0p2.yaml ;;
    8) CONFIG=runs/matsui_fit/fit_c1ratio_0p25.yaml ;;
    9) CONFIG=runs/matsui_fit/fit_c1ratio_0p3.yaml ;;
    10) CONFIG=runs/matsui_fit/fit_expN_r036.yaml ;;
    11) CONFIG=runs/matsui_fit/fit_expN_r015.yaml ;;
    12) CONFIG=runs/matsui_fit/fit_expN_r030.yaml ;;
    13) CONFIG=runs/matsui_fit/fit_k3_1p2em27.yaml ;;
    14) CONFIG=runs/matsui_fit/fit_k3_3p6em27.yaml ;;
    15) CONFIG=runs/matsui_fit/fit_k3_1p2em26.yaml ;;
    16) CONFIG=runs/matsui_fit/fit_k3real_1em30.yaml ;;
    17) CONFIG=runs/matsui_fit/fit_k3real_1em29.yaml ;;
    18) CONFIG=runs/matsui_fit/fit_k3real_1em28.yaml ;;
    *) echo "no config for task ${SGE_TASK_ID}"; exit 1 ;;
esac

echo "[task ${SGE_TASK_ID}] $(hostname) cfg=$CONFIG"
echo "[src]   $(git rev-parse HEAD)  $(git status --porcelain -- src | wc -l) dirty src files"
nvidia-smi -L || true

"$JULIA" --project=. -e '
    import CUDA
    CUDA.functional() || (@error "CUDA not functional — refusing CPU fallback"; exit(1))
    using SpinorBEC
    run_yaml(ARGS[1])' "$CONFIG"

echo "[task ${SGE_TASK_ID}] done"
