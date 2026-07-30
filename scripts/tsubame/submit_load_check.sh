#!/bin/bash
#$ -cwd
#$ -l cpu_4=1
#$ -l h_rt=0:15:00
#$ -N load_check
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#
# Does the package LOAD? A syntax error in src/ makes every other job on the
# branch a precompile failure, and a submit script that only runs a bench will
# report it as the bench failing. Cheap, and it must pass before anything else is
# submitted.
set -u
export JULIA_DEPOT_PATH="$HOME/.julia"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-ddi-conv}"
echo "host=$(hostname) commit=$(git rev-parse --short HEAD)"
$JULIA --project=. -e 'using SpinorBEC; println("LOADED ok  knobs=", length(SpinorBEC.ACCURACY_KNOBS))' 2>&1 | tail -20
echo "rc=$?"
$JULIA --project=. -e 'using Test; using SpinorBEC; include("test/workflow/validation/test_accuracy_knobs.jl")' 2>&1 | tail -20
echo "ALL DONE $(date)"
