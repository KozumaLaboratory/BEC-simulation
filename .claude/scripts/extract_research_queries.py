#!/usr/bin/env python3
"""
Extract the §7 Research queries JSON array from a theorist turn report.

Strict: only counts entries that are valid query objects (have `id` and
`topic` fields). Prose `<RESEARCH_NEEDED:...>` mentions outside the §7
block do NOT trigger researcher dispatch (Tier-1 E false-positive fix).

Usage: extract_research_queries.py <path-to-theorist-turn_N.md>
Outputs: JSON array (possibly empty) to stdout. Exit 0 always.
"""

import json
import re
import sys
from pathlib import Path


def extract(text: str) -> list[dict]:
    m = re.search(
        r"## 7\.[^\n]*\n+```(?:json)?\s*\n(\[.*?\])\s*\n```",
        text,
        re.DOTALL,
    )
    if not m:
        return []
    try:
        parsed = json.loads(m.group(1))
    except json.JSONDecodeError:
        return []
    if not isinstance(parsed, list):
        return []
    # Strict filter: require id + topic. Drop malformed entries silently
    # (the researcher's protocol will REJECT vague queries anyway).
    return [
        q for q in parsed
        if isinstance(q, dict) and "id" in q and "topic" in q
    ]


def main() -> int:
    if len(sys.argv) != 2:
        print("[]")
        return 0
    path = Path(sys.argv[1])
    if not path.exists():
        print("[]")
        return 0
    queries = extract(path.read_text(encoding="utf-8"))
    print(json.dumps(queries))
    return 0


if __name__ == "__main__":
    sys.exit(main())
