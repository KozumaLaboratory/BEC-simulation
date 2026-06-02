export compute_interaction_params
export compute_c0, compute_c_dd, compute_a_dd
export interaction_params_from_constraint
export compute_c_total, compute_c_dd_dimless, linear_zeeman_p
export compute_eu151_interactions
export compute_lhy_2d_params
export compute_quadratic_zeeman
export get_cn

"""
    compute_interaction_params(atom; N_atoms, dims, length_scale)

Compute interaction parameters in SI units from channel-resolved scattering lengths.

For F=1: uses analytic formulas c₀ = 4πℏ²(a₀+2a₂)/(3m), c₁ = 4πℏ²(a₂−a₀)/(3m).
For F≥2: requires `atom.scattering_lengths` dict (S => a_S for all even S channels).

For atoms where individual a_S are unknown (e.g. ¹⁵¹Eu), use
`interaction_params_from_constraint(; c_total, c1_ratio, F)` instead, which
constructs InteractionParams directly from the physical constraint c₀+F²c₁ = c_total.
"""
function compute_interaction_params(
    atom::AtomSpecies;
    N_atoms::Int=1,
    dims::Int=1,
    length_scale::Float64=1.0,
)
    # NOT GENERALIZABLE: F=1 path uses analytic c0/c1, F≥2 uses tensor cache.
    # Reason: physics
    # Why: F=1 c_0/c_1 (Ohmi-Machida / Ho 1998) is a closed-form 2-channel
    #   reduction from a_0, a_2 — entire physics fits two scalars. For F≥2
    #   channel couplings g_S live in TensorInteractionCache; this function
    #   returns an empty `InteractionParams` and the tensor step takes over.
    # See: src/hamiltonian/interactions/tensor_interaction.jl, KU 2012 §3.2
    if atom.F == 1
        a0, a2, m = atom.a0, atom.a2, atom.mass
        hbar = Units.HBAR

        c0_3d = 4π * hbar^2 * (a0 + 2a2) / (3m)
        c1_3d = 4π * hbar^2 * (a2 - a0) / (3m)

        if dims == 1
            l_perp = length_scale
            c0 = c0_3d / (2π * l_perp^2) * N_atoms
            c1 = c1_3d / (2π * l_perp^2) * N_atoms
        elseif dims == 2
            l_z = length_scale
            c0 = c0_3d / (sqrt(2π) * l_z) * N_atoms
            c1 = c1_3d / (sqrt(2π) * l_z) * N_atoms
        else
            c0 = c0_3d * N_atoms
            c1 = c1_3d * N_atoms
        end

        return InteractionParams(Dict(0 => c0, 1 => c1))
    end

    if isempty(atom.scattering_lengths)
        @warn "No channel scattering lengths for F=$(atom.F) atom $(atom.name); using c0-only (c1=0)" maxlog=1
        c0 = compute_c0(atom; N_atoms, dims, length_scale)
        return InteractionParams(Dict(0 => c0))
    end
    # F ≥ 2 with full channel scattering lengths: all S-channel couplings g_S
    # live in TensorInteractionCache (built downstream in make_workspace).
    # InteractionParams holds the scalar c₀ / c₁ path; for the tensor-cache
    # path these are not used, hence zero.
    InteractionParams(Dict{Int, Float64}())
end

"""
Density-only contact interaction for general F.
c0 = 4πℏ² a_s / m (no spin channels, just s-wave scattering length a0).
"""
function compute_c0(
    atom::AtomSpecies;
    N_atoms::Int=1,
    dims::Int=1,
    length_scale::Float64=1.0,
)
    hbar = Units.HBAR
    c0_3d = 4π * hbar^2 * atom.a_s / atom.mass

    if dims == 1
        c0_3d / (2π * length_scale^2) * N_atoms
    elseif dims == 2
        c0_3d / (sqrt(2π) * length_scale) * N_atoms
    else
        c0_3d * N_atoms
    end
end

