# Shared preamble for every submit script: pick the worktree, then REFUSE if it
# is not attributable.
#
# Sourced, not copied. Eight scripts each carried their own `cd` line and only
# some were moved off the shared `bec-ddi-conv` tree, so on 2026-08-02 two gates
# ran there — `git log -1` printed my commit while `src/` held twelve files of
# another session's work and a test file WITHOUT the testset the gate existed to
# run. Both came back green and neither result was about my code. One `cd` line,
# one guard, one place to change them.
#
# Usage, after the UGE directives:
#     source "$(dirname "$0")/_preamble.sh"

set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-$HOME/.julia}"
export SPINORBEC_TSUBAME_JULIA="${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}"
JULIA="$SPINORBEC_TSUBAME_JULIA"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true

# A worktree of its OWN by default. `bec-ddi-conv` is shared with other sessions.
cd "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}" || exit 1

echo "host=$(hostname) date=$(date) pwd=$(pwd)"
echo "commit=$(git rev-parse --short HEAD) dirty=$(git status --porcelain | wc -l)"

# The hash alone is not evidence about what ran: an aborted checkout leaves HEAD
# at the intended commit while the tree holds other files, and a shared tree can
# be edited under a running job. Refuse rather than produce a result nobody can
# attribute — and refuse on src/ specifically, since that is what the package is
# built from.
if [ -n "$(git status --porcelain -- src)" ]; then
    echo "REFUSING: src/ is dirty in $(pwd) — this run would not be attributable"
    git status --porcelain -- src
    echo "ALL DONE $(date)"
    exit 1
fi

# Filter CUDA's library-path box by CONTENT. Never by the box glyphs alone: they
# are what Julia's own @warn uses, and matching on them once deleted the single
# line explaining two failed measurement rounds.
# Cell-timing sink, exported HERE so a new submit script cannot forget it. Three
# benches in a row had their per-cell instrumentation land in a node-local
# `tempdir()` because the script did not export this, and each time the result was
# a run with no visibility into where its time went.
export SPINORBEC_GAP_CACHE="${SPINORBEC_GAP_CACHE:-/gs/fs/tga-kozuma-kouhi/uk07267/gap_cache}"
export SPINORBEC_CELL_TIMING="${SPINORBEC_CELL_TIMING:-$SPINORBEC_GAP_CACHE/cell_timing.log}"
mkdir -p "$SPINORBEC_GAP_CACHE"

CUDA_NOISE='loaded from a system path|This may cause errors|If you.re running under a profiler|ensure that your library path|In any other case, please file an issue|^│ *$|^└ @ CUDA|^┌ Warning: CUDA runtime library'
