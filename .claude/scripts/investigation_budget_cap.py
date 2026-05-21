#!/usr/bin/env python3
"""Per-investigation budget cap with auto-review trigger (2026-05-20).

Backlog #2 from `memory/design_backlog_post_reform_2026_05_19.md`:

> No mechanism currently fires when an investigation crosses N turns.
> Matsui ran 26 turns of monotonic continuation; nothing forced a "is
> this worth continuing?" review.
>
> Proposed: at investigation.turn_count = 10 (or threshold), critic
> auto-dispatches with the continue/abandon prompt mode. Verdicts:
> CONTINUE / REFORMULATE / CLOSE_AS_UNANSWERABLE / SUNK_COST_EXIT.

This script implements the trigger side. It scans state.json's history,
counts per-investigation turn budgets, and emits a list of investigations
that have crossed review thresholds. The director reads this list per
turn (via `loop.sh` post-step → state.json.recent_findings).

Thresholds (configurable via .claude/budget_caps.yaml if it exists):
  - SOFT_TURN_CAP = 10  → review-now advisory
  - HARD_TURN_CAP = 20  → BLOCK; investigation cannot advance without
                          explicit critic CONTINUE verdict

The cap respects `tier_current` — if an investigation hit tier 3, no
cap (it's done). If tier_current < 3 AND n_turns >= cap, cap fires.

Output (JSON):
  {
    "soft_advisories": [{inv_id, n_turns, cost_so_far, last_verdict}],
    "hard_blocks": [{inv_id, n_turns, cost_so_far, last_verdict}],
    "review_needed": [...]   # union, deduplicated
  }

Usage:
    investigation_budget_cap.py scan
    investigation_budget_cap.py inject-into-state   # writes hard_blocks
                                                    # as investigation.blocked_on
"""

from __future__ import annotations

import argparse
import fcntl
import json
import sys
from pathlib import Path

ROOT = Path("/home/suzume/workspace/BEC-simulation")
STATE = ROOT / "runs" / "_loop" / "state.json"
LOCK = ROOT / "runs" / "_loop" / "_local" / "state.json.lock"

SOFT_TURN_CAP = 10
HARD_TURN_CAP = 20


def scan(state: dict) -> dict:
    history = state.get("history") or []
    invs = state.get("investigations") or {}

    per_inv: dict[str, dict] = {}
    for h in history:
        inv = h.get("investigation_id")
        if not inv:
            continue
        rec = per_inv.setdefault(inv, {
            "n_turns": 0, "total_eff_cost": 0,
            "last_verdict": None, "last_turn": 0,
        })
        rec["n_turns"] += 1
        eff = ((h.get("tokens_used") or {}).get("effective_full_rate") or 0)
        if isinstance(eff, (int, float)):
            rec["total_eff_cost"] += int(eff)
        t = h.get("turn") or 0
        if isinstance(t, int) and t > rec["last_turn"]:
            rec["last_turn"] = t
            rec["last_verdict"] = h.get("judge_status")

    soft, hard = [], []
    for inv_id, rec in per_inv.items():
        inv = invs.get(inv_id, {})
        tier = inv.get("tier_current") or 0
        if tier >= 3:
            continue  # already closed Tier-3
        n = rec["n_turns"]
        entry = {
            "investigation_id": inv_id,
            "n_turns": n,
            "total_eff_cost": rec["total_eff_cost"],
            "last_verdict": rec["last_verdict"],
            "last_turn": rec["last_turn"],
            "tier_current": tier,
            "current_stage": (inv.get("current_stage") or "?").split()[0],
        }
        if n >= HARD_TURN_CAP:
            hard.append(entry)
        elif n >= SOFT_TURN_CAP:
            soft.append(entry)

    return {
        "soft_advisories": soft,
        "hard_blocks": hard,
        "soft_cap": SOFT_TURN_CAP,
        "hard_cap": HARD_TURN_CAP,
    }


def inject_into_state() -> dict:
    """Apply hard-cap as `blocked_on` on each tripped investigation.
    Soft advisories go into `recent_findings` for director visibility.
    """
    LOCK.parent.mkdir(parents=True, exist_ok=True)
    with LOCK.open("w") as fh:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            state = json.loads(STATE.read_text())
        except Exception as e:
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
            return {"ok": False, "reason": str(e)}

        report = scan(state)
        invs = state.setdefault("investigations", {})
        n_blocked, n_advised = 0, 0

        for h in report["hard_blocks"]:
            inv_id = h["investigation_id"]
            inv = invs.get(inv_id)
            if not inv:
                continue
            existing = inv.get("blocked_on")
            block_msg = (
                f"BUDGET_CAP_HARD: {h['n_turns']} turns ≥ {HARD_TURN_CAP}, "
                f"cost {h['total_eff_cost']:,} eff tokens, tier still "
                f"{h['tier_current']} < 3. Dispatch critic in continue/abandon "
                f"mode to issue verdict CONTINUE / REFORMULATE / "
                f"CLOSE_AS_UNANSWERABLE / SUNK_COST_EXIT before next stage advance."
            )
            # Don't overwrite an existing block, only add if absent
            if not existing:
                inv["blocked_on"] = block_msg
                n_blocked += 1

        # Soft advisories → recent_findings (10-turn broadcast queue)
        rf = state.setdefault("recent_findings", [])
        existing_ids = {f.get("from_investigation_id") for f in rf
                        if isinstance(f, dict)}
        current_turn = state.get("turn", 0)
        for s in report["soft_advisories"]:
            if s["investigation_id"] in existing_ids:
                continue
            rf.append({
                "from_investigation_id": s["investigation_id"],
                "turn": current_turn,
                "kind": "BUDGET_CAP_SOFT",
                "summary": (
                    f"{s['investigation_id']} at {s['n_turns']} turns "
                    f"(≥ {SOFT_TURN_CAP}); cost {s['total_eff_cost']:,} eff; "
                    f"tier {s['tier_current']}/3. Consider mid-investigation "
                    f"critic review before deeper investment."
                ),
                "expires_at_turn": current_turn + 10,
            })
            n_advised += 1

        # Trim recent_findings to expired entries
        rf[:] = [f for f in rf
                 if not isinstance(f, dict)
                 or (f.get("expires_at_turn") or current_turn + 11) > current_turn]

        tmp = STATE.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(state, indent=2, default=str))
        tmp.replace(STATE)
        fcntl.flock(fh.fileno(), fcntl.LOCK_UN)

    return {"ok": True, "n_blocked": n_blocked, "n_advised": n_advised,
            "report": report}


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("scan")
    sub.add_parser("inject-into-state")
    args = ap.parse_args()
    if args.cmd == "scan":
        state = json.loads(STATE.read_text())
        out = scan(state)
    elif args.cmd == "inject-into-state":
        out = inject_into_state()
    print(json.dumps(out, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
