#!/bin/bash
#$ -cwd
#$ -l cpu_4=1
#$ -l h_rt=0:45:00
#$ -N itp_cpu_ab
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#
# Gates on the changed worktree, then the CPU ITP breakdown for BOTH arms in one
# allocation.
#   qsub -g tga-kozuma-kouhi \
#        -v SPINORBEC_AB_A=<baseline>,SPINORBEC_AB_B=<changed> \
#        scripts/tsubame/submit_itp_cpu_ab.sh
set -u

export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-4}"

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
A="${SPINORBEC_AB_A:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-perf-itp}"
B="${SPINORBEC_AB_B:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-itp-taylor}"
GATES="${SPINORBEC_AB_GATES:-hamiltonian/test_cpu_spin_rotation_taylor_parity.jl hamiltonian/test_spin_mixing.jl hamiltonian/test_ddi.jl hamiltonian/test_ddi_padded.jl solvers/test_itp_ddi_strang_save_every.jl oracles/test_spin_density_consistency.jl oracles/test_ddi_translation_covariance.jl analysis/test_spin_rotation.jl}"

echo "host=$(hostname) date=$(date) threads=$JULIA_NUM_THREADS"
echo "A=$A  B=$B"

echo; echo "###### GATES on B commit=$(cd "$B" && git rev-parse --short HEAD)"
for t in $GATES; do
    echo "--- $t"
    (cd "$B" && $JULIA --project=. \
        -e "using Test; using SpinorBEC; include(\"test/$t\")" 2>&1 | tail -12)
done

echo; echo "###### BREAKDOWN"
SCRIPT="$B/bench/bench_itp_step.jl"
for n in 32 48; do
    for root in "$A" "$B"; do
        echo; echo "--- n=$n ROOT=$root commit=$(cd "$root" && git rev-parse --short HEAD)"
        (cd "$root" && $JULIA --project=. "$SCRIPT" cpu "$n" none 2>&1 | tail -22)
    done
done
echo "ALL DONE $(date)"