"""
DDI coupling for spinor Hamiltonian: `c_dd = μ₀ (g_F μ_B)²` (per-unit-spin).

# DO NOT MULTIPLY BY F²  ← this docstring exists because Bug-3 was an F²/36×
# regression caused by exactly that confusion. The Hamiltonian convention is

    H_dd = (c_dd / 2) ∫ d³r d³r' Σ_{αβ} F̂_α(r) Q_{αβ}(r-r') F̂_β(r')

with `F̂_α` the *operators* whose eigenvalues are `m ∈ -F..+F`. Therefore
`c_dd` carries `(g_F μ_B)²`, NOT `(g_F F μ_B)²` — the F² that maps eigenvalues
to physical magnetic moments is supplied by the operators inside the integral.

`atom.mu_mag` stores the *full* magnetic moment `g_F · F · μ_B` (saturation
moment), so we divide by F here to recover `g_F μ_B`. For ε_dd computations
use `compute_a_dd`, which does the opposite — see its docstring.

Scalar (F=0) BEC: `c_dd = μ₀ μ²` directly (no spin operators in H_dd).
"""
function compute_c_dd(atom::AtomSpecies)
    atom.mu_mag == 0.0 && return 0.0
    F = atom.F
    if F == 0
        return Units.MU_0 * atom.mu_mag^2
    end
    mu_gF = atom.mu_mag / F  # = g_F × μ_B  (DO NOT MULTIPLY BY F)
    Units.MU_0 * mu_gF^2
end

"""
Dipolar length: a_dd = μ₀ μ² m / (12π ℏ²), using full magnetic moment μ = g_F F μ_B.

Note: a_dd uses the full moment (not divided by F) because ε_dd = a_dd/a_s is
defined for the physical DDI strength, independent of the Hamiltonian convention.
The F² from the spin operators is accounted for separately in ε_dd calculations.
"""
function compute_a_dd(atom::AtomSpecies)
    atom.mu_mag == 0.0 && return 0.0
    Units.MU_0 * atom.mu_mag^2 * atom.mass / (12π * Units.HBAR^2)
end

function compute_interaction_params_dimless(
    atom::AtomSpecies;
    N_atoms::Int=1,
    dims::Int=1,
    omega::Float64=1.0,
)
    hbar = Units.HBAR
    m = atom.mass
    a_ho = sqrt(hbar / (m * omega))

    params_si = compute_interaction_params(atom; N_atoms, dims, length_scale=a_ho)

    energy_scale = hbar * omega
    InteractionParams(Dict(0 => params_si[0] / energy_scale,
        1 => params_si[1] / energy_scale))
end

"""
    _c0c1_to_gS(F, c0, c1) → Dict{Int,Float64}

Convert physical density (c₀) and spin (c₁) couplings to channel couplings g_S:
  g_S = c₀ + c₁(S(S+1) − 2F(F+1))/2

This is the physical relation, NOT the 6j tensor transform. It gives:
- F=1: g₀ = c₀ − 2c₁, g₂ = c₀ + c₁  (exact: 2 params → 2 channels)
- General F: g_S for all even S ∈ 0:2:2F

For F≥2, two parameters (c₀, c₁) constrain F+1 independent channels g_S to a
one-parameter family. This is appropriate when higher scattering lengths are
unknown (e.g. Eu151). To specify independent g_S, provide higher-rank c_n
couplings (n ≥ 4) via the InteractionParams Dict, or use
`_make_tensor_cache_from_channels` directly.
"""
function _c0c1_to_gS(F::Int, c0::Float64, c1::Float64)
    Dict{Int, Float64}(S => c0 + c1 * (S * (S + 1) - 2 * F * (F + 1)) / 2 for S in 0:2:2F)
end

"""
    c_to_g(F::Int, ip::InteractionParams) → Dict{Int,Float64}

Map the c_n couplings to channel couplings g_S for S ∈ 0:2:2F.

The c_n keys carry two physics conventions that combine into the same
g_S Dict:

  c_0    rank-0 identity              → constant: g_S += c_0
  c_1    F̂·F̂ scalar product           → linear-in-S(S+1): g_S += c_1·λ_S
                                          where λ_S = (S(S+1) − 2F(F+1))/2
  c_k    rank-k tensor T̂^(k)·T̂^(k)    → Wigner 6j: g_S += (2k+1)·{F F k; F F S}·c_k
         (k ≥ 2, even)

The two conventions have different numerical normalisations (c_1
specifically is in the Kawaguchi-Ueda "F̂·F̂" form, not the rank-1 6j
form), so the n=0,1 entries route through the closed-form `_c0c1_to_gS`
while n≥2 entries route through the 6j transform `_dict_to_delta_gS`.
"""
function c_to_g(F::Int, ip::InteractionParams)
    g = _c0c1_to_gS(F, ip[0], ip[1])
    delta = _dict_to_delta_gS(F, ip.c)
    isempty(delta) && return g
    for (S, dg) in delta
        g[S] = get(g, S, 0.0) + dg
    end
    g
