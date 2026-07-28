# Micro-benchmark for the Taylor-Horner spin-rotation kernel.
#
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. bench/micro_spin_taylor.jl [N] [D]
#
# The kernel is 79 % of GPU-busy time in an RTP step (bench/profile_rtp.jl), so
# its cost model decides what to optimize. Two regimes are possible and they
# want opposite fixes:
#
#   memory-bound  → time flat in K, fix the uncoalesced (N,D) column reads
#   compute-bound → time linear in K, fix the FP64 op count in the Horner body
#
# This sweeps K explicitly so the regime is measured, not assumed, on whatever
# card is present (consumer FP64 is 1/64-rate; H100 is 1/2).

import CUDA
using SpinorBEC
using Printf

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 64
const D_COMP = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 13

const EXT = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)

# `profile=:flat`  — |v| uniform over the box (worst case for a per-voxel degree)
# `profile=:cloud` — |v| ∝ a Gaussian of 1/4 the box width, i.e. what a trapped
#                    cloud actually presents: peak at the centre, ~0 in the tails
function setup(; n=N_GRID, D=D_COMP, T=Float64, profile=:flat)
    F = (D - 1) ÷ 2
    sm = spin_matrices(F)
    Ns = n^3
    psi = CUDA.rand(Complex{T}, Ns, D)
    if profile === :flat
        vx, vy, vz = CUDA.rand(T, Ns), CUDA.rand(T, Ns), CUDA.rand(T, Ns)
    else
        ax = range(-T(2), T(2); length=n)
        env = [exp(-(ax[i]^2 + ax[j]^2 + ax[k]^2)) for i in 1:n, j in 1:n, k in 1:n]
        e = CUDA.CuArray(reshape(env, Ns))
        vx, vy, vz = e .* CUDA.rand(T, Ns), e .* CUDA.rand(T, Ns), e .* CUDA.rand(T, Ns)
    end
    coef = EXT._get_spin_tridiag_coef(psi, sm)
    (; psi, vx, vy, vz, coef, sm, Ns, D, F=T(F))
end

"min-of-`samples` ms for one kernel launch."
function time_ms(f; samples=20)
    f();
    CUDA.synchronize()
    best = Inf
    for _ in 1:samples
        CUDA.synchronize()
        t0 = time_ns()
        f()
        CUDA.synchronize()
        best = min(best, (time_ns() - t0) * 1e-6)
    end
    best
end

function main()
    dev = CUDA.device()
    @printf("micro spin-taylor — %s, %d^3 × D=%d, Float64, field=%s\n",
        CUDA.name(dev), N_GRID, D_COMP, get(ARGS, 3, "flat"))
    s = setup(; profile=Symbol(get(ARGS, 3, "flat")))
    scale = 1.0e-3
    bytes = 2 * s.Ns * s.D * 16          # ψ read + write
    @printf("  ψ = %.1f MB, one read+write = %.1f MB\n",
        s.Ns * s.D * 16 / 2^20, bytes / 2^20)
    @printf("\n  %4s %10s %10s %12s\n", "K", "ms", "GB/s", "ns/(vox·K)")
    prev = 0.0
    for K in (1, 2, 3, 4, 6, 8, 12, 16, 24)
        t = time_ms(() -> EXT._apply_spin_rotation_taylor!(
            s.psi, s.vx, s.vy, s.vz, s.coef, scale, Val(D_COMP); F=s.F))
        @printf("  %4d %10.3f %10.1f %12.4f\n",
            K, t, bytes / (t * 1e-3) / 2^30, 1e6 * t / (s.Ns * K))
        prev = t
    end
    println("\n  same kernel with ψ staged through shared memory (coalesced):")
    EXT.SPIN_STAGE_SHARED[] = true
    ts = time_ms(() -> EXT._apply_spin_rotation_taylor!(
        s.psi, s.vx, s.vy, s.vz, s.coef, scale, Val(D_COMP); F=s.F))
    EXT.SPIN_STAGE_SHARED[] = false
    td = time_ms(() -> EXT._apply_spin_rotation_taylor!(
        s.psi, s.vx, s.vy, s.vz, s.coef, scale, Val(D_COMP); F=s.F))
    @printf("    direct %7.3f ms (%6.1f GB/s)   staged %7.3f ms (%6.1f GB/s)   %.2fx\n",
        td, bytes / (td * 1e-3) / 2^30, ts, bytes / (ts * 1e-3) / 2^30, td / ts)

    println("\n  slope between K=4 and K=16 tells the regime:")
    t4 = time_ms(() -> EXT._apply_spin_rotation_taylor!(
        s.psi, s.vx, s.vy, s.vz, s.coef, scale, Val(D_COMP); F=s.F))
    t16 = time_ms(() -> EXT._apply_spin_rotation_taylor!(
        s.psi, s.vx, s.vy, s.vz, s.coef, scale, Val(D_COMP); F=s.F))
    @printf("    t(16)/t(4) = %.2f   (1.0 = memory-bound, 4.0 = pure compute)\n", t16 / t4)
    @printf("    extrapolated K=0 intercept = %.3f ms → %.1f GB/s ceiling\n",
        t4 - (t16 - t4) / 12 * 4, bytes / ((t4 - (t16 - t4) / 12 * 4) * 1e-3) / 2^30)
end

main()
