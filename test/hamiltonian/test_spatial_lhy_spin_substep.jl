# Gate: the SpatialLHY propagator now carries the polarisation term (issue #131).
#
# `ε = n^(5/2) e₁(p)` depends on ψ through p = |⟨F⟩|/F as well as through n, so
#
#     δε/δψ̄ = (5/2)n^(3/2)e₁(p)·ψ  +  c[(ŝ·F)ψ/F − p·ψ],   c = n^(3/2)e₁′(p)
#
# The diagonal step applies the first term. The second is a SPIN operator, and
# the propagator simply omitted it — a measured 2.3 % of the gradient norm —
# while the LBFGS gradient carried it in full. ITP and LBFGS were therefore
# minimising different functionals for this one mode.
#
# `apply_spatial_lhy_spin_step!` closes it, as a rotation:
#
#     A = (c/F)(ŝ·F) − c·p,   exp(−dt·A) = exp(+dt·c·p)·exp(−dt·(φ·F)),
#     φ = (c/F)·ŝ
#
# The decisive check is not that the substep is self-consistent but that the
# propagator and the gradient now agree: one imaginary-time step of the FULL
# LHY (diagonal + this substep) must move ψ along −δE/δψ̄.

using Test
using LinearAlgebra: norm
using Random
using SpinorBEC
using SpinorBEC: apply_spatial_lhy_spin_step!, _lhy_de1_dp, _lhy_V, _grad_lhy!,
    _lhy_needs_spin, fp_ladder_coeff, _local_polarisation, total_density

const _F = 2
const _D = 5

function _lhy(; var=0.20)
    ps = collect(range(0.0, 1.0; length=9))
    SpatialLHY(ps, [0.5 * (1 - var * p^2) for p in ps], _F,
        [fp_ladder_coeff(_F, _F - (c - 1)) for c in 1:_D])
end

_ws(l) = (; interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.1)), lhy=l)

# The full local LHY operator applied for a time dt: diagonal V_LHY plus the
# spin substep. This is what the propagator does, assembled here directly so
# the test does not depend on the whole split-step sandwich.
function _full_lhy_step(psi, lhy, sm, dt, imaginary_time)
    q = copy(psi)
    mf = copy(psi)
    n_pts = size(psi)[1:3]
    Ns = prod(n_pts)
    P = reshape(mf, Ns, _D)
    fp = ntuple(c -> lhy.fp_coeffs[c], Val(_D))
    Q = reshape(q, Ns, _D)
    for i in 1:Ns
        s = sum(abs2, @view P[i, :])
        s < 1e-30 && continue
        p = _local_polarisation(P, i, s, lhy.F, fp, Val(_D))
        v = _lhy_V(s, p, lhy)
        f = imaginary_time ? exp(-v * dt) : cis(-v * dt)
        for c in 1:_D
            Q[i, c] *= f
        end
    end
    apply_spatial_lhy_spin_step!(q, lhy, sm, dt, 3; imaginary_time, psi_mf=mf)
    q
end

