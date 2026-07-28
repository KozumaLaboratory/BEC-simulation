#!/bin/bash
# ============================================================
#  UGE array — Eu F=6 texture B-scan, LHY-ON twin (full_bdg).
#
#  The A/B against config_texture_bscan.yaml (`lhy: {kind: none}`): same cells,
#  same five seeds, `lhy.kind` the only difference. Its job is to decide whether
#  "PCV wins at 50 µG, uniform axial from 60 µG" survives beyond mean field —
#  the F=6 phases these seeds separate are mean-field DEGENERATE, so the
#  mean-field assignment is provisional by construction.
#
#  8 cells = 4 B slices x 2 c1 values. Each array task is ONE cell and runs all
#  five seeds (flower / csv / pcv / fm / polar) inside it, so the min-energy
#  comparison that decides the phase happens within a task and never straddles
#  a node.
#
#    qsub -g tga-kozuma-kouhi -N eu_tex_lhy \
#         runs/eu_gs_phase_c1_B_kappa/submit_texture_bscan_lhy.sh \
#         runs/eu_gs_phase_c1_B_kappa/config_texture_bscan_lhy_full_bdg.yaml
#
#  Smoke first (config_texture_bscan_lhy_smoke.yaml) — it renders every path
#  this job takes, including the full_bdg table build on the GPU.
# ============================================================
#$ -cwd
#$ -N eu_texture_bscan_lhy
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -t 1-8
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
CONFIG="${1:?usage: submit_texture_bscan_lhy.sh <config.yaml>}"
[ -f "$CONFIG" ] || CONFIG="$PROJECT_ROOT/$CONFIG"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail                       # re-arm: tsubame_setup runs `set +e`

export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH}:/gs/fs/tga-kozuma-kouhi/shared/.julia:${HOME}/.julia"

export SPINORBEC_SCAN_ONLY_INDEX=$SGE_TASK_ID
export SPINORBEC_STAGE_CACHE=1
export SPINORBEC_LIGHT_POINTS=1

echo "[task $SGE_TASK_ID/$SGE_TASK_LAST] $(hostname) cfg=$CONFIG"
echo "[src] $(git rev-parse HEAD) $(git status --porcelain -- src | wc -l) dirty src files"
nvidia-smi -L || true

# Guard silent CPU fallback (a broken-CUDA node otherwise burns hours on CPU).
"$JULIA" --project=. -e '
    import CUDA
    CUDA.functional() || (@error "CUDA not functional — refusing CPU fallback"; exit(1))
    using SpinorBEC
    run_yaml(ARGS[1])' "$CONFIG"

echo "[task $SGE_TASK_ID] done"
