#!/bin/bash
# TSUBAME (UGE) submit: the magnetostricted-AR sensitivity table for #406.
#
#   qsub -g tga-kozuma-kouhi -N arsens scripts/klaus2022/submit_ar_sensitivity.sh
#
# gpu_1: each arm is one scalar-eGPE ITP ground state at 64²×32, which is
# grid-converged for AR to five digits against 128²×64 (§6b). Twelve of them fit
# in well under an hour, so a whole node would be paid for nothing.
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o logs/tsubame/
# The long-lived klaus2022 campaign worktree, not the scratch one #406 was run
# from — that one was removed after the campaign and a default pointing at it
# would `cd` into nothing.
ROOT="${AS_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/klaus2022}"
export EU335_ROOT="$ROOT"
export EU335_OUT="${AS_RUNS:-/gs/fs/tga-kozuma-kouhi/uk07267/runs/klaus2022}"
source "$ROOT/scripts/eu_hysteresis/_preamble.sh"

export AS_OUT="${AS_OUT:-$EU335_OUT/ar_sensitivity}"
for v in AS_GRID AS_STEPS AS_ARMS; do
    [ -n "${!v:-}" ] && export "$v"
done

echo "=== Klaus 2022 magnetostriction sensitivity (#406) ==="
"$JULIA" --project=. scripts/klaus2022/ar_sensitivity.jl
echo "=== done $(date) → $AS_OUT ==="
