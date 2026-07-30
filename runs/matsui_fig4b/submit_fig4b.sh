#!/bin/bash
# ============================================================
#  UGE — Matsui et al. (2025) Fig. 4B reproduction (session S-A6).
#
#  What is being measured: the m = -6 population dips as the held field is
#  scanned, and the dip minimum sits at a NEGATIVE field. The offset is the
#  gas's own dipole field shifting the EdH resonance, so its position and width
#  are a single-number test of the MDDI implementation. Targets, measured off
#  their published dataset by `resonance_dip` and pinned in
#  test/validation/test_matsui_fig4_dip.jl:
#
#      their simulation   centre -2.5495 nT   half-depth width 15.0224 nT
#      their experiment   centre -3.2048 nT   half-depth width 14.5414 nT
#
#  Four tasks, all loss-free (their L3loss = 0):
#    1  fig4b_scan_n32       81 fields, -20 … +20 nT, the curve
#    2  fig4b_conv_n64        8 fields, resolution error bar on task 1's centre
#    3  fig4b_gsvariant_n32  19 fields, their literal (inconsistent) ground state
#    4  fig2c_populations_n32  one field, 40 ms, N_m(t) against their Fig. 2C sheet
#
#  Run 2 and 3 are not optional extras. At 32³ the occupied band edge
#  sqrt(2·mu) ≈ 5.1 sits at 0.81·k_max, so task 1 alone cannot say whether its
#  centre is physics or resolution; and initial.f90 ships cc0_eff = 1 against
#  time.f90's 0.5, so "their ground state" is ambiguous by a factor 2 in the
#  contact coupling — which moves the peak density, hence the dipole field,
#  hence the very offset being measured.
#
#    qsub -g tga-kozuma-kouhi runs/matsui_fig4b/submit_fig4b.sh
#
#  Smoke first (2 fields at 32³, every code path, minutes):
#    qsub -g tga-kozuma-kouhi -N f4b_smk -t 1-1 -l h_rt=1:00:00 \
#         runs/matsui_fig4b/submit_fig4b.sh SMOKE
# ============================================================
#$ -cwd
#$ -N matsui_fig4b
#$ -l gpu_1=1
#$ -l h_rt=6:00:00
#$ -t 1-4
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/wt_matsui_fig4b
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail                       # re-arm: tsubame_setup runs `set +e`
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH}:/gs/fs/tga-kozuma-kouhi/shared/.julia:${HOME}/.julia"

# /gs/bs/work, not the group /gs/fs: the latter was full on 2026-07-29 and the
# failure mode is EDQUOT + mmap SIGBUS, not anything that says "disk full".
export SPINORBEC_STORE="${SPINORBEC_STORE:-/gs/bs/work/7/uk07267/runs}"
mkdir -p "$SPINORBEC_STORE"

if [ "${1:-}" = "SMOKE" ]; then
    CONFIG=runs/matsui_fig4b/fig4b_smoke_n32.yaml
else
    case "${SGE_TASK_ID:-1}" in
        1) CONFIG=runs/matsui_fig4b/fig4b_scan_n32.yaml ;;
        2) CONFIG=runs/matsui_fig4b/fig4b_conv_n64.yaml ;;
        3) CONFIG=runs/matsui_fig4b/fig4b_gsvariant_n32.yaml ;;
        4) CONFIG=runs/matsui_fig4b/fig2c_populations_n32.yaml ;;
        *) echo "no config for task ${SGE_TASK_ID}"; exit 1 ;;
    esac
fi

echo "[task ${SGE_TASK_ID:-smoke}] $(hostname) cfg=$CONFIG"
echo "[src]   $(git rev-parse HEAD)  $(git status --porcelain -- src | wc -l) dirty src files"
echo "[store] $SPINORBEC_STORE"
nvidia-smi -L || true

# Guard silent CPU fallback (a broken-CUDA node otherwise burns hours on CPU).
"$JULIA" --project=. -e '
    import CUDA
    CUDA.functional() || (@error "CUDA not functional — refusing CPU fallback"; exit(1))
    using SpinorBEC
    run_yaml(ARGS[1])' "$CONFIG"

echo "[task ${SGE_TASK_ID:-smoke}] done"
