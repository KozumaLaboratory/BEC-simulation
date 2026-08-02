#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:30:00
#$ -N chain_gate
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -2
# The bit-identity claim for the RTP path rests on this one file. Run it alone
# and read every line: a filter here could hide the arm that failed.
$JULIA --project=. -e 'import CUDA; using SpinorBEC; include("test/oracles/test_spin_chain_fusion_parity.jl")' 2>&1
echo "TEST_RC=$?"
echo "ALL DONE $(date)"
