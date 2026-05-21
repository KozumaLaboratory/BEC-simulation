#!/usr/bin/env python3
"""
Memory hygiene check — Upgrade A (1000-turn design).

Ensures MEMORY.md (auto-loaded into every subagent context) stays a
compact one-line-per-topic INDEX. Detail goes to per-topic files,
loaded on-demand via Read.

Per `long_horizon_design.md` §2 A:
- Letta core/archival/cold pattern [Packer 2023]
- Anthropic /memory 84% token reduction at 100 turns [2025]
- Codex CLI AGENTS.md compaction at 25h horizon [OpenAI 2025]

Run modes:
    memory_hygiene.py check        # one-shot audit
    memory_hygiene.py spill         # move cold entries
    memory_hygiene.py touch <slug>  # mark a topic file as read this turn

Outputs JSON. Exit 0 OK, 1 WARN, 2 FAIL.
"""

from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

# Per-project memory location (anko's Claude Code auto-memory)
MEMORY_DIR = Path(
    "/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory"
)
INDEX_FILE = MEMORY_DIR / "MEMORY.md"
COLD_DIR = MEMORY_DIR / "_cold"
TOUCH_FILE = MEMORY_DIR / ".touch_log.jsonl"

# Thresholds (tunable)
INDEX_SIZE_WARN_KB = 50    # warn when MEMORY.md exceeds this
INDEX_SIZE_FAIL_KB = 100   # fail (block loop) if exceeds
INDEX_LINE_MAX_CHARS = 250 # entry too long → push to detail file
COLD_TURNS_THRESHOLD = 100 # files unread for this many turns → cold


def check() -> dict:
    """Audit MEMORY.md + per-topic files. Return status + issues."""
    if not INDEX_FILE.exists():
        return {"status": "FAIL", "reason": f"{INDEX_FILE} missing"}

    size_kb = INDEX_FILE.stat().st_size / 1024
    text = INDEX_FILE.read_text()
    lines = text.splitlines()
    issues: list[str] = []
    warnings: list[str] = []

    if size_kb > INDEX_SIZE_FAIL_KB:
        issues.append(
            f"MEMORY.md is {size_kb:.1f} KB > {INDEX_SIZE_FAIL_KB} KB fail threshold. "
            f"Consolidate entries to detail files."
        )
    elif size_kb > INDEX_SIZE_WARN_KB:
        warnings.append(
            f"MEMORY.md is {size_kb:.1f} KB > {INDEX_SIZE_WARN_KB} KB warn threshold."
        )

    # Per-line audit: entries should be ≤ INDEX_LINE_MAX_CHARS
    long_lines: list[tuple[int, int, str]] = []
    for i, line in enumerate(lines, 1):
        if len(line) > INDEX_LINE_MAX_CHARS and line.lstrip().startswith("- "):
            long_lines.append((i, len(line), line[:80] + "..."))
    if long_lines:
        warnings.append(
            f"{len(long_lines)} entries exceed {INDEX_LINE_MAX_CHARS} chars; "
            f"first: L{long_lines[0][0]} ({long_lines[0][1]} chars)"
        )

    # Per-topic file resolution: each [link](file.md) must point at an
    # existing memory dir file.
    link_pattern = re.compile(r"\[([^\]]+)\]\(([^)]+\.md)\)")
    broken_links: list[str] = []
    for m in link_pattern.finditer(text):
        target = m.group(2)
        if target.startswith("http") or target.startswith("/"):
            continue
        if not (MEMORY_DIR / target).exists():
            broken_links.append(target)
    if broken_links:
        issues.append(
            f"{len(broken_links)} broken intra-memory links; "
            f"first: {broken_links[0]}"
        )

    # Cold-storage candidates: count topic files not touched recently
    cold_candidates = _cold_candidates()

    # Per-subagent role tagging present?
    has_role_sections = any(
        h.startswith("## ") and any(
            tag in h.lower()
            for tag in ["physics", "implementation", "literature", "code"]
        )
        for h in lines if h.startswith("## ")
    )

    return {
        "status": "FAIL" if issues else ("WARN" if warnings else "OK"),
        "size_kb": round(size_kb, 1),
        "line_count": len(lines),
        "long_lines": len(long_lines),
        "broken_links": len(broken_links),
        "cold_candidate_count": len(cold_candidates),
        "has_role_sections": has_role_sections,
        "warnings": warnings,
        "issues": issues,
    }


def _cold_candidates() -> list[Path]:
    """Topic files not Read in the last COLD_TURNS_THRESHOLD turns.

    Reads .touch_log.jsonl (one line per Read of a memory file).
    Returns files older than threshold.
    """
    if not TOUCH_FILE.exists():
        return []

    last_seen: dict[str, float] = {}
    with TOUCH_FILE.open() as fp:
        for line in fp:
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            slug = e.get("slug", "")
            ts = e.get("ts", 0)
            if slug and isinstance(ts, (int, float)):
                last_seen[slug] = max(last_seen.get(slug, 0), ts)

    now = time.time()
    # Heuristic: 100 turns ~ 24h at observed 12-min cadence
    cold_seconds = COLD_TURNS_THRESHOLD * 12 * 60

    candidates: list[Path] = []
    for f in MEMORY_DIR.glob("*.md"):
        if f.name == "MEMORY.md":
            continue
        if f.name.startswith("."):
            continue
        slug = f.stem
        if slug not in last_seen:
            # Never touched (or pre-touch-log era) — old enough to be cold
            candidates.append(f)
        elif (now - last_seen[slug]) > cold_seconds:
            candidates.append(f)
    return candidates


def touch(slug: str) -> dict:
    """Record that a memory file was Read this turn."""
    if not slug:
        return {"status": "FAIL", "reason": "empty slug"}
    TOUCH_FILE.parent.mkdir(parents=True, exist_ok=True)
    entry = {"slug": slug, "ts": time.time()}
    with TOUCH_FILE.open("a") as fp:
        fp.write(json.dumps(entry) + "\n")
    return {"status": "OK", "logged": slug}


def spill() -> dict:
    """Move cold entries to _cold/ subdir (no delete; reversible)."""
    COLD_DIR.mkdir(parents=True, exist_ok=True)
    candidates = _cold_candidates()
    moved: list[str] = []
    for f in candidates:
        dest = COLD_DIR / f.name
        if dest.exists():
            continue
        f.rename(dest)
        moved.append(f.name)
    return {"status": "OK", "moved": moved, "moved_count": len(moved)}


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    if mode == "check":
        result = check()
    elif mode == "touch":
        slug = sys.argv[2] if len(sys.argv) > 2 else ""
        result = touch(slug)
    elif mode == "spill":
        result = spill()
    else:
        result = {"status": "FAIL", "reason": f"unknown mode {mode!r}"}

    print(json.dumps(result, indent=2))
    if result.get("status") == "OK":
        return 0
    if result.get("status") == "WARN":
        return 1
    return 2


if __name__ == "__main__":
    sys.exit(main())
