# Shared preamble for the κ-dependent hysteresis-loop campaign (#335).
#
# Sourced, not copied — the campaign submits ~8 jobs and the environment they
# need is identical. Eight scripts each carrying their own `cd` line is how two
# gates once ran in a tree holding another session's `src/`.
#
# Usage, after the UGE directives:
#     source "$(dirname "$0")/_preamble.sh"
#
# NOTE: do NOT `source scripts/tsubame_setup.sh` from here. It runs `set +e` (to
# survive `module` failures) and never restores it, so every submit script that
# sources it loses `set -e` for the rest of the job: a middle stage can fail and
# the job still exits 0 through its final `echo`. That covered two failures with
# GREENs on 2026-08-08. Verified still present in this tree
# (`scripts/tsubame_setup.sh:21`, no matching `set -e`). This preamble does the
# same work inline and leaves the caller's `set -euo pipefail` intact.

set -euo pipefail

EU335_ROOT="${EU335_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu335}"
EU335_OUT="${EU335_OUT:-/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu335}"

# There is no julia modulefile on TSUBAME 4 — `module load julia` always fails.
# Point at the binary.
export SPINORBEC_TSUBAME_JULIA="${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}"
JULIA="$SPINORBEC_TSUBAME_JULIA"
# Depot as a LIST: node-local scratch first so precompile output never lands in
# the group quota, shared depot second so packages resolve from the precompiled
# copy. `JULIAUP_DEPOT_PATH` is a login-env-only variable that julialauncher
# needs; without it the launcher cannot find the channel.
export JULIA_DEPOT_PATH="${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/shared/.julia"
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
export JULIA_NUM_THREADS="${JULIA_NUM_THREADS:-8}"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true

cd "$EU335_ROOT"
mkdir -p "$EU335_OUT" logs/tsubame

echo "host=$(hostname) date=$(date) pwd=$(pwd)"
echo "commit=$(git rev-parse --short HEAD) dirty=$(git status --porcelain | wc -l)"
echo "out=$EU335_OUT"

# A result nobody can attribute is not a result. HEAD alone does not establish
# what ran: an aborted checkout leaves HEAD at the intended commit with other
# files in the tree, and a shared tree can be edited under a running job.
if [ -n "$(git status --porcelain -- src scripts)" ]; then
    echo "REFUSING: src/ or scripts/ is dirty in $(pwd) — this run would not be attributable"
    git status --porcelain -- src scripts
    exit 1
fi

# A GPU job that silently falls back to CPU produces numbers 50× later and looks
# like a slow queue rather than a broken environment.
"$JULIA" --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional — would silently run on CPU"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
