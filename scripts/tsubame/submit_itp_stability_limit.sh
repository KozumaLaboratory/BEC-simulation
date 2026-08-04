#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -N itp_stab
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
export SPINORBEC_CELL_TIMING="${SPINORBEC_GAP_CACHE:-/gs/fs/tga-kozuma-kouhi/uk07267/gap_cache}/stability_cells.log"
echo "### SMOKE"
$JULIA --project=. bench/itp_stability_limit_vs_c0.jl 16 40 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
rc=${PIPESTATUS[0]}; echo "### smoke rc=$rc"
[ "$rc" -ne 0 ] && { echo "SMOKE FAILED"; echo "ALL DONE $(date)"; exit 1; }
echo; echo "### PRODUCTION"
$JULIA --project=. bench/itp_stability_limit_vs_c0.jl 32 600 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
echo "ALL DONE $(date)"
