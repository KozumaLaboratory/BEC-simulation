#!/bin/bash
# TSUBAME (UGE) submit: render EVERY code path of the #334 campaign in one short
# job, before any multi-hour launch. CPU success does not imply GPU works, and
# the campaign's own drivers are what is under test here, not the physics.
#
#   qsub -g tga-kozuma-kouhi -N eu334_smoke -l h_rt=2:00:00 \
#     scripts/eu334/submit_smoke.sh
#
# Paths covered: the window table; a bifurcation walk anchored from a FILE and
# from an ITP state; its resume; a refinement walk anchored on a coarse cell with
# the upsample; one SPGPE trajectory with noise and one quiet; the classifier's
# calibration; a classification of a real endpoint. Two NEGATIVE controls close
# it — a C region that does not fit the grid must be REFUSED, and a classifier
# whose branch table is missing must refuse rather than default.
#
# Each stage's status is checked individually: a job that only checks its last
# command reports the health of its final `echo`.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o logs/tsubame/
source "${EU334_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu334}/scripts/eu334/_preamble.sh"

SM="$EU334_OUT/smoke"
rm -rf "$SM"; mkdir -p "$SM"

fails=0
stage() {
    local name="$1"; shift
    echo; echo "───── STAGE $name ─────"
    if "$@"; then echo "STAGE $name OK"; else echo "STAGE $name FAILED (rc=$?)"; fails=$((fails+1)); fi
}
expect_fail() {
    local name="$1" want="$2"; shift 2
    echo; echo "───── STAGE $name (expects refusal) ─────"
    if "$@" > "$SM/$name.log" 2>&1; then
        echo "STAGE $name FAILED: it was accepted"; fails=$((fails+1))
    elif grep -q "$want" "$SM/$name.log"; then
        echo "STAGE $name OK (refused for the right reason)"
    else
        echo "STAGE $name FAILED: refused, but not by the guard under test:"
        tail -20 "$SM/$name.log"; fails=$((fails+1))
    fi
}

# 1. the window table — the measurement every design decision rests on
stage window env EW_SEEDS=$EU334_SEEDS EW_OUT=$SM/window \
    "$JULIA" --project=. scripts/eu334/window.jl

# 2. bifurcation walk, anchored from the #335 reference files
stage bifurcation env NB_SMOKE=1 NB_SEEDS=$EU334_SEEDS NB_OUT=$SM/bif \
    "$JULIA" --project=. scripts/eu334/nucleation_bifurcation.jl

# 3. the same walk again — the per-cell files must be rewritten without error
stage bifurcation_rerun env NB_SMOKE=1 NB_SEEDS=$EU334_SEEDS NB_OUT=$SM/bif \
    "$JULIA" --project=. scripts/eu334/nucleation_bifurcation.jl

# 4. refinement walk on a FINER grid anchored on a coarse cell — the upsample
#    path. The SMOKE f ladder is [0.02, 0.0737, 0.2714, 1.0], so these two cells
#    are the ones stage 2 wrote.
stage bifurcation_upsample env NB_SMOKE=1 NB_GRID=64 NB_FMIN=0.0737 NB_FMAX=0.2714 \
    NB_SEEDS=$EU334_SEEDS NB_OUT=$SM/bif64 \
    NB_ANCHOR_FLOWER=$SM/bif/flower_down_f0.2714.jld2 \
    NB_ANCHOR_POLAR=$SM/bif/polar_up_f0.0737.jld2 \
    "$JULIA" --project=. scripts/eu334/nucleation_bifurcation.jl

# 5. one SPGPE trajectory, and the same trajectory quiet (the T→0 control's path).
#    µ has to stay inside the 32³ C region for a smoke to run at all — which is
#    itself the measurement stage 1 makes, so the numbers here are deliberately
#    the small-f ones and NOT the production point.
NUSMOKE="NU_SMOKE=1 NU_GRID=32 NU_T=0.5 NU_MU1=6.0 NU_TAU_MS=2"
stage nucleate env $NUSMOKE NU_SEED=1 \
    NU_SEED_FILE=$SM/bif/polar_up_f0.0737.jld2 NU_OUT=$SM/nucleate \
    "$JULIA" --project=. scripts/eu334/nucleate.jl
stage nucleate_quiet env $NUSMOKE NU_SEED=1 NU_NOISE=0 \
    NU_SEED_FILE=$SM/bif/polar_up_f0.0737.jld2 NU_OUT=$SM/nucleate \
    "$JULIA" --project=. scripts/eu334/nucleate.jl

# 6. the classifier's own calibration, then a real endpoint
stage classify_calibrate env CL_CALIBRATE=1 CL_GRID=32 CL_BIF=$SM/bif \
    CL_LBFGS=60 CL_F=0.2714 CL_OUT=$SM/classify \
    "$JULIA" --project=. scripts/eu334/classify.jl
stage classify env CL_GRID=32 CL_BIF=$SM/bif CL_LBFGS=60 CL_OUT=$SM/classify \
    CL_PSI=$SM/nucleate/psi_k1.8_T0.5_tau2_seed001.jld2 \
    "$JULIA" --project=. scripts/eu334/classify.jl

# 7. NEGATIVE: a C region that does not fit the grid must be refused, not clipped.
#    This is the guard the whole design rests on — µ = 14.9 puts k_cut above the
#    32³ grid's k_max, and a run that quietly clipped it would report a
#    grid-dependent number as a physical one.
expect_fail c_region_refused "C region does not fit" env \
    NU_SMOKE=1 NU_GRID=32 NU_T=1.0 NU_MU1=14.9 NU_TAU_MS=2 \
    NU_SEED_FILE=$SM/bif/polar_up_f0.0737.jld2 NU_OUT=$SM/nucleate_guard \
    "$JULIA" --project=. scripts/eu334/nucleate.jl

# 8. NEGATIVE: no branch table ⇒ no classification. A classifier that defaulted
#    to the f = 1 references when the table is missing would silently compare a
#    lagging endpoint against the wrong branch energies.
expect_fail classify_needs_table "missing" env \
    CL_GRID=32 CL_BIF=$SM/no_such_dir CL_OUT=$SM/classify \
    CL_PSI=$SM/nucleate/psi_k1.8_T0.5_tau2_seed001.jld2 \
    "$JULIA" --project=. scripts/eu334/classify.jl

echo
echo "=== smoke summary: $fails failed stage(s) ==="
[ "$fails" -eq 0 ] || exit 1
echo "ALL STAGES GREEN $(date)"
