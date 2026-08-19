#!/bin/bash
# TSUBAME (UGE) submit for one arm of the #340 shielding-spec campaign.
#
#   qsub -g tga-kozuma-kouhi -N nh_white \
#     -v NH_SHAPE=white,"NH_RMS_UG=0;0.05;0.15;0.5;1.5",NH_SEEDS=20,... \
#     scripts/eu_noise/submit_noise.sh
#
# Lists use `;` — `qsub -v` separates VARIABLES with commas, so a comma-joined
# list arrives as its first element only and the job still exits 0 with a
# plausible artefact. See gotcha from #335.
#$ -cwd
#$ -l node_q=1
#$ -l h_rt=24:00:00
#$ -j y
#$ -o logs/tsubame/
source "${EU335_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu335}/scripts/eu_hysteresis/_preamble.sh"

export NH_KAPPA="${NH_KAPPA:-1.8}"
export NH_B="${NH_B:-20}"
export NH_GRID="${NH_GRID:-32}"
export NH_DT="${NH_DT:-0.002}"
export NH_SEEDS="${NH_SEEDS:-20}"
export NH_OUT="${NH_OUT:-$EU335_OUT/noise_${NH_SHAPE:-white}}"
for v in NH_SEED_FILE NH_HOLD_MS NH_RMS_UG NH_SHAPE NH_LINES NH_F_LO NH_F_HI \
         NH_F_CORNER NH_PIN NH_FRAMES NH_BOX NH_CONTROL_TOL NH_DEALIAS; do
    [ -n "${!v:-}" ] && export "$v"
done

echo "=== noise hold κ=$NH_KAPPA B=$NH_B shape=${NH_SHAPE:-white} rms=${NH_RMS_UG:-default} holds=${NH_HOLD_MS:-145} seeds=$NH_SEEDS ==="
"$JULIA" --project=. scripts/eu_noise/noise_hold.jl
echo "=== done $(date) → $NH_OUT ==="
