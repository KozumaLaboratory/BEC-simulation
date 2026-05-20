#!/usr/bin/env python3
"""
T74 Step A: Julia precondition check via subprocess (with LD_LIBRARY_PATH for WSL2 GPU).
"""
import subprocess, sys, time, os

JULIA_BIN = "/home/suzume/.juliaup/bin/julia"
PROJECT   = "/home/suzume/workspace/BEC-simulation"
SCRIPT    = "/home/suzume/workspace/BEC-simulation/runs/auto/turn_74_edh-matsui-execute-baseline-case-A/step_a_precondition.jl"
LOG_PATH  = "/home/suzume/workspace/BEC-simulation/runs/auto/turn_74_edh-matsui-execute-baseline-case-A/precond.log"

env = os.environ.copy()
env["LD_LIBRARY_PATH"] = "/usr/lib/wsl/lib"

t0 = time.time()
print(f"Starting Julia precondition at {time.strftime('%Y-%m-%dT%H:%M:%S')}", flush=True)

with open(LOG_PATH, "w") as logf:
    result = subprocess.run(
        [JULIA_BIN, "--project=" + PROJECT, SCRIPT],
        cwd=PROJECT,
        env=env,
        stdout=logf,
        stderr=subprocess.STDOUT,
    )

elapsed = time.time() - t0
print(f"Julia precondition exited with code {result.returncode} in {elapsed:.1f}s", flush=True)

with open(LOG_PATH) as f:
    print(f.read())

sys.exit(result.returncode)
