#!/usr/bin/env python3
"""APC-style contract template cache (2026-05-18).

Per arXiv:2506.14852 (Agentic Plan Caching, 50% cost / 27% latency
reduction). For each (investigation_kind, flow_template, stage)
triple, extracts the structural skeleton of director's §6 contract
and caches it. On the next director turn for a similar (kind, template,
stage), the cache returns the skeleton — director uses it as scaffold
+ patches investigation-specific deltas instead of regenerating the
whole contract.

Cache file: `.claude/cache/contract_templates.json`

Template extracted: success_criteria + failure_modes structural shape
(field names + operators, value-stripped); observable_manifest schema;
budget envelope; stage transition rules. Investigation-specific values
(numbers, IDs) are stripped to placeholders.

Usage:
    contract_cache.py extract --turn N
        # extracts §6 from director/turn_N.md, updates cache
    contract_cache.py lookup --kind <k> --template <t> --stage <s>
        # returns matching template if exists, else null
    contract_cache.py list
        # shows current cache
"""

from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path("/home/suzume/workspace/BEC-simulation")
CACHE_PATH = ROOT / ".claude" / "cache" / "contract_templates.json"
STATE = ROOT / "runs" / "_loop" / "state.json"


def _strip_to_template(contract: dict) -> dict:
    """Strip investigation-specific values from a contract, leaving
    only the structural template."""
    t = copy.deepcopy(contract)
    # ID-style fields → placeholder
    for k in ("investigation_id", "rationale", "brief"):
        if k in t:
            t[k] = f"<{k}>"
    # success_criteria: keep field names + operators, strip values
    if isinstance(t.get("success_criteria"), list):
        for c in t["success_criteria"]:
            if isinstance(c, dict):
                if "value" in c:
                    c["value"] = "<value>"
                if "rationale" in c:
                    c["rationale"] = "<rationale>"
    # failure_modes: keep categories + actions structure
    if isinstance(t.get("failure_modes"), list):
        for fm in t["failure_modes"]:
            if isinstance(fm, dict):
                for k in ("if", "next_action"):
                    if k in fm and not fm[k].startswith("<"):
                        # keep generic patterns; replace specific IDs
                        fm[k] = re.sub(r"\bT\d+\b", "<turn>", str(fm[k]))[:200]
    # budget: keep keys, generalize values
    if isinstance(t.get("budget"), dict):
        for k in ("expected_cost_eff", "expected_wall_time_sec"):
            if k in t["budget"]:
                t["budget"][k] = "<numeric>"
    # observable_manifest: keep schema, strip content
    if isinstance(t.get("observable_manifest"), dict):
        if "precondition_check" in t["observable_manifest"]:
            t["observable_manifest"]["precondition_check"] = "<bash/python script>"
    return t


def _load_cache() -> dict:
    if not CACHE_PATH.exists():
        return {"templates": {}, "schema_version": 1}
    try:
        return json.loads(CACHE_PATH.read_text())
    except json.JSONDecodeError:
        return {"templates": {}, "schema_version": 1}


def _save_cache(cache: dict) -> None:
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    CACHE_PATH.write_text(json.dumps(cache, indent=2, default=str))


def _cache_key(kind: str, template: str, stage: str) -> str:
    return f"{kind}::{template}::{stage}"


def extract_from_turn(turn: int) -> dict:
    """Extract director's §6 contract for turn N, normalize, store in cache."""
    director_md = ROOT / "runs/_loop/director" / f"turn_{turn}.md"
    if not director_md.exists():
        return {"ok": False, "reason": f"no director report at turn {turn}"}

    text = director_md.read_text(encoding="utf-8")
    pat = re.compile(
        r"## 6\.\s*Dispatch decision[^\n]*\s*\n+```(?:json)?\s*\n(\{.*?\})\s*\n```",
        re.DOTALL,
    )
    m = pat.search(text)
    if not m:
        return {"ok": False, "reason": "no §6 dispatch decision block"}
    try:
        contract = json.loads(m.group(1))
    except json.JSONDecodeError as e:
        return {"ok": False, "reason": f"json decode: {e}"}

    inv_id = contract.get("investigation_id")
    stage = contract.get("stage_advancing_to") or "Unknown"

    state = {}
    if STATE.exists():
        try:
            state = json.loads(STATE.read_text())
        except json.JSONDecodeError:
            pass
    inv = (state.get("investigations") or {}).get(inv_id, {}) if inv_id else {}
    kind = inv.get("kind", "physics")
    template = inv.get("flow_template", "unknown")

    key = _cache_key(kind, template, stage)
    cache = _load_cache()
    template_skel = _strip_to_template(contract)

    entry = cache["templates"].get(key, {"n_seen": 0, "first_seen_turn": turn, "samples": []})
    entry["n_seen"] += 1
    entry["last_seen_turn"] = turn
    entry["template_skeleton"] = template_skel
    entry["last_updated"] = datetime.now(tz=timezone.utc).isoformat()
    if len(entry["samples"]) < 3:
        entry["samples"].append({"turn": turn, "investigation_id": inv_id})
    cache["templates"][key] = entry
    _save_cache(cache)

    return {
        "ok": True,
        "key": key,
        "n_seen": entry["n_seen"],
        "first_seen_turn": entry["first_seen_turn"],
    }


def lookup(kind: str, template: str, stage: str) -> dict:
    cache = _load_cache()
    key = _cache_key(kind, template, stage)
    entry = cache["templates"].get(key)
    if not entry:
        return {"found": False, "key": key}
    return {
        "found": True,
        "key": key,
        "n_seen": entry["n_seen"],
        "first_seen_turn": entry["first_seen_turn"],
        "last_seen_turn": entry.get("last_seen_turn"),
        "template_skeleton": entry["template_skeleton"],
        "samples": entry.get("samples", []),
    }


def list_cache() -> dict:
    cache = _load_cache()
    return {
        "schema_version": cache.get("schema_version"),
        "n_templates": len(cache.get("templates", {})),
        "entries": [
            {
                "key": k,
                "n_seen": v.get("n_seen"),
                "first_seen_turn": v.get("first_seen_turn"),
                "last_seen_turn": v.get("last_seen_turn"),
                "samples": v.get("samples", [])[:3],
            }
            for k, v in (cache.get("templates") or {}).items()
        ],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    e = sub.add_parser("extract")
    e.add_argument("--turn", type=int, required=True)

    l = sub.add_parser("lookup")
    l.add_argument("--kind", required=True)
    l.add_argument("--template", required=True)
    l.add_argument("--stage", required=True)

    sub.add_parser("list")

    args = ap.parse_args()
    if args.cmd == "extract":
        r = extract_from_turn(args.turn)
    elif args.cmd == "lookup":
        r = lookup(args.kind, args.template, args.stage)
    elif args.cmd == "list":
        r = list_cache()
    print(json.dumps(r, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
