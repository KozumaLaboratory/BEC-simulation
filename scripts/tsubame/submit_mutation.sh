#!/bin/bash
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=2:00:00
#$ -N mutation
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs-mutation/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs-mutation/
#
# Mutation harness on a compute node. The harness PATCHES REAL FILES under
# src/ while it runs, so it needs a tree nobody else is reading — that is why
# this uses its own checkout (`bec-mutation`) and not the shared one.
#
#   qsub -g tga-kozuma-kouhi \
#        -v MUT_PROBE=<spec+spec>,MUT_MUTANTS=<id:id:…>,MUT_TAG=<name> \
#        scripts/tsubame/submit_mutation.sh
#
# Everything it writes lands under /gs/fs (group volume), never $HOME.
set -u

MUT_PROBE=${MUT_PROBE:?set MUT_PROBE}
MUT_MUTANTS=${MUT_MUTANTS:-}
# ONE CHECKOUT PER JOB, keyed by tag. The harness patches real files under
# src/, so two jobs sharing a tree read each other's defects. Two jobs were
# submitted against one tree on 2026-07-31 and the second had to be qdel'd
# seconds after it started — making the root tag-specific removes the footgun
# instead of relying on remembering it.
ROOT=${MUT_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-mut-${MUT_TAG:-run}}
MUT_REF=${MUT_REF:-test/layered-gates-and-mutation-harness}
OUT=${MUT_OUT:-/gs/fs/tga-kozuma-kouhi/uk07267/mutation-out}/${MUT_TAG:-run}
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

# The shared depot, exported BEFORE anything Julia runs: a fresh tree with a
# node-local empty depot precompiles the whole dependency graph from scratch.
export JULIA_DEPOT_PATH=${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
# Plan selection by timing makes round-off quantities differ run to run, which
# reads as a flaky test rather than as a plan change.
export SPINORBEC_FFT_ESTIMATE=1
# A few-MB level-1 call on a 16-core node is spawn + barrier, not arithmetic.
export OPENBLAS_NUM_THREADS=1

# UGE's `-v` separates variables with commas, and both the probe spec and the
# mutant list are themselves comma-separated, so each has a wire format that
# avoids the comma. They are NOT the same character: `dir:` is part of the probe
# grammar, and translating colons there turned `dir:workflow` into
# `dir,workflow` — a spec matching no branch (2026-07-31).
MUT_PROBE=${MUT_PROBE//+/,}
MUT_MUTANTS=${MUT_MUTANTS//:/,}

mkdir -p "$OUT"

# Materialise this job's own checkout, and pin it to the ref by SHA. A failed
# fetch that leaves the previous commit in place is a known TSUBAME failure
# mode, so the SHA is printed and compared, not assumed.
if [ ! -d "$ROOT/.git" ]; then
    git clone -q /gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation "$ROOT" ||
        git clone -q https://github.com/KozumaLaboratory/BEC-simulation.git "$ROOT"
fi
cd "$ROOT"
git remote set-url origin https://github.com/KozumaLaboratory/BEC-simulation.git
git fetch -q origin "$MUT_REF" || { echo "FETCH FAILED — refusing to run a stale tree"; exit 1; }
git checkout -q -f FETCH_HEAD

echo "host=$(hostname) date=$(date)"
echo "commit=$(git rev-parse HEAD)"
echo "dirty=$(git status --porcelain | wc -l)   # must be 0 at start"
echo "probe=$MUT_PROBE"
echo "mutants=${MUT_MUTANTS:-<all>}"
echo "out=$OUT"

$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -3

ARGS=(--probe "$MUT_PROBE" --workers "${MUT_WORKERS:-8}"
      --max-cost "${MUT_MAX_COST:-300}" --out "$OUT")
[ -n "${MUT_MUTANTS:-}" ] && ARGS+=(--mutants "$MUT_MUTANTS")

$JULIA --project=. --startup-file=no test/mutation/run.jl "${ARGS[@]}" 2>&1
echo "MUT_RC=$?"

# The harness restores src itself and says so; this is the independent check.
# A dirty tree here means a worker died mid-mutation and the next job would
# read the DEFECT as if it were the code.
echo "dirty_after=$(git status --porcelain -- src | wc -l)   # must be 0"
git status --porcelain -- src
echo "ALL DONE $(date)"
