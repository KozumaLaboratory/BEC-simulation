#!/usr/bin/env python3
"""Single-command bash helpers for /run-loop slash command (2026-05-20).

Claude Code v2's permission gate rejects compound bash (`;`, `&&`, `||`,
`for`-loops, `if-then-fi`, `$(...)` command substitution, `sed -i`,
`sed -n NNNp` ranges, subshell `(...)` with `;`). The /run-loop slash
command had 11+ such patterns that caused the 2026-05-19 incident:
74 failed retries in 3h13min before permission-gate diagnosis.

This module centralizes all those operations as Python callables.
The slash command emits ONE simple bash line per action:

    !python3 .claude/scripts/run_loop_helpers.py <action> [args]

Each action is permission-gate-compatible: single `python3` invocation,
no shell metacharacters in the command line itself.

Actions:
    agent_hash_snapshot       — compute MD5 of .claude/agents/*.md,
                                store in state.json.current_agent_hashes
    state_modify_atomic JQ    — flock-protected jq edit of state.json
    git_add_turn_artifacts N  — git-add all turn_${N}.* files in the
                                runs/_loop/<role>/ dirs
    git_checkout_home_branch  — checkout state.home_branch
    read_lines FILE START END — emit lines [START..END] from FILE
                                (replaces `sed -n 'START,ENDp' FILE`)
    git_add_research_queries N — git-add runs/_loop/research/turn_${N}_Q*.md
                                (replaces for-loop pattern)
    list_with_mtime DIR PATTERN — emit "path mtime" for matching files

All actions are read-only-ish or use flock for atomicity. None require
shell expansion or compound commands.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path("/home/suzume/workspace/BEC-simulation")
STATE = ROOT / "runs" / "_loop" / "state.json"
LOCK = ROOT / "runs" / "_loop" / "_local" / "state.json.lock"
AGENTS_DIR = ROOT / ".claude" / "agents"


def _md5(path: Path) -> str:
    h = hashlib.md5()
    h.update(path.read_bytes())
    return h.hexdigest()


def _state_atomic_write(transform):
    """Read state.json under flock, apply transform(dict)->dict, write atomically."""
    LOCK.parent.mkdir(parents=True, exist_ok=True)
    with LOCK.open("w") as fh:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            data = json.loads(STATE.read_text())
        except FileNotFoundError:
            data = {"turn": 0, "status": "running", "history": [], "investigations": {}}
        new = transform(data)
        tmp = STATE.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(new, indent=2, default=str))
        tmp.replace(STATE)
        fcntl.flock(fh.fileno(), fcntl.LOCK_UN)


def agent_hash_snapshot() -> dict:
    """Compute MD5 of all .claude/agents/*.md and store in state.json."""
    if not AGENTS_DIR.exists():
        return {"ok": False, "reason": "no agents dir"}
    hashes = {}
    for p in sorted(AGENTS_DIR.glob("*.md")):
        hashes[p.stem] = _md5(p)

    def _xform(d):
        d["current_agent_hashes"] = hashes
        return d

    _state_atomic_write(_xform)
    return {"ok": True, "n_agents": len(hashes), "hashes": hashes}


def state_modify_atomic(jq_filter: str) -> dict:
    """Apply a jq filter to state.json atomically (via subprocess `jq`).
    The jq filter is invoked as a single subprocess argument — no shell
    expansion happens. The jq DSL itself can contain semicolons (those
    are jq syntax, not shell)."""
    LOCK.parent.mkdir(parents=True, exist_ok=True)
    with LOCK.open("w") as fh:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            proc = subprocess.run(
                ["jq", jq_filter, str(STATE)],
                capture_output=True, text=True, check=False,
            )
            if proc.returncode != 0:
                fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
                return {"ok": False, "reason": "jq failed",
                        "stderr": proc.stderr[:200]}
            tmp = STATE.with_suffix(".json.tmp")
            tmp.write_text(proc.stdout)
            tmp.replace(STATE)
        finally:
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
    return {"ok": True}


def git_add_turn_artifacts(turn: int) -> dict:
    """Git-add all turn_${N}.* artifacts in runs/_loop/<role>/ directories.
    Each file is added with a separate `git add` invocation — no shell
    if-then-fi compound, no for-loop."""
    roles = ["director", "theorist", "sim", "judge", "critic", "research"]
    suffixes = {
        "director": ".md", "theorist": ".md", "sim": ".md",
        "judge": ".json", "critic": ".md", "research": ".md",
    }
    added = []
    skipped = []
    for role in roles:
        d = ROOT / "runs" / "_loop" / role
        if not d.exists():
            continue
        ext = suffixes.get(role, ".md")
        f = d / f"turn_{turn}{ext}"
        if f.exists():
            r = subprocess.run(["git", "add", str(f)], cwd=str(ROOT), capture_output=True, text=True)
            if r.returncode == 0:
                added.append(str(f.relative_to(ROOT)))
            else:
                skipped.append({"path": str(f.relative_to(ROOT)), "err": r.stderr[:80]})
        # Also try the critic-audit variant
        if role == "judge":
            f2 = d / f"turn_{turn}_critic_audit.md"
            if f2.exists():
                r = subprocess.run(["git", "add", str(f2)], cwd=str(ROOT), capture_output=True, text=True)
                if r.returncode == 0:
                    added.append(str(f2.relative_to(ROOT)))
    return {"ok": True, "added": added, "skipped": skipped}


def git_add_research_queries(turn: int) -> dict:
    """Git-add runs/_loop/research/turn_${N}_Q*.md files (replaces for-loop)."""
    d = ROOT / "runs" / "_loop" / "research"
    if not d.exists():
        return {"ok": True, "added": []}
    added = []
    for f in sorted(d.glob(f"turn_{turn}_Q*.md")):
        r = subprocess.run(["git", "add", str(f)], cwd=str(ROOT), capture_output=True, text=True)
        if r.returncode == 0:
            added.append(str(f.relative_to(ROOT)))
    return {"ok": True, "added": added}


def git_checkout_home_branch() -> dict:
    """Checkout state.json's home_branch."""
    try:
        data = json.loads(STATE.read_text())
    except Exception as e:
        return {"ok": False, "reason": str(e)}
    branch = data.get("home_branch") or "main"
    r = subprocess.run(["git", "checkout", branch], cwd=str(ROOT), capture_output=True, text=True)
    return {"ok": r.returncode == 0, "branch": branch,
            "stderr": r.stderr[:200] if r.returncode != 0 else ""}


def read_lines(file_path: str, start: int, end: int) -> str:
    """Replaces `sed -n 'START,ENDp' FILE` — emit lines [start..end] (1-indexed)."""
    p = Path(file_path)
    if not p.exists():
        return f"(file not found: {file_path})"
    lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    s = max(1, start) - 1
    e = min(len(lines), end)
    return "\n".join(lines[s:e])


def list_with_mtime(directory: str, pattern: str) -> str:
    """Emit `path mtime_iso` for each matching file (replaces ls -t pattern)."""
    d = Path(directory)
    if not d.exists():
        return ""
    out = []
    for p in sorted(d.glob(pattern)):
        if not p.is_file():
            continue
        out.append(f"{p} {p.stat().st_mtime}")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("agent_hash_snapshot")

    p_sm = sub.add_parser("state_modify_atomic")
    p_sm.add_argument("jq_filter", help="jq filter (e.g. '.turn += 1')")

    p_gt = sub.add_parser("git_add_turn_artifacts")
    p_gt.add_argument("turn", type=int)

    p_gq = sub.add_parser("git_add_research_queries")
    p_gq.add_argument("turn", type=int)

    sub.add_parser("git_checkout_home_branch")

    p_rl = sub.add_parser("read_lines")
    p_rl.add_argument("file")
    p_rl.add_argument("start", type=int)
    p_rl.add_argument("end", type=int)

    p_lm = sub.add_parser("list_with_mtime")
    p_lm.add_argument("directory")
    p_lm.add_argument("pattern")

    args = ap.parse_args()
    if args.cmd == "agent_hash_snapshot":
        out = agent_hash_snapshot()
    elif args.cmd == "state_modify_atomic":
        out = state_modify_atomic(args.jq_filter)
    elif args.cmd == "git_add_turn_artifacts":
        out = git_add_turn_artifacts(args.turn)
    elif args.cmd == "git_add_research_queries":
        out = git_add_research_queries(args.turn)
    elif args.cmd == "git_checkout_home_branch":
        out = git_checkout_home_branch()
    elif args.cmd == "read_lines":
        print(read_lines(args.file, args.start, args.end))
        return 0
    elif args.cmd == "list_with_mtime":
        print(list_with_mtime(args.directory, args.pattern))
        return 0
    print(json.dumps(out, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
