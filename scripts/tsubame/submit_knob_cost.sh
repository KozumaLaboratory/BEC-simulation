#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:25:00
#$ -N knob_cost
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
# Filter CUDA library-path noise by CONTENT, never by the box characters — that
# swallows every @warn (2026-07-30).
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -3

echo "### SMOKE (tiny)"
$JULIA --project=. bench/accuracy_knob_cost.jl 8 3 2>&1 |
    grep -vE "loaded from a system path|This may cause errors|running under a profiler|library path environment|file an issue|In any other case"
smoke_rc=${PIPESTATUS[0]}
echo "### smoke rc=$smoke_rc"
[ "$smoke_rc" -ne 0 ] && { echo "SMOKE FAILED — not starting production"; echo "ALL DONE $(date)"; exit 1; }

echo; echo "### PRODUCTION"
$JULIA --project=. bench/accuracy_knob_cost.jl "${SPINORBEC_KNOB_N:-32}" 30 2>&1 |
    grep -vE "loaded from a system path|This may cause errors|running under a profiler|library path environment|file an issue|In any other case"
echo "ALL DONE $(date)"
