# Gate for the shared GPU spin-rotation propagator (gpu_spin_rotation_taylor.jl).
#
# Two substeps apply exp(z·(v·F)) per voxel — DDI with v = Φ and spin-mixing
# with v = c₁⟨F⟩ — and both now run the adaptive Taylor–Horner kernel, with the
# Euler 5-stage as the exact fallback. This file pins Taylor ≡ Euler for BOTH,
# across F, dtype, real/imaginary time, and rotation angle R.
#
# Why it is separate from `oracles/test_gpu_cpu_per_term_parity.jl`: that gate
# compares GPU to CPU at F=1 (D=3), which cannot see a defect in the D=13
# warp-lane layout the Taylor kernel uses (one spin component per lane of a
# width-16 subgroup). Production is F=6. It also cannot see a Taylor-degree
# selection that is too aggressive, because CPU and GPU would then agree only
# to the same wrong tolerance — here the reference is the exact Euler kernel
# running on the same device against the same input.

using Test
using LinearAlgebra: norm
import CUDA
using SpinorBEC

if !CUDA.functional()
    @info "CUDA not functional — skipping GPU spin-rotation Taylor parity"
else
    const Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)

    # exp(z·v·F) via each realization, same input.
    function _rotate(taylor::Bool, sm, psi0, vx, vy, vz, dt, it)
        old = Ext._SPIN_TAYLOR_ENABLED[]
        Ext._SPIN_TAYLOR_ENABLED[] = taylor
        try
            p = copy(psi0)
            SpinorBEC._apply_ddi_rotation!(p, vx, vy, vz, sm, dt, 3; imaginary_time=it)
            CUDA.synchronize()
            return p
        finally
            Ext._SPIN_TAYLOR_ENABLED[] = old
        end
    end

    @testset "GPU spin rotation: Taylor ≡ exact Euler" begin
        dt = 0.005
        n = 2048
        for F in (1, 6), T in (Float64, Float32)
            sm = spin_matrices(F)
            D = 2F + 1
            for scale in (1.0, 6.0, 35.0)      # R from ~0.02 up to ~1
                for it in (false, true)
                    psi0 = CUDA.CuArray(randn(Complex{T}, n, 1, 1, D))
                    vx = CUDA.CuArray(T(scale) .* randn(T, n, 1, 1))
                    vy = CUDA.CuArray(T(scale) .* randn(T, n, 1, 1))
                    vz = CUDA.CuArray(T(scale) .* randn(T, n, 1, 1))
                    eul = _rotate(false, sm, psi0, vx, vy, vz, dt, it)
                    tay = _rotate(true, sm, psi0, vx, vy, vz, dt, it)
                    rel = norm(Array(tay) .- Array(eul)) / norm(Array(eul))
                    tol = T === Float64 ? 1e-10 : 5e-5
                    @test rel < tol
                    # The rotation actually moved the state — a no-op kernel
                    # would pass the parity check above trivially.
                    @test norm(Array(eul) .- Array(psi0)) / norm(Array(psi0)) > 1e-6
                end
            end
        end
    end

    # The spin-mixing substep is the one that changed realization; check it
    # end-to-end (spin density → rotation) rather than only the shared kernel.
    @testset "spin-mixing propagator: Taylor ≡ exact Euler (F=6)" begin
        sm = spin_matrices(6)
        D = 13
        n = 12
        psi0 = CUDA.CuArray(randn(ComplexF64, n, n, n, D) ./ 10)
        for it in (false, true), c1 in (0.5, -0.5)
            outs = map((false, true)) do taylor
                old = Ext._SPIN_TAYLOR_ENABLED[]
                Ext._SPIN_TAYLOR_ENABLED[] = taylor
                try
                    p = copy(psi0)
                    apply_spin_mixing_step!(p, sm, c1, 0.01, 3; imaginary_time=it)
                    CUDA.synchronize()
                    Array(p)
                finally
                    Ext._SPIN_TAYLOR_ENABLED[] = old
                end
            end
            @test norm(outs[2] .- outs[1]) / norm(outs[1]) < 1e-10
            @test norm(outs[1] .- Array(psi0)) / norm(Array(psi0)) > 1e-6
        end
    end

    # A rotation is unitary; the Taylor truncation must not leak norm at the
    # production angle. (The imaginary-time arm is deliberately not unitary.)
    @testset "Taylor rotation preserves norm (real time)" begin
        sm = spin_matrices(6)
        psi0 = CUDA.CuArray(randn(ComplexF64, 4096, 1, 1, 13))
        n0 = sum(abs2, psi0)
        v() = CUDA.CuArray(6.0 .* randn(Float64, 4096, 1, 1))
        p = copy(psi0)
        SpinorBEC._apply_ddi_rotation!(p, v(), v(), v(), sm, 0.005, 3)
        CUDA.synchronize()
        @test abs(sum(abs2, p) / n0 - 1) < 1e-12
    end
end
