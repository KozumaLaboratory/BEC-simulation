using SpinorBEC
using SpinorBEC: phi_1_reg, T_KNOTS, VAL_KNOTS, DERIV_KNOTS,
    lhy_energy_polar, sigma_polar, delta_polar, build_polar_lhy_coefs,
    lhy_energy_polar_dipolar, antisym_branch, sym_branch, sym_branch_quad,
    lhy_energy_fm, sigma_fm, delta_fm, build_fm_lhy_coefs,
    lhy_energy_fm_dipolar
using SpinorBEC: lima_pelster_Q5
using Test
using LinearAlgebra: norm
# `_build_spinor_lhy` takes the Zeeman field as a required trailing argument
# since 2026-07-30: `:full_bdg` and `:spatial` solve a BdG problem and need it,
# and it is deliberately NOT defaulted — a default is how every table came to be
# built at zero field in the first place.
const _ZF = SpinorBEC._to_zeeman_field(ZeemanParams(0.0, 0.0), nothing)

# =================================================================
# PhiOneReg
# =================================================================

@testset "PhiOneReg evaluator" begin
    # Special values
    @test phi_1_reg(0.0) == 1.0
    @test isapprox(phi_1_reg(-1.0), 0.31770490679774216; atol=1e-12)

    # φ'(0) ≈ 5/8 (rigorous from sym mode J_1 = 27/4 expansion)
    h = 1e-4
    fp = (phi_1_reg(h) - phi_1_reg(-h)) / (2h)
    @test isapprox(fp, 0.625; atol=1e-3)

    # All 39 knots recovered exactly (spline passes through its own knots —
    # self-referential; the real gate is the independent quadrature below).
    for i in 1:length(T_KNOTS)
        @test isapprox(phi_1_reg(T_KNOTS[i]), VAL_KNOTS[i]; atol=1e-12)
    end

    @testset "φ₁ knots ≡ independent Gauss-Legendre quadrature (magic-number gate)" begin
        # The 78 VAL/DERIV knots are mpmath values pasted into the source. Recompute
        # φ₁ᵣₑ𝓰(t) = (15/8√2) ∫₀^∞ x²[Re√((x²+t)(x²+t+2)) − (x²+t+1) + 1/(2x²)] dx
        # from scratch by GL quadrature (x = u/(1−u); split at the branch kink
        # x²+t=0 for t<0; conjugate form avoids large-x cancellation) and compare
        # to the stored knots — a genuine re-derivation, not a self-read.
        function _phi1_integrand(x, t)
            a = x^2 + t
            prod = a * (a + 2)
            diff = prod >= 0 ? 1 / ((a + 1) + sqrt(prod)) : (a + 1)  # (a+1)−Re√, cancel-free
            x^2 * (diff - 1 / (2x^2))
        end
        function _phi1_quad(t; n=300)
            breaks = t < 0 ? [0.0, sqrt(-t) / (1 + sqrt(-t)), 1.0 - 1e-12] :
                     [0.0, 1.0 - 1e-12]
            I = 0.0
            for p in 1:(length(breaks) - 1)
                nodes, wts = SpinorBEC._gauss_legendre(n, breaks[p], breaks[p + 1])
                for (u, w) in zip(nodes, wts)
                    I += w * _phi1_integrand(u / (1 - u), t) / (1 - u)^2
                end
            end
            -(15 / (8 * sqrt(2))) * I
        end
        for t in (-1.0, -0.5, -0.05, 0.0, 0.5, 1.0, 5.0, 20.0, 50.0)
            @test isapprox(phi_1_reg(t), _phi1_quad(t); atol=1e-6)
        end
        # derivative table via central difference of the independent quadrature
        for t in (-0.5, 0.0, 1.0, 5.0)
            i = findfirst(≈(t), T_KNOTS)
            dq = (_phi1_quad(t + 1e-4) - _phi1_quad(t - 1e-4)) / 2e-4
            @test isapprox(DERIV_KNOTS[i], dq; atol=1e-5)
        end
    end

    # Petrov saturation for t < -1
    val_m1 = phi_1_reg(-1.0)
    for t in (-1.5, -2.0, -10.0)
        @test phi_1_reg(t) == val_m1
    end

    # Monotonic non-decreasing on (-1, 50]
    prev = phi_1_reg(-0.99)
    for t in -0.99:0.05:50.0
        cur = phi_1_reg(t)
        @test cur >= prev - 1e-12
        prev = cur
    end

    # Asymptotic patch is C⁰-continuous at t=50
    eps = 1e-10
    @test isapprox(phi_1_reg(50.0 - eps), phi_1_reg(50.0 + eps); atol=1e-6)

    # Asymptotic ratio φ/√(t+1) → 15π/(32√2) ≈ 1.04143
    asymp_C1 = 15.0 * π / (32.0 * sqrt(2.0))
    @test isapprox(phi_1_reg(1000.0) / sqrt(1001.0), asymp_C1; atol=5e-3)
