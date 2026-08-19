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
# Temperatures both fit the 64³ C region over the whole ramp (k_max/k_cut = 1.45
# and 1.27 at the top of the window) and bracket the selection scale: the two
# branches are within ~8 k_BT of each other at the bifurcation at T = 10 and
# within ~16 at T = 5, so if a thermal fluctuation can choose at all, it can here.
TEMPS=${TEMPS:-"5.0 10.0"}
# Traversal times around the reservoir-limited growth time, which is what the
# experiment's evaporation rate maps onto: 1/(γµ) is ~1 s at T = 5 and ~0.65 s at
# T = 10, and the window is 0.6 e-foldings of N₀ wide. So 500 ms is roughly
# matched and the other two bracket it by 3×.
TAUS=${TAUS:-"150 500 1500"}
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
    # κ = 0.9 has its own converged f = 1 seed; the #335 references are κ = 1.8
    # states and anchoring on one here would start the walk off its own branch.
    SEEDS=${EU334_SEEDS:-/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu335/seeds}
    q -N nb09_32 -l h_rt=12:00:00 \
      -v NB_KAPPA=0.9,NB_GRID=32,NB_FMIN=0.02,NB_FMAX=1.0,NB_NF=25,NB_ANCHOR_FLOWER=$SEEDS/flower_k0.9_B020_g32.jld2,NB_OUT=$OUT/bifurcation_k0.9_g32 \
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
    SEEDCELL=${2:?SEED_CELL required — the 64³ polarised cell BELOW the bifurcation}
    ENDCELL=${3:?END_CELL required — the 64³ cell the growth should end at}
    for f in "$SEEDCELL" "$ENDCELL"; do
        [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
    done
    for T in $TEMPS; do
        for TAU in $TAUS; do
            q -N nu_T${T}_t${TAU} -l h_rt=24:00:00 \
              -v NU_KAPPA=1.8,NU_GRID=64,NU_T=$T,NU_TAU_MS=$TAU,NU_SEEDS_N=$NSEED,NU_SEED_FILE=$SEEDCELL,NU_MU1_FROM=$ENDCELL,NU_OUT=$OUT/nucleate_k1.8_T${T}_tau${TAU} \
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
    ENDCELL=${3:?END_CELL required}
    # Two quiet arms, one from EACH branch. From the polarised seed the growth
    # must stay polarised; from a flower cell it must stay flower. One arm alone
    # cannot tell "the solver holds a branch" from "the solver always ends up
    # here", and that difference is the whole positive control.
    q -N nu_quiet_p -l h_rt=12:00:00 \
      -v NU_KAPPA=1.8,NU_GRID=64,NU_T=5.0,NU_TAU_MS=500,NU_NOISE=0,NU_SEEDS_N=1,NU_SEED_FILE=$SEEDCELL,NU_MU1_FROM=$ENDCELL,NU_OUT=$OUT/quiet_from_polar \
      scripts/eu334/submit_nucleate.sh
    FLOWERCELL=${4:-}
    if [ -n "$FLOWERCELL" ]; then
        q -N nu_quiet_f -l h_rt=12:00:00 \
          -v NU_KAPPA=1.8,NU_GRID=64,NU_T=5.0,NU_TAU_MS=500,NU_NOISE=0,NU_SEEDS_N=1,NU_SEED_FILE=$FLOWERCELL,NU_MU1_FROM=$ENDCELL,NU_OUT=$OUT/quiet_from_flower \
          scripts/eu334/submit_nucleate.sh
    else
        echo "note: the flower-seeded quiet arm needs a flower cell as argument 4"
    fi
    ;;

# The κ = 0.9 crossover control: #335 measured ONE branch there statically, so a
# selection statistic appearing here is the instrument, not the physics.
kappa09)
    SEED09=${2:?SEED_CELL required — a κ=0.9 cell below its own window}
    END09=${3:?END_CELL required}
    q -N nu_k09 -l h_rt=24:00:00 \
      -v NU_KAPPA=0.9,NU_GRID=64,NU_T=5.0,NU_TAU_MS=500,NU_SEEDS_N=$NSEED,NU_SEED_FILE=$SEED09,NU_MU1_FROM=$END09,NU_OUT=$OUT/nucleate_k0.9_T5.0_tau500 \
      scripts/eu334/submit_nucleate.sh
    ;;

*) echo "unknown stage '$1'" >&2; exit 64 ;;
esac
