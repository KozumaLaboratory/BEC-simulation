#!/usr/bin/env python3
"""Local test suite for run_loop_helpers.py (2026-05-20).

Run before any loop resume to confirm helpers are functionally equivalent
to the bash patterns they replaced. The 2026-05-19 incident (74 retries
in 3h13m) was caught only live; this suite catches regression locally.

Usage:
    python3 .claude/scripts/tests/test_run_loop_helpers.py
    # exits 0 on all pass, 1 on any failure
"""

from __future__ import annotations

import json
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path("/home/suzume/workspace/BEC-simulation")
HELPER = ROOT / ".claude" / "scripts" / "run_loop_helpers.py"


def _run(args: list[str]) -> tuple[int, str, str]:
    """Invoke a helper action via subprocess (mirrors how the slash
    command's `!python3 ...` invocation works). Returns (rc, stdout, stderr).
    """
    proc = subprocess.run(
        ["python3", str(HELPER)] + args,
        capture_output=True, text=True, cwd=str(ROOT), timeout=30,
    )
    return proc.returncode, proc.stdout, proc.stderr


def _assert(cond, msg):
    if not cond:
        print(f"  FAIL: {msg}")
        return 1
    print(f"  PASS: {msg}")
    return 0


def test_agent_hash_snapshot() -> int:
    print("\n=== test_agent_hash_snapshot ===")
    rc, out, err = _run(["agent_hash_snapshot"])
    fails = 0
    fails += _assert(rc == 0, f"exit code 0 (got {rc}, stderr={err[:80]})")
    try:
        result = json.loads(out)
    except json.JSONDecodeError as e:
        print(f"  FAIL: stdout not JSON: {e}")
        return 1
    fails += _assert(result.get("ok") is True, "result.ok == True")
    fails += _assert(isinstance(result.get("hashes"), dict),
                     "result.hashes is dict")
    fails += _assert(result.get("n_agents", 0) >= 5,
                     f"n_agents >= 5 (got {result.get('n_agents')})")
    # Verify state.json was updated
    state = json.loads((ROOT / "runs/_loop/state.json").read_text())
    fails += _assert("current_agent_hashes" in state,
                     "state.json has current_agent_hashes")
    fails += _assert(state.get("current_agent_hashes") == result.get("hashes"),
                     "state.current_agent_hashes matches stdout")
    return fails


def test_read_lines() -> int:
    print("\n=== test_read_lines ===")
    fails = 0
    # Use the helper itself as a fixed-content file
    rc, out, err = _run(["read_lines", str(HELPER), "1", "3"])
    fails += _assert(rc == 0, f"exit code 0 (got {rc})")
    lines = out.splitlines()
    fails += _assert(len(lines) == 3, f"3 lines returned (got {len(lines)})")
    fails += _assert(lines[0].startswith("#!"), f"line 1 is shebang (got {lines[0][:30]!r})")

    # Out-of-range end
    rc, out, _ = _run(["read_lines", str(HELPER), "1", "99999"])
    fails += _assert(rc == 0, "out-of-range end accepted")
    return fails


def test_list_with_mtime() -> int:
    print("\n=== test_list_with_mtime ===")
    fails = 0
    rc, out, err = _run(["list_with_mtime", ".claude/agents", "*.md"])
    fails += _assert(rc == 0, f"exit code 0 (got {rc})")
    lines = [l for l in out.splitlines() if l.strip()]
    fails += _assert(len(lines) >= 5, f"≥5 files (got {len(lines)})")
    # Each line: "<path> <mtime_float>"
    for ln in lines[:3]:
        parts = ln.rsplit(" ", 1)
        fails += _assert(len(parts) == 2, f"line has path+mtime ({ln[:60]!r})")
        try:
            float(parts[1])
        except ValueError:
            fails += _assert(False, f"mtime is float ({parts[1]!r})")
    return fails


