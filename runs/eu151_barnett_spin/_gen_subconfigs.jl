using SpinorBEC

master = SpinorBEC._load_julia_config(joinpath(@__DIR__, "config.experiment.jl"))
for (tag, frequency) in (("+0.5", 0.0795775), ("-0.5", -0.0795775))
    config = deepcopy(master)
    pop!(config, "scan", nothing)
    field = config["pipeline"][3]["dynamics"]["B"]
    field["Bx"]["sinusoidal"]["frequency"] = frequency
    field["By"]["sinusoidal"]["frequency"] = frequency
    path = joinpath(mkpath(joinpath(@__DIR__, "stir_$tag")), "config.experiment.jl")
    open(io -> show(io, config), path, "w")
    println("wrote $path")
end
