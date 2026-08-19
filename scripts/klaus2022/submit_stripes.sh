#!/bin/bash
# TSUBAME (UGE) submit: one seed of the Klaus 2022 vortex-stripe ensemble.
#
#   qsub -g tga-kozuma-kouhi -N klaus_s1 \
#     -v KLAUS_SEED=1,KLAUS_HOLD_S=1.1,KLAUS_TAG=_s1 \
#     scripts/klaus2022/submit_stripes.sh
#
# WHY THIS EXISTS. The committed stripes arm ran 500 ms as ONE realization and
# reached 4.67x its isotropic null against a pre-registered 5x
# (`docs/validation/klaus2022_primary_source.md` §6d). That is not a
# disagreement with the paper — it is us under-running the paper's own analysis:
# their Fig. 4c stripe signal is 115 frames between 700 ms and 1.1 s, averaged.
# So the re-measurement is longer runs, several seeds, and the window they used.
#
# AND WHY ON TSUBAME. The first three arms were run on the local WSL2 box — 4.7
# hours of it — against a standing norm that every Julia run of this size goes
# to the cluster (`feedback_use_tsubame_for_heavy_compute`, already corrected
# four times). The scalar eGPE path is CPU-only (`Array`, no CUDA extension), so
# "no GPU path" was never a reason not to submit: TSUBAME has CPU nodes.
#
# ONE SEED PER JOB. The seeds are independent realizations, so a kill costs one
# of them rather than the ensemble, and each writes its OWN results file —
# concurrent jobs sharing one JSON is a read-modify-write race that would
# silently keep whichever finished last.
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=8:00:00
#$ -j y
#$ -o logs/tsubame/

set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
JULIA="${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}"

cd "${KLAUS_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/klaus2022}" || exit 1
mkdir -p logs/tsubame runs/klaus2022 out

echo "host=$(hostname) date=$(date) pwd=$(pwd)"
echo "commit=$(git rev-parse --short HEAD) dirty=$(git status --porcelain -- src test | wc -l)"

# The hash alone is not evidence about what ran: a shared tree can be edited
# under a running job, and an aborted checkout leaves HEAD at the intended
# commit while the tree holds other files. Refuse rather than produce a result
# nobody can attribute — on `src/` and `test/` specifically, since that is what
# the package is built from. Same guard as scripts/tsubame/_preamble.sh; this
# tree is its own worktree so it does not source that file's `cd`.
if [ "$(git status --porcelain -- src test | wc -l)" -ne 0 ]; then
    echo "REFUSING: src/ or test/ is dirty in $(pwd) — result would not be attributable"
    git status --porcelain -- src test | head -20
    exit 2
fi

export KLAUS_SEED="${KLAUS_SEED:-1}"
export KLAUS_HOLD_S="${KLAUS_HOLD_S:-1.1}"
export KLAUS_TAG="${KLAUS_TAG:-_s${KLAUS_SEED}}"
# Per-job output. NOT the committed record: that one belongs to the runs that
# produced it, and an ensemble member overwriting it would make the gate read a
# different experiment than the one its thresholds were registered for.
export KLAUS_RESULTS="${KLAUS_RESULTS:-$(pwd)/out/klaus2022_ensemble${KLAUS_TAG}.json}"

echo "seed=$KLAUS_SEED hold_s=$KLAUS_HOLD_S tag=$KLAUS_TAG"
echo "results=$KLAUS_RESULTS"

# `-t` matches the requested cores; FFTW threads are set from it inside the
# script. The dynamics is FFT-bound, so this is the knob that matters.
time "$JULIA" --project=. -t 16 scripts/klaus2022_reproduce.jl stripes
rc=$?
echo "EXIT_RC=$rc"
exit $rc
