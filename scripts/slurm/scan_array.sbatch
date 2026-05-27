#!/bin/bash
#SBATCH --job-name=spinorbec_scan
#SBATCH --partition=gpu_h
#SBATCH --gres=gpu:h100:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --time=06:00:00
#SBATCH --requeue
#SBATCH --array=1-12%4                  # 12 scan points, 4 in flight at once
#SBATCH --output=logs/%x-%A_%a.out
#SBATCH --error=logs/%x-%A_%a.err
#
# SLURM array job: each task computes ONE scan point of a multi-point
# YAML by setting SPINORBEC_SCAN_ONLY_INDEX. Useful for embarrassingly
# parallel (p, q) phase diagrams across multiple H100 nodes — runs
# 4× faster than a single-job scan loop.
#
# Usage:
#   sbatch --array=1-N scripts/slurm/scan_array.sbatch runs/eu151_phase_pq_hires/config.yaml
#
# (N must match the actual scan point count; use
# `julia --project=. -e 'using SpinorBEC; println(scan_point_count(ARGS[1]))' <yaml>`
# to get the right N.)

set -euo pipefail

CONFIG="${1:?usage: sbatch $0 <config.yaml>}"
PROJECT="$SLURM_SUBMIT_DIR"

mkdir -p "$PROJECT/logs"
cd "$PROJECT"

source scripts/tsubame_setup.sh

export SPINORBEC_SCAN_ONLY_INDEX="$SLURM_ARRAY_TASK_ID"

julia --project="$PROJECT" -e '
    using CUDA, SpinorBEC
    @info "Array task" idx=ENV["SPINORBEC_SCAN_ONLY_INDEX"] config=ARGS[1]; run_yaml(ARGS[1])
' "$CONFIG"
