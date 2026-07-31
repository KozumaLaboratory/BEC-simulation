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
#  Eight tasks (1-4, 7-8 loss-free ; their L3loss = 0):
#    1  fig4b_scan_n32       81 fields, -20 … +20 nT, the curve
#    2  fig4b_conv_n64        8 fields, resolution error bar on task 1's centre
#    3  fig4b_gsvariant_n32  19 fields, their literal (inconsistent) ground state
#    4  fig2c_populations_n32  one field, 40 ms, N_m(t) against their Fig. 2C sheet
#    5  fig4b_loss_n32       45 fields x 3 K3, the experiment's atom-number deficit
#    6  gs_c1ratio_probe     3 ground states — RETRACTED, see the file's own header
#    7  fig4b_theirramp_n32  45 fields with THEIR exponential ramp, not our linear one
#    8  fig4b_scan_n64       the same 45 fields at 64^3, so the dip is measured not inferred
#    9  fig4b_ddikernel_n32  25 fields x {trunc auto,none} x {padded,unpadded}
#   10  fig4b_theirgrid_n128 THEIR grid exactly: 128^3, box 36.2 a_ho, dx 0.4 aHO
#   11  fig4b_boxscan_n32    box 16/24/32 at FIXED dx = 0.5 — box vs resolution
#   12  fig4b_dtconv_n32     dt 1e-3 vs 2.5e-4 — is OUR integrator converged
#   13  fig4b_natoms_n32     RETRACTED — overrode N in one of three places
#   14  fig4b_natoms_fixed_n32  N in lockstep everywhere, at +2.5 nT where F.txt
#                            gives us their own 5 ms state to compare against
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
#  Cost, measured warm (UGE 8304456): 5.2 s per 32³ point, 21.7 s per 64³ point,
#  plus ~75 s of JIT absorbed by each task's first point. The whole array is ~10
#  min per task, not the hours a cold smoke timer suggests.
#
#  Smoke first (2 fields at 32³, every code path, minutes):
#    qsub -g tga-kozuma-kouhi -N f4b_smk -t 1-1 -l h_rt=1:00:00 \
#         runs/matsui_fig4b/submit_fig4b.sh SMOKE
# ============================================================
#$ -cwd
#$ -N matsui_fig4b
#$ -l gpu_1=1
#$ -l h_rt=8:00:00
#$ -t 1-14
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
        5) CONFIG=runs/matsui_fig4b/fig4b_loss_n32.yaml ;;
        6) CONFIG=runs/matsui_fig4b/gs_c1ratio_probe.yaml ;;
        7) CONFIG=runs/matsui_fig4b/fig4b_theirramp_n32.yaml ;;
        8) CONFIG=runs/matsui_fig4b/fig4b_scan_n64.yaml ;;
        9) CONFIG=runs/matsui_fig4b/fig4b_ddikernel_n32.yaml ;;
       10) CONFIG=runs/matsui_fig4b/fig4b_theirgrid_n128.yaml ;;
       11) CONFIG=runs/matsui_fig4b/fig4b_boxscan_n32.yaml ;;
       12) CONFIG=runs/matsui_fig4b/fig4b_dtconv_n32.yaml ;;
       13) CONFIG=runs/matsui_fig4b/fig4b_natoms_n32.yaml ;;
       14) CONFIG=runs/matsui_fig4b/fig4b_natoms_fixed_n32.yaml ;;
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
