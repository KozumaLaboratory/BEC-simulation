#!/usr/bin/env bash
#
# Autonomous research loop driver for SpinorBEC.jl.
#
# Usage:
#   bash .claude/scripts/loop.sh                # run until halted
#   LOOP_MAX_TURNS=3 bash .claude/scripts/loop.sh   # run at most 3 turns
#
# Runs each turn as a separate `claude -p "/run-loop"` invocation.
# State persists in runs/_loop/state.json between turns. Quotas
# are checked before every turn.
#
# Critical: this script aggressively unsets ANTHROPIC_API_KEY so that
# Claude Code authenticates via the OAuth (Max plan) path, not API
# billing. If anko genuinely wants API billing, do not use this loop.

set -uo pipefail

# Paths
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

STATE="runs/_loop/state.json"
LOG_DIR=".claude/logs"
mkdir -p "$LOG_DIR" "$(dirname "$STATE")"

# Pre-flight
unset ANTHROPIC_API_KEY
unset ANTHROPIC_API_TOKEN

if [ -n "${ANTHROPIC_API_KEY:-}" ] || [ -n "${ANTHROPIC_API_TOKEN:-}" ]; then
    echo "$(date -Iseconds) ABORT: ANTHROPIC_API_KEY still set after unset" \
        >> "$LOG_DIR/loop.log"
    echo "Refuse to run: ANTHROPIC_API_KEY is set."
    exit 2
fi
echo "$(date -Iseconds) loop start: API key unset, OAuth (Max) only" \
    >> "$LOG_DIR/loop.log"

# Initialize state if absent
if [ ! -f "$STATE" ]; then
    cat > "$STATE" <<EOF
{
  "turn": 0,
  "status": "running",
  "retries": 0,
  "history": [],
  "created_at": "$(date -Iseconds)"
}
EOF
fi

