#!/bin/bash
# UGE — does their 3-point FD Laplacian explain the Fig. 4B residual?
#
#   qsub -g tga-kozuma-kouhi runs/matsui_fig4b/submit_fd_probe.sh
#
# The analytic estimate says no, and with the wrong sign: measured on their exact
# grid, the FD kinetic deficit differenced between m=-5 and m=-6 is 0.112 nT, and
# the resonance sits where the Zeeman splitting matches that difference — so FD
# pushes the resonance TOWARD zero, widening the 0.411 nT gap rather than closing
# it. This runs it rather than arguing it, with a positive control on the
# hand-built path.
#$ -cwd
#$ -N f4b_fd
#$ -l gpu_1=1
#$ -l h_rt=3:00:00
#$ -j n

set -euo pipefail

PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/wt_matsui_fig4b
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia

cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH}:/gs/fs/tga-kozuma-kouhi/shared/.julia:${HOME}/.julia"

REF=$(ls -dt /gs/bs/work/7/uk07267/runs/fig4b_scan_n32_* | head -1)
echo "[fd] $(hostname)  HEAD $(git rev-parse --short HEAD)  ref=$REF"
nvidia-smi -L || true

"$JULIA" --project=. -e '
    import CUDA
    CUDA.functional() || (@error "CUDA not functional — refusing CPU fallback"; exit(1))
    include("scripts/validation/matsui_fd_laplacian_probe.jl")' "$REF"

echo "[fd] done"
