# Property-style CPU/GPU equivalence fuzz for every per-point spin step.
#
# Why this exists: a GPU spin_mixing R_z sign bug (cis(±m·α)) was missed
# by the existing CUDA gate test (`test_cuda.jl`) because it only ran a
# polarized F=1 ground state — ⟨F_y⟩ = 0, the exact symmetry plane the
# bug needed to step off. Saved by code review (2026-04-26). To prevent
# recurrence we fuzz every GPU step on random *complex* spinors across
# F=1..6 — any deviation from the CPU reference shows up immediately.
#
# The whole testset is gated on `CUDA.functional()`; on CPU-only CI
# this file becomes a no-op. Whenever a GPU runner is available it
# becomes the load-bearing backstop for these per-point kernels.

using SpinorBEC
using Test
using Random
using LinearAlgebra

@testset "CUDA / CPU per-step equivalence (gated)" begin
    cuda_available = try
        import CUDA
        CUDA.functional()
    catch
        false
    end

    if !cuda_available
        @info "CUDA not available, skipping GPU/CPU equivalence fuzz"
        @test true
        return nothing
    end

    CuArray = CUDA.CuArray

    function _randspinor(rng, F::Int, n_pts)
        D = 2F + 1
        psi = randn(rng, ComplexF64, n_pts..., D)
        # Renormalise so |psi| stays O(1)
        psi ./= sqrt(sum(abs2, psi))
        psi
    end

    @testset "spin_mixing — random complex spinors, F=1..6" begin
        rng = Random.MersenneTwister(0xC0DE)
        for F in 1:6, trial in 1:6
            sm = SpinorBEC.spin_matrices(F)
            # 1D, 8 grid points keeps each trial sub-millisecond
            psi_cpu = _randspinor(rng, F, (8,))
            psi_gpu = CuArray(copy(psi_cpu))
            c1 = randn(rng)
            dt = 0.0017          # generic, off any obvious π/c1 resonance
            ndim = 1
            SpinorBEC.apply_spin_mixing_step!(psi_cpu, sm, c1, dt, ndim)
            SpinorBEC.apply_spin_mixing_step!(psi_gpu, sm, c1, dt, ndim)
            diff = maximum(abs, Array(psi_gpu) .- psi_cpu)
            @test diff < 1e-10
        end
    end

    @testset "nematic — random complex spinors, F=2..6" begin
        # F=1 has no nematic step (S=0 pair channel needs F≥2). The c2
        # coefficient is read via get_cn(ip, 2) → ip.c_extra[1], so the
        # 3-arg positional InteractionParams(c0, c1, c_extra) form is
        # the right entry point here.
        rng = Random.MersenneTwister(0xBEEF)
        for F in 2:6, trial in 1:4
            sm = SpinorBEC.spin_matrices(F)
            psi_cpu = _randspinor(rng, F, (8,))
            psi_gpu = CuArray(copy(psi_cpu))
            c2 = randn(rng)
            ip = InteractionParams(0.0, 0.0, Float64[c2])
            dt = 0.0023
            ndim = 1
            SpinorBEC.apply_nematic_step!(psi_cpu, ip, F, dt, ndim)
            SpinorBEC.apply_nematic_step!(psi_gpu, ip, F, dt, ndim)
            diff = maximum(abs, Array(psi_gpu) .- psi_cpu)
            @test diff < 1e-10
        end
    end

    @testset "raman — non-zero k_eff, random complex spinors, F=1..3" begin
        # Raman step depends on (Ω, δ, k_eff). Limit F to ≤3 so the
        # rotation matrices stay tractable per trial.
        rng = Random.MersenneTwister(0xFACE)
        for F in 1:3, trial in 1:4
            sm = SpinorBEC.spin_matrices(F)
            psi_cpu = _randspinor(rng, F, (8,))
            psi_gpu = CuArray(copy(psi_cpu))
            grid = make_grid(GridConfig((8,), (4.0,)))
            Ω = randn(rng)
            δ = randn(rng)
            k_eff = (randn(rng),)
            raman = RamanCoupling(Ω, δ, k_eff)
            dt = 0.0019
            SpinorBEC.apply_raman_step!(psi_cpu, sm, raman, grid, dt)
            SpinorBEC.apply_raman_step!(psi_gpu, sm, raman, grid, dt)
            diff = maximum(abs, Array(psi_gpu) .- psi_cpu)
            @test diff < 1e-10
        end
    end

    @testset "tensor — random complex spinors, F=2..6" begin
        # Tensor interaction step now runs the full path entirely on GPU
        # via CUSOLVER batched eigen + CUBLAS gemm. Compare against the
        # CPU per-point eigen reference.
        rng = Random.MersenneTwister(0xDA2A)
        for F in 2:6, trial in 1:3
            sm = SpinorBEC.spin_matrices(F)
            psi_cpu = _randspinor(rng, F, (8,))
            psi_gpu = CuArray(ComplexF32.(copy(psi_cpu)))
            # Random g_S over even channels — picks ψ off the diagonal
            g_dict = Dict{Int, Float64}(
                S => randn(rng) for S in 0:2:(2F)
            )
            cache = SpinorBEC._make_tensor_cache_from_channels(F, g_dict)
            dt = 0.0011
            SpinorBEC.apply_tensor_interaction_step!(psi_cpu, cache, sm, dt, 1)
            SpinorBEC.apply_tensor_interaction_step!(psi_gpu, cache, sm, dt, 1)
            diff = maximum(abs, ComplexF64.(Array(psi_gpu)) .- psi_cpu)
            # F32 GPU vs F64 CPU — relax tolerance to 1e-5 for the tensor
            # path because the eigendecomposition error compounds with
            # the F32→F64 reference comparison.
            @test diff < 1e-5
        end
    end

    @testset "norm preservation under random GPU step" begin
        # Bonus invariant — independent of CPU reference: every step we
        # apply must be unitary. Norm-drift over a random-spinor + random
        # parameters trial should be at most a few ULPs.
        rng = Random.MersenneTwister(0x1234)
        for F in 1:6
            sm = SpinorBEC.spin_matrices(F)
            psi = CuArray(_randspinor(rng, F, (8,)))
            n0 = sum(abs2, psi)
            SpinorBEC.apply_spin_mixing_step!(psi, sm, randn(rng), 0.001, 1)
            @test sum(abs2, psi) ≈ n0 atol=1e-10
        end
    end
end
