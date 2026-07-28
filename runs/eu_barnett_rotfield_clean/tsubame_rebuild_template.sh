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
#   4. **Snapshot scratch MUST stay node-local NVMe (mmap-OK); DON'T move to
#      Lustre.** For n>=100 the NVMe .tmp overflows -> EXDEV on the tmp->Lustre
#      move; but Lustre scratch SIGBUSes (JLD2 mmap). CORRECT fix = keep NVMe and
#      SHRINK the snapshot volume via RB_SAVE_EVERY so the jld2 fits (n112 -> ~2000;
#      n80 fine at default 300, box±20-proven). Reap runs/rb_* + watch group quota
#      (~1TB). See gotcha tsubame_nvme_scratch_overflow_exdev.
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

# --- run parameters. RB_SAVE_EVERY: raise for big grids so the jld2 fits NVMe
# (n112 -> 2000; n80 fine at 300). Commas break `qsub -v` — set inside a copy. ---
export RB_BOX="${RB_BOX:-20.0, 20.0, 10.0}"
export RB_N="${RB_N:-80, 80, 40}"
export RB_DT="${RB_DT:-0.0004}"
export RB_SAVE_EVERY="${RB_SAVE_EVERY:-300}"

source scripts/tsubame_setup.sh    # node-local NVMe SPINORBEC_SCRATCH_DIR (mmap-OK) — KEEP IT.
# Do NOT move the scratch to Lustre (JLD2 mmap SIGBUSes). Fit the jld2 via RB_SAVE_EVERY.

JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== node $(hostname) $(date) box=$RB_BOX n=$RB_N dt=$RB_DT save=$RB_SAVE_EVERY SCRATCH=$SPINORBEC_SCRATCH_DIR ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional() "CUDA not functional"; println("CUDA OK: ", CUDA.name(CUDA.device()))'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_rebuild.jl
echo "=== done $(date) ==="