@testset "SpatialLHY propagator carries the polarisation term" begin
    sm = spin_matrices(_F)
    Random.seed!(20260728)
    psi = 0.5 .* randn(ComplexF64, 3, 3, 3, _D)
    lhy = _lhy()

    @testset "the substep alone == exp(-dt A), both time directions" begin
        # Pinned against an explicit matrix exponential of the operator it
        # claims to be, so the rotation identity cannot silently rot.
        Ns = 27
        P = reshape(psi, Ns, _D)
        i = 1
        nn = sum(abs2, @view P[i, :])
        szl = sum((_F - (c - 1)) * abs2(P[i, c]) for c in 1:_D)
        sp = sum(lhy.fp_coeffs[c] * conj(P[i, c - 1]) * P[i, c] for c in 2:_D)
        smag = sqrt(abs2(sp) + szl^2)
        p = smag / (nn * _F)
        cc = nn * sqrt(nn) * _lhy_de1_dp(lhy, clamp(p, 0.0, 1.0))
        @test cc != 0.0
        sh = [real(sp), imag(sp), szl] ./ smag
        A =
            (cc / _F) * (sh[1] * Matrix(sm.Fx) + sh[2] * Matrix(sm.Fy) +
                         sh[3] * Matrix(sm.Fz)) - cc * p * Matrix(one(sm.Fz))

        for it in (false, true)
            q = copy(psi)
            apply_spatial_lhy_spin_step!(q, lhy, sm, 0.03, 3;
                imaginary_time=it, psi_mf=copy(psi))
            U = it ? exp(-0.03 * A) : exp(-im * 0.03 * A)
            want = U * [psi[1, 1, 1, c] for c in 1:_D]
            got = [q[1, 1, 1, c] for c in 1:_D]
            @test maximum(abs.(got .- want)) < 1e-13
        end
    end

    @testset "propagator now agrees with the gradient" begin
        # THE point of #131. One imaginary-time step of the full LHY moves psi
        # along -dE/dpsibar; before the substep existed this was 2.3% off.
        dt = 1e-6
        q = _full_lhy_step(psi, lhy, sm, dt, true)
        moved = (psi .- q) ./ dt                       # ≈ δE/δψ̄
        g = zeros(ComplexF64, size(psi))
        _grad_lhy!(g, psi, _ws(lhy), total_density(psi, 3), size(psi)[1:3], _D, Val(3))
        @test norm(g) > 1e-6
        @test norm(moved .- g) / norm(g) < 1e-4        # dt-limited, not systematic
    end

    @testset "the diagonal step ALONE is 2.3% short — the gap #131 closed" begin
        # Same comparison with the substep removed. Pins that the term being
        # added is real and of the measured size, so a no-op substep cannot
        # pass the test above by accident.
        dt = 1e-6
        Ns = 27
        q = copy(psi)
        P = reshape(psi, Ns, _D)
        Q = reshape(q, Ns, _D)
        fp = ntuple(c -> lhy.fp_coeffs[c], Val(_D))
        for i in 1:Ns
            s = sum(abs2, @view P[i, :])
            s < 1e-30 && continue
            v = _lhy_V(s, _local_polarisation(P, i, s, lhy.F, fp, Val(_D)), lhy)
            for c in 1:_D
                Q[i, c] *= exp(-v * dt)
            end
        end
        moved = (psi .- q) ./ dt
        g = zeros(ComplexF64, size(psi))
        _grad_lhy!(g, psi, _ws(lhy), total_density(psi, 3), size(psi)[1:3], _D, Val(3))
        gap = norm(moved .- g) / norm(g)
        @test 0.01 < gap < 0.05
    end

    @testset "real time is norm-preserving" begin
        # A is Hermitian, so the real-time step must be unitary. Catches a
        # dropped conjugate or a sign flip in the scalar half, which the
        # imaginary-time comparison above is much less sensitive to.
        q = _full_lhy_step(psi, lhy, sm, 0.05, false)
        @test isapprox(sum(abs2, q), sum(abs2, psi); rtol=1e-12)
    end

    @testset "flat e1 makes the substep an exact no-op" begin
        # e₁′ ≡ 0 ⇒ no polarisation force. Guards against the substep adding a
        # spurious rotation on states it should not touch.
        flat = SpatialLHY(collect(range(0.0, 1.0; length=9)), fill(0.5, 9), _F,
            [fp_ladder_coeff(_F, _F - (c - 1)) for c in 1:_D])
        for it in (false, true)
            q = copy(psi)
            apply_spatial_lhy_spin_step!(q, flat, sm, 0.05, 3;
                imaginary_time=it, psi_mf=copy(psi))
            @test q == psi
        end
    end

    @testset "non-spatial LHY never pays for it" begin
        @test !_lhy_needs_spin(ScalarLHY(0.5))
        @test !_lhy_needs_spin(NoLHY())
        @test _lhy_needs_spin(lhy)
        q = copy(psi)
        apply_spatial_lhy_spin_step!(q, ScalarLHY(0.5), sm, 0.05, 3)
        @test q == psi
    end
end
