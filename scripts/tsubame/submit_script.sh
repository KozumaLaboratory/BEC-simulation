#!/bin/bash
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=0:30:00
#$ -N script
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs-mutation/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs-mutation/
#
# Run one Julia script with arguments on a compute node, in its own checkout
# pinned by SHA. For the tools that are scripts rather than test files —
# `test/_inventory.jl`, the audit drivers under `scripts/`.
#
#   qsub -g tga-kozuma-kouhi \
#        -v SC_FILE=test/_inventory.jl,SC_ARGS=--files,SC_TAG=inv \
#        scripts/tsubame/submit_script.sh
#
# `SC_ARGS` uses `+` between arguments, since UGE's `-v` splits on commas.
set -u

SC_FILE=${SC_FILE:?set SC_FILE}
ROOT=${SC_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-sc-${SC_TAG:-run}}
REF=${SC_REF:-main}
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
echo "file=$SC_FILE args=${SC_ARGS:-<none>}"

IFS='+' read -r -a ARGV <<< "${SC_ARGS:-}"
$JULIA --project=. --startup-file=no "$SC_FILE" "${ARGV[@]}" 2>&1
echo "SC_RC=$?"
echo "ALL DONE $(date)"
