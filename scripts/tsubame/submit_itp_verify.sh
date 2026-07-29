#!/bin/bash
#$ -cwd
#$ -l cpu_4=1
#$ -l h_rt=0:40:00
#$ -N itp_verify
#$ -o /gs/bs/work/7/uk07267/logs/
#$ -e /gs/bs/work/7/uk07267/logs/
#
# Correctness gates for the ITP hot path, then the CPU breakdown. Run this on
# the optimised worktree; compare the breakdown against the baseline worktree's.
#   qsub -g tga-kozuma-kouhi -v SPINORBEC_BENCH_ROOT=<worktree> \
#        scripts/tsubame/submit_itp_verify.sh
set -u

export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-4}"

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/bs/work/7/uk07267/bec-perf-itp}"

echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD)"
echo "threads=$JULIA_NUM_THREADS"

echo; echo "###### GATES"
for t in hamiltonian/test_ddi_padded_zero_pad_invariant.jl \
    hamiltonian/test_ddi_padded.jl \
    hamiltonian/test_ddi.jl \
    hamiltonian/test_spin_mixing.jl \
    hamiltonian/test_ddi_truncated_kernel.jl \
    solvers/test_itp_ddi_strang_save_every.jl \
    oracles/test_ddi_translation_covariance.jl \
    oracles/test_spin_density_consistency.jl; do
    echo "--- $t"
    $JULIA --project=. -e "using SpinorBEC; include(\"test/$t\")" 2>&1 | tail -20
    echo "--- rc=$?"
done

echo; echo "###### BREAKDOWN"
for cfg in "cpu 32 none" "cpu 48 none"; do
    echo; echo "###### CONFIG: $cfg"
    $JULIA --project=. bench/bench_itp_step.jl $cfg 2>&1
done
echo "ALL DONE $(date)"
