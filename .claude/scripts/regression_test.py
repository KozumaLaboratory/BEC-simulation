#!/usr/bin/env python3
"""Slice-level regression test for prompt + judge edits (2026-05-19).

Per Ma et al. 2023 (arXiv:2311.11123) "(Why) Is My Prompt Getting Worse?",
the safety net against prompt-bloat regression is a pinned set of past
turns whose judge verdict + key fields are replayed and diff'd after any
prompt or judge.py edit.

Pinned set: `runs/_loop/regression/turn_${N}.expected.json` files.
Each captures the JSON output of `judge.py --turn N` at pin time.

Usage:
    regression_test.py pin --turn N [--turn N ...]
        Snapshot the current judge.py output for the given turns as the
        expected baseline.

    regression_test.py pin-set
        Snapshot the curated 20-turn baseline set (see PIN_SET below).

    regression_test.py run
        Walk all pinned turns, run judge.py, diff each output against
        expected. Exit 0 if all match (or only field whitelist differs),
        exit 1 if any regression found.

The diff IGNORES fields that depend on wall clock / random state:
  - tokens_used (post-step inject)
  - ratio_actual_over_expected, deviation_pct (cost_audit, depends on tokens)
  - issues containing "cost" (cost-cap may differ across runs)

The diff CHECKS:
  - status (PASS/FAIL/INCONCLUSIVE etc.)
  - tier_cap (central-falsifier gate)
  - central_falsifier_check.tier_cap
  - investigation_update.if_success_tier_becomes
  - contract_evaluation.verdict
  - contract_evaluation.criteria_results[].passed (each criterion's pass/fail)
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path("/home/suzume/workspace/BEC-simulation")
REGRESSION_DIR = ROOT / "runs" / "_loop" / "regression"

# Curated 20-turn baseline set — mix of:
# - Tier-3 closures (T86 Matsui terminal, T94 F=2 cyclic, T100 tdhfb-phase2)
# - Various verdicts (PASS, FAIL_OPERATIONAL, INCONCLUSIVE, CRITIC_PASS, NOOP)
# - Various actions (run_experiment, modify_code, analyze, critic_audit, researcher)
PIN_SET = [
    76,   # PASS analyze_existing (Matsui era)
    78,   # PASS modify_code
    79,   # INCONCLUSIVE run_experiment
    80,   # PASS derive_theory
    82,   # PASS analyze_existing (Matsui §4 metrics extraction)
    83,   # CRITIC_PASS critic_audit (Matsui F3 OPERATIONAL_GATE)
    85,   # FAIL_OPERATIONAL verify_and_close
    86,   # PASS verify_and_close (Matsui closure — now tier_cap=2.75 gate fires)
    88,   # PASS modify_text
    90,   # PASS modify_code
    92,   # FAIL_OPERATIONAL text_only
    94,   # PASS modify_code (F=2 cyclic Tier-3 closure)
    96,   # NOOP noop
    97,   # FAIL_OPERATIONAL modify_code
    99,   # PASS analyze_existing
    100,  # PASS run_experiment (tdhfb-phase2 polar phonon)
    101,  # CRITIC_PASS critic_audit
    102,  # PASS modify_code (tdhfb-phase2 Tier-3)
    104,  # CRITIC_PASS critic_l3_audit
    105,  # PASS modify_code
]

# Fields to ignore in diff (depend on wall clock / tokens)
IGNORE_FIELDS = {
    "tokens_used",
    "actual_cost_eff",
    "ratio_actual_over_expected",
    "deviation_pct",
    "flag",  # cost_audit flag depends on tokens
}

# Fields to check (load-bearing for regression)
CHECK_FIELDS = [
    "status",
    "tier_cap",
    ("contract_evaluation", "verdict"),
    ("central_falsifier_check", "applies"),
    ("central_falsifier_check", "tier_cap"),
    ("investigation_update", "if_success_tier_becomes"),
    ("investigation_update", "if_success_advance_to_stage"),
]


def _judge_run(turn: int) -> dict:
    """Run judge.py and return its JSON output."""
    proc = subprocess.run(
        ["python3", str(ROOT / ".claude" / "scripts" / "judge.py"), "--turn", str(turn)],
        capture_output=True, text=True, cwd=str(ROOT), timeout=120,
    )
    if proc.returncode != 0 and not proc.stdout:
        return {"_error": f"judge.py exit={proc.returncode}; stderr={proc.stderr[:200]}"}
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        return {"_error": f"judge.py output not JSON: {exc}; head={proc.stdout[:200]}"}


def _strip_volatile(d):
    """Recursively remove fields that depend on wall clock / tokens."""
    if isinstance(d, dict):
        return {k: _strip_volatile(v) for k, v in d.items() if k not in IGNORE_FIELDS}
    if isinstance(d, list):
        return [_strip_volatile(x) for x in d]
    return d


def _extract_checked(d: dict) -> dict:
    """Pull only CHECK_FIELDS from a judge output."""
    out = {}
    for f in CHECK_FIELDS:
        if isinstance(f, str):
            out[f] = d.get(f)
        else:
            cur = d
            for k in f:
                if not isinstance(cur, dict):
                    cur = None
                    break
                cur = cur.get(k)
            out[".".join(f)] = cur
    # Also: per-criterion pass/fail from contract_evaluation.criteria_results
    crits = (d.get("contract_evaluation") or {}).get("criteria_results") or []
    out["criteria_passed_ids"] = [c["id"] for c in crits if c.get("passed") is True]
    out["criteria_failed_ids"] = [c["id"] for c in crits if c.get("passed") is False]
    return out


def _check_state_drift(pinned_snapshot: dict | None) -> dict | None:
    """Compare pin-time investigation snapshot to current state. Return
    a drift report if any falsifier's result kind changed (e.g.,
    untested → corroborate), else None.
    """
    if not pinned_snapshot or not pinned_snapshot.get("inv_id"):
        return None
    inv_id = pinned_snapshot["inv_id"]
    try:
        state = json.loads((ROOT / "runs" / "_loop" / "state.json").read_text())
    except Exception:
        return None
    inv_now = (state.get("investigations") or {}).get(inv_id) or {}
    fals_now = inv_now.get("falsifiers") or []

    def _kind(result):
        if not result:
            return "untested"
        u = result.upper()
        if any(k in u for k in ("CORROBORATE", "CONFIRMED", "PASS")):
            return "corroborate"
        if "REFUTED" in u:
            return "refuted"
        return "other"

    drift = []
    pinned_by_id = {f["id"]: f["result_kind"] for f in pinned_snapshot.get("falsifiers_at_pin", [])}
    for f in fals_now:
        fid = f.get("id")
        new_kind = _kind(f.get("result"))
        pin_kind = pinned_by_id.get(fid)
        if pin_kind and pin_kind != new_kind:
            drift.append({"falsifier": fid, "pin_kind": pin_kind, "current_kind": new_kind})
    tier_now = inv_now.get("tier_current")
    tier_pin = pinned_snapshot.get("tier_current_at_pin")
    if tier_pin is not None and tier_now != tier_pin:
        drift.append({"tier_current": {"pin": tier_pin, "now": tier_now}})
    return drift if drift else None


def pin(turns: list[int]) -> dict:
    """Pin both the expected judge output AND the relevant slice of state.json
    (the investigation referenced by this turn) so a re-run is reproducible
    even when other investigations' falsifier results mutate later.
    """
    REGRESSION_DIR.mkdir(parents=True, exist_ok=True)
    state_now = json.loads((ROOT / "runs" / "_loop" / "state.json").read_text())
    out = {"pinned": [], "failed": []}
    for t in turns:
        r = _judge_run(t)
        if "_error" in r:
            out["failed"].append({"turn": t, "reason": r["_error"]})
            continue
        # Capture the investigation's falsifier state at pin time
        inv_id = r.get("investigation_id")
        inv_snapshot = (state_now.get("investigations") or {}).get(inv_id) if inv_id else None
        expected = _strip_volatile(r)
        expected["_pinned_inv_snapshot"] = {
            "inv_id": inv_id,
            "tier_current_at_pin": (inv_snapshot or {}).get("tier_current"),
            "falsifiers_at_pin": [
                {"id": f.get("id"), "is_central": f.get("is_central"),
                 "result_kind": (
                     "corroborate" if any(k in (f.get("result") or "").upper()
                                           for k in ("CORROBORATE", "CONFIRMED", "PASS"))
                     else "refuted" if "REFUTED" in (f.get("result") or "").upper()
                     else "untested" if not f.get("result")
                     else "other"
                 )}
                for f in ((inv_snapshot or {}).get("falsifiers") or [])
            ] if inv_snapshot else [],
        }
        path = REGRESSION_DIR / f"turn_{t}.expected.json"
        path.write_text(json.dumps(expected, indent=2, default=str))
        out["pinned"].append({"turn": t, "status": r.get("status"), "path": str(path.relative_to(ROOT))})
    return out


def run() -> dict:
    if not REGRESSION_DIR.exists():
        return {"ok": False, "reason": "no regression dir; run `pin-set` first"}
    expected_files = sorted(REGRESSION_DIR.glob("turn_*.expected.json"))
    if not expected_files:
        return {"ok": False, "reason": "no pinned turns"}

    results = {"n_pinned": len(expected_files), "regressions": [], "pass": [], "errors": []}
    for ef in expected_files:
        turn = int(ef.stem.replace("turn_", "").replace(".expected", ""))
        try:
            expected = json.loads(ef.read_text())
        except json.JSONDecodeError as exc:
            results["errors"].append({"turn": turn, "err": f"corrupted: {exc}"})
            continue
        actual = _judge_run(turn)
        if "_error" in actual:
            results["errors"].append({"turn": turn, "err": actual["_error"]})
            continue
        # Check if state has drifted from pin-time snapshot
        state_drift = _check_state_drift(expected.get("_pinned_inv_snapshot"))
        exp_check = _extract_checked(expected)
        act_check = _extract_checked(actual)
        # Find diffs
        diffs = []
        for k in set(exp_check) | set(act_check):
            if exp_check.get(k) != act_check.get(k):
                diffs.append({"field": k, "expected": exp_check.get(k), "actual": act_check.get(k)})
        if diffs:
            entry = {"turn": turn, "diffs": diffs}
            if state_drift:
                entry["state_drift"] = state_drift
                entry["verdict"] = "EXPECTED_DRIFT (state.json mutated post-pin; diff is legitimate)"
                results["pass"].append(turn)  # not counted as regression
            else:
                entry["verdict"] = "REGRESSION (state unchanged but verdict changed)"
                results["regressions"].append(entry)
        else:
            results["pass"].append(turn)
    results["ok"] = (not results["regressions"]) and (not results["errors"])
    return results


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_pin = sub.add_parser("pin")
    p_pin.add_argument("--turn", type=int, action="append", required=True)
    sub.add_parser("pin-set")
    sub.add_parser("run")
    args = ap.parse_args()
    if args.cmd == "pin":
        out = pin(args.turn)
    elif args.cmd == "pin-set":
        out = pin(PIN_SET)
    elif args.cmd == "run":
        out = run()
        if not out.get("ok"):
            print(json.dumps(out, indent=2, default=str))
            return 1
    print(json.dumps(out, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
