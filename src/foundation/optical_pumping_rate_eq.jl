# --- F → F' = F+1 closed-cycling absorption-imaging rate equation ---
#
# Rate-equation model for the absorption imaging σ_eff(m_initial) of a spin-F
# ground state on the closed F → F'=F+1 dipole cycling transition.
#
# Validity:   Γ ≫ Ω_Rabi (low saturation, s ≲ 1) and Γ ≫ |Δ|.
# Then the F'=F+1 excited state is adiabatically eliminated and the dynamics
# reduces to a linear rate equation on the 2F+1 ground-state populations plus
# a scalar photon counter.
#
# Per-atom rate when in ground state m:
#   R_abs(m) = (Γ/2) · s · |C(F, m, q_abs)|² · L(Δ/Γ)
# After absorption the atom is in excited m_e = m + q_abs and decays to ground
# m_g = m_e − q_emit with branching |D(F+1, m_e, q_emit)|² (q_emit ∈ {−1, 0, +1}).
#
# Output table:
#   σ_eff[m] = ⟨N_ph(m_init, t_pulse)⟩
# in dimensionless form (units of Γ⁻¹ × Γ = 1; multiply by σ_0 = (ℏω Γ / 2 I_sat)
# and divide by t_pulse to get an actual cross-section, or use directly as
# the OD column-density weight σ_eff[m] · n_col(m)).
#
# For F = 1 cycling, the table reproduces Hueck-style saturated absorption
# limits (test_optical_pumping_rate_eq.jl verifies this).

export OpticalPumpingParams, build_sigma_eff_table, polarization_q

"""
    polarization_q(p::Symbol) -> Int

Photon polarization symbol → angular-momentum quantum number q.
:sigma_plus → +1, :sigma_minus → -1, :pi → 0.
"""
@inline function polarization_q(p::Symbol)
    p === :sigma_plus && return +1
    p === :sigma_minus && return -1
    p === :pi && return 0
    throw(ArgumentError("polarization must be :sigma_plus, :sigma_minus, or :pi (got $p)"))
end

"""
    OpticalPumpingParams(; F_ground, polarization, saturation,
                          detuning_over_gamma, t_pulse_gamma)

Parameters for an absorption-imaging pulse on the F → F'=F+1 cycling transition.

- `F_ground::Int`:               atomic ground spin F
- `polarization::Symbol`:        `:sigma_plus | :sigma_minus | :pi`
- `saturation::Float64`:         peak s = I / I_sat
- `detuning_over_gamma::Float64`: Δ / Γ
- `t_pulse_gamma::Float64`:      dimensionless pulse time τ = Γ · t_pulse

Dimensionless time τ = Γ · t_pulse: τ ≲ 1 → linear regime,
σ_eff(m) ∝ |C(F, m, q)|²; τ ≫ 1 → pumped to stretched state.
"""
Base.@kwdef struct OpticalPumpingParams
    F_ground::Int
    polarization::Symbol
    saturation::Float64
    detuning_over_gamma::Float64
    t_pulse_gamma::Float64
end

# |⟨F+1, m+q | F, m, 1, q⟩|² closed forms for the F → F+1 dipole transition.
@inline function _absorb_cg2(F::Int, m::Int, q::Int)
    abs(m + q) > F + 1 && return 0.0
    den = float((2F + 1) * (2F + 2))
    if q == +1
        return (F + m + 1) * (F + m + 2) / den
    elseif q == -1
        return (F - m + 1) * (F - m + 2) / den
    elseif q == 0
        return 2 * (F - m + 1) * (F + m + 1) / den
    else
        throw(ArgumentError("q must be ±1 or 0 (got $q)"))
    end
end

# |⟨F, m_e − q_emit | 1, q_emit; F+1, m_e⟩|² for F+1 → F spontaneous decay.
# Atom Δm = −q_emit (σ⁺ photon emission, q_emit=+1, lowers atom m by 1).
@inline function _decay_cg2(F::Int, m_e::Int, q_emit::Int)
    den = float((2F + 1) * (2F + 2))
    if q_emit == +1
        m_g = m_e - 1
        abs(m_g) > F && return 0.0
        return (F + m_e) * (F + m_e + 1) / den
    elseif q_emit == -1
        m_g = m_e + 1
        abs(m_g) > F && return 0.0
        return (F - m_e) * (F - m_e + 1) / den
    elseif q_emit == 0
        m_g = m_e
        abs(m_g) > F && return 0.0
        return 2 * (F - m_e + 1) * (F + m_e + 1) / den
    else
        throw(ArgumentError("q_emit must be ±1 or 0 (got $q_emit)"))
    end
end

# Build the (2F+2) × (2F+2) rate matrix A acting on
#   x = [n_{-F}, n_{-F+1}, ..., n_{+F}, N_ph]
# such that dx/dτ = A · x with τ = Γ · t. Last row counts cumulative photons.
function _rate_matrix(p::OpticalPumpingParams)
    F = p.F_ground
    D = 2F + 1
    q_abs = polarization_q(p.polarization)
    lorentz = 1.0 / (1.0 + 4 * p.detuning_over_gamma^2)
    prefactor = 0.5 * p.saturation * lorentz   # (Γ/2)·s·L in units of Γ

    A = zeros(Float64, D + 1, D + 1)
    @inbounds for (i, m) in enumerate(-F:F)
        cg2_abs = _absorb_cg2(F, m, q_abs)
        cg2_abs == 0.0 && continue
        R = prefactor * cg2_abs
        A[i, i] -= R
        A[D + 1, i] += R
        m_e = m + q_abs
        for q_emit in (-1, 0, +1)
            cg2_dec = _decay_cg2(F, m_e, q_emit)
            cg2_dec == 0.0 && continue
            m_f = m_e - q_emit
            j = m_f + F + 1
            A[j, i] += R * cg2_dec
        end
    end
    A
end

"""
    build_sigma_eff_table(p::OpticalPumpingParams) -> Vector{Float64}

Return `σ_eff[i]` for ground-state index `i ∈ 1:2F+1` (i.e. m = i − F − 1).
`σ_eff[i] = ⟨N_ph⟩` integrated over the pulse, in dimensionless units.

For a stretched-state atom (m = ±F under σ±) in the low-saturation limit,
`σ_eff = (s/2) · L(Δ/Γ) · τ` with τ = `t_pulse_gamma`.
Other m_initial values yield smaller σ_eff at short τ (linear limit follows
|C(F, m, q)|² weighting) and approach the stretched value at long τ once
fully optically pumped.
"""
function build_sigma_eff_table(p::OpticalPumpingParams)
    F = p.F_ground
    D = 2F + 1
    A = _rate_matrix(p)
    # Small dim (D+1 ≤ 14 for F=6); matrix exponential is exact in floating point.
    expA = exp(A * p.t_pulse_gamma)
    Float64[expA[D + 1, i] for i in 1:D]
end
