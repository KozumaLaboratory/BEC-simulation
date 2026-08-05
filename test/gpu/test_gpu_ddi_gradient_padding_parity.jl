using SpinorBEC
using SpinorBEC: DDITerm, apply_operator!
using Test

# The padded DDI GRADIENT face, on the GPU.
#
# `_grad_ddi!` reads the padded potential as a Cartesian CORNER VIEW of
# `Phi_*_pad` — a strided, non-contiguous `SubArray` — and broadcasts it against
# component slices of ψ. On the CPU that is unremarkable. On the GPU it is the
# class of thing this codebase has been bitten by repeatedly: a view or a host
# array reaching a device broadcast and either failing to compile
# ("passing non-bitstype argument") or silently falling back to scalar
# indexing.
#
# `test_gpu_ddi_contraction_parity.jl` already covers the padded CONVOLUTION on
# device, but it stops at `_compute_and_convolve_ddi_padded!` and never calls
# `apply_operator!`, so the face this gates was uncovered.
#
# Claim: the padded DDI gradient agrees between CPU and GPU. Plus a canary, so
# that a green result cannot come from padding being a no-op at this size.

const HAS_CUDA = try
    @eval import CUDA
    CUDA.functional()
catch
    false
end

function _ddi_ws(backend; padded::Bool, psi0)
    grid = make_grid(GridConfig((8, 8, 8), (8.0, 8.0, 8.0)))
    make_workspace(;
        grid, atom=Na23,
        interactions=InteractionParams(Dict(0 => 5.0, 1 => -0.2)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=0.005, n_steps=1), psi_init=copy(psi0),
        enable_ddi=true, c_dd=1.0,
        ddi_padding=padded, ddi_pad_factor=2,
        backend=backend,
    )
end

function _ddi_grad(ws)
    psi = ws.state.psi
    g = similar(psi)
    fill!(g, zero(eltype(g)))
    apply_operator!(g, DDITerm(), ws, psi)
    Array(g)
end

@testset "padded DDI gradient: GPU == CPU" begin
    if !HAS_CUDA
        @info "CUDA not functional — GPU padded-DDI-gradient gate skipped"
        @test true
    else
        n = (8, 8, 8)
        grid = make_grid(GridConfig(n, (8.0, 8.0, 8.0)))
        D = 3
        psi0 = zeros(ComplexF64, n..., D)
        for I in CartesianIndices(n)
            env = exp(-sum(grid.x[d][I[d]]^2 for d in 1:3) / 4)
            psi0[I, 1] = env
            psi0[I, 2] = 0.6env * cis(0.4)
            psi0[I, 3] = 0.3env * cis(-0.9)
        end

        g_cpu_pad = _ddi_grad(_ddi_ws(CPUBackend(); padded=true, psi0))
        g_gpu_pad = _ddi_grad(_ddi_ws(CUDABackend(); padded=true, psi0))
        g_cpu_bare = _ddi_grad(_ddi_ws(CPUBackend(); padded=false, psi0))

        scale = maximum(abs, g_cpu_pad)
        @test scale > 0
        @test all(isfinite, g_gpu_pad)

        # Canary: without this the parity below could hold because padding does
        # nothing at this size, and the padded face would be untested.
        @test maximum(abs, g_cpu_pad .- g_cpu_bare) / scale > 1.0e-3

        # The claim.
        @test maximum(abs, g_gpu_pad .- g_cpu_pad) / scale < 1.0e-10
    end
end
