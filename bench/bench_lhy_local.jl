# Benchmark driver for the LHY local-mass-matrix eigvals prototype.
#
#     LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. bench/bench_lhy_local.jl
#
# Runs (1) a correctness sanity check against the analytical eigvals of
# the placeholder Hessian M = c_0 (|ψ|² I + ψ ψ†), and (2) timing at
# 24³, 32³, 48³ on CPU and (if CUDA functional) GPU. Output is a table
# the next session can reference for whether the kernel meets the
# Phase-C target of ≲ 50 ms / step at 24³.

using LinearAlgebra: norm
include(joinpath(@__DIR__, "..", "src/hamiltonian/interactions/lhy_local.jl"))
using .LHYLocal

const HAS_CUDA = try
    @eval using CUDA
    CUDA.functional()
catch
    false
end

if HAS_CUDA
    LHYLocal.enable_gpu!(@__MODULE__)
end

# ---- (1) Correctness sanity check ----------------------------------------
# Analytical eigvals of M = c_0 (|ψ|² I + ψ ψ†):
#     λ_1 = 2 c_0 |ψ|²   (×1, eigvec ∝ ψ)
#     λ_k = c_0 |ψ|²     (×D-1, orthogonal complement)

function sanity_check_cpu(; D::Int = 13, n_pts = (8, 8, 8), T::Type = Float64,
                          c_0 = 1.7)
    println("\n=== Sanity check (CPU, D=$D, $(prod(n_pts)) voxels, $T) ===")
    cache = LHYLocal.alloc_cache(T, D, n_pts)
    nx, ny, nz = n_pts
    psi = randn(Complex{T}, nx, ny, nz, D)
    LHYLocal.build_local_M!(cache, psi, c_0)
    LHYLocal.lhy_local_eigvals!(cache)

    # Compare against analytical answer per voxel
    psi_2d = reshape(psi, prod(n_pts), D)
    max_err_top = 0.0
    max_err_rest = 0.0
    for n in axes(psi_2d, 1)
        absq = sum(abs2, psi_2d[n, :])
        analytical = sort!([2c_0 * absq; fill(c_0 * absq, D - 1)])  # ascending
        numerical = sort(cache.eigvals[:, n])
        # Top eigval (last after sort)
        max_err_top = max(max_err_top, abs(numerical[end] - analytical[end]) / max(abs(analytical[end]), 1e-12))
        # Rest
        for k in 1:(D - 1)
            max_err_rest = max(max_err_rest,
                abs(numerical[k] - analytical[k]) / max(abs(analytical[k]), 1e-12))
        end
    end
    println("  max relative err (top eigval):  $max_err_top")
    println("  max relative err (rest D-1):    $max_err_rest")
    pass = max_err_top < 1e-10 && max_err_rest < 1e-9
    println("  $(pass ? "PASS" : "FAIL")")
    pass
end

# ---- (2) Timing ---------------------------------------------------------

function timing_table()
    println("\n=== Timing (10 reps after warm-up) ===")
    println(rpad("backend", 8), rpad("dtype", 9), rpad("D", 4), rpad("grid", 14),
            rpad("voxels", 9), rpad("min ms", 10), rpad("median ms", 11), "max ms")
    println("-"^82)
    for n in (16, 24, 32)
        n_pts = (n, n, n)
        for T in (Float64, Float32)
            r = LHYLocal.bench(13, n_pts; T = T, gpu = false, repeats = 5)
            println(rpad("cpu", 8), rpad(string(T), 9), rpad("13", 4),
                    rpad("$(n)³", 14), rpad(string(r.n_voxels), 9),
                    rpad(string(round(r.min_ms; digits = 2)), 10),
                    rpad(string(round(r.median_ms; digits = 2)), 11),
                    round(r.max_ms; digits = 2))
        end
        if HAS_CUDA
            for T in (Float64, Float32)
                r = LHYLocal.bench(13, n_pts; T = T, gpu = true, repeats = 10)
                println(rpad("gpu", 8), rpad(string(T), 9), rpad("13", 4),
                        rpad("$(n)³", 14), rpad(string(r.n_voxels), 9),
                        rpad(string(round(r.min_ms; digits = 2)), 10),
                        rpad(string(round(r.median_ms; digits = 2)), 11),
                        round(r.max_ms; digits = 2))
            end
        end
    end
end

# Run
ok = sanity_check_cpu()
if HAS_CUDA
    println("\n=== Sanity check (GPU consistency vs CPU) ===")
    cache_cpu = LHYLocal.alloc_cache(Float64, 13, (8, 8, 8))
    cache_gpu = LHYLocal.alloc_cache(Float64, 13, (8, 8, 8); gpu = true)
    psi_cpu = randn(ComplexF64, 8, 8, 8, 13)
    psi_gpu = CUDA.CuArray(psi_cpu)
    LHYLocal.build_local_M!(cache_cpu, psi_cpu, 1.7)
    LHYLocal.lhy_local_eigvals!(cache_cpu)
    LHYLocal.build_local_M!(cache_gpu, psi_gpu, 1.7)
    LHYLocal.lhy_local_eigvals!(cache_gpu)
    cpu_eig = sort!(sort(cache_cpu.eigvals; dims = 1); dims = 2)
    gpu_eig = sort!(sort(Array(cache_gpu.eigvals); dims = 1); dims = 2)
    err = maximum(abs, cpu_eig .- gpu_eig)
    println("  max |Δ eigval CPU vs GPU|: $err")
    println("  $(err < 1e-9 ? "PASS" : "FAIL")")
end

timing_table()
