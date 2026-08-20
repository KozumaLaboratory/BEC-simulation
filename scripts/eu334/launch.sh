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
# Ramp times bracketing the reservoir-limited growth time. The condensate grows at
# 2γ(µ_res − µ_ψ), which is ~1/3000 ms⁻¹ at T = 5, and the window is 0.8 e-foldings
# of N₀ wide — so a µ ramp FASTER than that does not make the field cross faster,
# it only raises the driving. τ = 4500 ms is quasi-static, 500 ms is drive-limited,
# 1500 ms is between.
TAUS=${TAUS:-"400 1300 4000"}
# Every arm runs to the SAME total duration, holding at µ₁ after its ramp, so all
# of them end at the same condensate fraction and the cells differ in how fast
# they crossed the window rather than in where they stopped. Without it the fast
# arm reports a selection statistic for a state that never reached the window.
# 4000 ms is set by where the CHOICE is frozen, not by where the growth ends: the
# branches pass 50 k_BT apart by f ≈ 0.40, and 0.68 e-foldings of N₀ at the
# reservoir-limited rate 2γΔµ takes ≈ 2400 ms. Running to f = 1 would cost 3× for
# a decision already made.
TOTAL_MS=${TOTAL_MS:-4000}
# dt = 0.004 with a 0.002 arm as the systematic check: #335 measured ⟨F⊥⟩ agreeing
# to three digits between 0.004 and 0.001 on this Hamiltonian, and it had to
# disclose an unrun dt axis. This campaign runs one.
DT=${DT:-0.004}
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
    # GROWTH-ONLY, and it survives a day of being argued about in both directions.
    #
    # The reason recorded here at launch — "the projected scattering step loses
    # number at ~1.25× the growth rate" — rested on evidence that did not support
    # it (flatness in resolution, which a one-off shows too), and was withdrawn on
    # 2026-08-20. The withdrawal was then measured to be too broad: it rested on a
    # NOISE-OFF experiment, and with the noise on the loss is a rate after all
    # (ratio 4.04 for 4x the steps, at zero growth drive, from a pre-projected
    # seed). Production runs with noise. See `src/solvers/spgpe.jl`.
    #
    # So the choice stands, now on a measurement instead of an inference, and the
    # `fullspgpe` stage shows the consequence directly: the full theory on this
    # very ramp holds N_C flat at f = 0.065 where growth-only reaches 0.37, and
    # pinning the C region changes that by 5 parts in 3271 — so it is the noise
    # channel, not the cutoff motion.
    #
    # What was always independent of that argument, and is the positive reason:
    # Rooney Eq. (20) is a sub-theory in its own right and carries the M_z-changing
    # exchange that makes nucleation possible where transport is blocked.
    # Passed through `-v`, not
    # exported: qsub only forwards the variables it is named, so an `export` here
    # would have left every job running the full theory.
    # ONE trajectory per job, and a 12 h slot for a job that takes ~7 h.
    #
    # The isolated rate probe measured 7.7 ms/step, i.e. 1.5 h for 691k steps, and a
    # 3-seed shard in a 6 h slot was sized from it. Under the real ensemble — 30
    # gpu_1 jobs, four to a node, all bandwidth-bound on 64³ D=13 FFTs — the
    # measured rate is 6.6 h per trajectory, 4.4× the isolated one. The first wave
    # was therefore killed at its walltime having banked one trajectory of three.
    #
    # A probe run alone does not measure the campaign; it measures the probe. One
    # trajectory per job makes the wall clock independent of that factor, and the
    # per-seed skip in submit_nucleate.sh makes a resubmission cost only what is
    # missing.
    SHARD=${SHARD:-1}
    for T in $TEMPS; do
        for TAU in $TAUS; do
            HOLD=$(awk -v a="$TOTAL_MS" -v b="$TAU" 'BEGIN{printf "%.1f", (a-b>0? a-b : 0)}')
            s0=1
            while [ "$s0" -le "$NSEED" ]; do
                n=$(( NSEED - s0 + 1 )); [ "$n" -gt "$SHARD" ] && n=$SHARD
                q -N nu_T${T}_t${TAU}_s${s0} -l h_rt=12:00:00 \
                  -v NU_KAPPA=1.8,NU_GRID=64,NU_T=$T,NU_DT=$DT,NU_TAU_MS=$TAU,NU_HOLD_MS=$HOLD,NU_NO_ED=1,NU_SEEDS_N=$n,NU_SEED0=$s0,NU_SEED_FILE=$SEEDCELL,NU_MU1_FROM=$ENDCELL,NU_OUT=$OUT/nucleate_k1.8_T${T}_tau${TAU} \
                  scripts/eu334/submit_nucleate.sh
                s0=$(( s0 + n ))
            done
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
    HOLD=$(awk -v a="$TOTAL_MS" 'BEGIN{printf "%.1f", a-1500}')
    q -N nu_quiet_p -l h_rt=12:00:00 \
      -v NU_KAPPA=1.8,NU_GRID=64,NU_T=5.0,NU_DT=$DT,NU_TAU_MS=1500,NU_HOLD_MS=$HOLD,NU_NOISE=0,NU_NO_ED=1,NU_SEEDS_N=1,NU_SEED_FILE=$SEEDCELL,NU_MU1_FROM=$ENDCELL,NU_OUT=$OUT/quiet_from_polar \
      scripts/eu334/submit_nucleate.sh
    FLOWERCELL=${4:-}
    if [ -n "$FLOWERCELL" ]; then
        q -N nu_quiet_f -l h_rt=12:00:00 \
          -v NU_KAPPA=1.8,NU_GRID=64,NU_T=5.0,NU_DT=$DT,NU_TAU_MS=1500,NU_HOLD_MS=$HOLD,NU_NOISE=0,NU_NO_ED=1,NU_SEEDS_N=1,NU_SEED_FILE=$FLOWERCELL,NU_MU1_FROM=$ENDCELL,NU_OUT=$OUT/quiet_from_flower \
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
      -v NU_KAPPA=0.9,NU_GRID=64,NU_T=5.0,NU_DT=$DT,NU_TAU_MS=1300,NU_HOLD_MS=2700,NU_NO_ED=1,NU_SEEDS_N=$NSEED,NU_SEED_FILE=$SEED09,NU_MU1_FROM=$END09,NU_OUT=$OUT/nucleate_k0.9_T5.0_tau500 \
      scripts/eu334/submit_nucleate.sh
    ;;

