#!/bin/bash
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=2:00:00
#$ -N test_tier
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs-test/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs-test/
#
# A test tier on a compute node, with its own checkout pinned by SHA.
#
#   qsub -g tga-kozuma-kouhi \
#        -v TT_TIER=ci,TT_TAG=ci,TT_WORKERS=8 \
#        scripts/tsubame/submit_test_tier.sh
#
# Generalises submit_test_tier_ci.sh, which is fixed to `ci` and to one bench
# root. Two things are designed in:
#
#   - logs land under /gs/fs, per the standing instruction that new runs write
#     to the group volume and not to $HOME or work;
#   - the tier's return code becomes the JOB's return code. The older script
#     ends with an `echo`, so `qacct` reports exit_status 0 for a red suite —
#     which is not a hypothetical: exit_status 0 was the only signal available
#     for job 8309102 until its log was found.
set -u

TIER=${TT_TIER:-ci}
ROOT=${TT_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-tt-${TT_TAG:-$TIER}}
REF=${TT_REF:-test/layered-gates-and-mutation-harness}
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

export JULIA_DEPOT_PATH=${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
export SPINORBEC_TEST_TIER=$TIER
export SPINORBEC_TEST_WORKERS=${TT_WORKERS:-8}
export SPINORBEC_FFT_ESTIMATE=1
export OPENBLAS_NUM_THREADS=1

mkdir -p /gs/fs/tga-kozuma-kouhi/uk07267/logs-test
if [ ! -d "$ROOT/.git" ]; then
    git clone -q /gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation "$ROOT" ||
        git clone -q https://github.com/KozumaLaboratory/BEC-simulation.git "$ROOT"
fi
cd "$ROOT"
git remote set-url origin https://github.com/KozumaLaboratory/BEC-simulation.git
git fetch -q origin "$REF" || { echo "FETCH FAILED — refusing to run a stale tree"; exit 1; }
git checkout -q -f FETCH_HEAD

echo "host=$(hostname) date=$(date)"
echo "commit=$(git rev-parse HEAD)"
echo "tier=$TIER workers=$SPINORBEC_TEST_WORKERS"

$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -2
$JULIA --project=. -e 'using Pkg; Pkg.test()' 2>&1
RC=${PIPESTATUS[0]}
echo "TEST_RC=$RC"
echo "ALL DONE $(date)"
exit "$RC"
