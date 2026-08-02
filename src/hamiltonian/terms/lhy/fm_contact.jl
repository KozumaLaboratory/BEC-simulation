# fm_contact_lhy.jl
# =================================================================
# Closed-form contact LHY for spinor BECs in the FM phase
# (ζ_α = δ_{α,+F}, the m=+F polarised state).
#
# Physical justification (Watanabe-Brauner 2011 / Watanabe-Murayama 2012
# Goldstone-mode counting):
#   For the FM state, SU(2) → U(1) with broken generators (S_x, S_y) that
#   are non-commuting in the ground state ([S_x, S_y] = i⟨S_z⟩ ≠ 0). This
#   counts as a SINGLE Type-B Goldstone mode with ω ∝ k² (the FM magnon),
#   NOT the 2 transverse Type-A modes (ω ∝ k) that one would naively
#   count for SO(3) → SO(2). Type-B Goldstones have trivial u_k - v_k → 1
#   structure and contribute ZERO to the LHY zero-point integral after
#   UV subtraction.
#
# Concretely: the anomalous coupling δ_m is non-zero only for m=+F
# (pair m_total = 2F, realised only by α=β=+F). All other modes are free
# (κ_m = 0) and contribute zero LHY after UV subtraction. The closed
# form collapses to a single mode:
#
#   ε_LHY^{FM,contact}(n) = (8√M³/(15π²ℏ³)) · (n g_{2F})^(5/2)
#                         = (8/15π²) · (n g_{2F})^(5/2)        [ℏ=M=1]
#
# Goldstone identities:
#   σ_+F = δ_+F = g_{2F}                        (U(1) phonon, ω∝k)
#   2σ_+(F-1) = σ_+F                            (F_- magnon, ω∝k², type-B)
#
# For uniform g_S = c_0 (i.e. c_1 = 0), this reduces to scalar
# Lima-Pelster (no DDI): (8/15π²) (c_0 n)^(5/2). The mode adds value
# only when g_S vary across S (realistic Eu/Er/Dy a_S, or non-zero c_1).
#
# Valid for any F: `sigma_fm` / `delta_fm` are closed forms in F, and the
# single-mode result is gated against `full_bdg` (no ansatz) at F = 1..8.

export FMLHYCoefs, build_fm_lhy_coefs, lhy_energy_fm
export sigma_fm, delta_fm

include("sigma_delta_fm.jl")

"""
    FMLHYCoefs(F, sigma, delta)

Pre-computed σ_m and δ_m for FM phase (ζ_α = δ_{α,+F}). σ indexed -F..+F
via m+F+1; δ stored only at m=+F by convention since δ_m=0 elsewhere.
"""
struct FMLHYCoefs
    F::Int
    sigma::Vector{Float64}   # length 2F+1, indexed by m+F+1
    delta_F::Float64         # δ_+F (the only non-zero δ_m)
end

"""
    build_fm_lhy_coefs(F, g_dict) -> FMLHYCoefs
"""
function build_fm_lhy_coefs(F::Int, g_dict)::FMLHYCoefs
    F >= 0 || throw(ArgumentError("F must be ≥ 0"))
    sigma = zeros(Float64, 2F + 1)
    for m in (-F):F
        sigma[m + F + 1] = sigma_fm(F, m, g_dict)
    end
    FMLHYCoefs(F, sigma, delta_fm(F, F, g_dict))
end

"""
    lhy_energy_fm(n, F, g_dict; M_mass=1.0, hbar=1.0) -> Float64

Contact-only LHY energy density for an F-FM BEC at local density `n`.

Single-mode result:
  ε = (8√M³ / (15π²ℏ³)) · (n g_{2F})^(5/2)

with `g_{2F} = δ_+F = κ_+F`. Other modes are free (no anomalous coupling)
and don't contribute. For uniform `g_S = c_0` this matches the scalar
Lima-Pelster (no DDI) formula.
"""
function lhy_energy_fm(n::Float64, F::Int, g_dict;
    M_mass::Float64=1.0, hbar::Float64=1.0)::Float64
    coefs = build_fm_lhy_coefs(F, g_dict)
    return lhy_energy_fm(n, coefs; M_mass, hbar)
end

function lhy_energy_fm(n::Float64, coefs::FMLHYCoefs;
    M_mass::Float64=1.0, hbar::Float64=1.0)::Float64
    prefactor = (8.0 * sqrt(M_mass^3)) / (15.0 * π^2 * hbar^3)
    kappa = coefs.delta_F
    # `kappa < 1e-12 && return 0.0` conflated two different things. "Negligible"
    # and "negative" are not the same answer: κ = g_{2F} is the FM branch's own
    # stiffness, so κ < 0 means the ansatz this closed form is built on has a
    # negative stiffness, and returning 0.0 there reported NO LHY for a state
    # whose LHY is undefined. Reachable at F=6 whenever c₁/c₀ < −1/36 = −0.0278,
    # since g_{2F} = c₀ + 36 c₁ — measured ε_fm = 0.0 at c₁/c₀ = −0.0278 and
    # −0.05, against 10.4048 at −0.005.
    #
    # NaN is how the closed forms decline (cf. `epsilon_LHY_F6_Ih`); `_tabulate_lhy`
    # turns it into an ArgumentError naming the regime. A silent zero is worse
    # than either, and is the same shape as the six paths that dropped `ws.lhy`.
    kappa < -1e-12 && return NaN
    kappa < 1e-12 && return 0.0      # genuinely negligible coupling
    return prefactor * (n * kappa)^2.5    # ν=1, t=0, φ_1^reg(0)=1
end
