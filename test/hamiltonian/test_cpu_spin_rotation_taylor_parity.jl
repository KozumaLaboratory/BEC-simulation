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
# CUDA realization. Both read the SAME `SPIN_TAYLOR_TOL`, so relaxing the
# contract turns both red.

using Test
using Random
using LinearAlgebra: norm
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_ENABLED, SPIN_TAYLOR_TOL, SPIN_TAYLOR_RSAFE,
    SPIN_TAYLOR_RK_MAX, _taylor_rot_schedule, _cpu_spin_rk,
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

    # The angle halving has its OWN assertion below (`SPIN_TAYLOR_RSAFE is what
    # halves`), because this sweep does not gate it — see the note there.
    @testset "DDI rotation (F=$F, IT=$it, amp=$amp)" for F in (1, 2, 6),
        it in (false, true), amp in (0.01, 1.0, 30.0)

        sm = spin_matrices(F)
        D = 2F + 1
        rng = MersenneTwister(11 + F + (it ? 3 : 0) + round(Int, 100amp))
        psi0 = randn(rng, ComplexF64, n..., D)
        # `amp` sweeps R = dt·|Φ|·F from deep inside the production range
        # (0.01–0.2) to far past `SPIN_TAYLOR_RSAFE`, where every voxel halves
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

    # `SPIN_TAYLOR_RSAFE` is a `Ref`, not a const. Cutover step 4 on this branch
    # froze it and pinned the bare values here; #307 then measured that the
    # premise for freezing the sibling tolerance was three orders wrong, so
    # origin/main's `Ref` form is what survived the merge and these reads are
    # dereferenced again. The canary for the freeze — set it to 1e30 so no voxel ever halves —
    # left this whole file GREEN. The `amp` sweep above says in its own comment
    # that it goes "far past SPIN_TAYLOR_RSAFE, where every voxel halves"; the
    # voxels do halve, but nothing here DEPENDS on it. Measured: the largest
    # angle the sweep reaches is R = 8.17 (F=6, IT=false, amp=30), where an
    # unhalved degree-40 Horner still has backward error R^40/40! = 3.8e-12,
    # inside the 1e-10 threshold. Pushing to amp = 45 does not fix it either —
    # R only reaches 9.98 and the aggregate rel-norm stays at 1.1e-14, because
    # one bad voxel in 216 is diluted by the norm.
    #
    # So the halving is asserted where it is decided, on the schedule itself.
    # Values are PINNED, not read back from the thing under test: at R = 8.17
    # with rsafe = 1.0 the schedule must halve 4 times and land at R·h = 0.511.
    @testset "SPIN_TAYLOR_RSAFE is what halves" begin
        # Pinned, so this cannot agree with a value that drifted. 1e-15 and not
        # 1e-13: #307 made the tighter value the default after measuring that
        # the tolerance BINDS at production angles (R_max = 1.3e-3…5.4e-2,
        # degrees 5 through 9), which is the same finding that reverted this
        # branch's freeze.
        @test SPIN_TAYLOR_RSAFE[] == 1.0
        @test SPIN_TAYLOR_TOL[] == 1.0e-15
        @test SPIN_TAYLOR_RK_MAX == 40

        dt, F, R = 0.01, 6.0, 8.17
        rk = _cpu_spin_rk(Float64, dt)
        g = (R / (dt * F))^2 * F^2          # g = |v|²F² with |scale|·|v|·F = R
        h, sh, kv = _taylor_rot_schedule(
            g, rk, SPIN_TAYLOR_RK_MAX, SPIN_TAYLOR_TOL[]^2, SPIN_TAYLOR_RSAFE[]^2)
        @test sh == 4                        # it halved, four times
        @test R * h ≈ 0.510625 rtol = 1e-12  # below rsafe, as the branch promises
        @test kv == 13                       # and the degree search terminated
        @test kv < SPIN_TAYLOR_RK_MAX

        # Without halving the same angle needs the whole ceiling and still
        # misses: this is the number the `amp` sweep could not see.
        _, sh0, kv0 = _taylor_rot_schedule(
            g, rk, SPIN_TAYLOR_RK_MAX, SPIN_TAYLOR_TOL[]^2, 1.0e60)
        @test sh0 == 0
        @test kv0 == SPIN_TAYLOR_RK_MAX
    end
end
