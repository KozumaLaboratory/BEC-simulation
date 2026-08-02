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
# c₁ < 0 runs with `lhy=none`: `polar_contact` refuses there (σ₀ < 0), and that
# refusal is correct rather than an obstacle to route around. The fusion question
# is about freezing ⟨F⟩, and the fused diagonal absorbs a tabulated LHY completely
# (under 2 % in every substep), so the LHY-free chain is the same test.
for cfg in "64 40000 0.05 polar_contact" "64 40000 -0.05 none"            "64 40000 0.05 none" "96 40000 0.05 polar_contact"; do
    echo; echo "### PRODUCTION n/steps/c1 = $cfg"
    $JULIA --project=. bench/itp_fused_chain_accuracy.jl $cfg 2>&1 | grep --line-buffered -vE "$CUDA_NOISE"
done
echo "ALL DONE $(date)"
