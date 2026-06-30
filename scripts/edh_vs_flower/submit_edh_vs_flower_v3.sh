#!/bin/bash
# UGE submission (ue06186 / tga-kozuma-kouhi): EdH-vs-Flower dynamics comparison.
# ONE GPU job, fresh unbiased ground state (NO stale seed):
#   (0) precompile warmup into the personal depot (works around the shared
#       depot's uk07267-owned stale REPLExt cache that EACCES'd the first job),
#   (1) per config: ITP from a RANDOM init @ 10 mG → LBFGS polish (Sobolev 0.5)
#       → RTP (EdH quench / Flower Goto protocol, full-ψ streamed),
#   (2) Mermin-Ho diagnostic on each.
# Bulky full-ψ results go to a DEDICATED data dir, not the code checkout.
# The spin-texture comparison is rendered locally from the saved full ψ.
#
#   qsub -g tga-kozuma-kouhi scripts/edh_vs_flower/submit_edh_vs_flower.sh
#   monitor:  tail -f /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower/run_all.out
#
# -g goes on the qsub CLI, NOT as a directive (TSUBAME rejects #$ -g).
#$ -cwd
#$ -N edh_flower_v3dyn
#$ -l gpu_h=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_v3/uge.log

set -euo pipefail

PROJECT_ROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation}
OUT_DIR=${SPINORBEC_TSUBAME_RUNS_ROOT:-/gs/fs/tga-kozuma-kouhi/ue06186/runs}/edh_vs_flower_v3
DATA_ROOT=${FPE_RUNS_ROOT:-/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data}

mkdir -p "$OUT_DIR" "$DATA_ROOT"
cd "$PROJECT_ROOT"
mkdir -p runs/eu151_edh_vs_flower/cache

. /etc/profile.d/modules.sh
module load cuda/12.8.0

# Hybrid depot: personal first (writable) over the read-only shared depot.
# Direct julia binary — the juliaup launcher is unreadable for non-uk07267
# users (juliaup.json is 0600).
export JULIA_DEPOT_PATH=${SPINORBEC_TSUBAME_DEPOT:-${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/ue06186/.julia}
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia}
export FPE_RUNS_ROOT="$DATA_ROOT"          # run_all.jl writes bulky RTP results here

echo "[edh_vs_flower] host=$(hostname)  $(date)"
echo "[edh_vs_flower] data → $DATA_ROOT   logs → $OUT_DIR"

# (0) Warmup on THIS compute node: rebuild package caches into the personal
#     depot so loading does not stat the shared depot's uk07267-owned caches
#     (the EACCES that killed job 8003645).
echo "[edh_vs_flower] === precompile warmup ==="
"$JULIA" --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' \
    2>&1 | tee "$OUT_DIR/warmup.out"

# (1)+(2) ITP(random,10mG)→LBFGS(0.5)→RTP for both legs + Mermin-Ho diagnostic,
#         single Julia session (JIT paid once). Loud progress bars with ETA.
echo "[edh_vs_flower] === ITP→LBFGS→RTP + diagnostic ==="
"$JULIA" --project=. scripts/edh_vs_flower/run_all.jl \
    runs/eu151_edh_vs_flower/edh_quench_v3.yaml \
    runs/eu151_edh_vs_flower/flower_smooth_v3.yaml \
    2>&1 | tee "$OUT_DIR/run_all.out"

echo "[edh_vs_flower] done  $(date)"
echo "[edh_vs_flower] next (local): extract_observables.py <result.jld2> cache.h5"
echo "                && viz_dynamics.py cache.h5 --view spin3d --anim spin3d.mp4"
