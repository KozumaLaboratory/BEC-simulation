#!/usr/bin/env python3
"""OpenTelemetry-style trace + metric emission for the loop (2026-05-18).

Emits OTEL-style structured events to `.claude/logs/otel_traces.ndjson`
(one JSON event per line, parseable by jq / OTEL collector / Grafana
Tempo via local file-based exporter).

Per anko 2026-05-18: monitor loop internals (turn-level cost, drift,
verdicts, investigation tier movement, schema warnings) via OTEL.

Design choice — NDJSON over a live OTLP exporter:
- Zero external dependency (no need for collector / Tempo / Prom)
- Replay-able: any analyst tool can read the file
- Drop-in for OTLP later: an `otelcol filelog` receiver can pick this
  file up unchanged.

Span hierarchy per turn:
  loop.turn (N)
    ├── loop.director.dispatch
    ├── loop.subagent.<type>
    ├── loop.judge
    └── loop.post_step
          ├── loop.cost_audit
          ├── loop.drift_signals
          ├── loop.status_md_update
          └── loop.schema_check

Metric points (counter / gauge):
  loop.cost_eff_per_turn       (gauge)
  loop.tokens_total            (counter)
  loop.drift_signal.<name>     (counter)
  loop.judge.verdict.<name>    (counter)
  loop.investigation.tier_current (gauge per inv_id)
  loop.schema_check.warnings   (gauge)
  loop.wall_time_sec           (gauge per turn)

Usage:
  otel_emit.py span --turn N --name <span> --attr key=val ...
  otel_emit.py metric --name <metric> --value <num> --attr key=val ...
  otel_emit.py turn-summary --turn N   # auto-fills from state + judge
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / ".claude" / "logs"
OUT_PATH = OUT_DIR / "otel_traces.ndjson"
STATE = ROOT / "runs" / "_loop" / "state.json"
JUDGE_DIR = ROOT / "runs" / "_loop" / "judge"


def _now_ns() -> int:
    return time.time_ns()


def _iso() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


def _emit(event: dict) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("a") as f:
        f.write(json.dumps(event, default=str) + "\n")


def emit_span(turn: int, name: str, attrs: dict, start_ns: int | None = None,
              end_ns: int | None = None, parent: str | None = None) -> str:
    span_id = uuid.uuid4().hex[:16]
    event = {
        "type": "span",
        "ts": _iso(),
        "trace_id": f"loop-turn-{turn}",
        "span_id": span_id,
        "parent_span_id": parent,
        "name": name,
        "start_time_unix_nano": start_ns or _now_ns(),
        "end_time_unix_nano": end_ns or _now_ns(),
        "attributes": {"turn": turn, **attrs},
    }
    _emit(event)
    return span_id


def emit_metric(name: str, value: float, attrs: dict, kind: str = "gauge") -> None:
    event = {
        "type": "metric",
        "ts": _iso(),
        "name": name,
        "kind": kind,                        # gauge | counter
        "value": value,
        "attributes": attrs,
    }
    _emit(event)


def emit_log(turn: int, level: str, body: str, attrs: dict | None = None) -> None:
    event = {
        "type": "log",
        "ts": _iso(),
        "trace_id": f"loop-turn-{turn}",
        "severity": level,                   # INFO | WARN | ERROR
        "body": body,
        "attributes": attrs or {},
    }
    _emit(event)


def turn_summary(turn: int) -> dict:
    """Synthesize an OTEL trace + metric set for a completed turn from
    state.json history entry and judge JSON. One-shot emission at loop
    post-step time."""
    if not STATE.exists():
        return {"emitted": False, "reason": "state.json missing"}
    state = json.loads(STATE.read_text())
    history = state.get("history") or []
    entry = next((h for h in history if h.get("turn") == turn), None)
    if entry is None:
        return {"emitted": False, "reason": f"turn {turn} not in history"}

    judge_path = JUDGE_DIR / f"turn_{turn}.json"
    judge = {}
    if judge_path.exists():
        try:
            judge = json.loads(judge_path.read_text())
        except json.JSONDecodeError:
            pass

    n = _now_ns()
    common = {
        "investigation_id": entry.get("investigation_id"),
        "stage_advancing_to": entry.get("stage_advancing_to"),
        "directive_label": entry.get("directive_label"),
        "directive_action": entry.get("directive_action"),
    }

    # Parent span for the turn
    parent_id = emit_span(turn, "loop.turn", attrs=common, start_ns=n - 1_000_000, end_ns=n)

    # Judge span
    emit_span(turn, "loop.judge", attrs={
        **common,
        "verdict": entry.get("judge_status"),
        "n_issues": len((judge.get("issues") or [])),
        "contract_verdict": (judge.get("contract_evaluation") or {}).get("verdict"),
    }, parent=parent_id, start_ns=n, end_ns=n)

    # Metrics
    tokens = entry.get("tokens_used") or {}
    eff = tokens.get("effective_full_rate")
    if isinstance(eff, (int, float)):
        emit_metric("loop.cost_eff_per_turn", eff,
                    attrs={"turn": turn, "verdict": entry.get("judge_status")})
    total = tokens.get("total")
    if isinstance(total, (int, float)):
        emit_metric("loop.tokens_total", total,
                    attrs={"turn": turn}, kind="counter")

    verdict = entry.get("judge_status") or "UNKNOWN"
    emit_metric(f"loop.judge.verdict.{verdict}", 1.0,
                attrs={"turn": turn}, kind="counter")

    drift = entry.get("drift_advisories") or []
    for advisory in drift:
        marker = advisory.split(":")[0].strip()
        emit_metric(f"loop.drift_signal.{marker}", 1.0,
                    attrs={"turn": turn, "advisory_text": advisory[:200]},
                    kind="counter")

    cost_audit = entry.get("cost_audit") or {}
    if cost_audit.get("flag"):
        emit_metric(f"loop.cost_audit.{cost_audit['flag']}", 1.0,
                    attrs={"turn": turn, "ratio": cost_audit.get("ratio_actual_over_expected")},
                    kind="counter")

    inv_id = entry.get("investigation_id")
    if inv_id:
        inv = (state.get("investigations") or {}).get(inv_id) or {}
        tier = inv.get("tier_current")
        if isinstance(tier, (int, float)):
            emit_metric("loop.investigation.tier_current", tier,
                        attrs={"investigation_id": inv_id, "turn": turn})

    wall = entry.get("wall_time_sec")
    if isinstance(wall, (int, float)):
        emit_metric("loop.wall_time_sec", wall, attrs={"turn": turn})

    # 2026-05-19 quota-conservation telemetry:
    # (a) cache_hit_rate — how much of input was served from prompt cache.
    breakdown = tokens.get("breakdown") or {}
    cache_read = breakdown.get("cache_read") or 0
    cache_creation = breakdown.get("cache_creation") or 0
    input_fresh = breakdown.get("input_fresh") or 0
    total_input = cache_read + cache_creation + input_fresh
    if total_input > 0:
        hit_rate = round(cache_read / total_input, 4)
        emit_metric("loop.cache_hit_rate", hit_rate,
                    attrs={"turn": turn, "cache_read": cache_read,
                           "cache_creation": cache_creation,
                           "input_fresh": input_fresh})

    # (b) critic_lite.verdict — scan runs/_loop/critic_lite/turn_<N>.md for the
    # verdict field. If critic_lite was dispatched this turn, record its outcome.
    crit_lite_path = ROOT / "runs/_loop/critic_lite" / f"turn_{turn}.md"
    if crit_lite_path.exists():
        try:
            txt = crit_lite_path.read_text(encoding="utf-8")
            m = __import__("re").search(r'"verdict"\s*:\s*"([A-Z_]+)"', txt)
            if m:
                emit_metric(f"loop.critic_lite.verdict.{m.group(1)}", 1.0,
                            attrs={"turn": turn}, kind="counter")
        except Exception:
            pass

    return {"emitted": True, "trace_id": f"loop-turn-{turn}", "parent_span_id": parent_id}


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    s_sp = sub.add_parser("span")
    s_sp.add_argument("--turn", type=int, required=True)
    s_sp.add_argument("--name", required=True)
    s_sp.add_argument("--attr", action="append", default=[],
                      help="key=value attribute (repeat)")
    s_sp.add_argument("--parent", default=None)

    s_m = sub.add_parser("metric")
    s_m.add_argument("--name", required=True)
    s_m.add_argument("--value", type=float, required=True)
    s_m.add_argument("--attr", action="append", default=[])
    s_m.add_argument("--kind", default="gauge", choices=["gauge", "counter"])

    s_l = sub.add_parser("log")
    s_l.add_argument("--turn", type=int, required=True)
    s_l.add_argument("--level", default="INFO", choices=["INFO", "WARN", "ERROR"])
    s_l.add_argument("--body", required=True)

    s_t = sub.add_parser("turn-summary")
    s_t.add_argument("--turn", type=int, required=True)

    args = ap.parse_args()

    if args.cmd == "span":
        attrs = dict(kv.split("=", 1) for kv in args.attr if "=" in kv)
        span_id = emit_span(args.turn, args.name, attrs, parent=args.parent)
        print(span_id)
    elif args.cmd == "metric":
        attrs = dict(kv.split("=", 1) for kv in args.attr if "=" in kv)
        emit_metric(args.name, args.value, attrs, kind=args.kind)
        print("OK")
    elif args.cmd == "log":
        emit_log(args.turn, args.level, args.body)
        print("OK")
    elif args.cmd == "turn-summary":
        r = turn_summary(args.turn)
        print(json.dumps(r))

    return 0


if __name__ == "__main__":
    sys.exit(main())
