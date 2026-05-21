#!/usr/bin/env python3
"""
Resource probe — emit current compute-budget policy for the loop director.

Per anko 2026-05-15: blanket "no julia" bans are unjustified. We should
*schedule* against current VRAM / RAM / process state, not hard-code a
prohibition that may have been right yesterday and wrong today.

Probes:
- VRAM free + GPU utilization via `nvidia-smi`
- RAM free via /proc/meminfo
- Foreign julia processes (not spawned by this loop)
- Foreign claude processes

Emits a JSON object with a policy enum the director reads in §B7:

    TEXT_ONLY        — VRAM or RAM critically low; loop is text-only
    JULIA_CPU_LIGHT  — small CPU-only julia (≤ 2 GB, ≤ 5 min) OK
    JULIA_CPU_HEAVY  — CPU julia up to ~8 GB OK
    JULIA_GPU_OK     — full freedom incl. GPU julia (no foreign users)

The director should use this to decide what subagent shape is safe THIS
turn, instead of relying on seed.md's static "no julia" clause.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from typing import Any


THRESHOLDS = {
    # Below these, only TEXT_ONLY:
    "vram_text_only_mb": 4_000,
    "ram_text_only_gb": 4,
    # Above text-only but below this → only CPU light:
    "vram_cpu_light_mb": 8_000,
    "ram_cpu_light_gb": 8,
    # Above cpu-light but below this → CPU heavy OK, no GPU:
    "vram_gpu_ok_mb": 12_000,
    "ram_cpu_heavy_gb": 14,
    # GPU utilization above this means someone else is computing — refuse
    # to add a GPU julia job on top:
    "gpu_util_busy_pct": 50,
}


def _run(cmd: list[str], timeout: float = 5.0) -> str:
    try:
        out = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, check=False
        )
        return out.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""


def probe_gpu() -> dict[str, Any]:
    if not shutil.which("nvidia-smi"):
        return {"vram_total_mb": None, "vram_free_mb": None, "vram_used_mb": None,
                "util_pct": None, "available": False}
    out = _run([
        "nvidia-smi",
        "--query-gpu=memory.total,memory.free,memory.used,utilization.gpu",
        "--format=csv,noheader,nounits",
    ])
    line = out.strip().splitlines()[0] if out.strip() else ""
    parts = [p.strip() for p in line.split(",")]
    if len(parts) != 4 or not all(p.isdigit() for p in parts):
        return {"vram_total_mb": None, "vram_free_mb": None, "vram_used_mb": None,
                "util_pct": None, "available": False}
    return {
        "vram_total_mb": int(parts[0]),
        "vram_free_mb": int(parts[1]),
        "vram_used_mb": int(parts[2]),
        "util_pct": int(parts[3]),
        "available": True,
    }


def probe_ram() -> dict[str, Any]:
    try:
        text = open("/proc/meminfo").read()
    except OSError:
        return {"ram_total_gb": None, "ram_avail_gb": None}
    fields = {}
    for line in text.splitlines():
        m = re.match(r"^(\w+):\s+(\d+)\s*kB", line)
        if m:
            fields[m.group(1)] = int(m.group(2))
    total_kb = fields.get("MemTotal", 0)
    avail_kb = fields.get("MemAvailable", 0)
    return {
        "ram_total_gb": round(total_kb / 1024 / 1024, 2),
        "ram_avail_gb": round(avail_kb / 1024 / 1024, 2),
    }


def probe_julia_procs() -> list[dict[str, Any]]:
    out = _run(["ps", "-eo", "pid,rss,etime,comm,args"])
    procs = []
    for line in out.splitlines()[1:]:
        if "julia" not in line.lower():
            continue
        parts = line.split(None, 4)
        if len(parts) < 5:
            continue
        pid, rss_kb, etime, comm, args = parts
        if comm.startswith("julia") or "/julia" in (args or ""):
            procs.append({
                "pid": int(pid),
                "rss_mb": int(rss_kb) // 1024,
                "etime": etime,
                "args_head": args[:120],
            })
    return procs


def probe_claude_procs() -> int:
    out = _run(["pgrep", "-c", "claude"])
    try:
        return int(out.strip() or "0")
    except ValueError:
        return 0


def derive_policy(gpu: dict, ram: dict, julia_procs: list) -> dict[str, Any]:
    """Pick the policy enum + free-form advice given the snapshot."""
    reasons = []
    vram_free = gpu.get("vram_free_mb") if gpu.get("available") else None
    ram_avail = ram.get("ram_avail_gb")
    util = gpu.get("util_pct") if gpu.get("available") else 0
    foreign_julia = len(julia_procs)

    # Tight rails first
    if (vram_free is not None and vram_free < THRESHOLDS["vram_text_only_mb"]) or \
       (ram_avail is not None and ram_avail < THRESHOLDS["ram_text_only_gb"]):
        reasons.append(
            f"VRAM free={vram_free} MB or RAM avail={ram_avail} GB below TEXT_ONLY threshold"
        )
        return {
            "policy": "TEXT_ONLY",
            "reasons": reasons,
            "allowed": ["theorist", "researcher", "critic",
                        "implementer:modify_code(text)", "compute_sympy"],
            "forbidden": ["implementer:run_experiment",
                          "implementer:modify_code w/ julia verify",
                          "any new julia spawn"],
        }

    # CPU-light tier
    if (vram_free is not None and vram_free < THRESHOLDS["vram_cpu_light_mb"]) or \
       (ram_avail is not None and ram_avail < THRESHOLDS["ram_cpu_light_gb"]):
        reasons.append(
            f"VRAM free={vram_free} MB or RAM avail={ram_avail} GB allow CPU julia ≤ 2GB only"
        )
        return {
            "policy": "JULIA_CPU_LIGHT",
            "reasons": reasons,
            "allowed": ["theorist", "researcher", "critic",
                        "implementer:modify_code(text)", "compute_sympy",
                        "implementer:modify_code w/ ≤2GB ≤5min julia verify",
                        "Pkg.test on single small file"],
            "forbidden": ["heavy julia (>2GB or >5min)",
                          "GPU julia (run_experiment)"],
        }

    # CPU-heavy tier
    if (vram_free is not None and vram_free < THRESHOLDS["vram_gpu_ok_mb"]) or \
       (ram_avail is not None and ram_avail < THRESHOLDS["ram_cpu_heavy_gb"]) or \
       util >= THRESHOLDS["gpu_util_busy_pct"] or \
       foreign_julia >= 2:
        reasons.append(
            f"VRAM={vram_free} MB / RAM={ram_avail} GB / GPU util={util}% / foreign_julia={foreign_julia} → CPU heavy OK, no GPU julia"
        )
        return {
            "policy": "JULIA_CPU_HEAVY",
            "reasons": reasons,
            "allowed": ["all text-only", "compute_sympy",
                        "implementer:modify_code w/ CPU julia verify (≤8GB ≤15min)",
                        "implementer:run_experiment(CPU backend only)",
                        "Pkg.test on small subsets"],
            "forbidden": ["GPU julia (CUDABackend)",
                          "long Julia runs (>15min)"],
        }

    # GPU OK tier
    return {
        "policy": "JULIA_GPU_OK",
        "reasons": [
            f"VRAM={vram_free} MB free / RAM={ram_avail} GB avail / GPU util={util}% / foreign_julia={foreign_julia} — full freedom"
        ],
        "allowed": ["everything incl. implementer:run_experiment(CUDA)",
                    "single-GPU-owner julia jobs"],
        "forbidden": ["spawning more than 1 GPU julia at a time"],
    }


def probe() -> dict[str, Any]:
    gpu = probe_gpu()
    ram = probe_ram()
    julia = probe_julia_procs()
    claude_n = probe_claude_procs()
    policy = derive_policy(gpu, ram, julia)
    return {
        "policy": policy["policy"],
        "policy_detail": policy,
        "gpu": gpu,
        "ram": ram,
        "julia_procs": julia,
        "claude_proc_count": claude_n,
        "thresholds": THRESHOLDS,
    }


def main() -> int:
    result = probe()
    if "--policy-only" in sys.argv:
        print(result["policy"])
    else:
        print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
