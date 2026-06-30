# scripts/edh_vs_flower/run_edh_v4.jl — EdH-only driver: run_yaml + Mermin-Ho diagnostic.
import CUDA
using SpinorBEC
using JLD2, Printf
include(joinpath(@__DIR__, "mermin_ho_diagnostic.jl"))   # run_mermin_ho_diagnostic
const RUNS_ROOT = get(ENV, "FPE_RUNS_ROOT", "runs")
const YAML = ARGS[1]
function find_result(rd)
    c = String[]
    for (root, _, fs) in walkdir(rd), fn in fs
        endswith(fn, ".jld2") && push!(c, joinpath(root, fn))
    end
    isempty(c) && error("no jld2 in $rd")
    sort!(c; by=filesize, rev=true); c[1]
end
run_dir = run_yaml(YAML; base_dir=RUNS_ROOT)
result = find_result(run_dir)
@printf("[edh_v4] run_dir=%s\n[edh_v4] result=%s\n", run_dir, result)
run_mermin_ho_diagnostic(result, joinpath(run_dir, "mermin_ho_diag.jld2"); F_OVR="6")
@printf("[edh_v4] DONE run_dir=%s\n", run_dir)