def test_state_modify_atomic() -> int:
    print("\n=== test_state_modify_atomic ===")
    fails = 0
    # Take backup
    state_path = ROOT / "runs/_loop/state.json"
    backup = state_path.read_text()
    try:
        # Set a probe field
        rc, out, err = _run(["state_modify_atomic", '.test_probe = "alive"'])
        fails += _assert(rc == 0, f"exit code 0 (got {rc}; err={err[:80]})")
        try:
            result = json.loads(out)
        except json.JSONDecodeError:
            fails += _assert(False, f"stdout not JSON: {out[:100]!r}")
            return fails
        fails += _assert(result.get("ok") is True, "result.ok == True")
        # Verify
        state = json.loads(state_path.read_text())
        fails += _assert(state.get("test_probe") == "alive",
                         "state.test_probe set to 'alive'")

        # Bad filter should fail gracefully (not corrupt state)
        rc, out, err = _run(["state_modify_atomic", ".this.is.invalid_jq[("])
        fails += _assert(rc == 0, "exit code 0 even on bad filter (graceful)")
        try:
            result = json.loads(out)
            fails += _assert(result.get("ok") is False,
                             "result.ok == False on bad filter")
        except json.JSONDecodeError:
            pass  # also acceptable
        # State should NOT be corrupted
        state_post = json.loads(state_path.read_text())
        fails += _assert(state_post.get("test_probe") == "alive",
                         "state survives bad filter (still has test_probe)")
    finally:
        # Restore backup
        state_path.write_text(backup)
    return fails


def test_git_helpers() -> int:
    print("\n=== test_git_helpers (read-only test) ===")
    fails = 0
    # git_checkout_home_branch — just verify it returns sensibly
    rc, out, err = _run(["git_checkout_home_branch"])
    fails += _assert(rc == 0, f"git_checkout exit 0 (got {rc}; err={err[:80]})")
    try:
        result = json.loads(out)
        fails += _assert("ok" in result, "git_checkout returns dict with 'ok'")
        fails += _assert("branch" in result, "git_checkout returns 'branch'")
    except json.JSONDecodeError:
        fails += _assert(False, f"git_checkout stdout not JSON: {out[:80]}")

    # git_add_turn_artifacts with non-existent turn (should be no-op success)
    rc, out, err = _run(["git_add_turn_artifacts", "999999"])
    fails += _assert(rc == 0, f"git_add for non-existent turn exit 0 (got {rc})")
    try:
        result = json.loads(out)
        fails += _assert(result.get("ok") is True,
                         "git_add for non-existent turn ok=True")
        fails += _assert(len(result.get("added", [])) == 0,
                         "no files added for non-existent turn")
    except json.JSONDecodeError:
        fails += _assert(False, "git_add stdout not JSON")
    return fails


def test_no_compound_bash_in_helpers_invocation() -> int:
    """Meta-test: verify all helper invocations in run-loop.md are single-command."""
    print("\n=== test_no_compound_bash_in_helpers_invocation ===")
    import re
    fails = 0
    text = (ROOT / ".claude/commands/run-loop.md").read_text()
    forbidden = ["&&", "||", "$(", "sed -i", "sed -n"]
    bad_lines = []
    for i, ln in enumerate(text.split("\n"), 1):
        body = ln.lstrip()
        if not body.startswith("!"):
            continue
        if "run_loop_helpers.py" in body:
            # Helper invocation itself should be clean
            for tok in forbidden:
                if tok in body:
                    bad_lines.append((i, body[:80], tok))
    fails += _assert(len(bad_lines) == 0,
                     f"helper invocations are clean ({len(bad_lines)} bad)")
    for i, body, tok in bad_lines[:5]:
        print(f"    L{i} [{tok}]: {body}")
    return fails


def main() -> int:
    print("Running run_loop_helpers.py test suite...")
    total_fails = 0
    total_fails += test_agent_hash_snapshot()
    total_fails += test_read_lines()
    total_fails += test_list_with_mtime()
    total_fails += test_state_modify_atomic()
    total_fails += test_git_helpers()
    total_fails += test_no_compound_bash_in_helpers_invocation()
    print(f"\n{'=' * 50}")
    if total_fails == 0:
        print(f"ALL TESTS PASS")
        return 0
    print(f"FAILURES: {total_fails}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