end

# =================================================================
# Polar contact LHY — F=1 polar reproduces KU 2012 Eq. (266)
# =================================================================

@testset "Polar contact LHY: F=1 polar matches KU 2012 Eq. (266)" begin
    # Polar phase is GS only for c_1 > 0 (otherwise FM); the literature
    # formula (8/(15π²))[c_0^(5/2) + 2|c_1|^(5/2)] implicitly assumes
    # polar-stable. Pick g_2 > g_0 so c_1 = (g_2-g_0)/3 > 0; for the
    # opposite sign the polar formula correctly Petrov-saturates and the
    # comparison with the bare-|c_1|^(5/2) literature form would diverge
    # by ~0.2%.
    g0, g2 = 80.0, 100.0
    g_dict = Dict(0 => g0, 2 => g2)

    # KU c_0 = (g_0 + 2g_2)/3, c_1 = (g_2 - g_0)/3
    c0_KU = (g0 + 2g2) / 3
    c1_KU = (g2 - g0) / 3

    # σ_0 ≡ c_0 (Goldstone identity), δ_0 ≡ σ_0
    @test isapprox(sigma_polar(1, 0, g_dict), c0_KU; atol=1e-10)
    @test isapprox(delta_polar(1, 0, g_dict), c0_KU; atol=1e-10)

    # δ_1 ≡ c_1 (verified algebraically in PolarContactMod docstring)
    @test isapprox(delta_polar(1, 1, g_dict), c1_KU; atol=1e-10)

    # ξ_1 = 2σ_1 - σ_0 ≡ c_1 (Goldstone identity for SO(3) breaking)
    sigma_1 = sigma_polar(1, 1, g_dict)
    xi_1 = 2 * sigma_1 - c0_KU
    @test isapprox(xi_1, c1_KU; atol=1e-10)

    # ε_LHY = (8/(15π²)) [c_0^(5/2) + 2 |c_1|^(5/2)] n^(5/2)
    n = 1.0
    eps_KU = (8.0 / (15.0 * π^2)) * (c0_KU^2.5 + 2.0 * abs(c1_KU)^2.5) * n^2.5
    eps_polar = lhy_energy_polar(n, 1, g_dict)
    @test isapprox(eps_polar, eps_KU; rtol=1e-10)
end

# =================================================================
# Polar contact LHY — Scalar limit + F=6 user parameters
# =================================================================

@testset "Polar contact LHY: scalar limit g_S = g for all S" begin
    # All g_S equal → reduces to scalar Lima-Pelster (Q5=1, no DDI)
    for F in (1, 2, 3, 6)
        g_dict = Dict(S => 1.0 for S in 0:2:(2F))
        eps_polar = lhy_energy_polar(1.0, F, g_dict)
        eps_scalar = (8.0 / (15.0 * π^2)) * 1.0^2.5
        @test isapprox(eps_polar, eps_scalar; rtol=1e-12)
    end
end

