#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -N phase_gap
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#
# How much accuracy does separating two ground-state phases need? Measures the
# GAP between competing states, not the total energy, plus the slope that turns
# an energy error into a boundary shift.
#   qsub -g tga-kozuma-kouhi -v SPINORBEC_BENCH_ROOT=<worktree> \
#        scripts/tsubame/submit_phase_gap_budget.sh
set -u
# `--line-buffered` is not optional here. Julia flushing its own stdout after each
# row buys nothing if grep then holds the line: GNU grep buffers its OUTPUT
# whenever stdout is not a tty, which is always in a batch job. Without this the
# rows arrive in one block at the end and the run is unreadable while alive —
# exactly the problem the per-row flush was added to fix.
#
# The output filter below drops ONLY the CUDA library-path warning boxes, which
# are noise on every TSUBAME node. DO NOT widen it to `^│|^└|^┌`: that swallows
# every Julia @warn, and on 2026-07-30 it destroyed the one piece of evidence
# that could distinguish two explanations for a non-converging reference arm —
# `full_bdg` warns exactly when the mean field is dynamically unstable, which is
# the case where there is no well-defined ground state to converge to at all.
export JULIA_DEPOT_PATH="$HOME/.julia"
export JULIA_NUM_THREADS="${NSLOTS:-8}"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
# A worktree of its OWN. `bec-ddi-conv` is shared, and on 2026-07-31 another
# session's uncommitted edits to src/ (LBFGS, make_workspace, a new analysis file)
# were present while this bench ran there — so a run logged as "commit=56149613"
# was executing different code, and my repeated `git reset --hard` on that
# directory may have destroyed that session's work. One worktree per running job.
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}"

# Refuse rather than produce an unattributable result. The cache already declines
# to LOAD when src/ is dirty; that is not enough, because the run still happens
# and its rows still get written under a commit hash that does not describe them.
if [ -n "$(git status --porcelain -- src)" ]; then
    echo "REFUSING: src/ is dirty in $(pwd) — this run would not be attributable"
    git status --porcelain -- src
    echo "ALL DONE $(date)"
    exit 1
fi
# The cell cache lives on the GROUP volume so it survives job-to-job: a run that
# changes only the reporting reuses every cell and costs no GPU. It is keyed on
# the tree hash of src/, so a physics change reuses nothing. Smoke and production
# write separate JSONLs — mixing 8^3 rows into the 32^3 record would be a silent
# corruption of the thing the report reads.
export SPINORBEC_GAP_CACHE=/gs/fs/tga-kozuma-kouhi/uk07267/gap_cache
mkdir -p "$SPINORBEC_GAP_CACHE"
# The dirty count belongs NEXT TO the hash: `git log -1` reports HEAD, which an
# aborted checkout leaves at the intended commit while the tree holds other files.
# The hash alone is not evidence about what ran.
echo "host=$(hostname) date=$(date) commit=$(git rev-parse --short HEAD) dirty=$(git status --porcelain | wc -l)"
nvidia-smi --query-gpu=name --format=csv,noheader || true
# SMOKE FIRST, at a size that renders every code path in seconds. CLAUDE.md asks
# for this before any launch over ~10 min, and skipping it cost a 19-second
# failure on a leftover rename that `submit_load_check.sh` cannot see — that
# checks src/ loads, not that a bench script runs.
echo "### SMOKE (tiny)"
SPINORBEC_GAP_JSONL="$SPINORBEC_GAP_CACHE/smoke.jsonl" \
    $JULIA --project=. bench/phase_gap_error_budget.jl 8 40 2>&1 | grep --line-buffered -vE "loaded from a system path|This may cause errors|If you.re running under a profiler|ensure that your library path|In any other case, please file an issue|^│ *$|^└ @ CUDA|^┌ Warning: CUDA runtime library"
smoke_rc=${PIPESTATUS[0]}
echo "### smoke rc=$smoke_rc"
if [ "$smoke_rc" -ne 0 ]; then
    echo "SMOKE FAILED — not starting the production run"
    echo "ALL DONE $(date)"
    exit 1
fi

echo; echo "### PRODUCTION"
$JULIA --project=. bench/phase_gap_error_budget.jl "${SPINORBEC_GAP_N:-32}" "${SPINORBEC_GAP_STEPS:-120000}" 2>&1 | grep --line-buffered -vE "loaded from a system path|This may cause errors|If you.re running under a profiler|ensure that your library path|In any other case, please file an issue|^│ *$|^└ @ CUDA|^┌ Warning: CUDA runtime library"
echo "ALL DONE $(date)"
