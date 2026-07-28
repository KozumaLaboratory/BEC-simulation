#!/usr/bin/env bash
# Sequential GPU chain for the Eu adiabatic-passage protocol:
#   κ = 1.8  first-order side of the tricritical point (B_eq ≈ 61.9 µG)
#   κ = 0.8  crossover control — the same protocol MUST show no loop here
#
# Run from the repo root that holds figs/eu_gs_library (the seed library).
#   bash scripts/run_eu_adiabatic_ramp.sh
set -euo pipefail

DRIVER="${DRIVER:-scripts/eu_adiabatic_ramp_protocol.jl}"
TAUS="${TAUS:-3,10,30,100,300}"
DT="${DT:-0.002}"
LOG="${LOG:-logs/eu_adiabatic_ramp.log}"
mkdir -p "$(dirname "$LOG")"

export LD_LIBRARY_PATH=/usr/lib/wsl/lib

{
  echo "=== κ=1.8 (first-order): rise 65→100 µG, fall 64→20 µG ==="
  AR_KAPPA=1.8 AR_TAUS="$TAUS" AR_DT="$DT" AR_B_LO=20 AR_B_HI=100 \
    julia --project=. "$DRIVER"

  echo
  echo "=== κ=0.8 (crossover control): rise 14→60 µG, fall 28→2 µG ==="
  AR_KAPPA=0.8 AR_TAUS="$TAUS" AR_DT="$DT" AR_B_LO=2 AR_B_HI=60 \
    AR_SEED_RISE_B=14 AR_SEED_FALL_B=28 \
    julia --project=. "$DRIVER"
} >> "$LOG" 2>&1

echo "done → $LOG"
