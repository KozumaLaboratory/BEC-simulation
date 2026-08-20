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

CFG_DIR="${WEFF_CFG_DIR:-runs/klaus_quench_weff}"
mapfile -t CFGS < <(ls "$CFG_DIR"/*.yaml | sort)
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

# Self-stop before the scheduler kills us. A run reaped at h_rt writes nothing
# and reports nothing; one that stops itself at 85 % leaves a readable partial
# and a reason. `h_rt` is 2 h here, so the budget is 6120 s.
export SPINORBEC_WALLTIME_BUDGET_S="${SPINORBEC_WALLTIME_BUDGET_S:-6120}"

if [ "${WEFF_SMOKE:-0}" = "1" ]; then
    echo "SMOKE: rendering every code path with a truncated ITP, not a result."
    export SPINORBEC_SMOKE=1
fi

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

echo "[$(date +%H:%M:%S)] task $IDX done: $CFG"
