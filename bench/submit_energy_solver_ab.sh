#!/bin/bash
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=00:20:00
#$ -N energy_solver_ab
#$ -o logs/energy_solver_ab.out
#$ -e logs/energy_solver_ab.err
set -euo pipefail
trap 'rc=$?; echo "$rc" > "logs/energy_solver_${JOB_ID:-local}.rc"' EXIT
export JULIA_DEPOT_PATH=${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
export OPENBLAS_NUM_THREADS=1
export JULIA_NUM_THREADS=4
export SPINORBEC_FFT_PLAN=estimate
JULIA_BIN=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}
date -u
hostname
BENCH_ENTRY=${SPINORBEC_BENCH_ENTRY:-bench/energy_solver_ab.jl}
arms="baseline:C1 candidate:D1 candidate:D2 baseline:C2"
if [[ ${SPINORBEC_BENCH_ABLATION:-0} == 1 ]]; then
    arms="energy:E1 direction:F1 direction:F2 energy:E2"
fi
for spec in $arms; do
    "$JULIA_BIN" --project=. "$BENCH_ENTRY" "${spec%:*}" "${SPINORBEC_BENCH_PREFIX:-}${spec#*:}" "${SPINORBEC_BENCH_GRID:-32}" "${SPINORBEC_BENCH_PROFILE:-strong}"
done

if [[ ${SPINORBEC_BENCH_ABLATION:-0} != 1 ]]; then
    "$JULIA_BIN" --project=. bench/compare_solver_states.jl "${SPINORBEC_BENCH_PREFIX:-}"
fi
