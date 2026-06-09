#!/bin/bash
# ============================================================
#  UGE array submission for the ±120 μG B-field sweep (v3).
#
#  Each array task picks one Bz point via SPINORBEC_SCAN_ONLY_INDEX
#  (mapped to SGE_TASK_ID) and runs ITP for that point only.
#
#  Submit from TSUBAME login node:
#      cd ~/bec-simulation
#      git pull origin feat/eu151-B-sweep
#      qsub -g <YOUR_GROUP> runs/eu151_B_sweep_pm120/submit_array.sh
#
#  Outputs:
#    /gs/bs/work/6/ue06186/bec-runs/projectA_ground_state/
#       survey_B_secular_false_pm120_v3/
#         ├── config.yaml          (snapshot of v3, written by first task)
#         ├── point_001.jld2 … point_047.jld2
#         └── logs/task_<JOBID>.<TASKID>.out|err
# ============================================================
#$ -cwd
#$ -N eu151_B_sweep_v3
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -t 1-47
#$ -j n
#$ -o /gs/bs/work/6/ue06186/bec-runs/projectA_ground_state/survey_B_secular_false_pm120_v3/logs/
#$ -e /gs/bs/work/6/ue06186/bec-runs/projectA_ground_state/survey_B_secular_false_pm120_v3/logs/

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────
PROJECT_ROOT=$HOME/bec-simulation
CONFIG_SRC=$PROJECT_ROOT/runs/eu151_B_sweep_pm120/config_scan_B_pm120_v3.yaml

OUTPUT_ROOT=/gs/bs/work/6/ue06186/bec-runs/projectA_ground_state/survey_B_secular_false_pm120_v3
mkdir -p "$OUTPUT_ROOT/logs"

# ── Environment (depot on NVMe, modules, threads) ──────────────────────
cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh

# ── Stage config into the output dir (idempotent) ──────────────────────
# Naming as config.yaml means run_yaml treats $OUTPUT_ROOT itself as the
# run directory and writes point_*.jld2 alongside.
CONFIG_DST=$OUTPUT_ROOT/config.yaml
if [ ! -f "$CONFIG_DST" ]; then
    cp "$CONFIG_SRC" "$CONFIG_DST"
fi

# ── Array hook: each task runs only scan.points[SGE_TASK_ID] ───────────
export SPINORBEC_SCAN_ONLY_INDEX=$SGE_TASK_ID

echo "[task $SGE_TASK_ID/$SGE_TASK_LAST] running point $SGE_TASK_ID on $(hostname)"
nvidia-smi -L || true

julia --project=. -e "using SpinorBEC; run_yaml(\"$CONFIG_DST\")"

echo "[task $SGE_TASK_ID] done"
