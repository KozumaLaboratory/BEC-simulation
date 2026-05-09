using Test
using SpinorBEC

@testset "P3/P4 scenario YAMLs — load + parse smoke test" begin
    scenario_dir = joinpath(@__DIR__, "..", "runs", "scenarios")
    yamls = String[]
    for entry in readdir(scenario_dir)
        d = joinpath(scenario_dir, entry)
        isdir(d) || continue
        (startswith(entry, "p3_") || startswith(entry, "p4_")) || continue
        path = joinpath(d, "params.yaml")
        isfile(path) && push!(yamls, path)
    end
    @test length(yamls) >= 6
    @info "Discovered $(length(yamls)) P3/P4 scenarios"

    @testset "$(basename(dirname(path)))" for path in yamls
        cfg = load_config(path)
        @test cfg isa PipelineConfig
        @test !isempty(cfg.steps)
    end
end
