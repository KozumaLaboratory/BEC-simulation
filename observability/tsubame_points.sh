#!/bin/bash
# TSUBAME operational-budget capture for the observability history.
# RUN ON THE LOGIN NODE (t4-user-info is login-node only).
#
#   ssh tsubame 'cd /gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt && bash observability/tsubame_points.sh'
#
# Appends one JSON record (points balance + disk) to observability/history.jsonl
# and prints a dispatch verdict against the 30-point campaign cap.
set -u
GRP=tga-kozuma-kouhi
CAP=30.0                                  # campaign cap (metrics.toml [budget].cap_points)
HIST="$(dirname "$0")/history.jsonl"
SPENT_FILE="$(dirname "$0")/.points_spent"   # cumulative points our jobs have reserved

# --- group balance: columns = gid group_name deposit balance ---
LINE=$(t4-user-info group point -g "$GRP" 2>/dev/null | awk -v g="$GRP" '$2==g {print}')
BALANCE=$(echo "$LINE" | awk '{print $4}')
DEPOSIT=$(echo "$LINE" | awk '{print $3}')
[ -z "$BALANCE" ] && BALANCE="null"

# --- disk: /gs/fs used GB ---
DISK_GS=$(t4-user-info disk group -g "$GRP" 2>/dev/null | awk '/gs\/fs/ {print $0}' | grep -oE '[0-9]+\.[0-9]+' | head -1)
[ -z "$DISK_GS" ] && DISK_GS="null"

# --- cumulative spent (best-effort: sum of reservations recorded by dispatch) ---
SPENT=$(cat "$SPENT_FILE" 2>/dev/null || echo 0)

TS=$(date -Iseconds)
printf '{"ts":"%s","metric_ns":"tsubame_budget","balance":%s,"deposit":%s,"spent":%s,"cap":%s,"disk_gs_gb":%s}\n' \
    "$TS" "$BALANCE" "${DEPOSIT:-null}" "$SPENT" "$CAP" "$DISK_GS" | tee -a "$HIST"

echo "----------------------------------------------------------------------"
echo "TSUBAME budget:  balance=$BALANCE  campaign_spent=$SPENT / cap=$CAP  disk_gs=$DISK_GS GB"
# dispatch gate: spent + typical node_q reservation must stay under cap
awk -v s="$SPENT" -v c="$CAP" 'BEGIN{
    if (s+0 >= c+0) { print "VERDICT: BLOCKED — campaign cap reached, do NOT dispatch"; exit 3 }
    else { printf "VERDICT: OK to dispatch (%.1f points remain under cap)\n", c-s }
}'
