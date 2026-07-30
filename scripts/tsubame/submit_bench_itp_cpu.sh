#!/bin/bash
#$ -cwd
#$ -l cpu_4=1
#$ -l h_rt=0:25:00
#$ -N bench_itp_cpu
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#
# CPU-side ITP kernel breakdown. Short h_rt so UGE backfills it ahead of the
# long GPU queue.
#   qsub -g tga-kozuma-kouhi scripts/tsubame/submit_bench_itp_cpu.sh
set -u

export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-4}"

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-perf-itp}"

echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD)"
echo "threads=$JULIA_NUM_THREADS"

for cfg in "cpu 32 none" "cpu 48 none"; do
    echo; echo "###### CONFIG: $cfg"
    $JULIA --project=. bench/bench_itp_step.jl $cfg 2>&1
    echo "###### rc=$?"
done
echo "ALL DONE $(date)"
