#!/bin/bash
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=1:00:00
#$ -N openinf
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# The unified design says an influence left OUTSIDE the name must carry a
# MEASURED cost against a budget, and `isnan(cost)` is red at build. Three rows
# are carried as `:dropped` because nobody has measured them on psi: the FFTW
# planner effort, the OpenBLAS thread count, and their interaction with the ITP
# loop. They are declared OPEN, so the question is not whether a different
# summation order can move the answer — of course it can — but HOW MUCH, on the
# state, in this regime.
#
# One process per condition: FFTW's plan cache and BLAS's team are
# process-global, so comparing them inside one session measures whichever was
# set first.
#
# NOTHING IS FILTERED. The previous revision piped through
# `grep -E '^COST|ERROR|Exception'` and the job finished in 17 s having printed
# five headers and no rows — the failure had none of those three shapes, so the
# filter reported silence as success.
set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-ddi-conv}"
echo "host=$(hostname) commit=$(git rev-parse --short HEAD) date=$(date)"
export SPINORBEC_NO_AUTO_BACKEND=1
PROBE=scripts/tsubame/jl/open_influence_probe.jl

$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -2

# SMOKE FIRST, inside the job. If the probe cannot run at all, say so here
# rather than five silent conditions later.
echo "### smoke: does the probe run?"
OPENBLAS_NUM_THREADS=1 $JULIA --project=. "$PROBE" smoke
echo "### smoke exit=$?"

for omp in 1 4 16; do
    echo "### OPENBLAS_NUM_THREADS=$omp"
    OPENBLAS_NUM_THREADS=$omp $JULIA --project=. "$PROBE" "blas$omp"
    echo "### exit=$?"
done

echo "### FFTW MEASURE (planner effort), blas=1"
OPENBLAS_NUM_THREADS=1 SPINORBEC_FFTW_PLAN=MEASURE $JULIA --project=. "$PROBE" blas1_measure
echo "### exit=$?"

echo "ALL DONE $(date)"
