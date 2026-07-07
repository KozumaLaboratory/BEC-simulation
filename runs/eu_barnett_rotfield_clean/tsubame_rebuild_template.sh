#!/bin/bash
# Reusable TSUBAME (UGE) submit template for the two-stage rebuild jobs.
# Bakes in EVERY environment fix learned the hard way 2026-07-08 — do not
# hand-write these again:
#
#   1. julia is NOT on compute-node PATH (shared juliaup, login-only) -> explicit
#      $JULIA path.
#   2. julialauncher needs JULIAUP_DEPOT_PATH (login env only) -> export it.
#   3. node-local JULIA_DEPOT_PATH is EMPTY each job -> use the shared depot that
#      already has the deps precompiled.
#   4. **node-local NVMe SPINORBEC_SCRATCH_DIR OVERFLOWS for >=100^3 snapshots**
#      (112^3 f32 = 91 MB/frame) -> the tmp->output rename crosses devices (NVMe
#      -> Lustre) and dies EXDEV / sendfile -122. Point the snapshot scratch at
#      LUSTRE (same device as runs/ output) so the rename is in-place. 80^3
#      squeaked through NVMe; 100^3+ does NOT. See gotcha
#      tsubame_nvme_scratch_overflow_exdev.
#
# Usage (edit the qsub -N/-o + RB_* below, or override via `qsub -v`):
#   qsub -g tga-kozuma-kouhi runs/eu_barnett_rotfield_clean/tsubame_rebuild_template.sh
#
#$ -cwd
#$ -N eu_barnett_rebuild
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -j y
#$ -o logs/tsubame/rebuild.log
set -euo pipefail

REPO=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
cd "$REPO"

# --- juliaup + package depot (shared, has deps precompiled) ---
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup

# --- run parameters (override with `qsub -v RB_BOX=...,RB_N=...`) ---
export RB_BOX="${RB_BOX:-20.0, 20.0, 10.0}"
export RB_N="${RB_N:-80, 80, 40}"
export RB_DT="${RB_DT:-0.0004}"

source scripts/tsubame_setup.sh    # sets threads + (node-local) SPINORBEC_SCRATCH_DIR

# --- CRITICAL: override node-local NVMe scratch -> Lustre (same device as runs/)
# so large-snapshot tmp->output renames stay in-place (no EXDEV). Per-JOB_ID dir
# so concurrent jobs don't clobber each other's intermediate yamls/snapshots. ---
export SPINORBEC_SCRATCH_DIR="$REPO/runs/rb_scratch_${JOB_ID:-manual}"
export SPINORBEC_SCRATCH="$SPINORBEC_SCRATCH_DIR"
mkdir -p "$SPINORBEC_SCRATCH_DIR"

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== node $(hostname) $(date) box=$RB_BOX n=$RB_N dt=$RB_DT SCRATCH=$SPINORBEC_SCRATCH_DIR ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_rebuild.jl
echo "=== done $(date) ==="
