# Re-run a single config from runs/ in the foreground with full logging.
#
# Usage:
#   julia --project=. scripts/rerun_single.jl phi_omega_scan
#   julia --project=. scripts/rerun_single.jl eu151_edh
#
# Cleans any partial .checkpoints/ directory (so cached half-finished
# state from the prior crash doesn't poison the rerun) but leaves
# completed point_NNN.jld2 / frames/ alone for resumable scans.

import CUDA
using SpinorBEC
using Dates

length(ARGS) == 1 || error("usage: julia --project=. scripts/rerun_single.jl <run_name>")
run_name = ARGS[1]
config_path = joinpath("runs", run_name, "config.yaml")
isfile(config_path) || error("config not found: $config_path")

ckpt_dir = joinpath("runs", run_name, ".checkpoints")
if isdir(ckpt_dir)
    @info "removing stale checkpoint dir" ckpt_dir
    rm(ckpt_dir; recursive=true, force=true)
end

@async while true
    ;
    flush(stdout);
    flush(stderr);
    sleep(10);
end

println("=" ^ 72)
println("[$(now())] rerun_single: $run_name")
println("=" ^ 72)
flush(stdout)

t0 = time()
run_yaml(config_path; base_dir="runs", verbose=true)
dt = time() - t0
println("\n[$(now())] $run_name done in $(round(dt/3600; digits=2)) h")
flush(stdout)
