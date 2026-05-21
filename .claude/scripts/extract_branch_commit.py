#!/usr/bin/env python3
"""
Extract implementer's branch + commit SHA from sim/turn_N.md §2.

The orchestrator was missing these fields when patching state.json's
history entry (T2 showed `commit: null, branch: null` despite
implementer committing). This script parses §2 of the implementer's
sim report:

    ## 2. Branch / commit
    - Branch: `auto/turn_N_<label>`
    - Parent: `<sha>`
    - Commits: [`<sha>`]
    - Files changed: [...]

Outputs JSON:
    {"branch": "auto/turn_N_<label>", "commit": "<short-sha>", "parent": "<sha>"}

Usage:
    python3 .claude/scripts/extract_branch_commit.py <path-to-sim-turn_N.md>

Exit 0 always; missing fields emit null values.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def extract(path: Path) -> dict:
    out = {"branch": None, "commit": None, "parent": None}
    if not path.exists():
        return out
    text = path.read_text(encoding="utf-8")

    # Find §2 block
    sec = re.search(
        r"## 2\.\s*Branch[^\n]*\n(.*?)(?=\n## |\Z)",
        text,
        re.DOTALL,
    )
    if not sec:
        return out
    block = sec.group(1)

    # Branch: `auto/turn_N_<label>` (allow bare, backticked, or with
    # leading hyphen bullet)
    m = re.search(
        r"branch[\s:]*[`*]*(auto/turn_\d+_[^\s`]+)",
        block,
        re.IGNORECASE,
    )
    if m:
        out["branch"] = m.group(1).strip("`* ")

    # Commit: 7-40 hex chars in backticks, after "Commits:" or
    # "Commit:" or as last sha mentioned
    m = re.search(
        r"commits?[\s:]*\[?[`*]*([0-9a-f]{7,40})",
        block,
        re.IGNORECASE,
    )
    if m:
        out["commit"] = m.group(1)[:12]  # keep at most 12 chars for compactness

    # Parent: 7-40 hex chars after "Parent:"
    m = re.search(
        r"parent[\s:]*[`*]*([0-9a-f]{7,40})",
        block,
        re.IGNORECASE,
    )
    if m:
        out["parent"] = m.group(1)[:12]

    return out


def main() -> int:
    if len(sys.argv) != 2:
        print(json.dumps({"branch": None, "commit": None, "parent": None}))
        return 0
    print(json.dumps(extract(Path(sys.argv[1]))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
