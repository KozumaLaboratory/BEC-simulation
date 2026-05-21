#!/usr/bin/env python3
"""Selective forgetting (2026-05-18, Item 5).

Three modes:

  1. otel-rotate — compress old entries in
     `.claude/logs/otel_traces.ndjson` to `.claude/logs/archive/`
     when the file exceeds size or line thresholds. Keep the
     recent tail uncompressed for fast queries.

  2. logs-prune — delete per-turn `*_${TURN}.log` files older than
     N days. The interesting failures already got promoted to
     state.json / status_md / OTEL traces; per-turn raw logs are
     only useful within the same week.

  3. memory-cool — move project-type memory files that have not
     been touched (per `.touch_log.jsonl`) in the last K turns to
     `memory/_cold/`. User and feedback types are NEVER cooled —
     they're durable instructions / corrections. Reference and
     project types may cool.

Selectiveness rationale: forgetting is not amnesia. We retain
  - all feedback / user memories (they are durable corrections)
  - the last N OTEL turns (for current-week queries)
  - per-turn logs of the last 30 days (for retro)
We discard
  - OTEL entries past N (compressed-archived, recoverable)
  - per-turn logs past 30 days
  - cold project memories (moved to _cold, recoverable)

Usage:
    forgetting.py otel-rotate          # if file exceeds threshold
    forgetting.py logs-prune --days 30
    forgetting.py memory-cool --cold-after-turns 80
    forgetting.py all                  # run all three with defaults
"""

from __future__ import annotations

import argparse
import gzip
import json
import re
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path("/home/suzume/workspace/BEC-simulation")
LOGS = ROOT / ".claude" / "logs"
ARCHIVE = LOGS / "archive"
OTEL = LOGS / "otel_traces.ndjson"
STATE = ROOT / "runs" / "_loop" / "state.json"

MEM = Path("/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory")
COLD = MEM / "_cold"
TOUCH_LOG = MEM / ".touch_log.jsonl"
INDEX = MEM / "MEMORY.md"

# Thresholds
OTEL_KEEP_LINES = 600         # keep tail of this many lines
OTEL_MAX_LINES = 1500         # rotate when above this
LOGS_PRUNE_DAYS = 30          # delete *_<turn>.log files older than this
MEM_COOL_TURNS = 80           # memory not touched in this many turns → cold


def _current_turn() -> int:
    try:
        return int(json.loads(STATE.read_text()).get("turn", 0))
    except Exception:
        return 0


def otel_rotate(force: bool = False) -> dict:
    if not OTEL.exists():
        return {"ok": True, "skipped": "no otel file"}
    lines = OTEL.read_text().splitlines()
    n = len(lines)
    if not force and n <= OTEL_MAX_LINES:
        return {"ok": True, "skipped": f"only {n} lines, threshold {OTEL_MAX_LINES}"}
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    archive_lines = lines[:-OTEL_KEEP_LINES] if not force else lines
    keep_lines = lines[-OTEL_KEEP_LINES:] if not force else []
    if not archive_lines:
        return {"ok": True, "skipped": "nothing to archive"}
    stamp = datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H%M%SZ")
    out = ARCHIVE / f"otel_traces_{stamp}.ndjson.gz"
    with gzip.open(out, "wt") as fh:
        fh.write("\n".join(archive_lines) + "\n")
    OTEL.write_text("\n".join(keep_lines) + ("\n" if keep_lines else ""))
    return {
        "ok": True,
        "archived": str(out.relative_to(ROOT)),
        "n_archived": len(archive_lines),
        "n_remaining": len(keep_lines),
    }


def logs_prune(days: int = LOGS_PRUNE_DAYS) -> dict:
    if not LOGS.exists():
        return {"ok": True, "skipped": "no logs dir"}
    cutoff = time.time() - days * 86400
    pat = re.compile(r"_\d+\.log$")
    n_removed = 0
    bytes_freed = 0
    for f in LOGS.iterdir():
        if not f.is_file() or not pat.search(f.name):
            continue
        if f.stat().st_mtime < cutoff:
            bytes_freed += f.stat().st_size
            f.unlink()
            n_removed += 1
    return {"ok": True, "n_removed": n_removed, "bytes_freed": bytes_freed, "days": days}


