#!/bin/bash
# TSUBAME (UGE) array submit for the static-trap ω_eff scan of the EdH quench.
#
# WHAT THIS SETTLES
#
# `docs/campaign/claims.toml` carries `edh-5p2nt-dip-is-a-resonance` as
# status=suggested with a prediction REGISTERED BEFORE the measurement:
#
#     "If the dip is a resonance, its ω_eff position must move again at
#      B = 10.4 nT. If it does not move, the resonance reading is wrong."
#
# At 2.6 nT the ω_eff curve is a clean single peak; at 5.2 nT a dip appears at
# ω_eff ≈ 0.65 that survives 64³ with 93 % of its depth. Two fields is not a
# trend. This job runs the third.
#
# It also re-runs the 5.2 nT grid from committed configs. PR #403 landed two
# documents and no configs, so that scan's evidence reads `absent` in the ledger
# — re-deriving it was a re-derivation, not a re-run. These arms fix that class
# going forward.
#
# ONE ARM PER TASK, deliberately. A shard that dies on walltime must not take
# completed neighbours with it, and classification is a separate step that reads
# whatever landed — the 2026-08-20 lesson that a killed shard never reads its own
# completed work.
#
# Submit (from the TSUBAME worktree root):
#   qsub -g tga-kozuma-kouhi -t 1-40 scripts/submit_klaus_weff_scan.sh
# Smoke first (one arm, short wall):
#   qsub -g tga-kozuma-kouhi -t 13-13 -l h_rt=0:20:00 -v WEFF_SMOKE=1 \
#        scripts/submit_klaus_weff_scan.sh
#
#$ -cwd
#$ -N klaus_weff
#$ -l cpu_16=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o logs/tsubame/klaus_weff.$TASK_ID.log
set -euo pipefail

REPO="${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation}"
cd "$REPO"
mkdir -p logs/tsubame

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
JULIA="${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}"

source scripts/tsubame_setup.sh
# Re-arm unconditionally. `tsubame_setup.sh` now restores errexit itself, but a
# submit script must not depend on the internals of a file it sources — that
# dependency is what let a failed arm print "done" for twelve days.
set -euo pipefail

# TASK INDEX -> CONFIG. A positional index over a directory listing is only
# stable while the directory is. Adding six arms on 2026-08-21 shifted every
# index, and a requeued job read the list ~13 s before the checkout was synced --
# had the order been reversed it would have run a DIFFERENT config and written it
# to a log named for the old one, silently. So: prefer an explicit manifest, a
# file of config paths that a submission pins at qsub time and that git records.
# The glob remains the default for a full sweep, where the whole set is the point.
CFG_DIR="${WEFF_CFG_DIR:-runs/klaus_quench_weff}"
if [ -n "${WEFF_MANIFEST:-}" ]; then
    [ -f "$WEFF_MANIFEST" ] || { echo "FATAL: manifest not found: $WEFF_MANIFEST" >&2; exit 1; }
    # Plain bash, no regex: the first version of this line was written through
    # two layers of quoting, the escape collapsed, and every COMMENT line was
    # read as a config path -- "14 arms" for a six-arm manifest, and task 1 tried
    # to open a sentence. A filter that can be mis-escaped will be.
    CFGS=()
    while IFS= read -r _line || [ -n "$_line" ]; do
        _line="${_line%%#*}"
        _line="$(echo "$_line" | tr -d '[:space:]')"
        [ -n "$_line" ] && CFGS+=("$_line")
    done < "$WEFF_MANIFEST"
    # Every entry must resolve NOW. A manifest naming a file that is not there is
    # a typo or an unsynced checkout, and both are cheaper to find here than after
    # the scheduler has handed out task numbers.
    _missing=0
    for _c in "${CFGS[@]}"; do
        [ -f "$_c" ] || { echo "FATAL: manifest entry does not exist: $_c" >&2; _missing=1; }
    done
    [ "$_missing" -eq 0 ] || exit 1
    echo "manifest: $WEFF_MANIFEST (${#CFGS[@]} arms, all resolve)"
