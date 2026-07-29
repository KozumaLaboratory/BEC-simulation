# Fused V half-step vs the operator-by-operator chain, same process, same
# workspace, warm.
#
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. bench/rtp_fusion_ab.jl [N] [steps]
#
# Comparing two separate `bench/profile_rtp.jl` runs cannot resolve this: JIT
# state, GPU clocks and machine load all move between processes, and the two
# arms differ by ~10 % of a ~30 ms step. `SPIN_CHAIN_FUSION_ENABLED[]` flips
# the same binary, so the arms share everything else.

import CUDA
using SpinorBEC
using Printf
include(joinpath(@__DIR__, "eu151_params.jl"))
include(joinpath(@__DIR__, "reconcile.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 64
const N_STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 10

function build_ws(; n=N_GRID)
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> 12.0, 3)))
    sp = SimParams(; dt=1e-4, n_steps=N_STEPS, imaginary_time=false, save_every=10^9)
    ws = make_workspace(;
        grid, atom=Eu151, interactions=eu_interaction_params(0.05),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap(1.0, 1.0, EU_λ_z),
        sim_params=sp, enable_ddi=true, c_dd=EU_c_dd, backend=CUDABackend(),
    )
    psi = init_psi(grid, ws.spin_matrices.system;
        state=:spin_coherent, init_theta=0.6, init_phi=0.4)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    copyto!(ws.state.psi, psi)
    ws
end

step_n!(ws, k) = (for _ in 1:k
    SpinorBEC.split_step!(ws)
end; CUDA.synchronize())

# Each arm builds its own workspace (~0.3 GB at 64³ with the midpoint scratch),
# so the pool is reclaimed between arms — otherwise the later arms measure
# allocator pressure rather than the step.
function ms_per_step(fused::Bool; k=N_STEPS, samples=5)
    SpinorBEC.SPIN_CHAIN_FUSION_ENABLED[] = fused
    ws = build_ws()
    step_n!(ws, 3)                       # warm this arm's kernels
    t = 1e3 * timed(() -> step_n!(ws, k); warmup=1, samples).t / k
    ws = nothing
    GC.gc(true)
    CUDA.reclaim()
    t
end

function main()
    @printf("RTP fused-V A/B — Eu151 D=13, %d^3, %s, load=%s\n",
        N_GRID, CUDA.name(CUDA.device()),
        first(split(read("/proc/loadavg", String))))
    SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true
    # Interleave the arms so a drifting clock cannot masquerade as a win.
    offs = Float64[]
    ons = Float64[]
    for _ in 1:3
        push!(offs, ms_per_step(false))
        push!(ons, ms_per_step(true))
    end
    off = minimum(offs)
    on = minimum(ons)
    @printf("\n  %-34s %8.3f ms/step  %s\n", "operator-by-operator half-step",
        off, string(round.(offs; digits=2)))
    @printf("  %-34s %8.3f ms/step  %s\n", "fused half-step",
        on, string(round.(ons; digits=2)))
    @printf("\n  speedup %.3fx  (%.3f ms/step saved)\n", off / on, off - on)
    SpinorBEC.SPIN_CHAIN_FUSION_ENABLED[] = true
end

main()
