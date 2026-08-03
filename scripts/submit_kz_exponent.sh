#!/bin/bash
# UGE submission: Kibble-Zurek exponent from the SPGPE, scalar-limit control.
#
#   qsub -g tga-kozuma-kouhi -o <dir>/uge.log \
#        -v SPINORBEC_TSUBAME_PROJECT_ROOT=<worktree>,SBEC_KZ_MODE=scalar \
#        scripts/submit_kz_exponent.sh
#
# Reports the EXPONENT alpha in N_v ~ tau_Q^-alpha, never the absolute defect
# count: absolute condensate numbers are not an output of a grand-canonical SPGPE
# (prescribing mu prescribes N0), whereas a ratio measured at fixed cutoff with
# only the quench rate varying is.
#
# NB: -g and -o go on the qsub CLI; UGE rejects `#$ -g` and expands nothing in
# directives.
#$ -cwd
#$ -N sbec_kz
#$ -l gpu_h=1
#$ -l h_rt=8:00:00
#$ -j y

set -euo pipefail

PROJECT_ROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:?set SPINORBEC_TSUBAME_PROJECT_ROOT}
MODE=${SBEC_KZ_MODE:-scalar}
OUT_DIR=${SPINORBEC_TSUBAME_RUNS_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/runs}/kz_exponent
mkdir -p "$OUT_DIR"
cd "$PROJECT_ROOT"

source scripts/tsubame_setup.sh
. /etc/profile.d/modules.sh
module load "${SPINORBEC_TSUBAME_CUDA_MODULE:-cuda/12.8.0}"

# Node-local depot first so precompile output stays off the group quota.
SHARED_DEPOT=${SPINORBEC_TSUBAME_DEPOT:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
if [ -n "${T4_TMPDIR:-}" ] && [ -w "${T4_TMPDIR}" ]; then
    mkdir -p "$T4_TMPDIR/.julia"
    export JULIA_DEPOT_PATH="$T4_TMPDIR/.julia:$SHARED_DEPOT"
else
    export JULIA_DEPOT_PATH="$SHARED_DEPOT"
fi
JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

export SBEC_KZ_BACKEND=gpu
export SPINORBEC_FIGS_ROOT="$OUT_DIR"
echo "[sbec_kz] host=$(hostname)  mode=${MODE}  OUT_DIR=$OUT_DIR"
echo "[sbec_kz] HEAD=$(git rev-parse --short HEAD)  $(git log -1 --format=%s)"
git status --porcelain | head -20

set +e
"$JULIA" --project=. docs/guides/figures/eu_kz_exponent.jl "$MODE" \
    > "$OUT_DIR/kz_${MODE}.out" 2>&1
status=$?
set -e
tail -40 "$OUT_DIR/kz_${MODE}.out"
if [ $status -eq 0 ]; then echo "[sbec_kz] PASS"; else
    echo "[sbec_kz] FAIL exit=$status"
    [ $status -eq 137 ] && echo "[sbec_kz] 137 = SIGKILL, likely OOM"
fi
exit $status
