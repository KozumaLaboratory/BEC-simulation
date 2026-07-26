using SpinorBEC
using Test
using Random
using LinearAlgebra

# GPU=CPU parity regression for `apply_projected_gp!` (src/solvers/projected_gp.jl).
#
# Why this exists: the momentum-cutoff mask is built from `ws.grid.k_squared`,
# which is a HOST `Array{Float64,3}` even for a GPU workspace. A bare broadcast
# of that host array against the device `fft_buf` (a `CuArray`) fails GPU
# compilation with "passing non-bitstype argument" — the mask never reaches the
# device. The fix moves the mask to the psi device first
# (`_to_device(ws.backend, ws.grid.k_squared)`, no-op on CPU). This test would
# have caught the compile failure and gates it going forward: the same random ψ
# projected on CPU and GPU must agree bit-for-bit (both the hard and the
# cosine-tapered `smooth=true` paths, since both broadcast the host mask).
#
# The parity testset is gated on `CUDA.functional()`; on CPU-only CI it becomes
# a no-op. The CPU high-k-removal sanity testset below always runs, so this file
# is never a total no-op on CPU CI.

# Build a single-Fourier-mode plane wave exp(i k·r) whose wavevector k is an
# exact grid frequency at index `idx`, so its FFT is one bin at |k|² =
# grid.k_squared[idx]. After projection it survives iff |k| ≤ k_cut.
function _plane_wave(grid, D, idx)
    N = length(grid.config.n_points)
    psi = zeros(ComplexF64, grid.config.n_points..., D)
    kt = ntuple(d -> grid.k[d][idx[d]], N)
    for I in CartesianIndices(grid.config.n_points)
        phase = sum(kt[d] * grid.x[d][I[d]] for d in 1:N)
        psi[I, 1] = cis(phase)
    end
    psi
end

@testset "projected GP — CPU high-k removal sanity" begin
    # Runs everywhere (not gated). Confirms the projection is not a no-op: a
    # high-|k| plane wave is annihilated while a low-|k| one survives.
    grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
    atom = Rb87
    interactions = compute_interaction_params(atom)
    sp = SimParams(; dt=0.001, n_steps=1, imaginary_time=false)
    D = SpinorBEC.SpinSystem(atom.F).n_components

    # Lowest nonzero frequency along one axis vs the Nyquist corner.
    lo_idx = (2, 1, 1)
    hi_idx = (9, 9, 9)   # n/2+1 on each axis ⇒ Nyquist, largest |k|
    ksq_lo = grid.k_squared[lo_idx...]
    ksq_hi = grid.k_squared[hi_idx...]
    @test ksq_lo < ksq_hi
    k_cut = sqrt((ksq_lo + ksq_hi) / 2)   # between the two modes

    ws = make_workspace(; grid, atom, interactions, sim_params=sp)

    # High-k mode: projected to ~zero.
    copyto!(ws.state.psi, _plane_wave(grid, D, hi_idx))
    amp_hi = maximum(abs, ws.state.psi)
    apply_projected_gp!(ws, k_cut)
    @test maximum(abs, ws.state.psi) < 1e-10 * amp_hi

    # Low-k mode: survives essentially untouched.
    copyto!(ws.state.psi, _plane_wave(grid, D, lo_idx))
    amp_lo = maximum(abs, ws.state.psi)
    apply_projected_gp!(ws, k_cut)
    @test maximum(abs, ws.state.psi) > 0.99 * amp_lo
end

@testset "projected GP — GPU/CPU parity (gated)" begin
    cuda_available = try
        import CUDA
        CUDA.functional()
    catch
        false
    end

    if !cuda_available
        @info "CUDA not available, skipping projected-GP GPU/CPU parity"
        @test true
        return nothing
    end

    grid = make_grid(GridConfig((24, 24, 24), (10.0, 10.0, 10.0)))
    atom = Rb87
    interactions = compute_interaction_params(atom)
    sp = SimParams(; dt=0.001, n_steps=1, imaginary_time=false)
    D = SpinorBEC.SpinSystem(atom.F).n_components

    # k_cut at half the Nyquist wavenumber: removes some modes, keeps others.
    k_max = π / minimum(grid.dx)
    k_cut = 0.5 * k_max

    # Identical random complex spinor field on both backends.
    rng = Random.MersenneTwister(0xC17)
    psi0 = randn(rng, ComplexF64, grid.config.n_points..., D)
    scale = maximum(abs, psi0)

    for smooth in (false, true)
        # Force CPUBackend: make_workspace auto-selects GPU for 3D grids with
        # n≥24 when CUDA is functional, so the reference must pin CPU explicitly.
        ws_cpu = make_workspace(;
            grid, atom, interactions, sim_params=sp, backend=CPUBackend()
        )
        ws_gpu = make_workspace(;
            grid, atom, interactions, sim_params=sp, backend=CUDABackend()
        )
        copyto!(ws_cpu.state.psi, psi0)
        copyto!(ws_gpu.state.psi, psi0)

        apply_projected_gp!(ws_cpu, k_cut; smooth)
        apply_projected_gp!(ws_gpu, k_cut; smooth)

        diff = maximum(abs, Array(ws_gpu.state.psi) .- ws_cpu.state.psi)
        @test diff < 1e-10 * scale
    end
end
