# Shared preamble for the #334 in-place-nucleation campaign.
#
# Sourced, not copied — the campaign submits one job per (T, rate, seed) cell and
# the environment they need is identical. A `cd` line per script is how two gates
# once ran in a tree holding another session's `src/`.
#
# Usage, after the UGE directives:
#     source "${EU334_ROOT:-…}/scripts/eu334/_preamble.sh"
#
# NOTE: do NOT `source scripts/tsubame_setup.sh` from here. It runs `set +e` (to
# survive `module` failures) and never restores it, so every submit script that
# sources it loses `set -e` for the rest of the job: a middle stage can fail and
# the job still exits 0 through its final `echo`. That covered two failures with
# GREENs on 2026-08-08.

set -euo pipefail

EU334_ROOT="${EU334_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu334}"
EU334_OUT="${EU334_OUT:-/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu334}"
# #335's converged branch seeds — the anchors and the reference energies this
# campaign is measured against. Shared rather than copied: a second copy is a
# second epoch waiting to drift.
EU334_SEEDS="${EU334_SEEDS:-/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu335/seeds}"

# There is no julia modulefile on TSUBAME 4 — `module load julia` always fails.
export SPINORBEC_TSUBAME_JULIA="${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}"
JULIA="$SPINORBEC_TSUBAME_JULIA"
# Depot as a LIST: node-local scratch first so precompile output never lands in
# the group quota, shared depot second so packages resolve from the precompiled
# copy. `JULIAUP_DEPOT_PATH` is a login-env-only variable julialauncher needs.
export JULIA_DEPOT_PATH="${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/shared/.julia"
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
export JULIA_NUM_THREADS="${JULIA_NUM_THREADS:-8}"
module load cuda/12.6 2>/dev/null || module load cuda 2>/dev/null || true

cd "$EU334_ROOT"
mkdir -p "$EU334_OUT" logs/tsubame

echo "host=$(hostname) date=$(date) pwd=$(pwd)"
echo "commit=$(git rev-parse --short HEAD) dirty=$(git status --porcelain | wc -l)"
echo "out=$EU334_OUT  seeds=$EU334_SEEDS"

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
#
# `EU334_NO_GPU=1` is for the jobs that genuinely never touch a CUDA path — the
# unit-scale probes, which do not `import CUDA` and pass no backend, so there is
# no fallback to be silent about. It must be set by the SUBMIT SCRIPT beside its
# `-l cpu_16=1`, so the declaration and the reservation are one edit apart and
# cannot drift: a job asking for a GPU and skipping this check is the exact
# failure the assertion exists for.
#
# Default is still to assert. Opting out has to be deliberate and visible.
if [ "${EU334_NO_GPU:-0}" = "1" ]; then
    echo "[preamble] EU334_NO_GPU=1 — CPU-only job, skipping the CUDA assertion"
else
    "$JULIA" --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional — would silently run on CPU"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
fi