end

"""
    _dict_to_delta_gS(F, c_dict) → Dict{Int,Float64}

Convert higher-rank tensor couplings c_k (n ≥ 2) to channel coupling
perturbations δg_S via 6j transform. Takes the same Dict that
`InteractionParams.c` stores (keys 0, 1, 2, 4, 6, ...) and processes
ONLY even-rank entries with k ≥ 2 and k ≤ 2F. Lower ranks (n=0, n=1)
are c_0, c_1 and routed through diagonal + spin_mixing steps separately.

Odd-rank n ≥ 3 entries are not allowed in `InteractionParams.c` (the
constructor rejects them) so any encountered here would indicate a
direct field-access bypass; we re-check defensively.
"""
function _dict_to_delta_gS(F::Int, c_dict::Dict{Int, Float64})
    for (k, val) in c_dict
        if k >= 3 && isodd(k) && is_active(val)
            throw(
                ArgumentError(
                    "c_$k is odd-rank and not a physical tensor coupling. " *
                    "Use _make_tensor_cache_from_channels(F, Dict(S => g_S, ...)) " *
                    "for KU-style pair-channel couplings."),
            )
        end
        # Silent-drop guard: reject k > 2F so high-rank entries don't
        # silently disappear when the user passes c_8 for an F=2 atom.
        if k > 2F && is_active(val)
            throw(
                ArgumentError(
                    "c_$k coupling supplied but F=$F only supports up to c_$(2F). " *
                    "Either set the entry to 0 or use a larger F."),
            )
        end
    end
    extra = Dict{Int, Float64}()
    for (k, val) in c_dict
        k >= 2 && k <= 2F && iseven(k) && is_active(val) && (extra[k] = val)
    end
    isempty(extra) && return Dict{Int, Float64}()
    _cn_to_gS(F, extra)
end

"""
    interaction_params_from_constraint(; c_total, c1_ratio, F, c_extra)

Compute c₀, c₁ satisfying the physical constraint c₀ + F²c₁ = c_total.

For atoms where individual scattering lengths a_S are unknown (e.g. ¹⁵¹Eu),
the total contact interaction c_total = 4π(a_s/a_ho)N is known but the
spin-dependent split c₁/c₀ is a free parameter. This function parameterizes
by ratio r = c₁/c₀:

  c₀ = c_total / (1 + F²r)
  c₁ = r × c₀

The optional `c_extra::Dict{Int, Float64}` provides higher-rank tensor
couplings keyed by rank (`c_extra[4] = c₄`, `c_extra[6] = c₆`, …). When
any even-rank entry with k ≥ 4 is nonzero, `make_workspace` activates the
tensor interaction path and zeros c₀/c₁.

Example with c₄ = 50:

    ip = interaction_params_from_constraint(;
        c_total=4689.0, c1_ratio=1/36, F=6,
        c_extra=Dict(4 => 50.0))

Note: r = -1/F² is singular (c₀ → ∞). For F=6, avoid r ≤ -1/36.
"""
function interaction_params_from_constraint(;
    c_total::Float64,
    c1_ratio::Float64=0.0,
    F::Int,
    c_extra::Dict{Int, Float64}=Dict{Int, Float64}(),
)
    if !isempty(c_extra) && any(!iszero, values(c_extra))
        @warn """interaction_params_from_constraint: c_total constraint applies only to the
                 c_0/c_1 textbook truncation. With nonzero c_extra (higher-rank tensor channels)
                 the tensor path takes over and the physical stretched-pair coupling g_{S=2F}
                 is determined by Wigner-6j transform, NOT by c_0 + F²·c_1 = c_total.
                 For SBI / inverse-problem work, parameterize in the channel basis {g_S}
                 directly via `_make_tensor_cache_from_channels(F, Dict(S => g_S))`.""" maxlog=1
    end
    c0 = c_total / (1.0 + F^2 * c1_ratio)
    c1 = c1_ratio * c0
    full = merge(Dict(0 => c0, 1 => c1), c_extra)
    InteractionParams(full)
