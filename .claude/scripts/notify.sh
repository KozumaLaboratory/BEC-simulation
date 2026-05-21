#!/usr/bin/env bash
# Loop notification dispatcher. Logs always; webhooks if env vars set.
#
# Usage: notify.sh "T5 PASS"
#
# Env knobs:
#   DISCORD_WEBHOOK - full webhook URL
#   SLACK_WEBHOOK   - full webhook URL
#   NOTIFY_QUIET    - set to "1" to suppress webhook calls, log only

set -euo pipefail

MSG="${1:-no message}"
HOST="$(hostname)"
TS="$(date -Iseconds)"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${ROOT}/.claude/logs"
mkdir -p "$LOG_DIR"
echo "${TS} [${HOST}] ${MSG}" >> "${LOG_DIR}/notify.log"

if [ "${NOTIFY_QUIET:-0}" = "1" ]; then
    exit 0
fi

if [ -n "${DISCORD_WEBHOOK:-}" ]; then
    PAYLOAD=$(jq -n --arg c "\`[${HOST}]\` ${MSG}" '{content: $c}')
    curl -sS -X POST -H 'Content-Type: application/json' \
        -d "$PAYLOAD" "$DISCORD_WEBHOOK" > /dev/null 2>&1 || \
        echo "${TS} discord webhook failed" >> "${LOG_DIR}/notify.log"
fi

if [ -n "${SLACK_WEBHOOK:-}" ]; then
    PAYLOAD=$(jq -n --arg t "[${HOST}] ${MSG}" '{text: $t}')
    curl -sS -X POST -H 'Content-Type: application/json' \
        -d "$PAYLOAD" "$SLACK_WEBHOOK" > /dev/null 2>&1 || \
        echo "${TS} slack webhook failed" >> "${LOG_DIR}/notify.log"
fi
