#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:40:00
#$ -N itp_prof
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
nvidia-smi --query-gpu=name --format=csv,noheader || true
echo "### SMOKE"
$JULIA --project=. bench/profile_itp_substeps.jl 8 3 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
rc=${PIPESTATUS[0]}; echo "### smoke rc=$rc"
[ "$rc" -ne 0 ] && { echo "SMOKE FAILED"; echo "ALL DONE $(date)"; exit 1; }
for n in 64 96; do
    for lhy in polar_contact; do
        echo; echo "### n=$n lhy=$lhy"
        $JULIA --project=. bench/profile_itp_substeps.jl $n 50 $lhy 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
    done
done
echo "ALL DONE $(date)"
