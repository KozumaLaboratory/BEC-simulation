#!/bin/bash
# Vortex-survival positive control across a resolution ladder.
#$ -cwd
#$ -N eu_vs
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -j y
#$ -o logs/tsubame/vs.log
set -euo pipefail
REPO="${REPO:-/gs/bs/work/7/uk07267/bec-repo-barnett}"
cd "$REPO"; mkdir -p logs/tsubame
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
export SPINORBEC_STORE="${SPINORBEC_STORE:-/gs/bs/work/7/uk07267/bec-runs}"
mkdir -p "$SPINORBEC_STORE"
# qsub -v splits on commas; take an x-separated grid spec.
[ -n "${VS_GRID:-}" ] && VS_N="${VS_GRID//x/,}"
[ -n "${VS_BOXSPEC:-}" ] && VS_BOX="${VS_BOXSPEC//x/,}"
export VS_N="${VS_N:-64,64,32}" VS_BOX="${VS_BOX:-24.0,24.0,12.0}"
case "$VS_N" in *,*,*) ;; *) echo "FATAL: VS_N='$VS_N' not 3-D"; exit 1;; esac
source scripts/tsubame_setup.sh
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "=== VS node $(hostname) $(date) n=$VS_N box=$VS_BOX tag=${VS_TAG:-} ==="
$JULIA --project=. -e 'using CUDA; @assert CUDA.functional()'
$JULIA --project=. runs/eu_barnett_rotfield_clean/run_vortex_survival.jl
