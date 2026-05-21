#!/usr/bin/env python3
"""Deterministic investigation picker (2026-05-19, reviewer #2+#3 + P8).

Moves the "which investigation to advance this turn" decision OUT of
director.md prompt judgment and INTO Python code. Per academic-frameworks
research P2: "flow lives in code, NOT prompt."

The director's job is reduced to: given a pre-chosen investigation +
stage + subagent, draft the §6 contract (rationale, brief, observable
manifest, success_criteria, budget). The director cannot override the
pick.

Input (read at turn start):
- runs/_loop/state.json
- runs/_loop/_local/scheduler_${N}.json (if exists)
- runs/_loop/seed.md (top section overrides)
- runs/eu151_* / runs/auto/* (sibling artifacts via glob)
- runs/_loop/judge/turn_$((N-1)).json (last verdict)

Output:
- runs/_loop/_local/director_pick_${N}.json with:
    investigation_id, stage_advancing_to, subagent_type,
    project_axis, decision_table_row_matched, sibling_artifacts_found

The director reads this file at top of turn (per director.md §Inputs)
and writes the §6 contract around it.

Decision table (first match wins, mirrors director.md):
1. seed.md highest-priority section names an investigation → pick it (hard-lock)
2. last verdict INCONCLUSIVE on inv X AND X is active → continue X at same stage
3. inv X has next_stage_action set + scheduler allows → continue X
4. inv X has sibling artifact in runs/<topic>*/ + tier<3 + last verdict not INCONCLUSIVE → ARTIFACT-FIRST: stage=Update (or flow-specific), subagent=critic
5. open inv with lowest priority (number) + scheduler allows → advance
6. open inv with largest tier_gap + scheduler allows → advance
7. nothing qualifies → noop

Usage:
    director_pick.py --turn N [--write-pick]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path("/home/suzume/workspace/BEC-simulation")
STATE = ROOT / "runs" / "_loop" / "state.json"
SEED = ROOT / "runs" / "_loop" / "seed.md"
LOCAL = ROOT / "runs" / "_loop" / "_local"

# Flow template → audit/review stage (for artifact-first path)
ARTIFACT_FIRST_STAGE_BY_FLOW = {
    "verify-claim": "Update",
    "build-theory": "Update",
    "fix-bug": "Test",
    "survey": "Triage",
    "meta-improvement": "Evaluate",
    "audit-class-scan": "Audit",
}

# Flow template → role per stage (mirrors director.md)
ROLE_BY_FLOW_STAGE = {
    "verify-claim": {
        "Research": "researcher",
        "Hypothesize": "theorist",
        "Design": "theorist",
        "Execute": "implementer",
        "Analyze": "theorist",
        "Update": "critic",
        "Document": "theorist",
    },
    "build-theory": {
        "Research": "researcher",
        "Hypothesize": "theorist",
        "Derive": "theorist",
        "Specialize": "theorist",
        "Test": "implementer",
        "Generalize": "theorist",
        "Update": "critic",
        "Document": "theorist",
    },
    "fix-bug": {
        "Reproduce": "implementer",
        "Hypothesize": "theorist",
        "Patch": "implementer",
        "Test": "implementer",
        "Land": "implementer",
        "Document": "theorist",
    },
    "survey": {
        "Inventory": "researcher",
        "Triage": "critic",
        "Report": "theorist",
    },
    "meta-improvement": {
        "Observe": "theorist",
        "Hypothesize": "theorist",
        "Design": "theorist",
        "Pilot": "implementer",
        "Evaluate": "critic",
        "Adopt/Revert": "critic",
        "Document": "theorist",
    },
    "audit-class-scan": {
        "Observe": "researcher",
        "Triage": "implementer",
        "Sample": "implementer",
        "Audit": "critic",
        "Patch": "implementer",
        "Verify": "critic",
        "Report": "theorist",
    },
}

# project_axis by flow_template
AXIS_BY_FLOW = {
    "verify-claim": "D1",
    "build-theory": "D3",
    "fix-bug": "D1",
    "survey": "D1",
    "meta-improvement": "D4",
    "audit-class-scan": "D4",
}


def _read_state() -> dict:
    return json.loads(STATE.read_text())


def _read_seed_top_priority() -> str | None:
    """Parse seed.md for top section that names an investigation.

    Looks for a heading like '## Highest priority NOW (date)' + body
    mentioning `investigation_id` in backticks. Returns the id or None.
    """
    if not SEED.exists():
        return None
    text = SEED.read_text(encoding="utf-8")
    # Find first ## section after the leading # title
    sections = re.split(r"\n## ", text, maxsplit=1)
    if len(sections) < 2:
        return None
    first_section = sections[1].split("\n## ")[0]
    # Look for backticked inv id (kebab-case, dates ok, case-insensitive).
    # Investigation IDs may contain uppercase (e.g. `Te1`, `T117`).
    m = re.search(r"`([A-Za-z][A-Za-z0-9-]{8,})`", first_section)
    if m:
        return m.group(1)
    return None


def _read_scheduler(turn: int) -> dict:
    """Last scheduler decision for this turn (loop.sh writes scheduler_${N}.json)."""
    p = LOCAL / f"scheduler_{turn}.json"
    if not p.exists():
        # try latest available
        candidates = sorted(LOCAL.glob("scheduler_*.json"), key=lambda x: x.stat().st_mtime, reverse=True)
        if candidates:
            p = candidates[0]
        else:
            return {}
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError:
        return {}


def _read_last_judge(turn: int) -> dict:
    p = ROOT / "runs" / "_loop" / "judge" / f"turn_{turn - 1}.json"
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError:
        return {}


def _has_sibling_artifact(inv: dict) -> tuple[bool, list[str]]:
    """Glob runs/ for non-trivial artifact dirs matching inv's topic."""
    runs_root = ROOT / "runs"
    # Derive topic keywords from inv id (split by hyphens, drop dates/numbers)
    inv_id = inv.get("id") or ""
    parts = [p for p in inv_id.split("-")
             if p and not p.isdigit() and not re.match(r"^\d{4}$", p)
             and p not in ("2026", "05", "06", "07", "vs", "T87", "T103", "T50", "T61")]
    if not parts:
        return False, []
    keyword = parts[0].lower()
    if len(keyword) < 3:
        return False, []
    matches = []
    for d in runs_root.glob(f"*{keyword}*"):
        if not d.is_dir():
            continue
        # Non-trivial = has at least one of these output artifacts
        for fname in ("trajectory.csv", "trajectory.png", "result.jld2", "result.json", "_live_status.json"):
            if (d / fname).exists():
                matches.append(str(d.relative_to(ROOT)))
                break
    return bool(matches), matches


