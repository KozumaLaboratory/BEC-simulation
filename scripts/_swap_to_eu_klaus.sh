#!/bin/bash
# Watcher: waits for klaus2022_full to finish in the running batch, then
# does a brief kill+restart so the swap of klaus2022_freq_scan →
# eu151_klaus_freq_scan in scripts/run_batch_overnight.jl takes effect.
#
# Cache is reused on restart: klaus2022_full skips (point_001.jld2 + summary
# already on disk), so total interruption is ~2 min.
#
# Self-match safe: uses `ps -p $PID`, not `pgrep -f`.

set -u
cd /home/suzume/workspace/BEC-simulation

OLD_LOG="logs/batch_overnight_freqfix_20260427_075348.log"
BATCH_PID=1921056
JULIA="/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia"

echo "[swap] watcher start at $(date), pid=$$, target batch pid=$BATCH_PID"

# Wait until klaus2022_full completes OR batch dies on its own.
while ps -p $BATCH_PID > /dev/null 2>&1; do
    if grep -q "✓ klaus2022_full completed" "$OLD_LOG" 2>/dev/null; then
        echo "[swap] saw klaus2022_full completion at $(date)"
        break
    fi
    sleep 30
done

if ! ps -p $BATCH_PID > /dev/null 2>&1; then
    echo "[swap] batch already gone — skipping restart"
    exit 1
fi

echo "[swap] killing batch $BATCH_PID"
kill -TERM $BATCH_PID
sleep 5
if ps -p $BATCH_PID > /dev/null 2>&1; then
    echo "[swap] SIGTERM did not take, sending SIGKILL"
    kill -KILL $BATCH_PID
    sleep 3
fi

NEW_LOG="logs/batch_overnight_eu_swap_$(date +%Y%m%d_%H%M%S).log"
setsid nohup bash -c "LD_LIBRARY_PATH=/usr/lib/wsl/lib $JULIA --project=. scripts/run_batch_overnight.jl" \
    > "$NEW_LOG" 2>&1 < /dev/null &
NEW_PID=$!
disown
echo "[swap] restarted batch pid=$NEW_PID log=$NEW_LOG at $(date)"
