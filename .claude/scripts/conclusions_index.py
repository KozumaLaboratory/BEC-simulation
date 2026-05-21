#!/usr/bin/env python3
"""Conclusions index per investigation (2026-05-18).

Maintains `runs/_loop/conclusions/<inv_id>.md` — a durable, append-only
record of [Established] / [Plausible] claims per investigation thread.

Director's §B1 reads this index BEFORE dispatching the next subagent;
the brief tells the subagent "claim X is already established at T22,
do not re-derive". Prevents the cold-context redundant-derivation
waste pattern.

Each turn's post-step calls `extract --turn N --inv-id X` which:
1. Reads runs/_loop/theorist/turn_N.md (if exists) for [Established] tags
2. Reads runs/_loop/judge/turn_N.json for falsifier results
3. Appends new entries to conclusions/<inv_id>.md
4. Deduplicates by topic_tag + claim_summary

Usage:
    conclusions_index.py extract --turn N --inv-id X
    conclusions_index.py read --inv-id X   # returns the index for an agent
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path("/home/suzume/workspace/BEC-simulation/runs/_loop")
CONCLUSIONS = ROOT / "conclusions"


def _safe_filename(s: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_.\-]", "_", s)


def _extract_tagged_claims(text: str, tag: str = "Established") -> list[str]:
    """Find lines containing [Established] / [Plausible] / [Speculative]
    and return the surrounding bullet/sentence."""
    out: list[str] = []
    pat = re.compile(rf"\[{tag}\][^\n]*", re.MULTILINE)
    for m in pat.finditer(text):
        # Take up to 200 chars after the tag (the claim summary)
        start = m.start()
        end = min(len(text), m.end() + 200)
        # Trim at next blank line or new section
        snippet = text[start:end]
        snippet = snippet.split("\n\n")[0].split("\n## ")[0].strip()
        if len(snippet) > 280:
            snippet = snippet[:280] + "…"
        out.append(snippet)
    return out


def _extract_falsifier_results(judge: dict) -> list[dict]:
    """From judge JSON's investigation_update.if_success_falsifier_update."""
    update = judge.get("investigation_update") or {}
    fu = update.get("if_success_falsifier_update")
    if fu and isinstance(fu, dict):
        return [{"id": fu.get("id"), "result": fu.get("result_template")}]
    return []


def extract(turn: int, inv_id: str) -> dict:
    if not inv_id:
        return {"ok": False, "reason": "no inv_id"}
    CONCLUSIONS.mkdir(parents=True, exist_ok=True)
    out_path = CONCLUSIONS / f"{_safe_filename(inv_id)}.md"

    theorist_md = ROOT / "theorist" / f"turn_{turn}.md"
    judge_json = ROOT / "judge" / f"turn_{turn}.json"
    sim_md = ROOT / "sim" / f"turn_{turn}.md"

    established: list[str] = []
    plausible: list[str] = []
    falsifiers: list[dict] = []

    for src in (theorist_md, sim_md):
        if src.exists():
            text = src.read_text(encoding="utf-8")
            established.extend(_extract_tagged_claims(text, "Established"))
            plausible.extend(_extract_tagged_claims(text, "Plausible"))

    if judge_json.exists():
        try:
            j = json.loads(judge_json.read_text())
            falsifiers.extend(_extract_falsifier_results(j))
        except json.JSONDecodeError:
            pass

    if not (established or plausible or falsifiers):
        return {"ok": True, "appended": 0, "skipped": "no new content this turn"}

    # Init index if new
    if not out_path.exists():
        out_path.write_text(
            f"# Conclusions index — {inv_id}\n\n"
            f"Durable record of [Established] / [Plausible] / falsifier-tested claims for this investigation.\n"
            f"Director reads this before dispatching next subagent so claims aren't re-derived.\n\n"
        )

    # Dedupe against existing entries (substring match on the claim summary)
    existing_text = out_path.read_text(encoding="utf-8")
    new_entries: list[str] = []
    appended = 0
    ts = datetime.now(tz=timezone.utc).astimezone().isoformat()

    if established:
        for claim in established:
            sig = claim[:80].strip()
            if sig and sig not in existing_text:
                new_entries.append(f"### T{turn} [Established] {ts}\n\n{claim}\n")
                appended += 1
    if plausible:
        for claim in plausible:
            sig = claim[:80].strip()
            if sig and sig not in existing_text:
                new_entries.append(f"### T{turn} [Plausible] {ts}\n\n{claim}\n")
                appended += 1
    for f in falsifiers:
        if not f.get("id"):
            continue
        sig = f"falsifier:{f['id']}"
        if sig not in existing_text:
            new_entries.append(f"### T{turn} [Falsifier-tested: {f['id']}] {ts}\n\n{f.get('result', '?')}\n")
            appended += 1

    if new_entries:
        with out_path.open("a") as fh:
            fh.write("\n".join(new_entries) + "\n")

    return {"ok": True, "appended": appended, "wrote": str(out_path.relative_to(ROOT.parent))}


def read_index(inv_id: str) -> str:
    p = CONCLUSIONS / f"{_safe_filename(inv_id)}.md"
    if not p.exists():
        return f"# Conclusions index — {inv_id}\n\n(empty)"
    return p.read_text(encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    e = sub.add_parser("extract")
    e.add_argument("--turn", type=int, required=True)
    e.add_argument("--inv-id", required=True)

    r = sub.add_parser("read")
    r.add_argument("--inv-id", required=True)

    args = ap.parse_args()

    if args.cmd == "extract":
        out = extract(args.turn, args.inv_id)
        print(json.dumps(out, default=str))
    elif args.cmd == "read":
        print(read_index(args.inv_id))

    return 0


if __name__ == "__main__":
    sys.exit(main())
