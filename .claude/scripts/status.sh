#!/usr/bin/env bash
#
# Quick loop status summary. Run from anywhere in the project.
# Prints: current turn / status / last judge, recent history, current
# branch, quota usage, stuck-check.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

STATE="runs/_loop/state.json"
[ -f "$STATE" ] || { echo "no state.json yet — loop not initialized"; exit 0; }

TURN=$(jq -r '.turn // 0' "$STATE")
STATUS=$(jq -r '.status // "unknown"' "$STATE")
LAST=$(jq -r '.last_judge // "—"' "$STATE")
HOME_B=$(jq -r '.home_branch // "main"' "$STATE")
HIST_LEN=$(jq -r '.history | length' "$STATE")
PHASE=$(jq -r '.phase // "—"' "$STATE")

echo "=== Loop status ==="
printf "  turn=%s  status=%s  phase=%s\n" "$TURN" "$STATUS" "$PHASE"
printf "  last_judge=%s  home_branch=%s  history_entries=%s\n" "$LAST" "$HOME_B" "$HIST_LEN"
echo ""

echo "=== Recent history (last 5) ==="
jq -r '.history[-5:] | .[] | "  T\(.turn)  \(.judge_status // "—")  \(.directive_action // "—")  \(.directive_label // "—")"' "$STATE" 2>/dev/null || echo "  (empty)"
echo ""

echo "=== Stuck check (last 5 verdicts) ==="
RECENT=$(jq -r '.history[-5:] | [.[] | .judge_status] | join(" ")' "$STATE")
echo "  $RECENT"
FAIL_COUNT=$(echo "$RECENT" | tr ' ' '\n' | grep -cE '^(FAIL|REJECTED)' || true)
TOTAL=$(echo "$RECENT" | tr ' ' '\n' | grep -vc '^$' || true)
if [ "$TOTAL" -ge 5 ] && [ "$FAIL_COUNT" -ge 4 ]; then
    echo "  ⚠  stuck: ${FAIL_COUNT}/${TOTAL} recent turns failed — loop should be halted"
elif [ "$FAIL_COUNT" -gt 0 ]; then
    echo "  ${FAIL_COUNT}/${TOTAL} recent fails"
else
    echo "  clean"
fi
echo ""

echo "=== Git ==="
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
printf "  current=%s\n" "$BRANCH"
AUTO_COUNT=$(git branch --list 'auto/turn_*' | wc -l)
ARCHIVED_COUNT=$(git branch --list 'auto/archived/*' | wc -l)
printf "  auto branches: %s active, %s archived\n" "$AUTO_COUNT" "$ARCHIVED_COUNT"
echo ""

echo "=== Quota ==="
python3 .claude/scripts/quota_check.py 2>&1 | head -3
echo ""

echo "=== Tail logs ==="
if [ -f .claude/logs/notify.log ]; then
    echo "  notify.log (last 5):"
    tail -5 .claude/logs/notify.log | sed 's/^/    /'
fi
if [ -f .claude/logs/loop.log ]; then
    echo "  loop.log (last 3):"
    tail -3 .claude/logs/loop.log | sed 's/^/    /'
fi
