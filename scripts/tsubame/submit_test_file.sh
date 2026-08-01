#!/bin/bash
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=0:30:00
#$ -N testfile
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs-mutation/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs-mutation/
#
# Run ONE test file on a compute node. For iterating on a single gate without
# paying for a tier, and for the canary step ("run it against the known-bad
# source, require RED") where a tier tells you nothing.
#
#   qsub -g tga-kozuma-kouhi \
#        -v TF_FILE=test/hamiltonian/test_x.jl,TF_TAG=x \
#        scripts/tsubame/submit_test_file.sh
#
# Its own checkout, pinned by SHA, under /gs/fs — same discipline as
# submit_mutation.sh, and for the same reason.
set -u

TF_FILE=${TF_FILE:?set TF_FILE}
ROOT=${TF_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-tf-${TF_TAG:-run}}
REF=${TF_REF:-test/layered-gates-and-mutation-harness}
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

export JULIA_DEPOT_PATH=${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
export SPINORBEC_FFT_ESTIMATE=1
export OPENBLAS_NUM_THREADS=1

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
echo "file=$TF_FILE"

$JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -2
$JULIA --project=. --startup-file=no -e "using SpinorBEC; include(\"$TF_FILE\")" 2>&1
echo "TF_RC=$?"
echo "ALL DONE $(date)"
