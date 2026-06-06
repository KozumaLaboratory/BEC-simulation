# polar_dipolar_lhy.jl
# =================================================================
# Closed-form contact + DDI LHY for spinor BECs in the polar phase.
#
# Dipolar extension of the contact-only polar LHY. The dipole anisotropy
# splits the |m|=1 anomalous coupling into antisymmetric (m=+1 ↔ m=-1) and
# symmetric (m=+1, m=-1 separately) modes:
#
#   m=0 phonon: same as the contact case (DDI does not shift to LO)
#   |m|=1 antisym: I_a = κ_1^(5/2) · [(1-2ε̃)/(1-ε̃)]^(5/2) · φ_1^reg(ε̃/(1-2ε̃))
#                  EXACT closed form via PhiOneReg.
#   |m|=1 sym:    1D quadrature after u-substitution u = √(w-α):
#                  I_s = κ_1^(5/2) · (1-ε̃)/√(3ε̃(1+ε̃))
#                       · ∫₀^√(β-α) φ_1^reg(α+u²-1)/(α+u²)^4 du
#                  α = (1-ε̃)/(1+ε̃),  β = (1-ε̃)/(1-2ε̃)
#                  Limits: I_s/κ_1^(5/2) → 1 as ε̃ → 0 (contact baseline);
#                          0 at ε̃ ≥ 1/2 (Petrov regime, β diverges).
#   |m|≥2:        Contact only (DDI LO = 0; ⟨Y_{2,M}⟩_Ω = 0).
#
# F-genericity: σ/δ pulled from PolarContactMod (50-digit sympy table).
# The DDI angular-average structure (antisym/sym split for |m|=1) is
# intrinsic to the polar phase dipole geometry and independent of F.
# F=6 Eu is the primary application (paper #1).

module PolarDipolarMod

function _phi_1_reg(t)
    return parentmodule(@__MODULE__).PhiOneReg.phi_1_reg(t)
end
const phi_1_reg = _phi_1_reg

# σ_m / δ_m and the cache live in PolarContactMod (sibling module already
# loaded by SpinorBEC before this one).
function _polar_contact()
    return parentmodule(@__MODULE__).PolarContactMod
end

export lhy_energy_polar_dipolar
export antisym_branch, sym_branch, sym_branch_quad

# =================================================================
# Antisym branch (closed form)
# =================================================================

"""
    antisym_branch(eps_tilde::Float64) -> Float64

|m|=1 antisymmetric contribution per `(n κ_1)^(5/2)`:

    factor = ((1-2ε̃)/(1-ε̃))^(5/2),   t = ε̃/(1-2ε̃)
    return  factor · φ_1^reg(t)

PhiOneReg handles t ≤ -1 via Petrov saturation, so ε̃ ≥ 1/2 gracefully
defers to the saturated regime.
"""
@inline function antisym_branch(eps_tilde::Float64)::Float64
    one_minus_2eps = 1.0 - 2.0 * eps_tilde
    one_minus_eps = 1.0 - eps_tilde
    if abs(one_minus_eps) < 1e-15
        return 0.0
    end
    factor = (one_minus_2eps / one_minus_eps)^2.5
    t_resc = eps_tilde / one_minus_2eps
    return factor * phi_1_reg(t_resc)
end

# =================================================================
# Sym branch — Simpson 1D quadrature
# =================================================================
#
# An earlier draft shipped a small-ε̃ series
#   I_s/κ_1^(5/2) ≈ √(3ε̃)·(J_0 + J_1·ε̃ + ...)   with J_0 = 2, J_1 = 27/4
# that captured only the DDI *excess* over the contact baseline. The full
# I_s/κ_1^(5/2) limits to 1 at ε̃→0 (the m=±1 sym-mode contact contribution),
# not to 0; including the series broke the ε̃=0 → contact-only reduction by
# ~3% per mode. The Simpson quadrature handles ε̃ → 0 correctly via the
# cancellation between the `1/√(3ε̃)` prefactor and the integrand's
# `√(β-α) ≈ √(3ε̃)` shrinkage, so we use it uniformly.

# Simpson 1/3 rule over [a, b] with `n` panels (n must be even).
function _simpson(f, a::Float64, b::Float64, n::Int)
    iseven(n) || (n += 1)
    n == 0 && return 0.0
    h = (b - a) / n
    s = f(a) + f(b)
    @inbounds for i in 1:(n - 1)
        x = a + i * h
        s += (iseven(i) ? 2.0 : 4.0) * f(x)
    end
    return s * h / 3.0
