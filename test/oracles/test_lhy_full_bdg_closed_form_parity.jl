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
using LinearAlgebra
using SpinorBEC
using SpinorBEC: _lhy_bdg_energy_density, _lhy_V, _lhy_quadrature,
    _bdg_branch_sum, _bdg_hessian_posdef, _lhy_bdg_stiffness, _bdg_contact_matrices,
    spin_matrices,
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

    @testset "rtol is a contract, not a hint" begin
        # k_max / n_k are DERIVED from rtol and then rtol is enforced by
        # measuring truncation (an outer-panel doubling), so the delivered
        # error has to land inside the request — across couplings, not just
        # at the point the starting-cutoff formula was calibrated on.
        for (F, sp, c1, closed) in (
            (6, _fm_spinor(6), -0.02, g -> lhy_energy_fm(1.0, build_fm_lhy_coefs(6, g))),
            (6, _polar_spinor(6), 0.1, g -> lhy_energy_polar(1.0, build_polar_lhy_coefs(6, g))),
            (2, _polar_spinor(2), 0.5, g -> lhy_energy_polar(1.0, build_polar_lhy_coefs(2, g))),
        )
            for c0 in (10.0, 100.0)
                g = _c0c1_to_gS(F, c0, c1 * c0 / 10)
                all(>(0), values(g)) || continue
                ip = InteractionParams(Dict(0 => c0, 1 => c1 * c0 / 10))
                exact = closed(g)
                for rt in (1e-3, 1e-4, 1e-5)
                    v = _lhy_bdg_energy_density(sp, 1.0, F, ip, ZeemanParams(),
                        0.0, nothing, nothing, 1; rtol=rt)
                    @test abs(v - exact) / exact <= rt
                end
            end
        end
    end

    @testset "derived cutoff scales with the stiffness, not absolutely" begin
        # The dimensionless range k_max / k_scale must depend on rtol ALONE —
        # that invariance is what lets one rtol serve every coupling. A fixed
        # k_max cannot, and the old default silently degraded as c0 grew.
        for rt in (1e-3, 1e-4, 1e-5)
            x = map((1.0, 4.5, 14.0)) do ks
                km, _ = _lhy_quadrature(rt, ks, nothing, nothing)
                km / ks
            end
            @test all(≈(x[1]; rtol=1e-12), x)
        end
        # tighter rtol ⇒ larger cutoff, monotonically
        ks = 4.5
        kms = [_lhy_quadrature(rt, ks, nothing, nothing)[1] for rt in (1e-2, 1e-3, 1e-4, 1e-5)]
        @test issorted(kms)
        # explicit pins pass straight through
        @test _lhy_quadrature(1e-4, ks, 123.0, 77) == (123.0, 77)
    end

    @testset "a pinned k_max is honoured, not silently refined" begin
        # Convergence studies and this file's own k_max gate depend on it: if
        # refinement ran anyway, a pinned k_max = 20 would come back far more
        # accurate than k_max = 20 can be, and no cutoff study would mean
        # anything. Independently, refining past a pinned large cutoff walks
        # into the round-off cliff.
        F, c1 = 6, -0.02
        g = _c0c1_to_gS(F, 10.0, c1)
        exact = lhy_energy_fm(1.0, build_fm_lhy_coefs(F, g))
        ip = InteractionParams(Dict(0 => 10.0, 1 => c1))
        v20 = _lhy_bdg_energy_density(_fm_spinor(F), 1.0, F, ip, ZeemanParams(),
            0.0, 20.0, 200, 1; rtol=1e-6)
        @test abs(v20 - exact) / exact > 1e-3      # k_max=20 cannot do better
        @test isapprox(abs(v20 - exact) / exact, 2.7e-3; rtol=0.2)
    end

    @testset "positive-definite fast path agrees with norm selection" begin
        # When the Bogoliubov Hessian is positive definite the branch sum skips
        # the eigenvectors. The two routes must be the same number, or the
        # optimisation is a silent physics change.
        F = 6
        D = 2F + 1
        for (sp, c1) in ((_polar_spinor(F), 0.1), (_fm_spinor(F), -0.02))
            ip = InteractionParams(Dict(0 => 10.0, 1 => c1))
            h, M, zee, _ = _bdg_contact_matrices(sp, F, ip, ZeemanParams())
            C, B, _ = _lhy_bdg_stiffness(h, M, zee, sp, 1.0, F, 0.0, nothing,
                [0.0, 0.0, 1.0])
            for ek in (0.5, 2.0, 20.0, 200.0)
                A = copy(C)
                for i in 1:D
                    A[i, i] += ek
                end
                @test _bdg_hessian_posdef(A, B, D)      # PD in this regime
                fast, _ = _bdg_branch_sum(C, B, ek, D)
                # reference: explicit positive-symplectic-norm selection
                H = zeros(ComplexF64, 2D, 2D)
                H[1:D, 1:D] .= A
                H[1:D, (D + 1):(2D)] .= B
                H[(D + 1):(2D), 1:D] .= .-conj.(B)
                H[(D + 1):(2D), (D + 1):(2D)] .= .-conj.(A)
                ef = eigen(H)
                slow = sum(
                    j ->
                        if (
                            sum(abs2, view(ef.vectors, 1:D, j)) -
                            sum(abs2, view(ef.vectors, (D + 1):(2D), j))
                        ) > 0
                            real(ef.values[j])
                        else
                            0.0
                        end, 1:(2D))
                @test fast ≈ slow rtol = 1e-9
            end
        end
    end

    @testset "an unreachable rtol warns instead of returning garbage" begin
        # The integrand is a cancelling difference whose round-off grows like
        # k_max^6, so refinement has a floor. Unguarded, rtol=1e-6 returned
        # answers wrong by factors of 4 to 120.
        F, c1 = 6, -0.02
        ip = InteractionParams(Dict(0 => 10.0, 1 => c1))
        g = _c0c1_to_gS(F, 10.0, c1)
        exact = lhy_energy_fm(1.0, build_fm_lhy_coefs(F, g))
        v = @test_logs (:warn, r"past what Float64 can deliver") match_mode = :any begin
            _lhy_bdg_energy_density(_fm_spinor(F), 1.0, F, ip, ZeemanParams(),
                0.0, nothing, nothing, 1; rtol=1e-10)
        end
        @test isfinite(v)
        @test abs(v - exact) / exact < 1e-2        # degraded, not destroyed
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
