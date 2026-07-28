#!/bin/bash
# TSUBAME (UGE) submit for one decisive-core cell. See README.md.
#
# Environment fixes carried over from 2026-07-08 — do not re-derive:
#   1. julia is NOT on the compute-node PATH (shared juliaup is login-only)
#      -> explicit $JULIA path.
#   2. julialauncher needs JULIAUP_DEPOT_PATH (login env only) -> export it.
#   3. node-local JULIA_DEPOT_PATH is EMPTY each job -> use the shared depot,
#      which already has the deps precompiled.
#   4. keep scratch on node-local NVMe (JLD2 mmap SIGBUSes on Lustre).
#
# Unlike the previous round this driver does NOT stream full psi snapshots: the
# J_z ledger is accumulated in-process and written as a CSV, and only 8 frames
# per cell are kept for the vortex figure (~300 MB/cell instead of ~25 GB).
# That matters — the group volume was at 98% (21 GB free) on 2026-07-28.
#
# Usage:
#   qsub -g tga-kozuma-kouhi -v BR_CELL=plus      runs/eu_barnett_redo/tsubame_core.sh
#   qsub -g tga-kozuma-kouhi -v BR_CELL=minus     runs/eu_barnett_redo/tsubame_core.sh
#   qsub -g tga-kozuma-kouhi -v BR_CELL=zero      runs/eu_barnett_redo/tsubame_core.sh
#   qsub -g tga-kozuma-kouhi -v BR_CELL=plus_nodd runs/eu_barnett_redo/tsubame_core.sh
#
#$ -cwd
#$ -N eu_barnett_redo
#$ -l gpu_1=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o logs/tsubame/barnett_redo.log
set -euo pipefail

REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
export BR_CELL="${BR_CELL:-plus}"

source scripts/tsubame_setup.sh    # node-local NVMe SPINORBEC_SCRATCH_DIR — KEEP IT.

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== node $(hostname) $(date) cell=$BR_CELL SCRATCH=$SPINORBEC_SCRATCH_DIR ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_redo/run_core.jl
echo "=== done $(date) ==="
