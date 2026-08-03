#!/bin/bash
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=1:00:00
#$ -N psicause
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# WHICH stage first differs across processes? Nothing filtered.
set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-ddi-conv}"
echo "host=$(hostname) commit=$(git rev-parse --short HEAD) date=$(date)"
export SPINORBEC_NO_AUTO_BACKEND=1
for rep in 1 2 3; do
    OPENBLAS_NUM_THREADS=1 $JULIA --project=. scripts/tsubame/jl/psi_cause_probe.jl "p$rep"
    echo "### exit=$?"
done
echo "ALL DONE $(date)"
