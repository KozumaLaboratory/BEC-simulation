#!/usr/bin/env python3
"""state.json schema v2 validator (Item 9, 2026-05-18)."""

from __future__ import annotations
import json
import sys
from pathlib import Path

STATE = Path("/home/suzume/workspace/BEC-simulation/runs/_loop/state.json")

VALID_KIND = {"physics", "meta"}
VALID_STAGE_PHYSICS = {
    "Research", "Hypothesize", "Design", "Execute", "Analyze",
    "Update", "Document", "closed", "dormant",
    "Refine", "Cross-check",
    "Reproduce", "Fix", "Test",
    "Synthesize",
    "Observe", "Findings", "Triage",
}
VALID_STAGE_META = {
    "Observe", "Hypothesize", "Design", "Pilot", "Evaluate",
    "Adopt", "Revert", "Document", "closed",
}


def validate() -> dict:
    issues: list[str] = []
    warnings: list[str] = []

    if not STATE.exists():
        return {"ok": False, "issues": ["state.json missing"], "warnings": []}

    try:
        state = json.loads(STATE.read_text())
    except json.JSONDecodeError as e:
        return {"ok": False, "issues": [f"state.json malformed JSON: {e}"], "warnings": []}

    for field in ("turn", "status", "history"):
        if field not in state:
            issues.append(f"missing top-level field: {field}")

    if "schema_version" not in state:
        warnings.append("missing schema_version (expected 2 or 2.1)")
    elif state["schema_version"] not in (2, 2.1):
        warnings.append(f"schema_version={state['schema_version']!r} unexpected")

    investigations = state.get("investigations") or {}
    if not isinstance(investigations, dict):
        issues.append("investigations must be an object")
    else:
        for inv_id, inv in investigations.items():
            if not isinstance(inv, dict):
                issues.append(f"investigations[{inv_id}] not a dict")
                continue
            kind = inv.get("kind", "physics")
            if kind not in VALID_KIND:
                issues.append(f"investigations[{inv_id}].kind={kind!r} invalid")
            stage = inv.get("current_stage")
            if stage is None:
                warnings.append(f"investigations[{inv_id}].current_stage missing")
            else:
                valid_set = VALID_STAGE_META if kind == "meta" else VALID_STAGE_PHYSICS
                if stage not in valid_set:
                    warnings.append(
                        f"investigations[{inv_id}].current_stage={stage!r} unrecognized"
                    )
            for required in ("title", "hypothesis"):
                if required not in inv:
                    warnings.append(f"investigations[{inv_id}].{required} missing")

    active = state.get("active_investigation_id")
    if active and active not in investigations:
        issues.append(f"active_investigation_id={active!r} points to nonexistent investigation")

    history = state.get("history", [])
    for i, h in enumerate(history):
        if not isinstance(h, dict):
            issues.append(f"history[{i}] not a dict")
            continue
        if "turn" not in h:
            warnings.append(f"history[{i}] missing turn")

    return {
        "ok": len(issues) == 0,
        "issues": issues,
        "warnings": warnings[:5],
        "n_warnings_total": len(warnings),
        "stats": {
            "turn": state.get("turn"),
            "n_investigations": len(investigations),
            "n_history": len(history),
            "active": active,
        },
    }


def main() -> int:
    r = validate()
    print(json.dumps(r, indent=2, default=str))
    return 0 if r["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
