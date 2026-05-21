#!/usr/bin/env python3
"""
LLM-free judge for the SpinorBEC.jl autonomous research loop.

Parses runs/_loop/sim/turn_${N}.md, extracts the §4 Metrics JSON
block, runs the checks defined in .claude/agents/implementer.md
Section D, and writes a verdict to runs/_loop/judge/turn_${N}.json.

Exit 0 on PASS, 1 on any FAIL / SUSPICIOUS / REJECTED / NOOP.
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "runs" / "_loop"

DEFAULT_TOL = {
    "norm_drift": 1e-8,
    "order_window": 0.3,
    "mz_target": 1e-6,
    "fit_r_squared_min": 0.99,
    "fz_overshoot_abs": 0.01,
    "novelty_sigma": 3.0,
    # Tier-4 S: token cap, FAIL_PHYSICS above.
    # Two thresholds — raw (sum of input/cache/output) and effective
    # (Anthropic-billing-weighted: 1x in, 1.25x cache write, 0.1x cache
    # read, 5x output). 2026-05-16: bumped from 3M → 6M effective and
    # 35M → 60M raw, after anko removed the 15M/5h rolling cap (per
    # `feedback_cost_overhead_is_the_cost`). Substantive multi-stage
    # turns (theorist + sympy + implementer w/ julia) routinely exceed
    # 3M; cap should catch runaway loops, not normal cascade work.
    "cost_cap_per_turn_effective": 6_000_000,
    "cost_cap_per_turn_raw": 60_000_000,
}


def _read_section_json(md_path: Path, header_regex: str) -> dict[str, Any] | None:
    if not md_path.exists():
        return None
    text = md_path.read_text(encoding="utf-8")
    pat = re.compile(
        rf"{header_regex}\s*\n+```(?:json)?\s*\n(\{{.*?\}})\s*\n```",
        re.DOTALL,
    )
    m = pat.search(text)
    if not m:
        return None
    try:
        return json.loads(m.group(1))
    except json.JSONDecodeError:
        return None


def _read_directive(turn: int) -> dict[str, Any] | None:
    theorist = REPORTS / "theorist" / f"turn_{turn}.md"
    return _read_section_json(theorist, r"## 6\. Directive for implementer")


def _read_director_contract(turn: int) -> dict[str, Any] | None:
    """Read the declarative contract from director/turn_N.md §6.

    Schema v2 (2026-05-17): director writes a JSON contract in §6
    with success_criteria, failure_modes, observable_manifest,
    tolerance_overrides, budget. Judge applies the contract
    mechanically. Falls back to None if no contract present, in
    which case the legacy hardcoded evaluation runs.

    Header regex accepts variants: "## 6. Dispatch decision",
    "## 6. Dispatch decision (declarative contract)", "## 6. Dispatch",
    etc. — director.md template has trailing parenthetical hint that
    earlier versions of this regex rejected.
    """
    director = REPORTS / "director" / f"turn_{turn}.md"
    return _read_section_json(director, r"## 6\.\s*Dispatch decision[^\n]*")


def _read_metrics(turn: int) -> dict[str, Any] | None:
    sim = REPORTS / "sim" / f"turn_{turn}.md"
    # 2026-05-18: relaxed regex — accept ANY section number, just match
    # "Metrics" or "Metrics block" header. Implementer may organize
    # sections differently (T75 put Metrics at §9 instead of §4).
    # Try strict §4 first for backward-compat, then any-section-number.
    result = _read_section_json(sim, r"## 4\. Metrics")
    if result is not None:
        return result
    return _read_section_json(sim, r"## \d+\.\s*Metrics(?:\s+block)?")


def _in_op(a, b):
    """Evaluate "in" operator: 2-element numeric list -> range check; otherwise -> list membership."""
    if not isinstance(b, (list, tuple)):
        return False
    if len(b) == 2 and all(isinstance(x, (int, float)) and not isinstance(x, bool) for x in b):
        return b[0] <= a <= b[1]
    return a in b


_OPS: dict[str, Any] = {
    "<":  lambda a, b: a < b,
    "<=": lambda a, b: a <= b,
    ">":  lambda a, b: a > b,
    ">=": lambda a, b: a >= b,
    "==": lambda a, b: a == b,
    "!=": lambda a, b: a != b,
    "in":  _in_op,
    "out": lambda a, b: not _in_op(a, b),
}


def _evaluate_criterion(criterion: dict[str, Any], metrics: dict[str, Any]) -> dict[str, Any]:
    """Apply one declarative success criterion.

    criterion shape (one of two forms):

    FORM A — metric-based (legacy, reads sim §4 Metrics JSON):
        {id, metric, operator, value, tolerance?, rationale?}

    FORM B — raw-artifact check (2026-05-19, reviewer rec #1; reads raw
    files via shell command, NOT sim metrics):
        {id, check_cmd, expect: {exit_code?, stdout_contains?, stdout_json_field?, ...}, rationale?}

    FORM B grounds verdict in raw data — `runs/auto/*/result.jld2`,
    `runs/eu151_edh_K3_long/trajectory.csv`, etc. — bypassing LLM-
    written sim §4 summary. Per Lossfunk arXiv:2601.03315 #2.

    Returns: {id, passed (bool|None), actual, reason}
    """
    cid = criterion.get("id", "<unnamed>")
    check_cmd = criterion.get("check_cmd")

    if check_cmd:
        return _evaluate_shell_criterion(criterion)

    # FORM A: metric-based (legacy)
    metric_name = criterion.get("metric")
    operator = criterion.get("operator")
    target = criterion.get("value")

    actual = metrics.get(metric_name) if metric_name else None
    if actual is None:
        return {"id": cid, "passed": None, "actual": None,
                "reason": f"metric '{metric_name}' missing from sim metrics"}

    op_fn = _OPS.get(operator)
    if op_fn is None:
        return {"id": cid, "passed": None, "actual": actual,
                "reason": f"unknown operator '{operator}'"}

    try:
        result = op_fn(actual, target)
    except (TypeError, ValueError) as exc:
        return {"id": cid, "passed": None, "actual": actual,
                "reason": f"operator failed: {exc}"}

    return {"id": cid, "passed": bool(result), "actual": actual,
            "reason": f"{metric_name}={actual} {operator} {target} → {bool(result)}"}


def _evaluate_shell_criterion(criterion: dict[str, Any]) -> dict[str, Any]:
    """Run a shell command and evaluate its output against the `expect`
    block. Read-only by convention (cwd in repo root, no Write tools).

    expect keys:
      exit_code: int — must equal
      stdout_contains: str | list[str] — all substrings must be present
      stdout_not_contains: str | list[str]
      stdout_json_field: {field: <name>, operator: <op>, value: <target>}
        — interpret stdout as JSON, evaluate field against value
    """
    import shlex
    import subprocess

    cid = criterion.get("id", "<unnamed>")
    cmd = criterion.get("check_cmd", "")
    expect = criterion.get("expect") or {}

    if not cmd or not isinstance(cmd, str):
        return {"id": cid, "passed": None, "actual": None,
                "reason": "check_cmd missing or not a string"}

    # Safety: parse via shlex first to allow `;` and `|` inside quoted
    # arguments (e.g. `python3 -c '...; print(...)'`). Then check the
    # PROGRAM (argv[0]) is on an allow-list and argv contains no
    # unquoted shell metacharacters that survived parsing.
    try:
        argv = shlex.split(cmd)
    except ValueError as exc:
        return {"id": cid, "passed": None, "actual": None,
                "reason": f"check_cmd shlex parse error: {exc}"}
    if not argv:
        return {"id": cid, "passed": None, "actual": None,
                "reason": "check_cmd empty after parsing"}

    # Allow-list of program names (read-only / verification)
    allowed_progs = {
        "ls", "cat", "head", "tail", "wc", "stat", "file", "find",
        "grep", "rg", "ripgrep", "awk", "sed",
        "python3", "python", "uv", "jq",
        "julia",  # Julia is allowed (compute-heavy but read-only by convention)
        "test", "[", "echo",
    }
    prog = Path(argv[0]).name
    if prog not in allowed_progs:
        return {"id": cid, "passed": None, "actual": None,
                "reason": f"check_cmd program '{prog}' not in allow-list {sorted(allowed_progs)}"}
    # Even after shlex, refuse multi-command tokens that snuck through
    for a in argv:
        if a in ("&&", "||", ";", "|", ">", ">>", "<", "<<"):
            return {"id": cid, "passed": None, "actual": None,
                    "reason": f"check_cmd argv contains shell-metachar '{a}' — use one program + args only"}

    try:
        proc = subprocess.run(
            argv,
            cwd=str(ROOT),
            capture_output=True,
            text=True,
            timeout=120,
        )
    except subprocess.TimeoutExpired:
        return {"id": cid, "passed": False, "actual": None,
                "reason": f"check_cmd timed out (>120s): {cmd[:80]}"}
    except (FileNotFoundError, OSError) as exc:
        return {"id": cid, "passed": None, "actual": None,
                "reason": f"check_cmd failed to launch: {exc}"}

    stdout = (proc.stdout or "").strip()
    rc = proc.returncode

    # Evaluate expectations
    failures: list[str] = []

    if "exit_code" in expect:
        if rc != expect["exit_code"]:
            failures.append(f"exit_code={rc} != expected {expect['exit_code']}")

    sc = expect.get("stdout_contains")
    if sc is not None:
        needles = [sc] if isinstance(sc, str) else list(sc)
        for n in needles:
            if n not in stdout:
                failures.append(f"stdout missing '{n[:40]}'")

    snc = expect.get("stdout_not_contains")
    if snc is not None:
        needles = [snc] if isinstance(snc, str) else list(snc)
        for n in needles:
            if n in stdout:
                failures.append(f"stdout contains forbidden '{n[:40]}'")

    sjf = expect.get("stdout_json_field")
    if isinstance(sjf, dict):
        try:
            parsed = json.loads(stdout)
        except json.JSONDecodeError as exc:
            failures.append(f"stdout not JSON: {exc}")
        else:
            field = sjf.get("field")
            actual_val = parsed.get(field) if isinstance(parsed, dict) else None
            op = sjf.get("operator")
            target = sjf.get("value")
            op_fn = _OPS.get(op)
            if op_fn is None:
                failures.append(f"unknown json-field operator '{op}'")
            elif actual_val is None:
                failures.append(f"json field '{field}' missing in stdout")
            else:
                try:
                    if not op_fn(actual_val, target):
                        failures.append(f"json {field}={actual_val} not {op} {target}")
                except (TypeError, ValueError) as exc:
                    failures.append(f"json field eval error: {exc}")

    passed = (not failures)
    reason = (
        f"check_cmd PASS: {cmd[:60]}" if passed
        else f"check_cmd FAIL: {'; '.join(failures)}"
    )
    return {"id": cid, "passed": passed, "actual": {"exit_code": rc, "stdout_head": stdout[:200]},
            "reason": reason, "shell_check": True}


def _evaluate_contract(contract: dict[str, Any], metrics: dict[str, Any]) -> dict[str, Any]:
    """Evaluate sim metrics against director's declarative contract.

    Returns: {
      verdict: PASS | FAIL_OPERATIONAL | FAIL_SCIENTIFIC | INCONCLUSIVE,
      criteria_results: [{id, passed, actual, reason}, ...],
      triggered_failure_modes: [{if, category, next_action}, ...],
      issues: [<list of human-readable issues>],
    }
    """
    criteria = contract.get("success_criteria") or []
    failure_modes = contract.get("failure_modes") or []

    criteria_results: list[dict[str, Any]] = []
    for c in criteria:
        criteria_results.append(_evaluate_criterion(c, metrics))

    failed_ids = [r["id"] for r in criteria_results if r["passed"] is False]
    inconclusive_ids = [r["id"] for r in criteria_results if r["passed"] is None]

    triggered: list[dict[str, Any]] = []
    for fm in failure_modes:
        cond = fm.get("if", "")
        # Simple condition matcher: "<id> failed" or specific named conditions.
        for fid in failed_ids:
            if fid in cond:
                triggered.append(fm)
                break

    issues = [r["reason"] for r in criteria_results if r["passed"] is False]
    issues += [r["reason"] for r in criteria_results if r["passed"] is None]

    # Verdict mapping
    op_failure_categories = {"operational", "framework_error"}
    sci_failure_categories = {"scientific_refuted", "scientific_inconclusive"}
    data_gap_categories = {"data_gap"}

    has_op = any(fm.get("category") in op_failure_categories for fm in triggered)
    has_sci = any(fm.get("category") in sci_failure_categories for fm in triggered)
    has_gap = any(fm.get("category") in data_gap_categories for fm in triggered)

    if has_op:
        verdict = "FAIL_OPERATIONAL"
    elif has_sci:
        # Per anko 2026-05-16/17: scientific refutation IS a positive result.
        # Verdict reflects this — the loop progresses, hypothesis revised.
        verdict = "PASS_REFUTED"
    elif inconclusive_ids:
        verdict = "INCONCLUSIVE"
    elif failed_ids:
        # Generic criterion fail without category mapping — default operational
        verdict = "FAIL_OPERATIONAL"
    else:
        verdict = "PASS"

    return {
        "verdict": verdict,
        "criteria_results": criteria_results,
        "triggered_failure_modes": triggered,
        "issues": issues,
    }


def _check_central_falsifier_for_tier3(contract: dict[str, Any] | None,
                                       metrics: dict[str, Any] | None) -> dict[str, Any]:
    """Central-falsifier gate for tier-3 promotion (2026-05-19 reviewer rec #2).

    If the contract's investigation_update would promote tier to ≥3.0, the
    investigation's central falsifier MUST have result == CORROBORATE / PASS.
    Otherwise emit `tier_cap = 2.75` so the loop.sh post-step jq clamps the
    promotion. Blocks Matsui-level "F3-alone closure" failure class.

    Reads state.json directly for the investigation's falsifiers (judge.py
    has no other way to see them; the contract may not embed them).
    """
    if not contract:
        return {"applies": False, "reason": "no contract"}
    inv_id = contract.get("investigation_id")
    update = contract.get("investigation_update") or {}
    target_tier = update.get("if_success_tier_becomes")
    if not isinstance(target_tier, (int, float)) or target_tier < 3.0:
        return {"applies": False, "reason": f"target tier {target_tier} < 3.0"}
    if not inv_id:
        return {"applies": False, "reason": "no inv_id"}

    # Read falsifier list from state.json
    state_path = ROOT / "runs" / "_loop" / "state.json"
    try:
        state = json.loads(state_path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {"applies": False, "reason": "state.json unreadable"}
    inv = (state.get("investigations") or {}).get(inv_id)
    if not inv:
        return {"applies": False, "reason": f"inv {inv_id} not in state"}
    falsifiers = inv.get("falsifiers") or []
    central = next((f for f in falsifiers if f.get("is_central")), None)
    if not central:
        return {
            "applies": True,
            "tier_cap": 2.75,
            "issues": [f"tier-3 promotion blocked: no central falsifier marked on {inv_id} (run falsifier_central_migration.py)"],
        }
    central_result = (central.get("result") or "")
    # Result is freeform text; look for CORROBORATE / CONFIRMED keywords.
    # A bare "REFUTED" earlier in the string (referring to an alternative
    # hypothesis being killed) is OK as long as the supporting hypothesis
    # is CONFIRMED / CORROBORATE-d in the same string.
    result_upper = central_result.upper()
    has_support = any(k in result_upper for k in (
        "CORROBORATE", "CORROBORATED", "CONFIRMED", "PASS"
    ))
    has_negation_anywhere = "REFUTED-FRAMEWORK" in result_upper or "REFUTED-THEORY" in result_upper
    if (not central_result) or has_negation_anywhere or not has_support:
        return {
            "applies": True,
            "tier_cap": 2.75,
            "issues": [
                f"tier-3 promotion blocked: central falsifier '{central.get('id')}' result='{central_result[:80]}{'…' if len(central_result) > 80 else ''}' lacks CORROBORATE/CONFIRMED keyword; "
                f"target tier {target_tier} clamped to 2.75 until central PASS"
            ],
            "central_falsifier_id": central.get("id"),
            "central_falsifier_result": central_result or None,
        }
    return {
        "applies": True,
        "tier_cap": None,
        "central_falsifier_id": central.get("id"),
        "central_falsifier_result": central_result,
        "issues": [],
    }


def _is_rejected(turn: int) -> bool:
    sim = REPORTS / "sim" / f"turn_{turn}.md"
    if not sim.exists():
        return False
    return "Implementer Report (REJECTED)" in sim.read_text(encoding="utf-8")


def _historical_orders(current_turn: int) -> list[float]:
    """Pull fitted_order from prior sim reports for novelty scoring."""
    orders: list[float] = []
    sim_dir = REPORTS / "sim"
    if not sim_dir.exists():
        return orders
    for p in sorted(sim_dir.glob("turn_*.md")):
        m = re.match(r"turn_(\d+)\.md", p.name)
        if not m:
            continue
        n = int(m.group(1))
        if n >= current_turn:
            continue
        metrics = _read_section_json(p, r"## 4\. Metrics")
        if metrics and isinstance(metrics.get("fitted_order"), (int, float)):
            orders.append(float(metrics["fitted_order"]))
    return orders


def _parse_expected_order(directive: dict[str, Any] | None) -> float | None:
    if not directive:
        return None
    text = directive.get("expected_outcome", "") or ""
    m = re.search(r"order[^=]*p\s*=\s*(-?\d+(?:\.\d+)?)", text, re.IGNORECASE)
    if not m:
        m = re.search(r"order\s*(-?\d+(?:\.\d+)?)", text, re.IGNORECASE)
    return float(m.group(1)) if m else None


def evaluate(turn: int, tol: dict[str, float]) -> dict[str, Any]:
    if _is_rejected(turn):
        return {
            "turn": turn,
            "status": "REJECTED",
            "issues": ["implementer returned REJECTED — see sim report"],
            "metrics": None,
        }

    metrics = _read_metrics(turn)
    if metrics is None:
        return {
            "turn": turn,
            "status": "FAIL_NO_METRICS",
            "issues": [f"sim/turn_{turn}.md missing or §4 JSON unparseable"],
            "metrics": None,
        }

    # Targeted-test failure short-circuits all other checks: if the
    # implementer ran tests and they failed, the directive cannot
    # be PASS regardless of any other metric (Bug-1 fix, 2026-05-14).
    if metrics.get("tests_passed") is False:
        return {
            "turn": turn,
            "status": "FAIL_NUMERICAL",
            "issues": ["targeted tests failed (implementer reported tests_passed=False)"],
            "metrics": metrics,
        }

    # Schema v2 (2026-05-17): if director wrote a declarative contract
    # in §6 of director/turn_N.md, evaluate against THAT instead of the
    # legacy hardcoded thresholds. The contract owns success_criteria,
    # failure_modes, tolerance_overrides. Legacy path remains as
    # fallback when no contract is present.
    contract = _read_director_contract(turn)
    # Cost-vs-actual audit (Item 2): even without success_criteria, if
    # contract has budget.expected_cost_eff, compare to actual.
    cost_audit = None
    if contract is not None and isinstance(contract.get("budget"), dict):
        expected = contract["budget"].get("expected_cost_eff")
        actual = ((metrics.get("tokens_used") or {}).get("effective_full_rate"))
        if isinstance(expected, (int, float)) and isinstance(actual, (int, float)) and expected > 0:
            ratio = actual / expected
            cost_audit = {
                "expected_cost_eff": int(expected),
                "actual_cost_eff": int(actual),
                "ratio_actual_over_expected": round(ratio, 2),
                "deviation_pct": round((ratio - 1.0) * 100, 1),
                "flag": (
                    "BUDGET_BUSTED" if ratio > 2.0
                    else "BUDGET_OVER" if ratio > 1.3
                    else "BUDGET_UNDER" if ratio < 0.5
                    else "BUDGET_OK"
                ),
            }
    if contract is not None and contract.get("success_criteria"):
        # Merge contract.tolerance_overrides into tol (per-turn overrides)
        if isinstance(contract.get("tolerance_overrides"), dict):
            tol = dict(tol)
            tol.update(contract["tolerance_overrides"])

        contract_result = _evaluate_contract(contract, metrics)

        # Cost-cap is policy-level, not a contract criterion — always
        # check regardless of contract.
        cost_issues: list[str] = []
        tokens = metrics.get("tokens_used") or {}
        if isinstance(tokens, dict):
            effective = tokens.get("effective_full_rate")
            raw = tokens.get("total")
            if isinstance(effective, int) and effective > tol["cost_cap_per_turn_effective"]:
                cost_issues.append(
                    f"token effective cost {effective:,} > cap "
                    f"{tol['cost_cap_per_turn_effective']:,} (billing-weighted)"
                )
            if isinstance(raw, int) and raw > tol["cost_cap_per_turn_raw"]:
                cost_issues.append(
                    f"token raw cost {raw:,} > cap "
                    f"{tol['cost_cap_per_turn_raw']:,} (any-source)"
                )

        verdict = contract_result["verdict"]
        all_issues = contract_result["issues"] + cost_issues
        if cost_issues and verdict == "PASS":
            verdict = "PASS_WITH_COST_WARNING"

        # 2026-05-19: central-falsifier gate (reviewer rec #2).
        # If the contract would promote tier to ≥3, the active
        # investigation's central falsifier MUST have result CORROBORATE.
        # Otherwise emit tier_cap so loop.sh's jq min-clamps the promotion.
        central_check = _check_central_falsifier_for_tier3(contract, metrics)

        return {
            "turn": turn,
            "status": verdict,
            "issues": all_issues + central_check.get("issues", []),
            "metrics": metrics,
            "contract_evaluation": contract_result,
            "cost_audit": cost_audit,
            "central_falsifier_check": central_check,
            "tier_cap": central_check.get("tier_cap"),
            "investigation_id": contract.get("investigation_id"),
            "stage_advancing_to": contract.get("stage_advancing_to"),
            "investigation_update": contract.get("investigation_update"),
        }

    # === LEGACY PATH (no contract → hardcoded thresholds) ============
    # Pre-v2 turns or partial migrations. Same checks as before.

    if metrics.get("experiment_kind") == "modify_only":
        # Code-only change with no run. PASS unless:
        # - tests_passed explicitly False (the Tier-1 check above
        #   already catches this), OR
        # - physical_red_flags non-empty (real problems detected), OR
        # - falsification_result == REFUTED.
        # `warnings` is informational only (e.g. "1Password unavailable,
        # used --no-gpg-sign" is operational, not a quality failure).
        # T8 fix 2026-05-15: previously FAILed on any warning.
        warnings = metrics.get("warnings", []) or []
        red_flags = metrics.get("physical_red_flags", []) or []
        falsification = metrics.get("falsification_result")
        if red_flags:
            return {
                "turn": turn,
                "status": "FAIL_PHYSICS",
                "issues": red_flags,
                "metrics": metrics,
            }
        if falsification == "REFUTED":
            return {
                "turn": turn,
                "status": "FAIL_PHYSICS",
                "issues": ["falsification_criterion REFUTED"],
                "metrics": metrics,
            }
        return {
            "turn": turn,
            "status": "PASS",
            "issues": [],  # warnings flow through metrics, not as issues
            "metrics": metrics,
            "info_warnings": warnings if warnings else [],
        }

    directive = _read_directive(turn)
    numerical_issues: list[str] = []
    physics_issues: list[str] = []

    # Norm. If the experiment has known dissipation (K3, γ_dr, atom loss,
    # etc.), the unitary-GP norm-conservation check does not apply. The
    # implementer signals this via `has_dissipation: true` or by reporting
    # an `expected_norm_drift` upper bound. Fix 2026-05-16 — previously the
    # Barnett c_dd=0 control FAILed because K3 dropped norm by 1% (expected),
    # which exceeded the 1e-8 unitary tolerance.
    has_dissipation = bool(metrics.get("has_dissipation"))
    expected_drift = metrics.get("expected_norm_drift")
    norm_drift = metrics.get("norm_drift")
    if norm_drift is None and metrics.get("norm_final") is not None:
        norm_drift = abs(metrics["norm_final"] - 1.0)
    if norm_drift is not None:
        # Resolve effective tolerance: explicit expected_norm_drift wins,
        # else widened tol for dissipative runs, else strict unitary tol.
        if expected_drift is not None:
            eff_tol = float(expected_drift) * 1.2  # 20% margin around expectation
        elif has_dissipation:
            eff_tol = 5e-2  # 5% drift allowed under generic dissipation
        else:
            eff_tol = tol["norm_drift"]
        if norm_drift > eff_tol:
            numerical_issues.append(
                f"norm_drift={norm_drift:.2e} exceeds eff_tol {eff_tol:.0e} "
                f"(has_dissipation={has_dissipation}, expected={expected_drift})"
            )

    # Energy monotonicity (ITP)
    if metrics.get("experiment_kind") == "ground_state":
        if metrics.get("energy_monotonic") is False:
            numerical_issues.append("energy non-monotonic in ITP")

    # Mz match
    mz_target = metrics.get("mz_target")
    mz_final = metrics.get("mz_final")
    if mz_target is not None and mz_final is not None:
        if abs(mz_final - mz_target) > tol["mz_target"]:
            numerical_issues.append(
                f"mz_final={mz_final} deviates from target={mz_target} by "
                f"{abs(mz_final - mz_target):.2e}"
            )

    # Fitted order vs prediction
    p_expected = _parse_expected_order(directive)
    p_actual = metrics.get("fitted_order")
    r2 = metrics.get("fit_r_squared")
    if p_actual is not None:
        if r2 is not None and r2 < tol["fit_r_squared_min"]:
            numerical_issues.append(
                f"order fit r²={r2:.3f} < {tol['fit_r_squared_min']}"
            )
        if p_expected is not None:
            delta = abs(p_actual - p_expected)
            if delta > tol["order_window"]:
                physics_issues.append(
                    f"order p={p_actual} deviates from predicted "
                    f"p={p_expected} by {delta:.2f}"
                )

    # Physical red flags (free-form from implementer)
    red_flags = metrics.get("physical_red_flags", []) or []
    physics_issues.extend(red_flags)

    # Falsification: implementer's §7 verdict. REFUTED is NOT a turn
    # failure — refuting a hypothesis IS a scientific result. The director
    # uses the REFUTED signal to redirect next turn. Only emit a real
    # failure if physical_red_flags reports an actual bug.
    # Fix 2026-05-16 — T20 c_dd=0 control was REFUTED (good science:
    # M1-active despite sub-Landau, T19 §2.5.2 ruled out) but judge marked
    # it FAIL_PHYSICS, blocking loop progress.
    falsification = metrics.get("falsification_result")
    # NOTE: physical_red_flags already added above. Do NOT double-count
    # REFUTED as a physics failure.

    # Cost cap (Tier-4 S, F2 timing fix): two checks against effective
    # (billing-weighted) and raw (any-source) token sums. Both are
    # patched into metrics.tokens_used by loop.sh BEFORE judge runs
    # (post-restructure ordering). If still null, the check is skipped
    # (e.g., judge invoked manually outside the loop).
    tokens = metrics.get("tokens_used") or {}
    if isinstance(tokens, dict):
        effective = tokens.get("effective_full_rate")
        raw = tokens.get("total")
        if isinstance(effective, int) and effective > tol["cost_cap_per_turn_effective"]:
            physics_issues.append(
                f"token effective cost {effective:,} > cap "
                f"{tol['cost_cap_per_turn_effective']:,} (billing-weighted)"
            )
        if isinstance(raw, int) and raw > tol["cost_cap_per_turn_raw"]:
            physics_issues.append(
                f"token raw cost {raw:,} > cap "
                f"{tol['cost_cap_per_turn_raw']:,} (any-source)"
            )

    # Novelty: fitted_order outside historical 3σ
    novel = False
    if p_actual is not None:
        history = _historical_orders(turn)
        if len(history) >= 5:
            mu = statistics.mean(history)
            sigma = statistics.stdev(history)
            if sigma > 0 and abs(p_actual - mu) / sigma > tol["novelty_sigma"]:
                novel = True

    # Status decision
    if numerical_issues:
        status = "FAIL_NUMERICAL"
    elif physics_issues:
        status = "FAIL_PHYSICS"
    elif novel:
        status = "SUSPICIOUS_NOVEL"
    else:
        status = "PASS"

    return {
        "turn": turn,
        "status": status,
        "issues": numerical_issues + physics_issues,
        "novel_detected": novel,
        "metrics": metrics,
        "directive_expected_order": p_expected,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--turn", type=int, required=True)
    ap.add_argument("--tol-config", type=Path, default=None)
    args = ap.parse_args()

    tol = dict(DEFAULT_TOL)
    if args.tol_config and args.tol_config.exists():
        tol.update(json.loads(args.tol_config.read_text()))

    # Tier-1 Bug-B: wrap evaluate() so judge crashes surface as a
    # distinct status instead of leaking out as a generic non-zero exit
    # that the orchestrator can't distinguish from a real test failure.
    try:
        result = evaluate(args.turn, tol)
    except Exception as exc:
        import traceback
        result = {
            "turn": args.turn,
            "status": "FAIL_JUDGE_CRASHED",
            "issues": [
                f"judge.py raised {type(exc).__name__}: {exc}",
                "this is a judge bug, not a turn failure — investigate before next turn",
            ],
            "traceback": traceback.format_exc(),
            "metrics": None,
        }

    out_dir = REPORTS / "judge"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"turn_{args.turn}.json"
    out.write_text(json.dumps(result, indent=2, default=str))
    print(json.dumps(result, indent=2, default=str))

    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
