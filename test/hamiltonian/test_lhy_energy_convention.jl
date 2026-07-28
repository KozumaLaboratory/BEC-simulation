# Gate: E_LHY = ∫ ε(n) dV, and the tables store V = dε/dn.
#
# The tabulated reduction was `n·V(n)`. Every one of these tables has
# ε ∝ n^(5/2), for which `n·V = (5/2)ε`, so the reported LHY energy was exactly
# 2.5× too large for polar_contact / fm_contact / icosahedral / polar_dipolar /
# fm_dipolar / polar_two_channel / full_bdg. Measured ratio against the closed
# form on a uniform cloud: 2.500002.
#
# The tables were never wrong — `∫₀ⁿ V dn'` reproduces the closed-form ε to
# 6.8e-5 — and the propagator was unaffected, since it uses V directly. Only
# this reduction was, which is why it survived: the dynamics were right and the
# number printed next to them was not.
#
# The scalar branch was always correct (`(2/5)c∫n^(5/2)`), which is what makes
# the comparison below an oracle rather than a self-check.

using Test
using SpinorBEC
using SpinorBEC: _lhy_energy, _lhy_V, lhy_energy_polar, build_polar_lhy_coefs,
    lhy_energy_fm, build_fm_lhy_coefs, _c0c1_to_gS

const _F = 6
const _D = 13

_uniform_cloud(n0, m=4) = (p=zeros(ComplexF64, m, m, m, _D);
    p[:, :, :, 1].=sqrt(n0); p)

@testset "LHY energy convention: E = ∫ε, not ∫nV" begin
    @testset "tabulated == its own closed form on a uniform cloud" begin
        # Independent truth: the analytic ε from paper #1 / #2, integrated by
        # hand over a constant-density cloud.
        cases = (
            ("polar", _c0c1_to_gS(_F, 10.0, 0.1),
                g -> compute_spinor_lhy_polar_contact(; F=_F, g_dict=g, n_max=20.0,
                    n_points=4000),
                (g, n) -> lhy_energy_polar(n, build_polar_lhy_coefs(_F, g))),
            ("fm", _c0c1_to_gS(_F, 10.0, -0.02),
                g -> compute_spinor_lhy_fm_contact(; F=_F, g_dict=g, n_max=20.0,
                    n_points=4000),
                (g, n) -> lhy_energy_fm(n, build_fm_lhy_coefs(_F, g))),
        )
        for (label, g, mk, exact) in cases, n0 in (0.5, 2.0, 5.0)
            tbl = mk(g)
            m = 4
            dV = 0.5
            E = _lhy_energy(_uniform_cloud(n0, m), tbl, _D, 3, (m, m, m), dV)
            @test E ≈ exact(g, n0) * m^3 * dV rtol = 1e-3
        end
    end

    @testset "tabulated == scalar when the physics is the same" begin
        # Uniform g_S makes the polar closed form reduce exactly to scalar
        # Lima-Pelster. The scalar branch's energy was always right, so this
        # pins the tabulated one against an independently-written formula.
        g0 = 10.0
        g = Dict(S => g0 for S in 0:2:(2 * _F))
        tbl = compute_spinor_lhy_polar_contact(; F=_F, g_dict=g, n_max=20.0,
            n_points=4000)
        sca = ScalarLHY(2.5 * 8 / (15 * π^2) * g0^2.5)
        for n in (0.5, 1.0, 4.0)
            @test _lhy_V(n, tbl) ≈ _lhy_V(n, sca) rtol = 1e-4
        end
        for n0 in (0.5, 2.0)
            psi = _uniform_cloud(n0)
            Et = _lhy_energy(psi, tbl, _D, 3, (4, 4, 4), 0.5)
            Es = _lhy_energy(psi, sca, _D, 3, (4, 4, 4), 0.5)
            @test Et ≈ Es rtol = 1e-3
            # the specific wrong answer, pinned so it cannot come back
            @test !isapprox(Et, 2.5 * Es; rtol=0.1)
        end
    end

    @testset "energy is the integral of the potential the propagator uses" begin
        # dE/dn must be V — otherwise the term the propagator applies and the
        # energy reported for it are different physics.
        tbl = compute_spinor_lhy_polar_contact(; F=_F, g_dict=_c0c1_to_gS(_F, 10.0, 0.1),
            n_max=20.0, n_points=4000)
        m = 4
        dV = 1.0
        h = 1e-4
        for n0 in (0.7, 2.0, 4.0)
            Ep = _lhy_energy(_uniform_cloud(n0 + h, m), tbl, _D, 3, (m, m, m), dV)
            Em = _lhy_energy(_uniform_cloud(n0 - h, m), tbl, _D, 3, (m, m, m), dV)
            dEdn = (Ep - Em) / (2h) / (m^3 * dV)
            @test dEdn ≈ _lhy_V(n0, tbl) rtol = 1e-3
        end
    end

    @testset "an empty cloud costs nothing" begin
        tbl = compute_spinor_lhy_polar_contact(; F=_F, g_dict=_c0c1_to_gS(_F, 10.0, 0.1),
            n_max=20.0, n_points=200)
        @test _lhy_energy(zeros(ComplexF64, 4, 4, 4, _D), tbl, _D, 3, (4, 4, 4), 1.0) ==
            0.0
    end
end
