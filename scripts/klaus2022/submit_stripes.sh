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
#
# THE RESOURCE CLASS IS NOT OVERRIDABLE FROM THE COMMAND LINE. Adding
# `-l cpu_4=1` to the qsub alongside the `#$ -l cpu_16=1` below is REJECTED
# outright — "Job is rejected because of multiple specifying of gpu_? and cpu_?
# parameters at one time" — so trying a smaller class to get scheduled sooner
# means editing this line, not passing a flag. `h_rt` overrides fine, which is
# what makes the smoke usable.
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

# `KLAUS_SMOKE=1` renders every code path on the SMALL grid, for the
# "smoke-test before any >10 min launch" rule. It is a real flag rather than
# something a caller can approximate: passing an env var the script does not
# read is silent, and the first submission of this job did exactly that —
# `-v KLAUS_SMOKE_ARGS=1` was ignored, so a 30-minute walltime would have been
# spent on a 1.1 s production run and killed with nothing to show.
EXTRA=""
if [ "${KLAUS_SMOKE:-0}" = "1" ]; then
    EXTRA="--smoke"
    echo "SMOKE: small grid, short hold — not a production result"
fi

echo "seed=$KLAUS_SEED hold_s=$KLAUS_HOLD_S tag=$KLAUS_TAG smoke=${KLAUS_SMOKE:-0}"
echo "results=$KLAUS_RESULTS"

# `-t` matches the requested cores; FFTW threads follow it inside the script
# unless `KLAUS_FFTW_THREADS` overrides. The dynamics is FFT-bound, so this is
# the knob that matters.
#
# FFTW THREADS DEFAULT TO THE CORE COUNT, measured ON THE GRID THAT RUNS.
#
# 128^3 (production), hold 0.05 s, one variable:
#
#   FFTW threads   wall     ru_maxrss    job
#        1        1803 s     1.06 GB     8445674
#        4         825 s     1.28 GB     8445675
#       16         575 s     1.15 GB     8445676   <- 3.13x faster than 1
#
# 48^3 (--smoke), where this was FIRST measured and where the answer INVERTS:
#
#   julia -t   FFTW threads   ru_maxrss   outcome
#      16          16          36.9 GB    SIGKILL at 55 s   (8445105)
#      16           1           1.08 GB   exit 0, 343 s     (8445106)
#       1           1           1.27 GB   exit 0, 341 s     (8445107)
#
# So the small grid says "1 or die" and the production grid says "16, and it is
# also the LIGHTEST". Both are measured; neither generalises to the other. A
# default of 1 was set from the 48^3 table alone with a comment saying the
# production grid should be measured — and then the production seeds were
# launched without measuring it, at 3.13x the cost, into a 2 h h_rt they could
# not have met (jobs 8445116/7/8, all `execd enforced h_rt limit` at 7195 s).
# Writing the caveat is not measuring it.
#
# STILL NOT EXPLAINED: why 16 threads costs 36.9 GB at 48^3 and 1.15 GB at
# 128^3 — a 19x LARGER problem using 32x LESS memory at the same thread count.
# "Small grid x many threads is pathological" is as far as the measurements go.
# The same `-t 16` with FFTW at 16 also peaks at 1.12 GB locally on a 10-core
# box, so the visible-CPU count (384 on the node) is a candidate; untested.
#
# The first failure was a SIGSEGV inside FFTW's threaded spawn loop (8444494)
# and the stack trace pointed at FFTW as a bug. TWO FAILURE MODES FROM ONE
# CONFIGURATION — SIGSEGV at 3m14s, then SIGKILL at 55 s — is what said
# "resource", not "bug".
JT="${KLAUS_JULIA_THREADS:-16}"
export KLAUS_FFTW_THREADS="${KLAUS_FFTW_THREADS:-$JT}"
echo "julia_threads=$JT fftw_threads=$KLAUS_FFTW_THREADS"
time "$JULIA" --project=. -t "$JT" scripts/klaus2022_reproduce.jl stripes $EXTRA
rc=$?
echo "EXIT_RC=$rc"
exit $rc
