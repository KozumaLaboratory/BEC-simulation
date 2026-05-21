#!/usr/bin/env python3
"""Twice rule for feedback memories (2026-05-18).

Premise: when anko gives the SAME correction twice on different
occasions, the memory system should treat it as elevated. Two
feedback memories on the same topic = a rule that has been
reinforced and deserves a more prominent home (e.g., a hoist into
project-level CLAUDE.md or a top-of-MEMORY.md "active rules"
section).

This script:
  1. Scans feedback_*.md memory files
  2. Computes pairwise topic / body similarity
  3. Flags pairs above a threshold as "twice candidates"
  4. (with --hoist) appends to MEMORY.md an "active rules" anchor
     pointing to each twice-detected feedback

The intent is NOT to dedupe — both memories stay (they may have
different rationale lines). The hoist surfaces the *class*.

Usage:
    memory_twice_rule.py scan              # list candidates
    memory_twice_rule.py scan --json       # machine-readable
    memory_twice_rule.py hoist             # write active-rules block
                                           # at top of MEMORY.md
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from collections import Counter

MEM_DIR = Path("/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory")
MEMORY_INDEX = MEM_DIR / "MEMORY.md"

STOPWORDS = {
    "the", "a", "an", "is", "are", "was", "were", "be", "been", "to",
    "of", "in", "on", "at", "by", "for", "with", "without", "this",
    "that", "these", "those", "and", "or", "but", "not", "if", "as",
    "from", "into", "out", "up", "down", "than", "then", "do", "does",
    "did", "doing", "have", "has", "had", "having", "i", "you", "we",
    "they", "it", "its", "use", "used", "when", "where", "why", "how",
    "what", "which", "who", "whose", "should", "would", "could", "may",
    "might", "must", "can", "will", "shall", "any", "all", "some",
    "no", "yes", "very", "just", "only", "even", "still", "also",
    "memory", "feedback", "rule", "claim", "user", "anko",
}


def _tokenize(text: str) -> Counter:
    text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)
    text = re.sub(r"\[\[[^\]]+\]\]", " ", text)
    tokens = re.findall(r"[a-z][a-z_-]{2,}", text.lower())
    return Counter(t for t in tokens if t not in STOPWORDS)


def _jaccard(a: Counter, b: Counter) -> float:
    if not a or not b:
        return 0.0
    keys_a = set(a)
    keys_b = set(b)
    inter = keys_a & keys_b
    union = keys_a | keys_b
    return len(inter) / len(union) if union else 0.0


def _load_memory(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    # Strip frontmatter
    fm = re.match(r"^---\s*\n(.*?)\n---\s*\n(.*)$", text, re.DOTALL)
    if fm:
        body = fm.group(2)
        desc = ""
        for ln in fm.group(1).splitlines():
            m = re.match(r"description:\s*(.*)", ln)
            if m:
                desc = m.group(1).strip()
    else:
        body = text
        desc = ""
    return {
        "path": path,
        "name": path.stem,
        "description": desc,
        "body": body,
        "tokens": _tokenize(desc + " " + body),
    }


def scan() -> list[dict]:
    files = sorted(MEM_DIR.glob("feedback_*.md"))
    mems = [_load_memory(p) for p in files]
    pairs: list[dict] = []
    for i, a in enumerate(mems):
        for b in mems[i + 1:]:
            sim = _jaccard(a["tokens"], b["tokens"])
            if sim >= 0.18:
                overlap = sorted((set(a["tokens"]) & set(b["tokens"])),
                                 key=lambda k: -(a["tokens"][k] + b["tokens"][k]))[:6]
                pairs.append({
                    "a": a["name"],
                    "b": b["name"],
                    "jaccard": round(sim, 3),
                    "a_desc": a["description"],
                    "b_desc": b["description"],
                    "top_overlap_terms": overlap,
                })
    pairs.sort(key=lambda p: -p["jaccard"])
    return pairs


def hoist() -> dict:
    pairs = scan()
    if not pairs:
        return {"ok": True, "n_pairs": 0, "wrote": False}
    if not MEMORY_INDEX.exists():
        return {"ok": False, "reason": "no MEMORY.md"}

    text = MEMORY_INDEX.read_text(encoding="utf-8")

    block_start = "<!-- twice-rule:auto-start -->"
    block_end = "<!-- twice-rule:auto-end -->"
    block_lines = [block_start, "## Active rules (twice-reinforced feedback)"]
    seen_files: set[str] = set()
    for p in pairs[:5]:
        for f in (p["a"], p["b"]):
            if f in seen_files:
                continue
            seen_files.add(f)
            block_lines.append(f"- [{f.replace('feedback_', '')}]({f}.md) — twice-reinforced (paired with [[{p['a'] if f == p['b'] else p['b']}]])")
    block_lines.append(block_end)
    new_block = "\n".join(block_lines) + "\n"

    pat = re.compile(re.escape(block_start) + r".*?" + re.escape(block_end) + r"\n?", re.DOTALL)
    if pat.search(text):
        text = pat.sub(new_block, text)
    else:
        text = new_block + "\n" + text

    MEMORY_INDEX.write_text(text)
    return {"ok": True, "n_pairs": len(pairs), "hoisted": list(seen_files), "wrote": True}


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("scan")
    s.add_argument("--json", action="store_true")

    sub.add_parser("hoist")

    args = ap.parse_args()
    if args.cmd == "scan":
        pairs = scan()
        if args.json:
            print(json.dumps(pairs, indent=2, default=str))
        else:
            if not pairs:
                print("no twice-reinforced feedback pairs detected")
                return 0
            for p in pairs:
                print(f"jaccard={p['jaccard']:.2f}  {p['a']}  <—>  {p['b']}")
                print(f"  overlap: {', '.join(p['top_overlap_terms'])}")
    elif args.cmd == "hoist":
        print(json.dumps(hoist(), indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
