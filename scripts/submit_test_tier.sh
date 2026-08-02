#!/bin/bash
# UGE submission: run a test tier on a TSUBAME GPU node.
#
#   qsub -g tga-kozuma-kouhi -o $HOME/runs/tests/uge.log \
#        -v SPINORBEC_TSUBAME_PROJECT_ROOT=<worktree>,SBEC_TIER=ci \
#        scripts/submit_test_tier.sh
#
# Why this exists: branch protection requires only `fast` + `oracles`, so a
# green PR says nothing about the `ci` tier — #140 landed red through exactly
# that gap. The tier has to be run somewhere before merging anything under
# solvers/ hamiltonian/ analysis/, and a laptop is the wrong somewhere: the
# suite is long enough to matter and the local box runs several sessions.
#
# GPU node on purpose — the `ci` tier contains GPU=CPU parity gates that silently
# no-op without CUDA, which is the same "the gate never ran" failure in a
# different costume.
#
# NB: the `-o` log only ever holds this wrapper's own echo lines. The suite's
# output goes to $OUT_DIR/tier_<tier>.out, and OUT_DIR follows
# SPINORBEC_TSUBAME_RUNS_ROOT, which scripts/spinorbec.env sets to
# /gs/fs/tga-kozuma-kouhi/uk07267/runs — NOT $HOME. Watching the -o log alone
# looks exactly like a job that has produced nothing for half an hour.
#
# NB: the tree must include `runs/`. Config-scanning gates
# (test_config_zeeman_seed_agreement.jl, test_lhy_config_validity_domain.jl) read
# it, and an rsync that syncs only src/ and test/ makes them error on ENOENT
# rather than skip — a red that is about the transfer, not the code.
#
# NB: -g and -o go on the qsub CLI, not as directives (UGE rejects `#$ -g` and
# does not expand $HOME in directives).
#$ -cwd
#$ -N sbec_tier
#$ -l gpu_h=1
#$ -l h_rt=4:00:00
#$ -j y

set -euo pipefail

PROJECT_ROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:?set SPINORBEC_TSUBAME_PROJECT_ROOT}
TIER=${SBEC_TIER:-ci}
# NOT `auto`. `auto` = one worker per core, and a TSUBAME node reports 384 of
# them; each worker is an independent julia process that loads SpinorBEC + CUDA
# (~1-2 GB), so `auto` asked for ~500 GB and the job was OOM-killed with nothing
# but "Killed" in the log. Memory, not cores, is the binding resource here.
WORKERS=${SBEC_WORKERS:-12}
OUT_DIR=${SPINORBEC_TSUBAME_RUNS_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/runs}/tests
mkdir -p "$OUT_DIR"
cd "$PROJECT_ROOT"

source scripts/tsubame_setup.sh
. /etc/profile.d/modules.sh
module load "${SPINORBEC_TSUBAME_CUDA_MODULE:-cuda/12.8.0}"

# Node-local depot first so precompile output never touches the group quota
# (which sits at ~994/1000 GB); shared depot second for the installed packages.
SHARED_DEPOT=${SPINORBEC_TSUBAME_DEPOT:-/gs/fs/tga-kozuma-kouhi/shared/.julia}
if [ -n "${T4_TMPDIR:-}" ] && [ -w "${T4_TMPDIR}" ]; then
    mkdir -p "$T4_TMPDIR/.julia"
    export JULIA_DEPOT_PATH="$T4_TMPDIR/.julia:$SHARED_DEPOT"
else
    export JULIA_DEPOT_PATH="$SHARED_DEPOT"
fi
# Pin BLAS to one thread. OpenBLAS sizes its level-1 thread team from the core
# count, and a TSUBAME node reports 384 of them, so every `dot` on a few-MB
# ComplexF64 array becomes spawn+barrier rather than arithmetic. Left unset, a
# ci-tier attempt ran `oracles/test_lhy_full_bdg_closed_form_parity.jl` for
# 18m52s against the 51.8s estimate in _tiers.jl (24s on cpu_4 with this pinned),
# a worker then hit the 1800s per-file timeout mid-`test_term_properties.jl`, and
# the suite aborted with 227 files never started — reporting FAIL while having
# measured almost nothing, which reads like a tier result and is not one. With
# the pin the same tier finishes 266 files in 11m20s.
#
# Not tuning: the workers already are the parallelism, so a BLAS team inside each
# one is pure contention. `${VAR:-1}` so an explicit caller choice still wins.
export OPENBLAS_NUM_THREADS=${OPENBLAS_NUM_THREADS:-1}
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}

JULIA=${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}

echo "[sbec_tier] host=$(hostname)  tier=${TIER}  workers=${WORKERS}"
echo "[sbec_tier] HEAD=$(git rev-parse --short HEAD)  $(git log -1 --format=%s)"
git status --porcelain | head -20

set +e
SPINORBEC_TEST_TIER="$TIER" SPINORBEC_TEST_WORKERS="$WORKERS" \
    "$JULIA" --project=. -e 'using Pkg; Pkg.test()' \
    > "$OUT_DIR/tier_${TIER}.out" 2>&1
status=$?
set -e
tail -40 "$OUT_DIR/tier_${TIER}.out"

# Say the verdict in the log. The first attempt was OOM-killed and the script
# still printed "done", because the failure was inside a pipeline and got lost;
# a test job that cannot report its own failure is worse than no test job.
if [ $status -eq 0 ]; then
    echo "[sbec_tier] PASS  (tier=${TIER})"
else
    echo "[sbec_tier] FAIL  (tier=${TIER}, exit=${status})"
    [ $status -eq 137 ] && echo "[sbec_tier] exit 137 = SIGKILL, almost certainly OOM — lower SBEC_WORKERS"
fi
exit $status
