#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:30:00
#$ -N itp_prize
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
nvidia-smi --query-gpu=name --format=csv,noheader || true
echo "### SMOKE"
$JULIA --project=. bench/itp_spin_chain_prize.jl 16 3 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
rc=${PIPESTATUS[0]}; echo "### smoke rc=$rc"
[ "$rc" -ne 0 ] && { echo "SMOKE FAILED"; echo "ALL DONE $(date)"; exit 1; }
# Only the sizes whose substep budget RECONCILED (99-102%). 32^3 came out 114%,
# so a saving quoted there would be a share of a breakdown that does not describe
# the step.
for n in 64 96; do
    echo; echo "### n=$n"
    $JULIA --project=. bench/itp_spin_chain_prize.jl $n 30 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
done
echo "ALL DONE $(date)"
