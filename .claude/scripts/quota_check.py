#!/usr/bin/env python3
"""
Approximate rolling-window quota check for the autonomous loop.

Anthropic does not publicly expose Max-plan remaining tokens, so this
script approximates: count turns logged in state.json.history within
the rolling window, and compare against a measured-baseline budget.

Tune .claude/scripts/quota_config.json after the first week of real
usage. The defaults are intentionally conservative for Max x20.

Exit 0: budget remains for >= safety_margin more turns.
Exit 1: budget exhausted (or about to be).
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "runs" / "_loop"
CONFIG = ROOT / ".claude" / "scripts" / "quota_config.json"
STATE = REPORTS / "state.json"

DEFAULT_CONFIG = {
    # Legacy turn-based limits (kept for compat; secondary check)
    "rolling_window_hours": 5,
    "max_turns_per_window": 15,
    "safety_margin_turns": 2,
    "weekly_window_hours": 168,
    "max_turns_per_week": 280,
    "weekly_safety_margin_turns": 10,
    # Upgrade C: primary check is effective-tokens-based (per design synthesis
    # §2 C, citing Bai 2026 30× token variability). Observed ~1.2M
    # effective/turn average over T3-T7. Window cap at ~12 typical turns ≈ 15M.
    "max_effective_tokens_per_window": 15_000_000,
    "effective_tokens_safety_margin": 2_500_000,
    "max_effective_tokens_per_week": 300_000_000,  # ~250 turns/wk × 1.2M
    "weekly_effective_safety_margin": 30_000_000,
}


def load_config() -> dict:
    cfg = dict(DEFAULT_CONFIG)
    if CONFIG.exists():
        try:
            cfg.update(json.loads(CONFIG.read_text()))
        except json.JSONDecodeError as e:
            print(f"warn: malformed {CONFIG}: {e}", file=sys.stderr)
    return cfg


def count_recent_turns(window_hours: int) -> int:
    if not STATE.exists():
        return 0
    try:
        state = json.loads(STATE.read_text())
    except json.JSONDecodeError:
        return 0
    history = state.get("history", [])
    cutoff = datetime.now(timezone.utc) - timedelta(hours=window_hours)
    count = 0
    for entry in history:
        ts_str = entry.get("ts")
        if not ts_str:
            continue
        try:
            ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        except ValueError:
            continue
        if ts >= cutoff:
            count += 1
    return count


def sum_recent_effective_tokens(window_hours: int) -> int:
    """Upgrade C: sum effective_full_rate tokens in rolling window."""
    if not STATE.exists():
        return 0
    try:
        state = json.loads(STATE.read_text())
    except json.JSONDecodeError:
        return 0
    history = state.get("history", [])
    cutoff = datetime.now(timezone.utc) - timedelta(hours=window_hours)
    total = 0
    for entry in history:
        ts_str = entry.get("ts")
        if not ts_str:
            continue
        try:
            ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        except ValueError:
            continue
        if ts < cutoff:
            continue
        tu = entry.get("tokens_used") or {}
        eff = tu.get("effective_full_rate")
        if isinstance(eff, (int, float)) and eff > 0:
            total += int(eff)
    return total


def main() -> int:
    cfg = load_config()

    # Token-based primary check (Upgrade C, design synthesis §2 C)
    rolling_eff = sum_recent_effective_tokens(cfg["rolling_window_hours"])
    rolling_eff_budget = (
        cfg["max_effective_tokens_per_window"]
        - rolling_eff
        - cfg["effective_tokens_safety_margin"]
    )

    weekly_eff = sum_recent_effective_tokens(cfg["weekly_window_hours"])
    weekly_eff_budget = (
        cfg["max_effective_tokens_per_week"]
        - weekly_eff
        - cfg["weekly_effective_safety_margin"]
    )

    # Turn-based secondary (legacy / robustness when tokens missing)
    rolling_turns = count_recent_turns(cfg["rolling_window_hours"])
    rolling_turn_budget = (
        cfg["max_turns_per_window"] - rolling_turns - cfg["safety_margin_turns"]
    )

    weekly_turns = count_recent_turns(cfg["weekly_window_hours"])
    weekly_turn_budget = (
        cfg["max_turns_per_week"] - weekly_turns - cfg["weekly_safety_margin_turns"]
    )

    eff_status = (
        f"rolling-eff: {rolling_eff:,}/{cfg['max_effective_tokens_per_window']:,} "
        f"(margin {cfg['effective_tokens_safety_margin']:,}) -> budget={rolling_eff_budget:,}"
    )
    weekly_eff_status = (
        f"weekly-eff: {weekly_eff:,}/{cfg['max_effective_tokens_per_week']:,} "
        f"(margin {cfg['weekly_effective_safety_margin']:,}) -> budget={weekly_eff_budget:,}"
    )
    turn_status = (
        f"rolling-turns: {rolling_turns}/{cfg['max_turns_per_window']} | "
        f"weekly-turns: {weekly_turns}/{cfg['max_turns_per_week']}"
    )

    if rolling_eff_budget < 0:
        print(f"QUOTA_EXHAUSTED rolling-eff: {eff_status}")
        return 1
    if weekly_eff_budget < 0:
        print(f"QUOTA_EXHAUSTED weekly-eff: {weekly_eff_status}")
        return 1
    if rolling_turn_budget < 0:
        print(f"QUOTA_EXHAUSTED rolling-turns: {turn_status}")
        return 1
    if weekly_turn_budget < 0:
        print(f"QUOTA_EXHAUSTED weekly-turns: {turn_status}")
        return 1

    print(f"QUOTA_OK | {eff_status} | {weekly_eff_status} | {turn_status}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
