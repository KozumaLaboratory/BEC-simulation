#!/usr/bin/env python3
"""
T74 Step B: run_yaml GPU execute via subprocess (with LD_LIBRARY_PATH for WSL2 GPU).
Timeout: 2700 seconds (45 min hard cap per director brief).
"""
import subprocess, sys, time, os

JULIA_BIN = "/home/suzume/.juliaup/bin/julia"
PROJECT   = "/home/suzume/workspace/BEC-simulation"
SCRIPT    = "/home/suzume/workspace/BEC-simulation/runs/auto/turn_74_edh-matsui-execute-baseline-case-A/step_b_run.jl"
LOG_PATH  = "/home/suzume/workspace/BEC-simulation/runs/auto/turn_74_edh-matsui-execute-baseline-case-A/run.log"

env = os.environ.copy()
env["LD_LIBRARY_PATH"] = "/usr/lib/wsl/lib"

TIMEOUT_SEC = 2700

t0 = time.time()
print(f"Starting run_yaml at {time.strftime('%Y-%m-%dT%H:%M:%S')}", flush=True)

timeout_triggered = False
returncode = None

try:
    with open(LOG_PATH, "w") as logf:
        proc = subprocess.Popen(
            [JULIA_BIN, "--project=" + PROJECT, SCRIPT],
            cwd=PROJECT,
            env=env,
            stdout=logf,
            stderr=subprocess.STDOUT,
        )
        try:
            returncode = proc.wait(timeout=TIMEOUT_SEC)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            timeout_triggered = True
            returncode = -1
except Exception as e:
    print(f"EXCEPTION: {e}", flush=True)
    sys.exit(1)

elapsed = time.time() - t0
if timeout_triggered:
    print(f"TIMEOUT triggered after {elapsed:.1f}s (cap={TIMEOUT_SEC}s)", flush=True)
else:
    print(f"Julia run_yaml exited with code {returncode} in {elapsed:.1f}s", flush=True)

# Print last 200 lines of the log
with open(LOG_PATH) as f:
    lines = f.readlines()
n_lines = len(lines)
print(f"--- log: {n_lines} total lines; showing last 200 ---", flush=True)
for line in lines[-200:]:
    print(line, end="", flush=True)

if timeout_triggered:
    sys.exit(2)
sys.exit(returncode if returncode is not None else 1)
