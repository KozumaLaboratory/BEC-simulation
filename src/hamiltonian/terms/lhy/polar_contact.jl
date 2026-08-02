# polar_contact_lhy.jl
# =================================================================
# Closed-form contact LHY for spinor BECs in the polar phase.
#
# For arbitrary F polar (ζ_α = δ_{α,0} in the m-quantisation basis):
#
#   ε_LHY(n) = (8√M³ / (15π²ℏ³)) · n^(5/2) · Σ_m ν_m · κ_m^(5/2) · φ_1^reg(t_m)
#
#   σ_m = Σ_S g_S |⟨S, m | F m; F 0⟩|²
#   δ_m = Σ_S g_S ⟨S, 0 | F m; F -m⟩ ⟨S, 0 | F 0; F 0⟩
#   ξ_0 = σ_0,    ξ_m = 2σ_m - σ_0  (m ≠ 0)
#   Δ_m = δ_m,    κ_m = |Δ_m|,   t_m = ξ_m/|Δ_m| - 1
#   ν_0 = 1,      ν_m = 2 (m ≠ 0)
#
# Goldstone identities (algebraic, hold for any F polar):
#   ξ_0 ≡ δ_0  (U(1) phonon)
#   ξ_1 ≡ δ_1  (broken SO(3) → SO(2); see KU 2010 / 2012 derivation)
#
# σ_m / δ_m use 50-digit sympy values for F = 1..8 (see
# `sigma_delta_polar_F1_F8.jl`). For F=1 polar this reproduces KU 2012
# Eq. (266); for F=2 UN it reproduces Eq. (305-307); F=6 is the main
# application (paper #1).

export PolarLHYCoefs, build_polar_lhy_coefs, lhy_energy_polar
export sigma_polar, delta_polar

# =================================================================
# σ_m, δ_m from pre-computed Clebsch-Gordan tables (F=1..8)
# =================================================================
#
# 50-digit sympy values cast to Float64. Faster than dynamic CG and the
# Goldstone identities are encoded exactly in the rationals (σ_0 ≡ δ_0,
# 2σ_1 - σ_0 ≡ δ_1 verified S-by-S for F = 1..8).

include("sigma_delta_polar_F1_F8.jl")

# =================================================================
# Cached σ_m, δ_m for fast LDA evaluation
# =================================================================

"""
    PolarLHYCoefs(F, sigma, delta)

Pre-computed σ_m and δ_m for m ∈ 0..F (using ±m symmetry). Allocate once
per (F, g_dict) and pass into `lhy_energy_polar(n, ...)` for each density.
"""
struct PolarLHYCoefs
    F::Int
    sigma::Vector{Float64}   # length F+1, indexed by |m|+1
    delta::Vector{Float64}
end

"""
    build_polar_lhy_coefs(F, g_dict) -> PolarLHYCoefs
"""
function build_polar_lhy_coefs(F::Int, g_dict)::PolarLHYCoefs
    F >= 0 || throw(ArgumentError("F must be ≥ 0"))
    sigma = zeros(Float64, F + 1)
    delta = zeros(Float64, F + 1)
    for m in 0:F
        sigma[m + 1] = sigma_polar(F, m, g_dict)
        delta[m + 1] = delta_polar(F, m, g_dict)
    end
    PolarLHYCoefs(F, sigma, delta)
end

# =================================================================
# LHY energy density (closed form, contact only)
# =================================================================

"""
    lhy_energy_polar(n, F, g_dict; M_mass=1.0, hbar=1.0) -> Float64

LHY energy density for an F-polar BEC at local density `n`.

Modes:
  - m=0 phonon (ν=1, t_0=0): contributes (n σ_0)^(5/2)
  - m=±1 SO(3) Goldstones (ν=2, t_1=0): contributes 2(n |δ_1|)^(5/2)
  - m=±2..F gapped (ν=2, t_m≠0): contributes 2(n κ_m)^(5/2) · φ_1^reg(t_m)

Free modes (κ_m ≈ 0) are skipped. The Goldstone identities ξ_0=δ_0, ξ_1=δ_1
are reflected in t_0=t_1=0 (φ_1^reg(0)=1) by the sigma_polar/delta_polar
coefficients themselves, not enforced here as a special case.
"""
function lhy_energy_polar(n::Float64, F::Int, g_dict;
    M_mass::Float64=1.0, hbar::Float64=1.0)::Float64
    coefs = build_polar_lhy_coefs(F, g_dict)
    return lhy_energy_polar(n, coefs; M_mass, hbar)
end

function lhy_energy_polar(n::Float64, coefs::PolarLHYCoefs;
    M_mass::Float64=1.0, hbar::Float64=1.0)::Float64
    F = coefs.F
    prefactor = (8.0 * sqrt(M_mass^3)) / (15.0 * π^2 * hbar^3)

    # m = 0: ν=1, κ_0 = |δ_0| = σ_0 (Goldstone), t_0 = 0
    sigma_0 = coefs.sigma[1]
    # REFUSE rather than throw a DomainError from `^`. σ₀ < 0 is the density
    # Goldstone branch going unstable, which is the same situation as
    # `λ_spin < 0` in `epsilon_LHY_F6_Ih`: the closed form assumes a branch
    # structure that no longer holds, and ε_LHY is scheme-dependent there. That
    # path returns NaN and lets `_tabulate_lhy` raise a message naming the fix;
    # this one used to evaluate `(n·σ₀)^2.5` and die with
    # "Exponentiation yielding a complex result requires a complex argument",
    # 12 frames deep, saying nothing about couplings. Found 2026-08-02 running
    # this at c₁/c₀ = −0.05 — the sign Eu F=6 PRODUCTION uses.
    sigma_0 < 0 && return NaN
    total = (n * sigma_0)^2.5

    # m = ±1..F: ν=2 each
    @inbounds for m in 1:F
        sigma_m = coefs.sigma[m + 1]
        delta_m = coefs.delta[m + 1]
        kappa_m = abs(delta_m)
        kappa_m < 1e-12 && continue
        xi_m = 2.0 * sigma_m - sigma_0
        t_m = xi_m / kappa_m - 1.0
        total += 2.0 * (n * kappa_m)^2.5 * phi_1_reg(t_m)
    end

    return prefactor * total
end
