using SpinorBEC
using SpinorBEC: PhiOneReg, PolarContactMod, PolarDipolarMod, FMContactMod, FMDipolarMod
using SpinorBEC.PhiOneReg: phi_1_reg, T_KNOTS, VAL_KNOTS, DERIV_KNOTS
using SpinorBEC.PolarContactMod: lhy_energy_polar, sigma_polar, delta_polar,
    build_polar_lhy_coefs
using SpinorBEC.PolarDipolarMod:
    lhy_energy_polar_dipolar, antisym_branch,
    sym_branch, sym_branch_quad
using SpinorBEC.FMContactMod: lhy_energy_fm, sigma_fm, delta_fm,
    build_fm_lhy_coefs
using SpinorBEC.FMDipolarMod: lhy_energy_fm_dipolar
using SpinorBEC: lima_pelster_Q5
using Test
using LinearAlgebra: norm

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

    # All 39 knots recovered exactly
    for i in 1:length(T_KNOTS)
        @test isapprox(phi_1_reg(T_KNOTS[i]), VAL_KNOTS[i]; atol=1e-12)
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

@testset "FM contact LHY: structure" begin
    # δ_m non-zero only at m=+F
    g_user = Dict(S => 100.0 + 5.0 * S for S in (0, 2, 4, 6, 8, 10, 12))
    @test delta_fm(6, 6, g_user) ≈ g_user[12]
    for m in -6:5
        @test delta_fm(6, m, g_user) == 0.0
    end

    # Goldstone identities: σ_+F = δ_+F, 2σ_+(F-1) = σ_+F
    @test isapprox(sigma_fm(6, 6, g_user), delta_fm(6, 6, g_user); atol=1e-10)
    @test isapprox(2 * sigma_fm(6, 5, g_user), sigma_fm(6, 6, g_user); atol=1e-10)
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
    ws = InteractionParams(c0, 0.0)
    c_dd_per_spin = 3.0
    expected_eps = c_dd_per_spin * Eu151.F^2 / (3.0 * c0)
    g_uniform = Dict(S => c0 for S in (0, 2, 4, 6, 8, 10, 12))

    table = SpinorBEC._build_spinor_lhy(
        Val(:fm_dipolar), Eu151, ws, nothing, c_dd_per_spin, true)
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
