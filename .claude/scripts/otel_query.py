#!/usr/bin/env python3
"""Agent-friendly OTEL queries (2026-05-18).

Reads `.claude/logs/otel_traces.ndjson` and returns pre-aggregated
summaries suitable for ingesting into a director / critic / theorist
context. Output is compact JSON / TSV so agents don't pay the cost
of grep-ing raw 1MB+ trace files.

Per anko 2026-05-18: AI consumers don't need Grafana — they need
direct query primitives. This script is the query layer.

Usage:
    otel_query.py cost-trend [--last N]
    otel_query.py drift-histogram [--last N]
    otel_query.py tier-progression --inv <id>
    otel_query.py verdict-mix [--last N]
    otel_query.py investigation-summary --inv <id>
    otel_query.py budget-busts [--last N]
    otel_query.py overview
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

OTEL_PATH = Path("/home/suzume/workspace/BEC-simulation/.claude/logs/otel_traces.ndjson")


def _read_events() -> list[dict]:
    if not OTEL_PATH.exists():
        return []
    events = []
    for line in OTEL_PATH.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return events


def _last_n_turns(events: list[dict], n: int) -> list[dict]:
    # Find max turn seen
    turns = set()
    for e in events:
        t = (e.get("attributes") or {}).get("turn")
        if isinstance(t, (int, float)):
            turns.add(int(t))
    if not turns:
        return events
    cutoff = max(turns) - n + 1
    return [
        e for e in events
        if (e.get("attributes") or {}).get("turn") is None
        or int((e.get("attributes") or {}).get("turn", 0)) >= cutoff
    ]


def cost_trend(last_n: int = 20) -> dict:
    evs = _last_n_turns(_read_events(), last_n)
    pts = []
    for e in evs:
        if e.get("name") == "loop.cost_eff_per_turn":
            t = (e.get("attributes") or {}).get("turn")
            pts.append({"turn": int(t), "eff": int(e["value"]),
                        "verdict": (e.get("attributes") or {}).get("verdict")})
    pts.sort(key=lambda p: p["turn"])
    median = (sorted([p["eff"] for p in pts])[len(pts)//2] if pts else None)
    return {"points": pts, "median_eff": median, "n": len(pts)}


def drift_histogram(last_n: int = 30) -> dict:
    evs = _last_n_turns(_read_events(), last_n)
    counter: dict[str, int] = defaultdict(int)
    for e in evs:
        n = e.get("name", "")
        if n.startswith("loop.drift_signal."):
            counter[n.replace("loop.drift_signal.", "")] += 1
    return dict(sorted(counter.items(), key=lambda kv: -kv[1]))


def tier_progression(inv_id: str) -> dict:
    evs = _read_events()
    pts = []
    for e in evs:
        if e.get("name") != "loop.investigation.tier_current":
            continue
        if (e.get("attributes") or {}).get("investigation_id") != inv_id:
            continue
        pts.append({"turn": (e.get("attributes") or {}).get("turn"),
                    "tier": e["value"]})
    pts.sort(key=lambda p: p["turn"] or 0)
    return {"investigation_id": inv_id, "trajectory": pts}


def verdict_mix(last_n: int = 30) -> dict:
    evs = _last_n_turns(_read_events(), last_n)
    counter: dict[str, int] = defaultdict(int)
    for e in evs:
        n = e.get("name", "")
        if n.startswith("loop.judge.verdict."):
            counter[n.replace("loop.judge.verdict.", "")] += int(e["value"])
    return dict(sorted(counter.items(), key=lambda kv: -kv[1]))


def budget_busts(last_n: int = 30) -> dict:
    evs = _last_n_turns(_read_events(), last_n)
    busts: list[dict] = []
    for e in evs:
        n = e.get("name", "")
        if n.startswith("loop.cost_audit.BUDGET_"):
            flag = n.replace("loop.cost_audit.", "")
            if flag in ("BUDGET_BUSTED", "BUDGET_OVER"):
                a = e.get("attributes") or {}
                busts.append({"turn": a.get("turn"), "flag": flag, "ratio": a.get("ratio")})
    busts.sort(key=lambda b: b["turn"] or 0)
    return {"busts": busts, "n": len(busts)}


def investigation_summary(inv_id: str) -> dict:
    evs = _read_events()
    turns_seen: set[int] = set()
    verdicts: dict[str, int] = defaultdict(int)
    total_cost = 0
    tiers: list[float] = []
    for e in evs:
        a = e.get("attributes") or {}
        if a.get("investigation_id") != inv_id:
            continue
        t = a.get("turn")
        if isinstance(t, (int, float)):
            turns_seen.add(int(t))
        if e.get("name") == "loop.cost_eff_per_turn" and isinstance(e.get("value"), (int, float)):
            total_cost += int(e["value"])
        if e.get("name") == "loop.investigation.tier_current":
            tiers.append(e["value"])
        if e.get("name", "").startswith("loop.judge.verdict.") and e.get("type") == "metric":
            v = e["name"].replace("loop.judge.verdict.", "")
            verdicts[v] += 1
    return {
        "investigation_id": inv_id,
        "n_turns": len(turns_seen),
        "turns": sorted(turns_seen),
        "total_cost_eff": total_cost,
        "tier_min": min(tiers) if tiers else None,
        "tier_max": max(tiers) if tiers else None,
        "tier_latest": tiers[-1] if tiers else None,
        "verdict_mix": dict(verdicts),
    }


def retry_cost_by_investigation(min_turns: int = 2) -> dict:
    """Per-investigation retry-cost telemetry (2026-05-19, Opus-vs-Sonnet
    ablation support). Aggregates from state.json history (it has the
    investigation_id + judge_status + tokens_used fields).

    For each investigation with >= min_turns history entries:
      - total turns
      - n_fail / n_inconclusive / n_pass
      - cumulative effective tokens (sum of effective_full_rate)
      - retry_ratio = (n_fail + n_inconclusive) / total
      - cost_per_pass = total_eff / max(n_pass, 1)
    """
    import json
    from pathlib import Path
    state_path = Path("/home/suzume/workspace/BEC-simulation/runs/_loop/state.json")
    try:
        state = json.loads(state_path.read_text())
    except Exception as exc:
        return {"error": f"state.json unreadable: {exc}"}
    history = state.get("history") or []

    by_inv: dict[str, dict] = {}
    for h in history:
        inv = h.get("investigation_id")
        if not inv:
            continue
        rec = by_inv.setdefault(inv, {
            "n_turns": 0, "n_pass": 0, "n_fail": 0, "n_inconclusive": 0,
            "n_other": 0, "total_eff_cost": 0, "turns": [],
        })
        rec["n_turns"] += 1
        rec["turns"].append(h.get("turn"))
        status = h.get("judge_status") or ""
        if status.startswith("PASS"):
            rec["n_pass"] += 1
        elif status.startswith("FAIL") or status == "REFUTED":
            rec["n_fail"] += 1
        elif status == "INCONCLUSIVE":
            rec["n_inconclusive"] += 1
        else:
            rec["n_other"] += 1
        eff = ((h.get("tokens_used") or {}).get("effective_full_rate") or 0)
        if isinstance(eff, (int, float)):
            rec["total_eff_cost"] += int(eff)

    out: list[dict] = []
    for inv, rec in by_inv.items():
        if rec["n_turns"] < min_turns:
            continue
        retry_ratio = (rec["n_fail"] + rec["n_inconclusive"]) / rec["n_turns"]
        out.append({
            "investigation_id": inv,
            **{k: v for k, v in rec.items() if k != "turns"},
            "turn_first_last": [min(rec["turns"]), max(rec["turns"])] if rec["turns"] else None,
            "retry_ratio": round(retry_ratio, 3),
            "cost_per_pass": rec["total_eff_cost"] // max(rec["n_pass"], 1),
        })
    out.sort(key=lambda x: -x["total_eff_cost"])
    return {
        "by_investigation": out,
        "totals": {
            "n_investigations": len(out),
            "grand_total_eff_cost": sum(r["total_eff_cost"] for r in out),
            "median_retry_ratio": (sorted(r["retry_ratio"] for r in out)[len(out) // 2]
                                   if out else None),
        },
    }


def portfolio() -> dict:
    """Cross-investigation analytics view (2026-05-20, backlog #4).

    Aggregates all investigations from state.json into a portfolio
    snapshot useful for director/anko EXPLORE-vs-EXPLOIT decisions.

    For each investigation:
      - n_turns (from history), n_pass, n_fail, n_inconclusive
      - retry_ratio
      - total_eff_cost
      - tier_current, tier_target
      - current_stage, kind, flow_template
      - days_since_first_turn (age)
      - 20-turn-pit flag (n_turns >= 20 AND tier_current < 3)
      - clean-Tier-3 flag (n_turns <= 7 AND tier_current >= 3)

    Portfolio-level metrics:
      - total Tier-3 closures (firm)
      - portfolio retry_ratio (token-weighted average)
      - cost-per-Tier-3 (total spend / n_firm_tier_3)
      - sunk-cost ratio (cost on unfinished invs / total cost)
      - by-flow-template aggregation
    """
    import json
    from pathlib import Path
    state_path = Path("/home/suzume/workspace/BEC-simulation/runs/_loop/state.json")
    state = json.loads(state_path.read_text())
    history = state.get("history") or []
    invs = state.get("investigations") or {}

    # Aggregate history by inv
    inv_stats: dict[str, dict] = {}
    for h in history:
        inv = h.get("investigation_id")
        if not inv:
            continue
        r = inv_stats.setdefault(inv, {
            "n_turns": 0, "n_pass": 0, "n_fail": 0, "n_inconclusive": 0,
            "n_other": 0, "total_eff_cost": 0, "turns": [],
        })
        r["n_turns"] += 1
        r["turns"].append(h.get("turn"))
        status = h.get("judge_status") or ""
        if status.startswith("PASS"):
            r["n_pass"] += 1
        elif status.startswith("FAIL") or status == "REFUTED":
            r["n_fail"] += 1
        elif status == "INCONCLUSIVE":
            r["n_inconclusive"] += 1
        else:
            r["n_other"] += 1
        eff = ((h.get("tokens_used") or {}).get("effective_full_rate") or 0)
        if isinstance(eff, (int, float)):
            r["total_eff_cost"] += int(eff)

    rows = []
    for inv_id, inv in invs.items():
        s = inv_stats.get(inv_id, {})
        n_turns = s.get("n_turns", 0)
        tier_cur = inv.get("tier_current", 0) or 0
        tier_tgt = inv.get("tier_target", 0) or 0
        cur_stage = (inv.get("current_stage") or "?").split()[0]
        rows.append({
            "investigation_id": inv_id,
            "kind": inv.get("kind", "physics"),
            "flow_template": inv.get("flow_template", "unknown"),
            "current_stage": cur_stage,
            "tier_current": tier_cur,
            "tier_target": tier_tgt,
            "n_turns": n_turns,
            "n_pass": s.get("n_pass", 0),
            "n_fail": s.get("n_fail", 0),
            "n_inconclusive": s.get("n_inconclusive", 0),
            "retry_ratio": (
                round((s.get("n_fail", 0) + s.get("n_inconclusive", 0)) / n_turns, 3)
                if n_turns > 0 else None
            ),
            "total_eff_cost": s.get("total_eff_cost", 0),
            "priority": inv.get("priority"),
            "blocked_on": inv.get("blocked_on"),
            "is_20turn_pit": n_turns >= 20 and tier_cur < 3,
            "is_clean_tier3": n_turns <= 7 and tier_cur >= 3,
            "tier_clamped": inv.get("tier_clamped_at") is not None,
        })

    rows.sort(key=lambda r: -r["total_eff_cost"])

    # Portfolio-level aggregates
    n_firm_tier3 = sum(1 for r in rows if r["is_clean_tier3"])
    n_20turn_pits = sum(1 for r in rows if r["is_20turn_pit"])
    n_tier_clamped = sum(1 for r in rows if r["tier_clamped"])
    total_cost = sum(r["total_eff_cost"] for r in rows)
    finished_cost = sum(r["total_eff_cost"] for r in rows
                        if (r["current_stage"] == "closed" and r["tier_current"] >= 3))
    sunk_cost_ratio = (
        round((total_cost - finished_cost) / total_cost, 3)
        if total_cost > 0 else None
    )

    by_template: dict[str, dict] = {}
    for r in rows:
        ft = r["flow_template"]
        b = by_template.setdefault(ft, {"n_invs": 0, "total_cost": 0,
                                        "n_firm_tier3": 0, "n_pits": 0})
        b["n_invs"] += 1
        b["total_cost"] += r["total_eff_cost"]
        if r["is_clean_tier3"]: b["n_firm_tier3"] += 1
        if r["is_20turn_pit"]: b["n_pits"] += 1

    # Recent activity (last 10 history turns by investigation)
    recent_active = {}
    for h in history[-10:]:
        inv = h.get("investigation_id")
        if inv:
            recent_active[inv] = recent_active.get(inv, 0) + 1

    return {
        "by_investigation": rows,
        "portfolio_summary": {
            "n_investigations": len(rows),
            "n_firm_tier3": n_firm_tier3,
            "n_20turn_pits": n_20turn_pits,
            "n_tier_clamped_retroactive": n_tier_clamped,
            "total_eff_cost": total_cost,
            "cost_per_firm_tier3": (total_cost // n_firm_tier3 if n_firm_tier3 else None),
            "sunk_cost_ratio": sunk_cost_ratio,
            "by_flow_template": by_template,
            "recent_active_last10_turns": recent_active,
        },
    }


def overview() -> dict:
    evs = _read_events()
    turns = set()
    cost_total = 0
    verdicts: dict[str, int] = defaultdict(int)
    investigations: set[str] = set()
    for e in evs:
        a = e.get("attributes") or {}
        if "turn" in a and isinstance(a["turn"], (int, float)):
            turns.add(int(a["turn"]))
        if e.get("name") == "loop.cost_eff_per_turn" and isinstance(e.get("value"), (int, float)):
            cost_total += int(e["value"])
        if e.get("name", "").startswith("loop.judge.verdict."):
            v = e["name"].replace("loop.judge.verdict.", "")
            verdicts[v] += int(e.get("value", 1))
        if isinstance(a.get("investigation_id"), str):
            investigations.add(a["investigation_id"])
    return {
        "n_turns": len(turns),
        "turn_range": [min(turns), max(turns)] if turns else None,
        "total_cost_eff": cost_total,
        "avg_cost_per_turn": cost_total // len(turns) if turns else 0,
        "verdict_mix": dict(sorted(verdicts.items(), key=lambda kv: -kv[1])),
        "n_investigations_touched": len(investigations),
        "investigations": sorted(investigations),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    for cmd in ("cost-trend", "drift-histogram", "verdict-mix", "budget-busts"):
        p = sub.add_parser(cmd)
        p.add_argument("--last", type=int, default=20)

    p_inv = sub.add_parser("tier-progression")
    p_inv.add_argument("--inv", required=True)

    p_is = sub.add_parser("investigation-summary")
    p_is.add_argument("--inv", required=True)

    sub.add_parser("overview")
    p_retry = sub.add_parser("retry-cost")
    p_retry.add_argument("--min-turns", type=int, default=2)
    sub.add_parser("portfolio")

    args = ap.parse_args()
    if args.cmd == "cost-trend":
        r = cost_trend(args.last)
    elif args.cmd == "drift-histogram":
        r = drift_histogram(args.last)
    elif args.cmd == "verdict-mix":
        r = verdict_mix(args.last)
    elif args.cmd == "budget-busts":
        r = budget_busts(args.last)
    elif args.cmd == "tier-progression":
        r = tier_progression(args.inv)
    elif args.cmd == "investigation-summary":
        r = investigation_summary(args.inv)
    elif args.cmd == "overview":
        r = overview()
    elif args.cmd == "retry-cost":
        r = retry_cost_by_investigation(args.min_turns)
    elif args.cmd == "portfolio":
        r = portfolio()
    else:
        return 1

    print(json.dumps(r, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
