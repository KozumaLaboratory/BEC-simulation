#!/usr/bin/env python3
"""
T57 runner: invoke julia analysis script via subprocess, stream output to log file.
"""
import subprocess, sys, time, os

JULIA_BIN = "/home/suzume/.juliaup/bin/julia"
PROJECT    = "/home/suzume/workspace/BEC-simulation"
SCRIPT     = "/home/suzume/workspace/BEC-simulation/scripts/diagnostic/klaus_bch_leak_verification.jl"
LOG_PATH   = "/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_57_run.log"

t0 = time.time()
print(f"Starting julia at {time.strftime('%Y-%m-%dT%H:%M:%S')}")
sys.stdout.flush()

with open(LOG_PATH, "w") as logf:
    result = subprocess.run(
        [JULIA_BIN, "--project=" + PROJECT, SCRIPT],
        cwd=PROJECT,
        stdout=logf,
        stderr=subprocess.STDOUT,
    )

elapsed = time.time() - t0
print(f"Julia exited with code {result.returncode} in {elapsed:.1f}s")

# Print the log to stdout as well
with open(LOG_PATH) as f:
    print(f.read())

sys.exit(result.returncode)
