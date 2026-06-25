# Parity: fused GPU spin-density kernel vs CPU _compute_spin_density!.
import CUDA
using SpinorBEC
using LinearAlgebra: norm

function run_case(::Type{T}, n_pts) where {T}
    D = 13
    sm = SpinorBEC.spin_matrices((D - 1) ÷ 2)
    ndim = length(n_pts)
    psi_h = randn(Complex{T}, n_pts..., D)
    fx_c = zeros(T, n_pts...); fy_c = zeros(T, n_pts...); fz_c = zeros(T, n_pts...)
    SpinorBEC._compute_spin_density!(fx_c, fy_c, fz_c, psi_h, sm, Val(D), ndim, n_pts)

    psi_g = CUDA.CuArray(psi_h)
    fx_g = CUDA.zeros(T, n_pts...); fy_g = CUDA.zeros(T, n_pts...); fz_g = CUDA.zeros(T, n_pts...)
    SpinorBEC._compute_spin_density!(fx_g, fy_g, fz_g, psi_g, sm, Val(D), ndim, n_pts)
    CUDA.synchronize()

    ex = norm(Array(fx_g) .- fx_c) / max(norm(fx_c), eps(T))
    ey = norm(Array(fy_g) .- fy_c) / max(norm(fy_c), eps(T))
    ez = norm(Array(fz_g) .- fz_c) / max(norm(fz_c), eps(T))
    max(ex, ey, ez)
end

println("Fused GPU spin-density vs CPU parity")
for T in (Float64, Float32)
    re = run_case(T, (16, 16, 16))
    tol = T == Float64 ? 1e-12 : 1e-5
    println("  T=$T 16^3  maxrelerr=$re  ", re < tol ? "OK" : "*** FAIL ***")
end
println("DONE")
