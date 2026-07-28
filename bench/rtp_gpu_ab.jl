# A/B of the RTP step's spin-rotation realization, in ONE process.
#
#   LD_LIBRARY_PATH=... julia --project=. bench/rtp_gpu_ab.jl [64,128] [n_steps]
#
# Both arms run on the same workspace and the same initial ψ, differing only in
# `_SPIN_TAYLOR_ENABLED[]`:
#
#   Euler  — the exact 5-stage kernel (9 HBM passes over ψ: 5 phase + 4 gemm)
#   Tay/warp   — shared adaptive Taylor-Horner, one component per LANE (2 passes)
#   Tay/thread — same recurrence, one VOXEL per thread (coalesced ψ access)
#
# Same process, so device clocks, cuFFT plans and the JIT are common-mode and
# the ratio is the thing being measured rather than a difference of two jobs.
# The run also reports max|Δψ| between the arms after the timed steps, so a
# speedup can never be reported without the accuracy cost of getting it.

import CUDA
using SpinorBEC
using Printf

include(joinpath(@__DIR__, "eu151_params.jl"))
include(joinpath(@__DIR__, "reconcile.jl"))

const Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)
const SIZES = length(ARGS) >= 1 ? parse.(Int, split(ARGS[1], ",")) : [64, 128]
const NSTEP = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 10

function build(n; c1_ratio=0.05, dt=1e-4)
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> 12.0, 3)))
    sp = SimParams(; dt, n_steps=NSTEP, imaginary_time=false, save_every=10^9)
    ws = make_workspace(;
        grid, atom=Eu151,
        interactions=eu_interaction_params(c1_ratio),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap(1.0, 1.0, EU_λ_z),
        sim_params=sp, enable_ddi=true, c_dd=EU_c_dd,
        backend=CUDABackend())
    psi = init_psi(grid, ws.spin_matrices.system;
        state=:spin_coherent, init_theta=0.6, init_phi=0.4)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    (ws, psi)
end

function arm!(ws, psi0, mode::Symbol, k)
    Ext._SPIN_TAYLOR_ENABLED[] = mode !== :euler
    Ext._SPIN_TAYLOR_THREAD_PER_VOXEL[] = mode === :taylor_thread
    copyto!(ws.state.psi, psi0)
    ws.state.t = 0.0
    ws.state.step = 0
    run = () -> (for _ in 1:k
        SpinorBEC.split_step!(ws)
    end; CUDA.synchronize())
    # warm-up must not advance the state we then compare, so re-seed after it
    run()
    copyto!(ws.state.psi, psi0)
    ws.state.t = 0.0
    ws.state.step = 0
    best = Inf
    for _ in 1:3
        copyto!(ws.state.psi, psi0)
        ws.state.t = 0.0
        ws.state.step = 0
        t = CUDA.@elapsed run()
        best = min(best, t)
    end
    (1e3 * best / k, Array(ws.state.psi))
end

println("RTP GPU A/B — Eu151 F=6 (D=13), F64, DDI + c₀ + c₁, midpoint on")
println("  device: ", CUDA.name(CUDA.device()),
    "  free/total ", round(CUDA.available_memory() / 2^30; digits=1), "/",
    round(CUDA.total_memory() / 2^30; digits=1), " GiB")
@printf("\n%6s %11s %11s %11s %9s %9s %11s\n", "grid",
    "Euler", "Tay/warp", "Tay/thread", "sp(warp)", "sp(thr)", "max|Δψ|/|ψ|∞")
for n in SIZES
    ws, psi0 = build(n)
    t_eul, p_eul = arm!(ws, psi0, :euler, NSTEP)
    t_war, p_war = arm!(ws, psi0, :taylor_warp, NSTEP)
    t_thr, p_thr = arm!(ws, psi0, :taylor_thread, NSTEP)
    scale = maximum(abs.(p_eul))
    rel = max(maximum(abs.(p_war .- p_eul)), maximum(abs.(p_thr .- p_eul))) / scale
    @printf("%5d³ %11.3f %11.3f %11.3f %8.2f× %8.2f× %11.2e\n",
        n, t_eul, t_war, t_thr, t_eul / t_war, t_eul / t_thr, rel)
    flush(stdout)
    ws = nothing
    p_eul = nothing
    p_war = nothing
    p_thr = nothing
    GC.gc()
    CUDA.reclaim()
end

# Kernel breakdown of the production path at the largest size.
Ext._SPIN_TAYLOR_ENABLED[] = true
Ext._SPIN_TAYLOR_THREAD_PER_VOXEL[] = true
let n = SIZES[end]
    ws, psi0 = build(n)
    copyto!(ws.state.psi, psi0)
    for _ in 1:3
        SpinorBEC.split_step!(ws)
    end
    CUDA.synchronize()
    println("\n=== CUDA kernel breakdown, $(n)³, Taylor path, one step ===")
    display(CUDA.@profile SpinorBEC.split_step!(ws))
    println()
end
