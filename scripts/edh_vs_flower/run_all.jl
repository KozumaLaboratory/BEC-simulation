# scripts/edh_vs_flower/run_all.jl
# ============================================================================
# Single-process driver for the EdH-vs-Flower comparison: runs BOTH YAML
# configs (sharing the cached 10 mG ground state) and then the Mermin–Ho
# post-hoc diagnostic on each — all in one Julia session so the JIT cascade
# is paid once (important on TSUBAME GPU wall-time).
#
# Usage (CPU smoke or GPU production both work — backend comes from the YAML):
#   julia --project=. scripts/edh_vs_flower/run_all.jl [edh.yaml] [flower.yaml]
#
# Defaults to the production configs. Returns nonzero on any failure.
# ============================================================================

using SpinorBEC
using SpinorBEC: run_yaml
include(joinpath(@__DIR__, "mermin_ho_diagnostic.jl"))   # run_mermin_ho_diagnostic

const EDH_YAML = length(ARGS) >= 1 ? ARGS[1] : "runs/eu151_edh_vs_flower/edh_quench.yaml"
const FLO_YAML = length(ARGS) >= 2 ? ARGS[2] : "runs/eu151_edh_vs_flower/flower_smooth.yaml"

# Pick the result file: the largest *.jld2 in the run dir (the streamed full-ψ
# result dwarfs any sidecar). Falls back to a recursive search.
function find_result_jld2(run_dir::AbstractString)
    cands = String[]
    for (root, _, files) in walkdir(run_dir)
        for fn in files
            endswith(fn, ".jld2") && push!(cands, joinpath(root, fn))
        end
    end
    isempty(cands) && error("no .jld2 under $run_dir")
    cands[argmax(map(filesize, cands))]
end

function process(label, yaml)
    println("\n", "="^70, "\n[run_all] $label  ←  $yaml\n", "="^70)
    run_dir = run_yaml(yaml)
    println("[run_all] $label run dir: $run_dir")
    result = find_result_jld2(run_dir)
    out_h5 = joinpath(run_dir, "mermin_ho_diag.jld2")
    println("[run_all] $label result: $result")
    run_mermin_ho_diagnostic(result, out_h5; F_OVR="6")
    (run_dir, result, out_h5)
end

edh = process("EdH(quench)", EDH_YAML)
flo = process("Flower(smooth)", FLO_YAML)

println("\n[run_all] DONE")
println("  EdH    diag: ", edh[3])
println("  Flower diag: ", flo[3])
println("\nNext: render figures locally with")
println("  python3 scripts/edh_vs_flower/viz/viz_compare.py \\")
println("      ", edh[3], " \\")
println("      ", flo[3], " \\")
println("      runs/eu151_edh_vs_flower/figures")
