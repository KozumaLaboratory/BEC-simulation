#!/bin/bash
# Submit one stage of the #335 campaign. Run ON the TSUBAME login node, from the
# campaign worktree. The exact submissions live here rather than in a session
# transcript, so a stage can be re-run or extended without reconstructing its
# environment from a log.
#
#   bash scripts/eu_hysteresis/launch.sh smoke
#   bash scripts/eu_hysteresis/launch.sh branches18      # stage A: κ=1.8 both branches
#   bash scripts/eu_hysteresis/launch.sh branches09      # stage A: κ=0.9 both branches
#   bash scripts/eu_hysteresis/launch.sh ramps  <B_TOP>  # stage B/C: 2 κ × 2 legs
#   bash scripts/eu_hysteresis/launch.sh grid64 <B_TOP>  # stage D
#   bash scripts/eu_hysteresis/launch.sh pin    <B_TOP>  # stage E: shielding axis
#
# B_TOP is the top of the common field window, chosen from stage A: a little above
# the measured upper spinodal. It is an argument rather than a default because a
# window that does not contain both spinodals produces a lower bound, which is the
# defect the campaign exists to remove — so it must be a decision someone made
# against data, not a number that was already sitting in a script.
set -euo pipefail

G=tga-kozuma-kouhi
ROOT=${EU335_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu335}
OUT=${EU335_OUT:-/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu335}
SEEDS=$OUT/seeds
cd "$ROOT"
mkdir -p logs/tsubame "$OUT"

# 2.5 decades of ramp rate. τ = span / rate, so the two legs of one loop get the
# same field rate over the same window even though they run in opposite directions.
RATES=${RATES:-40,12,4,1.2,0.4,0.12}
PIN=${PIN:-0.002}

q() { echo "+ qsub $*"; qsub -g "$G" "$@"; }

case "${1:?stage required}" in

smoke)
    q -N eu335_smoke -l h_rt=2:00:00 scripts/eu_hysteresis/submit_smoke.sh
    ;;

# Stage A. Each branch is walked until it stops existing, which is what turns the
# open end into a measurement. BMAX=300 is deliberately past any plausible upper
# spinodal: cells beyond the collapse are stiff and cheap, and a scan that stops
# before the branch dies reproduces the bound it is meant to replace.
branches18)
    q -N hb18up -l h_rt=24:00:00 \
      -v HB_KAPPA=1.8,HB_DIR=up,HB_BMIN=20,HB_BMAX=300,HB_DB=5,HB_PIN=$PIN,HB_ANCHOR_FILE=$SEEDS/reference_flower.jld2,HB_OUT=$OUT/branch_k1.8_up_g32 \
      scripts/eu_hysteresis/submit_branch.sh
    q -N hb18dn -l h_rt=24:00:00 \
      -v HB_KAPPA=1.8,HB_DIR=down,HB_BMIN=5,HB_BMAX=300,HB_DB=5,HB_PIN=$PIN,HB_ANCHOR_STATE=m_minus_F,HB_OUT=$OUT/branch_k1.8_dn_g32 \
      scripts/eu_hysteresis/submit_branch.sh
    ;;

# The control's own seeds, and the static half of its verdict: at κ ≤ 0.9 the two
# continuations should MERGE onto one branch, which is what a crossover looks like
# statically and is checkable without any dynamics.
branches09)
    q -N hb09up -l h_rt=24:00:00 \
      -v HB_KAPPA=0.9,HB_DIR=up,HB_BMIN=20,HB_BMAX=300,HB_DB=5,HB_PIN=$PIN,HB_ANCHOR_STATE=flower,HB_OUT=$OUT/branch_k0.9_up_g32 \
      scripts/eu_hysteresis/submit_branch.sh
    q -N hb09dn -l h_rt=24:00:00 \
      -v HB_KAPPA=0.9,HB_DIR=down,HB_BMIN=5,HB_BMAX=300,HB_DB=5,HB_PIN=$PIN,HB_ANCHOR_STATE=m_minus_F,HB_OUT=$OUT/branch_k0.9_dn_g32 \
      scripts/eu_hysteresis/submit_branch.sh
    ;;

