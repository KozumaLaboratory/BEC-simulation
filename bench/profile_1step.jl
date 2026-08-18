# Profile ONE split_step! by kernel. Two configs:
#   (A) bench config: Eu151 16³, c0/c1, NO DDI  (matches baseline split_step bench)
#   (B) production:    Eu151 16³ + 32³, c0 + DDI (fast-Larmor / Matsui regime)
# Uses the built-in TimerOutputs tracing (enable_tracing! / TIMER) for a
# per-kernel breakdown, plus a BenchmarkTools minimum for the whole step.

using SpinorBEC
using BenchmarkTools
using Printf

include(joinpath(@__DIR__, "eu151_params.jl"))

ferro_init(grid, D) = begin
    psi = zeros(ComplexF64, grid.config.n_points..., D)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r2 = sum(grid.x[d][I[d]]^2 for d in 1:length(grid.config.n_points))
        psi[I, 1] = exp(-r2 / 2)
    end
    psi
end

function build_ws(; n, ddi::Bool)
    L = 12.0
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> L, 3)))
    sp = SimParams(; dt = 0.005, n_steps = 1)
    psi0 = ferro_init(grid, 13)
    ws = make_workspace(;
        grid, atom = Eu151,
        interactions = InteractionParams(Dict(0 => EU_c0, 1 => 0.0)),
        zeeman = ZeemanParams(EU_p_weak, 0.0),
        potential = HarmonicTrap((1.0, 1.0, EU_λ_z)),
        sim_params = sp, psi_init = psi0,
        enable_ddi = ddi, c_dd = ddi ? 100.0 : 0.0,
    )
    # normalize
    dV = prod(grid.config.box_size ./ grid.config.n_points)
    ws.state.psi ./= sqrt(sum(abs2, ws.state.psi) * dV)
    ws
end

function profile_config(label; n, ddi)
    println("\n" * "="^70)
    println("CONFIG: $label   (n=$n, ddi=$ddi, threads=$(Threads.nthreads()))")
    println("="^70)
    ws = build_ws(; n, ddi)

    for _ in 1:5; SpinorBEC.split_step!(ws); end   # warmup JIT

    SpinorBEC.enable_tracing!()
    SpinorBEC.reset_tracing!()
    for _ in 1:200; SpinorBEC.split_step!(ws); end
    println(SpinorBEC.TIMER)
    SpinorBEC.disable_tracing!()

    b = @benchmark SpinorBEC.split_step!($ws) samples=200 seconds=15
    m = minimum(b)
    @printf("\n  WHOLE split_step!: min %.1f μs / %d allocs / %d bytes\n",
            time(m)/1e3, allocs(m), memory(m))
    time(m)
end

# Eu production is always DDI-on; the no-DDI case is not a real scenario.
profile_config("prod-DDI-16"; n=16, ddi=true)   # smoke/test size (serial path)
profile_config("prod-DDI-32"; n=32, ddi=true)   # production-shaped (threaded path)
