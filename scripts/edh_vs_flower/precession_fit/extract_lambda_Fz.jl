using JLD2, JSON
F = 6; D = 13; mvals = [F - (c - 1) for c in 1:D]
RUNROOT = "/gs/bs/work/6/ue06186/bec-runs"

dirs = readdir(RUNROOT)
resolve(tag) = RUNROOT * "/" * first(filter(x -> occursin("lam_$(tag)_", x), dirs))

runs = Dict(
    "baseline_1.182" => RUNROOT * "/ramp_quench500_par_da924410",
    "prolate_0.5"    => resolve("prolate"),
    "sphere_1.0"     => resolve("sphere"),
    "oblate2_2.0"    => resolve("oblate2"),
)

out = Dict{String,Any}()
for (name, dir) in runs
    p = dir * "/point_001.jld2"
    jldopen(p, "r") do f
        t = f["dynamics/times"]
        pops = f["dynamics/component_populations"]
        ns = size(pops, 1)
        Fz = [sum(mvals[c] * pops[i, c] for c in 1:D) / sum(pops[i, c] for c in 1:D) for i in 1:ns]
        out[name] = Dict("t" => Float64.(t[1:ns]), "Fz" => Fz)
    end
    println("  $name : $(length(out[name]["Fz"])) frames, Fz[end]=$(round(out[name]["Fz"][end],digits=2))")
end
open(RUNROOT * "/lambda_Fz.json", "w") do io
    JSON.print(io, out)
end
println("wrote lambda_Fz.json")
