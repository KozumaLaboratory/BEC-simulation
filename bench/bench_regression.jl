# BenchmarkTools regression suite. Run from project root:
#   julia --project=. bench/bench_regression.jl
#
# Tracks wall-clock + allocation for split_step, find_ground_state,
# common analyzers. Saved to bench/results.json so PR runs can diff
# against the baseline.

using BenchmarkTools
using SpinorBEC
using JSON

const SUITE = BenchmarkGroup()

# 1. split_step on a tiny CPU workspace
let
    grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
    sp = SimParams(; dt = 0.005, n_steps = 1)
    ws = make_workspace(;
        grid, atom = Eu151,
        interactions = InteractionParams(50.0, 1.0),
        zeeman = ZeemanParams(0.5, 0.1),
        potential = HarmonicTrap(1.0, 1.0, 1.0),
        sim_params = sp,
    )
    SUITE["split_step/eu151_16cubed"] =
        @benchmarkable SpinorBEC.split_step!($ws, 0.005)
end

# 2. find_ground_state on a tiny grid
let
    grid = make_grid(GridConfig((16, 16), (6.0, 6.0)))
    SUITE["find_ground_state/rb87_16sq"] = @benchmarkable find_ground_state(;
        grid = $grid, atom = Rb87,
        interactions = InteractionParams(5.0, 0.0),
        potential = HarmonicTrap(1.0, 1.0),
        zeeman = ZeemanParams(0.0, 0.1),
        dt = 0.01, n_steps = 50, tol = 1e-4,
        initial_state = :ferromagnetic,
    )
end

# 3. spin_tomography (representative analyzer)
let
    grid = make_grid(GridConfig((16, 16, 8), (8.0, 8.0, 4.0)))
    psi = randn(ComplexF64, 16, 16, 8, 13) ./ 100
    SUITE["analyze/tomography_16x16x8"] = @benchmarkable begin
        SpinorBEC._run_analyzer(:tomography, $psi, $grid,
            $Eu151, Dict{String,Any}("n_angles" => 5))
    end
end

# Tune + run
println("Tuning…"); tune!(SUITE)
println("Running…"); results = run(SUITE; verbose = false, samples = 10, evals = 1)

# Save median time / allocations
out = Dict{String,Any}()
for (name, t) in leaves(results)
    m = median(t)
    out[join(name, "/")] = Dict(
        "time_ns" => time(m),
        "memory_bytes" => memory(m),
        "allocs" => allocs(m),
    )
end

mkpath("bench")
out_path = "bench/results.json"
open(out_path, "w") do io
    JSON.print(io, out, 2)
end
println("\nWrote $out_path")

# Pretty print
println("\nName                                   median(μs)    allocs   memory")
println("-" ^ 75)
for (k, v) in sort(collect(out); by = first)
    @printf("%-40s  %10.1f  %8d  %8d\n",
            k, v["time_ns"] / 1e3, v["allocs"], v["memory_bytes"])
end
