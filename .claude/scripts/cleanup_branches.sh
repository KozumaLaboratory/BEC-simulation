#!/usr/bin/env bash
#
# Manual housekeeping for auto/turn_* branches.
#
# anko runs this on demand — the loop never auto-deletes branches
# (per D2 decision). The script classifies each auto branch by:
#   - merged to main?      → DELETE (the canonical record is on main)
#   - PASS but unmerged?   → KEEP (anko's review pending)
#   - FAIL_* / REJECTED?   → RENAME to auto/archived/...
#   - NOVEL?               → KEEP (anko must review novelty findings)
#   - status unknown?      → KEEP, warn
#
# Default is dry run. Re-invoke with DRY_RUN=0 to actually apply.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

DRY_RUN="${DRY_RUN:-1}"
STATE="runs/_loop/state.json"
ARCHIVE_DIR="runs/_loop/history_archive"
HOME_BRANCH=$(jq -r '.home_branch // "main"' "$STATE" 2>/dev/null || echo "main")

emit() {
    local action="$1"
    local branch="$2"
    local reason="$3"
    local prefix
    if [ "$DRY_RUN" = "1" ]; then
        prefix="[DRY]"
    else
        prefix="[GO] "
    fi
    printf "%s %-32s  branch=%s  reason=%s\n" "$prefix" "$action" "$branch" "$reason"
}

lookup_status() {
    local turn="$1"
    local status
    status=$(jq -r --arg t "$turn" '.history[] | select(.turn == ($t | tonumber)) | .judge_status' "$STATE" 2>/dev/null | head -1)
    if [ -z "$status" ] && ls "$ARCHIVE_DIR"/*.json >/dev/null 2>&1; then
        status=$(jq -r --arg t "$turn" '.[] | select(.turn == ($t | tonumber)) | .judge_status' "$ARCHIVE_DIR"/*.json 2>/dev/null | head -1)
    fi
    echo "$status"
}

BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -E '^auto/turn_[0-9]+_' || true)

if [ -z "$BRANCHES" ]; then
    echo "cleanup_branches.sh: no auto/turn_* branches found"
    exit 0
fi

echo "cleanup_branches.sh: classifying $(echo "$BRANCHES" | wc -l) branches (DRY_RUN=$DRY_RUN)"
echo ""

while IFS= read -r branch; do
    [ -z "$branch" ] && continue

    turn=$(echo "$branch" | sed -nE 's|^auto/turn_([0-9]+)_.*|\1|p')
    if [ -z "$turn" ]; then
        emit "SKIP" "$branch" "cannot parse turn number"
        continue
    fi

    status=$(lookup_status "$turn")
    merged="no"
    if git merge-base --is-ancestor "$branch" "$HOME_BRANCH" 2>/dev/null; then
        merged="yes"
    fi

    case "${merged}:${status}" in
        yes:*)
            emit "DELETE (merged to $HOME_BRANCH)" "$branch" "${status:-unknown}"
            [ "$DRY_RUN" = "0" ] && git branch -d "$branch"
            ;;
        no:PASS|no:NOOP|no:NOVEL_CONFIRMED|no:SUSPICIOUS_NOVEL)
            emit "KEEP (anko review)" "$branch" "$status"
            ;;
        no:FAIL_NUMERICAL|no:FAIL_PHYSICS|no:REJECTED|no:FAIL_NO_METRICS|no:FAIL_NO_REPORT)
            new_name="auto/archived/${branch#auto/}"
            emit "ARCHIVE -> $new_name" "$branch" "$status"
            [ "$DRY_RUN" = "0" ] && git branch -m "$branch" "$new_name"
            ;;
        no:)
            emit "KEEP (status unknown)" "$branch" "no history entry for turn $turn"
            ;;
        *)
            emit "SKIP (unhandled)" "$branch" "merged=$merged status=$status"
            ;;
    esac
done <<< "$BRANCHES"

echo ""
if [ "$DRY_RUN" = "1" ]; then
    echo "DRY RUN complete. Re-run with DRY_RUN=0 to apply."
else
    echo "Cleanup applied."
fi
