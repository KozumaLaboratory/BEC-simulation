using SpinorBEC
using Printf

master = SpinorBEC._load_julia_config(joinpath(@__DIR__, "config.experiment.jl"))
for rate in master["scan"]["zip"]["pipeline.3.dynamics.B.phi.rate"]
    config = deepcopy(master)
    pop!(config, "scan", nothing)
    config["pipeline"][3]["dynamics"]["B"]["phi"]["rate"]["to"] = Float64(rate)
    config["pipeline"][4]["dynamics"]["B"]["phi"]["rate"] = Float64(rate)
    tag = @sprintf("%+g", rate)
    path = joinpath(mkpath(joinpath(@__DIR__, "phi_$tag")), "config.experiment.jl")
    open(io -> show(io, config), path, "w")
    println("wrote $path")
end