end

"""
    sym_branch_quad(eps_tilde::Float64; n_panels=256) -> Float64

Sym branch via the substitution `u = √(w-α)`:

    I_s/(κ_1^(5/2)) = (1-ε̃) / (2√(3ε̃(1+ε̃))) ·
                       ∫_α^β φ_1^reg(w-1) / (w⁴ √(w-α)) dw
                    = (1-ε̃) / (√(3ε̃(1+ε̃))) ·
                       ∫₀^√(β-α) φ_1^reg(α+u²-1) / (α+u²)^4 du

The integrand is smooth in `u`; 256-panel Simpson reaches ~1e-9 relative
accuracy even near ε̃ → 0.5 (β large).
"""
function sym_branch_quad(eps_tilde::Float64; n_panels::Int=256)::Float64
    # ε̃ = 0 is the contact-only limit: factor (1-ε̃)/√(3ε̃(1+ε̃)) diverges,
    # integrand collapses to a √(β-α) ≈ √(3ε̃) shrinking interval, the two
    # cancel and I_s/κ_1^(5/2) → 1 (the m=±1 sym-mode contact value).
    eps_tilde <= 0.0 && return 1.0
    eps_tilde >= 0.5 && return 0.0  # β diverges; defer to Petrov regime

    alpha = (1.0 - eps_tilde) / (1.0 + eps_tilde)
    beta = (1.0 - eps_tilde) / (1.0 - 2.0 * eps_tilde)
    u_max = sqrt(beta - alpha)

    integrand = u -> begin
        w = alpha + u * u
        return phi_1_reg(w - 1.0) / w^4
    end
    integral = _simpson(integrand, 0.0, u_max, n_panels)

    factor = (1.0 - eps_tilde) / sqrt(3.0 * eps_tilde * (1.0 + eps_tilde))
    return factor * integral
end

@inline function sym_branch(eps_tilde::Float64)::Float64
    return sym_branch_quad(eps_tilde)
end

# =================================================================
# LHY energy density (closed form, contact + DDI)
# =================================================================

"""
    lhy_energy_polar_dipolar(n, F, g_dict, eps_tilde_dd; M_mass=1.0, hbar=1.0) -> Float64

LHY energy density for an F-polar BEC with DDI parameter `eps_tilde_dd`.

`eps_tilde_dd` is the dimensionless ratio governing the |m|=1 antisym
channel: `ε̃ = (DDI strength)/(contact strength of |m|=1 channel)`. The
caller is responsible for choosing the convention; for Eu the typical
regime is ε̃ ~ 0.1 - 0.3.

`ε̃ = 0` reduces to `lhy_energy_polar` exactly (verified in
test_lhy_polar.jl).
"""
function lhy_energy_polar_dipolar(n::Float64, F::Int, g_dict, eps_tilde_dd::Float64;
    M_mass::Float64=1.0, hbar::Float64=1.0)::Float64
    coefs = _polar_contact().build_polar_lhy_coefs(F, g_dict)
    return lhy_energy_polar_dipolar(n, coefs, eps_tilde_dd; M_mass, hbar)
end

function lhy_energy_polar_dipolar(n::Float64, coefs, eps_tilde_dd::Float64;
    M_mass::Float64=1.0, hbar::Float64=1.0)::Float64
    F = coefs.F
    prefactor = (8.0 * sqrt(M_mass^3)) / (15.0 * π^2 * hbar^3)

    # m = 0 phonon: same as contact-only
    sigma_0 = coefs.sigma[1]
    total = (n * sigma_0)^2.5

    # |m|=1: split antisym + sym
    if F >= 1
        delta_1 = coefs.delta[2]
        kappa_1 = abs(delta_1)
        if kappa_1 > 1e-12
            n52_kappa1 = (n * kappa_1)^2.5
            I_a = antisym_branch(eps_tilde_dd) * n52_kappa1
            I_s = sym_branch(eps_tilde_dd) * n52_kappa1
            total += I_a + I_s   # ν_a = ν_s = 1 (each is a single mode, sum = 2 = ν_{|m|=1})
        end
    end

    # |m| ≥ 2: contact only (DDI LO = 0)
    @inbounds for m in 2:F
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

end # module PolarDipolarMod
