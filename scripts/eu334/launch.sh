#!/bin/bash
# Submit one stage of the #334 campaign. Run ON the TSUBAME login node, from the
# campaign tree. The exact submissions live here rather than in a session
# transcript, so a stage can be re-run or extended without reconstructing its
# environment from a log.
#
#   bash scripts/eu334/launch.sh smoke
#   bash scripts/eu334/launch.sh bifurcation          # stage A: f-walks at 32³
#   bash scripts/eu334/launch.sh window <F_LO> <F_HI> # stage B: refine at 64³
#   bash scripts/eu334/launch.sh ensemble <SEED_CELL> # stage C: (T, rate) × seeds
#   bash scripts/eu334/launch.sh control <SEED_CELL>  # stage D: quiet + κ=0.9
#
# The f window for stage B is an ARGUMENT, not a default: it is read off stage A's
# measured bifurcation and choosing it is a decision someone made against data.
# A window that does not contain the bifurcation produces a bound, which is the
# defect #335 existed to remove and it is not repeated here.
set -euo pipefail

G=tga-kozuma-kouhi
ROOT=${EU334_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu334}
OUT=${EU334_OUT:-/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu334}
cd "$ROOT"
mkdir -p logs/tsubame "$OUT"

# Semicolons, NOT commas: `qsub -v` separates VARIABLES with commas, so a
# comma-joined list arrives as its first element only.
TEMPS=${TEMPS:-"2.0 5.0"}
TAUS=${TAUS:-"50 200 800"}
NSEED=${NSEED:-20}

q() { echo "+ qsub $*"; qsub -g "$G" "$@"; }

case "${1:?stage required}" in

smoke)
    q -N eu334_smoke -l h_rt=2:00:00 scripts/eu334/submit_smoke.sh
    ;;

# Stage A. Both branches walked over a decade and a half in condensate fraction
# at the library grid. Cheap (~1 min/cell) and it is what locates the window
# every later stage is defined against.
bifurcation)
    q -N nb18_32 -l h_rt=12:00:00 \
      -v NB_KAPPA=1.8,NB_GRID=32,NB_FMIN=0.02,NB_FMAX=1.0,NB_NF=25,NB_OUT=$OUT/bifurcation_k1.8_g32 \
      scripts/eu334/submit_bifurcation.sh
    q -N nb09_32 -l h_rt=12:00:00 \
      -v NB_KAPPA=0.9,NB_GRID=32,NB_FMIN=0.02,NB_FMAX=1.0,NB_NF=25,NB_OUT=$OUT/bifurcation_k0.9_g32 \
      scripts/eu334/submit_bifurcation.sh
    ;;

# Stage B. The same walk at the grid a trajectory can actually run on, over the
# window stage A found. 64³ is the coarsest grid whose k_max clears µ + T; the
# anchors are stage A's own cells, upsampled.
window)
    LO=${2:?F_LO required — from the measured bifurcation in stage A}
    HI=${3:?F_HI required}
    AF=$(printf "$OUT/bifurcation_k1.8_g32/flower_down_f%06.4f.jld2" "$HI")
    AP=$(printf "$OUT/bifurcation_k1.8_g32/polar_up_f%06.4f.jld2" "$LO")
    for f in "$AF" "$AP"; do
        [ -f "$f" ] || { echo "missing stage-A anchor $f" >&2; exit 1; }
    done
    q -N nb18_64 -l h_rt=24:00:00 \
      -v NB_KAPPA=1.8,NB_GRID=64,NB_FMIN=$LO,NB_FMAX=$HI,NB_NF=13,NB_LBFGS=600,NB_ANCHOR_FLOWER=$AF,NB_ANCHOR_POLAR=$AP,NB_OUT=$OUT/bifurcation_k1.8_g64 \
      scripts/eu334/submit_bifurcation.sh
    ;;

# Stage C. One job per (T, τ) cell, every seed inside it. The cell is the unit
# the binomial error is quoted over.
ensemble)
    SEEDCELL=${2:?SEED_CELL required — the 64³ polarised cell below the bifurcation}
    [ -f "$SEEDCELL" ] || { echo "missing $SEEDCELL" >&2; exit 1; }
    for T in $TEMPS; do
        for TAU in $TAUS; do
            q -N nu_T${T}_t${TAU} -l h_rt=24:00:00 \
              -v NU_KAPPA=1.8,NU_GRID=64,NU_T=$T,NU_TAU_MS=$TAU,NU_SEEDS_N=$NSEED,NU_SEED_FILE=$SEEDCELL,NU_OUT=$OUT/nucleate_k1.8_T${T}_tau${TAU} \
              scripts/eu334/submit_nucleate.sh
        done
    done
    ;;

# Stage D. The two controls, and they are not optional.
#   quiet   — noise off at the same (µ, τ): the growth must track the branch it
#             started on. A solver that cannot hold a branch without noise cannot
#             be read for a selection statistic.
#   kappa09 — the crossover side, where #335 measured ONE branch statically. If a
#             selection statistic appears there, it is the solver being measured.
control)
    SEEDCELL=${2:?SEED_CELL required}
    q -N nu_quiet -l h_rt=12:00:00 \
      -v NU_KAPPA=1.8,NU_GRID=64,NU_T=2.0,NU_TAU_MS=200,NU_NOISE=0,NU_SEEDS_N=2,NU_SEED_FILE=$SEEDCELL,NU_OUT=$OUT/nucleate_quiet \
      scripts/eu334/submit_nucleate.sh
    SEED09=${3:-}
    if [ -n "$SEED09" ]; then
        q -N nu_k09 -l h_rt=24:00:00 \
          -v NU_KAPPA=0.9,NU_GRID=64,NU_T=2.0,NU_TAU_MS=200,NU_SEEDS_N=$NSEED,NU_SEED_FILE=$SEED09,NU_OUT=$OUT/nucleate_k0.9_T2.0_tau200 \
          scripts/eu334/submit_nucleate.sh
    else
        echo "note: κ=0.9 arm not submitted — pass its seed cell as the 3rd argument"
    fi
    ;;

*) echo "unknown stage '$1'" >&2; exit 64 ;;
esac
