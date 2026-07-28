# Does staging ψ through shared memory (for a coalesced load/store) pay?
#
#   LD_LIBRARY_PATH=... julia --project=. bench/rtp_stage_ab.jl [N] [steps]
#
# The rotation/half-step kernels put one spin COMPONENT per lane, so a lane
# reads `P[vox, c]` with the D components N·16 B apart — 13 scattered 32-byte
# transactions per warp. `SPIN_STAGE_SHARED[]` moves ψ through shared memory
# with consecutive threads on consecutive voxels instead, turning the scatter
# into a shared-memory transpose.
#
# The answer is architecture-dependent, which is the point of the toggle:
# where FP64 is 1/64-rate the kernel is compute-bound and staging is dead
# weight; where it is 1/2-rate the kernel is at ~27 % of peak bandwidth and the
# coalescing is the whole game. Run this on BOTH.

import CUDA
using SpinorBEC
using Printf
include(joinpath(@__DIR__, "eu151_params.jl"))
include(joinpath(@__DIR__, "reconcile.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 64
const N_STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 10
const Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)

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

function ms_per_step(stage::Bool; k=N_STEPS, samples=5)
    Ext.SPIN_STAGE_SHARED[] = stage
    ws = build_ws()
    step_n!(ws, 3)
    t = 1e3 * timed(() -> step_n!(ws, k); warmup=1, samples).t / k
    ws = nothing
    GC.gc(true)
    CUDA.reclaim()
    t
end

function main()
    @printf("ψ-staging A/B — Eu151 D=13, %d^3, %s, load=%s\n",
        N_GRID, CUDA.name(CUDA.device()),
        first(split(read("/proc/loadavg", String))))
    SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true
    SpinorBEC.SPIN_CHAIN_FUSION_ENABLED[] = true
    offs = Float64[]
    ons = Float64[]
    for _ in 1:3
        push!(offs, ms_per_step(false))
        push!(ons, ms_per_step(true))
    end
    Ext.SPIN_STAGE_SHARED[] = false
    off, on = minimum(offs), minimum(ons)
    @printf("\n  %-30s %8.3f ms/step  %s\n", "direct (N,D) addressing", off,
        string(round.(offs; digits=3)))
    @printf("  %-30s %8.3f ms/step  %s\n", "staged through shared", on,
        string(round.(ons; digits=3)))
    @printf("\n  staging is %.3fx  (%+.3f ms/step)\n", off / on, off - on)
end

main()
