# Gate for the CPU Taylor–Horner spin rotation.
#
# Two substeps apply `exp(z·(v·F))` per voxel — DDI with v = Φ and spin-mixing
# with v = c₁⟨F⟩ — and both now take the Taylor kernel, with the exact Euler
# 5-stage as the reference. This file pins Taylor ≡ Euler for BOTH, across F,
# real/imaginary time and rotation angle R.
#
# The reference is the EXACT realization running on the same device against the
# same input, which is what makes this an oracle rather than a self-check: a
# Taylor degree chosen too aggressively shows up here and nowhere else. A
# CPU↔GPU comparison could not see it, because the two would agree to the same
# wrong tolerance.
#
# `test/gpu/test_gpu_spin_rotation_taylor_parity.jl` is the same gate for the
# CUDA realization. Both read the SAME `SPIN_TAYLOR_TOL[]`, so relaxing the
# contract turns both red.

using Test
using Random
using LinearAlgebra: norm
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_ENABLED, SPIN_TAYLOR_TOL, SPIN_TAYLOR_RSAFE,
    _apply_ddi_rotation!, apply_spin_mixing_step!, spin_matrices

# Run `f` with the Taylor path forced on/off, restoring the flag afterwards.
function _with_taylor(f, on::Bool)
    old = SPIN_TAYLOR_ENABLED[]
    SPIN_TAYLOR_ENABLED[] = on
    try
        f()
    finally
        SPIN_TAYLOR_ENABLED[] = old
    end
end

_relerr(a, b) = norm(vec(a) .- vec(b)) / max(norm(vec(b)), eps())

@testset "CPU spin rotation: Taylor ≡ exact Euler" begin
    n = (6, 6, 6)
    Ns = prod(n)

    @testset "DDI rotation (F=$F, IT=$it, amp=$amp)" for F in (1, 2, 6),
        it in (false, true), amp in (0.01, 1.0, 30.0)

        sm = spin_matrices(F)
        D = 2F + 1
        rng = MersenneTwister(11 + F + (it ? 3 : 0) + round(Int, 100amp))
        psi0 = randn(rng, ComplexF64, n..., D)
        # `amp` sweeps R = dt·|Φ|·F from deep inside the production range
        # (0.01–0.2) to far past `SPIN_TAYLOR_RSAFE[]`, where every voxel halves
        # its angle and applies it repeatedly.
        px = amp .* randn(rng, Float64, n...)
        py = amp .* randn(rng, Float64, n...)
        pz = amp .* randn(rng, Float64, n...)
        dt = 0.01

        a = _with_taylor(true) do
            p = copy(psi0)
            _apply_ddi_rotation!(p, px, py, pz, sm, dt, 3; imaginary_time=it)
            p
        end
        b = _with_taylor(false) do
            p = copy(psi0)
            _apply_ddi_rotation!(p, px, py, pz, sm, dt, 3; imaginary_time=it)
            p
        end
        # The Taylor degree targets a BACKWARD error of SPIN_TAYLOR_TOL on the
        # rotation; allow a modest multiple for the accumulated forward error.
        @test _relerr(a, b) < 1e-10
    end

    @testset "spin-mixing (F=$F, IT=$it)" for F in (2, 6), it in (false, true)
        sm = spin_matrices(F)
        D = 2F + 1
        rng = MersenneTwister(77 + F + (it ? 5 : 0))
        psi0 = randn(rng, ComplexF64, n..., D)
        c1, dt = 0.7, 0.02

        a = _with_taylor(true) do
            p = copy(psi0)
            apply_spin_mixing_step!(p, sm, c1, dt, 3; imaginary_time=it)
            p
        end
        b = _with_taylor(false) do
            p = copy(psi0)
            apply_spin_mixing_step!(p, sm, c1, dt, 3; imaginary_time=it)
            p
        end
        @test _relerr(a, b) < 1e-10
    end

    # Real time is UNITARY: the rotation must preserve the norm to machine
    # precision. This is the property a wrong Horner coefficient or a
    # mis-signed band breaks first, and it needs no reference to check.
    @testset "real-time rotation preserves norm (F=$F)" for F in (1, 6)
        sm = spin_matrices(F)
        D = 2F + 1
        rng = MersenneTwister(303 + F)
        psi = randn(rng, ComplexF64, n..., D)
        n0 = norm(vec(psi))
        px = randn(rng, Float64, n...)
        py = randn(rng, Float64, n...)
        pz = randn(rng, Float64, n...)
        _with_taylor(true) do
            for _ in 1:20
                _apply_ddi_rotation!(psi, px, py, pz, sm, 0.01, 3; imaginary_time=false)
            end
        end
        @test norm(vec(psi)) ≈ n0 rtol = 1e-13
    end

    # The per-voxel stack buffers must not reach the heap: at D = 13 an
    # `MVector` that escapes is 208 B × N_spatial × 6 rotations per step, which
    # would hand back the traffic this kernel exists to save.
    @testset "kernel does not allocate per voxel" begin
        sm = spin_matrices(6)
        D = 13
        rng = MersenneTwister(5)
        psi = randn(rng, ComplexF64, n..., D)
        px = randn(rng, Float64, n...)
        py = randn(rng, Float64, n...)
        pz = randn(rng, Float64, n...)
        _with_taylor(true) do
            _apply_ddi_rotation!(psi, px, py, pz, sm, 0.01, 3; imaginary_time=true)  # warm
            bytes = @allocated _apply_ddi_rotation!(
                psi, px, py, pz, sm, 0.01, 3; imaginary_time=true)
            # A per-voxel heap MVector would be ≥ 3·208·216 B ≈ 130 KB here;
            # the threading itself costs a small fixed amount.
            @test bytes < 20_000
        end
    end
end