else
    mapfile -t CFGS < <(ls "$CFG_DIR"/*.yaml | sort)
fi
N=${#CFGS[@]}
if [ "$N" -eq 0 ]; then
    echo "FATAL: no configs under $CFG_DIR" >&2
    exit 1
fi

IDX="${SGE_TASK_ID:-1}"
if [ "$IDX" -gt "$N" ]; then
    echo "FATAL: task $IDX exceeds $N configs — the -t range and the config count disagree." >&2
    exit 1
fi
CFG="${CFGS[$((IDX - 1))]}"

echo "[$(date +%H:%M:%S)] task $IDX/$N  ->  $CFG"

# WALLTIME SELF-STOP — reusing the interrupt path that already exists.
#
# A run reaped at h_rt writes nothing and reports nothing. `run_loops.jl` already
# handles this correctly for Ctrl-C: it catches InterruptException, sets
# `interrupted[] = true` BEFORE saving (so a failure inside the snapshot cannot
# leave the run looking complete), trims the traces, saves a final snapshot, and
# `run_step_dynamics.jl` records `:interrupted`. That path is tested.
#
# So the implementation is not new code. It is sending ourselves SIGINT before the
# scheduler sends SIGKILL: `timeout --signal=INT` at 85 % of h_rt, then
# --kill-after as a backstop if the interrupt lands inside a long ccall and the
# process does not unwind.
#
# An earlier version of this block exported SPINORBEC_WALLTIME_BUDGET_S and
# claimed the same behaviour. Nothing in src/ read that variable; the export was a
# no-op and the claim was repeated in a commit message and upward twice.
WALL_S="${WALL_S:-7200}"                       # must match -l h_rt
BUDGET_S=$(( WALL_S * 85 / 100 ))
echo "walltime: h_rt=${WALL_S}s, self-interrupt at ${BUDGET_S}s"

# JOB-LAYER RECORD. Written before the run and completed after, so a task that
# never comes back is distinguishable from one that finished: absence of the
# `finished` line IS the signal. `qacct` has this too, but only until it is
# rotated, and only for someone who knows the job id.
JOBREC="logs/tsubame/jobrec.${JOB_ID:-local}.${SGE_TASK_ID:-1}.tsv"
printf "started\t%s\tjob=%s\ttask=%s\thost=%s\tcfg=%s\n" \
    "$(date -Is)" "${JOB_ID:-none}" "${SGE_TASK_ID:-1}" "$(hostname)" "$CFG" >> "$JOBREC"

if [ "${WEFF_SMOKE:-0}" = "1" ]; then
    echo "SMOKE: rendering every code path with a truncated ITP, not a result."
    export SPINORBEC_SMOKE=1
fi

set +e
timeout --signal=INT --kill-after=120 "$BUDGET_S" \
    "$JULIA" --project=. -e '
    using SpinorBEC
    cfg = ARGS[1]
    # Pre-flight before the expensive part: the inspector is the thing that
    # catches a feature_incompat (rotating_frame_omega + spinor + GPU crashed
    # historically) BEFORE two hours of walltime, not after.
    r = inspect_config(cfg)
    for w in r.warnings
        println("inspect[", w.severity, "] ", w.title)
    end
    # READ THE FIELD. The first version of this line matched the substring
    # "block" against the printed struct, and every arm died on the q-auto-derive
    # INFO message, whose text is "Step 1 has no `q:` in its B BLOCK". A severity
    # is a field (`:error | :warn | :info`); `:block` is the registration
    # level used by the autopilot pre-flight and is not a ConfigWarning value at all.
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

# Distinguish the three outcomes rather than printing one word for all of them.
# `timeout` reports 124 when it fired, and the run has saved a partial and marked
# it interrupted; 137 means --kill-after had to escalate, which means the
# interrupt did not unwind and there IS no partial.
case "$RC" in
    0)   OUTCOME="completed" ;;
    124) OUTCOME="self_interrupted_at_budget" ;;
    137) OUTCOME="killed_after_interrupt_ignored" ;;
    *)   OUTCOME="failed_rc_$RC" ;;
esac
printf "finished\t%s\trc=%s\toutcome=%s\tcfg=%s\n" \
    "$(date -Is)" "$RC" "$OUTCOME" "$CFG" >> "$JOBREC"
echo "[$(date +%H:%M:%S)] task $IDX $OUTCOME (rc=$RC): $CFG"
[ "$RC" -eq 0 ] || [ "$RC" -eq 124 ] || exit "$RC"
