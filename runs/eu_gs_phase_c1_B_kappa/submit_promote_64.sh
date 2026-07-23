#!/bin/bash
# ============================================================
#  UGE array — Eu F=6 GS phase diagram, 64³ full-map promotion (Stage B).
#  Each task = one (c1,Bz,κ) point × 2 seeds, warm-started from its 32³
#  recon winner via seed_from (config_promote_64.yaml). continuation is OFF
#  ⇒ cells are independent (no hysteresis), so array order is irrelevant.
#
#  Prereqs on the login node (once):
#    cd $PROJECT_ROOT && git fetch origin && git checkout feat/eu-phase-diagram-seed-promote
#    rsync the 32³ recon CAS into $PROJECT_ROOT/runs/config_recon_335a2216/
#  Submit:
#    qsub -g tga-kozuma-kouhi runs/eu_gs_phase_c1_B_kappa/submit_promote_64.sh
# ============================================================
#$ -cwd
#$ -N eu_gs_phase64
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -t 1-120
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
CONFIG=$PROJECT_ROOT/runs/eu_gs_phase_c1_B_kappa/config_promote_64.yaml
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail                       # re-arm: tsubame_setup runs `set +e`

export SPINORBEC_SCAN_ONLY_INDEX=$SGE_TASK_ID   # this task computes one point (2 seeds)
echo "[task $SGE_TASK_ID/$SGE_TASK_LAST] $(hostname)"; nvidia-smi -L || true

# Guard silent CPU fallback (a broken-CUDA node otherwise burns hours on CPU).
"$JULIA" --project=. -e '
    import CUDA
    CUDA.functional() || (@error "CUDA not functional — refusing CPU fallback"; exit(1))
    using SpinorBEC
    run_yaml(ARGS[1])' "$CONFIG"

echo "[task $SGE_TASK_ID] done"
