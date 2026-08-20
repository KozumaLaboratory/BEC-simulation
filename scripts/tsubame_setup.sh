#!/usr/bin/env bash
# TSUBAME 4 environment bootstrap. Source this from interactive shells
# or UGE submit scripts:
#
#   source scripts/tsubame_setup.sh
#
# Sets up:
#   - module load cuda (best-effort). The julia load is attempted and always
#     fails: TSUBAME 4 ships no julia modulefile. This script does NOT put
#     julia on PATH — name the binary yourself in UGE jobs, via
#     $SPINORBEC_TSUBAME_JULIA (see scripts/spinorbec.env). A bare `julia`
#     works in a login shell only, from the lab profile, which qsub drops.
#   - JULIA_DEPOT_PATH on node-local NVMe so first-time precompile
#     doesn't thrash Lustre's metadata server
#   - SPINORBEC_SCRATCH_DIR for per-frame snapshot streaming
#   - LD_LIBRARY_PATH so CUDA.jl finds the runtime
#   - JULIA_NUM_THREADS sized to NHOSTS / NSLOTS / fallback
#
# Idempotent — safe to source multiple times.

# `module` on TSUBAME 4 exits non-zero for a missing modulefile (there is no
# julia one), so errexit has to come off around it. It must go back ON, and it
# did not: from 2026-08-08 until 2026-08-20 every submit script that sourced this
# file ran the REST OF ITSELF unguarded. A job whose julia step errored still
# reached its final `echo` and reported "done" — verified again on job 8450018.13.
# The memory recording the 2026-08-08 incident says it was fixed; on this ref it
# was not, which is why a landed-fix claim has to be anchored to a ref.
_SBEC_ERREXIT_WAS_SET=0
case "$-" in *e*) _SBEC_ERREXIT_WAS_SET=1 ;; esac
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
# UGE exports NSLOTS (slot count for parallel envs); fall back to a
# sensible default when running outside the scheduler (interactive node).
if [[ -n "${NSLOTS:-}" ]]; then
    export JULIA_NUM_THREADS="$NSLOTS"
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

# Hand errexit back exactly as we found it. Sourcing this file must not change
# the caller's failure semantics.
if [ "${_SBEC_ERREXIT_WAS_SET:-0}" = "1" ]; then
    set -e
fi
unset _SBEC_ERREXIT_WAS_SET
