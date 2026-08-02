#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:15:00
#$ -N ddi_conv
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
#
# Stage breakdown of the padded DDI convolution, at both production grid sizes.
#   qsub -g tga-kozuma-kouhi -v SPINORBEC_BENCH_ROOT=<worktree> \
#        scripts/tsubame/submit_profile_ddi_convolve.sh
# The output filter below drops ONLY the CUDA library-path warning boxes, which
# are noise on every TSUBAME node. DO NOT widen it to `^│|^└|^┌`: that swallows
# every Julia @warn, and on 2026-07-30 it destroyed the one piece of evidence
# that could distinguish two explanations for a non-converging reference arm —
# `full_bdg` warns exactly when the mean field is dynamically unstable, which is
# the case where there is no well-defined ground state to converge to at all.
nvidia-smi --query-gpu=name --format=csv,noheader || true
for n in 32 64; do
    echo; echo "###### n=$n"
    $JULIA --project=. bench/profile_ddi_convolve.jl "$n" 50 2>&1 | grep -vE "loaded from a system path|This may cause errors|If you.re running under a profiler|ensure that your library path|In any other case, please file an issue|^│ *$|^└ @ CUDA|^┌ Warning: CUDA runtime library"
done
echo "ALL DONE $(date)"
