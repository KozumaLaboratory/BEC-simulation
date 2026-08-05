#!/bin/bash
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=1:00:00
#$ -N psirepro
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# Can a psi hash serve as a parity oracle? Nothing filtered, exit codes echoed.
set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-ddi-conv}"
echo "host=$(hostname) commit=$(git rev-parse --short HEAD) date=$(date)"
export SPINORBEC_NO_AUTO_BACKEND=1
echo "julia threads=$($JULIA --project=. -e 'println(Threads.nthreads())')"
for rep in 1 2 3; do
    OPENBLAS_NUM_THREADS=1 $JULIA --project=. scripts/tsubame/jl/psi_reproducibility.jl "proc$rep"
    echo "### exit=$?"
done
echo "ALL DONE $(date)"
