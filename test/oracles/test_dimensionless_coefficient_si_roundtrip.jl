# Oracle: every auto-derived dimensionless coupling against an SI statement
# that has no convention freedom.
#
# Why this file exists. `_resolve_lhy_block!` shipped a `c_lhy` that was wrong by
# π·(a_s/a_ho)·√N — both the a_s exponent and the N exponent low — and nothing
# caught it for months. Neither could have:
#
#   - a units check passes: the quantity is dimensionless either way;
#   - every LHY test passed `c_lhy` in explicitly, so none exercised the
#     derivation;
#   - checking the derivation against its own construction is circular.
#
# The only thing that catches it is an anchor OUTSIDE the dimensionless
# convention: a ratio of two physical quantities, computed in SI from ℏ, m, μ₀,
# a_s, and compared with what the dimensionless couplings produce. That is what
# `test_scalar_lhy_si_roundtrip.jl` does for `c_lhy`. This file does the same for
# the rest of the derived chain, since a bug of that shape is a property of the
# pattern rather than of that one function.
#
# Each testset states its SI anchor explicitly. If an anchor is ever weakened to
# something the code also computes, the test stops being an oracle.

using Test
using SpinorBEC

const _U = SpinorBEC.Units

# (atom, N, ω_ref) triples spanning the mass / moment / a_s range in use.
const _CASES = [
    (Er166, 60_000, 2π * 600.0),
    (Dy164, 50_000, 2π * 300.0),
    (Eu151, 50_000, 2π * 110.0),
    (Cr52, 20_000, 2π * 500.0),
]

_a_ho(atom, w) = sqrt(_U.HBAR / (atom.mass * w))

