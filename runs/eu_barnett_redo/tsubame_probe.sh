#!/bin/bash
# One geometry-probe cell on TSUBAME. Same driver as production; the variant is
# passed in through the environment (see probe_leak.sh for the variant table).
#
#   qsub -g tga-kozuma-kouhi -N br_base \
#        -v BR_TAG=_probe_base,BR_N=64\,64\,28,BR_BOX=28\,28\,12,BR_PAD=0,BR_DT=1.0e-3 \
#        runs/eu_barnett_redo/tsubame_probe.sh
#
# h_rt is 1 h, not the production 6 h: probes schedule in minutes at that size,
# and the ledger is flushed on every observation, so a walltime kill still
# leaves a usable CSV.
#
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=1:00:00
#$ -j y
#$ -o logs/tsubame/$JOB_NAME.$JOB_ID.log
set -euo pipefail

REPO="${BR_REPO:-$PWD}"
cd "$REPO"
echo "REPO=$REPO  branch=$(git branch --show-current 2>/dev/null)  HEAD=$(git rev-parse --short HEAD 2>/dev/null)"

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
export BR_CELL="${BR_CELL:-plus}"
export BR_FRAMES="${BR_FRAMES:-0}"
export BR_T_STIR="${BR_T_STIR:-10.0}"
export BR_T_QUENCH="${BR_T_QUENCH:-20.0}"

source scripts/tsubame_setup.sh    # node-local NVMe SPINORBEC_SCRATCH_DIR — KEEP IT.

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== node $(hostname) $(date) tag=${BR_TAG:-none} n=${BR_N:-default} box=${BR_BOX:-default} pad=${BR_PAD:-0} dt=${BR_DT:-default} ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_redo/run_core.jl
echo "=== done $(date) ==="
