#!/bin/bash
#$ -cwd
#$ -l cpu_4=1
#$ -l h_rt=0:20:00
#$ -N prof_gate
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -3
$JULIA --project=. -e '
using Test; using SpinorBEC
include("test/workflow/validation/test_accuracy_profiles.jl")
println(); SpinorBEC.accuracy_profile_report(:reference)
println(); SpinorBEC.accuracy_profile_report(:fast)' 2>&1
echo "ALL DONE $(date)"
