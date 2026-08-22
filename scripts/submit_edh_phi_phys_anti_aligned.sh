#!/bin/bash
# TSUBAME (UGE) submit for #423 — eu151_klaus_phi_phys at PRODUCTION scale with
# the anti-aligned preparation.
#
# WHAT THIS SETTLES
#
# `prepare_anti_aligned` landed in #421 and the MECHANISM is verified at the
# production field (F=6, p=26700, dt=0.005, 12x12x8): aligned relaxes to
# <F_z> = +6, anti-aligned to -6, and the two energies agree to every digit
# (-160174.95). That agreement is the check, not a coincidence: p -> -p is a
# pi rotation about x, so a correct reversal is unitarily equivalent and MUST
# land on the same energy. A discrepancy would mean the reversal is buggy.
#
# What has never run is the PIPELINE-SCALE version. `runs/eu151_klaus_phi_phys/
# config.yaml` carries `prepare_anti_aligned: true` but was never re-run, so
# every 151Eu number in
# `docs/campaign/edh_quench_polarisation_decision.md` sections 3 and 4 is from
# the ALIGNED preparation. Those are two different physical states, not an old
# and a new value, so the anti-aligned numbers go BESIDE them.
#
# ONE JOB, NOT AN ARRAY, and that is forced rather than chosen: `run_yaml` has
# no point selection (there is no `--only-point`), so the 8-point `scan:` block
# is indivisible from the outside. What makes that safe is that `run_yaml` IS
# resumable — it skips any scan point whose `point_*.jld2` already exists — so a
# task reaped at h_rt costs only the point it was inside. Requeue to continue.
#
# Submit (from the TSUBAME worktree root):
#   qsub -g tga-kozuma-kouhi scripts/submit_edh_phi_phys_anti_aligned.sh
# Smoke first (proves config + GPU + the anti-aligned assertion, then dies):
#   qsub -g tga-kozuma-kouhi -l h_rt=0:30:00 -v PHI_SMOKE=1 \
#        scripts/submit_edh_phi_phys_anti_aligned.sh
#
# A SMOKE HERE PROVES LESS THAN IT LOOKS LIKE. There is no `--smoke` flag and
# `SPINORBEC_SMOKE` is read by nothing in `src/` (checked 2026-08-22 — it is
# exported by one sibling submit script and consumed nowhere, the same dead-knob
# shape as the `SPINORBEC_WALLTIME_BUDGET_S` export that claimed a behaviour
# nothing implemented). So the smoke is a SHORT WALLTIME and what it establishes
# is bounded: the config inspects clean, the GPU is acquired, the ground state
# converges, and the runtime anti-aligned assertion passes. It does NOT
# establish that an arm completes.
#
#$ -cwd
#$ -N edh_phi_aa
#$ -l gpu_1=1
#$ -l h_rt=24:00:00
#$ -j y
#$ -o logs/tsubame/edh_phi_aa.$JOB_ID.log
set -euo pipefail

REPO="${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation}"
cd "$REPO"
mkdir -p logs/tsubame

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
JULIA="${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}"

source scripts/tsubame_setup.sh
# Re-arm unconditionally. `tsubame_setup.sh` restores errexit itself now, but a
# submit script must not depend on the internals of a file it sources — that
# dependency is what let a failed arm print "done" for twelve days.
set -euo pipefail

CFG="${PHI_CFG:-runs/eu151_klaus_phi_phys/config.yaml}"
[ -f "$CFG" ] || { echo "FATAL: config not found: $CFG" >&2; exit 1; }

# The config must actually carry the preparation this job exists to exercise.
# Asserting it here rather than trusting the checkout: a tree synced before #421
# would run the ALIGNED arm and write it to a log named for the anti-aligned one.
grep -q "prepare_anti_aligned: true" "$CFG" || {
    echo "FATAL: $CFG does not set 'prepare_anti_aligned: true' — this job would" >&2
    echo "       silently produce a second copy of the aligned numbers." >&2
    exit 1
}
echo "config: $CFG (prepare_anti_aligned: true confirmed)"

WALL_S="${WALL_S:-86400}"                      # must match -l h_rt
BUDGET_S=$(( WALL_S * 85 / 100 ))
echo "walltime: h_rt=${WALL_S}s, self-interrupt at ${BUDGET_S}s"

JOBREC="logs/tsubame/jobrec.${JOB_ID:-local}.phi_aa.tsv"
printf "started\t%s\tjob=%s\thost=%s\tcfg=%s\n" \
    "$(date -Is)" "${JOB_ID:-none}" "$(hostname)" "$CFG" >> "$JOBREC"

if [ "${PHI_SMOKE:-0}" = "1" ]; then
    echo "SMOKE: short walltime. Establishes config+GPU+GS+anti-aligned assertion ONLY."
fi

set +e
timeout --signal=INT --kill-after=120 "$BUDGET_S" \
    "$JULIA" --project=. -e '
    import CUDA          # BEFORE `using SpinorBEC` — loads the CUDA extension
    using SpinorBEC
    cfg = ARGS[1]
    # Pre-flight before the expensive part. Read the FIELD, not the printed
    # struct: `:block` is an autopilot registration level and is not a
    # ConfigWarning severity at all, and substring-matching "block" against the
    # struct killed every arm of a sibling scan on the q-auto-derive INFO
    # message, whose text contains "B BLOCK".
    r = inspect_config(cfg)
    for w in r.warnings
        println("inspect[", w.severity, "] ", w.title)
    end
    blockers = filter(w -> w.severity === :error, r.warnings)
    if !isempty(blockers)
        for w in blockers
            println("BLOCKING: ", w.title, " — ", w.message)
        end
        error("pre-flight found $(length(blockers)) :error warning(s) — refusing to launch")
    end
    run_yaml(cfg)
' "$CFG"

RC=$?
set -e

case "$RC" in
    0)   OUTCOME="completed" ;;
    124) OUTCOME="self_interrupted_at_budget" ;;
    137) OUTCOME="killed_after_interrupt_ignored" ;;
    *)   OUTCOME="failed_rc_$RC" ;;
esac
printf "finished\t%s\trc=%s\toutcome=%s\tcfg=%s\n" \
    "$(date -Is)" "$RC" "$OUTCOME" "$CFG" >> "$JOBREC"
echo "[$(date +%H:%M:%S)] $OUTCOME (rc=$RC): $CFG"
[ "$RC" -eq 0 ] || [ "$RC" -eq 124 ] || exit "$RC"
