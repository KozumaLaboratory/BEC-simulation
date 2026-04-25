#!/usr/bin/env bash
# Supervisor for long-running runs: restarts on crash, posts Slack on
# final completion. Resumability is provided by run_yaml itself
# (cached point_NNN.jld2 files are skipped).
#
# Usage:
#   scripts/supervised_run.sh <run_name> [max_retries]
#
# Defaults: max_retries = 5. Sleeps 30 s between restarts.

set -uo pipefail

RUN_NAME="${1:?usage: $0 <run_name> [max_retries]}"
MAX_RETRIES="${2:-5}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="${PROJECT_ROOT}/logs/${RUN_NAME}_supervised.log"

mkdir -p "${PROJECT_ROOT}/logs"
echo "=== supervised_run start: $(date) ===" | tee -a "$LOG"

attempt=0
exit_code=1
while [[ $attempt -lt $MAX_RETRIES ]]; do
    attempt=$((attempt + 1))
    echo "--- attempt $attempt / $MAX_RETRIES at $(date) ---" | tee -a "$LOG"

    LD_LIBRARY_PATH=/usr/lib/wsl/lib \
        julia --project="$PROJECT_ROOT" "$PROJECT_ROOT/scripts/rerun_single.jl" "$RUN_NAME" \
        2>&1 | tee -a "$LOG"
    exit_code=${PIPESTATUS[0]}

    if [[ $exit_code -eq 0 ]]; then
        echo "=== success on attempt $attempt at $(date) ===" | tee -a "$LOG"
        break
    fi

    echo "--- exit $exit_code on attempt $attempt; sleeping 30 s before retry ---" | tee -a "$LOG"
    sleep 30
done

if [[ $exit_code -eq 0 ]]; then
    msg=":white_check_mark: SpinorBEC run *${RUN_NAME}* completed (attempts: $attempt)"
else
    msg=":x: SpinorBEC run *${RUN_NAME}* gave up after $MAX_RETRIES attempts"
fi

julia --project="$PROJECT_ROOT" "$PROJECT_ROOT/scripts/notify_slack.jl" "$msg" || true
exit $exit_code
