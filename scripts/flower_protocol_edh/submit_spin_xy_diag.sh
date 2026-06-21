#!/bin/bash
# UGE submission (uk07267 / tga-kozuma-kouhi): transverse-spin x/y (C4)
# anisotropy diagnostic at low field.
#
#   qsub -g tga-kozuma-kouhi [-v DIAG_SMOKE=1] \
#       scripts/flower_protocol_edh/submit_spin_xy_diag.sh
#
# NB: -g goes on the qsub CLI, NOT as a directive (TSUBAME rejects #$ -g).
#$ -cwd
#$ -N spin_xy_diag
#$ -l gpu_h=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/runs/diag_spin_xy/uge.log

set -euo pipefail

# Paths follow the SPINORBEC_TSUBAME_* env convention (see CLAUDE.md UGE
# auto-registration); defaults reproduce the uk07267 / tga-kozuma-kouhi layout.
PROJECT_ROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation}
OUT_DIR=${SPINORBEC_TSUBAME_RUNS_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/runs}/diag_spin_xy
mkdir -p "$OUT_DIR"
cd "$PROJECT_ROOT"

. /etc/profile.d/modules.sh
module load cuda/12.8.0

# Compute nodes do NOT inherit the login depot; point at the shared depot
# (where packages were instantiated) or every job fails "Package not installed".
export JULIA_DEPOT_PATH=${SPINORBEC_TSUBAME_DEPOT:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

echo "[spin_xy_diag] host=$(hostname)  smoke=${DIAG_SMOKE:-0}  B_uG=${DIAG_B_UG:-10}"
"$JULIA" --project=. scripts/flower_protocol_edh/spin_xy_anisotropy_diag.jl \
    2>&1 | tee "$OUT_DIR/diag_B${DIAG_B_UG:-10}uG_smoke${DIAG_SMOKE:-0}.out"
echo "[spin_xy_diag] done"
