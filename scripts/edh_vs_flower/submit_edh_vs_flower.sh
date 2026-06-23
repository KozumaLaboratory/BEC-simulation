#!/bin/bash
# UGE submission (ue06186 / tga-kozuma-kouhi): EdH-vs-Flower comparison.
# Runs BOTH configs (shared cached GS) + Mermin–Ho diagnostic in ONE GPU job.
#
#   qsub -g tga-kozuma-kouhi scripts/edh_vs_flower/submit_edh_vs_flower.sh
#
# NB: -g goes on the qsub CLI, NOT as a directive (TSUBAME rejects #$ -g).
# Follow the Sato-san rule: confirm on an INTERACTIVE H100 first (see README),
# then submit this batch job.
#$ -cwd
#$ -N edh_vs_flower
#$ -l gpu_h=1
#$ -l h_rt=4:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower/uge.log

set -euo pipefail

# Paths follow the SPINORBEC_TSUBAME_* env convention; defaults reproduce the
# ue06186 / tga-kozuma-kouhi layout. Override via env if your clone differs.
PROJECT_ROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation}
OUT_DIR=${SPINORBEC_TSUBAME_RUNS_ROOT:-/gs/fs/tga-kozuma-kouhi/ue06186/runs}/edh_vs_flower
mkdir -p "$OUT_DIR"
cd "$PROJECT_ROOT"

. /etc/profile.d/modules.sh
module load cuda/12.8.0

# Compute nodes do NOT inherit the login depot; point at the shared depot
# (hybrid keeps personal precompile cache writable, avoiding EACCES on the
# read-only shared depot — see project_tsubame_kozumalab memory).
export JULIA_DEPOT_PATH=${SPINORBEC_TSUBAME_DEPOT:-$HOME/.julia:/gs/fs/tga-kozuma-kouhi/shared/.julia}
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

echo "[edh_vs_flower] host=$(hostname)  $(date)"
"$JULIA" --project=. scripts/edh_vs_flower/run_all.jl \
    runs/eu151_edh_vs_flower/edh_quench.yaml \
    runs/eu151_edh_vs_flower/flower_smooth.yaml \
    2>&1 | tee "$OUT_DIR/run_all.out"
echo "[edh_vs_flower] done  $(date)"
