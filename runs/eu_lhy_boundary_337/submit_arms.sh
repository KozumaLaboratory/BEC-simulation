#!/bin/bash
# ============================================================
#  UGE array — #337 criterion B/C: LHY arms across the Eu F=6 boundary.
#  One task = one Bz point × all 9 comparison runs (seeds × LHY arms).
#
#    qsub -g tga-kozuma-kouhi -N eu337 runs/eu_lhy_boundary_337/submit_arms.sh \
#         runs/eu_lhy_boundary_337/config_arms.yaml
#
#  The config path is the FIRST script argument (same convention as
#  runs/eu_gs_phase_c1_B_kappa/submit_c1kappa.sh, which this is copied from).
#  -t must match the number of scan points in the config.
# ============================================================
#$ -cwd
#$ -N eu337_lhy_arms
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -t 1-9
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
CONFIG="${1:?usage: submit_arms.sh <config.yaml>}"
[ -f "$CONFIG" ] || CONFIG="$PROJECT_ROOT/$CONFIG"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail                       # re-arm: tsubame_setup runs `set +e`

export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH}:/gs/fs/tga-kozuma-kouhi/shared/.julia:${HOME}/.julia"

export SPINORBEC_SCAN_ONLY_INDEX=$SGE_TASK_ID
export SPINORBEC_STAGE_CACHE=1
# NOT light points: criterion C needs psi on disk to evaluate
# `spatial_lhy_residual` on the converged state afterwards.
echo "[task $SGE_TASK_ID/$SGE_TASK_LAST] $(hostname) cfg=$CONFIG"; nvidia-smi -L || true

"$JULIA" --project=. -e '
    import CUDA
    CUDA.functional() || (@error "CUDA not functional — refusing CPU fallback"; exit(1))
    using SpinorBEC
    run_yaml(ARGS[1])' "$CONFIG"

echo "[task $SGE_TASK_ID] done"
