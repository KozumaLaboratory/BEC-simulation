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
using SpinorBEC
using SpinorBEC: _grad_lhy!, _lhy_energy, _lhy_V, _lhy_is_active, total_density,
    _c0c1_to_gS

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
    psi = 0.3 .* randn(ComplexF64, m, m, m, _D)
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
