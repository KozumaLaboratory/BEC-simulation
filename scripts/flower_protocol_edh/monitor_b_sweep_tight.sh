#!/usr/bin/env bash
# [DEPRECATED 2026-06-19] use `b_sweep_status_grid.py` instead — it shows
# the unified Phase 1 + Phase 2 dashboard for the b_sweep_all pipeline.
#
# Poll the b_sweep_tight progress file + recent cache writes via ssh t4.
# Usage: bash scripts/flower_protocol_edh/monitor_b_sweep_tight.sh [interval_sec]
set -euo pipefail
INTERVAL=${1:-30}
ROOT=/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh
echo "polling every ${INTERVAL}s — Ctrl-C to stop"
while true; do
    echo "=== $(date '+%H:%M:%S') ==="
    ssh t4 "cat ${ROOT}/b_sweep_tight_progress.json 2>/dev/null || echo '(no progress.json yet)'; echo; ls -lt ${ROOT}/lbfgs_*uG_final_psi.jld2 2>/dev/null | head -4" 2>&1 | grep -v "WARNING\|This session\|may be upgraded"
    sleep "${INTERVAL}"
done
