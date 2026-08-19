#!/bin/bash
# TSUBAME (UGE) submit: render EVERY code path of the #335 campaign in one short
# job, before any multi-hour launch. CPU success does not imply GPU works, and
# the campaign's own drivers are the thing under test here, not the physics.
#
#   qsub -g tga-kozuma-kouhi -N eu335_smoke -l h_rt=1:00:00 \
#     scripts/eu_hysteresis/submit_smoke.sh
#
# Paths covered: branch continuation anchored from a FILE (with upsample skipped)
# and from an ITP state; ramp seeded from a file on both legs; the τ-indexed and
# the rate-indexed scan; the arm-resume skip. Each stage's exit status is checked
# individually — a job that only checks its last command reports the health of
# its final `echo`.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=1:00:00
#$ -j y
#$ -o logs/tsubame/
# UGE copies the job script into a spool directory, so `dirname $0` is NOT the
# repo and `-cwd` does not help — it sets the working directory, not $0. Source
# by absolute path.
source "${EU335_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu335}/scripts/eu_hysteresis/_preamble.sh"

SEEDS=/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu335/seeds
SM="$EU335_OUT/smoke"
rm -rf "$SM"; mkdir -p "$SM"

fails=0
stage() {
    local name="$1"; shift
    echo; echo "───── STAGE $name ─────"
    if "$@"; then echo "STAGE $name OK"; else echo "STAGE $name FAILED (rc=$?)"; fails=$((fails+1)); fi
}

jl() { "$JULIA" --project=. "$@"; }

# 1. branch continuation, anchor from a file (the production path for stage A)
stage branch_from_file env \
    HB_SMOKE=1 HB_KAPPA=1.8 HB_DIR=up HB_BMIN=20 HB_DB=5 HB_PIN=0.002 \
    HB_ANCHOR_FILE=$SEEDS/reference_flower.jld2 HB_OUT=$SM/branch_file \
    "$JULIA" --project=. scripts/eu_hysteresis/branch_continuation.jl

# 2. same, resumed — must SKIP every cell it already wrote
stage branch_resume env \
    HB_SMOKE=1 HB_KAPPA=1.8 HB_DIR=up HB_BMIN=20 HB_DB=5 HB_PIN=0.002 \
    HB_ANCHOR_FILE=$SEEDS/reference_flower.jld2 HB_OUT=$SM/branch_file \
    "$JULIA" --project=. scripts/eu_hysteresis/branch_continuation.jl

# 3. branch continuation, anchor from an ITP state (the polarised branch's top)
stage branch_from_itp env \
    HB_SMOKE=1 HB_KAPPA=1.8 HB_DIR=down HB_BMAX=200 HB_DB=5 HB_PIN=0.002 \
    HB_ANCHOR_STATE=m_minus_F HB_OUT=$SM/branch_itp \
    "$JULIA" --project=. scripts/eu_hysteresis/branch_continuation.jl

# 4. ramp, rise leg from a seed file, τ-indexed
stage ramp_rise_tau env \
    AR_SMOKE=1 AR_KAPPA=1.8 AR_LEGS=rise AR_B_LO=20 AR_B_HI=30 \
    AR_SEED_RISE_FILE=$SEEDS/reference_flower.jld2 AR_OUT=$SM/ramp_rise \
    "$JULIA" --project=. scripts/eu_adiabatic_ramp_protocol.jl

# 5. ramp, fall leg from a seed file
stage ramp_fall_tau env \
    AR_SMOKE=1 AR_KAPPA=1.8 AR_LEGS=fall AR_B_LO=10 AR_B_HI=20 \
    AR_SEED_FALL_FILE=$SEEDS/reference_m_minus_F.jld2 AR_OUT=$SM/ramp_fall \
    "$JULIA" --project=. scripts/eu_adiabatic_ramp_protocol.jl

# 6. rate-indexed scan + the arm-resume path. AR_SMOKE forces the τ grid, so the
#    rate path needs a real (small) run: 2 rates × 1 leg at 32³ over 10 µG.
stage ramp_rate env \
    AR_KAPPA=1.8 AR_LEGS=rise AR_B_LO=20 AR_B_HI=30 AR_RATES=200,100 \
    AR_DT=0.004 AR_FRAMES=20 AR_SAVE_PSI=0 \
    AR_SEED_RISE_FILE=$SEEDS/reference_flower.jld2 AR_OUT=$SM/ramp_rate \
    "$JULIA" --project=. scripts/eu_adiabatic_ramp_protocol.jl
stage ramp_rate_resume env \
    AR_KAPPA=1.8 AR_LEGS=rise AR_B_LO=20 AR_B_HI=30 AR_RATES=200,100 \
    AR_DT=0.004 AR_FRAMES=20 AR_SAVE_PSI=0 \
    AR_SEED_RISE_FILE=$SEEDS/reference_flower.jld2 AR_OUT=$SM/ramp_rate \
    "$JULIA" --project=. scripts/eu_adiabatic_ramp_protocol.jl

# 7. NEGATIVE control: a seed at the wrong end of the window must be REFUSED.
#    Without this the smoke only proves the drivers run, not that the guard that
#    keeps both legs on one window can fire.
echo; echo "───── STAGE guard_wrong_seed_field (expects failure) ─────"
if env AR_KAPPA=1.8 AR_LEGS=fall AR_B_LO=20 AR_B_HI=200 \
       AR_SEED_FALL_FILE=$SEEDS/reference_m_minus_F.jld2 AR_OUT=$SM/ramp_guard \
       "$JULIA" --project=. scripts/eu_adiabatic_ramp_protocol.jl > "$SM/guard.log" 2>&1
then
    echo "STAGE guard_wrong_seed_field FAILED: a 20 µG seed was accepted for a leg that must start at 200 µG"
    fails=$((fails+1))
else
    grep -q "would not span one field window" "$SM/guard.log" \
        && echo "STAGE guard_wrong_seed_field OK (refused for the right reason)" \
        || { echo "STAGE guard_wrong_seed_field FAILED: refused, but not by the window guard:"; tail -20 "$SM/guard.log"; fails=$((fails+1)); }
fi

echo
echo "=== smoke summary: $fails failed stage(s) ==="
[ "$fails" -eq 0 ] || exit 1
echo "ALL STAGES GREEN $(date)"
