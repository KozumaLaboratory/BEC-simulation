# Parity: adaptive tridiagonal Taylor–Horner DDI rotation vs the exact Euler
# 5-stage kernel (same operator exp(z·Φ·F)). Sweeps the per-step rotation
# R = dt·max|Φ|·F across the Eu EdH regime and into the Euler-fallback regime.
import CUDA
using SpinorBEC
using LinearAlgebra: norm

const Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)

function inputs(N, D, ::Type{T}, scale) where {T}
    sm = SpinorBEC.spin_matrices((D - 1) ÷ 2)
    s = T(scale)
    psi = CUDA.CuArray(randn(Complex{T}, N, 1, 1, D))
    px = CUDA.CuArray(s .* randn(T, N, 1, 1))
    py = CUDA.CuArray(s .* randn(T, N, 1, 1))
    pz = CUDA.CuArray(s .* randn(T, N, 1, 1))
    sm, psi, px, py, pz
end

function run(use_taylor, sm, psi, px, py, pz, dt, it)
    SpinorBEC.SPIN_TAYLOR_ENABLED[] = use_taylor
    p = copy(psi)
    SpinorBEC._apply_ddi_rotation!(p, px, py, pz, sm, dt, 3; imaginary_time=it)
    CUDA.synchronize()
    p
end

println("Taylor–Horner vs Euler DDI rotation parity (D=13, F=6)")
dt = 0.005
F = 6.0
for T in (Float64, Float32)
    for scale in (1.0, 6.0, 35.0, 180.0)   # → R from ~0.02 to well past the halving point
        for it in (false, true)
            sm, psi, px, py, pz = inputs(4096, 13, T, scale)
            pm = sqrt(maximum(Array(px) .^ 2 .+ Array(py) .^ 2 .+ Array(pz) .^ 2))
            R = dt * pm * F
            eul = run(false, sm, psi, px, py, pz, dt, it)
            tay = run(true, sm, psi, px, py, pz, dt, it)
            relerr = norm(Array(tay) .- Array(eul)) / norm(Array(eul))
            tol = T == Float64 ? 1e-11 : 5e-5
            tag = R > SpinorBEC.SPIN_TAYLOR_RSAFE[] ? "halved" : "direct"
            ok = relerr < tol
            println("  T=$T R=$(round(R,digits=4)) it=$it  $tag  relerr=$relerr  ",
                ok ? "OK" : "*** FAIL ***")
        end
    end
end
SpinorBEC.SPIN_TAYLOR_ENABLED[] = true
println("DONE")
