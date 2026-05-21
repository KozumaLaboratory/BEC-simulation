#!/usr/bin/env python3
"""
Loop scheduler — combines time windows, resource probe, and workload
specs into a single per-turn dispatch decision.

Per anko 2026-05-15: blanket "no julia" ban → context-aware
scheduling. Each turn-head invocation answers:

  - Should we dispatch a turn at all RIGHT NOW?
  - If yes, which workload classes are allowed?
  - How much time is left in the current window?
  - Does the probe agree (resource-feasible)?

Inputs:
  - runs/_loop/schedule.yaml   (anko's declared windows)
  - .claude/workload_specs.yaml (per-workload resource fingerprint)
  - resource_probe.py output    (live VRAM/RAM/util/foreign-julia)
  - current local time

Output (stdout JSON):
{
  "decision": "go" | "wait_until_T" | "halt",
  "current_window": {<window metadata>} | null,
  "policy": "TEXT_ONLY" | ... | "HALT",
  "allowed_workloads": [<workload_specs keys passing filters>],
  "rejected_workloads": [{"name": ..., "reason": ...}],
  "window_ends_at": "ISO time" | null,
  "window_seconds_left": int | null,
  "probe_policy": "<from resource_probe>",
  "advice": "free-form text the director should respect",
}

Exit codes:
  0 if decision == go
  1 if wait
  2 if halt

Usage:
    scheduler.py                # full JSON
    scheduler.py --decision     # just the decision string
    scheduler.py --allowed      # just the allowed workload list
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print(json.dumps({
        "decision": "halt",
        "error": "PyYAML not installed; run `uv pip install pyyaml` in loop venv",
    }, indent=2))
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[2]
SCHEDULE = ROOT / "runs" / "_loop" / "schedule.yaml"
WORKLOADS = ROOT / ".claude" / "workload_specs.yaml"
PROBE_SCRIPT = ROOT / ".claude" / "scripts" / "resource_probe.py"


def _now() -> dt.datetime:
    return dt.datetime.now().astimezone()


def _parse_iso(s: str) -> dt.datetime:
    """Parse ISO 8601, preserving offset; if naive, attach local TZ."""
    out = dt.datetime.fromisoformat(s)
    if out.tzinfo is None:
        out = out.astimezone()
    return out


def _read_yaml(path: Path) -> dict:
    if not path.exists():
        return {}
    return yaml.safe_load(path.read_text()) or {}


def _run_probe() -> dict:
    if not PROBE_SCRIPT.exists():
        return {"policy": "TEXT_ONLY", "policy_detail": {"reasons": ["probe missing"]}}
    try:
        out = subprocess.run(
            ["python3", str(PROBE_SCRIPT)], capture_output=True, text=True, timeout=10,
        )
        return json.loads(out.stdout)
    except (subprocess.SubprocessError, json.JSONDecodeError) as e:
        return {"policy": "TEXT_ONLY", "policy_detail": {"reasons": [f"probe failed: {e}"]}}


def _current_window(schedule: dict, now: dt.datetime) -> dict | None:
    for w in schedule.get("windows", []):
        start = _parse_iso(w["from"])
        end = _parse_iso(w["until"])
        if start <= now < end:
            return w
    return None


def _next_window(schedule: dict, now: dt.datetime) -> dict | None:
    upcoming = []
    for w in schedule.get("windows", []):
        start = _parse_iso(w["from"])
        if start > now:
            upcoming.append((start, w))
    upcoming.sort(key=lambda x: x[0])
    return upcoming[0][1] if upcoming else None


PROBE_TIER = {
    "TEXT_ONLY": 0,
    "JULIA_CPU_LIGHT": 1,
    "JULIA_CPU_HEAVY": 2,
    "JULIA_GPU_OK": 3,
}


def _effective_policy(window: dict, probe_policy: str) -> str:
    """Window can TIGHTEN probe but not LOOSEN it. PROBE_DRIVEN passes through."""
    wpol = window.get("loop_policy", "TEXT_ONLY")
    if wpol == "PROBE_DRIVEN":
        return probe_policy
    if wpol == "HALT":
        return "HALT"
    # Window-stated policy: clamp to MIN(window, probe).
    if wpol not in PROBE_TIER or probe_policy not in PROBE_TIER:
        return wpol
    return min(wpol, probe_policy, key=lambda p: PROBE_TIER[p])


def _filter_workloads(
    workloads: dict,
    effective_policy: str,
    window: dict,
    probe: dict,
    seconds_left: int,
) -> tuple[list[str], list[dict]]:
    allowed = []
    rejected = []
    whitelist = window.get("allowed_workloads") if window else None
    blacklist = window.get("forbidden_workloads") if window else None
    vram_free = (probe.get("gpu") or {}).get("vram_free_mb") or 0
    ram_avail = (probe.get("ram") or {}).get("ram_avail_gb") or 0

    for name, spec in workloads.items():
        # Whitelist / blacklist gates
        if whitelist and name not in whitelist:
            rejected.append({"name": name, "reason": f"not in window.allowed_workloads"})
            continue
        if blacklist and name in blacklist:
            rejected.append({"name": name, "reason": f"in window.forbidden_workloads"})
            continue

        # Policy tier gate
        req_julia = bool(spec.get("requires_julia"))
        req_gpu = bool(spec.get("requires_gpu"))
        if req_gpu and effective_policy != "JULIA_GPU_OK":
            rejected.append({"name": name, "reason": f"requires GPU; policy={effective_policy}"})
            continue
        if req_julia and effective_policy == "TEXT_ONLY":
            rejected.append({"name": name, "reason": f"requires julia; policy=TEXT_ONLY"})
            continue
        if req_julia and effective_policy == "JULIA_CPU_LIGHT":
            # only the *_light julia class is allowed in this policy
            if name not in ("implementer_julia_cpu_light",):
                rejected.append({"name": name, "reason": f"julia heavy under CPU_LIGHT policy"})
                continue

        # Resource fit gate
        if req_gpu and vram_free < spec.get("min_vram_mb", 0):
            rejected.append({"name": name, "reason": f"vram free {vram_free} < spec {spec.get('min_vram_mb')}"})
            continue
        if ram_avail < spec.get("min_ram_gb", 0):
            rejected.append({"name": name, "reason": f"ram avail {ram_avail} GB < spec {spec.get('min_ram_gb')} GB"})
            continue

        # Time fit gate (typical duration + 30 % margin)
        dur = spec.get("typical_duration_sec", 0)
        margin = int(dur * 1.3)
        if seconds_left >= 0 and margin > seconds_left:
            rejected.append({
                "name": name,
                "reason": f"typical {dur}s + 30% margin = {margin}s > window left {seconds_left}s",
            })
            continue

        allowed.append(name)

    return allowed, rejected


def decide() -> dict:
    schedule = _read_yaml(SCHEDULE)
    workloads = _read_yaml(WORKLOADS)
    probe = _run_probe()
    now = _now()

    window = _current_window(schedule, now)
    if window is None:
        nxt = _next_window(schedule, now)
        if nxt is None:
            return {
                "decision": "halt",
                "current_window": None,
                "policy": "HALT",
                "allowed_workloads": [],
                "rejected_workloads": [],
                "window_ends_at": None,
                "window_seconds_left": None,
                "probe_policy": probe.get("policy"),
                "now": now.isoformat(),
                "advice": "no schedule window active and none upcoming; edit runs/_loop/schedule.yaml",
            }
        wait_seconds = int((_parse_iso(nxt["from"]) - now).total_seconds())
        return {
            "decision": "wait",
            "wait_until": nxt["from"],
            "wait_seconds": wait_seconds,
            "current_window": None,
            "next_window": nxt,
            "policy": "WAIT",
            "allowed_workloads": [],
            "rejected_workloads": [],
            "probe_policy": probe.get("policy"),
            "now": now.isoformat(),
            "advice": f"loop is between windows; next window opens at {nxt['from']}",
        }

    end = _parse_iso(window["until"])
    seconds_left = int((end - now).total_seconds())
    effective = _effective_policy(window, probe.get("policy", "TEXT_ONLY"))

    if effective == "HALT":
        return {
            "decision": "halt",
            "current_window": window,
            "policy": "HALT",
            "allowed_workloads": [],
            "rejected_workloads": [],
            "window_ends_at": window["until"],
            "window_seconds_left": seconds_left,
            "probe_policy": probe.get("policy"),
            "now": now.isoformat(),
            "advice": "current window declares HALT",
        }

    allowed, rejected = _filter_workloads(
        workloads, effective, window, probe, seconds_left,
    )

    if not allowed:
        return {
            "decision": "halt",
            "current_window": window,
            "policy": effective,
            "allowed_workloads": [],
            "rejected_workloads": rejected,
            "window_ends_at": window["until"],
            "window_seconds_left": seconds_left,
            "probe_policy": probe.get("policy"),
            "now": now.isoformat(),
            "advice": "no workload class passes all gates; widen window or wait for probe to recover",
        }

    return {
        "decision": "go",
        "current_window": window,
        "policy": effective,
        "allowed_workloads": allowed,
        "rejected_workloads": rejected,
        "window_ends_at": window["until"],
        "window_seconds_left": seconds_left,
        "probe_policy": probe.get("policy"),
        "probe_summary": {
            "vram_free_mb": (probe.get("gpu") or {}).get("vram_free_mb"),
            "ram_avail_gb": (probe.get("ram") or {}).get("ram_avail_gb"),
            "gpu_util_pct": (probe.get("gpu") or {}).get("util_pct"),
            "foreign_julia": len(probe.get("julia_procs") or []),
        },
        "now": now.isoformat(),
        "advice": (
            f"window {window['from']} → {window['until']}; "
            f"{seconds_left}s left ({seconds_left // 60} min); "
            f"effective policy = {effective}; "
            f"director picks workload from {allowed}"
        ),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--decision", action="store_true",
                    help="emit just the decision string (for shell)")
    ap.add_argument("--allowed", action="store_true",
                    help="emit just the allowed workload list, newline-separated")
    args = ap.parse_args()

    out = decide()

    if args.decision:
        print(out["decision"])
    elif args.allowed:
        print("\n".join(out.get("allowed_workloads", [])))
    else:
        print(json.dumps(out, indent=2))

    return {"go": 0, "wait": 1, "halt": 2}.get(out["decision"], 2)


if __name__ == "__main__":
    sys.exit(main())