@testset "Polar contact LHY: F=6 user-validation parameters g_S = 100 + 5S" begin
    # Per integration plan: g_S = 100..160 for S = 0,2,...,12 → ε_LHY ≈ 12331.35
    g_user = Dict(S => 100.0 + 5.0 * S for S in (0, 2, 4, 6, 8, 10, 12))
    eps_user = lhy_energy_polar(1.0, 6, g_user)
    @test eps_user > 0
    @test isfinite(eps_user)
    @test isapprox(eps_user, 12331.345573; atol=1e-1)

    # Goldstone identities at F=6
    sigma_0 = sigma_polar(6, 0, g_user)
    delta_0 = delta_polar(6, 0, g_user)
    @test isapprox(sigma_0, delta_0; atol=1e-10)

    sigma_1 = sigma_polar(6, 1, g_user)
    delta_1 = delta_polar(6, 1, g_user)
    xi_1 = 2 * sigma_1 - sigma_0
    @test isapprox(xi_1, delta_1; atol=1e-10)
end

# =================================================================
# Polar dipolar LHY — ε̃ = 0 reduces exactly to contact-only
# =================================================================

@testset "Polar dipolar LHY: ε̃=0 limit reduces to contact-only" begin
    g_user = Dict(S => 100.0 + 5.0 * S for S in (0, 2, 4, 6, 8, 10, 12))
    for n in (0.5, 1.0, 2.5, 10.0)
        eps_contact = lhy_energy_polar(n, 6, g_user)
        eps_dipolar0 = lhy_energy_polar_dipolar(n, 6, g_user, 0.0)
        @test isapprox(eps_contact, eps_dipolar0; rtol=1e-10)
    end
end

@testset "Polar dipolar LHY: antisym branch ε̃=0 limit" begin
    # antisym_branch(0) = 1 (factor=1, t=0, φ=1)
    @test antisym_branch(0.0) ≈ 1.0
    # Smooth across small ε̃
    for et in (0.001, 0.01, 0.1, 0.2, 0.3)
        I_a = antisym_branch(et)
        @test I_a > 0
        @test isfinite(I_a)
    end
end

@testset "Polar dipolar LHY: sym branch limits + monotonic" begin
    # ε̃→0 limit: contact-only sym mode gives 1
    @test isapprox(sym_branch(0.0), 1.0; atol=1e-12)
    @test isapprox(sym_branch_quad(1e-6), 1.0; atol=1e-3)

    # Smooth + positive across the physical range
    prev = sym_branch(1e-6)
    for et in (0.001, 0.01, 0.05, 0.1, 0.2, 0.3, 0.4)
        cur = sym_branch(et)
        @test cur > 0
        @test isfinite(cur)
        # Sym branch is monotonically increasing in ε̃ (DDI enhances zero-point)
        @test cur >= prev - 1e-10
        prev = cur
    end
end

@testset "Polar dipolar LHY: Eu-relevant ε̃ ≈ 0.2 finite + DDI shifts up" begin
    g_user = Dict(S => 100.0 + 5.0 * S for S in (0, 2, 4, 6, 8, 10, 12))
    eps_contact = lhy_energy_polar(1.0, 6, g_user)
    eps_dipolar = lhy_energy_polar_dipolar(1.0, 6, g_user, 0.2)
    @test isfinite(eps_dipolar)
    @test eps_dipolar > eps_contact   # DDI antisym/sym branches should increase total LHY
end

# =================================================================
# Wrapper integration: TabulatedLHY round-trip
# =================================================================

@testset "compute_spinor_lhy_polar_contact wrapper" begin
    g_user = Dict(S => 100.0 + 5.0 * S for S in (0, 2, 4, 6, 8, 10, 12))
    table = compute_spinor_lhy_polar_contact(; F=6, g_dict=g_user,
        n_max=10.0, n_points=50)
    @test table isa PolarContactLHY
    @test length(table.densities) == 50
    @test length(table.potential_values) == 50
    # Potential should be positive and monotonically increasing for repulsive LHY
    @test all(v -> v >= -1e-10, table.potential_values)
end

# =================================================================
# FM contact LHY — uniform g_S reduces to scalar Lima-Pelster
# =================================================================