@testset "Dimensionless couplings ↔ SI round-trip" begin
    @testset "c_total: contact chemical potential" begin
        # SI: μ_contact = g·n with g = 4πℏ²a_s/m. Dimensionless: the same
        # quantity is c_total·n_dimless·ℏω, with n_SI = N·n_d/a_ho³.
        # No convention freedom — g is the textbook coupling.
        for (atom, N, w) in _CASES
            a_ho = _a_ho(atom, w)
            c_total = SpinorBEC.compute_c_total(atom; N_atoms=N, omega_ref=w)
            g_si = 4π * _U.HBAR^2 * atom.a_s / atom.mass
            for n_d in (1e-3, 1e-2, 5e-2)
                n_si = N * n_d / a_ho^3
                @test c_total * n_d * _U.HBAR * w ≈ g_si * n_si rtol = 1e-12
            end
        end
    end

    @testset "c_dd: dipolar-to-contact ratio is 2·ε_dd along B̂" begin
        # SI anchor: for a density modulation with k ∥ B̂ the dipolar kernel is
        # (k̂·B̂)² − 1/3 = 2/3, so
        #     V_dd/V_contact = (2/3)·c_dd·F²/c_total
        # and that must equal 2·a_dd/a_s with a_dd = μ₀μ²m/(12πℏ²) — the
        # standard dipolar length, built from SI constants and independent of
        # how this repo splits μ between c_dd and the F² spin factor.
        #
        # This is the same identity measured directly off the scalar-eGPE kernel
        # during the supersolid reproduction (docs/validation/
        # dipolar_supersolid_tube.md item 1); here it gates the coefficient
        # builders rather than the kernel.
        for (atom, N, w) in _CASES
            atom.mu_mag > 0 || continue
            F = atom.F
            c_dd = SpinorBEC.compute_c_dd_dimless(atom; N_atoms=N, omega_ref=w)
            c_total = SpinorBEC.compute_c_total(atom; N_atoms=N, omega_ref=w)
            a_dd_si = _U.MU_0 * atom.mu_mag^2 * atom.mass / (12π * _U.HBAR^2)

            @test (2 / 3) * c_dd * F^2 / c_total ≈ 2 * a_dd_si / atom.a_s rtol = 1e-12
            # compute_a_dd must agree with the SI expression it claims to be.
            @test SpinorBEC.compute_a_dd(atom) ≈ a_dd_si rtol = 1e-12
        end
    end

    @testset "c_dd and c_total scale as N¹" begin
        # Both are extensive in N at fixed density normalisation. An exponent
        # slip here is exactly the c_lhy failure mode.
        for (atom, _, w) in _CASES
            atom.mu_mag > 0 || continue
            for f in (2, 10)
                @test SpinorBEC.compute_c_total(atom; N_atoms=10_000f, omega_ref=w) ≈
                    f * SpinorBEC.compute_c_total(atom; N_atoms=10_000, omega_ref=w) rtol =
                    1e-12
                @test SpinorBEC.compute_c_dd_dimless(atom; N_atoms=10_000f, omega_ref=w) ≈
                    f * SpinorBEC.compute_c_dd_dimless(atom; N_atoms=10_000, omega_ref=w) rtol =
                    1e-12
            end
        end
    end

    @testset "c_total and c_dd scale correctly in ω_ref" begin
        # c_total ∝ 1/a_ho ∝ √ω; c_dd ∝ 1/(ω a_ho³) ∝ ω^{1/2}. Both come out of
        # the same a_ho, so a wrong power of ω would cancel in their ratio and
        # hide from the ε_dd test above — check them separately.
        atom, N = Er166, 60_000
        w1, w2 = 2π * 300.0, 2π * 1200.0     # ×4 in ω
        @test SpinorBEC.compute_c_total(atom; N_atoms=N, omega_ref=w2) /
              SpinorBEC.compute_c_total(atom; N_atoms=N, omega_ref=w1) ≈ 2.0 rtol = 1e-12
        @test SpinorBEC.compute_c_dd_dimless(atom; N_atoms=N, omega_ref=w2) /
              SpinorBEC.compute_c_dd_dimless(atom; N_atoms=N, omega_ref=w1) ≈ 2.0 rtol =
            1e-12
    end

    @testset "ε_dd from the derived couplings equals a_dd/a_s" begin
        for (atom, N, w) in _CASES
            atom.mu_mag > 0 || continue
            eps_from_couplings =
                SpinorBEC.compute_c_dd_dimless(atom; N_atoms=N, omega_ref=w) *
                atom.F^2 / (3 * SpinorBEC.compute_c_total(atom; N_atoms=N, omega_ref=w))
            @test eps_from_couplings ≈ SpinorBEC.compute_a_dd(atom) / atom.a_s rtol = 1e-12
        end
    end

    @testset "linear Zeeman: p is g_F μ_B B in ℏω units" begin
        # SI anchor: the Zeeman energy of the m = 1 state is g_F μ_B B. The
        # Kawaguchi-Ueda operator is H = -p·F_z, so p ≡ -g_F μ_B B — the sign
        # lives in Units.bfield_to_p and nowhere else (CLAUDE.md).
        for (atom, _, w) in _CASES
            atom.g_F == 0 && continue
            for B_gauss in (0.05, 1.0, 20.0)
                B_T = B_gauss * 1e-4
                p = SpinorBEC.Units.bfield_to_p(B_gauss, atom.g_F, w)
                @test p * _U.HBAR * w ≈ -atom.g_F * _U.BOHR_MAGNETON * B_T rtol = 1e-12
                @test p < 0                       # +B on g_F>0 ⇒ negative p
            end
        end
    end

    @testset "quadratic Zeeman: dimensionless q equals q_SI/(ℏω)" begin
        # SI anchor: q_SI = (g_J μ_B B)²·q_geometry/Δ_hf (2nd-order PT). The
        # dimensionless builder goes through p rather than B, so this checks the
        # whole B → p → q chain, not just the last step.
        atom = Eu151
        for w in (2π * 110.0, 2π * 600.0), B_gauss in (0.1, 1.0, 5.0)
            B_T = B_gauss * 1e-4
            p = SpinorBEC.Units.bfield_to_p(B_gauss, atom.g_F, w)
            q_dl = SpinorBEC.compute_quadratic_zeeman(atom; p_dimless=p, omega_ref=w)
            q_si = (atom.g_J * _U.BOHR_MAGNETON * B_T)^2 * atom.q_geometry / atom.Delta_E_hf
            @test q_dl * _U.HBAR * w ≈ q_si rtol = 1e-12
            @test q_dl > 0                        # q > 0 regardless of sign(B)
        end
        # q ∝ B² exactly.
        w = 2π * 110.0
        q(B) = SpinorBEC.compute_quadratic_zeeman(
            atom; p_dimless=SpinorBEC.Units.bfield_to_p(B, atom.g_F, w), omega_ref=w
        )
        @test q(2.0) / q(1.0) ≈ 4.0 rtol = 1e-12
        # 1.43 kHz/G² is the pinned Eu value (mistake_eu_quadratic_zeeman_...).
        @test q(1.0) * w / (2π) ≈ 1.43e3 rtol = 5e-2
    end

    @testset "atoms with no moment / no hyperfine derive zero, not garbage" begin
        @test SpinorBEC.compute_c_dd_dimless(Yb174; N_atoms=1000, omega_ref=2π * 100) == 0.0
        # I=0 ⇒ no hyperfine ⇒ no second-order shift.
        @test SpinorBEC.compute_quadratic_zeeman(Dy164; p_dimless=1.0, omega_ref=2π * 100) ==
            0.0
    end
end
