#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=3:00:00
#$ -N pvar
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# WHICH LINE of cutover step 1 moves this config's numbers?
#
# Established (job 8339763, three repeats per side, separate processes):
#
#     before f2c609d1   E(point_020) = 10.603650095504927   3/3 bit-identical
#     after  f758d7d3   E(point_020) = 10.603740166491125   3/3 bit-identical
#
# Zero within-commit scatter on either side. The difference is deterministic and
# real: dE/E = 8.5e-6. The noise hypothesis is dead.
#
# The bisect (job 8339199) puts the whole of it in the FIRST cutover commit,
# 3a9bf499, and every later commit reproduces the same value. That commit's only
# changes on the run path are two metadata writes into the point files:
#
#     f["gs_cache_key"] = stage_ref
#     f["code_rev"]     = _code_rev_or_nothing()
#
# Neither can change physics by writing. But `_code_rev_or_nothing()` calls
# `code_tree_hash()`, which READS EVERY FILE under src/ and ext/ before the next
# point is solved — hundreds of allocations against the same pools the run uses.
# The config is a `pin: {epsilon_ramp: [...]}` continuation and reports
# conv=false at all 20 points, so it is exactly the shape that amplifies a
# last-ulp perturbation.
#
# That is a story, not a measurement. This job turns it into one: at HEAD,
# remove one line at a time and see which restores 4ef90c4b7d0f4145.
#
#   A. HEAD untouched                    -> expect c196cb3dce860f34
#   B. HEAD, code_rev write removed      -> back to 4ef9...?  (accuses the read)
#   C. HEAD, gs_cache_key write removed  -> back to 4ef9...?  (accuses the write)
#   D. HEAD, both removed                -> the conjunction
#
# Nothing filtered; exit codes echoed; every arm prints its own patch state so a
# silently-failed sed cannot masquerade as a null result.
set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
ROOT=/gs/fs/tga-kozuma-kouhi/uk07267
W=$ROOT/parity_var
CFG=runs/eu_gs_phase_c1_B_kappa/config_c1kappa_preview_B10.yaml
DUMP=$ROOT/bec-ddi-conv/scripts/tsubame/jl/dump_scan_energies.jl

echo "host=$(hostname) date=$(date)"
nvidia-smi --query-gpu=name --format=csv,noheader | head -1

rm -rf "$W"; git clone -q $ROOT/parity_after "$W"
cd "$W"
echo "checkout $(git rev-parse --short HEAD)"

arm () {   # $1 = label
    local tag=$1
    echo "### ARM $tag"
    echo "--- patch state: code_rev writes = $(grep -c 'f\["code_rev"\]' src/workflow/experiments/pipeline/*.jl | awk -F: '{s+=$2} END {print s}'), gs_cache_key writes = $(grep -c 'f\["gs_cache_key"\]' src/workflow/experiments/pipeline/*.jl | awk -F: '{s+=$2} END {print s}')"
    local STORE=$ROOT/var_store_$tag
    rm -rf "$STORE"
    SPINORBEC_STORE=$STORE $JULIA --project=. "$DUMP" "$CFG" "$tag"
    echo "### exit=$?"
}

arm A_untouched

git checkout -q -- src/
sed -i 's/^\(\s*\)\(code_rev === nothing || (f\["code_rev"\] = code_rev)\)/\1# PATCHED OUT: \2/' \
    src/workflow/experiments/pipeline/run_registry.jl src/workflow/experiments/pipeline/run_step_ground_state.jl
sed -i 's/^\(\s*\)\(code_rev = _code_rev_or_nothing()\)/\1# PATCHED OUT: \2/' \
    src/workflow/experiments/pipeline/run_registry.jl src/workflow/experiments/pipeline/run_step_ground_state.jl
arm B_no_code_rev

git checkout -q -- src/
sed -i 's/^\(\s*\)\(.*f\["gs_cache_key"\] = .*\)$/\1# PATCHED OUT: \2/' \
    src/workflow/experiments/pipeline/run_registry.jl src/workflow/experiments/pipeline/run_step_ground_state.jl
arm C_no_cache_key

git checkout -q -- src/
sed -i 's/^\(\s*\)\(code_rev === nothing || (f\["code_rev"\] = code_rev)\)/\1# PATCHED OUT: \2/;s/^\(\s*\)\(code_rev = _code_rev_or_nothing()\)/\1# PATCHED OUT: \2/;s/^\(\s*\)\(.*f\["gs_cache_key"\] = .*\)$/\1# PATCHED OUT: \2/' \
    src/workflow/experiments/pipeline/run_registry.jl src/workflow/experiments/pipeline/run_step_ground_state.jl
arm D_neither

git checkout -q -- src/
echo "ALL DONE $(date)"