# Stages B and C. One job per (κ, leg): the arms are independent, and a 24 h wall
# clock holding both legs means a kill costs the loop instead of half of one side.
ramps)
    T=${2:?B_TOP required — the top of the common window, from stage A}
    for K in 1.8 0.9; do
        for LEG in rise fall; do
            SEEDVAR=AR_SEED_RISE_FILE; SEEDF=$SEEDS/flower_k${K}_B020_g32.jld2
            if [ "$LEG" = fall ]; then
                SEEDVAR=AR_SEED_FALL_FILE; SEEDF=$SEEDS/polar_k${K}_B${T}_g32.jld2
            fi
            [ -f "$SEEDF" ] || { echo "missing seed $SEEDF — extract it from stage A first" >&2; exit 1; }
            q -N ar${K/./}_$LEG -l h_rt=24:00:00 \
              -v AR_KAPPA=$K,AR_GRID=32,AR_LEGS=$LEG,AR_B_LO=20,AR_B_HI=$T,AR_RATES=$RATES,$SEEDVAR=$SEEDF,AR_OUT=$OUT/ramp_g32 \
              scripts/eu_hysteresis/submit_ramp.sh
        done
    done
    ;;

# Stage D. 64³ costs ~8× per step, so only the two slowest rates — the ones the
# verdict is read from — and only at κ=1.8. Seeds are upsampled from 32³ and
# re-polished by the branch driver's anchor path.
grid64)
    T=${2:?B_TOP required}
    q -N hb18up64 -l h_rt=24:00:00 \
      -v HB_KAPPA=1.8,HB_GRID=64,HB_DIR=up,HB_BMIN=20,HB_BMAX=20,HB_DB=5,HB_PIN=$PIN,HB_LBFGS=1200,HB_ANCHOR_FILE=$SEEDS/flower_k1.8_B020_g32.jld2,HB_OUT=$OUT/seed64_flower \
      scripts/eu_hysteresis/submit_branch.sh
    q -N hb18dn64 -l h_rt=24:00:00 \
      -v HB_KAPPA=1.8,HB_GRID=64,HB_DIR=down,HB_BMIN=$T,HB_BMAX=$T,HB_DB=5,HB_PIN=$PIN,HB_LBFGS=1200,HB_ANCHOR_FILE=$SEEDS/polar_k1.8_B${T}_g32.jld2,HB_OUT=$OUT/seed64_polar \
      scripts/eu_hysteresis/submit_branch.sh
    echo "when both 64³ seeds exist, submit the two legs with:"
    echo "  RATES=0.4,0.12 bash scripts/eu_hysteresis/launch.sh ramps64 $T"
    ;;

ramps64)
    T=${2:?B_TOP required}
    for LEG in rise fall; do
        SEEDVAR=AR_SEED_RISE_FILE; SEEDF=$SEEDS/flower_k1.8_B020_g64.jld2
        if [ "$LEG" = fall ]; then
            SEEDVAR=AR_SEED_FALL_FILE; SEEDF=$SEEDS/polar_k1.8_B${T}_g64.jld2
        fi
        [ -f "$SEEDF" ] || { echo "missing seed $SEEDF" >&2; exit 1; }
        q -N ar18_${LEG}64 -l h_rt=24:00:00 \
          -v AR_KAPPA=1.8,AR_GRID=64,AR_LEGS=$LEG,AR_B_LO=20,AR_B_HI=$T,AR_RATES=${RATES},$SEEDVAR=$SEEDF,AR_OUT=$OUT/ramp_g64 \
          scripts/eu_hysteresis/submit_ramp.sh
    done
    ;;

# Stage E. The shielding axis: a 10× pin is ~1.35 µG, the scale of a real residual
# transverse field. Needs its OWN seeds — a state converged at one ε is not
# stationary at another, so reusing them would measure that transient.
pin)
    T=${2:?B_TOP required}
    q -N hb18up_p02 -l h_rt=24:00:00 \
      -v HB_KAPPA=1.8,HB_DIR=up,HB_BMIN=20,HB_BMAX=20,HB_DB=5,HB_PIN=0.02,HB_LADDER=0.08,0.04,0.02,HB_LADDER_ANCHOR=0.08,0.04,0.02,HB_ANCHOR_FILE=$SEEDS/reference_flower.jld2,HB_OUT=$OUT/seedpin_flower \
      scripts/eu_hysteresis/submit_branch.sh
    q -N hb18dn_p02 -l h_rt=24:00:00 \
      -v HB_KAPPA=1.8,HB_DIR=down,HB_BMIN=$T,HB_BMAX=$T,HB_DB=5,HB_PIN=0.02,HB_LADDER=0.08,0.04,0.02,HB_LADDER_ANCHOR=0.08,0.04,0.02,HB_ANCHOR_STATE=m_minus_F,HB_OUT=$OUT/seedpin_polar \
      scripts/eu_hysteresis/submit_branch.sh
    ;;

*) echo "unknown stage '$1'" >&2; exit 64 ;;
esac