@testset "FM contact LHY: structure at every F" begin
    # δ_m non-zero only at m=+F, for any F — not a property of one table.
    for F in 1:8
        g = Dict(S => 100.0 + 5.0 * S for S in 0:2:(2F))
        @test delta_fm(F, F, g) ≈ g[2F]
        for m in (-F):(F - 1)
            @test delta_fm(F, m, g) == 0.0
        end
        # Goldstone identities: σ_+F = δ_+F (U(1) phonon),
        # 2σ_+(F-1) = σ_+F (F₋ magnon, type-B, ω ∝ k²).
        @test isapprox(sigma_fm(F, F, g), delta_fm(F, F, g); rtol=1e-12)
        @test isapprox(2 * sigma_fm(F, F - 1, g), sigma_fm(F, F, g); rtol=1e-12)
    end
    @test_throws ArgumentError sigma_fm(6, 7, Dict(0 => 1.0))
end

# The 49 sympy-derived rationals that used to BE the implementation (a hand-
# entered F=6 lookup table, with `error()` for every other F). They are pinned
# here instead, as the oracle for the general-F closed form that replaced it.
#
# This has to be a literal table, not a call to `clebsch_gordan`: the
# implementation now IS a Clebsch-Gordan sum, so recomputing it that way would
# be a self-comparison. These numbers come from an independent sympy derivation
# at 50-digit precision (parallel session 2026-05-07, Paper #3 §V.E).
const _FM_SIGMA_F6_SYMPY = Dict{Int, Dict{Int, Float64}}(
    -6 => Dict(
        0 => 1.0/13.0,
        2 => 22.0/91.0,
        4 => 891.0/6188.0,
        6 => 11.0/323.0,
        8 => 11.0/3458.0,
        10 => 9.0/96577.0,
        12 => 1.0/2704156.0,
    ),
    -5 => Dict(
        2 => 11.0/91.0,
        4 => 1485.0/6188.0,
        6 => 77.0/646.0,
        8 => 33.0/1729.0,
        10 => 165.0/193154.0,
        12 => 1.0/208012.0,
    ),
    -4 => Dict(
        2 => 2.0/91.0,
        4 => 1215.0/6188.0,
        6 => 70.0/323.0,
        8 => 15.0/247.0,
        10 => 405.0/96577.0,
        12 => 1.0/29716.0,
    ),
    -3 => Dict(
        4 => 81.0/884.0, 6 => 84.0/323.0, 8 => 33.0/247.0, 10 => 108.0/7429.0, 12 => 5.0/29716.0
    ),
    -2 => Dict(
        4 => 9.0/442.0, 6 => 70.0/323.0, 8 => 55.0/247.0, 10 => 294.0/7429.0, 12 => 5.0/7429.0
    ),
    -1 => Dict(6 => 77.0/646.0, 8 => 11.0/38.0, 10 => 1323.0/14858.0, 12 => 1.0/437.0),
    +0 => Dict(6 => 11.0/323.0, 8 => 11.0/38.0, 10 => 1260.0/7429.0, 12 => 3.0/437.0),
    +1 => Dict(8 => 55.0/266.0, 10 => 120.0/437.0, 12 => 3.0/161.0),
    +2 => Dict(8 => 11.0/133.0, 10 => 162.0/437.0, 12 => 15.0/322.0),
    +3 => Dict(10 => 9.0/23.0, 12 => 5.0/46.0),
    +4 => Dict(10 => 6.0/23.0, 12 => 11.0/46.0),
    +5 => Dict(12 => 1.0/2.0),
    +6 => Dict(12 => 1.0),
)

@testset "FM σ_m closed form ↔ the F=6 sympy rationals" begin
    F = 6
    for (m, want) in _FM_SIGMA_F6_SYMPY
        for S in 0:2:(2F)
            onehot = Dict(s => (s == S ? 1.0 : 0.0) for s in 0:2:(2F))
            # one-hot g_S isolates the single coefficient of g_S in σ_m
            @test isapprox(sigma_fm(F, m, onehot), get(want, S, 0.0); atol=1e-12)
        end
    end
    # Every non-zero rational is actually exercised above, and the fixture has
    # not silently lost rows. 49 non-zero coefficients over 13 m-values × 7
    # even-S channels = 91 comparisons; the count is asserted because a fixture
    # that quietly shrinks turns this oracle into a weaker one that still
    # passes. (It earned its place immediately: the first version of this line
    # said 62, having counted the outer `m => Dict(...)` arrows as well.)
    @test sum(length, values(_FM_SIGMA_F6_SYMPY)) == 49
    @test length(_FM_SIGMA_F6_SYMPY) == 13
