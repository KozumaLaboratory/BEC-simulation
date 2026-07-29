#!/bin/bash
# UGE submission: run a test tier on a TSUBAME GPU node.
#
#   qsub -g tga-kozuma-kouhi -o $HOME/runs/tests/uge.log \
#        -v SPINORBEC_TSUBAME_PROJECT_ROOT=<worktree>,SBEC_TIER=ci \
#        scripts/submit_test_tier.sh
#
# Why this exists: branch protection requires only `fast` + `oracles`, so a
# green PR says nothing about the `ci` tier — #140 landed red through exactly
# that gap. The tier has to be run somewhere before merging anything under
# solvers/ hamiltonian/ analysis/, and a laptop is the wrong somewhere: the
# suite is long enough to matter and the local box runs several sessions.
#
# GPU node on purpose — the `ci` tier contains GPU=CPU parity gates that silently
# no-op without CUDA, which is the same "the gate never ran" failure in a
# different costume.
#
# NB: -g and -o go on the qsub CLI, not as directives (UGE rejects `#$ -g` and
# does not expand $HOME in directives).
#$ -cwd
#$ -N sbec_tier
#$ -l gpu_h=1
#$ -l h_rt=4:00:00
#$ -j y

set -euo pipefail

PROJECT_ROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:?set SPINORBEC_TSUBAME_PROJECT_ROOT}
TIER=${SBEC_TIER:-ci}
WORKERS=${SBEC_WORKERS:-auto}
OUT_DIR=${SPINORBEC_TSUBAME_RUNS_ROOT:-$HOME/runs}/tests
mkdir -p "$OUT_DIR"
cd "$PROJECT_ROOT"

source scripts/tsubame_setup.sh
. /etc/profile.d/modules.sh
module load "${SPINORBEC_TSUBAME_CUDA_MODULE:-cuda/12.8.0}"

# Node-local depot first so precompile output never touches the group quota
# (which sits at ~994/1000 GB); shared depot second for the installed packages.
SHARED_DEPOT=${SPINORBEC_TSUBAME_DEPOT:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
if [ -n "${T4_TMPDIR:-}" ] && [ -w "${T4_TMPDIR}" ]; then
    mkdir -p "$T4_TMPDIR/.julia"
    export JULIA_DEPOT_PATH="$T4_TMPDIR/.julia:$SHARED_DEPOT"
else
    export JULIA_DEPOT_PATH="$SHARED_DEPOT"
fi
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

echo "[sbec_tier] host=$(hostname)  tier=${TIER}  workers=${WORKERS}"
echo "[sbec_tier] HEAD=$(git rev-parse --short HEAD)  $(git log -1 --format=%s)"
git status --porcelain | head -20

SPINORBEC_TEST_TIER="$TIER" SPINORBEC_TEST_WORKERS="$WORKERS" \
    "$JULIA" --project=. -e 'using Pkg; Pkg.test()' \
    2>&1 | tee "$OUT_DIR/tier_${TIER}.out"

echo "[sbec_tier] done"
