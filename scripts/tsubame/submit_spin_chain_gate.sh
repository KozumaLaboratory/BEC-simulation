#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:30:00
#$ -N chain_gate
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
set -u
export JULIA_DEPOT_PATH="$HOME/.julia"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}"
if [ -n "$(git status --porcelain -- src)" ]; then
    echo "REFUSING: src/ is dirty in $(pwd)"; git status --porcelain -- src
    echo "ALL DONE $(date)"; exit 1
fi
echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD) dirty=$(git status --porcelain|wc -l)"
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -2
# The bit-identity claim for the RTP path rests on this one file. Run it alone
# and read every line: a filter here could hide the arm that failed.
$JULIA --project=. -e 'import CUDA; using SpinorBEC; include("test/oracles/test_spin_chain_fusion_parity.jl")' 2>&1
echo "TEST_RC=$?"
echo "ALL DONE $(date)"
