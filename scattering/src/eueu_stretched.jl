"""
High-level API for Eu+Eu scattering in the stretched channel
|F=6, m_F=-6⟩ ⊗ |F=6, m_F=-6⟩ at M_tot = -12.

At M_tot = -12 with ℓ = 0 there is a single symmetry-allowed channel:
the fully-stretched state projects entirely onto the molecular septet
(𝒮 = 7), so the coupling matrix W(R) collapses to V_{S=7}(R). Because
this is a single-channel problem, the s-wave scattering length `a`
depends on the potential shape but is magnetic-field-independent (no
closed-channel coupling without spin-dependent non-central terms such
as the magnetic DDI, which are Phase 3 scope).

Utilities here focus on reproducing the analysis of Zaremba-Kopczyk,
Żuchowski, Tomza, PRA 98, 032704 (2018), Fig. 5: scan a(λ) for
V_{S=7}(R) → λ · V_{S=7}(R). Poles in `a(λ)` correspond to the
appearance / disappearance of bound states in the septet well.
"""

"""
    eueu_stretched_swave_length(; λ = 1.0, R_min = 6.0, R_max = 200.0,
                                   h = 5e-3, u0 = (0.0, 1e-40)) → a

Zero-energy s-wave scattering length [a_0] for the Eu+Eu stretched
channel with V_{S=7}(R) → λ · V_{S=7}(R). Uses ¹⁵¹Eu reduced mass.
"""
function eueu_stretched_swave_length(;
    λ::Real = 1.0,
    R_min::Real = 6.0,
    R_max::Real = 200.0,
    h::Real = 5e-3,
    u0::Tuple{<:Real,<:Real} = (0.0, 1e-40),
)
    atom = Eu151()
    μ = reduced_mass(atom, atom)
    septet = eueu_septet_params()
    V(R) = λ * V_septet(septet, R)
    zero_energy_scattering_length(V, R_min, R_max, h;
                                   μ = μ, ℓ = 0, u0 = u0)
end

"""
    scan_eueu_septet_rescale(λs; kwargs...) → Vector{Float64}

Return `a(λ_k)` for each λ in `λs` (same keyword arguments as
`eueu_stretched_swave_length`).
"""
function scan_eueu_septet_rescale(λs::AbstractVector; kwargs...)
    [eueu_stretched_swave_length(; λ = λ, kwargs...) for λ in λs]
end