def _eligible(inv: dict, scheduler: dict) -> bool:
    """Filter rules from director.md §B2 eliminate-from-consideration."""
    stage = (inv.get("current_stage") or "").lower()
    if stage.startswith("closed"):
        return False
    if stage == "dormant" and (inv.get("priority") or 99) >= 50:
        return False
    if inv.get("blocked_on"):
        # If scheduler clears the block, allow; otherwise filter
        allowed = scheduler.get("allowed_workloads") or []
        block = inv.get("blocked_on")
        if isinstance(block, str) and "scheduler" in block.lower():
            return False
    return True


def pick(turn: int) -> dict:
    state = _read_state()
    invs = state.get("investigations") or {}
    scheduler = _read_scheduler(turn)
    last_judge = _read_last_judge(turn)

    decision = {
        "turn": turn,
        "decision_table_row_matched": None,
        "investigation_id": None,
        "stage_advancing_to": None,
        "subagent_type": "noop",
        "project_axis": None,
        "flow_template": None,
        "sibling_artifacts_found": [],
        "rationale_seed": "",
    }

    # Row 1: seed.md hard-lock
    seed_inv_id = _read_seed_top_priority()
    if seed_inv_id and seed_inv_id in invs:
        inv = invs[seed_inv_id]
        if _eligible(inv, scheduler):
            flow = inv.get("flow_template", "verify-claim")
            decision["decision_table_row_matched"] = "1_seed_md_hard_lock"
            decision["investigation_id"] = seed_inv_id
            decision["flow_template"] = flow
            decision["project_axis"] = AXIS_BY_FLOW.get(flow, "D1")
            decision["rationale_seed"] = f"seed.md highest-priority section names `{seed_inv_id}` (hard-lock)"
            # Stage: prefer Update if sibling artifact exists, else next per flow
            has_sibling, paths = _has_sibling_artifact(inv)
            decision["sibling_artifacts_found"] = paths
            if has_sibling and (inv.get("tier_current") or 0) < 3:
                decision["stage_advancing_to"] = ARTIFACT_FIRST_STAGE_BY_FLOW.get(flow, "Update")
                decision["subagent_type"] = "critic"
                decision["rationale_seed"] += f"; artifact-first ({len(paths)} sibling dirs found)"
            else:
                # Default: continue from current_stage's next per flow, or use next_stage_action
                next_stage = inv.get("next_stage_action") or ""
                decision["stage_advancing_to"] = (re.match(r"\s*(\w+)", next_stage).group(1)
                                                  if next_stage and re.match(r"\s*\w+", next_stage)
                                                  else inv.get("current_stage", "?").split()[0])
                role = ROLE_BY_FLOW_STAGE.get(flow, {}).get(decision["stage_advancing_to"], "theorist")
                decision["subagent_type"] = role
            return decision

    # Row 2: INCONCLUSIVE continuation
    if last_judge.get("status") == "INCONCLUSIVE":
        last_inv_id = last_judge.get("investigation_id")
        if last_inv_id and last_inv_id in invs and _eligible(invs[last_inv_id], scheduler):
            inv = invs[last_inv_id]
            flow = inv.get("flow_template", "verify-claim")
            cur_stage = (inv.get("current_stage") or "").split()[0]
            decision["decision_table_row_matched"] = "2_inconclusive_continue"
            decision["investigation_id"] = last_inv_id
            decision["flow_template"] = flow
            decision["project_axis"] = AXIS_BY_FLOW.get(flow, "D1")
            decision["stage_advancing_to"] = cur_stage
            decision["subagent_type"] = ROLE_BY_FLOW_STAGE.get(flow, {}).get(cur_stage, "theorist")
            decision["rationale_seed"] = f"continuing INCONCLUSIVE {last_inv_id} at {cur_stage}"
            return decision

    # Row 3-4: walk all eligible, find next_stage_action OR artifact-first OR priority
    eligible = [(k, v) for k, v in invs.items() if _eligible(v, scheduler)]
    if not eligible:
        decision["decision_table_row_matched"] = "7_no_eligible_noop"
        decision["rationale_seed"] = "no eligible investigations"
        return decision

    # Row 3: continuation via next_stage_action (active inv with set field)
    # Row 4: artifact-first
    artifact_first_candidates = []
    for k, inv in eligible:
        if (inv.get("tier_current") or 0) < 3:
            has_sibling, paths = _has_sibling_artifact(inv)
            if has_sibling:
                artifact_first_candidates.append((k, inv, paths))

    if artifact_first_candidates:
        # Prefer highest-priority (lowest number) artifact-first inv
        artifact_first_candidates.sort(key=lambda t: t[1].get("priority", 99))
        k, inv, paths = artifact_first_candidates[0]
        flow = inv.get("flow_template", "verify-claim")
        decision["decision_table_row_matched"] = "4_artifact_first"
        decision["investigation_id"] = k
        decision["flow_template"] = flow
        decision["project_axis"] = AXIS_BY_FLOW.get(flow, "D1")
        decision["stage_advancing_to"] = ARTIFACT_FIRST_STAGE_BY_FLOW.get(flow, "Update")
        decision["subagent_type"] = "critic"
        decision["sibling_artifacts_found"] = paths
        decision["rationale_seed"] = f"artifact-first: {k} has {len(paths)} sibling dirs"
        return decision

    # Row 5: lowest priority
    eligible.sort(key=lambda t: (t[1].get("priority", 99), -(t[1].get("tier_target", 0) - t[1].get("tier_current", 0))))
    k, inv = eligible[0]
    flow = inv.get("flow_template", "verify-claim")
    cur_stage = (inv.get("current_stage") or "").split()[0]
    next_stage = cur_stage  # default repeat; director's contract may advance
    decision["decision_table_row_matched"] = "5_priority"
    decision["investigation_id"] = k
    decision["flow_template"] = flow
    decision["project_axis"] = AXIS_BY_FLOW.get(flow, "D1")
    decision["stage_advancing_to"] = next_stage or "Research"
    decision["subagent_type"] = ROLE_BY_FLOW_STAGE.get(flow, {}).get(next_stage, "theorist")
    decision["rationale_seed"] = f"lowest priority eligible: {k} (priority={inv.get('priority')}, tier_gap={inv.get('tier_target', 0) - inv.get('tier_current', 0)})"
    return decision


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--turn", type=int, required=True)
    ap.add_argument("--write-pick", action="store_true",
                    help="Write the pick to runs/_loop/_local/director_pick_${TURN}.json")
    args = ap.parse_args()

    decision = pick(args.turn)
    if args.write_pick:
        LOCAL.mkdir(parents=True, exist_ok=True)
        out = LOCAL / f"director_pick_{args.turn}.json"
        out.write_text(json.dumps(decision, indent=2, default=str))
        print(f"wrote {out.relative_to(ROOT)}")
    else:
        print(json.dumps(decision, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
