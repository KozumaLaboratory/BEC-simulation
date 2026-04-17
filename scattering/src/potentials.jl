"""
Born-Oppenheimer potentials for Eu + Eu (⁸S_{7/2} × ⁸S_{7/2}).

Source: Zaremba-Kopczyk, Żuchowski, Tomza, PRA 98, 032704 (2018).

In Tomza 2018 only the septet potential V_{S=7}(R) is fit to ab initio data,
and potentials for S = 0, 1, ..., 6 are generated via the Heisenberg model:

    V_S(R) = V_{S=7}(R) + J(R) · (S_max(S_max+1) − S(S+1)) / 2     (Eq. 5)

with S_max = 7 and the exchange coupling J(R) given in Eq. 6 (Table II):

    J(R) = α / cosh(β · (R − R_0))

The septet is represented in the Morse/Long-Range (MLR) form of LeRoy &
Henderson 2007; p = q = 4, and only the C_6 dispersion term is retained.

All parameters are stored in atomic units (E_h, a_0) after conversion.
"""

"""
    EuEuPotentialParams

Parameters of the Eu₂ V_{S=7} MLR potential. Fields are in atomic units.
"""
struct EuEuPotentialParams
    De::Float64              # dissociation energy [E_h]
    Re::Float64              # equilibrium bond length [a_0]
    phi::NTuple{5,Float64}   # MLR exponent coefficients φ_0..φ_4
    C6::Float64              # long-range C_6 [E_h·a_0^6]
    p::Int                   # MLR p exponent
    q::Int                   # MLR q exponent (series variable)
end

"""
    EuEuExchangeParams

Heisenberg-exchange coupling for Eu+Eu (Tomza 2018 Eq. 6, Table II).
"""
struct EuEuExchangeParams
    alpha::Float64  # amplitude [E_h]
    beta::Float64   # inverse length scale [1/a_0]
    R0::Float64     # center [a_0]
end

"""
    eueu_septet_params()

Return the Eu+Eu V_{S=7} MLR parameters from Tomza 2018, Table II.
"""
eueu_septet_params() = EuEuPotentialParams(
    cm1_to_au(704.32),
    9.2919,
    (-0.78004, -0.49552, -0.28324, 0.36690, -0.45423),
    3610.0,
    4, 4,
)

"""
    eueu_exchange_params()

Return the Eu+Eu Heisenberg exchange parameters from Tomza 2018, Table II.
"""
eueu_exchange_params() = EuEuExchangeParams(
    cm1_to_au(-0.53915),
    0.79223,
    7.8760,
)

# --- MLR internals ---

"Long-range reference u_LR(R) = C_6 / R^6 (Tomza 2018 keeps only C_6)."
u_LR(p::EuEuPotentialParams, R::Real) = p.C6 / R^6

"LeRoy radial variable y_n(R) = (R^n - Re^n) / (R^n + Re^n)."
function _y_n(R::Real, Re::Real, n::Int)
    Rn = R^n
    Ren = Re^n
    (Rn - Ren) / (Rn + Ren)
end

"MLR exponent φ(R) with φ_∞ = ln(2 De / u_LR(Re)) enforcing correct tail."
function _phi_mlr(p::EuEuPotentialParams, R::Real)
    yp = _y_n(R, p.Re, p.p)
    yq = _y_n(R, p.Re, p.q)
    phi_inf = log(2 * p.De / u_LR(p, p.Re))
    # Σ_{i=0}^{N-1} φ_i · y_q^i  (Horner)
    s = p.phi[end]
    @inbounds for i in (length(p.phi) - 1):-1:1
        s = s * yq + p.phi[i]
    end
    yp * phi_inf + (1 - yp) * s
end

"""
    V_septet(params, R) [E_h]

Septet (S = 7) Born-Oppenheimer potential in the MLR form. `R` in a_0.
"""
function V_septet(p::EuEuPotentialParams, R::Real)
    u_ratio = u_LR(p, R) / u_LR(p, p.Re)
    yp = _y_n(R, p.Re, p.p)
    phi = _phi_mlr(p, R)
    factor = 1 - u_ratio * exp(-phi * yp)
    p.De * factor * factor - p.De
end

"""
    J_exchange(params, R) [E_h]

Heisenberg exchange coupling J(R) = α / cosh(β (R − R_0)). `R` in a_0.
"""
J_exchange(e::EuEuExchangeParams, R::Real) = e.alpha / cosh(e.beta * (R - e.R0))

"""
    V_spin(septet, exch, S, R) [E_h]

Spin-resolved potential for total electronic spin S ∈ {0, 1, ..., 7} via
the Heisenberg model (Tomza 2018 Eq. 5):

    V_S(R) = V_{S=7}(R) + J(R) · (56 − S(S+1)) / 2
"""
function V_spin(
    septet::EuEuPotentialParams,
    exch::EuEuExchangeParams,
    S::Integer,
    R::Real,
)
    0 <= S <= 7 || throw(ArgumentError("S must be in 0..7, got $S"))
    V_septet(septet, R) + J_exchange(exch, R) * (56 - S * (S + 1)) / 2
end
