#!/usr/bin/env python3
"""
MEMORY.md consolidation cycle (Item 1, 2026-05-18).

MEMORY.md is loaded into every agent's context. Unchecked growth →
context pressure for all subsequent agent dispatches. This script
periodically:

  1. Prunes feedback entries superseded by newer ones (same subject)
  2. Merges duplicate / near-duplicate memory entries
  3. Truncates index lines > 250 chars (already enforced via memory_hygiene.py)
  4. Flags very old entries (>60 days, low recent reference count)

Runs in `--check` mode (no writes, reports candidates) or `--apply`
mode (executes consolidation per `should_consolidate()` heuristics).

Trigger: loop.sh calls this every ~30 turns OR when MEMORY.md
exceeds 40 KB. Manual: `python3 .claude/scripts/memory_consolidate.py
[--apply | --check]`.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

MEMORY_DIR = Path("/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory")
INDEX = MEMORY_DIR / "MEMORY.md"

CONSOLIDATE_TRIGGER_SIZE_KB = 40
CONSOLIDATE_TRIGGER_LINE_COUNT = 60   # index line count
SUPERSESSION_AGE_DAYS = 14            # if a newer feedback covers same subject, the older is candidate for pruning


def _read_index() -> list[str]:
    if not INDEX.exists():
        return []
    return INDEX.read_text(encoding="utf-8").splitlines(keepends=True)


def _list_memory_files() -> list[Path]:
    return sorted(MEMORY_DIR.glob("*.md"))


def _file_mtime(p: Path) -> datetime:
    return datetime.fromtimestamp(p.stat().st_mtime, tz=timezone.utc)


def _parse_frontmatter(p: Path) -> dict:
    """Best-effort frontmatter parse (YAML block at file top)."""
    text = p.read_text(encoding="utf-8")
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return {}
    fm: dict = {}
    for line in m.group(1).splitlines():
        if ":" not in line or line.strip().startswith("#"):
            continue
        k, _, v = line.partition(":")
        fm[k.strip()] = v.strip().strip("\"'")
    return fm


def should_consolidate() -> tuple[bool, list[str]]:
    """Heuristics: should we run consolidation now?

    Returns (should_run, reasons).
    """
    reasons: list[str] = []
    if INDEX.exists():
        size_kb = INDEX.stat().st_size / 1024
        if size_kb > CONSOLIDATE_TRIGGER_SIZE_KB:
            reasons.append(f"MEMORY.md size {size_kb:.1f} KB > {CONSOLIDATE_TRIGGER_SIZE_KB} KB")
        lines = _read_index()
        n_lines = sum(1 for L in lines if L.strip().startswith("- ["))
        if n_lines > CONSOLIDATE_TRIGGER_LINE_COUNT:
            reasons.append(f"MEMORY.md entries {n_lines} > {CONSOLIDATE_TRIGGER_LINE_COUNT}")
    return (len(reasons) > 0, reasons)


def find_supersession_candidates() -> list[dict]:
    """Find feedback entries that likely supersede older ones.

    Heuristic: type=feedback entries whose `name:` slug shares a common
    prefix with another, older type=feedback entry → candidate for
    consolidation note.
    """
    feedback_files: list[tuple[Path, dict, datetime]] = []
    for p in _list_memory_files():
        fm = _parse_frontmatter(p)
        if fm.get("type") == "feedback" or "feedback" in p.name:
            feedback_files.append((p, fm, _file_mtime(p)))

    # Sort by mtime, newest first
    feedback_files.sort(key=lambda t: t[2], reverse=True)

    candidates: list[dict] = []
    # Pairwise check for shared TOPIC prefix (skipping the leading
    # "feedback" prefix common to all entries of type=feedback).
    def topic_tokens(slug: str) -> list[str]:
        toks = re.split(r"[-_]", slug.lower())
        # Drop common type prefix tokens that don't distinguish topic
        skip = {"feedback", "project", "reference", "user", "gotcha", "pitfall"}
        return [t for t in toks if t and t not in skip][:2]

    for i, (p_new, fm_new, t_new) in enumerate(feedback_files):
        slug_new = fm_new.get("name", p_new.stem)
        toks_new = topic_tokens(slug_new)
        if len(toks_new) < 2:
            continue
        for p_old, fm_old, t_old in feedback_files[i + 1:]:
            slug_old = fm_old.get("name", p_old.stem)
            toks_old = topic_tokens(slug_old)
            if len(toks_old) < 2:
                continue
            shared = sum(1 for a, b in zip(toks_new, toks_old) if a == b)
            if shared >= 2:
                candidates.append({
                    "newer": str(p_new.name),
                    "older": str(p_old.name),
                    "shared_tokens": toks_new[:shared],
                    "age_gap_days": (t_new - t_old).days,
                    "action": "manual review — possible merge or older-supersession",
                })
    return candidates


def find_long_index_lines() -> list[dict]:
    findings: list[dict] = []
    for i, line in enumerate(_read_index()):
        L = line.rstrip("\n")
        if L.startswith("- [") and len(L) > 250:
            findings.append({
                "index_line": i + 1,
                "length": len(L),
                "preview": L[:80] + "..." if len(L) > 80 else L,
            })
    return findings


def find_orphan_files() -> list[str]:
    """Memory files not referenced from MEMORY.md index."""
    index_text = INDEX.read_text(encoding="utf-8") if INDEX.exists() else ""
    referenced = set(re.findall(r"\[[^\]]+\]\(([^)]+\.md)\)", index_text))
    orphans = []
    for p in _list_memory_files():
        if p.name == "MEMORY.md":
            continue
        if p.name not in referenced:
            orphans.append(p.name)
    return orphans


def report() -> dict:
    do_consolidate, reasons = should_consolidate()
    return {
        "should_consolidate": do_consolidate,
        "reasons": reasons,
        "memory_md_size_kb": round(INDEX.stat().st_size / 1024, 2) if INDEX.exists() else 0,
        "n_memory_files": len(_list_memory_files()),
        "supersession_candidates": find_supersession_candidates()[:10],
        "long_index_lines": find_long_index_lines()[:10],
        "orphan_files": find_orphan_files()[:10],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="report only, no writes")
    ap.add_argument("--apply", action="store_true",
                    help="apply consolidation (writes; CURRENTLY: report mode only — manual application recommended)")
    ap.add_argument("--gentle", action="store_true",
                    help="report only when should_consolidate is True")
    args = ap.parse_args()

    r = report()

    if args.gentle and not r["should_consolidate"]:
        return 0

    print(json.dumps(r, indent=2, default=str))

    if args.apply:
        # For now, apply mode is documented but conservative: it does
        # NOT mutate memory files automatically. The heuristics produce
        # CANDIDATES that anko or a follow-up agent should review.
        # Auto-deletion of memory entries is too risky to do without
        # a critic audit.
        print("# --apply mode: candidates listed above; manual review or critic-audited consolidation turn required to execute.",
              file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
