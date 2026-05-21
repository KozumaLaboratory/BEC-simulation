#!/usr/bin/env python3
"""
Drift signal computer — Upgrade B (1000-turn design).

Computes per-turn drift metrics from state.json + last N turn outputs.
Outputs JSON for embedding into `state.json.history[-1].drift_signals`.

Per `long_horizon_design.md` §2 B — covers 5 documented failure modes:
- Context Window Saturation [arXiv:2510.18939]
- Meltdown / pass@k gap [arXiv:2603.29231]
- Tool Hallucination [arXiv:2510.22977]
- Planning Brittleness [arXiv:2509.18970]
- Looping without recovery [arXiv:2512.07497]

Signals (each ∈ [0, 1+], 0 = clean, > 1 = problematic):

    topic_repetition       Jaccard of last 3 directive_labels (1.0 = same exact label)
    subagent_repetition    Run-length of consecutive same subagent
    manuscript_delta_zero  1 if last 10 turns made no docs/manuscript change
    code_delta_zero        1 if last 10 turns made no src/* change
    verdict_drift          Fraction of last 10 NOT in {PASS, RESEARCHER_ONLY, CRITIC_PASS}
    cost_inflation         Last turn effective / median of last 10
    novel_claim_zero       1 if last 10 turns had no [Established] tags

Escalation:
- Any single signal ≥ 1.0 → emit `DRIFT_<signal>` warning (record only)
- Two or more signals ≥ 1.0 → director MUST address next turn
- Three or more signals ≥ 1.0 → force `human_required` status

Usage:
    drift_signals.py [--turn N]     # default: latest history entry
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOOP_DIR = ROOT / "runs" / "_loop"
STATE = LOOP_DIR / "state.json"

PASS_LIKE = {"PASS", "RESEARCHER_ONLY", "CRITIC_PASS", "NOOP", "NOVEL_CONFIRMED"}


def _git_diff_touched_paths(since_n_commits: int) -> set[str]:
    """Returns set of file paths modified in the last N commits on main."""
    try:
        out = subprocess.run(
            ["git", "log", f"-n", str(since_n_commits), "--name-only", "--pretty=format:"],
            capture_output=True, text=True, cwd=str(ROOT), check=False,
        )
        return {ln.strip() for ln in out.stdout.splitlines() if ln.strip()}
    except FileNotFoundError:
        return set()


def _auto_branch_touched_paths(history_window: list[dict]) -> set[str]:
    """Refinement: include `auto/turn_*` branch implementer commits in the
    drift's "did we modify code/manuscript" check. Without this, every turn
    that puts changes on an auto branch (not yet merged to main) falsely
    triggers DRIFT_CODE_DELTA_ZERO + DRIFT_MANUSCRIPT_DELTA_ZERO.

    Reads commit SHAs from history's recent entries, git-shows each to
    extract touched paths. Limits to entries with `branch` starting with
    `auto/turn_`.
    """
    touched: set[str] = set()
    for entry in history_window:
        sha = entry.get("commit")
        branch = entry.get("branch", "")
        if not sha or not branch.startswith("auto/turn_"):
            continue
        try:
            out = subprocess.run(
                ["git", "show", "--name-only", "--pretty=format:", sha],
                capture_output=True, text=True, cwd=str(ROOT), check=False,
            )
            for ln in out.stdout.splitlines():
                p = ln.strip()
                if p:
                    touched.add(p)
        except (FileNotFoundError, subprocess.SubprocessError):
            continue
    return touched


def _label_similarity(a: str, b: str) -> float:
    """Jaccard of word tokens, lowercased."""
    if not a or not b:
        return 0.0
    sa = set(re.split(r"[-_/.\s]+", a.lower())) - {""}
    sb = set(re.split(r"[-_/.\s]+", b.lower())) - {""}
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / len(sa | sb)


def _read_state() -> dict:
    if not STATE.exists():
        return {"history": []}
    try:
        return json.loads(STATE.read_text())
    except json.JSONDecodeError:
        return {"history": []}


def compute(target_turn: int | None = None) -> dict:
    state = _read_state()
    history = state.get("history") or []
    if not history:
        return {"status": "OK", "signals": {}, "advisories": [], "escalation": "none"}

    # Identify which entry is "this turn"
    if target_turn is None:
        idx = len(history) - 1
    else:
        idx = next(
            (i for i, h in enumerate(history) if h.get("turn") == target_turn),
            len(history) - 1,
        )

    current = history[idx]
    last_n = history[max(0, idx - 9): idx + 1]  # up to 10 most recent including current
    last_3 = history[max(0, idx - 2): idx + 1]

    signals: dict[str, float] = {}

    # topic_repetition: max similarity of current to prior 2
    cur_label = current.get("directive_label", "")
    sims = [
        _label_similarity(cur_label, h.get("directive_label", ""))
        for h in history[max(0, idx - 2): idx]
    ]
    signals["topic_repetition"] = max(sims) if sims else 0.0

    # subagent_repetition: run-length of identical directive_action ending at current
    cur_action = current.get("directive_action", "")
    rl = 1
    for h in reversed(history[:idx]):
        if h.get("directive_action") == cur_action and cur_action:
            rl += 1
        else:
            break
    signals["subagent_repetition"] = float(rl) / 3.0  # 1.0 = 3-run streak

    # manuscript_delta + code_delta: scan recent commits on main AND on
    # the recent auto branches (refinement: T7 dispatch.jl change was on
    # auto branch only, was previously a false positive).
    touched_main = _git_diff_touched_paths(since_n_commits=min(20, len(last_n) * 2))
    touched_auto = _auto_branch_touched_paths(last_n)
    touched = touched_main | touched_auto
    has_manuscript = any(p.startswith("docs/manuscript") for p in touched)
    has_code = any(
        p.startswith("src/") or p.startswith("test/") or p.startswith("scripts/")
        for p in touched
    )
    signals["manuscript_delta_zero"] = 0.0 if has_manuscript else 1.0
    signals["code_delta_zero"] = 0.0 if has_code else 1.0

    # verdict_drift
    fails = sum(1 for h in last_n if h.get("judge_status") not in PASS_LIKE)
    signals["verdict_drift"] = fails / max(1, len(last_n))

    # cost_inflation: current / median of last 10 (excluding current)
    costs = []
    for h in last_n[:-1]:
        tu = h.get("tokens_used") or {}
        e = tu.get("effective_full_rate")
        if isinstance(e, (int, float)) and e > 0:
            costs.append(e)
    cur_cost = ((current.get("tokens_used") or {}).get("effective_full_rate") or 0)
    if costs and cur_cost > 0:
        med = statistics.median(costs)
        signals["cost_inflation"] = cur_cost / med if med > 0 else 0.0
    else:
        signals["cost_inflation"] = 0.0

    # novel_claim_zero: theorist/turn_N.md count of [Established] tags
    novel_seen = 0
    for h in last_n:
        n = h.get("turn")
        if n is None:
            continue
        t_path = LOOP_DIR / "theorist" / f"turn_{n}.md"
        if t_path.exists():
            try:
                txt = t_path.read_text()
            except OSError:
                continue
            novel_seen += txt.count("[Established]")
    signals["novel_claim_zero"] = 0.0 if novel_seen > 0 else 1.0

    # Triggered signals
    triggered = [k for k, v in signals.items() if v >= 1.0]
    advisories = [f"DRIFT_{k.upper()}" for k in triggered]
    n_trig = len(triggered)
    if n_trig >= 3:
        escalation = "human_required"
    elif n_trig >= 2:
        escalation = "director_must_address"
    elif n_trig == 1:
        escalation = "advisory"
    else:
        escalation = "none"

    # Periodic audit-class-scan advisory (per anko 2026-05-18 L2 abstraction).
    # If patterns.yaml audit_history last entry is >=10 turns old, surface an
    # "AUDIT_DUE" advisory. Director honors unless urgent physics blocked.
    audit_advisory = _compute_audit_due_advisory(history)
    if audit_advisory:
        advisories = advisories + [audit_advisory]

    return {
        "status": "OK",
        "turn": current.get("turn"),
        "signals": {k: round(v, 3) for k, v in signals.items()},
        "triggered": triggered,
        "advisories": advisories,
        "escalation": escalation,
    }


def _compute_audit_due_advisory(history: list) -> str | None:
    """Return AUDIT_DUE advisory string if patterns.yaml hasn't been
    audited in ≥10 turns (or never), else None.

    Reads patterns.yaml audit_history list and compares last run's turn
    counter against current. If the run_at field is absent or the file
    is missing, treats as never-audited.
    """
    patterns_path = ROOT / "runs" / "_loop" / "patterns.yaml"
    if not patterns_path.exists():
        return None
    try:
        import yaml as _yaml
        patterns = _yaml.safe_load(patterns_path.read_text()) or {}
    except Exception:
        return None

    audit_log = patterns.get("audit_history") or []
    current_turn = (history[-1].get("turn") if history else 0) or 0
    if not audit_log:
        return f"AUDIT_DUE: patterns.yaml never audited via flow; current turn={current_turn}"

    # Find max turn referenced in audit_history; missing → very old
    last_audit_turn = 0
    for entry in audit_log:
        # Older entries may have "triggered_by" without turn — use 0 fallback
        last_audit_turn = max(last_audit_turn, int(entry.get("turn") or 0))

    gap = current_turn - last_audit_turn
    if gap >= 10:
        return f"AUDIT_DUE: patterns.yaml last audited at T{last_audit_turn}, gap={gap}"
    return None


# ──────────────────────────────────────────────────────────────────
# Meta-investigation auto-spawn (per anko 2026-05-17 "メタ的に改善できなきゃだめ")
# Detects loop-pathology patterns and spawns a meta-investigation in
# state.json.investigations so the next director turn picks it up.
# Safety rails per director.md §F5.
# ──────────────────────────────────────────────────────────────────

META_TRIGGERS = {
    "cost_inflation_run": {
        "window": 5,
        "condition": lambda history: sum(
            1 for h in history[-5:]
            if "DRIFT_COST_INFLATION" in (h.get("drift_advisories") or [])
        ) >= 4,
        "investigation_id_template": "meta-cost-inflation-{date}",
        "title": "Why is per-turn token cost inflating? (auto-spawn)",
        "hypothesis": "5-turn run shows ≥4 DRIFT_COST_INFLATION — orchestrator overhead or directive bloat. Identify root cause and bound it.",
        "target_metric": "median_tokens_eff_per_turn",
        "modifies_files": [".claude/agents/director.md", ".claude/agents/implementer.md"],
        "priority": 40,
    },
    "directive_label_repetition": {
        "window": 4,
        "condition": lambda history: len({
            (h.get("directive_label") or "")[:30]
            for h in history[-3:]
            if h.get("directive_label")
        }) <= 1,  # all 3 last labels share their 30-char prefix
        "investigation_id_template": "meta-retry-loop-{date}",
        "title": "Same directive label dispatched 3+ turns in a row — retry-loop pathology (auto-spawn)",
        "hypothesis": "Loop is stuck re-dispatching the same directive without progress. Director's failure_modes mapping may be missing a next_action for this failure shape.",
        "target_metric": "unique_directive_labels_per_5_turns",
        "modifies_files": [".claude/agents/director.md"],
        "priority": 30,
    },
    "director_self_audit_due": {
        "window": 20,
        # Item 3 (2026-05-18): every 20 turns, propose a director
        # self-audit meta-investigation. The audit asks critic to
        # review the director's last 20 decisions for quality.
        "condition": lambda history: (
            (len(history) > 0)
            and (history[-1].get("turn", 0) > 0)
            and (history[-1].get("turn", 0) % 20 == 0)
        ),
        "investigation_id_template": "meta-director-self-audit-{date}",
        "title": "Director self-audit: last 20 decisions quality review (auto-spawn)",
        "hypothesis": "Director's pick-quality / tier-estimation-accuracy / waste-rate has drifted. Independent critic audit identifies systematic biases or routing errors that drift_signals (quantitative) cannot catch.",
        "target_metric": "director_decision_quality_score",
        "modifies_files": [".claude/agents/director.md"],
        "priority": 20,
    },
    "same_stage_fail_streak": {
        "window": 4,
        "condition": lambda history: sum(
            1 for h in history[-4:]
            # Fix 2026-05-18 (anko): include INCONCLUSIVE alongside FAIL.
            # YLS reproduction had 3 INCONCLUSIVE in 5 turns (T33/35/37) but
            # this trigger missed it because INCONCLUSIVE doesn't start with FAIL.
            # INCONCLUSIVE means "we tried but couldn't tell" which is the same
            # operational pathology shape as FAIL for retry-loop detection.
            if h.get("judge_status", "").startswith("FAIL")
            or h.get("judge_status") == "INCONCLUSIVE"
        ) >= 3,
        "investigation_id_template": "meta-stage-routing-{date}",
        "title": "3+ FAIL/INCONCLUSIVE in last 4 turns — stage routing / contract design flaw (auto-spawn)",
        "hypothesis": "Multiple consecutive operational failures / inconclusives suggest either contract design is wrong, observable_manifest precondition is missing, stage role is mis-assigned, or success_criteria are not discriminating.",
        "target_metric": "fail_or_inconclusive_rate_per_5_turns",
        "modifies_files": [".claude/agents/director.md", ".claude/scripts/judge.py"],
        "priority": 25,
    },
}


def maybe_spawn_meta_investigation(state_path: Path | None = None) -> dict | None:
    """Detect loop-pathology patterns and spawn a meta-investigation.

    Run after each turn (loop.sh post-step). Returns the spawned
    meta-investigation dict, or None if no trigger fired.

    Idempotent: skips if an active meta-investigation with the same
    trigger id already exists.
    """
    if state_path is None:
        state_path = STATE
    if not state_path.exists():
        return None
    try:
        state = json.loads(state_path.read_text())
    except json.JSONDecodeError:
        return None

    history = state.get("history") or []
    if len(history) < 5:
        return None

    last_meta_check_turn = state.get("last_meta_check_turn", 0)
    current_turn = history[-1].get("turn", 0)
    if current_turn <= last_meta_check_turn:
        return None  # already checked this turn

    investigations = state.get("investigations") or {}

    today = dt.date.today().isoformat() if False else __import__("datetime").date.today().isoformat()

    for trigger_id, trig in META_TRIGGERS.items():
        if not trig["condition"](history):
            continue

        inv_id = trig["investigation_id_template"].format(date=today)
        if inv_id in investigations:
            # Already spawned today
            continue

        # Spawn it
        spawned = {
            "id": inv_id,
            "kind": "meta",
            "title": trig["title"],
            "hypothesis": trig["hypothesis"],
            "flow_template": "meta-improvement",
            "current_stage": "Observe",
            "stages_done": [],
            "target_metric": trig["target_metric"],
            "baseline_value": None,  # researcher fills in at Observe stage
            "baseline_window": f"last {trig['window']} turns up to T{current_turn}",
            "predicted_improvement": None,  # theorist fills at Hypothesize
            "modifies_files": trig["modifies_files"],
            "rollback_branch": "main",
            "safety_class": "low",
            "auto_spawned_by_trigger": trigger_id,
            "auto_spawned_at_turn": current_turn,
            "falsifiers": [],
            "tier_current": 0,
            "tier_target": 1,
            "priority": trig["priority"],
            "blocked_on": None,
            "next_stage": "Hypothesize",
            "next_stage_action": f"researcher Observe stage already triggered this auto-spawn; theorist Hypothesize next",
        }

        # Atomically update state.json
        state["investigations"][inv_id] = spawned
        state["last_meta_check_turn"] = current_turn
        state_path.write_text(json.dumps(state, indent=2, default=str))
        return spawned

    # No trigger fired; still mark this turn as checked
    state["last_meta_check_turn"] = current_turn
    state_path.write_text(json.dumps(state, indent=2, default=str))
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--turn", type=int, default=None)
    ap.add_argument("--check-meta-spawn", action="store_true",
                    help="run maybe_spawn_meta_investigation() side-effect")
    args = ap.parse_args()

    if args.check_meta_spawn:
        spawned = maybe_spawn_meta_investigation()
        if spawned:
            print(json.dumps({"spawned": spawned["id"], "trigger": spawned.get("auto_spawned_by_trigger")}, indent=2))
        else:
            print(json.dumps({"spawned": None}, indent=2))
        return 0

    result = compute(target_turn=args.turn)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
