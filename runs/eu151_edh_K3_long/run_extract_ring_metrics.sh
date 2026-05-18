#!/usr/bin/env bash
# Run extract_ring_metrics.jl from the project root with the canonical
# juliaup-managed interpreter. Mirrors the pattern in
# runs/eu151_barnett_spin_cdd0/run_extract_actual.sh.
set -euo pipefail
cd /home/suzume/workspace/BEC-simulation
exec /home/suzume/.juliaup/bin/julia --project=. \
  /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_ring_metrics.jl
