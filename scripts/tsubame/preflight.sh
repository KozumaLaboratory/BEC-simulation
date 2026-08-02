#!/usr/bin/env bash
# Source this at the top of any TSUBAME job that runs SpinorBEC:
#
#     source scripts/tsubame/preflight.sh          # asserts + exports
#     source scripts/tsubame/preflight.sh --gpu    # also checks the CUDA path
#
# Why this is a script and not a paragraph in a guide. On 2026-07-31 one session
# lost four job batches to four separate environment requirements, and every one
# of them was already written down — two of them in files that same session had
# just edited:
#
#   1. BLAS threads unpinned      → a ci tier ran 18m52s on one file against a
#                                   51.8s estimate, hit the per-file timeout and
#                                   aborted with 227 files never started.
#   2. `runs/` excluded from rsync → config-scanning gates errored on ENOENT and
#                                   reported a red that was about the transfer.
#   3. `import CUDA` omitted      → all five GPU configs died with
#                                   `MethodError: _to_device(::CUDABackend, ::Array)`.
#   4. work tree under $HOME      → $HOME is a 25 GB quota; nine of twelve runs
#                                   died mid-flight with "Disk quota exceeded".
#
# Reading did not prevent any of them. Failing at second zero, with the fix in the
# message, might. Each check below costs milliseconds and names its own remedy.

_pf_die() { echo "[preflight] FAIL: $*" >&2; exit 78; }
_pf_warn() { echo "[preflight] warn: $*" >&2; }

# ── 1. BLAS threads ──────────────────────────────────────────────────────
# OpenBLAS sizes its level-1 team from the core count and a TSUBAME node reports
# 384, so every `dot` on a few-MB ComplexF64 array becomes spawn+barrier. The
# workers are already the parallelism; a BLAS team inside each is pure
# contention. `${VAR:-1}` so an explicit caller choice still wins.
export OPENBLAS_NUM_THREADS=${OPENBLAS_NUM_THREADS:-1}
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}

# ── 2. Not under $HOME ───────────────────────────────────────────────────
# docs/guides/tsubame.md's filesystem table: $HOME is "tiny (no project dirs)".
# The quota is 25 GB, not the 30 the table says — `t4-user-info disk home`.
_pf_root="${SPINORBEC_TSUBAME_PROJECT_ROOT:-$PWD}"
case "$_pf_root" in
    "$HOME"/*)
        _pf_die "project root is under \$HOME ($_pf_root).
    \$HOME has a 25 GB quota and fills silently — a run dies with
    'SystemError: close: Disk quota exceeded' partway through, so early jobs in a
    batch look fine. Use \$T4_GROUP (TB-scale):
        /gs/fs/tga-kozuma-kouhi/\$USER/<name>
    Check with: t4-user-info disk home" ;;
esac

# ── 3. Headroom on whatever volume we ARE on ─────────────────────────────
# A quota is not free space: `df` reports the raw Lustre mount, which is why a
# full group volume shows as terabytes available right up until EDQUOT.
if command -v t4-user-info >/dev/null 2>&1; then
    _pf_grp=$(t4-user-info disk group 2>/dev/null | awk 'NR==3 {print $3, $4}')
    if [ -n "${_pf_grp:-}" ]; then
        set -- $_pf_grp
        _pf_used=${1%%.*}; _pf_cap=${2%%.*}
        if [ -n "$_pf_cap" ] && [ "$_pf_cap" -gt 0 ] 2>/dev/null; then
            _pf_pct=$(( _pf_used * 100 / _pf_cap ))
            [ "$_pf_pct" -ge 90 ] && _pf_die \
                "group volume ${_pf_used}/${_pf_cap} GB (${_pf_pct}%). Free space
    before launching; a batch that fills it dies partway, and the jobs that ran
    first still look successful."
            [ "$_pf_pct" -ge 75 ] && _pf_warn "group volume ${_pf_pct}% full"
        fi
    fi
fi

# ── 4. runs/ present ─────────────────────────────────────────────────────
# test_config_zeeman_seed_agreement.jl and test_lhy_config_validity_domain.jl
# walk runs/. An rsync that syncs only src/ and test/ makes them ENOENT rather
# than skip, so the suite goes red for a reason that is about the transfer.
[ -d "$_pf_root/runs" ] || _pf_warn \
    "no runs/ under $_pf_root — config-scanning gates will error, not skip.
    Include it in the rsync (excluding *.jld2 keeps it small)."

# ── 5. GPU path ──────────────────────────────────────────────────────────
# `_to_device(::CUDABackend, ::Array)` lives in ext/SpinorBECCUDAExt, a weak
# dependency: it is only active once CUDA is loaded. `import CUDA` must come
# BEFORE `using SpinorBEC` (CLAUDE.md:141). This cannot check the caller's julia
# one-liner, so it verifies the runtime is there and says the rest.
if [ "${1:-}" = "--gpu" ]; then
    module load "${SPINORBEC_TSUBAME_CUDA_MODULE:-cuda/12.8.0}" 2>/dev/null || \
        module load cuda 2>/dev/null || _pf_warn "no cuda module loaded"
    echo "[preflight] GPU job: every julia invocation must start with" \
         "\`import CUDA; using SpinorBEC\` — in that order, or the extension is" \
         "inert and backend: gpu dies with MethodError on _to_device."
fi

echo "[preflight] ok — root=$_pf_root OPENBLAS_NUM_THREADS=$OPENBLAS_NUM_THREADS"
