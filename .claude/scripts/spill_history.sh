#!/usr/bin/env bash
#
# Cap state.json's history[] array at $HISTORY_CAP entries (default 50).
# When the cap is exceeded, spill the oldest $SPILL_SIZE entries (default
# 30) into a single archive file under runs/_loop/history_archive/.
# Idempotent — exits 0 silently when no spill is needed.
#
# Invoked by /run-loop.md Step 6c before the commit. Can also be run
# manually for ad-hoc cleanup.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE="$ROOT/runs/_loop/state.json"
ARCHIVE_DIR="$ROOT/runs/_loop/history_archive"

CAP="${HISTORY_CAP:-50}"
SPILL="${SPILL_SIZE:-30}"

if [ ! -f "$STATE" ]; then
    echo "spill_history.sh: $STATE not found, nothing to do"
    exit 0
fi

LEN=$(jq '.history | length' "$STATE")
if [ "$LEN" -le "$CAP" ]; then
    exit 0
fi

mkdir -p "$ARCHIVE_DIR"

FIRST_TURN=$(jq -r ".history[0].turn" "$STATE")
LAST_TURN=$(jq -r ".history[$SPILL - 1].turn" "$STATE")
ARCHIVE_FILE="$ARCHIVE_DIR/turns_${FIRST_TURN}_to_${LAST_TURN}.json"

# Write the archive slice atomically
TMP_ARCHIVE=$(mktemp)
jq ".history[0:$SPILL]" "$STATE" > "$TMP_ARCHIVE"
mv "$TMP_ARCHIVE" "$ARCHIVE_FILE"

# Trim state.json's history[] to keep only entries beyond the spill range
TMP_STATE=$(mktemp)
jq ".history = .history[$SPILL:]" "$STATE" > "$TMP_STATE"
mv "$TMP_STATE" "$STATE"

echo "spill_history.sh: spilled $SPILL entries (turn $FIRST_TURN..$LAST_TURN) to $ARCHIVE_FILE; history[] now has $(jq '.history | length' "$STATE") entries"
