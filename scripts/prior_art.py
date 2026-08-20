#!/usr/bin/env python3
"""Enumerate the open work that already touches a topic, and force a disposition.

    python3 scripts/prior_art.py --topic spgpe --keywords spgpe reservoir damping
    python3 scripts/prior_art.py --check          # what the test gate runs

WHY THIS EXISTS, AND WHY IT IS NOT ANOTHER NOTE

On 2026-08-20 an SPGPE campaign (#334) re-derived, from a cluster job that died at
99.97 % of a 94 GiB GPU, a cache-key bug that PR #351 had already found, fixed and
gated two days earlier. Worse, it shipped a documented limit — "the projected
scattering step loses number at the order of the growth rate, so growth problems
must run energy_damping=false" — that the same PR had already RETRACTED, with the
general reason ("flatness is what a one-off necessarily shows"). The whole ensemble
was designed on a limit that did not exist.

`gh pr list` was run at the start of that session and #351 was IN THE OUTPUT, its
title beginning `feat(spgpe):`, while the task was entirely about SPGPE. It was not
read. The failure was not search; it was **not connecting what was already
displayed**.

Two memory notes covered this exactly — `feedback_use_existing_artifacts_first` and
`mistake_abandoned_branch_already_landed` ("ask before you assemble") — and neither
fired. Salience-based mechanisms lose to task momentum, so a third note would not
help. The remedy has to be an ARTIFACT that must exist, not a thing to remember:

    enumerate the matching open PRs / issues / branches, and record a disposition
    for each, before the topic's work proceeds.

Here the record would have carried the line `#351  unread`, and the gate would have
refused. That is the whole design.

WHAT THIS CAN AND CANNOT CHECK

It can check that a record exists, that every entry has a disposition, and that no
entry is still `unread`. It CANNOT check that the enumeration is current — the test
runner has no network. So the generator is what makes enumeration cheap, and the
gate is what makes leaving an entry unread impossible to do quietly. A record
written and never refreshed is a dated snapshot, and it says so in its header.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RECORD_DIR = ROOT / "docs" / "campaign" / "prior_art"

# A disposition has to say what was DONE, not merely that the row was seen.
# "unread" is the initial state and the one the gate refuses.
DISPOSITIONS = {
    "unread": "not yet looked at — the gate refuses this",
    "read": "read; its findings are accounted for in this work",
    "unrelated": "matched the keywords but does not touch this topic",
    "superseded": "this work replaces it; say so in the PR body",
    "depends": "this work builds on it and must land after / merge it",
}


def gh_json(args: list[str]) -> list[dict]:
    """`gh` output as JSON, or an empty list with a warning.

    Never raises: a missing `gh` must not stop someone recording a disposition by
    hand. It DOES warn, because a silent empty enumeration is the failure mode
    this tool exists to remove.
    """
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=60, check=True)
        return json.loads(out.stdout)
    except Exception as e:  # noqa: BLE001 - any failure is the same story here
        print(f"WARNING: {' '.join(args[:3])}… failed ({e}); enumeration is INCOMPLETE",
              file=sys.stderr)
        return []


def matches(text: str, keywords: list[str]) -> bool:
    t = text.lower()
    return any(k.lower() in t for k in keywords)


def enumerate_topic(keywords: list[str]) -> list[dict]:
    items: list[dict] = []
    for pr in gh_json(["gh", "pr", "list", "--state", "open", "--limit", "100",
                       "--json", "number,title,headRefName"]):
        if matches(pr["title"] + " " + pr["headRefName"], keywords):
            items.append({"kind": "pr", "ref": f"#{pr['number']}", "title": pr["title"]})
    for iss in gh_json(["gh", "issue", "list", "--state", "open", "--limit", "100",
                        "--json", "number,title"]):
        if matches(iss["title"], keywords):
            items.append({"kind": "issue", "ref": f"#{iss['number']}", "title": iss["title"]})
    try:
        br = subprocess.run(["git", "-C", str(ROOT), "branch", "-r", "--format=%(refname:short)"],
                            capture_output=True, text=True, timeout=30, check=True)
        for b in br.stdout.split():
            if b.startswith("origin/") and matches(b, keywords) and not b.endswith("/HEAD"):
                items.append({"kind": "branch", "ref": b, "title": ""})
    except Exception as e:  # noqa: BLE001
        print(f"WARNING: branch enumeration failed ({e}); INCOMPLETE", file=sys.stderr)
    return items


def write_record(topic: str, keywords: list[str], items: list[dict]) -> Path:
    RECORD_DIR.mkdir(parents=True, exist_ok=True)
    path = RECORD_DIR / f"{topic}.md"
    prev = {}
    if path.exists():
        for line in path.read_text().splitlines():
            m = re.match(r"^\|\s*([^|\s]+)\s*\|\s*(\w+)\s*\|", line)
            if m and m.group(2) in DISPOSITIONS:
                prev[m.group(1)] = m.group(2)

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out = [
        f"# Prior art — {topic}",
        "",
        f"Enumerated {stamp} for keywords: {', '.join(keywords)}.",
        "",
        "**A dated snapshot.** Nothing keeps this current; re-run",
        f"`python3 scripts/prior_art.py --topic {topic} --keywords {' '.join(keywords)}`",
        "when picking the topic up again. Existing dispositions are preserved.",
        "",
        "Dispositions: " + ", ".join(f"`{k}`" for k in DISPOSITIONS),
        "",
        "| ref | disposition | what | note |",
        "|---|---|---|---|",
    ]
    for it in sorted(items, key=lambda x: (x["kind"], x["ref"])):
        d = prev.get(it["ref"], "unread")
        out.append(f"| {it['ref']} | {d} | {it['kind']}: {it['title']} | |")
    if not items:
        out.append("| — | read | nothing open matched these keywords | |")
    path.write_text("\n".join(out) + "\n")
    return path


def check() -> int:
    """Every record's every entry has a disposition, and none is `unread`."""
    if not RECORD_DIR.is_dir():
        print("no prior-art records yet")
        return 0
    bad = []
    for p in sorted(RECORD_DIR.glob("*.md")):
        for line in p.read_text().splitlines():
            m = re.match(r"^\|\s*([^|\s]+)\s*\|\s*([^|\s]+)\s*\|", line)
            # Skip the header and the markdown rule. Matching the rule as a row is
            # how the first version reported a problem on a table that had none —
            # a checker that cries wolf on its own format gets switched off.
            if not m or m.group(1) == "ref" or set(m.group(1)) <= {"-", ":"}:
                continue
            ref, disp = m.group(1), m.group(2)
            if disp not in DISPOSITIONS:
                bad.append(f"{p.name}: {ref} has unknown disposition {disp!r}")
            elif disp == "unread":
                bad.append(f"{p.name}: {ref} is still UNREAD")
    for b in bad:
        print("  " + b)
    print(f"prior-art records: {len(list(RECORD_DIR.glob('*.md')))}, problems: {len(bad)}")
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--topic")
    ap.add_argument("--keywords", nargs="*", default=[])
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.check:
        return check()
    if not a.topic or not a.keywords:
        ap.error("--topic and --keywords are required unless --check")
    items = enumerate_topic(a.keywords)
    p = write_record(a.topic, a.keywords, items)
    n_unread = sum(1 for line in p.read_text().splitlines() if "| unread |" in line)
    print(f"wrote {p.relative_to(ROOT)} — {len(items)} matched, {n_unread} unread")
    if n_unread:
        print("Read each unread item and set its disposition before continuing.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
