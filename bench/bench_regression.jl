# BenchmarkTools regression suite. Run from project root:
#   julia --project=. bench/bench_regression.jl
#
# Tracks wall-clock + allocation for split_step, find_ground_state,
# common analyzers. Saved to bench/results.json so PR runs can diff
# against the baseline.

using BenchmarkTools
using SpinorBEC
using JSON
using Printf

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
        @benchmarkable SpinorBEC.split_step!($ws)
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

# 4. spin_mixing inner loop on Eu151 (D=13). Hot kernel called each
# split-step substep when c1 ≠ 0. Documented `_get_spinor` 352 B/call
# alloc lives here — measuring it directly tightens the alloc loop.
let
    sm = spin_matrices(6)            # F=6 → D=13
    psi = randn(ComplexF64, 16, 16, 8, 13) ./ 100
    c1 = 0.028
    dt = 0.005
    n_pts = (16, 16, 8)
    SUITE["kernel/spin_mixing_eu151_16x16x8"] = @benchmarkable begin
        SpinorBEC._spin_mixing_loop!($psi, $sm, $c1, $dt,
            Val(13), $n_pts, false)
    end
end

# 6. apply_ddi_step! on Eu151 16³ (CPU). 6 rFFTs + spin-density + tensor
# contraction in k-space + Euler spin rotation. Single largest cost in
# Klaus / Berry rotating-basis runs (called every split-step).
let
    grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
    sm = spin_matrices(6)
    ddi = SpinorBEC.make_ddi_params(grid, Eu151)
    bufs = SpinorBEC.make_ddi_buffers(grid.config.n_points)
    psi = randn(ComplexF64, 16, 16, 16, 13) ./ 100
    SUITE["kernel/apply_ddi_step_eu151_16cubed"] = @benchmarkable begin
        SpinorBEC.apply_ddi_step!($psi, $sm, $ddi, $bufs, 0.005, 3)
    end
end

# 5. apply_uniform_spin_rotation! on Eu151 (D=13). GPU-safe matmul
# rebuilds R::Matrix per call from (phi_x, phi_y, phi_z) — host scalar
# work + broadcast, used heavily by rotating-basis Klaus runs. Bench
# the production path (scratch threaded through) — without scratch the
# function falls back to similar(psi) per call (~432 KB) which is the
# fallback path, not what production callers exercise. Optimising the
# fallback was misleading Ralph into changes that broke split_step
# (collateral +15%).
let
    sm = spin_matrices(6)
    psi = randn(ComplexF64, 16, 16, 8, 13) ./ 100
    scratch = similar(psi)
    SUITE["kernel/uniform_spin_rotation_eu151_16x16x8"] = @benchmarkable begin
        SpinorBEC.apply_uniform_spin_rotation!($psi, $sm,
            0.1, 0.05, 0.0, 0.005, 3; scratch = $scratch)
    end
end

# Tune + run. Use minimum (not median) for noise immunity — system jitter
# only adds time, never subtracts, so minimum is a tighter floor on true
# performance. samples=100 + 10s budget gives us several hundred datapoints
# per benchmark; minimum() over those is stable to ~1% on this machine.
println("Tuning…"); tune!(SUITE)
println("Running…")
results = run(SUITE; verbose = false, samples = 100, seconds = 10.0)

# Save minimum time / allocations
out = Dict{String,Any}()
for (name, t) in BenchmarkTools.leaves(results)
    m = minimum(t)
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
println("\nName                                   min(μs)       allocs   memory")
println("-" ^ 75)
for (k, v) in sort(collect(out); by = first)
    @printf("%-40s  %10.1f  %8d  %8d\n",
            k, v["time_ns"] / 1e3, v["allocs"], v["memory_bytes"])
end
