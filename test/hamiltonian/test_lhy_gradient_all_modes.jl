# Gate: the LBFGS gradient must see whatever LHY the workspace holds.
#
# `_grad_lhy!` read `ws.interactions.c_lhy` only, so every TabulatedLHY produced
# a gradient of EXACTLY ZERO — with no warning, unlike the c2/c4/tensor gaps
# which do warn. Measured for PolarContactLHY against a finite difference of
# `_lhy_energy`: |grad| = 0 against a true 628.9.
#
# The consequence is worse than a wrong number: ITP goes through the propagator
# and had the LHY, LBFGS went through the gradient and did not, so the two
# solvers were minimising different Hamiltonians and LBFGS "converged" happily.
#
# The fix is not a warning. E_LHY = ∫ε(n)dV with V = dε/dn, so δE/δψ̄ = V(n)·ψ —
# the same `_lhy_V` the propagator applies. One function behind all three faces.

using Test
using LinearAlgebra
using Random
using SpinorBEC
using SpinorBEC: _grad_lhy!, _lhy_energy, _lhy_V, _lhy_is_active, total_density,
    _c0c1_to_gS, _lhy_needs_spin, _lhy_de1_dp, _local_polarisation, fp_ladder_coeff

const _F = 6
const _D = 13

_ws(lhy, c_lhy=0.0) =
    (; interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.1)), lhy=lhy)

function _fd_grad(psi, lhy, npts, dV; h=1e-6)
    g = zeros(ComplexF64, size(psi))
    for I in CartesianIndices(size(psi))
        for (dz, w) in ((complex(h), 1.0 + 0im), (complex(0, h), 0.0 + 1.0im))
            p1 = copy(psi)
            p1[I] += dz
            p2 = copy(psi)
            p2[I] -= dz
            E1 = _lhy_energy(p1, lhy, _D, 3, npts, dV)
            E2 = _lhy_energy(p2, lhy, _D, 3, npts, dV)
            g[I] += w * (E1 - E2) / (2h) / 2
        end
    end
    g
end

function _zoo()
    g = _c0c1_to_gS(_F, 10.0, 0.1)
    (
        "PolarContactLHY" => compute_spinor_lhy_polar_contact(;
            F=_F, g_dict=g, n_max=50.0, n_points=2000),
        "FMContactLHY" => compute_spinor_lhy_fm_contact(;
            F=_F, g_dict=_c0c1_to_gS(_F, 10.0, -0.02), n_max=50.0, n_points=2000),
        "IcosahedralLHY" => compute_spinor_lhy_icosahedral(;
            F=_F, g_dict=g, n_max=50.0, n_points=2000),
        "ScalarLHY" => ScalarLHY(0.7),
    )
end

