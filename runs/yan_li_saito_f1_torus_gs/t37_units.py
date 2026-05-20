import subprocess, os, sys
env = os.environ.copy()
env["LD_LIBRARY_PATH"] = "/usr/lib/wsl/lib"
result = subprocess.run(
    ["/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia",
     "--project=/home/suzume/workspace/BEC-simulation",
     "/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/t37_units.jl"],
    env=env, capture_output=True, text=True, timeout=120,
)
print("STDOUT:", result.stdout)
print("STDERR:", result.stderr[-2000:] if len(result.stderr) > 2000 else result.stderr)
print("EXIT:", result.returncode)
sys.exit(result.returncode)