end

@testset "FM dipolar reduces to FM contact at eps_dd = 0, at every F" begin
    # The FM+DDI closed form dresses the same single mode with Lima-Pelster
    # Q_5(eps_dd), so eps_dd = 0 must return the contact result EXACTLY at any F
    # — Q_5(0) = 1. Was only ever checked at F=6, which is what let the F=6
    # lookup table look load-bearing on this path too.
    #
    # Deliberately NOT compared to full_bdg: this closed form drops the S=2F-2
    # channel coupling (documented, suppressed by Δa/a_s << 1), so it is a
    # different physical model rather than a different computation of the same
    # one. Asserting equality would be pinning an approximation to an exact
    # result.
    for F in 1:8
        g = Dict(S => 100.0 + 5.0 * S for S in 0:2:(2F))
        for n in (0.5, 1.0, 3.0)
            @test lhy_energy_fm_dipolar(n, F, g, 0.0) ≈ lhy_energy_fm(n, F, g) rtol = 1e-13
        end
        # and monotone in eps_dd over the stable range (Q_5 grows with eps_dd)
        vals = [lhy_energy_fm_dipolar(1.0, F, g, et) for et in (0.0, 0.2, 0.5, 0.8)]
        @test issorted(vals)
    end
end

@testset "FM single-mode collapse holds at every F (vs full_bdg)" begin
    # The closed form needs only g_{2F}, on the argument that every mode other
    # than m=+F is free (κ_m = 0) and cancels against its own counterterm.
    # `full_bdg` diagonalises the coupled problem with no ansatz, so it is an
    # independent statement of the same number — and it is what shows the
    # F=6-only restriction was never a physics limit.
    pref = 8 / (15 * π^2)
    for F in 1:8, c1 in (-0.02, -0.1)
        g = SpinorBEC._c0c1_to_gS(F, 10.0, c1)
        all(>(0), values(g)) || continue
        spinor = ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:(2F + 1)]   # m = +F
        closed = lhy_energy_fm(1.0, build_fm_lhy_coefs(F, g))
        @test closed ≈ pref * g[2F]^2.5 rtol = 1e-12
        bdg = SpinorBEC._lhy_bdg_energy_density(spinor, 1.0, F,
            InteractionParams(Dict(0 => 10.0, 1 => c1)), ZeemanParams(), 0.0,
            nothing, nothing, nothing; rtol=1e-5)
        @test bdg ≈ closed rtol = 1e-5
    end
end

@testset "polar contact LHY: σ_m/δ_m coefficients ≡ Clebsch-Gordan (magic-number gate)" begin
    # Polar (nematic) condensate at m=0 ⇒ per-S coefficients are pure CG:
    #   σ_m = |⟨F,m; F,0 | S,m⟩|²                          (normal)
    #   δ_m = ⟨F,m; F,-m | S,0⟩ · ⟨F,0; F,0 | S,0⟩          (anomalous, pair m_tot=0)
    # Recompute every SIGMA_TABLE / DELTA_TABLE entry (F=1..8, all m, even S) from
    # clebsch_gordan and compare to the accessors — gates the ~1000 hand-entered
    # polar coefficients against an independent derivation (35/144-class guard).
    for F in 1:8, m in (-F):F, S in 0:2:(2F)
        onehot = Dict(s => (s == S ? 1.0 : 0.0) for s in 0:2:(2F))
        @test isapprox(sigma_polar(F, m, onehot),
            clebsch_gordan(F, m, F, 0, S, m)^2; atol=1e-10)
        @test isapprox(delta_polar(F, m, onehot),
            clebsch_gordan(F, m, F, -m, S, 0) * clebsch_gordan(F, 0, F, 0, S, 0);
            atol=1e-10)
    end
