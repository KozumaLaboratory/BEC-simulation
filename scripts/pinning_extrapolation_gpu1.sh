#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=6:00:00
#$ -N eu_pin_fast
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt/logs/
set -e
GRP=tga-kozuma-kouhi
export JULIA_DEPOT_PATH=/gs/fs/$GRP/shared/.julia      # pre-precompiled, fast start
JULIA=/gs/fs/$GRP/shared/.juliaup/bin/julia
cd /gs/fs/$GRP/uk07267/BEC-opt
mkdir -p logs
echo "host=$(hostname) date=$(date)"

# --- CUDA driver setup + HARD guard ------------------------------------------
# TSUBAME GPU jobs silently fall back to CPU if the driver isn't on the path
# (gotcha_tsubame_ldap_outage_and_wsl_1password_socket 1b): cpu≈wallclock,
# gpu_usage NONE, and a 48^3 LBFGS run then takes hours with a bogus ETA.
# Abort in ~30s instead of burning the node.
if command -v module >/dev/null 2>&1; then
    module load cuda/12.4 2>/dev/null || module load cuda 2>/dev/null || true
    [ -n "${CUDA_HOME:-}" ] && export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
fi
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader || true
echo "[guard] checking CUDA.functional()…"
$JULIA --project=. -e 'using CUDA; CUDA.functional() || (println(stderr, "FATAL: CUDA NOT FUNCTIONAL — would silently run on CPU. Aborting."); exit(1)); println("CUDA OK: ", CUDA.name(CUDA.device()))'

# --- run ----------------------------------------------------------------------
# Pinning + ε→0 extrapolation for the weak-field Eu+DDI degenerate GS.
# SM_PIN=bx (conjugate transverse field) primary; SM_PIN=trap (elliptical
# trap) is the independent cross-check — same E0 ⇒ trustworthy.
# The script prints per-step LBFGS ETA + per-ε elapsed/remaining estimates
# (SM_VERBOSE=1 default), so `tail -f logs/eu_pin_extrap.o<id>` shows live ETA.
export SM_PIN=${SM_PIN:-bx}
export SM_GRID=${SM_GRID:-32}
export SM_BOX=${SM_BOX:-24.0}
export SM_B_UG=${SM_B_UG:-10.0}
export SM_DT=${SM_DT:-0.002}
export SM_ITP=${SM_ITP:-5000}
export SM_LBFGS=${SM_LBFGS:-600}
export SM_NITER=${SM_NITER:-300}
export SM_EPS=${SM_EPS:-4e-3,2e-3,1e-3,5e-4,2.5e-4}
export SM_VERBOSE=1
echo "[run] PIN=$SM_PIN GRID=$SM_GRID LBFGS=$SM_LBFGS ITP=$SM_ITP niter=$SM_NITER eps=$SM_EPS"
$JULIA --project=. scripts/eu_pinning_extrapolation.jl
echo "ALLDONE"
