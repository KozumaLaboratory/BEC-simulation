#!/bin/bash
# ============================================================
#  UGE array submission — Eu F=6 GS phase diagram, 128³ (Stage B).
#  120 (c1×Bz×κ) points; each task runs one point × 2 seeds.
#
#  Submit from TSUBAME login node:
#      cd $PROJECT_ROOT && git pull
#      qsub -g <GROUP> runs/eu_gs_phase_c1_B_kappa/submit_array.sh
#
#  >>> FILL THESE (see report; user provides) <<<
#    GROUP       = TSUBAME billing group   (qsub -g flag)
#    OUTPUT_ROOT = /gs/bs/work/<n>/<user>/bec-runs/eu_gs_phase_c1_B_kappa
# ============================================================
#$ -cwd
#$ -N eu_gs_phase
#$ -l gpu_1=1
#$ -l h_rt=3:00:00
#$ -t 1-120
#$ -j n

set -euo pipefail

PROJECT_ROOT=$HOME/bec-simulation                              # <-- confirm
CONFIG_SRC=$PROJECT_ROOT/runs/eu_gs_phase_c1_B_kappa/config.yaml
OUTPUT_ROOT=__FILL_OUTPUT_ROOT__                               # <-- FILL
mkdir -p "$OUTPUT_ROOT/logs"

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail
export JULIA_DEPOT_PATH="$JULIA_DEPOT_PATH:$HOME/.julia"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

CONFIG_DST=$OUTPUT_ROOT/config.yaml
[ -f "$CONFIG_DST" ] || cp "$CONFIG_SRC" "$CONFIG_DST"

export SPINORBEC_SCAN_ONLY_INDEX=$SGE_TASK_ID                  # one point per task
echo "[task $SGE_TASK_ID/$SGE_TASK_LAST] $(hostname)"; nvidia-smi -L || true
"$JULIA" --project=. -e "import CUDA; using SpinorBEC; run_yaml(\"$CONFIG_DST\")"
echo "[task $SGE_TASK_ID] done"
