#!/bin/bash
# FIT TO EXPERIMENT — c1_ratio scan. See any arm's header for the reasoning.
#
#   qsub -g tga-kozuma-kouhi runs/matsui_fit/submit_fit.sh
#
#$ -cwd
#$ -N matsui_fit
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -t 1-48
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

# A duplicated case label is silently unreachable — `case` takes the first
# match — and two sessions appending arms to the same `*)` sentinel produce
# exactly that. This cost a 25-minute run of the wrong config.
dup=$(grep -oE '^ *[0-9]+\)' "$0" | tr -d ' )' | sort -n | uniq -d)
if [ -n "$dup" ]; then echo "duplicate task labels: $dup" >&2; exit 1; fi
for c in $(grep -oE 'runs/matsui_fit/[A-Za-z0-9_.]+\.yaml' "$0"); do
    [ -f "$c" ] || { echo "missing config: $c" >&2; exit 1; }
done

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
    19) CONFIG=runs/matsui_fit/fit_hold_T52.yaml ;;
    20) CONFIG=runs/matsui_fit/fit_hold_T54.yaml ;;
    21) CONFIG=runs/matsui_fit/fit_hold_T52r200.yaml ;;
    22) CONFIG=runs/matsui_fit/fit_paperN_r036.yaml ;;
    23) CONFIG=runs/matsui_fit/fit_paperN_r018.yaml ;;
    24) CONFIG=runs/matsui_fit/fit_paperN_r009.yaml ;;
    25) CONFIG=runs/matsui_fit/fit_paperN_r020.yaml ;;
    26) CONFIG=runs/matsui_fit/fit_paperN_r030.yaml ;;
    27) CONFIG=runs/matsui_fit/fit_code_q_n35k.yaml ;;
    28) CONFIG=runs/matsui_fit/fit_code_c1e2_n35k.yaml ;;
    29) CONFIG=runs/matsui_fit/fit_code_qc1e2_n35k.yaml ;;
    30) CONFIG=runs/matsui_fit/fit_code_q_n50k.yaml ;;
    31) CONFIG=runs/matsui_fit/fit_code_c1e2_n50k.yaml ;;
    32) CONFIG=runs/matsui_fit/fit_code_qc1e2_n50k.yaml ;;
    33) CONFIG=runs/matsui_fit/rings_c0.yaml ;;
    34) CONFIG=runs/matsui_fit/rings_c1e2.yaml ;;
    35) CONFIG=runs/matsui_fit/rings_c036.yaml ;;
    36) CONFIG=runs/matsui_fit/rings_c030.yaml ;;
    37) CONFIG=runs/matsui_fit/res64_c036.yaml ;;
    38) CONFIG=runs/matsui_fit/res64_c1e2.yaml ;;
    39) CONFIG=runs/matsui_fit/res128_c036.yaml ;;
    40) CONFIG=runs/matsui_fit/rc0p0139.yaml ;;
    41) CONFIG=runs/matsui_fit/rc0p5.yaml ;;
    42) CONFIG=runs/matsui_fit/rc1p0.yaml ;;
    44) CONFIG=runs/matsui_fit/sdloss_1em40.yaml ;;
    45) CONFIG=runs/matsui_fit/sdloss_5em40.yaml ;;
    46) CONFIG=runs/matsui_fit/sdloss_2em39.yaml ;;
    47) CONFIG=runs/matsui_fit/sdloss_dip.yaml ;;
    48) CONFIG=runs/matsui_fit/fig2c_n35k.yaml ;;
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
