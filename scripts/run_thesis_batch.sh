#!/usr/bin/env bash
# Sequential batch driver for the thesis-batch runs.
# Runs 4 batches of 6 in parallel; total ~12h wall clock on a single GPU.
#
# Usage (detached, survives Claude session close):
#   setsid nohup bash scripts/run_thesis_batch.sh > logs/thesis_batch_master.log 2>&1 < /dev/null &
#   disown

set -euo pipefail

BATCH_1=(dy164_main_500ms eu151_full_500ms eu151_no_ddi_500ms eu151_no_stir_500ms eu151_baseline_500ms eu151_no_chirp_500ms)
BATCH_2=(p_30 p_100 p_300 p_1000 p_3000 p_10000)
BATCH_3=(c1_FM_strong c1_FM_weak c1_AFM_strong c1_AFM_weak cdd_half cdd_2x)
BATCH_4=(duration_1500ms duration_2000ms grid_48cube epsilon_1e6 theta_25deg theta_45deg)

JULIA=/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
LAUNCHER=scripts/launch_thesis_run.jl
LOGS_DIR=logs/thesis_batch
mkdir -p "$LOGS_DIR"

PARALLEL=3   # 15 GB host RAM safety: julia ~3 GB × 3 + OS = ~10 GB peak

run_batch () {
    # Run a list of names in chunks of $PARALLEL. Each chunk waits for all
    # workers before the next chunk starts.
    local batch_idx=$1
    shift
    local names=("$@")
    echo "[$(date +%H:%M:%S)] === starting batch $batch_idx (${#names[@]} runs, $PARALLEL parallel) ==="
    local i=0
    while [ $i -lt ${#names[@]} ]; do
        local pids=()
        for ((j=0; j<PARALLEL && i+j<${#names[@]}; j++)); do
            local name="${names[$((i+j))]}"
            local logf="$LOGS_DIR/${name}.log"
            LD_LIBRARY_PATH=/usr/lib/wsl/lib "$JULIA" --project=. "$LAUNCHER" "$name" > "$logf" 2>&1 &
            pids+=($!)
            echo "  launched $name (PID $!)"
            sleep 3  # stagger JIT to avoid CPU thrash
        done
        echo "[$(date +%H:%M:%S)] batch $batch_idx chunk waiting for ${#pids[@]} pids: ${pids[*]}"
        for pid in "${pids[@]}"; do
            wait "$pid" || echo "  PID $pid exited non-zero (continuing)"
        done
        i=$((i+PARALLEL))
    done
    echo "[$(date +%H:%M:%S)] === batch $batch_idx done ==="
}

run_batch 1 "${BATCH_1[@]}"
run_batch 2 "${BATCH_2[@]}"
run_batch 3 "${BATCH_3[@]}"
run_batch 4 "${BATCH_4[@]}"

echo "[$(date +%H:%M:%S)] all 24 thesis-batch runs complete."
