#!/bin/bash
# UGE submission (uk07267 / tga-kozuma-kouhi): finite-temperature SGPE GPU
# campaign for Eu shape optimization at production resolution (96^3-128^3,
# F64) on a full H100.
#
#   qsub -g tga-kozuma-kouhi [-v SBEC_FT_MODE=<mode>] \
#       scripts/eu_shape/submit_finite_t.sh
#
# NB: -g goes on the qsub CLI, NOT as a directive (TSUBAME rejects #$ -g).
# SBEC_FT_MODE selects the driver mode (positional ARG passed to the Julia
# driver); defaults to "campaign" when unset. Examples: ft_smoke -> "smoke",
# production -> "campaign".
#$ -cwd
#$ -N eu_ft_sgpe
#$ -l gpu_h=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/runs/eu_shape_finite_t/uge.log

set -euo pipefail

# Paths follow the SPINORBEC_TSUBAME_* env convention (see CLAUDE.md UGE
# auto-registration); defaults reproduce the uk07267 / tga-kozuma-kouhi layout.
PROJECT_ROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation}
OUT_DIR=${SPINORBEC_TSUBAME_RUNS_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/runs}/eu_shape_finite_t
mkdir -p "$OUT_DIR"
cd "$PROJECT_ROOT"

# Environment bootstrap: node-local depot scratch, threads, LD_LIBRARY_PATH.
source scripts/tsubame_setup.sh

. /etc/profile.d/modules.sh
module load "${SPINORBEC_TSUBAME_CUDA_MODULE:-cuda/12.8.0}"

# Compute nodes do NOT inherit the login depot; point at the shared depot
# (where packages were instantiated) or every job fails "Package not installed".
export JULIA_DEPOT_PATH=${SPINORBEC_TSUBAME_DEPOT:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

FT_MODE=${SBEC_FT_MODE:-campaign}
export SBEC_FT_BACKEND=gpu            # driver selects CUDABackend (import CUDA)

echo "[eu_ft_sgpe] host=$(hostname)  mode=${FT_MODE}"
"$JULIA" --project=. docs/guides/figures/eu_shape_finite_t.jl "${FT_MODE}" \
    2>&1 | tee "$OUT_DIR/finite_t_${FT_MODE}.out"

# collect the CSVs the driver wrote next to itself (@__DIR__) into the run dir
cp -f docs/guides/figures/eu_ft_*.csv "$OUT_DIR/" 2>/dev/null || true
echo "[eu_ft_sgpe] done"