# Loop knobs
MAX_TURNS="${LOOP_MAX_TURNS:-0}"   # 0 = no limit
INTER_TURN_SLEEP="${LOOP_SLEEP_SEC:-5}"
# 2026-05-19 restrict-mode (anko 90% quota incident): if schedule.yaml has
# restrict_mode_2026_05_19.enabled: true AND today's expires_after has not
# passed, override INTER_TURN_SLEEP from that field.
if [ -f runs/_loop/schedule.yaml ] && [ -z "${LOOP_SLEEP_SEC:-}" ]; then
    RESTRICT_SLEEP=$(python3 -c "
import yaml, sys, datetime
try:
    cfg = yaml.safe_load(open('runs/_loop/schedule.yaml')) or {}
    r = cfg.get('restrict_mode_2026_05_19') or {}
    if r.get('enabled') and datetime.date.today().isoformat() <= r.get('expires_after', '2000-01-01'):
        print(r.get('inter_turn_sleep_sec', 5))
    else:
        print(5)
except Exception:
    print(5)
" 2>/dev/null)
    if [ -n "$RESTRICT_SLEEP" ] && [ "$RESTRICT_SLEEP" -gt 5 ]; then
        echo "$(date -Iseconds) restrict-mode active: inter_turn_sleep=${RESTRICT_SLEEP}s (vs 5s default)" >> "$LOG_DIR/loop.log"
        INTER_TURN_SLEEP="$RESTRICT_SLEEP"
    fi
fi
TURNS_RUN=0

# Trap SIGINT for graceful halt + tmp cleanup (Tier-1 P).
cleanup_tmp() {
    rm -f /tmp/spinorbec_loop_*.json /tmp/spinorbec_loop_*.tmp 2>/dev/null || true
}
trap 'echo "$(date -Iseconds) loop SIGINT, halting" >> "$LOG_DIR/loop.log"; \
      bash .claude/scripts/notify.sh "loop SIGINT" || true; cleanup_tmp; exit 130' INT
trap 'cleanup_tmp' EXIT

# Log rotation: gzip logs older than 7 days (Tier-2 I).
find "$LOG_DIR" -maxdepth 1 -name 'turn_*.jsonl' -type f -mtime +7 -exec gzip {} \; 2>/dev/null || true
find "$LOG_DIR" -maxdepth 1 -name 'turn_*.jsonl.gz' -type f -mtime +30 -delete 2>/dev/null || true

# Main loop
while true; do
    STATUS=$(jq -r '.status // "running"' "$STATE")
    TURN_BEFORE=$(jq -r '.turn // 0' "$STATE")

    if [ "$STATUS" != "running" ]; then
        echo "$(date -Iseconds) loop halt: status=${STATUS}" \
            >> "$LOG_DIR/loop.log"
        bash .claude/scripts/notify.sh "loop halted: ${STATUS}" || true
        exit 0
    fi

    if [ "$MAX_TURNS" -gt 0 ] && [ "$TURNS_RUN" -ge "$MAX_TURNS" ]; then
        echo "$(date -Iseconds) loop halt: reached LOOP_MAX_TURNS=${MAX_TURNS}" \
            >> "$LOG_DIR/loop.log"
        bash .claude/scripts/notify.sh "loop stopped: max-turns=${MAX_TURNS}" || true
        exit 0
    fi

    # 2026-05-19 restrict-mode: daily turn cap (UTC day).
    # Counts director/turn_*.md files modified today.
    DAILY_CAP=$(python3 -c "
import yaml, datetime
try:
    cfg = yaml.safe_load(open('runs/_loop/schedule.yaml')) or {}
    r = cfg.get('restrict_mode_2026_05_19') or {}
    if r.get('enabled') and datetime.date.today().isoformat() <= r.get('expires_after', '2000-01-01'):
        print(r.get('daily_turn_cap', 0))
    else:
        print(0)
except Exception:
    print(0)
" 2>/dev/null)
    if [ -n "$DAILY_CAP" ] && [ "$DAILY_CAP" -gt 0 ]; then
        TODAY=$(date +%Y-%m-%d)
        # Count files in director/ whose mtime is today
        TODAY_TURNS=$(find runs/_loop/director -name 'turn_*.md' -newermt "$TODAY 00:00:00" 2>/dev/null | wc -l)
        if [ "$TODAY_TURNS" -ge "$DAILY_CAP" ]; then
            echo "$(date -Iseconds) loop halt: restrict-mode daily cap ${DAILY_CAP} reached (${TODAY_TURNS} turns today)" >> "$LOG_DIR/loop.log"
            bash .claude/scripts/notify.sh "loop daily cap reached: ${TODAY_TURNS}/${DAILY_CAP}" || true
            (
                flock -x 9
                jq '.status = "halted_daily_cap"' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
            ) 9>runs/_loop/_local/state.json.lock
            exit 0
        fi
    fi

    if ! python .claude/scripts/quota_check.py > "$LOG_DIR/quota_${TURN_BEFORE}.log" 2>&1; then
        jq '.status = "budget_exhausted"' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
        echo "$(date -Iseconds) loop halt: budget_exhausted" >> "$LOG_DIR/loop.log"
        bash .claude/scripts/notify.sh "quota exhausted" || true
        exit 0
    fi

    # Scheduler gate (2026-05-15): time-window + probe + workload-fit decision.
    # Writes runs/_loop/_local/scheduler_${TURN_BEFORE}.json for director to read.
    mkdir -p runs/_loop/_local
    SCHED_JSON_FILE="runs/_loop/_local/scheduler_${TURN_BEFORE}.json"
    if ! python3 .claude/scripts/scheduler.py > "$SCHED_JSON_FILE" 2>"$LOG_DIR/scheduler_${TURN_BEFORE}.err"; then
        SCHED_DECISION=$(jq -r '.decision // "halt"' "$SCHED_JSON_FILE" 2>/dev/null || echo "halt")
        case "$SCHED_DECISION" in
            wait)
                SCHED_WAIT_SEC=$(jq -r '.wait_seconds // 60' "$SCHED_JSON_FILE")
                # Cap wait at 1 hour; loop will re-check after.
                if [ "$SCHED_WAIT_SEC" -gt 3600 ]; then
                    SCHED_WAIT_SEC=3600
                fi
                echo "$(date -Iseconds) scheduler: wait ${SCHED_WAIT_SEC}s" >> "$LOG_DIR/loop.log"
                bash .claude/scripts/notify.sh "scheduler wait ${SCHED_WAIT_SEC}s" 2>/dev/null || true
                sleep "$SCHED_WAIT_SEC"
                continue
                ;;
            halt)
                jq '.status = "scheduler_halt"' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
                SCHED_ADVICE=$(jq -r '.advice // "no advice"' "$SCHED_JSON_FILE")
                echo "$(date -Iseconds) loop halt: scheduler — ${SCHED_ADVICE}" >> "$LOG_DIR/loop.log"
                bash .claude/scripts/notify.sh "loop halted by scheduler: ${SCHED_ADVICE}" || true
                exit 0
                ;;
        esac
    fi
    SCHED_POLICY=$(jq -r '.policy // "TEXT_ONLY"' "$SCHED_JSON_FILE")
    SCHED_LEFT_MIN=$(jq -r '(.window_seconds_left // 0) / 60 | floor' "$SCHED_JSON_FILE")
    echo "$(date -Iseconds) scheduler: go, policy=${SCHED_POLICY}, ${SCHED_LEFT_MIN}m left in window" >> "$LOG_DIR/loop.log"

    TURN_LOG="$LOG_DIR/turn_${TURN_BEFORE}_$(date +%Y%m%d_%H%M%S).jsonl"
    echo "=== Turn ${TURN_BEFORE} starting at $(date -Iseconds) ==="

    # 2026-05-19 (reviewer #2 + #3): deterministic investigation picker.
    # Pre-spawn step: director_pick.py walks the decision table mechanically
    # and writes the chosen investigation+stage+role to a state file the
    # director reads. This moves "investigation picking" OUT of director's
    # prompt judgment (which fails per Geng 2025 Control Illusion) and INTO
    # code. The director still drafts the §6 contract, but cannot override
    # the pick.
    NEXT_TURN=$((TURN_BEFORE + 1))
    python3 .claude/scripts/director_pick.py --turn "$NEXT_TURN" --write-pick \
        > "$LOG_DIR/director_pick_${NEXT_TURN}.log" 2>&1 || true

    # Per-turn wall-time timeout (Tier-1 D). Default 2400s = 40 min;
    # override with LOOP_TURN_TIMEOUT_SEC. Exit code 124 from timeout(1)
    # signals the per-turn wall-time was exceeded.
    # 2026-05-16: bumped from 1200 → 2400 after T11 substantive D1+D3
    # theorist turn finished derivation OK but orchestrator post-step
    # (implementer dispatch + sim/judge writing) ran out of time.
    TURN_TIMEOUT="${LOOP_TURN_TIMEOUT_SEC:-2400}"
    # Capture claude exit code separately from `if !` — inside `if !cmd; then`
    # the `$?` reads the negation result (0), not cmd's actual exit, which made
    # every failure log "exit=0" and disabled the timeout-124 branch. Fix
    # 2026-05-16.
    # 2026-05-19 token-quota conservation:
    # - --model sonnet: top-level orchestrator runs on Sonnet 4.6 (1/5 cost
    #   of Opus 4.7 per MTok). Subagents pick their own model per agent.md
    #   frontmatter (critic=haiku, theorist/researcher/implementer=sonnet).
    #   Theorist may still upgrade to Opus via director's brief for tier-3
    #   derivations only.
    # - --exclude-dynamic-system-prompt-sections: moves per-machine sections
    #   (cwd, env info, memory paths, git status) from system prompt to first
    #   user message. Improves prompt-cache hit rate across turns by keeping
    #   the cached prefix static.
    # 2026-05-19 → 2026-05-20: --max-budget-usd raised 0.50 → 1.50.
    # Empirical: 3 sample turns 2026-05-20 ranged $0.63-$1.23 (cache-creation
    # heavy first turn pushed higher). $0.50 was too tight, sessions died
    # at error_max_budget_usd before completing. $1.50 fits typical Sonnet
    # turn cost + cache-creation margin. 6 turns × $1.50 max = $9 (~3% of
    # Max x20 weekly quota), safe against 5% remaining at 95% utilization.
    timeout "$TURN_TIMEOUT" claude -p "/run-loop" \
        --permission-mode acceptEdits \
        --output-format stream-json \
        --verbose \
        --model sonnet \
        --exclude-dynamic-system-prompt-sections \
        --max-budget-usd 1.50 \
        > "$TURN_LOG" 2>&1
    CLAUDE_EXIT=$?
    if [ "$CLAUDE_EXIT" -ne 0 ]; then
        if [ "$CLAUDE_EXIT" = "124" ]; then
            echo "$(date -Iseconds) turn ${TURN_BEFORE} TIMEOUT after ${TURN_TIMEOUT}s" >> "$LOG_DIR/loop.log"
            jq --arg msg "turn timed out after ${TURN_TIMEOUT}s" '.status = "error" | .last_error = $msg' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
            bash .claude/scripts/notify.sh "T${TURN_BEFORE} TIMEOUT, halting" || true
            exit 0
        fi
        # 2026-05-20 failsafe: if the failure was a permission-gate
        # rejection of compound bash (yesterday's incident + this morning's
        # follow-up), do NOT retry — the prompt issue will repeat
        # identically. Halt and require human inspection.
        PERMISSION_GATE_HIT=$(grep -lE "Contains shell syntax|requires approval|backtick body|statically analyzed" "$TURN_LOG" 2>/dev/null | head -1)
        if [ -n "$PERMISSION_GATE_HIT" ]; then
            echo "$(date -Iseconds) turn ${TURN_BEFORE} PERMISSION_GATE_REJECT detected, HALTING (no retry)" >> "$LOG_DIR/loop.log"
            jq '.status = "halted_permission_gate_reject" | .last_error = "compound bash rejected by Claude Code v2 permission gate; see TURN_LOG"' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
            bash .claude/scripts/notify.sh "T${TURN_BEFORE} permission-gate reject, halted (no retry)" || true
            exit 0
        fi
        echo "$(date -Iseconds) claude invocation failed (turn ${TURN_BEFORE}, exit=${CLAUDE_EXIT}), \
sleeping 60s and retrying" >> "$LOG_DIR/loop.log"
        bash .claude/scripts/notify.sh "claude failed @ T${TURN_BEFORE} (exit=${CLAUDE_EXIT}), retrying" || true
        sleep 60
        continue
    fi

    # Post-step (F2 + F3): extract tokens + branch/commit from
    # implementer artifacts, patch state.json AND the just-written
    # sim/turn_N.md, then re-run judge so cost cap can see real
    # numbers. The orchestrator's judge run during the claude -p
    # invocation already wrote a preliminary judge/turn_N.json; we
    # overwrite it here with the cost-cap-aware verdict.
    if [ -f "$TURN_LOG" ]; then
        TURN_DONE=$(jq -r '.history[-1].turn // empty' "$STATE")
        if [ -n "$TURN_DONE" ]; then
            SIM_MD="runs/_loop/sim/turn_${TURN_DONE}.md"

            # F1: extract token usage breakdown
            TOKENS_JSON=$(python3 .claude/scripts/extract_turn_tokens.py "$TURN_LOG" 2>/dev/null || echo "null")

            # F3: extract branch + commit from sim §2 (best-effort)
            BC_JSON='{"branch": null, "commit": null, "parent": null}'
            if [ -f "$SIM_MD" ]; then
                BC_JSON=$(python3 .claude/scripts/extract_branch_commit.py "$SIM_MD" 2>/dev/null || echo "$BC_JSON")
            fi

            mkdir -p runs/_loop/_local
            (
                flock -x 9
                # Patch history entry with tokens + branch/commit/parent
                jq --argjson t "$TOKENS_JSON" --argjson b "$BC_JSON" '
                    if (.history | length) > 0
                    then .history[-1] += ({tokens_used: $t} + ($b | {branch: .branch, commit: .commit, parent: .parent}))
                    else .
                    end
                ' "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"
            ) 9>runs/_loop/_local/state.json.lock

            # Flow-v2 (2026-05-17): check meta-investigation auto-spawn
            # triggers (cost inflation streak, retry loop, fail streak).
            # Side-effects state.json by adding a new meta-investigation
            # when a pathology pattern is detected.
            python3 .claude/scripts/drift_signals.py --check-meta-spawn \
                > "$LOG_DIR/meta_spawn_${TURN_DONE}.log" 2>&1 || true

            # Upgrade B (drift signals): compute drift metrics for this turn
            # and embed into state.history[-1].drift_signals.
            DRIFT_JSON=$(python3 .claude/scripts/drift_signals.py 2>/dev/null || echo "null")
            if [ -n "$DRIFT_JSON" ] && [ "$DRIFT_JSON" != "null" ]; then
                (
                    flock -x 9
                    jq --argjson d "$DRIFT_JSON" '
                        if (.history | length) > 0
                        then .history[-1] += {drift_signals: ($d.signals // {}), drift_escalation: ($d.escalation // "none"), drift_advisories: ($d.advisories // [])}
                        else .
                        end
                    ' "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"
                ) 9>runs/_loop/_local/state.json.lock
            fi

            # Upgrade D (forensic index): regenerate INDEX.md + by_subagent/
            # by_paper/ by_tag/ — best-effort.
            python3 .claude/scripts/turn_index_regen.py > /dev/null 2>&1 || true

            # Upgrade A (memory hygiene): periodic audit, log only (do NOT block).
            # Touch the agent's own .md as having been read this turn.
            python3 .claude/scripts/memory_hygiene.py check > "$LOG_DIR/memory_hygiene_${TURN_DONE}.log" 2>&1 || true
            # 2026-05-18: twice rule — detect when two feedback memories
            # have converged on the same topic (anko gave the same class
            # of correction twice). Logs pairs above similarity threshold.
            python3 .claude/scripts/memory_twice_rule.py scan \
                > "$LOG_DIR/memory_twice_${TURN_DONE}.log" 2>&1 || true

            # Patch sim §4 Metrics with tokens_used so judge re-run sees real numbers.
            if [ -f "$SIM_MD" ] && [ -n "$TOKENS_JSON" ] && [ "$TOKENS_JSON" != "null" ]; then
                python3 << PYEOF
import json, re
from pathlib import Path
sim_path = Path("$SIM_MD")
tokens = json.loads('''$TOKENS_JSON''')
text = sim_path.read_text()
m = re.search(r'(## 4\.\s*Metrics\s*\n+\`\`\`(?:json)?\s*\n)(\{.*?\})(\s*\n\`\`\`)', text, re.DOTALL)
if m:
    metrics = json.loads(m.group(2))
    metrics["tokens_used"] = tokens
    new_block = m.group(1) + json.dumps(metrics, indent=2) + m.group(3)
    text = text[:m.start()] + new_block + text[m.end():]
    sim_path.write_text(text)
PYEOF

                # F2: re-run judge.py now that tokens_used is populated.
                # Overwrites the preliminary judge/turn_N.json from orchestrator.
                python3 .claude/scripts/judge.py --turn "$TURN_DONE" \
                    > /dev/null 2>&1 || true

                # If post-rerun judge downgrades status, propagate to state.
                NEW_VERDICT=$(jq -r '.status' "runs/_loop/judge/turn_${TURN_DONE}.json" 2>/dev/null)
                CURR_LAST=$(jq -r '.last_judge' "$STATE")
                if [ -n "$NEW_VERDICT" ] && [ "$NEW_VERDICT" != "$CURR_LAST" ]; then
                    (
                        flock -x 9
                        jq --arg v "$NEW_VERDICT" '.last_judge = $v | .history[-1].judge_status = $v' "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"
                    ) 9>runs/_loop/_local/state.json.lock
                    echo "$(date -Iseconds) post-step judge re-run changed verdict: $CURR_LAST → $NEW_VERDICT" >> "$LOG_DIR/loop.log"
                fi

                # 2026-05-18 fix: copy investigation_id + stage + cost_audit
                # from judge JSON into history[-1] so status.sh / queries see them.
                # Match by turn (not blind history[-1]) — race-safe.
                JUDGE_PATCH=$(jq -c '{
                    investigation_id: .investigation_id,
                    stage_advancing_to: .stage_advancing_to,
                    cost_audit: .cost_audit
                } | with_entries(select(.value != null))' "runs/_loop/judge/turn_${TURN_DONE}.json" 2>/dev/null)
                JUDGE_PATCH_LOG="$LOG_DIR/judge_patch_${TURN_DONE}.log"
                echo "$(date -Iseconds) JUDGE_PATCH attempt for T${TURN_DONE}" > "$JUDGE_PATCH_LOG"
                echo "JUDGE_PATCH=$JUDGE_PATCH" >> "$JUDGE_PATCH_LOG"
                if [ -n "$JUDGE_PATCH" ] && [ "$JUDGE_PATCH" != "{}" ] && [ "$JUDGE_PATCH" != "null" ]; then
                    (
                        flock -x 9
                        if jq --argjson p "$JUDGE_PATCH" --argjson t "$TURN_DONE" '
                          (.history | map(.turn) | index($t)) as $i |
                          if $i != null then .history[$i] += $p else . end
                        ' "$STATE" > "${STATE}.tmp" 2>>"$JUDGE_PATCH_LOG"; then
                            mv "${STATE}.tmp" "$STATE"
                            echo "OK: patched history[turn=${TURN_DONE}]" >> "$JUDGE_PATCH_LOG"
                        else
                            echo "FAIL: jq returned non-zero" >> "$JUDGE_PATCH_LOG"
                            rm -f "${STATE}.tmp"
                        fi
                    ) 9>runs/_loop/_local/state.json.lock
                else
                    echo "SKIP: JUDGE_PATCH empty/null" >> "$JUDGE_PATCH_LOG"
                fi

                # Flow-v2 post-step (2026-05-17): if the judge applied a
                # declarative contract, propagate investigation_update
                # into state.investigations.<id>. Without this, the
                # investigation thread state stays stale and director's
                # next turn re-dispatches the same stage.
                JUDGE_JSON="runs/_loop/judge/turn_${TURN_DONE}.json"
                if [ -f "$JUDGE_JSON" ]; then
                    INV_ID=$(jq -r '.investigation_id // empty' "$JUDGE_JSON")
                    INV_VERDICT=$(jq -r '.status // empty' "$JUDGE_JSON")

                    # Items 1, 6, 9 (2026-05-18) post-step hooks
                    if [ -n "$INV_ID" ] && [ "$INV_ID" != "null" ]; then
                        python3 .claude/scripts/update_investigation_status.py \
                            --inv-id "$INV_ID" --turn "$TURN_DONE" \
                            > "$LOG_DIR/status_md_${TURN_DONE}.log" 2>&1 || true
                    fi
                    python3 .claude/scripts/state_schema_check.py \
                        > "$LOG_DIR/state_schema_${TURN_DONE}.log" 2>&1 || true
                    if [ $((TURN_DONE % 30)) -eq 0 ]; then
                        python3 .claude/scripts/memory_consolidate.py --gentle \
                            > "$LOG_DIR/memory_consolidate_${TURN_DONE}.log" 2>&1 || true
                    fi
                    # 2026-05-18: Selective forgetting (Item 5).
                    # Every 50 turns: rotate OTEL if oversized, prune
                    # *_turn.log >30 days, cool untouched project memories.
                    # Feedback/user memories are NEVER cooled.
                    if [ $((TURN_DONE % 50)) -eq 0 ] && [ "$TURN_DONE" -gt 0 ]; then
                        python3 .claude/scripts/forgetting.py all \
                            > "$LOG_DIR/forgetting_${TURN_DONE}.log" 2>&1 || true
                    fi
                    # 2026-05-18: OTEL trace + metric emission
                    python3 .claude/scripts/otel_emit.py turn-summary --turn "$TURN_DONE" \
                        > "$LOG_DIR/otel_${TURN_DONE}.log" 2>&1 || true

                    # 2026-05-20: per-investigation budget cap (backlog #2).
                    # Scans history for investigations crossing SOFT/HARD turn
                    # caps; advisories go to recent_findings, hard blocks set
                    # blocked_on. Prevents 20+ turn pit reproduction (Matsui-
                    # class incidents).
                    python3 .claude/scripts/investigation_budget_cap.py inject-into-state \
                        > "$LOG_DIR/budget_cap_${TURN_DONE}.log" 2>&1 || true

                    # 2026-05-18: OTEL-driven cost-waste audit + auto-spawn
                    # of meta-cost-waste-audit investigation when patterns
                    # exceed thresholds. Idempotent per day.
                    python3 .claude/scripts/otel_cost_audit.py --maybe-spawn \
                        > "$LOG_DIR/cost_audit_${TURN_DONE}.log" 2>&1 || true

                    # 2026-05-18: conclusions index.
                    # APC contract_cache extract removed 2026-05-19 per audit
                    # (runs/_loop/research/apc_audit_2026_05_19.md):
                    # director has no Bash tool, can't lookup; skeleton was
                    # last-seen copy not class-generic, key (kind/template/stage)
                    # too coarse, n_seen counts meaningless. Script preserved
                    # in .claude/scripts/ for historical inspection.
                    # conclusions_index appends [Established]/[Plausible]/falsifier
                    # entries to runs/_loop/conclusions/<inv>.md so director's §B1
                    # can tell the next subagent "claim X is already established
                    # at TN, do not re-derive".
                    if [ -n "$INV_ID" ] && [ "$INV_ID" != "null" ]; then
                        python3 .claude/scripts/conclusions_index.py extract \
                            --turn "$TURN_DONE" --inv-id "$INV_ID" \
                            > "$LOG_DIR/conclusions_${TURN_DONE}.log" 2>&1 || true
                    fi
                    if [ -n "$INV_ID" ] && [ "$INV_ID" != "null" ]; then
                        (
                            flock -x 9
                            # 2026-05-19: tier_cap clamp (reviewer rec #2 — central-falsifier gate).
                            # If judge.py emitted tier_cap (central falsifier not PASS),
                            # min-clamp the promotion. Blocks Matsui-level F3-alone closures.
                            jq --arg id "$INV_ID" --arg v "$INV_VERDICT" --argjson j "$(cat "$JUDGE_JSON")" '
                                if (.investigations // {}) | has($id) then
                                  if ($v == "PASS" or $v == "PASS_WITH_COST_WARNING") then
                                    (($j.investigation_update.if_success_tier_becomes // .investigations[$id].tier_current) as $raw_tier
                                     | ($j.tier_cap // 99) as $cap
                                     | (if ($raw_tier > $cap) then $cap else $raw_tier end) as $final_tier
                                     | .investigations[$id].current_stage = ($j.investigation_update.if_success_advance_to_stage // .investigations[$id].current_stage)
                                     | .investigations[$id].tier_current = $final_tier
                                     | .investigations[$id].stages_done = ((.investigations[$id].stages_done // []) + [($j.stage_advancing_to // "?")] | unique)
                                     | (if ($raw_tier != $final_tier) then
                                          .investigations[$id].tier_clamped_at = {turn: $j.turn, raw: $raw_tier, cap: $cap, reason: "central_falsifier_gate"}
                                        else . end)
                                     | if ($j.investigation_update.if_success_falsifier_update // null) != null then
                                         .investigations[$id].falsifiers = ((.investigations[$id].falsifiers // []) | map(if .id == $j.investigation_update.if_success_falsifier_update.id then . + {tested_at_turn: $j.investigation_update.if_success_falsifier_update.tested_at_turn, result: $j.investigation_update.if_success_falsifier_update.result_template} else . end))
                                       else . end)
                                  elif ($v == "PASS_REFUTED") then
                                    .investigations[$id].current_stage = ($j.investigation_update.if_refuted_advance_to_stage // "Update")
                                    | .investigations[$id].tier_current = ($j.investigation_update.if_refuted_tier_becomes // .investigations[$id].tier_current)
                                  else . end
                                else . end
                            ' "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"
                        ) 9>runs/_loop/_local/state.json.lock
                        echo "$(date -Iseconds) flow-v2: investigation $INV_ID updated per judge verdict $INV_VERDICT" >> "$LOG_DIR/loop.log"
                    fi
                fi
            fi
        fi
    fi

    TURNS_RUN=$((TURNS_RUN + 1))
    TURN_AFTER=$(jq -r '.turn // 0' "$STATE")
    STATUS_AFTER=$(jq -r '.status // "running"' "$STATE")

    if [ "$TURN_AFTER" = "$TURN_BEFORE" ] && [ "$STATUS_AFTER" = "running" ]; then
        STALL=$(jq -r '.retries // 0' "$STATE")
        if [ "$STALL" -ge 3 ]; then
            jq '.status = "human_required"' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
            echo "$(date -Iseconds) loop halt: 3 retries at turn ${TURN_BEFORE}" \
                >> "$LOG_DIR/loop.log"
            bash .claude/scripts/notify.sh "stalled at T${TURN_BEFORE}, human_required" || true
            exit 0
        fi
    fi

    sleep "$INTER_TURN_SLEEP"
done
