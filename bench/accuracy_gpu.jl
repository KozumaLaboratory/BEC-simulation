# Accuracy audit of the optimized GPU kernels.
#  (1) Unitarity: the Euler rotation must preserve each voxel's spinor norm
#      exactly (reference-independent — a direct measure of matvec accuracy).
#  (2) Norm + energy drift over many RTP steps (the physical accuracy metric),
#      GPU vs CPU.
#   julia --project=. bench/accuracy_gpu.jl [N]

import CUDA
using SpinorBEC
using Printf, LinearAlgebra

include(joinpath(@__DIR__, "eu151_params.jl"))
const N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 64

# ---------- (1) Per-voxel unitarity of the DDI Euler rotation ----------
# Random spinor field + random dipolar field; rotation is unitary so each
# voxel's Σ_c|ψ_c|² must be invariant. Max relative norm change = accuracy.
println("="^64)
println("(1) Euler rotation unitarity (per-voxel norm preservation)")
let
    sm = spin_matrices(6); D = 13
    psi_h = randn(ComplexF64, N, N, N, D)
    phix_h = randn(Float64, N, N, N); phiy_h = randn(Float64, N, N, N); phiz_h = randn(Float64, N, N, N)
    for (lbl, dev) in (("CPU", false), ("GPU", true))
        psi = dev ? CUDA.CuArray(psi_h) : copy(psi_h)
        phx = dev ? CUDA.CuArray(phix_h) : copy(phix_h)
        phy = dev ? CUDA.CuArray(phiy_h) : copy(phiy_h)
        phz = dev ? CUDA.CuArray(phiz_h) : copy(phiz_h)
        P0 = reshape(Array(psi), N^3, D)
        n_before = vec(sum(abs2, P0; dims=2))
        SpinorBEC._apply_ddi_rotation!(psi, phx, phy, phz, sm, 0.01, 3)
        dev && CUDA.synchronize()
        P1 = reshape(Array(psi), N^3, D)
        n_after = vec(sum(abs2, P1; dims=2))
        rel = maximum(abs.(n_after .- n_before) ./ n_before)
        @printf("    %s  max per-voxel |Δ‖s‖²|/‖s‖² = %.3e\n", lbl, rel)
    end
end

# ---------- (2) Norm + energy drift over RTP steps ----------
println("="^64)
println("(2) RTP norm + energy drift over 200 steps (Eu $(N)^3 DDI)")
function build(backend)
    grid = make_grid(GridConfig(ntuple(_->N,3), ntuple(_->12.0,3)))
    sp = SimParams(; dt=0.002, n_steps=1, imaginary_time=false)
    psi0 = zeros(ComplexF64, N,N,N,13)
    for I in CartesianIndices((N,N,N))
        r2 = sum((I[d]-N/2)^2 for d in 1:3)/N
        psi0[I,1]=exp(-r2); psi0[I,3]=0.1exp(-r2); psi0[I,7]=0.05exp(-r2)
    end
    ws = make_workspace(; grid, atom=Eu151,
        interactions=InteractionParams(Dict(0=>EU_c0,1=>0.3)),
        zeeman=ZeemanParams(EU_p_weak,0.05), potential=HarmonicTrap((1.0,1.0,EU_λ_z)),
        sim_params=sp, psi_init=copy(psi0), enable_ddi=true, c_dd=100.0, backend=backend)
    dV = prod(grid.config.box_size ./ grid.config.n_points)
    ws.state.psi ./= sqrt(sum(abs2, ws.state.psi)*dV)
    ws, dV
end

for (lbl, backend) in (("CPU", CPUBackend()), ("GPU", CUDABackend()))
    ws, dV = build(backend)
    norm0 = sum(abs2, ws.state.psi)*dV
    e0 = total_energy(ws)
    for _ in 1:200; split_step!(ws); end
    backend isa CUDABackend && CUDA.synchronize()
    norm1 = sum(abs2, ws.state.psi)*dV
    e1 = total_energy(ws)
    @printf("    %s  |‖ψ‖²-1|: start %.2e → end %.2e | energy rel drift %.3e\n",
            lbl, abs(norm0-1), abs(norm1-1), abs((e1-e0)/e0))
end
println("DONE")
