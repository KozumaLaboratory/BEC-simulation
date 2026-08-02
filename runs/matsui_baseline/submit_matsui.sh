#!/bin/bash
# ============================================================
#  UGE — Matsui 2026 Eu-151 EdH reproduction, re-run against current code.
#
#  Why this exists at all: docs/validation/matsui_reproduction_status.md froze on
#  2026-05-26 and NOTHING here has been run since. Everything under runs/ predates
#  the corrections listed in docs/validation/stored_results_vintage_audit.md, of
#  which the disqualifying one for this suite is the 2026-07-08 quadratic-Zeeman
#  geometry fix (q was 11x too large, and q sets the m-level structure). On top of
#  that these configs carried a NEGATIVE B_z under `initial_state: m_minus_F`,
#  which under current code selects m=+F -- fixed in the same branch as this file.
#
#  This is a type-C check (model fidelity vs published data), and it is the
#  strongest one available: the paper publishes its own 13-component GPE
#  numerics, so agreement is checkable term by term rather than by eye.
#
#  Two targets, run as one array:
#    1  5ms  morphology, n=64   (paper Fig 1 ring morphology)
#    2  40ms dynamics,   n=64   (paper Fig 2C N_m(t) populations)
#  Both LOSS-FREE, matching the paper's simulation. The loss-on variants
#  (matsui_40ms_lossy_*.yaml) are the separate "experiment target" and are not
#  run here -- claims of "experiment reproduction" need those, claims of
#  "simulation reproduction" need these. Do not conflate them.
#
#    qsub -g tga-kozuma-kouhi -N matsui runs/matsui_baseline/submit_matsui.sh
#
#  Smoke first with the n=32 5ms config, which renders every path at 1/8 the
#  voxels:
#    qsub -g tga-kozuma-kouhi -N matsui_smk -t 1-1 -l h_rt=1:00:00 \
#         runs/matsui_baseline/submit_matsui.sh SMOKE
# ============================================================
#$ -cwd
#$ -N matsui_edh
#$ -l gpu_1=1
#$ -l h_rt=12:00:00
#$ -t 1-2
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail                       # re-arm: tsubame_setup runs `set +e`
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH}:/gs/fs/tga-kozuma-kouhi/shared/.julia:${HOME}/.julia"

# Output on /gs/bs/work: 100 GiB per user, persistent (no documented purge --
# what IS deleted at job end is the node-local scratch, a different thing). The
# group's /gs/fs is 1 TB and was full on 2026-07-29, which killed a whole array
# job with EDQUOT and mmap SIGBUS rather than anything that says "disk full".
export SPINORBEC_STORE="${SPINORBEC_STORE:-/gs/bs/work/7/uk07267/runs}"
mkdir -p "$SPINORBEC_STORE"

if [ "${1:-}" = "SMOKE" ]; then
    CONFIG=runs/matsui_baseline/matsui_5ms_morphology_n32.yaml
else
    case "${SGE_TASK_ID:-1}" in
        1) CONFIG=runs/matsui_baseline/matsui_5ms_morphology_n64.yaml ;;
        2) CONFIG=runs/matsui_baseline/matsui_40ms_dynamics_n64.yaml ;;
        *) echo "no config for task ${SGE_TASK_ID}"; exit 1 ;;
    esac
fi

echo "[task ${SGE_TASK_ID:-smoke}] $(hostname) cfg=$CONFIG"
echo "[src]   $(git rev-parse HEAD)  $(git status --porcelain -- src | wc -l) dirty src files"
echo "[store] $SPINORBEC_STORE"
# The sign this suite got wrong. Print it so the log carries the value, not a claim.
grep -m1 "Bz" "$CONFIG" || true
nvidia-smi -L || true

# Guard silent CPU fallback (a broken-CUDA node otherwise burns hours on CPU).
"$JULIA" --project=. -e '
    import CUDA
    CUDA.functional() || (@error "CUDA not functional — refusing CPU fallback"; exit(1))
    using SpinorBEC
    run_yaml(ARGS[1])' "$CONFIG"

echo "[task ${SGE_TASK_ID:-smoke}] done"