@testset "LBFGS gradient covers every LHY mode" begin
    m = 4
    npts = (m, m, m)
    dV = 1.0
    # Seeded. The `gap` assertion below is a hardcoded window around a measured
    # value, and psi was an UNSEEDED draw, so the window was being tested against
    # a different random state every run: observed 0.0379 against
    # `0.015 < gap < 0.035` in a parallel run that passed standalone. Same class as
    # the test_seed_from.jl flake fixed earlier today — a fitted window on an
    # unseeded quantity is a coin toss, and an unreproducible one.
    psi = 0.3 .* randn(MersenneTwister(20260730), ComplexF64, m, m, m, _D)
    n = total_density(psi, 3)

    @testset "gradient == finite difference of the energy" begin
        # The FD oracle: the gradient face and the energy face of the same term
        # must be derivatives of each other, which is what `_grad_lhy!` silently
        # failed for every table.
        for (label, lhy) in _zoo()
            g = zeros(ComplexF64, size(psi))
            _grad_lhy!(g, psi, _ws(lhy), n, npts, _D, Val(3))
            fd = _fd_grad(psi, lhy, npts, dV)
            @test norm(g) > 1.0                       # not silently zero
            @test maximum(abs.(g .- fd)) < 1e-5 * max(norm(fd), 1.0)
        end
    end

    @testset "gradient == V_LHY(n)·ψ, the potential the propagator applies" begin
        for (label, lhy) in _zoo()
            g = zeros(ComplexF64, size(psi))
            _grad_lhy!(g, psi, _ws(lhy), n, npts, _D, Val(3))
            want = similar(psi)
            for I in CartesianIndices(npts), c in 1:_D
                want[I, c] = _lhy_V(n[I], lhy) * psi[I, c]
            end
            @test maximum(abs.(g .- want)) < 1e-12 * max(maximum(abs.(want)), 1.0)
        end
    end

    @testset "inactive LHY contributes nothing" begin
        for lhy in (NoLHY(), ScalarLHY(0.0), nothing)
            g = zeros(ComplexF64, size(psi))
            _grad_lhy!(g, psi,
                (; interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.1)),
                    lhy=lhy), n, npts, _D, Val(3))
            @test all(iszero, g)
        end
        @test !_lhy_is_active(nothing)
        @test !_lhy_is_active(NoLHY())
        @test !_lhy_is_active(ScalarLHY(0.0))
    end

    @testset "SpatialLHY: the polarisation piece is in the gradient" begin
        # ε = n^(5/2) e₁(p) depends on ψ through p as well as n, so δE/δψ̄ is
        # NOT the diagonal V·ψ. The extra piece is a spin operator, which is
        # exactly why the propagator cannot hold it.
        e1var = 0.20                              # the F=6 variation spatial.jl reports
        pgrid = collect(range(0.0, 1.0; length=9))
        lhy = SpatialLHY(pgrid, [0.5 * (1 - e1var * p^2) for p in pgrid], _F,
            [fp_ladder_coeff(_F, _F - (c - 1)) for c in 1:_D])
        @test _lhy_needs_spin(lhy)
        @test _lhy_is_active(lhy)

        g = zeros(ComplexF64, size(psi))
        _grad_lhy!(g, psi, _ws(lhy), n, npts, _D, Val(3))
        fd = _fd_grad(psi, lhy, npts, dV)
        @test norm(g) > 1.0
        @test norm(g .- fd) / norm(fd) < 1e-7     # measured 8.3e-10

        # The diagonal-only gradient, and by how much it falls short. Since
        # issue #131 the propagator also applies the spin piece
        # (`apply_spatial_lhy_spin_step!`), so this is no longer what the
        # propagator does — it is the measurement that makes that substep's
        # contribution a number rather than an assumption.
        P = reshape(psi, prod(npts), _D)
        fp = ntuple(c -> fp_ladder_coeff(_F, _F - (c - 1)), Val(_D))
        diag = zeros(ComplexF64, prod(npts), _D)
        for i in 1:prod(npts)
            s = sum(abs2, @view P[i, :])
            s < 1e-30 && continue
            v = _lhy_V(s, _local_polarisation(P, i, s, _F, fp, Val(_D)), lhy)
            diag[i, :] .= v .* @view P[i, :]
        end
        gap = norm(reshape(diag, size(psi)) .- fd) / norm(fd)
        @test 0.015 < gap < 0.035                 # measured 0.0233

        # e₁′ is the slope of the SAME interpolant, flat outside the table.
        @test _lhy_de1_dp(lhy, -0.1) == 0.0
        @test _lhy_de1_dp(lhy, 1.5) == 0.0
        @test _lhy_de1_dp(lhy, 0.5) < 0.0         # e₁ decreases with p here

        # A constant e₁ has no polarisation piece: the gradient must collapse
        # onto the diagonal form, so the spin term cannot be adding a bias.
        flat = SpatialLHY(pgrid, fill(0.5, length(pgrid)), _F,
            [fp_ladder_coeff(_F, _F - (c - 1)) for c in 1:_D])
        gf = zeros(ComplexF64, size(psi))
        _grad_lhy!(gf, psi, _ws(flat), n, npts, _D, Val(3))
        want = similar(psi)
        for I in CartesianIndices(npts), c in 1:_D
            want[I, c] = 2.5 * 0.5 * n[I] * sqrt(n[I]) * psi[I, c]
        end
        @test maximum(abs.(gf .- want)) < 1e-12 * maximum(abs.(want))
    end

    @testset "the specific old failure is pinned" begin
        # |grad| was exactly 0 for a table. If that returns, this is the line
        # that says so rather than a subtle tolerance drifting.
        tbl = compute_spinor_lhy_polar_contact(;
            F=_F, g_dict=_c0c1_to_gS(_F, 10.0, 0.1), n_max=50.0, n_points=2000)
        g = zeros(ComplexF64, size(psi))
        _grad_lhy!(g, psi, _ws(tbl), n, npts, _D, Val(3))
        @test norm(g) > 100.0
    end
end
