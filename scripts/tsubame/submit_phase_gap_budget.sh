#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=1:00:00
#$ -N phase_gap
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#
# How much accuracy does separating two ground-state phases need? Measures the
# GAP between competing states, not the total energy, plus the slope that turns
# an energy error into a boundary shift.
#   qsub -g tga-kozuma-kouhi -v SPINORBEC_BENCH_ROOT=<worktree> \
#        scripts/tsubame/submit_phase_gap_budget.sh
set -u
export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-8}"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-ddi-conv}"
echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD)"
nvidia-smi --query-gpu=name --format=csv,noheader || true
$JULIA --project=. bench/phase_gap_error_budget.jl "${SPINORBEC_GAP_N:-24}" "${SPINORBEC_GAP_STEPS:-4000}" 2>&1 | grep -vE "^│|^└|^┌"
echo "ALL DONE $(date)"
