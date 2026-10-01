using Test
using SpinorBEC
using JSON

@testset "Sweep hypothesis uses the typed prediction contract" begin
    axes = [SweepAxis(:u, "", :linear, [1.0, 2.0]),
        SweepAxis(:v, "", :linear, [3.0, 4.0])]
    observables = [SweepObservable(key=:signal, kind=:signed)]
    data = [
        Dict{Symbol, Any}(:u => x, :v => y, :signal => x + y + 0.5)
        for x in [1.0, 2.0] for y in [3.0, 4.0]
    ]
    hypothesis = Hypothesis(question="Does signal follow x+y?",
        relation=:residual, primary_obs=:signal,
        models=Dict(:signal => ModelSpec(fn=a -> a.u + a.v, label="x+y")))
    result = SweepResult(axes, observables, data;
        meta=Dict{Symbol, Any}(:narrative => Dict(:hypothesis => hypothesis)))
    spec = to_viewspec(result)
    primary = first(spec["vconcat"])
    @test primary["_meta"]["kind"] == "residual"
    points = primary["layer"][2]["data"]["values"]
    @test length(points) == 4
    @test all(p -> p["value"] == 0.5, points)
    @test all(p -> p["predicted"] == p["u"] + p["v"], points)
    printable = JSON.parse(JSON.json(spec))
    @test printable["_meta"]["narrative"]["hypothesis"]["models"]["signal"]["label"] == "x+y"
    result.meta[:narrative] = Dict("hypothesis" => hypothesis)
    @test to_viewspec(result)["_meta"]["narrative"]["hypothesis"]["relation"] == "residual"
    result.meta[:narrative] = Dict(:hypothesis => Dict(:primary_obs => :signal))
    @test_throws ArgumentError to_viewspec(result)
    result.meta[:narrative] = Dict(:hypothesis => "residual")
    @test_throws ArgumentError to_viewspec(result)
    delete!(result.meta, :narrative)
    @test to_viewspec(result)["_meta"]["narrative"]["hypothesis"] === nothing
end
