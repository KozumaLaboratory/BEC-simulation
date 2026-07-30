#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:30:00
#$ -N perterm
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#
# The per-term parity gate went 156/156 -> 2 pass / 14 error on this branch, and
# the gates runner pipes each file through `tail -25`, which cuts the exception
# header. This runs that one file with nothing truncated, after instantiating so
# a depot that has lost CUDA cannot be mistaken for the change under test.
set -u
export JULIA_DEPOT_PATH="$HOME/.julia"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-ddi-conv}"
echo "host=$(hostname) commit=$(git rev-parse --short HEAD)"
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -5
$JULIA --project=. -e 'using Test; import CUDA; using SpinorBEC;
    println("CUDA functional: ", CUDA.functional());
    include("test/oracles/test_gpu_cpu_per_term_parity.jl")' 2>&1 | grep -vE "^│|^└|^┌"
echo "rc=$?"
echo "ALL DONE $(date)"
