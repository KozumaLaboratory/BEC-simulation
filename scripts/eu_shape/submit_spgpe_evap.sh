#!/bin/bash
# UGE submission (uk07267 / tga-kozuma-kouhi): SECOND-SCALE evaporation of ¹⁵¹Eu
# as a full SPGPE (growth + energy-damping reservoirs) on one H100.
#
#   qsub -g tga-kozuma-kouhi [-v SBEC_SPGPE_MODE=<mode>] \
#       scripts/eu_shape/submit_spgpe_evap.sh
#
# NB: -g goes on the qsub CLI, NOT as a directive (TSUBAME rejects #$ -g).
# SBEC_SPGPE_MODE ∈ {smoke, preflight, production}; defaults to production.
#
# Sizing (measured on an RTX 5070 Ti; H100 is faster and has the headroom that
# the 16 GB consumer card does not):
#   window T ≤ 1.05 T_c = 0.714 s of REAL ramp = 1288 internal units
#   80³ grid, dt = 0.002 ⇒ 6.4e5 steps ≈ 0.5 h per trajectory, 4 trajectories.
#   HOST memory is the binding constraint locally, not GPU: the ensemble
#   accumulators are n_save full spatial arrays (≈0.5 GB at 80³ × 40 saves).
#   h_rt=6:00:00 leaves room for JIT + a slower-than-expected node.
#$ -cwd
#$ -N eu_spgpe_evap
#$ -l gpu_h=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/runs/eu_evap_spgpe/uge.log

set -euo pipefail

PROJECT_ROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation}
OUT_DIR=${SPINORBEC_TSUBAME_RUNS_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/runs}/eu_evap_spgpe
mkdir -p "$OUT_DIR"
cd "$PROJECT_ROOT"

source scripts/tsubame_setup.sh

. /etc/profile.d/modules.sh
module load "${SPINORBEC_TSUBAME_CUDA_MODULE:-cuda/12.8.0}"

# Depot as a LIST: node-local NVMe first, shared Lustre depot second.
#
# Compute nodes do not inherit the login depot, so the shared depot has to be on
# the path or every job fails "Package not installed". But pointing at it ALONE
# makes Julia write precompile output to Lustre, and the group is at 985/1000 GB
# — a run died with `LLVM ERROR: IO failure on output stream: Disk quota
# exceeded` mid-precompile (2026-07-29). Julia writes new caches to the FIRST
# writable depot and reads packages from all of them, so this puts compile
# output on per-job NVMe and keeps the installed packages readable, without
# deleting anyone's data. Cost: precompile runs once per job (~2-3 min).
SHARED_DEPOT=${SPINORBEC_TSUBAME_DEPOT:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
if [ -n "${T4_TMPDIR:-}" ] && [ -w "${T4_TMPDIR}" ]; then
    mkdir -p "$T4_TMPDIR/.julia"
    export JULIA_DEPOT_PATH="$T4_TMPDIR/.julia:$SHARED_DEPOT"
else
    export JULIA_DEPOT_PATH="$SHARED_DEPOT"
fi
echo "[eu_spgpe_evap] JULIA_DEPOT_PATH=$JULIA_DEPOT_PATH"
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

# Fail loudly and early if the group quota cannot absorb this job's output.
t4-user-info disk group -g tga-kozuma-kouhi 2>/dev/null | tail -2 || true

MODE=${SBEC_SPGPE_MODE:-production}
export SBEC_SPGPE_BACKEND=gpu

# The remote checkout has silently run PRE-FIX source before and produced
# all-NaN output (2026-07-27). Record what is actually about to run.
echo "[eu_spgpe_evap] host=$(hostname)  mode=${MODE}"
echo "[eu_spgpe_evap] HEAD=$(git rev-parse --short HEAD)  $(git log -1 --format=%s)"
git status --porcelain | head -20

"$JULIA" --project=. docs/guides/figures/eu_evaporation_spgpe.jl "${MODE}" \
    2>&1 | tee "$OUT_DIR/spgpe_evap_${MODE}.out"

# The driver writes into figs/eu_evaporation_optimization/ (repo-relative);
# copy the CSVs to the run dir so results survive a re-clone.
cp -f figs/eu_evaporation_optimization/eu_evap_spgpe*.csv "$OUT_DIR/" 2>/dev/null || true
echo "[eu_spgpe_evap] done"
