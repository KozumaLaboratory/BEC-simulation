#!/bin/bash
# TSUBAME (UGE) submit: one leg of the rate scan (#335 stages B/C/D/E).
#
#   qsub -g tga-kozuma-kouhi -N ar_k18_rise \
#     -v AR_KAPPA=1.8,AR_LEGS=rise,AR_B_LO=20,AR_B_HI=200,AR_RATES=50,15,5,1.5,0.5,\
#AR_SEED_RISE_FILE=/gs/.../flower_k1.8_B020.jld2 \
#     scripts/eu_hysteresis/submit_ramp.sh
#
# One leg per job: the arms of a rate scan are independent, and a 24 h wall clock
# holding both legs means a kill costs the loop rather than half of one side.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=24:00:00
#$ -j y
#$ -o logs/tsubame/
source "$(dirname "$0")/_preamble.sh"

export AR_KAPPA="${AR_KAPPA:-1.8}"
export AR_GRID="${AR_GRID:-32}"
export AR_BOX="${AR_BOX:-24.0}"
export AR_B_LO="${AR_B_LO:-20}"
export AR_B_HI="${AR_B_HI:-200}"
export AR_LEGS="${AR_LEGS:-rise,fall}"
export AR_DT="${AR_DT:-0.002}"
export AR_FRAMES="${AR_FRAMES:-400}"
# Dealiasing stays OFF: at 32³ / box 24 the Orszag 2/3 cutoff k=2.62 sits BELOW
# the occupied band k≈4.3, so the filter removes physically occupied modes and
# |ψ|² bleeds ~17 % over a long ramp. Only re-enable on a grid whose cutoff
# clears the band — at 64³ it does (k_cut=5.24), but the seeds and the 32³ arms
# were converged without it, so the campaign keeps one setting.
export AR_DEALIAS="${AR_DEALIAS:-0}"
export AR_SAVE_PSI="${AR_SAVE_PSI:-1}"
export AR_OUT="${AR_OUT:-$EU335_OUT/ramp_g${AR_GRID}}"
for v in AR_RATES AR_TAUS AR_SEED_RISE_FILE AR_SEED_FALL_FILE \
         AR_SEED_RISE_B AR_SEED_FALL_B AR_FORCE AR_SMOKE AR_LIB; do
    [ -n "${!v:-}" ] && export "$v"
done

echo "=== ramp κ=$AR_KAPPA grid=$AR_GRID legs=$AR_LEGS B=$AR_B_LO..$AR_B_HI rates=${AR_RATES:-} taus=${AR_TAUS:-} ==="
"$JULIA" --project=. scripts/eu_adiabatic_ramp_protocol.jl
echo "=== done $(date) → $AR_OUT ==="
