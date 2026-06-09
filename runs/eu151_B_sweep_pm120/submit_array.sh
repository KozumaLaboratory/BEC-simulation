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
set -euo pipefail  # tsubame_setup.sh resets errexit; restore it

# tsubame_setup.sh overrides JULIA_DEPOT_PATH to a fresh NVMe temp (fast
# writes) but that temp is empty. We need two fallback depots:
#   1. $HOME/.julia  — user-writable; holds instantiated packages +
#                      precompiled .ji cache (built once on the login node).
#   2. shared depot  — group read-only fallback for any remaining packages.
# NVMe temp stays first so any new precompile writes go there, not HOME.
SHARED_DEPOT=/gs/fs/tga-kozuma-kouhi/shared/.julia
HOME_DEPOT=$HOME/.julia
export JULIA_DEPOT_PATH="$JULIA_DEPOT_PATH:$HOME_DEPOT:$SHARED_DEPOT"

# Use the direct Julia binary — bypasses juliaup launcher which tries to
# update juliaupself.json in the group-shared area (no write permission).
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

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

"$JULIA" --project=. -e "using SpinorBEC; run_yaml(\"$CONFIG_DST\")"

echo "[task $SGE_TASK_ID] done"
