#!/usr/bin/env bash
# Sequential 3-parallel driver for the local phi_omega scan.
# 8 configs × ~50 min each, 3-parallel, 3 chunks → ~2.5h total wall.
#
# Usage (detached, survives Claude session close):
#   setsid nohup bash scripts/run_phi_omega_scan.sh > logs/phi_omega_master.log 2>&1 < /dev/null &
#   disown

set -euo pipefail

CONFIGS=(
    eu151_phi1_0_500ms
    eu151_phi2_0_500ms
    eu151_phi3_0_500ms
    eu151_phi4_524_500ms
    eu151_phi6_0_500ms
    eu151_phi8_0_500ms
    eu151_phi12_0_500ms
    eu151_phi18_0_500ms
)

JULIA=/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
LAUNCHER=scripts/cli.jl
BATCH=phi_omega_scan
LOGS_DIR=logs/phi_omega_scan
mkdir -p "$LOGS_DIR"
PARALLEL=3

i=0
chunk_idx=0
while [ $i -lt ${#CONFIGS[@]} ]; do
    chunk_idx=$((chunk_idx + 1))
    echo "[$(date +%H:%M:%S)] === chunk $chunk_idx start ==="
    pids=()
    for ((j = 0; j < PARALLEL && i + j < ${#CONFIGS[@]}; j++)); do
        name="${CONFIGS[$((i + j))]}"
        logf="$LOGS_DIR/${name}.log"
        LD_LIBRARY_PATH=/usr/lib/wsl/lib "$JULIA" --project=. "$LAUNCHER" launch "$BATCH" "$name" > "$logf" 2>&1 &
        pids+=($!)
        echo "  launched $name (PID $!)"
        sleep 3
    done
    echo "[$(date +%H:%M:%S)] chunk $chunk_idx waiting on ${pids[*]}"
    for pid in "${pids[@]}"; do
        wait "$pid" || echo "  PID $pid exited non-zero (continuing)"
    done
    i=$((i + PARALLEL))
done

echo "[$(date +%H:%M:%S)] === all 8 phi_omega runs complete ==="