# The ensemble ran the growth-only sub-theory (Rooney Eq. 20), so #334 item 3
# asks whether the full theory would have answered differently. One trajectory per
# temperature at the middle rate is enough to see a verdict move; this is a check
# on the sub-theory, not a second ensemble.
fullspgpe)
    SEEDCELL=${2:?SEED_CELL required}
    ENDCELL=${3:?END_CELL required}
    for T in $TEMPS; do
        for s0 in 1 2 3; do
            q -N nu_full_T${T}_s${s0} -l h_rt=24:00:00 \
              -v NU_KAPPA=1.8,NU_GRID=64,NU_T=$T,NU_DT=$DT,NU_TAU_MS=1300,NU_HOLD_MS=2700,NU_SEEDS_N=1,NU_SEED0=$s0,NU_SEED_FILE=$SEEDCELL,NU_MU1_FROM=$ENDCELL,NU_OUT=$OUT/nucleate_fullspgpe_T${T} \
              scripts/eu334/submit_nucleate.sh
        done
    done
    ;;

# ATTRIBUTION for the stage above. The full-theory runs hold ~7.6x less condensate
# than growth-only at the same simulated time, and the trajectory alone cannot say
# whether the scattering reservoir is redistributing atoms (physics) or the moving
# C region is re-imposing the projector's one-off loss every step (bookkeeping).
# Pinning k_cut while the drive still runs separates them: suppression that
# survives a stationary cutoff is physics.
#
# ONE job, and only after the stage above frees the GPUs — this is a shared
# allocation and a second ensemble here would buy precision on a number whose
# MEANING is what is in doubt.
kcut_fixed)
    SEEDCELL=${2:?SEED_CELL required}
    ENDCELL=${3:?END_CELL required}
    T=${4:-10.0}
    q -N nu_kcfix_T${T} -l h_rt=24:00:00 \
      -v NU_KAPPA=1.8,NU_GRID=64,NU_T=$T,NU_DT=$DT,NU_TAU_MS=1300,NU_HOLD_MS=2700,NU_KCUT_FIXED=1,NU_SEEDS_N=1,NU_SEED0=1,NU_SEED_FILE=$SEEDCELL,NU_MU1_FROM=$ENDCELL,NU_OUT=$OUT/nucleate_kcutfixed_T${T} \
      scripts/eu334/submit_nucleate.sh
    ;;

# Unit-scale probe for the stall seen in the fullspgpe stage. Same setup as the
# suite's only condensate-growth gate, run at BOTH values of M, so the arms differ
# in one knob. Cheap and short: this is a debugging instrument, not a measurement
# of the campaign's physics.
ed_probe)
    q -N eu334_edprobe -l h_rt=2:00:00 -v ED_NSTEP=${ED_NSTEP:-25000} \
      scripts/eu334/submit_ed_probe.sh
    ;;

# Classify every endpoint that has one and no class CSV yet. Idempotent, and
# separate from the trajectory jobs so a shard killed at its walltime does not
# leave its finished trajectories unread.
classify)
    q -N eu334_cls -l h_rt=12:00:00 -v CL_ROOT=$OUT,CL_GRID=64 \
      scripts/eu334/submit_classify.sh
    ;;

*) echo "unknown stage '$1'" >&2; exit 64 ;;
esac
