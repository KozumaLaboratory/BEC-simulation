import subprocess, os, sys, time
env = os.environ.copy()
env["LD_LIBRARY_PATH"] = "/usr/lib/wsl/lib"
t0 = time.time()
result = subprocess.run(
    ["/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia",
     "--project=/home/suzume/workspace/BEC-simulation",
     "/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/t36_smoke.jl"],
    env=env, capture_output=True, text=True, timeout=300,
)
elapsed = time.time() - t0
print("STDOUT:", result.stdout)
print("STDERR:", result.stderr[-3000:] if len(result.stderr) > 3000 else result.stderr)
print("EXIT:", result.returncode)
print(f"ELAPSED: {elapsed:.1f}s")
sys.exit(result.returncode)