end

@testset "FM contact LHY: uniform g_S = c_0 reduces to scalar Lima-Pelster" begin
    c_0 = 100.0
    g_uniform = Dict(S => c_0 for S in (0, 2, 4, 6, 8, 10, 12))
    for n in (0.5, 1.0, 2.5, 10.0)
        eps_fm = lhy_energy_fm(n, 6, g_uniform)
        eps_scalar = (8.0 / (15.0 * π^2)) * (c_0 * n)^2.5
        @test isapprox(eps_fm, eps_scalar; rtol=1e-12)
    end
end

# =================================================================
# FM dipolar LHY — Q5 reduction (Stage C scalar)
# =================================================================

@testset "FM dipolar LHY: Q5(0) = 1 (scalar limit)" begin
    @test isapprox(lima_pelster_Q5(0.0), 1.0; atol=1e-12)
end

@testset "FM dipolar LHY: ε_dd=0 reduces to fm_contact" begin
    g_user = Dict(S => 100.0 + 5.0 * S for S in (0, 2, 4, 6, 8, 10, 12))
    for n in (0.5, 1.0, 2.5, 10.0)
        eps_contact = lhy_energy_fm(n, 6, g_user)
        eps_dipolar0 = lhy_energy_fm_dipolar(n, 6, g_user, 0.0)
        @test isapprox(eps_contact, eps_dipolar0; rtol=1e-12)
    end
end

@testset "FM dipolar LHY: species Q5 reference values (Lima-Pelster)" begin
    # Reference values: parallel session 2026-05-07 honest correction +
    # Saito-Li 2024 conventions. ε_dd = a_dd / a_s (standard scalar; F²
    # already in c_dd via μ²).
    references = [
        ("Cr", 0.15, 1.03),
        ("Eu", 0.55, 1.46),
        ("Er", 0.88, 2.23),
        ("Dy", 1.39, 4.11),
    ]
    for (atom, eps, q5_expected) in references
        q5 = lima_pelster_Q5(eps)
        @test isapprox(q5, q5_expected; atol=0.05)
    end
end

@testset "FM dipolar LHY: monotonic enhancement with ε_dd" begin
    g_user = Dict(S => 100.0 + 5.0 * S for S in (0, 2, 4, 6, 8, 10, 12))
    eps_prev = lhy_energy_fm_dipolar(1.0, 6, g_user, 0.0)
    for et in (0.05, 0.15, 0.3, 0.55, 0.88, 1.0)
        eps = lhy_energy_fm_dipolar(1.0, 6, g_user, et)
        @test eps >= eps_prev   # Q5 monotonically grows in (0, 1)
        eps_prev = eps
    end
end

@testset "compute_spinor_lhy_fm_dipolar wrapper" begin
    g_user = Dict(S => 100.0 + 5.0 * S for S in (0, 2, 4, 6, 8, 10, 12))
    table = compute_spinor_lhy_fm_dipolar(; F=6, g_dict=g_user, eps_dd=0.55,
        n_max=10.0, n_points=50)
    @test table isa FMDipolarLHY
    @test length(table.densities) == 50
    @test length(table.potential_values) == 50
end

@testset "make_workspace FM dipolar LHY converts per-spin c_dd to epsilon_dd" begin
    c0 = 100.0
    ws = InteractionParams(Dict(0 => c0, 1 => 0.0))
    c_dd_per_spin = 3.0
    expected_eps = c_dd_per_spin * Eu151.F^2 / (3.0 * c0)
    g_uniform = Dict(S => c0 for S in (0, 2, 4, 6, 8, 10, 12))

    table = SpinorBEC._build_spinor_lhy(
        Val(:fm_dipolar), Eu151, ws, nothing, c_dd_per_spin, true, LHYTableOpts(), _ZF)
    expected = compute_spinor_lhy_fm_dipolar(;
        F=6, g_dict=g_uniform, eps_dd=expected_eps)

    @test table.densities == expected.densities
    @test table.potential_values ≈ expected.potential_values rtol = 1e-12
