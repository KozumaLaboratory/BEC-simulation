#!/usr/bin/env bash
#
# PostToolUse hook for Write|Edit. Reads tool-use JSON from stdin and
# checks the written file for two failure patterns:
#
# 1. UNKNOWN_VALUE / RESEARCH_NEEDED markers — the theorist's signal
#    that a value couldn't be derived in-place. The researcher
#    subagent should resolve these before the next theorist turn.
#
# 2. Convention-locked symbols (the SpinorBEC.jl "do not fix" list)
#    being touched in `src/**.jl`. Advisory only — confirms the
#    theorist directive's rationale cited an explicit override.
#
# Both cases: log to .claude/logs/hook_alerts.log AND print to stderr
# (which Claude Code surfaces as system feedback). Non-blocking —
# the markers are intentional from the theorist; the convention notice
# is advisory for the implementer's next-turn directive review.

set -uo pipefail

INPUT=$(cat)
FP=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[ -z "$FP" ] && exit 0
[ ! -f "$FP" ] && exit 0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$ROOT/.claude/logs"
LOG_FILE="$LOG_DIR/hook_alerts.log"
mkdir -p "$LOG_DIR"

log_alert() {
    local msg="$1"
    echo "$(date -Iseconds) $msg" >> "$LOG_FILE"
    echo "[hook] $msg" >&2
}

if grep -q 'UNKNOWN_VALUE\|RESEARCH_NEEDED' "$FP" 2>/dev/null; then
    log_alert "UNKNOWN_VALUE/RESEARCH_NEEDED markers in $FP — researcher subagent should resolve before next theorist turn"
fi

if echo "$FP" | grep -qE '^src/(.*)\.jl$' && \
   grep -qE '_YOSHIDA_W0|secular_ddi|c_dd|even_c_extra|spinor_lhy|c_lhy|apply_nematic_step!|full_bdg' "$FP" 2>/dev/null; then
    log_alert "Convention-locked symbol touched in $FP — verify theorist directive cites the don't-fix override rationale"
fi

exit 0
