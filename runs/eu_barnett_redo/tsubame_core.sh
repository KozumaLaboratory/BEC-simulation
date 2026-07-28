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

# `#$ -cwd` already puts the job in the submission directory, which is the
# checkout the script was submitted from. Do NOT hard-code the main checkout:
# it is a shared working copy that other sessions keep on other branches with
# modified src/, and running against a stale tree is how a whole TSUBAME sweep
# silently produced NaNs on 2026-07-27. Override with BR_REPO if needed.
REPO="${BR_REPO:-$PWD}"
cd "$REPO"
echo "REPO=$REPO  branch=$(git branch --show-current 2>/dev/null)  HEAD=$(git rev-parse --short HEAD 2>/dev/null)"

# The shared depot lives on the group volume. When that volume is full, Julia
# cannot write precompile output and dies with an LLVM "IO failure on output
# stream: Disk quota exceeded" -- so the depot has to be overridable too, not
# just the results. `JULIA_DEPOT_PATH=$HOME/.julia` runs entirely off the
# separate 25 GB home quota.
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
export JULIAUP_DEPOT_PATH="${JULIAUP_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup}"
export BR_CELL="${BR_CELL:-plus}"

# Optional named geometry. `qsub -v` splits values on commas, so BR_N / BR_BOX
# tuples CANNOT be passed through -v -- they silently expand into several bogus
# variables and the job runs the default geometry. Use BR_VARIANT=<name> from
# variants.sh instead.
if [ -n "${BR_VARIANT:-}" ]; then
  source runs/eu_barnett_redo/variants.sh
  br_select_prod "$BR_VARIANT"
  echo "variant=$BR_VARIANT n=$BR_N box=$BR_BOX dt=$BR_DT"
fi

source scripts/tsubame_setup.sh    # node-local NVMe SPINORBEC_SCRATCH_DIR — KEEP IT.

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== node $(hostname) $(date) cell=$BR_CELL SCRATCH=$SPINORBEC_SCRATCH_DIR ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_redo/run_core.jl
echo "=== done $(date) ==="
