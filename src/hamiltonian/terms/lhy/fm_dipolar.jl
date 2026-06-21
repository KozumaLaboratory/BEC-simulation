# fm_dipolar_lhy.jl
# =================================================================
# Closed-form contact + DDI LHY for spinor BECs in the FM phase
# (Stage C scalar reduction, paper #2 contact-only piece extended with
# Lima-Pelster Q_5 angular average).
#
# For F-FM polarised condensates (ζ_α = δ_{α,+F}) the contact LHY collapses
# to a single mode at m=+F (see fm_contact_lhy.jl). DDI dresses this single
# mode with the standard Lima-Pelster Q_5(ε_dd) factor; spinor extension
# (S=2F-2 channel coupling) is suppressed by Δa/a_s << 1 in the regime
# where Saito-Li 2024 establishes the "spin almost fully polarised" picture.
#
#   ε_LHY^{FM,DDI}(n; ε_dd) = (8 √M³ / (15π²ℏ³)) · (g_{2F} · n)^(5/2) · Q_5(ε_dd)
#
# Convention (CRITICAL):
#   eps_dd is the standard scalar Lima-Pelster parameter in
#      g * [1 + eps_dd * (3cos^2(theta) - 1)].
#   Direct callers pass eps_dd explicitly.
#   SpinorBEC workspaces store c_dd = mu0*(gF*muB)^2 per unit spin and use
#   Q = cos^2(theta) - 1/3, so the FM workspace wrapper converts with
#      eps_dd = c_dd * F^2 / (3*g_{2F}).
#   If a caller instead uses a full-moment scalar C_dd = mu0*(gF*F*muB)^2,
#   the equivalent scalar conversion is eps_dd = C_dd/(3*g_{2F}) = a_dd/a_s.
#
# Petrov prescription: lima_pelster_Q5 already zeros the integrand where
# `1 + ε_dd(3cos²θ - 1) < 0`, so ε_dd > 1 (unstable angles) is handled
# without further regulation here.
#
# Stage C spinor extension (proper S=2F-2 channel coupling) is research-
# open and NOT covered here — see paper #2 "Open issues".

export lhy_energy_fm_dipolar

"""
    lhy_energy_fm_dipolar(n, F, g_dict, eps_dd; M_mass=1.0, hbar=1.0) -> Float64

LHY energy density for an F-FM-polarised BEC with DDI parameter `eps_dd`.

Single-mode result:
    ε = (8 √M³ / (15π²ℏ³)) · (n · g_{2F})^(5/2) · Q_5(eps_dd)

`eps_dd = 0` reduces to `lhy_energy_fm` exactly (Q_5(0) = 1). For
realistic dipolar atoms:
- Cr  (ε_dd = 0.15): Q_5 ≈ 1.03
- Eu  (ε_dd = 0.55): Q_5 ≈ 1.46          (paper #2 baseline)
- Er  (ε_dd = 0.88): Q_5 ≈ 2.23
- Dy  (ε_dd = 1.39): Q_5 ≈ 4.11
"""
function lhy_energy_fm_dipolar(n::Float64, F::Int, g_dict, eps_dd::Real;
    M_mass::Float64=1.0, hbar::Float64=1.0)::Float64
    coefs = build_fm_lhy_coefs(F, g_dict)
    return lhy_energy_fm_dipolar(n, coefs, eps_dd; M_mass, hbar)
end

function lhy_energy_fm_dipolar(n::Float64, coefs, eps_dd::Real;
    M_mass::Float64=1.0, hbar::Float64=1.0)::Float64
    prefactor = (8.0 * sqrt(M_mass^3)) / (15.0 * π^2 * hbar^3)
    kappa = coefs.delta_F     # δ_+F = g_{2F}, the only non-zero δ_m for FM
    kappa < 1e-12 && return 0.0
    Q5 = lima_pelster_Q5(Float64(eps_dd))
    return prefactor * (n * kappa)^2.5 * Q5
end
