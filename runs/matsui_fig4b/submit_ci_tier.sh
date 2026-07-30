#!/bin/bash
# UGE — run the `ci` test tier for this branch on a CPU node.
#
# The repo's required GitHub checks do not cover the `ci` tier, so a green PR
# says nothing about it. This is the evidence that
# test/validation/test_matsui_fig4_dip.jl is actually gated where its tier entry
# claims, and that adding it did not redden anything else.
#
#   qsub -g tga-kozuma-kouhi runs/matsui_fig4b/submit_ci_tier.sh
#$ -cwd
#$ -N f4b_ci
#$ -l cpu_16=1
#$ -l h_rt=4:00:00
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/wt_matsui_fig4b
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH}:/gs/fs/tga-kozuma-kouhi/shared/.julia:${HOME}/.julia"

echo "[ci] $(hostname)  HEAD $(git rev-parse --short HEAD)  $(git status --porcelain | wc -l) dirty"

export SPINORBEC_TEST_TIER=ci
export SPINORBEC_TEST_WORKERS=auto
export SPINORBEC_TEST_TIMING=quiet

"$JULIA" --project=. -e 'using Pkg; Pkg.test()'
