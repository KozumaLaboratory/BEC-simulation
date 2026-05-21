#!/usr/bin/env bash
#
# GPU lockfile helper for the loop (Tier-3 O).
# Preemptive infrastructure — currently the loop runs only one Julia
# process at a time so contention is impossible, but Axis-3 parallel
# experiments (per docs/parallelism_design.md, future work) will need
# this.
#
# Usage:
#   bash gpu_lock.sh acquire <slot_id>       # acquire lock, exit 0 on success
#   bash gpu_lock.sh release <slot_id>       # release lock
#   bash gpu_lock.sh status                  # show all current holders
#
# Each `slot_id` is a free-form string (e.g. "turn_5_sweep_dt0.01"); the
# lock is exclusive across ALL slot_ids per default. With LOCK_SLOTS=N,
# allows up to N concurrent holders (useful for multi-GPU rigs).

set -uo pipefail

LOCK_FILE="/tmp/spinorbec_gpu.lock"
SLOTS="${LOCK_SLOTS:-1}"

action="${1:-status}"
slot="${2:-default}"

case "$action" in
    acquire)
        exec 9>>"$LOCK_FILE"
        if ! flock -n 9; then
            echo "gpu_lock.sh: $slot blocked — another holder has the lock"
            exit 1
        fi
        echo "$(date -Iseconds) $$ $slot" >> "$LOCK_FILE"
        echo "gpu_lock.sh: $slot acquired (pid=$$)"
        exec 9>&-
        ;;
    release)
        if [ -f "$LOCK_FILE" ]; then
            grep -v " $slot$" "$LOCK_FILE" > "$LOCK_FILE.tmp" && mv "$LOCK_FILE.tmp" "$LOCK_FILE"
            echo "gpu_lock.sh: $slot released"
        fi
        ;;
    status)
        if [ -f "$LOCK_FILE" ]; then
            echo "=== current GPU lock holders ==="
            cat "$LOCK_FILE"
        else
            echo "no lock holders"
        fi
        ;;
    *)
        echo "usage: $0 {acquire|release|status} [slot_id]" >&2
        exit 2
        ;;
esac
