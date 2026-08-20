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


def gh_json(args: list[str]) -> tuple[list[dict], bool]:
    """`gh` output as JSON, paired with whether the call actually succeeded.

    Never raises — a missing `gh` must not stop someone recording a disposition
    by hand — but it never lets a failure pass as an empty result either. Those
    two are indistinguishable in the data and opposite in meaning.
    """
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=60, check=True)
        return json.loads(out.stdout), True
    except Exception as e:  # noqa: BLE001 - any failure is the same story here
        print(f"WARNING: {' '.join(args[:3])}… failed ({e}); enumeration is INCOMPLETE",
              file=sys.stderr)
        return [], False


def matches(text: str, keywords: list[str]) -> bool:
    t = text.lower()
    return any(k.lower() in t for k in keywords)


def enumerate_topic(keywords: list[str]) -> tuple[list[dict], bool]:
    """Matching open work, and whether the enumeration was COMPLETE.

    The flag is load-bearing. An incomplete enumeration looks exactly like an
    empty one, and writing an empty record over a full one destroys the very
    dispositions this tool exists to accumulate — a network hiccup would erase
    the reason #351 was finally read.
    """
    items: list[dict] = []
    complete = True
    prs, ok = gh_json(["gh", "pr", "list", "--state", "open", "--limit", "100",
                       "--json", "number,title,headRefName"])
    complete &= ok
    for pr in prs:
        if matches(pr["title"] + " " + pr["headRefName"], keywords):
            items.append({"kind": "pr", "ref": f"#{pr['number']}", "title": pr["title"]})
    issues, ok = gh_json(["gh", "issue", "list", "--state", "open", "--limit", "100",
                          "--json", "number,title"])
    complete &= ok
    for iss in issues:
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
        complete = False
    return items, complete


def write_record(topic: str, keywords: list[str], items: list[dict]) -> Path:
    RECORD_DIR.mkdir(parents=True, exist_ok=True)
    path = RECORD_DIR / f"{topic}.md"
    # Carry BOTH columns forward. The disposition says a row was handled; the
    # note says what was found, and that is the part worth having — "#351: not
    # reading this cost a day" is the whole point of the record. An earlier
    # version preserved only the disposition, so the first regeneration silently
    # blanked every note while reporting `0 unread`.
    prev: dict[str, tuple[str, str]] = {}
    if path.exists():
        for line in path.read_text().splitlines():
            m = re.match(r"^\|([^|]*)\|([^|]*)\|([^|]*)\|(.*)\|\s*$", line)
            if m and m.group(2).strip() in DISPOSITIONS:
                prev[m.group(1).strip()] = (m.group(2).strip(), m.group(4).strip())

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out = [
        f"# Prior art — {topic}",
        "",
        # The docs gate (test_docs_live_set.jl) asks every file to be either
        # maintained or dated, and this is squarely the dated kind: nothing
        # refreshes it, so a reader must know as-of when it was true. The
        # generator stamps it rather than a human, so the mark cannot outlive the
        # enumeration it describes.
        f"> **FROZEN {stamp}.** A snapshot of the open work on {topic} as of that",
        "> date. Re-run the generator when picking the topic up again; existing",
        "> dispositions are preserved.",
        "",
        f"Keywords: {', '.join(keywords)}. Regenerate with",
        f"`python3 scripts/prior_art.py --topic {topic} --keywords {' '.join(keywords)}`.",
        "",
        "Dispositions: " + ", ".join(f"`{k}`" for k in DISPOSITIONS),
        "",
        "| ref | disposition | what | note |",
        "|---|---|---|---|",
    ]
    seen = set()
    for it in sorted(items, key=lambda x: (x["kind"], x["ref"])):
        d, note = prev.get(it["ref"], ("unread", ""))
        seen.add(it["ref"])
        out.append(f"| {it['ref']} | {d} | {it['kind']}: {it['title']} | {note} |")
    # A row that no longer matches has usually MERGED or CLOSED, which is exactly
    # when its note is most worth keeping. Dropping it would let a topic be
    # re-litigated the moment its prior art lands.
    for ref, (d, note) in sorted(prev.items()):
        if ref not in seen:
            out.append(f"| {ref} | {d} | (no longer open) | {note} |")
    if not out[-1].startswith("|") or out[-1].startswith("|---"):
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
    items, complete = enumerate_topic(a.keywords)
    if not complete and (RECORD_DIR / f"{a.topic}.md").exists():
        print("REFUSING to overwrite an existing record from an INCOMPLETE "
              "enumeration — fix `gh` / the network and re-run.", file=sys.stderr)
        return 2
    p = write_record(a.topic, a.keywords, items)
    n_unread = sum(1 for line in p.read_text().splitlines() if "| unread |" in line)
    print(f"wrote {p.relative_to(ROOT)} — {len(items)} matched, {n_unread} unread")
    if n_unread:
        print("Read each unread item and set its disposition before continuing.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
