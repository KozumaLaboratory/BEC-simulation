#!/bin/bash
#SBATCH --job-name=spinorbec
#SBATCH --partition=gpu_h
#SBATCH --gres=gpu:h100:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --time=12:00:00
#SBATCH --requeue
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err
#
# Single H100 SXM (80 GB) on TSUBAME 4. Run a single config:
#   sbatch scripts/slurm/eu151_h100_single.sbatch runs/eu151_edh_ext/config.yaml
#
# --requeue lets SLURM auto-restart on preemption; SpinorBEC's
# checkpoint logic resumes from the last .checkpoints/ snapshot.

set -euo pipefail

CONFIG="${1:?usage: sbatch $0 <config.yaml>}"
PROJECT="$SLURM_SUBMIT_DIR"

mkdir -p "$PROJECT/logs"
cd "$PROJECT"

source scripts/tsubame_setup.sh

# Verbose CUDA report at start
julia --project="$PROJECT" -e '
    import CUDA
    using SpinorBEC
    @info "CUDA" device = CUDA.name(CUDA.device()) mem_gb = CUDA.totalmem(CUDA.device()) / 2^30
    @info "Project" project = "'$PROJECT'" config = "'$CONFIG'"
    @info "Budget"; estimate_run_budget("'$CONFIG'")
    run_yaml("'$CONFIG'")
'

# Optional: notify on completion (no-op without SLACK_WEBHOOK_URL)
julia --project="$PROJECT" scripts/notify_slack.jl \
    ":white_check_mark: SLURM ${SLURM_JOB_NAME} #${SLURM_JOB_ID} done — config=$CONFIG"
