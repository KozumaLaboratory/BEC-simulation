#!/usr/bin/env bash
# TSUBAME (4.0 / 3.0) environment bootstrap. Source this from interactive
# shells or sbatch scripts:
#
#   source scripts/tsubame_setup.sh
#
# Sets up:
#   - module load cuda + julia (best-effort, defaults to TSUBAME 4 names)
#   - JULIA_DEPOT_PATH on node-local NVMe so first-time precompile
#     doesn't thrash Lustre's metadata server
#   - SPINORBEC_SCRATCH_DIR for per-frame snapshot streaming
#   - LD_LIBRARY_PATH so CUDA.jl finds the runtime
#   - JULIA_NUM_THREADS sized to the SLURM cpus-per-task
#
# Idempotent — safe to source multiple times.

set +e   # don't kill the parent shell on `module` failures

# --- Resolve node-local scratch (TSUBAME 4 → 3 fallback → /tmp) -------
if [[ -n "${T4_TMPDIR:-}" ]] && [[ -w "${T4_TMPDIR}" ]]; then
    SBEC_LOCAL="$T4_TMPDIR"
elif [[ -n "${T4_LOCAL:-}" ]] && [[ -w "${T4_LOCAL}" ]]; then
    SBEC_LOCAL="$T4_LOCAL"
elif [[ -n "${TMPDIR:-}" ]] && [[ -w "${TMPDIR}" ]]; then
    SBEC_LOCAL="$TMPDIR"
else
    SBEC_LOCAL="/tmp"
fi

# --- Module load (silent on machines that don't have it) --------------
if command -v module >/dev/null 2>&1; then
    module load cuda/12.4 2>/dev/null || module load cuda 2>/dev/null || true
    module load julia/1.12 2>/dev/null || module load julia/1.11 2>/dev/null || \
        module load julia 2>/dev/null || true
    # CUDA_HOME populated by the cuda module
    if [[ -n "${CUDA_HOME:-}" ]]; then
        export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
    fi
fi

# --- Julia depot on node-local NVMe -----------------------------------
# Avoids Lustre metadata storms on first-time precompile (~10k file ops).
if [[ -z "${JULIA_DEPOT_PATH:-}" ]] && [[ -n "${SBEC_LOCAL}" ]]; then
    mkdir -p "${SBEC_LOCAL}/.julia"
    export JULIA_DEPOT_PATH="${SBEC_LOCAL}/.julia"
fi

# --- SpinorBEC snapshot scratch ---------------------------------------
export SPINORBEC_SCRATCH_DIR="${SBEC_LOCAL}/spinorbec_snaps"
mkdir -p "$SPINORBEC_SCRATCH_DIR"

# --- Threads ----------------------------------------------------------
if [[ -n "${SLURM_CPUS_PER_TASK:-}" ]]; then
    export JULIA_NUM_THREADS="$SLURM_CPUS_PER_TASK"
elif [[ -z "${JULIA_NUM_THREADS:-}" ]]; then
    export JULIA_NUM_THREADS=4
fi

# --- WSL2 dev-machine convenience -------------------------------------
# (no-op on real TSUBAME nodes since /usr/lib/wsl is absent)
if [[ -d /usr/lib/wsl/lib ]]; then
    export LD_LIBRARY_PATH="/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}"
fi

echo "[tsubame_setup] JULIA_DEPOT_PATH    = $JULIA_DEPOT_PATH"
echo "[tsubame_setup] SPINORBEC_SCRATCH_DIR = $SPINORBEC_SCRATCH_DIR"
echo "[tsubame_setup] JULIA_NUM_THREADS   = $JULIA_NUM_THREADS"
