#!/usr/bin/env python3
"""Append a turn narrative to runs/_loop/status/<inv_id>.md (Item 6, 2026-05-18).

Living STATUS.md per investigation thread — narrative complement to
state.json structured data. Each turn, loop.sh post-step calls this
with --inv-id and --turn args; the script reads judge/turn_N.json
and history entry to append a one-paragraph entry.
"""

from __future__ import annotations
import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path("/home/suzume/workspace/BEC-simulation/runs/_loop")
STATE = ROOT / "state.json"
STATUS_DIR = ROOT / "status"


def safe_filename(s: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_.\-]", "_", s)


def append_turn_narrative(inv_id: str, turn: int) -> dict:
    STATUS_DIR.mkdir(parents=True, exist_ok=True)
    out_path = STATUS_DIR / f"{safe_filename(inv_id)}.md"

    if not STATE.exists():
        return {"ok": False, "reason": "state.json missing"}
    state = json.loads(STATE.read_text())
    investigations = state.get("investigations") or {}
    inv = investigations.get(inv_id)
    if not inv:
        return {"ok": False, "reason": f"investigation {inv_id} not in state"}

    judge_path = ROOT / "judge" / f"turn_{turn}.json"
    judge = {}
    if judge_path.exists():
        try:
            judge = json.loads(judge_path.read_text())
        except json.JSONDecodeError:
            pass

    history = state.get("history") or []
    history_entry = next((h for h in history if h.get("turn") == turn), {})

    now = datetime.now(timezone.utc).astimezone().isoformat()
    verdict = judge.get("status") or history_entry.get("judge_status", "?")
    stage = inv.get("current_stage", "?")
    tier = inv.get("tier_current", "?")
    label = history_entry.get("directive_label", "?")
    cost = (history_entry.get("tokens_used") or {}).get("effective_full_rate")
    cost_str = f"{cost//1000}k" if isinstance(cost, int) else "?"

    # Initialize STATUS.md if new
    if not out_path.exists():
        out_path.write_text(
            f"# Investigation thread — {inv_id}\n\n"
            f"**Title**: {inv.get('title', '?')}\n\n"
            f"**Hypothesis**: {inv.get('hypothesis', '?')}\n\n"
            f"**Flow template**: {inv.get('flow_template', '?')}\n\n"
            f"**Tier target**: {inv.get('tier_target', '?')}\n\n"
            f"## Turn-by-turn narrative\n\n"
        )

    # Append entry
    issues = judge.get("issues") or []
    issues_summary = ""
    if issues:
        issues_summary = " — " + "; ".join(s[:120] for s in issues[:2])

    entry = (
        f"### T{turn} ({now}) — {verdict} — `{label}`\n\n"
        f"- Stage: **{stage}**, tier: {tier}\n"
        f"- Cost: {cost_str} effective tokens\n"
    )
    if issues:
        entry += f"- Issues: {issues_summary.lstrip(' — ')}\n"
    contract_eval = judge.get("contract_evaluation") or {}
    if contract_eval.get("verdict"):
        entry += f"- Contract: {contract_eval['verdict']}\n"
    cost_audit = judge.get("cost_audit") or {}
    if cost_audit.get("flag") and cost_audit["flag"] != "BUDGET_OK":
        entry += f"- Budget audit: {cost_audit['flag']} (actual/expected = {cost_audit.get('ratio_actual_over_expected', '?')})\n"
    entry += "\n"

    with out_path.open("a") as f:
        f.write(entry)

    return {"ok": True, "wrote": str(out_path.relative_to(ROOT.parent)), "verdict": verdict}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--inv-id", required=True)
    ap.add_argument("--turn", required=True, type=int)
    args = ap.parse_args()
    r = append_turn_narrative(args.inv_id, args.turn)
    print(json.dumps(r))
    return 0 if r["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
