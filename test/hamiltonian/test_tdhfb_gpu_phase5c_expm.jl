using Test
using SpinorBEC
using LinearAlgebra
using Printf

# Phase 5c GPU batched matrix-exp tests — design ref
# `tdhfb_gpu_port_design.md` §4 ("BdG matrix-exp on GPU — critical kernel").
#
# Tests the Taylor-series batched matrix-exp `batched_expm_neg_i_dt!`:
# computes `M[v] = exp(-i W[v] dt)` for all voxels in parallel via
# truncated Taylor + CUBLAS.gemm_strided_batched! for the matrix powers.
#
# For ‖W·dt‖ < 0.5, Taylor with N=14 reaches F32 precision (1e-7) — adequate
# for the typical TDHFB regime where g·n·dt ~ 1e-3 → ‖W·dt‖ ~ 1e-2 → 1e-3.

# `return` at the top level of an included file does not stop the include —
# Julia evaluates each top-level expression on its own, so the old
# `try … return nothing … end` guard logged "skipping" and then fell straight
# through to the CUDA calls below. On every CPU-only runner this file died with
# `LoadError: CUDA driver not functional` instead of skipping. The guard has to
# sit inside each `@testset`, whose body IS a function.
const HAS_CUDA = try
    @eval using CUDA
    CUDA.functional()
catch
    false
end

ext = HAS_CUDA ? Base.get_extension(SpinorBEC, :SpinorBECCUDAExt) : nothing
batched_expm = HAS_CUDA ? ext.batched_expm_neg_i_dt! : nothing

HAS_CUDA && (GC.gc(); CUDA.reclaim())

@testset "TDHFB GPU phase5c: F=1 batched expm vs CPU Base.exp" begin
    HAS_CUDA || (@test true; return nothing)
    D = 6  # twoD for F=1
    N_vox = 50
    dt = 0.01

    # Random non-Hermitian W (BdG-like), small norm so Taylor converges fast
    W_cpu = randn(ComplexF64, D, D, N_vox) * 0.1
    W_gpu = CuArray(W_cpu)

    M_gpu = CUDA.zeros(ComplexF64, D, D, N_vox)
    A_scratch = CUDA.zeros(ComplexF64, D, D, N_vox)
    A_tmp = CUDA.zeros(ComplexF64, D, D, N_vox)
    P_tmp = CUDA.zeros(ComplexF64, D, D, N_vox)

    batched_expm(M_gpu, W_gpu, dt; n_taylor=14, A_scratch, A_tmp, P_tmp)
    CUDA.synchronize()
    M_gpu_host = Array(M_gpu)

    M_cpu = similar(W_cpu)
    for v in 1:N_vox
        M_cpu[:, :, v] = exp(-1im * W_cpu[:, :, v] * dt)
    end

    max_diff = maximum(abs.(M_gpu_host .- M_cpu))
    @test max_diff < 1e-12  # F64 + small ||W||·dt: Taylor matches to machine eps
end

@testset "TDHFB GPU phase5c: F=6 batched expm sample voxel F32" begin
    HAS_CUDA || (@test true; return nothing)
    D = 26  # twoD for F=6
    N_vox = 32 * 32 * 32  # production scale
    dt = 0.001

    W_cpu = randn(ComplexF32, D, D, N_vox) * 0.05f0
    W_gpu = CuArray(W_cpu)

    M_gpu = CUDA.zeros(ComplexF32, D, D, N_vox)
    A_scratch = CUDA.zeros(ComplexF32, D, D, N_vox)
    A_tmp = CUDA.zeros(ComplexF32, D, D, N_vox)
    P_tmp = CUDA.zeros(ComplexF32, D, D, N_vox)

    batched_expm(M_gpu, W_gpu, dt; n_taylor=10, A_scratch, A_tmp, P_tmp)
    CUDA.synchronize()

    # Sanity check sample voxels against CPU
    for v in [1, 1234, 32768]
        M_cpu_v = exp(-1im * Matrix(W_cpu[:, :, v]) * dt)
        M_gpu_v = Array(M_gpu[:, :, v])
        @test maximum(abs.(M_gpu_v .- M_cpu_v)) < 1e-5
    end
end

@testset "TDHFB GPU phase5c: identity preserved when W = 0" begin
    HAS_CUDA || (@test true; return nothing)
    D = 8
    N_vox = 10
    W = CUDA.zeros(ComplexF64, D, D, N_vox)
    M = CUDA.zeros(ComplexF64, D, D, N_vox)
    A_scratch = similar(M)
    A_tmp = similar(M)
    P_tmp = similar(M)

    batched_expm(M, W, 0.01; n_taylor=14, A_scratch, A_tmp, P_tmp)
    CUDA.synchronize()
    M_host = Array(M)
    # M[:,:,v] should be I for each v
    for v in 1:N_vox
        @test maximum(abs.(M_host[:, :, v] .- Matrix{ComplexF64}(I, D, D))) < 1e-13
    end
end

@testset "TDHFB GPU phase5c: dt=0 returns identity" begin
    HAS_CUDA || (@test true; return nothing)
    D = 6
    N_vox = 5
    W = CuArray(randn(ComplexF64, D, D, N_vox))
    M = CUDA.zeros(ComplexF64, D, D, N_vox)
    A_scratch = similar(M)
    A_tmp = similar(M)
    P_tmp = similar(M)

    batched_expm(M, W, 0.0; n_taylor=10, A_scratch, A_tmp, P_tmp)
    CUDA.synchronize()
    M_host = Array(M)
    for v in 1:N_vox
        @test maximum(abs.(M_host[:, :, v] .- Matrix{ComplexF64}(I, D, D))) < 1e-15
    end
end

@testset "TDHFB GPU phase5c: unitary preservation for Hermitian W" begin
    HAS_CUDA || (@test true; return nothing)
    # If W is Hermitian, exp(-i W dt) is unitary: M M† = I
    D = 8
    N_vox = 20
    dt = 0.05
    # Build Hermitian W per voxel
    W_cpu = randn(ComplexF64, D, D, N_vox) * 0.1
    for v in 1:N_vox
        W_cpu[:, :, v] = 0.5 * (W_cpu[:, :, v] + W_cpu[:, :, v]')
    end
    W_gpu = CuArray(W_cpu)

    M = CUDA.zeros(ComplexF64, D, D, N_vox)
    A_scratch = similar(M)
    A_tmp = similar(M)
    P_tmp = similar(M)

    batched_expm(M, W_gpu, dt; n_taylor=14, A_scratch, A_tmp, P_tmp)
    CUDA.synchronize()
    M_host = Array(M)

    for v in 1:N_vox
        Mv = M_host[:, :, v]
        unitarity_dev = maximum(abs.(Mv * Mv' - I))
        @test unitarity_dev < 1e-10
    end
end

HAS_CUDA && (GC.gc(); CUDA.reclaim())
