# Gate: the warp-cooperative fused Euler kernels ≡ the one-thread-per-voxel ones.
#
# There are two realizations of the same 5-stage rotation on the device. The
# warp form maps ONE spin component to ONE lane (the spinor lives across lanes,
# in registers) and two voxels share a 32-lane warp via width-16 subgroups; the
# legacy form holds the whole spinor in two `MVector{D}` per thread, which at
# D = 13 spills to local memory. Same math, different data layout, so they must
# agree — and lanes 13-15 / 29-31 of each warp are idle, which is where an
# out-of-range voxel or an odd N can go wrong without anything else noticing.
#
# WHY THIS FILE EXISTS RATHER THAN THE BENCH THAT CLAIMED TO DO IT.
# `bench/verify_euler_warp.jl` (deleted in cutover step 4) flipped
# `_DDI_EULER_WARP[]` and then called `SpinorBEC._apply_ddi_rotation!` — which
# takes the TAYLOR path first for D ≤ 16 and never reaches either Euler kernel.
# Measured with its own shape: `SPIN_TAYLOR_ENABLED = true` gives relerr 0.0 and
# `bitwise-equal = true`, under a tolerance of 1e-11 / 1e-4 that says its author
# expected a real difference. It had been comparing the Taylor kernel against
# itself and printing OK. `_SM_EULER_WARP` had no coverage at all.
#
# The fix is not a tighter tolerance: it is to call the launcher DIRECTLY, which
# is possible now that the switch is a `warp` keyword instead of a module-level
# `Ref`. Nothing ambient is set, so no confound and no leakage into other files.
#
# The expected agreement is BITWISE, not a tolerance. Both kernels apply the
# same five stages in the same order; only the storage differs. `≈` here would
# hide a real reordering, so `==` is the assertion and the relative norm is only
# reported when it fails.

using Test
using Random
using LinearAlgebra: norm
import CUDA
using SpinorBEC
using SpinorBEC: spin_matrices

const Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)

if !CUDA.functional()
    @info "CUDA not functional — skipping GPU euler-warp parity"
else
    @testset "fused Euler: warp kernel ≡ per-voxel kernel" begin
        # D = 13 is the shape that matters: it is Eu F=6, it is where the legacy
        # kernel spills, and it is the width the subgroup layout was built for.
        # N = 4097 puts the last warp's second subgroup out of range; N = 100
        # is smaller than one block.
        @testset "DDI rotation (T=$T, N=$N, IT=$it)" for T in (Float64, Float32),
            N in (4096, 4097, 100), it in (false, true)

            D = 13
            sm = spin_matrices((D - 1) ÷ 2)
            rng = MersenneTwister(1000 + N + (T === Float32 ? 1 : 0) + (it ? 7 : 0))
            psi_h = randn(rng, Complex{T}, N, 1, 1, D)
            px = CUDA.CuArray(randn(rng, T, N))
            py = CUDA.CuArray(randn(rng, T, N))
            pz = CUDA.CuArray(randn(rng, T, N))
            cache = Ext._get_gpu_ddi_rot_cache(CUDA.CuArray(psi_h), sm, 3)

            function run(warp::Bool)
                P = reshape(CUDA.CuArray(psi_h), N, D)
                Ext.apply_ddi_euler_fused_kernel!(
                    P, px, py, pz, cache.m_row, cache.λ_row, cache.V, cache.conj_V,
                    T(0.0025); imaginary_time=it, warp)
                CUDA.synchronize()
                Array(P)
            end
            a, b = run(true), run(false)
            @test a == b
            a == b || @info "DDI warp mismatch" T N it relerr =
                norm(vec(a) .- vec(b)) /
                max(norm(vec(b)), eps(T))
        end

        @testset "spin-mixing rotation (T=$T, N=$N, IT=$it)" for T in (Float64, Float32),
            N in (4096, 4097, 100), it in (false, true)

            D = 13
            sm = spin_matrices((D - 1) ÷ 2)
            rng = MersenneTwister(2000 + N + (T === Float32 ? 1 : 0) + (it ? 7 : 0))
            psi_h = randn(rng, Complex{T}, N, 1, 1, D)
            cache = Ext._get_gpu_sm_cache(CUDA.CuArray(psi_h), sm, 3)
            # α / β / θ are (N,1) angle arrays, exactly the shape the spin-mixing
            # fallback hands the launcher. β ∈ [0, π] and α spans a full turn so
            # no stage's branch is left unexercised.
            #
            # θ's scale is bounded on PURPOSE and the bound is different per time
            # direction. Stage 3 is `cis(-m θ)` in real time (never overflows)
            # but `exp(-m θ)` in imaginary time, with |m| ≤ F = 6 — so θ = ±16,
            # which the first version of this file drew, is exp(96) and OVERFLOWS
            # Float32. That is the instrument, not the kernels: it made this arm
            # fail with relerr = NaN32 while both realizations were computing the
            # same Inf. Production θ = c₁·dt·|⟨F⟩| is ~1e-2; ±0.5 is 50× that and
            # exp(3) at every m.
            α = CUDA.CuArray(reshape(T(2π) .* rand(rng, T, N), N, 1))
            β = CUDA.CuArray(reshape(T(π) .* rand(rng, T, N), N, 1))
            θ_scale = it ? T(0.5) : T(4)
            θ = CUDA.CuArray(reshape(θ_scale .* randn(rng, T, N), N, 1))

            function run(warp::Bool)
                P = reshape(CUDA.CuArray(psi_h), N, D)
                Ext.apply_euler_5stage_fused_kernel!(
                    P, α, β, θ, cache.m_vals, cache.m_shift, cache.λ,
                    cache.V, cache.conj_V; imaginary_time=it, warp)
                CUDA.synchronize()
                Array(P)
            end
            a, b = run(true), run(false)
            @test a == b
            a == b || @info "SM warp mismatch" T N it relerr =
                norm(vec(a) .- vec(b)) /
                max(norm(vec(b)), eps(T))
        end

        # Both arms must actually have moved ψ, or `a == b` is two copies of the
        # input agreeing. The bench this replaces had no such control, which is
        # part of why it could pass while measuring nothing.
        @testset "positive control: the rotation is not a no-op" begin
            D = 13
            N = 4096
            sm = spin_matrices((D - 1) ÷ 2)
            rng = MersenneTwister(31337)
            psi_h = randn(rng, ComplexF64, N, 1, 1, D)
            px = CUDA.CuArray(randn(rng, Float64, N))
            py = CUDA.CuArray(randn(rng, Float64, N))
            pz = CUDA.CuArray(randn(rng, Float64, N))
            cache = Ext._get_gpu_ddi_rot_cache(CUDA.CuArray(psi_h), sm, 3)
            base = reshape(copy(psi_h), N, D)
            for warp in (true, false)
                P = reshape(CUDA.CuArray(psi_h), N, D)
                Ext.apply_ddi_euler_fused_kernel!(
                    P, px, py, pz, cache.m_row, cache.λ_row, cache.V, cache.conj_V,
                    0.0025; imaginary_time=false, warp)
                CUDA.synchronize()
                out = Array(P)
                @test out != base
                @test norm(vec(out) .- vec(base)) / norm(vec(base)) > 1.0e-4
                # Real time is unitary: a warp-layout bug that dropped a lane
                # would show here even if both kernels dropped the same one.
                @test norm(vec(out)) ≈ norm(vec(base)) rtol = 1.0e-12
            end
        end
    end
end
