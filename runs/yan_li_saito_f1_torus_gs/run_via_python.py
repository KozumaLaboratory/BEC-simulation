#!/usr/bin/env python3
"""T35 runner: invoke Julia scripts via Python subprocess to bypass bash sandbox."""
import subprocess
import sys
import os
import time

JULIA = "/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia"
PROJECT = "/home/suzume/workspace/BEC-simulation"
RUN_DIR = "/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs"

env = dict(os.environ)
env["LD_LIBRARY_PATH"] = "/usr/lib/wsl/lib"
env["HOME"] = "/home/suzume"


def run_julia(script, log_file, timeout=None):
    print(f"Running: {script}")
    print(f"Log: {log_file}")
    t0 = time.time()
    with open(log_file, "w") as f:
        result = subprocess.run(
            [JULIA, f"--project={PROJECT}", script],
            stdout=f,
            stderr=subprocess.STDOUT,
            env=env,
            timeout=timeout,
        )
    elapsed = time.time() - t0
    print(f"Exit code: {result.returncode}, elapsed: {elapsed:.1f}s")
    # Append exit code to log
    with open(log_file, "a") as f:
        f.write(f"\nExit code: {result.returncode}\n")
        f.write(f"Elapsed: {elapsed:.1f}s\n")
    return result.returncode, elapsed


if __name__ == "__main__":
    stage = sys.argv[1] if len(sys.argv) > 1 else "smoke"

    if stage == "smoke":
        code, elapsed = run_julia(
            f"{RUN_DIR}/run_t35_smoke.jl",
            f"{RUN_DIR}/run_t35_smoke.log",
            timeout=300,
        )
        sys.exit(code)

    elif stage == "itp":
        code, elapsed = run_julia(
            f"{RUN_DIR}/run_t35_itp.jl",
            f"{RUN_DIR}/run_t35_itp.log",
            timeout=1800,
        )
        sys.exit(code)

    elif stage == "post":
        code, elapsed = run_julia(
            f"{RUN_DIR}/run_t35_post.jl",
            f"{RUN_DIR}/run_t35_post.log",
            timeout=300,
        )
        sys.exit(code)
