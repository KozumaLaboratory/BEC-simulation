#!/bin/bash
# UGE GPU SMOKE (ue06186 / tga-kozuma-kouhi): verify the full EdH/Flower
# pipeline RUNS CORRECTLY on TSUBAME hardware before the real job.
# Tiny grid / few steps; exercises ITP(random)→LBFGS(sobolev)→RTP+K_3 loss
# + full-ψ save + Mermin-Ho diagnostic on GPU.  ~minutes.
#
#   qsub -g tga-kozuma-kouhi scripts/edh_vs_flower/submit_smoke.sh
#   check:  cat /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower/smoke.out
#$ -cwd
#$ -N edh_smoke
#$ -l gpu_h=1
#$ -l h_rt=0:30:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower/smoke_uge.log

set -euo pipefail

PROJECT_ROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation}
OUT_DIR=${SPINORBEC_TSUBAME_RUNS_ROOT:-/gs/fs/tga-kozuma-kouhi/ue06186/runs}/edh_vs_flower
DATA_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_smoke

mkdir -p "$OUT_DIR" "$DATA_ROOT"
cd "$PROJECT_ROOT"
mkdir -p runs/eu151_edh_vs_flower/cache

. /etc/profile.d/modules.sh
module load cuda/12.8.0
export JULIA_DEPOT_PATH=${SPINORBEC_TSUBAME_DEPOT:-${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia}
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia}
export FPE_RUNS_ROOT="$DATA_ROOT"

echo "[smoke] host=$(hostname)  $(date)  CUDA node check:"
"$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' 2>&1 | tee "$OUT_DIR/smoke_warmup.out"
"$JULIA" --project=. -e 'import CUDA; println("CUDA.functional() = ", CUDA.functional())' 2>&1 | tee -a "$OUT_DIR/smoke.out"

echo "[smoke] === full pipeline on tiny GPU config ==="
"$JULIA" --project=. scripts/edh_vs_flower/run_all.jl \
    runs/eu151_edh_vs_flower/_smoke_gpu.yaml \
    runs/eu151_edh_vs_flower/_smoke_gpu.yaml \
    2>&1 | tee -a "$OUT_DIR/smoke.out"

echo "[smoke] OK — pipeline ran on GPU. $(date)"
