# A/B correctness: warp-cooperative DDI euler kernel vs the legacy
# one-thread-per-voxel MVector kernel. Same input → outputs must match to
# float-reordering tolerance. Exercises real (cis) + imaginary (exp) time and
# odd N (last warp's second subgroup out of range).
import CUDA
using SpinorBEC
using LinearAlgebra: norm

const Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)

function make_inputs(N, D, ::Type{T}) where {T}
    sm = SpinorBEC.spin_matrices((D - 1) ÷ 2)   # F = (D-1)/2 = 6 for D=13
    # spatial layout (n_pts..., D); use a (N,1,1,D) grid so prod(n_pts)=N
    psi = CUDA.CuArray(randn(Complex{T}, N, 1, 1, D))
    px = CUDA.CuArray(randn(T, N, 1, 1)); py = CUDA.CuArray(randn(T, N, 1, 1)); pz = CUDA.CuArray(randn(T, N, 1, 1))
    sm, psi, px, py, pz
end

function run_variant(warp::Bool, sm, psi, px, py, pz, dt, ndim, it)
    Ext._DDI_EULER_WARP[] = warp
    p = copy(psi)
    SpinorBEC._apply_ddi_rotation!(p, px, py, pz, sm, dt, ndim; imaginary_time=it)
    CUDA.synchronize()
    p
end

println("D=13 (F=6) warp-vs-legacy DDI euler parity")
for T in (Float64, Float32)
    for N in (4096, 4097, 100)          # even, odd (OOB subgroup), tiny
        for it in (false, true)
            sm, psi, px, py, pz = make_inputs(N, 13, T)
            old = run_variant(false, sm, psi, px, py, pz, 0.0025, 3, it)
            new = run_variant(true,  sm, psi, px, py, pz, 0.0025, 3, it)
            d = Array(new) .- Array(old)
            relerr = norm(d) / max(norm(Array(old)), eps(T))
            maxabs = maximum(abs, d)
            tol = T == Float64 ? 1e-11 : 1e-4
            ok = relerr < tol
            println("  T=$T N=$N it=$it  relerr=$(relerr)  maxabs=$(maxabs)  ", ok ? "OK" : "*** FAIL ***")
        end
    end
end
Ext._DDI_EULER_WARP[] = true
println("DONE")
