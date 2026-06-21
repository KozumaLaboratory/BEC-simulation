# Decompose ddi_rotation cost: BLAS gemm stages vs per-voxel phase loops.
using SpinorBEC
using BenchmarkTools, LinearAlgebra, Printf

const SB = SpinorBEC

function setup(n)
    sm = spin_matrices(6)             # F=6 → D=13
    D = 13
    N = n^3
    P = randn(ComplexF64, N, D) ./ 100
    W = similar(P)
    conj_V = Matrix{ComplexF64}(conj(sm.Fy_eigvecs))
    V_T = Matrix{ComplexF64}(transpose(sm.Fy_eigvecs))
    alpha = randn(N); beta = randn(N); theta = randn(N) ./ 100
    (; P, W, conj_V, V_T, alpha, beta, theta, F=6.0, N, D)
end

# Just the 4 gemms (BLAS-bound, OpenBLAS-threaded)
function gemm_only!(s)
    mul!(s.W, s.P, s.conj_V)
    mul!(s.P, s.W, s.V_T)
    mul!(s.W, s.P, s.conj_V)
    mul!(s.P, s.W, s.V_T)
    nothing
end

for n in (16, 32)
    s = setup(n)
    println("\n=== n=$n (N_spatial=$(s.N), D=$(s.D), jl_threads=$(Threads.nthreads()), blas=$(BLAS.get_num_threads())) ===")
    b_full = @benchmark SB._apply_euler_5stage_batched_real!(
        $s.P, $s.W, $s.conj_V, $s.V_T, $s.alpha, $s.beta, $s.theta, $s.F, Val(13)
    ) samples=300 seconds=8
    b_gemm = @benchmark gemm_only!($s) samples=300 seconds=8
    tf = time(minimum(b_full))/1e3
    tg = time(minimum(b_gemm))/1e3
    @printf("  full 5-stage:  %8.1f μs\n", tf)
    @printf("  4 gemms only:  %8.1f μs  (%.0f%%)\n", tg, 100*tg/tf)
    @printf("  phase loops:   %8.1f μs  (%.0f%%)  [by difference]\n", tf-tg, 100*(tf-tg)/tf)
end
