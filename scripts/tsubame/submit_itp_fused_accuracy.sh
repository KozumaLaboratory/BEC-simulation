#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -N itp_facc
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
nvidia-smi --query-gpu=name --format=csv,noheader || true
echo "### SMOKE"
$JULIA --project=. bench/itp_fused_chain_accuracy.jl 16 400 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
rc=${PIPESTATUS[0]}; echo "### smoke rc=$rc"
[ "$rc" -ne 0 ] && { echo "SMOKE FAILED"; echo "ALL DONE $(date)"; exit 1; }
# A MATRIX, not one point. The 2.9x-at-equal-accuracy claim rests on 64^3 with
# c1_ratio = +0.05, and CLAUDE.md records that c1 < 0 is the sign Eu F=6
# production uses — so the configuration the claim is FOR had never been run. The
# grid is varied for the same reason: one point cannot tell a property of the
# scheme from a coincidence of the state.
# ONE CONFIG PER JOB, taken from $CFG. Four configs in one job meant a slow one
# starved the other three: the c₁ < 0 arm ran 2.5 h without finishing and was
# killed at the wall clock, losing two configs that had never started. Separate
# jobs also let a slow config get its own h_rt instead of the whole matrix
# inheriting the worst case.
#   qsub -v CFG="64 40000 -0.05 none" scripts/tsubame/submit_itp_fused_accuracy.sh
# FOUR variables, not one space-separated string: `qsub -v CFG="64 40000 …"` is
# split by the shell before UGE ever sees it — "Unable to read script file because
# of error: error opening 40000". Nothing about a space-containing value survives
# that path, so the config is passed as separate names.
CFG="${CFG_N:-64} ${CFG_STEPS:-40000} ${CFG_C1:-0.05} ${CFG_LHY:-polar_contact}"
echo; echo "### PRODUCTION n/steps/c1/lhy = ${CFG}"
$JULIA --project=. bench/itp_fused_chain_accuracy.jl ${CFG} 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
echo "ALL DONE $(date)"
