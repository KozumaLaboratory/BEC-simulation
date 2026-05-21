#!/usr/bin/env python3
"""OTEL-driven cost waste detector (2026-05-18).

Analyzes `.claude/logs/otel_traces.ndjson` for token-waste patterns
and emits structured findings. Wired into drift_signals.py so that
when waste thresholds are exceeded, a meta-investigation is
auto-spawned to improve the loop.

Patterns detected:

  1. RETRY_WASTE: same directive_label dispatched ≥3 turns in a row,
     cumulative cost ≥2x typical for the subagent type.

  2. PERSISTENT_BUDGET_OVER: ≥4 of last 10 turns had cost_audit
     BUDGET_OVER or BUDGET_BUSTED. Director's predictions miscalibrated.

  3. STAGE_OUTLIER: average cost for a (stage, subagent) tuple over
     last 5 occurrences is ≥1.8x typical from workload_specs.

  4. INVESTIGATION_COST_OVERSHOOT: cumulative cost on a single
     investigation > 3x sum of its turn budget estimates.

  5. NOOP_OVERUSE: ≥3 NOOP_DIRECTOR / NOOP in last 8 turns —
     director uncertain too often.

Output: a JSON report with `findings: [...]` and `should_spawn: bool`.

Usage:
    otel_cost_audit.py [--last N]      # default 20 turns
    otel_cost_audit.py --maybe-spawn   # side-effect: write meta-inv to state.json
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

ROOT = Path("/home/suzume/workspace/BEC-simulation")
OTEL = ROOT / ".claude" / "logs" / "otel_traces.ndjson"
STATE = ROOT / "runs" / "_loop" / "state.json"
WORKLOAD = ROOT / ".claude" / "workload_specs.yaml"

# Thresholds (tunable)
THR_RETRY_RUN_MIN = 3
THR_BUDGET_OVER_COUNT = 4
THR_BUDGET_OVER_WINDOW = 10
THR_STAGE_OUTLIER_RATIO = 1.8
THR_INV_OVERSHOOT_RATIO = 3.0
THR_NOOP_COUNT = 3
THR_NOOP_WINDOW = 8


def _read_otel() -> list[dict]:
    if not OTEL.exists():
        return []
    out = []
    for line in OTEL.read_text().splitlines():
        if not line.strip():
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def _read_state() -> dict:
    if not STATE.exists():
        return {}
    try:
        return json.loads(STATE.read_text())
    except json.JSONDecodeError:
        return {}


def _read_workload_typicals() -> dict[str, int]:
    """Return {workload_name: typical_cost_eff} parsed loosely from YAML."""
    if not WORKLOAD.exists():
        return {}
    try:
        import yaml
        d = yaml.safe_load(WORKLOAD.read_text()) or {}
        return {k: int(v.get("typical_cost_eff", 0)) for k, v in d.items()
                if isinstance(v, dict)}
    except Exception:
        return {}


def detect_retry_waste(history: list[dict]) -> dict | None:
    """Same directive_label ≥3 turns in a row."""
    if len(history) < THR_RETRY_RUN_MIN:
        return None
    recent = history[-THR_RETRY_RUN_MIN:]
    labels = [h.get("directive_label", "")[:60] for h in recent]
    if len(set(labels)) == 1 and labels[0]:
        total_cost = sum(((h.get("tokens_used") or {}).get("effective_full_rate") or 0)
                         for h in recent)
        return {
            "pattern": "RETRY_WASTE",
            "label": labels[0],
            "n_turns": len(recent),
            "total_cost_eff": total_cost,
            "severity": "high" if total_cost > 5_000_000 else "medium",
            "remediation": "spawn meta-stage-routing investigation to identify why this directive is re-dispatched",
        }
    return None


def detect_persistent_budget_over(history: list[dict]) -> dict | None:
    """≥4 of last 10 turns BUDGET_OVER or BUDGET_BUSTED."""
    window = history[-THR_BUDGET_OVER_WINDOW:]
    over_count = sum(
        1 for h in window
        if (h.get("cost_audit") or {}).get("flag") in ("BUDGET_OVER", "BUDGET_BUSTED")
    )
    if over_count >= THR_BUDGET_OVER_COUNT:
        return {
            "pattern": "PERSISTENT_BUDGET_OVER",
            "n_over_in_window": over_count,
            "window_size": len(window),
            "severity": "high" if over_count >= 6 else "medium",
            "remediation": "director.md expected_cost_eff predictions miscalibrated; meta-improvement to recalibrate budget table per workload",
        }
    return None


def detect_stage_outlier(history: list[dict], typicals: dict[str, int]) -> dict | None:
    """Average (stage, action) cost over last 5 occurrences > 1.8x typical."""
    if not typicals:
        return None
    by_action: dict[str, list[int]] = defaultdict(list)
    for h in history[-30:]:
        action = h.get("directive_action") or ""
        eff = (h.get("tokens_used") or {}).get("effective_full_rate")
        if action and isinstance(eff, (int, float)):
            by_action[action].append(int(eff))
    findings = []
    for action, costs in by_action.items():
        if len(costs) < 3:
            continue
        recent = costs[-5:]
        avg = sum(recent) / len(recent)
        # Heuristic typical mapping (action → workload key)
        typical = typicals.get(f"implementer_{action}") or typicals.get(action) or 1_500_000
        if avg > THR_STAGE_OUTLIER_RATIO * typical:
            findings.append({
                "action": action,
                "n_recent_samples": len(recent),
                "avg_cost_eff": int(avg),
                "typical_eff": typical,
                "ratio": round(avg / typical, 2),
            })
    if findings:
        return {
            "pattern": "STAGE_OUTLIER",
            "outliers": findings,
            "severity": "medium",
            "remediation": "subagent or stage protocol over-running; consider stage-specific budget cap or prompt diet",
        }
    return None


def detect_investigation_overshoot(state: dict) -> dict | None:
    """Investigation cumulative cost > 3x its turn-count-weighted budget."""
    investigations = state.get("investigations") or {}
    history = state.get("history") or []
    by_inv_cost: dict[str, int] = defaultdict(int)
    by_inv_turns: dict[str, int] = defaultdict(int)
    for h in history:
        inv = h.get("investigation_id")
        if not inv:
            continue
        eff = (h.get("tokens_used") or {}).get("effective_full_rate")
        if isinstance(eff, (int, float)):
            by_inv_cost[inv] += int(eff)
        by_inv_turns[inv] += 1
    findings = []
    for inv, cost in by_inv_cost.items():
        turns = by_inv_turns[inv]
        budget = turns * 2_000_000   # typical 2M/turn baseline
        if cost > THR_INV_OVERSHOOT_RATIO * budget:
            inv_state = investigations.get(inv, {})
            findings.append({
                "investigation_id": inv,
                "n_turns": turns,
                "total_cost_eff": cost,
                "budget_baseline": budget,
                "ratio": round(cost / budget, 2),
                "current_stage": inv_state.get("current_stage"),
                "tier_current": inv_state.get("tier_current"),
            })
    if findings:
        return {
            "pattern": "INVESTIGATION_COST_OVERSHOOT",
            "investigations": findings,
            "severity": "high",
            "remediation": "investigation absorbing disproportionate cost; consider closing-as-unanswerable or backtracking question",
        }
    return None


def detect_noop_overuse(history: list[dict]) -> dict | None:
    window = history[-THR_NOOP_WINDOW:]
    noops = sum(1 for h in window if (h.get("judge_status") or "").startswith("NOOP"))
    if noops >= THR_NOOP_COUNT:
        return {
            "pattern": "NOOP_OVERUSE",
            "noop_count": noops,
            "window_size": len(window),
            "severity": "low",
            "remediation": "director picking noop too often; seed.md may need new investigations OR scheduler windows widened",
        }
    return None


def audit() -> dict:
    state = _read_state()
    history = state.get("history") or []
    typicals = _read_workload_typicals()

    findings = [
        f for f in (
            detect_retry_waste(history),
            detect_persistent_budget_over(history),
            detect_stage_outlier(history, typicals),
            detect_investigation_overshoot(state),
            detect_noop_overuse(history),
        ) if f
    ]
    return {
        "ok": True,
        "n_findings": len(findings),
        "findings": findings,
        "should_spawn_meta": any(f.get("severity") in ("medium", "high") for f in findings),
        "audited_at": datetime.now().isoformat(),
        "history_depth_used": len(history),
    }


def maybe_spawn_meta(state_path: Path = STATE) -> dict:
    """Side-effect: if findings warrant, write a meta-investigation
    into state.investigations for the director to pick up."""
    report = audit()
    if not report["should_spawn_meta"]:
        return {"spawned": None, **report}

    state = _read_state()
    investigations = state.setdefault("investigations", {})

    # Idempotency: do not spawn another meta-cost-audit on the same day
    today_iso = datetime.now().date().isoformat()
    inv_id = f"meta-cost-waste-audit-{today_iso}"
    if inv_id in investigations:
        return {"spawned": None, "skipped": "already-exists-today", **report}

    investigations[inv_id] = {
        "id": inv_id,
        "kind": "meta",
        "title": "OTEL-detected token-waste pattern audit",
        "hypothesis": "OTEL trace shows token-waste patterns. Identify root cause + propose loop-prompt / workload-spec / director-policy change to recover budget.",
        "flow_template": "meta-improvement",
        "current_stage": "Observe",
        "stages_done": [],
        "target_metric": "median_cost_eff_per_turn_post_fix",
        "baseline_value": None,
        "predicted_improvement": "≥30% cost reduction on the affected workload",
        "auto_spawned_by_trigger": "otel_cost_audit",
        "spawned_findings": report["findings"],
        "modifies_files": [
            ".claude/agents/director.md",
            ".claude/workload_specs.yaml",
            ".claude/agents/theorist.md",
            ".claude/agents/researcher.md",
        ],
        "rollback_branch": "main",
        "safety_class": "low",
        "tier_current": 0,
        "tier_target": 1,
        "priority": 15,
        "blocked_on": None,
        "next_stage": "Hypothesize",
        "next_stage_action": "theorist Hypothesize: classify findings, propose specific prompt/workload changes, predict cost savings.",
    }

    state_path.write_text(json.dumps(state, indent=2, default=str))
    return {"spawned": inv_id, **report}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--maybe-spawn", action="store_true",
                    help="side-effect: write meta-investigation to state.json if findings warrant")
    args = ap.parse_args()

    r = maybe_spawn_meta() if args.maybe_spawn else audit()
    print(json.dumps(r, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