def _read_touch_log() -> dict[str, int]:
    """Return {memory_name: last_touched_turn}."""
    out: dict[str, int] = {}
    if not TOUCH_LOG.exists():
        return out
    for ln in TOUCH_LOG.read_text().splitlines():
        try:
            r = json.loads(ln)
            name = r.get("slug") or r.get("name")
            turn = r.get("turn")
            if name and isinstance(turn, int):
                out[name] = max(out.get(name, 0), turn)
        except json.JSONDecodeError:
            continue
    return out


def memory_cool(cold_after_turns: int = MEM_COOL_TURNS) -> dict:
    """Move project/reference memories not touched in N turns to _cold/.
    Never cool feedback or user memories."""
    if not MEM.exists():
        return {"ok": True, "skipped": "no memory dir"}
    current = _current_turn()
    if current == 0:
        return {"ok": True, "skipped": "no current turn (state.json unreadable)"}
    touches = _read_touch_log()
    COLD.mkdir(parents=True, exist_ok=True)
    cooled: list[str] = []
    skipped: list[str] = []
    for f in MEM.glob("*.md"):
        if f.name in ("MEMORY.md",) or f.name.startswith("_"):
            continue
        # Read frontmatter type
        text = f.read_text(encoding="utf-8", errors="ignore")[:600]
        m = re.search(r"^type:\s*([a-z]+)\s*$", text, re.MULTILINE)
        mtype = m.group(1) if m else "unknown"
        if mtype in ("user", "feedback"):
            continue
        last = touches.get(f.stem)
        # If never touched, fall back to file mtime
        if last is None:
            mtime = f.stat().st_mtime
            mtime_turn = current - max(0, int((time.time() - mtime) / 86400 / 0.5))
            last = mtime_turn
        age = current - last
        if age >= cold_after_turns:
            dest = COLD / f.name
            shutil.move(str(f), str(dest))
            cooled.append(f.name)
        else:
            skipped.append(f"{f.name}({age}t old)")
    return {
        "ok": True,
        "current_turn": current,
        "cold_after_turns": cold_after_turns,
        "n_cooled": len(cooled),
        "cooled": cooled,
        "n_kept_active": len(skipped),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    o = sub.add_parser("otel-rotate")
    o.add_argument("--force", action="store_true")

    lg = sub.add_parser("logs-prune")
    lg.add_argument("--days", type=int, default=LOGS_PRUNE_DAYS)

    m = sub.add_parser("memory-cool")
    m.add_argument("--cold-after-turns", type=int, default=MEM_COOL_TURNS)
    m.add_argument("--dry-run", action="store_true",
                   help="Print which files would be cooled without moving them")

    sub.add_parser("all")

    args = ap.parse_args()
    if args.cmd == "otel-rotate":
        r = otel_rotate(args.force)
    elif args.cmd == "logs-prune":
        r = logs_prune(args.days)
    elif args.cmd == "memory-cool":
        if args.dry_run:
            # Quick path: same as memory_cool but using MEM_COOL_TURNS large
            # enough not to cool anything; we just report ages.
            current = _current_turn()
            touches = _read_touch_log()
            report = []
            for f in MEM.glob("*.md"):
                if f.name in ("MEMORY.md",) or f.name.startswith("_"):
                    continue
                last = touches.get(f.stem)
                if last is None:
                    last = "(no touch record, falls back to mtime)"
                report.append({"name": f.name, "last_touch": last})
            r = {"ok": True, "dry_run": True, "current_turn": current,
                 "entries": report}
        else:
            r = memory_cool(args.cold_after_turns)
    elif args.cmd == "all":
        r = {
            "otel_rotate": otel_rotate(),
            "logs_prune": logs_prune(),
            "memory_cool": memory_cool(),
        }
    print(json.dumps(r, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
