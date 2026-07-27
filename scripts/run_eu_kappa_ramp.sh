#!/usr/bin/env bash
# Sequential GPU chain for the Eu κ-ramp (trap-shaping) preparation protocol:
# hold B below B_eq and ramp κ from the crossover side (0.8) across the
# tricritical point to the first-order side (1.8), round trip, rate-scanned.
#
# Waits for any running eu_adiabatic_ramp_protocol.jl to finish first — the local
# GPU is compute-saturated by one of these at a time and sharing it halves both.
#   bash scripts/run_eu_kappa_ramp.sh
set -euo pipefail

TAUS="${TAUS:-3,10,30,100,300}"
DT="${DT:-0.002}"
B_HOLD="${B_HOLD:-20}"
LOG="${LOG:-logs/eu_kappa_ramp.log}"
WAIT_FOR="${WAIT_FOR:-eu_adiabatic_ramp_protocol.jl}"
mkdir -p "$(dirname "$LOG")"

export LD_LIBRARY_PATH=/usr/lib/wsl/lib

if [[ -n "$WAIT_FOR" ]]; then
  while pgrep -f "$WAIT_FOR" > /dev/null; do sleep 60; done
fi

{
  echo "=== κ ramp 0.8 → 1.8 → 0.8 at B = ${B_HOLD} µG, τ = ${TAUS} ω_ref⁻¹ ==="
  echo "    (KR_REF=1 also converges the two reference branches at κ = 1.8)"
  KR_B_HOLD="$B_HOLD" KR_TAUS="$TAUS" KR_DT="$DT" KR_REF=1 KR_ROUND_TRIP=1 \
    julia --project=. scripts/eu_kappa_ramp_protocol.jl
} >> "$LOG" 2>&1

echo "done → $LOG"
