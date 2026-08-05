#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -N pwithin
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# THE CONTROL THE PARITY INVESTIGATION NEVER RAN.
#
# Established so far:
#   * origin/main through the bisect probe reproduces 4ef90c4b7d0f4145 exactly,
#     and every one of the 20 cutover commits gives c196cb3dce860f34 — stable
#     on both sides, so the difference is deterministic, not random (job
#     8339310 + 8339199).
#   * psi across PROCESSES differs at 1e-16 from FFTW plan/alignment alone,
#     while the energy agrees to 3e-16; within a process it is bit-exact
#     (job 8339525).
#   * cutover step 1's only run-path change is writing two metadata keys, one
#     of which calls `code_tree_hash()` — a full read of src/ + ext/ — before
#     the solve. Enough to move allocation alignment, hence the plan, hence
#     psi at 1e-16.
#
# What that does NOT explain is the energy: up to 9.0e-5 absolute / 8.5e-6
# relative on config_c1kappa_preview_B10, which is 1e10 times the 1e-16 noise.
# That config carries `pin: {kind: transverse, epsilon_ramp: [...]}` — an
# epsilon-continuation, a sequence of solves — so the hypothesis is that it
# amplifies a last-ulp perturbation. Points 007 and 012 came back bit-identical
# across sides while others moved, which is what a sensitive-but-deterministic
# process looks like and not what a physics change looks like.
#
# So: run the SAME config at the SAME commit, in separate processes, three
# times. If the energies scatter by ~1e-5 within one commit, the cross-commit
# difference IS that scatter and the cutover is exonerated. If they are
# bit-identical within a commit, the difference is real and the cutover owns it.
#
# Nothing filtered. Exit codes echoed.
set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
ROOT=/gs/fs/tga-kozuma-kouhi/uk07267
CFG=runs/eu_gs_phase_c1_B_kappa/config_c1kappa_preview_B10.yaml

echo "host=$(hostname) date=$(date)"
nvidia-smi --query-gpu=name --format=csv,noheader | head -1

for side in parity_before parity_after; do
    D=$ROOT/$side
    [ -d "$D" ] || { echo "MISSING $D"; continue; }
    echo "### $side  $(cd $D && git rev-parse --short HEAD)"
    for rep in 1 2 3; do
        STORE=$ROOT/within_store_${side}_$rep
        rm -rf "$STORE"
        (cd "$D" && SPINORBEC_STORE=$STORE $JULIA --project=. \
            "$ROOT/bec-ddi-conv/scripts/tsubame/jl/dump_scan_energies.jl" "$CFG" "$side/rep$rep")
        echo "### exit=$?"
    done
done
echo "ALL DONE $(date)"
