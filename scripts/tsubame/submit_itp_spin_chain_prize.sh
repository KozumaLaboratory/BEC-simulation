#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:30:00
#$ -N itp_prize
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
set -u
export JULIA_DEPOT_PATH="$HOME/.julia"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}"
if [ -n "$(git status --porcelain -- src)" ]; then
    echo "REFUSING: src/ is dirty in $(pwd) — this run would not be attributable"
    git status --porcelain -- src; echo "ALL DONE $(date)"; exit 1
fi
FILT='loaded from a system path|This may cause errors|If you.re running under a profiler|ensure that your library path|In any other case, please file an issue|^│ *$|^└ @ CUDA|^┌ Warning: CUDA runtime library'
echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD) dirty=$(git status --porcelain|wc -l)"
nvidia-smi --query-gpu=name --format=csv,noheader || true
echo "### SMOKE"
$JULIA --project=. bench/itp_spin_chain_prize.jl 16 3 2>&1 | grep --line-buffered -vE "$FILT"
rc=${PIPESTATUS[0]}; echo "### smoke rc=$rc"
[ "$rc" -ne 0 ] && { echo "SMOKE FAILED"; echo "ALL DONE $(date)"; exit 1; }
# Only the sizes whose substep budget RECONCILED (99-102%). 32^3 came out 114%,
# so a saving quoted there would be a share of a breakdown that does not describe
# the step.
for n in 64 96; do
    echo; echo "### n=$n"
    $JULIA --project=. bench/itp_spin_chain_prize.jl $n 30 2>&1 | grep --line-buffered -vE "$FILT"
done
echo "ALL DONE $(date)"
