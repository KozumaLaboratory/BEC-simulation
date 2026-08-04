#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=3:00:00
#$ -N lhy_bound
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
echo "### SMOKE"
$JULIA --project=. bench/lhy_none_divergence_boundary.jl 16 100 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
rc=${PIPESTATUS[0]}; echo "### smoke rc=$rc"
[ "$rc" -ne 0 ] && { echo "SMOKE FAILED"; echo "ALL DONE $(date)"; exit 1; }
echo; echo "### PRODUCTION"
$JULIA --project=. bench/lhy_none_divergence_boundary.jl 32 800 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
echo "ALL DONE $(date)"