end

"""
    compute_c_total(atom; N_atoms, omega_ref)

Total contact interaction c_total = 4π(a_s/a_ho)N in dimensionless units (3D).
"""
function compute_c_total(atom::AtomSpecies; N_atoms::Int, omega_ref::Float64)
    a_ho = sqrt(Units.HBAR / (atom.mass * omega_ref))
    4π * (atom.a_s / a_ho) * N_atoms
end

"""
    compute_c_dd_dimless(atom; N_atoms, omega_ref)

Dimensionless DDI coupling: c_dd = N × μ₀μ² / (ℏω × a_ho³).
"""
function compute_c_dd_dimless(atom::AtomSpecies; N_atoms::Int, omega_ref::Float64)
    a_ho = sqrt(Units.HBAR / (atom.mass * omega_ref))
    N_atoms * compute_c_dd(atom) / (Units.HBAR * omega_ref * a_ho^3)
end

"""
    compute_quadratic_zeeman(atom; p_dimless, omega_ref) -> q_dimless

Second-order Zeeman shift coefficient `q` (dimensionless, in ℏω_ref units)
from rigorous Breit-Rabi for the F=I+J ground manifold. Uses the closed-form
geometry factor stored on each AtomSpecies.

Formula (closed-form 2nd-order PT, F coupled to F-1 via J_z):

    q_phys = (g_J μ_B B)² · q_geometry / |Δ_hf|

In dimensionless internal units (B → p via p = g_F μ_B B / ℏω_ref):

    q_dimless = q_phys / (ℏω_ref)
              = p² · ω_ref · ℏ · (g_J/g_F)² · q_geometry / Δ_hf

For Eu151 F=6: q_geometry = 35/144, exact (m⁴ correction zero at 2nd order).

Returns 0.0 if the atom lacks `Delta_E_hf` or `q_geometry` (not derivable);
caller is responsible for either setting `q` explicitly or refusing to
proceed.
"""
function compute_quadratic_zeeman(atom::AtomSpecies; p_dimless::Real, omega_ref::Real)
    atom.Delta_E_hf > 0 && atom.g_J > 0 && atom.q_geometry > 0 || return 0.0
    Δ_rad_s = atom.Delta_E_hf / Units.HBAR
    Float64(p_dimless)^2 * omega_ref * (atom.g_J / atom.g_F)^2 *
    atom.q_geometry / Δ_rad_s
end

"""
    compute_eu151_interactions(; N_atoms, omega_ref, c1_ratio, c_extra)

Dimensionless interaction params for ¹⁵¹Eu (F=6) with mandatory c₁/c₀ ratio.

Individual scattering lengths a_S are unknown for Eu, so `compute_interaction_params`
falls back to c₁=0 with a warning. This wrapper prevents that silent fallback by
requiring an explicit `c1_ratio`.

Physical estimates for c1_ratio:
- `0.0`: DDI-only (c₁=0, no spin-dependent contact)
- `1/36`: Buchachenko et al. antiferromagnetic estimate
- negative: ferromagnetic

Returns `InteractionParams` with c₀+F²c₁ = 4π(a_s/a_ho)N.
"""
function compute_eu151_interactions(;
    N_atoms::Int,
    omega_ref::Float64,
    c1_ratio::Float64,
    c_extra::Dict{Int, Float64}=Dict{Int, Float64}(),
)
    c_total = compute_c_total(Eu151; N_atoms, omega_ref)
    interaction_params_from_constraint(; c_total, c1_ratio, F=6, c_extra)
end

