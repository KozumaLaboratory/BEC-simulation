#!/bin/bash
# UGE submission: run the defect-mutation catalog on a TSUBAME GPU node.
#
#   qsub -g tga-kozuma-kouhi -o $HOME/runs/mutation/uge.log \
#        -l h_rt=8:00:00 \
#        -v SPINORBEC_TSUBAME_PROJECT_ROOT=<checkout>,SBEC_MUT_PROBE=grounded_cheap \
#        scripts/submit_mutation_sweep.sh
#
# Why a GPU node, and why that is not optional. `test/mutation/run.jl` credits a
# test with catching a mutant when the file goes RED. A test that SKIPS is green,
# so on a node without CUDA every GPU-gated file is silently unable to catch
# anything, and the harness reports its mutants as ESCAPED. That is a report full
# of gaps that do not exist — the same "an empty testset is not a pass" mistake
# that cost a day on 2026-07-31, in a costume where it produces a plausible
# artifact instead of an obvious error.
#
# Why a DEDICATED checkout. The harness edits files under `src/` and restores
# them afterwards. Any other job reading the same tree mid-run compiles a
# deliberately broken source. The guard below refuses to start in the shared
# project root for that reason; give it its own directory.
#
# Cost: one package precompile per mutant, plus one probe pass. Measure with a
# 2-3 mutant smoke before sizing h_rt for the full catalog — the per-mutant cost
# is dominated by precompile and by which probe set was chosen, not by the
# mutation itself.
#$ -cwd
#$ -N sbec_mutation
#$ -l gpu_h=1
#$ -l h_rt=8:00:00
#$ -j y

set -euo pipefail

PROJECT_ROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:?set SPINORBEC_TSUBAME_PROJECT_ROOT}
SHARED_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
if [ "$(readlink -f "$PROJECT_ROOT")" = "$(readlink -f "$SHARED_ROOT")" ]; then
    echo "[sbec_mutation] REFUSING: this harness mutates src/ in place, and" >&2
    echo "[sbec_mutation] $SHARED_ROOT is the tree other jobs run from." >&2
    exit 2
fi

# qsub's `-v` value cannot carry a command line. It splits on BOTH commas (the
# separator between assignments) and spaces (end of the argument), so
# `SBEC_MUT_ARGS="--mutants a,b,c --probe oracles"` loses everything after the
# first space and qsub then tries to open `a` — or `zeeman_quadratic_sign` — as
# the script file. Quoting does not help; the split is qsub's, not the shell's.
#
# So the knobs are separate variables whose values contain neither, and the
# command line is assembled HERE. `+` stands in for the harness's `,`.
MUT_IDS=${SBEC_MUT_IDS:-}
MUT_PROBE=${SBEC_MUT_PROBE:-grounded_cheap}
MUT_ARGS=(--probe "${MUT_PROBE//+/,}")
[ -n "$MUT_IDS" ] && MUT_ARGS+=(--mutants "${MUT_IDS//+/,}")
[ -n "${SBEC_MUT_MAXCOST:-}" ] && MUT_ARGS+=(--max-cost "$SBEC_MUT_MAXCOST")
# Same reasoning as submit_test_tier.sh: each worker is an independent julia
# process holding SpinorBEC + CUDA, so memory and not the node's 384 cores is
# what bounds this.
WORKERS=${SBEC_WORKERS:-12}
TAG=${SBEC_MUT_TAG:-sweep}
OUT_DIR=${SPINORBEC_TSUBAME_RUNS_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/runs}/mutation/$TAG
mkdir -p "$OUT_DIR"
cd "$PROJECT_ROOT"

source scripts/tsubame_setup.sh
. /etc/profile.d/modules.sh
# BLAS pin, $HOME check, quota headroom, runs/ presence, cuda module — #272.
source scripts/tsubame/preflight.sh --gpu

# Node-local depot first so 58 precompiles never touch the group quota.
SHARED_DEPOT=${SPINORBEC_TSUBAME_DEPOT:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
if [ -n "${T4_TMPDIR:-}" ] && [ -w "${T4_TMPDIR}" ]; then
    mkdir -p "$T4_TMPDIR/.julia"
    export JULIA_DEPOT_PATH="$T4_TMPDIR/.julia:$SHARED_DEPOT"
else
    export JULIA_DEPOT_PATH="$SHARED_DEPOT"
fi

JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

echo "[sbec_mutation] host=$(hostname)  workers=${WORKERS}  args=${MUT_ARGS[*]}"
echo "[sbec_mutation] root=$PROJECT_ROOT"
echo "[sbec_mutation] HEAD=$(git rev-parse HEAD)  $(git log -1 --format=%s)"
# The sha above is the whole provenance of the result, so print the src/ diff
# state too: a harness that refuses to start on a dirty src/ still cannot tell
# you it was given the wrong commit.
git status --porcelain -- src test | head -20

# CUDA has to be visible from THIS process, not assumed from the queue name.
"$JULIA" --project=. -e 'using CUDA; println("[sbec_mutation] CUDA.functional() = ", CUDA.functional()); CUDA.functional() || exit(3)' || {
    echo "[sbec_mutation] ABORT: no usable GPU — every GPU-gated file would SKIP," >&2
    echo "[sbec_mutation] and a skipped file reports its mutants as ESCAPED." >&2
    exit 3
}

set +e
"$JULIA" --project=. test/mutation/run.jl \
    --workers "$WORKERS" --out "$OUT_DIR" "${MUT_ARGS[@]}" \
    > "$OUT_DIR/sweep.out" 2>&1
status=$?
set -e

tail -60 "$OUT_DIR/sweep.out"
echo "[sbec_mutation] artifacts: $OUT_DIR/{sweep.out,catch_matrix.csv,report.md}"

if [ $status -eq 0 ]; then
    echo "[sbec_mutation] DONE  (exit=0)"
else
    echo "[sbec_mutation] FAIL  (exit=${status})"
    [ $status -eq 137 ] && echo "[sbec_mutation] exit 137 = SIGKILL, almost certainly OOM — lower SBEC_WORKERS"
    # A mutation left in src/ is a silently wrong repository. The harness
    # restores in a `finally` and recovers from a sidecar on the next run, but
    # say it here too: this log is what gets read after a killed job.
    git -C "$PROJECT_ROOT" diff --quiet -- src ||
        echo "[sbec_mutation] WARNING: src/ is dirty — a mutation may be left behind"
fi
exit $status
