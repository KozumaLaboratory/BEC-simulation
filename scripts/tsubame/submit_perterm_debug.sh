#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:30:00
#$ -N perterm
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
#
# The per-term parity gate went 156/156 -> 2 pass / 14 error on this branch, and
# the gates runner pipes each file through `tail -25`, which cuts the exception
# header. This runs that one file with nothing truncated, after instantiating so
# a depot that has lost CUDA cannot be mistaken for the change under test.
# The output filter below drops ONLY the CUDA library-path warning boxes, which
# are noise on every TSUBAME node. DO NOT widen it to `^│|^└|^┌`: that swallows
# every Julia @warn, and on 2026-07-30 it destroyed the one piece of evidence
# that could distinguish two explanations for a non-converging reference arm —
# `full_bdg` warns exactly when the mean field is dynamically unstable, which is
# the case where there is no well-defined ground state to converge to at all.
$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -5
$JULIA --project=. -e 'using Test; import CUDA; using SpinorBEC;
    println("CUDA functional: ", CUDA.functional());
    include("test/oracles/test_gpu_cpu_per_term_parity.jl")' 2>&1 | grep -vE "loaded from a system path|This may cause errors|If you.re running under a profiler|ensure that your library path|In any other case, please file an issue|^│ *$|^└ @ CUDA|^┌ Warning: CUDA runtime library"
echo "rc=$?"
echo "ALL DONE $(date)"