end

@testset "compute_spinor_lhy_fm_contact wrapper" begin
    g_user = Dict(S => 100.0 + 5.0 * S for S in (0, 2, 4, 6, 8, 10, 12))
    table = compute_spinor_lhy_fm_contact(; F=6, g_dict=g_user,
        n_max=10.0, n_points=50)
    @test table isa FMContactLHY
    @test length(table.densities) == 50
    @test length(table.potential_values) == 50
    # FM single-mode formula gives positive monotonically increasing potential
    @test all(v -> v >= -1e-10, table.potential_values)
end

@testset "compute_spinor_lhy_polar_dipolar wrapper, ε̃=0 matches contact wrapper" begin
    g_user = Dict(S => 100.0 + 5.0 * S for S in (0, 2, 4, 6, 8, 10, 12))
    table_contact = compute_spinor_lhy_polar_contact(; F=6, g_dict=g_user,
        n_max=10.0, n_points=50)
    table_dipolar = compute_spinor_lhy_polar_dipolar(; F=6, g_dict=g_user,
        eps_tilde_dd=0.0,
        n_max=10.0, n_points=50)
    @test table_contact.densities ≈ table_dipolar.densities
    @test maximum(abs.(table_contact.potential_values .- table_dipolar.potential_values)) < 1e-8
end

@testset "polar_contact REFUSES at c₀ < 0 instead of dying in `^`" begin
    # A negative c₀ drives the density Goldstone stiffness σ₀ negative, and the
    # closed form then evaluated `(n·σ₀)^2.5` and threw a bare DomainError twelve
    # frames deep — "Exponentiation yielding a complex result requires a complex
    # argument" — naming no coupling and suggesting no fix. `epsilon_LHY_F6_Ih`
    # already refuses the SAME case (`c_0 < 0 && return NaN`, "I_h not the GS");
    # polar_contact simply never got that treatment.
    #
    # How it was found is worth recording, because the first version of this test
    # was wrong: it passed `(c₀ = 10, c₁ = −0.5)` on the assumption that a
    # negative c₁ is what triggers it, and that builds fine. The real trigger came
    # from `c₀ + F²c₁ = c_total` with `c₁ = r·c₀`, i.e. `c₀ = c_total/(1 + 36r)`,
    # which flips c₀ NEGATIVE for `r < −1/36`. So the couplings are constructed
    # here the way that constraint constructs them, rather than guessed.
    F = 6
    c_total = 4687.3
    r_bad = -0.05                    # past the −1/36 singularity ⇒ c₀ < 0
    c0_bad = c_total / (1 + F^2 * r_bad)
    @test c0_bad < 0                 # the premise, asserted rather than assumed
    err = try
        SpinorBEC.compute_spinor_lhy_polar_contact(;
            F, g_dict=SpinorBEC._c0c1_to_gS(F, c0_bad, r_bad * c0_bad),
            n_max=2.0, n_points=8)
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("not applicable", err.msg)
    @test occursin("full_bdg", err.msg)

    # POSITIVE CONTROL at a REAL production point. `runs/eu_gs_phase_c1_B_kappa`
    # scans r ∈ [−0.024, +0.048] and says in its header that it "stays >
    # singularity −1/36" — so r = −0.024 has c₀ > 0 with c₁ < 0, which is the
    # combination production actually uses, and it must still build. Without this
    # the test would pass on a form that refuses everything.
    r_ok = -0.024
    c0_ok = c_total / (1 + F^2 * r_ok)
    @test c0_ok > 0 && r_ok * c0_ok < 0        # c₀ > 0 AND c₁ < 0
    tbl = SpinorBEC.compute_spinor_lhy_polar_contact(;
        F, g_dict=SpinorBEC._c0c1_to_gS(F, c0_ok, r_ok * c0_ok),
        n_max=2.0, n_points=8)
    @test tbl isa SpinorBEC.PolarContactLHY
    @test all(isfinite, tbl.potential_values)
end
