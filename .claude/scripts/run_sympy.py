#!/usr/bin/env python3
"""
Sympy compute-step executor for the loop's `action: "compute_sympy"`
implementer branch.

Reads compute steps from stdin (JSON array of {id, sympy_expr, ...}),
runs each via `uv run --with sympy python3 -c "..."` (ephemeral sympy
install; no persistent venv required), and returns a JSON array of
results.

Usage:
    cat compute_steps.json | python3 .claude/scripts/run_sympy.py

Output format (sim/turn_N.md §4 metrics `compute_results` schema):
    [
      {
        "id": "S1",
        "task": "<from input>",
        "status": "OK" | "FAILED" | "TIMEOUT",
        "result": "<stdout>" (when OK),
        "error": "<stderr>" (when FAILED/TIMEOUT)
      },
      ...
    ]

Exit 0 always (per-step failures are reported in output, not by exit
code — the implementer aggregates).

Timeout per step: 60s (sympy timeouts on hard problems are common;
theorist should fragment large derivations).
"""

from __future__ import annotations

import json
import shlex
import subprocess
import sys
from typing import Any

STEP_TIMEOUT_SEC = 60


def run_one(step: dict[str, Any]) -> dict[str, Any]:
    step_id = step.get("id", "?")
    expr = step.get("sympy_expr", "")
    task = step.get("task", "")

    if not isinstance(expr, str) or not expr.strip():
        return {
            "id": step_id,
            "task": task,
            "status": "FAILED",
            "error": "empty or non-string sympy_expr",
        }

    # Run via uv with ephemeral sympy install — no global state mutation.
    cmd = ["uv", "run", "--with", "sympy", "python3", "-c", expr]

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=STEP_TIMEOUT_SEC,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return {
            "id": step_id,
            "task": task,
            "status": "TIMEOUT",
            "error": f"step exceeded {STEP_TIMEOUT_SEC}s",
            "cmd": shlex.join(cmd),
        }
    except FileNotFoundError as e:
        return {
            "id": step_id,
            "task": task,
            "status": "FAILED",
            "error": f"uv not in PATH: {e}",
        }
    except Exception as e:
        return {
            "id": step_id,
            "task": task,
            "status": "FAILED",
            "error": f"{type(e).__name__}: {e}",
        }

    if proc.returncode != 0:
        return {
            "id": step_id,
            "task": task,
            "status": "FAILED",
            "error": proc.stderr.strip() or "non-zero exit, no stderr",
            "result": proc.stdout.strip(),
            "returncode": proc.returncode,
        }

    return {
        "id": step_id,
        "task": task,
        "status": "OK",
        "result": proc.stdout.strip(),
    }


def main() -> int:
    raw = sys.stdin.read().strip()
    if not raw:
        print("[]")
        return 0
    try:
        steps = json.loads(raw)
    except json.JSONDecodeError as e:
        print(json.dumps([{"id": "?", "status": "FAILED",
                          "error": f"input JSON parse: {e}"}]))
        return 0
    if not isinstance(steps, list):
        print(json.dumps([{"id": "?", "status": "FAILED",
                          "error": "input must be a JSON array of step objects"}]))
        return 0

    results = [run_one(s) if isinstance(s, dict) else
               {"id": "?", "status": "FAILED", "error": "non-dict step entry"}
               for s in steps]
    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