"""
    linear_zeeman_p(atom, B, omega_ref)

Dimensionless linear Zeeman shift: p = g_F × μ_B × B / (ℏ × omega_ref).
"""
function linear_zeeman_p(atom::AtomSpecies, B::Float64, omega_ref::Float64)
    atom.g_F * Units.MU_BOHR * B / (Units.HBAR * omega_ref)
end

# --- Quasi-2D LHY ---

"""
    compute_lhy_2d_params(c0_2d, l_z) → Quasi2DLHY

Quasi-2D LHY correction: ε_LHY ∝ n² ln(n a²_2d).
Ref: Petrov & Astrakharchik, PRL 117, 100401 (2016).
"""
function compute_lhy_2d_params(c0_2d::Float64, l_z::Float64)
    γ_E = 0.5772156649015329
    log_const = 2.0 * γ_E - 1.0 - log(2.0)
    c_lhy_2d = c0_2d^2 / (4.0 * Float64(π))
    a_2d_sq = l_z^2
    Quasi2DLHY(c_lhy_2d, a_2d_sq, log_const)
end

# --- Lima-Pelster DDI-corrected LHY ---

"""
    _gauss_legendre(n, a, b) → (nodes, weights)

n-point Gauss-Legendre quadrature on [a, b].
"""
function _gauss_legendre(n::Int, a::Float64, b::Float64)
    nodes = zeros(Float64, n)
    weights = zeros(Float64, n)
    m = div(n + 1, 2)
    mid = (a + b) / 2
    half = (b - a) / 2

    for i in 1:m
        z = cos(π * (i - 0.25) / (n + 0.5))
        for _ in 1:100
            p1 = 1.0
            p2 = 0.0
            for j in 1:n
                p3 = p2
                p2 = p1
                p1 = ((2j - 1) * z * p2 - (j - 1) * p3) / j
            end
            pp = n * (z * p1 - p2) / (z^2 - 1.0)
            dz = p1 / pp
            z -= dz
            abs(dz) < 1e-15 && break
        end
        nodes[i] = mid - half * z
        nodes[n + 1 - i] = mid + half * z
        # Recompute P_n and P_n' at the converged z (pp from the Newton loop
        # was evaluated at z+dz, before the final update).
        p1 = 1.0;
        p2 = 0.0
        for j in 1:n
            p3 = p2;
            p2 = p1
            p1 = ((2j - 1) * z * p2 - (j - 1) * p3) / j
        end
        pp_final = n * (z * p1 - p2) / (z^2 - 1.0)
        w = 2.0 * half / ((1.0 - z^2) * pp_final^2)
        weights[i] = w
        weights[n + 1 - i] = w
    end
    (nodes, weights)
end

export lima_pelster_Q5, compute_c_lhy_with_ddi

"""
    lima_pelster_Q5(eps_dd) → Float64

Lima-Pelster correction factor Q₅(ε_dd) for the LHY energy of a dipolar BEC:

    Q₅ = ∫₀^π (sinθ / 2) [1 + ε_dd(3cos²θ - 1)]^{5/2} dθ

Ref: Lima & Pelster, PRA 84, 041604(R) (2011).

Returns 1.0 for ε_dd=0. Throws DomainError if the integrand becomes negative
(argument < 0 inside the 5/2 power).
"""
function lima_pelster_Q5(eps_dd::Float64)
    abs(eps_dd) < 1e-15 && return 1.0

    nodes, weights = _gauss_legendre(20, 0.0, Float64(π))
    s = 0.0
    for i in eachindex(nodes)
        theta = nodes[i]
        ct = cos(theta)
        arg = 1.0 + eps_dd * (3.0 * ct^2 - 1.0)
        s += weights[i] * sin(theta) / 2.0 * (arg >= 0.0 ? arg^(5 / 2) : 0.0)
    end
    s
end

"""
    compute_c_lhy_with_ddi(c_lhy_scalar, eps_dd) → Float64

Apply the Lima-Pelster DDI correction to a scalar LHY coefficient:
    c_lhy_corrected = c_lhy_scalar × Q₅(ε_dd)
"""
function compute_c_lhy_with_ddi(c_lhy_scalar::Float64, eps_dd::Float64)
    c_lhy_scalar * lima_pelster_Q5(eps_dd)
end
