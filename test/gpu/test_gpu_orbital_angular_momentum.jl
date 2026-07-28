# orbital_angular_momentum on a device array.
#
# The body runs CPU FFTs and loops over voxels, so a CuArray ψ hit CUDA's
# scalar-indexing guard and THREW — measured on main before the fix:
# "Scalar indexing is disallowed. Invocation of getindex resulted in scalar
# indexing of a GPU array."
#
# This is not a niche entry point: ⟨L_z⟩ is the observable the Einstein-de Haas
# / Barnett J_z ledger is written in (J_z = L_z + ⟨F_z⟩), and those runs are on
# GPU. Same bug class as `test_superfluid_fraction_gpu.jl` — a public analysis
# function that only worked when something upstream happened to host the array.
#
# Gated on CUDA.functional(); a no-op on CPU-only machines.

using SpinorBEC
using Test
using FFTW

@testset "orbital_angular_momentum on device arrays (gated)" begin
    cuda_available = try
        import CUDA
        CUDA.functional()
    catch
        false
    end

    if !cuda_available
        @info "CUDA not functional — orbital_angular_momentum GPU test skipped"
        @test true
        return nothing
    end

    N = 32
    L = 12.0
    grid = make_grid(GridConfig{2}((N, N), (L, L)))
    plans = make_fft_plans(grid.config.n_points)

    # Single-component winding-1 vortex: ⟨L_z⟩ → 1 per atom.
    psi_h = zeros(ComplexF64, N, N, 1)
    for j in 1:N, i in 1:N
        x, y = grid.x[1][i], grid.x[2][j]
        psi_h[i, j, 1] = (x + im * y) * exp(-(x^2 + y^2) / 8)
    end
    psi_h ./= sqrt(sum(abs2, psi_h) * cell_volume(grid))

    host = orbital_angular_momentum(psi_h, grid, plans)
    device = orbital_angular_momentum(CUDA.CuArray(psi_h), grid, plans)

    # The device path only copies to the host — the arithmetic is the same
    # code on the same Float64 data, so this is an equality, not a tolerance.
    @test device == host

    # And it is the right number, not merely a consistent one.
    @test abs(host - 1.0) < 0.05

    # A GPU workspace hands in CUFFT plans; those must not be applied to the
    # hosted copy (that was the 30 GB RSS spike this guard also covers).
    # Rb87 is F=1, so the workspace state carries D=3 — put the same vortex in
    # the m=+1 component and leave the rest empty, which reproduces `host`.
    psi3 = zeros(ComplexF64, N, N, 3)
    psi3[:, :, 1] .= psi_h[:, :, 1]
    ws = make_workspace(; grid, atom=Rb87,
        interactions=InteractionParams(Dict{Int, Float64}()),
        potential=NoPotential(),
        sim_params=SimParams(; dt=0.01, n_steps=1),
        psi_init=psi3, backend=CUDABackend())
    @test ws.state.psi isa CUDA.CuArray
    @test orbital_angular_momentum(ws.state.psi, grid, ws.fft_plans) == host
end
