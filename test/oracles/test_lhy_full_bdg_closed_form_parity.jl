# Oracle: the general-spinor BdG zero-point integral (`full_bdg`) must
# reproduce EVERY closed form that covers its ansatz.
#
# The two sides are independent statements of the same physics:
#   - closed forms  — analytic per-mode (ξ_m, κ_m) from Clebsch-Gordan
#     tables, k-integral done on paper into φ₁^reg;
#   - full_bdg      — numerical diagonalisation of the coupled 2D × 2D
#     BdG matrix, k-integral done by quadrature.
# Nothing is shared between them but the prefactor. That makes this a
# genuine oracle rather than a self-comparison.
#
# Anchor for the renormalisation: Uchino-Kobayashi-Ueda, PRA 81, 063632
# (2010) [arXiv:0912.0355] Eqs. (16)-(19).
#
# The gate this file exists for: the pre-2026-07 implementation folded
# ε_k into its per-branch UV asymptote and then subtracted ε_k a second
# time, so the integrand tended to −ε_k/2 and the "LHY energy" diverged
# as k_max⁵ at EVERY F and EVERY phase. It survived because no test ever
# compared full_bdg to a closed form, and the only guard in place warned
# about F=6 polar specifically — a case that is not special at all.

using Test
using SpinorBEC
using SpinorBEC: _lhy_bdg_energy_density, _lhy_V,
    lhy_energy_polar, lhy_energy_fm, build_polar_lhy_coefs, build_fm_lhy_coefs,
    _c0c1_to_gS

const _KMAX = 60.0
const _NK = 300
const _RTOL = 2e-3   # quadrature + φ₁^reg spline, not method error (~1e-4 typ.)

_polar_spinor(F) = ComplexF64[c == F + 1 ? 1.0 : 0.0 for c in 1:(2F + 1)]
_fm_spinor(F) = ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:(2F + 1)]

function _bdg_eps(spinor, F, c0, c1; n0=1.0, k_max=_KMAX, n_k=_NK)
    _lhy_bdg_energy_density(spinor, n0, F, InteractionParams(Dict(0 => c0, 1 => c1)),
        ZeemanParams(), 0.0, k_max, n_k, 1)
end

@testset "full_bdg LHY ↔ closed-form parity" begin
    @testset "polar: full_bdg == polar_contact (F = 1, 2, 6)" begin
        # c1 > 0 keeps the polar state mean-field stable; c1 magnitudes are
        # capped so every g_S stays positive at F = 6.
        for (F, c1) in ((1, 0.1), (1, 0.5), (1, 2.0), (2, 0.1), (2, 0.5), (6, 0.1))
            g = _c0c1_to_gS(F, 10.0, c1)
            @test all(>(0), values(g))
            closed = lhy_energy_polar(1.0, build_polar_lhy_coefs(F, g))
            @test _bdg_eps(_polar_spinor(F), F, 10.0, c1) ≈ closed rtol = _RTOL
        end
    end

    @testset "FM: full_bdg == fm_contact (F = 6)" begin
        # c1 < 0 is the FM-stable side. c1 > 0 additionally exercises the
        # NEGATIVE-ENERGY branch: the magnon sits below zero there, and
        # selecting branches by |Re ω| instead of by symplectic norm gets
        # this wrong by 28% (c1 = 0.1) to 89% (c1 = 0.2).
        for c1 in (-0.2, -0.1, -0.05, 0.1, 0.2)
            g = _c0c1_to_gS(6, 10.0, c1)
            @test all(>(0), values(g))
            closed = lhy_energy_fm(1.0, build_fm_lhy_coefs(6, g))
            @test _bdg_eps(_fm_spinor(6), 6, 10.0, c1) ≈ closed rtol = _RTOL
        end
    end

    @testset "scalar limit: uniform g_S ⇒ (8/15π²)(g n)^(5/2)" begin
        for (F, g0) in ((1, 10.0), (2, 4.0), (6, 10.0))
            closed = 8 / (15π^2) * g0^2.5
            @test _bdg_eps(_fm_spinor(F), F, g0, 0.0) ≈ closed rtol = _RTOL
        end
    end

    @testset "k_max convergence (the divergence gate)" begin
        # The old implementation grew as k_max⁵ here: −11568 → −384483 →
        # −1.24e7 for k_max = 20 → 40 → 80. Assert the value is stationary
        # in k_max instead of merely finite.
        sp = _polar_spinor(6)
        v = [_bdg_eps(sp, 6, 10.0, 0.1; k_max=km, n_k=300) for km in (30.0, 60.0, 120.0)]
        @test all(isfinite, v)
        @test abs(v[2] - v[1]) / abs(v[2]) < 1e-3
        @test abs(v[3] - v[2]) / abs(v[3]) < 1e-3
    end

    @testset "n^(5/2) scaling is exact at degenerate Zeeman" begin
        # With all Zeeman energies equal, C and B are exactly ∝ n, so
        # ω(k; n) = n·ω(k/√n; 1) and ε_LHY(n) = n^(5/2) ε_LHY(1). The
        # cutoff has to be carried along by the same substitution — at a
        # FIXED k_max the truncation error is n-dependent (1e-3 at n = 5),
        # which is precisely why `compute_spinor_lhy_table` integrates once
        # and scales rather than integrating per density point.
        sp = _polar_spinor(6)
        e1 = _bdg_eps(sp, 6, 10.0, 0.1; n0=1.0)
        for n in (0.25, 2.0, 5.0)
            scaled = _bdg_eps(sp, 6, 10.0, 0.1; n0=n, k_max=_KMAX * sqrt(n))
            @test scaled ≈ e1 * n^2.5 rtol = 1e-8
        end
    end

    @testset "tabulated V_LHY == d/dn of the closed form" begin
        F, c1 = 6, 0.1
        g = _c0c1_to_gS(F, 10.0, c1)
        eps_1 = lhy_energy_polar(1.0, build_polar_lhy_coefs(F, g))
        tbl = compute_spinor_lhy_table(;
            spinor=_polar_spinor(F), F,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => c1)),
            n_max=4.0, n_points=200, k_max=_KMAX, n_k=_NK,
        )
        @test tbl isa FullBdGLHY
        for n in (0.5, 1.0, 2.0)
            @test _lhy_V(n, tbl) ≈ 2.5 * eps_1 * n^1.5 rtol = _RTOL
        end
    end

    @testset "dynamically unstable mean field warns" begin
        # Polar at c1 < 0: the spin modes go complex (max Im ω ≈ 1.4 at
        # F = 2). The zero-point sum drops those branches while the trace
        # counterterms still subtract all D — scheme-dependent, so say so.
        @test_logs (:warn, r"dynamically unstable") match_mode = :any begin
            _bdg_eps(_polar_spinor(2), 2, 10.0, -0.5; n_k=60)
        end
    end
end
