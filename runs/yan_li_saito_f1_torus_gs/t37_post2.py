import subprocess, os, sys, time
env = os.environ.copy()
env["LD_LIBRARY_PATH"] = "/usr/lib/wsl/lib"
start = time.time()
result = subprocess.run(
    ["/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia",
     "--project=/home/suzume/workspace/BEC-simulation",
     "/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/t37_post2.jl"],
    env=env, capture_output=True, text=True, timeout=600,
)
elapsed = time.time() - start
print("STDOUT:", result.stdout)
print("STDERR:", result.stderr[-5000:] if len(result.stderr) > 5000 else result.stderr)
print("EXIT:", result.returncode)
print(f"ELAPSED: {elapsed:.1f}s")
sys.exit(result.returncode)
