#!/usr/bin/env bash
# Sequential 3-parallel driver for the Berry crossover scan.
# 6 configs × ~50 min each, 3-parallel, 2 chunks → ~1.5h total wall.
#
# Usage (detached, survives Claude session close):
#   setsid nohup bash scripts/run_berry_crossover_scan.sh > logs/berry_master.log 2>&1 < /dev/null &
#   disown

set -euo pipefail

CONFIGS=(
    eu151_p10_0_500ms
    eu151_p30_0_500ms
    eu151_p100_0_500ms
    eu151_p300_0_500ms
    eu151_p1000_0_500ms
    eu151_p3000_0_500ms
)

JULIA=/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
LAUNCHER=scripts/launch_berry_crossover_run.jl
LOGS_DIR=logs/berry_crossover_scan
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
        LD_LIBRARY_PATH=/usr/lib/wsl/lib "$JULIA" --project=. "$LAUNCHER" "$name" > "$logf" 2>&1 &
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

echo "[$(date +%H:%M:%S)] === all 6 Berry crossover runs complete ==="
