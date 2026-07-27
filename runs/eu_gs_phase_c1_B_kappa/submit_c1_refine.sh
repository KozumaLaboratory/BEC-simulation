#!/bin/bash
# ============================================================
#  UGE array — Eu F=6 GS phase diagram, c1 × κ plane (one B slice).
#  Each task = one (c1,κ) point × 2 seeds (m_plus_F, polar). No seed_from /
#  continuation ⇒ cells independent; array order irrelevant. 13×15 = 195.
#
#  The config path is the FIRST script argument, so one script serves all
#  three B slices:
#    qsub -g tga-kozuma-kouhi -N eu_c1k_b0  runs/eu_gs_phase_c1_B_kappa/submit_c1kappa.sh runs/eu_gs_phase_c1_B_kappa/config_c1kappa_B0.yaml
#    qsub -g tga-kozuma-kouhi -N eu_c1k_b10 runs/eu_gs_phase_c1_B_kappa/submit_c1kappa.sh runs/eu_gs_phase_c1_B_kappa/config_c1kappa_B10.yaml
#    qsub -g tga-kozuma-kouhi -N eu_c1k_b60 runs/eu_gs_phase_c1_B_kappa/submit_c1kappa.sh runs/eu_gs_phase_c1_B_kappa/config_c1kappa_B60.yaml
# ============================================================
#$ -cwd
#$ -N eu_c1ref
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -t 1-96
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
CONFIG="${1:?usage: submit_c1kappa.sh <config.yaml>}"
[ -f "$CONFIG" ] || CONFIG="$PROJECT_ROOT/$CONFIG"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail                       # re-arm: tsubame_setup runs `set +e`

# Append the SHARED depot (packages/artifacts) after the node-local NVMe depot.
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH}:/gs/fs/tga-kozuma-kouhi/shared/.julia:${HOME}/.julia"

export SPINORBEC_SCAN_ONLY_INDEX=$SGE_TASK_ID
# Content-addressed GS stage cache: reuse a ground state computed by any other
# config/scan (shared store at $PROJECT_ROOT/runs/_stage/gs).
export SPINORBEC_STAGE_CACHE=1
echo "[task $SGE_TASK_ID/$SGE_TASK_LAST] $(hostname) cfg=$CONFIG"; nvidia-smi -L || true

# Guard silent CPU fallback (a broken-CUDA node otherwise burns hours on CPU).
"$JULIA" --project=. -e '
    import CUDA
    CUDA.functional() || (@error "CUDA not functional — refusing CPU fallback"; exit(1))
    using SpinorBEC
    run_yaml(ARGS[1])' "$CONFIG"

echo "[task $SGE_TASK_ID] done"
