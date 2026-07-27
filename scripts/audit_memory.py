#!/usr/bin/env python3
"""Audit the project's Claude memory tree for silent rot.

    python3 scripts/audit_memory.py [--memory-dir DIR] [--limit 17100]

Three failure modes, all of which were live on 2026-07-27 and none of which
announce themselves:

1. **Unreachable files.** `MEMORY.md` is the only thing loaded at session
   start. A memory that is neither indexed there nor linked from something
   that is will never be read again. 43 of 233 files (18%) were in this
   state, including the type-stability pitfalls and two Zeeman sign
   mistakes. Knowledge written down but never loaded is worse than absent:
   it creates the belief that a lesson was captured.

2. **Dangling `[[links]]`.** Renames drift and the pointer rots silently.
   13 were broken, two of them malformed enough to have swallowed a
   paragraph of prose into a link target.

3. **Index over budget.** `MEMORY.md` past the read limit gets truncated,
   which silently drops whatever is at the bottom.

Exits non-zero if any check fails, so it can gate.
"""
import argparse
import pathlib
import re
import sys
from collections import defaultdict

DEFAULT_DIR = pathlib.Path.home() / ".claude/projects/-home-suzume-workspace-BEC-simulation/memory"
INDEXES = ("MEMORY", "memory_index_history")


def load(memdir):
    return {p.stem: p.read_text(encoding="utf-8") for p in sorted(memdir.glob("*.md"))}


_FENCE = re.compile(r"```.*?```", re.S)
_INLINE = re.compile(r"`[^`\n]*`")


def prose(text):
    """Text with code fences and inline spans removed.

    A memory that *documents* the `[[link]]` syntax must not be flagged for
    mentioning it — a linter you cannot write about is broken. Scanning
    stripped prose also keeps `Verify:` blocks (which contain real code, and
    sometimes brackets) out of the link graph.
    """
    return _INLINE.sub(" ", _FENCE.sub(" ", text))


def resolvable_names(texts):
    names = set(texts)
    for stem, t in texts.items():
        m = re.search(r"^name:\s*(.+)$", t, re.M)
        if m:
            names.add(m.group(1).strip().strip("\"'"))
        names.add(stem.replace("_", "-"))
    return names


def reachable(texts, roots, hops=4):
    """Files reachable from the indexes via markdown links, then [[links]]."""
    seen = set(roots)
    for _ in range(hops):
        for stem in list(seen):
            for lk in re.findall(r"\[\[([^\]]+)\]\]", prose(texts.get(stem, ""))):
                key = (lk[:-3] if lk.endswith(".md") else lk).replace("-", "_")
                if key in texts:
                    seen.add(key)
    return seen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--memory-dir", type=pathlib.Path, default=DEFAULT_DIR)
    ap.add_argument("--limit", type=int, default=17100, help="MEMORY.md byte budget")
    args = ap.parse_args()

    memdir = args.memory_dir
    if not memdir.is_dir():
        print(f"no memory dir at {memdir}", file=sys.stderr)
        return 2
    texts = load(memdir)
    if "MEMORY" not in texts:
        print("no MEMORY.md", file=sys.stderr)
        return 2

    index_text = "".join(prose(texts.get(i, "")) for i in INDEXES)
    linked = set(re.findall(r"\]\(([A-Za-z0-9_\-]+)\.md\)", index_text))
    reach = reachable(texts, linked)
    orphans = sorted(set(texts) - reach - set(INDEXES))
    broken_index = sorted(linked - set(texts))

    names = resolvable_names(texts)
    dangling = defaultdict(list)
    for stem, t in texts.items():
        for lk in re.findall(r"\[\[([^\]]+)\]\]", prose(t)):
            key = lk[:-3] if lk.endswith(".md") else lk
            if key not in names and key.replace("-", "_") not in texts:
                dangling[key].append(stem)

    size = len(texts["MEMORY"].encode("utf-8"))
    fails = []

    print(f"memories            : {len(texts) - len(INDEXES)}")
    print(f"MEMORY.md size      : {size} / {args.limit} bytes")
    if size > args.limit:
        fails.append(f"MEMORY.md is {size - args.limit} bytes over budget — it will be truncated")

    print(f"unreachable files   : {len(orphans)}")
    for o in orphans[:20]:
        print(f"    {o}")
    if orphans:
        fails.append(f"{len(orphans)} memories are reachable from nothing and will never load")

    print(f"dangling [[links]]  : {len(dangling)}")
    for k, v in sorted(dangling.items())[:20]:
        print(f"    [[{k}]]  <- {', '.join(v[:3])}")
    if dangling:
        fails.append(f"{len(dangling)} [[links]] point at nothing")

    print(f"index -> missing    : {broken_index}")
    if broken_index:
        fails.append(f"index links to {len(broken_index)} missing files")

    if fails:
        print("\nFAIL")
        for f in fails:
            print(f"  - {f}")
        return 1
    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
