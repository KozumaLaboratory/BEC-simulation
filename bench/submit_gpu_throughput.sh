#!/bin/bash
# qsub -g GROUP -o logs/NAME.out -e logs/NAME.err \
#   bench/submit_gpu_throughput.sh bench/gradient_only_ab.jl
# Set SPINORBEC_TSUBAME_JULIA / SPINORBEC_BENCH_PROJECT / JULIA_DEPOT_PATH
# to compare an isolated runtime without changing the shared environment.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=00:20:00
#$ -N gpu_throughput
set -euo pipefail
mkdir -p logs
trap 'rc=$?; echo "$rc" > "logs/throughput_${JOB_ID:-local}.rc"' EXIT
[[ $# -gt 0 ]] || { echo 'Expected a Julia script and optional arguments' >&2; exit 2; }
export JULIA_DEPOT_PATH=${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
export OPENBLAS_NUM_THREADS=${OPENBLAS_NUM_THREADS:-1}
export JULIA_NUM_THREADS=${JULIA_NUM_THREADS:-4}
export SPINORBEC_FFT_PLAN=${SPINORBEC_FFT_PLAN:-estimate}
JULIA_BIN=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}
date -u
hostname
nvidia-smi --query-gpu=uuid,name,memory.total --format=csv
"$JULIA_BIN" --project="${SPINORBEC_BENCH_PROJECT:-.}" "$@"
