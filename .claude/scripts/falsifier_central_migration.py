#!/usr/bin/env python3
"""One-shot migration: add `is_central: bool` to every falsifier
(2026-05-19, per external reviewer recommendation #2).

Reviewer's structural argument: at 23 investigations × P(false PASS |
1-of-3 falsifiers, p=0.1) ≈ 27%, the loop's current closure logic
admits expected 6.2 false Tier-3 closures. Matsui case was not bad
luck — it was system-permitted. Fix: each investigation declares
ONE central falsifier; judge.py refuses to promote to Tier 3 unless
the central falsifier PASS-es.

This script:
1. Reads state.json
2. For each investigation with falsifiers, calls back to a hand-curated
   table (CENTRAL_BY_INV below) to mark the central one
3. Adds `is_central: bool` field to every falsifier
4. Writes back atomically under flock

Run once, then judge.py + state_schema_check.py enforce going forward.
"""

from __future__ import annotations

import json
import fcntl
import sys
from pathlib import Path

ROOT = Path("/home/suzume/workspace/BEC-simulation")
STATE = ROOT / "runs" / "_loop" / "state.json"
LOCK = ROOT / "runs" / "_loop" / "_local" / "state.json.lock"

# Hand-curated central-falsifier map.
# For each investigation with falsifiers, name the ONE falsifier that
# encodes the published group's central claim (or, for internal work,
# the load-bearing assertion). Other falsifiers are corroborative.
# Investigations not listed: first falsifier defaults to central (best
# guess; can be re-curated).
CENTRAL_BY_INV = {
    # Tier-3 published-paper benchmarks: central = paper's headline result
    "edh-eu151-vortex-vs-matsui-science-2026": "F1-ring-appears-correct-timescale",
    "barnett-mechanism-2026-05-16": None,  # auto-pick first
    "klaus-magnetostir-bch-leak-2026-05-13": None,
    "yan-li-saito-2026-reproduction": None,
    # Internal validation: central = the assertion being tested
    "f2-cyclic-tetrahedral-a1-tier3-2026-05-18": None,
    "sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18": None,
    "tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18": None,
    "bug-4-itp-ddi-half-rate-revalidation-2026-05-18": None,
    "fullbdg-f6-polar-3000x": None,
    "judge-in-operator-bug-2026-05-18": None,
    # Meta / audit: central = the loop-pathology being fixed
    "meta-cost-waste-audit-2026-05-18": None,
    "meta-cost-inflation-2026-05-18": None,
    "meta-cost-inflation-2026-05-19": None,
    "meta-critic-placement-2026-05-17": None,
    "meta-director-self-audit-2026-05-19": None,
    "meta-internal-b-unification-2026-05-18": None,
    "meta-stage-routing-2026-05-18": None,
    "audit-class-scan-2026-05-18-T50": None,
    "audit-class-scan-2026-05-18-T61": None,
    "audit-class-scan-2026-05-18-T87": None,
    "audit-class-scan-2026-05-19-T103": None,
    "audit-due-heuristic-bug-2026-05-18": None,
}


def migrate(dry_run: bool = False) -> dict:
    state = json.loads(STATE.read_text())
    invs = state.get("investigations") or {}
    summary = {"n_invs": 0, "n_fals_marked": 0, "central_pick": {}, "skipped": []}

    for inv_id, inv in invs.items():
        fals = inv.get("falsifiers")
        if not isinstance(fals, list) or not fals:
            summary["skipped"].append(inv_id)
            continue
        summary["n_invs"] += 1

        central_id = CENTRAL_BY_INV.get(inv_id)
        # Default: first falsifier becomes central
        if central_id is None:
            central_id = fals[0].get("id") or fals[0].get("description", "")[:60]

        # Apply
        n_marked = 0
        for f in fals:
            f_id = f.get("id") or f.get("description", "")[:60]
            is_c = (f_id == central_id)
            f["is_central"] = is_c
            if is_c:
                n_marked += 1
        if n_marked != 1:
            # Shouldn't happen — but log
            summary["skipped"].append(f"{inv_id} (got {n_marked} centrals)")
            continue
        summary["n_fals_marked"] += len(fals)
        summary["central_pick"][inv_id] = central_id

    if not dry_run:
        LOCK.parent.mkdir(parents=True, exist_ok=True)
        with LOCK.open("w") as fh:
            fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
            STATE.write_text(json.dumps(state, indent=2, default=str))
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)

    return summary


if __name__ == "__main__":
    dry = "--dry-run" in sys.argv
    out = migrate(dry_run=dry)
    print(json.dumps(out, indent=2, default=str))
