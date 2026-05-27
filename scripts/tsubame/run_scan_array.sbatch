#!/bin/bash
#$ -cwd
#$ -l h_rt=12:00:00
#$ -l f_node=1
#$ -t 1-11        # array of 11 = 3 Dy + 8 Eu configs (adjust if scan changes)
#$ -tc 4          # max 4 concurrent (TSUBAME node has limited GPU sharing)
#$ -N spinor_scan
#$ -o logs/tsubame/$JOB_NAME_$JOB_ID_$TASK_ID.log
#$ -j y

# TSUBAME job array driver for the high-resolution Dy + Eu scan.
#
# Submit:
#   julia --project=. scripts/tsubame/generate_hires_scan.jl   # one-shot, populates runs/tsubame_scan/
#   qsub scripts/tsubame/run_scan_array.sbatch
#
# Each task picks one config from runs/tsubame_scan/ (sorted alphabetically)
# and runs it. Job status:
#   qstat -j $JOB_ID
#   qstat -u $USER -t

. /etc/profile.d/modules.sh
module load cuda/12.6.0
module load julia/1.12.6 || true

PROJECT_ROOT=/gs/bs/${USER}/SpinorBEC.jl
cd "$PROJECT_ROOT" || exit 1
mkdir -p logs/tsubame

# --- Pick this task's config by index (1-based, sorted) ---
mapfile -t CONFIGS < <(ls -d runs/tsubame_scan/*/ | sort | awk -F/ '{print $(NF-1)}')
RUN_NAME="${CONFIGS[$((SGE_TASK_ID - 1))]}"

if [ -z "$RUN_NAME" ]; then
    echo "Task $SGE_TASK_ID: no config found"
    exit 1
fi

echo "[$(date)] Task $SGE_TASK_ID/$SGE_TASK_LAST starting $RUN_NAME"

# --- Node-local scratch ---
export SPINORBEC_SCRATCH_DIR=$T3TMPDIR/${JOB_ID}_${SGE_TASK_ID}
mkdir -p "$SPINORBEC_SCRATCH_DIR"

# --- CUDA paths (verify on TSUBAME — may need adjustment) ---
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# --- Sysimage support (optional) ---
# If `spinor_sysimage.so` exists at the project root (built once via
# `scripts/tsubame/build_sysimage.jl`), each task skips the SpinorBEC
# JIT cost (~30-60 sec/job → ~5 min saved across an 8-job array).
SYSIMAGE_FLAG=""
if [ -f "$PROJECT_ROOT/spinor_sysimage.so" ]; then
    SYSIMAGE_FLAG="--sysimage=$PROJECT_ROOT/spinor_sysimage.so"
    echo "[$(date)] using sysimage: $SYSIMAGE_FLAG"
fi

# --- Run via the canonical launcher ---
# Dashboard-canonical save_rotating_basis_result! is auto-invoked
# from run_pipeline (since 2026-04-29).
julia --project=. $SYSIMAGE_FLAG \
    scripts/cli.jl launch tsubame_scan "$RUN_NAME"

echo "[$(date)] Task $SGE_TASK_ID done"
