export compute_spinor_lhy_polar_two_channel, compute_spinor_lhy_table
export compute_spinor_lhy_polar_contact, compute_spinor_lhy_polar_dipolar
export compute_spinor_lhy_fm_contact, compute_spinor_lhy_fm_dipolar
export compute_spinor_lhy_icosahedral
export make_lhy

# NOT GENERALIZABLE: two-channel (c_0/c_1) LHY is exact only at F=1 polar.
# Reason: physics
# Why: TwoChannel keeps the m=0 phonon plus 2 SO(3) Goldstones (3 of 2F+1
#   modes); the m=±2..±F gapped modes carry non-zero anomalous coupling
#   whenever g_S varies across S, generic for F≥2. ~0.3-1.5% at F=2,
#   ~3-9% at F=3, **30-70% at F=6**. Prefer PolarContact / FMContact /
#   IcosahedralLHY closed forms for F≥2.
# See: src/hamiltonian/interactions/lhy/polar_contact.jl, dispatch.jl docstring below

"""
    compute_spinor_lhy_polar_two_channel(; F, c0, c1, c_dd, n_max, n_points) → PolarTwoChannelLHY

**Polar-state LHY in the two-channel approximation.** For ζ_α = δ_{α,0}
(m=0 condensate; SO(3)→SO(2) broken with 2F Type-A Goldstones):

    ε_LHY = (8/15π²) [c0^(5/2) n^(5/2) Q5(ε_dd) + 2F |c1|^(5/2) n^(5/2)]

- Density term `c0^(5/2)` corresponds to the polar density stiffness
  (mean field ⟨F⟩=0 ⇒ stiffness = c0).
- Spin term `2F · |c1|^(5/2)` counts the 2F Type-A transverse magnons
  with stiffness c1. At F=1 this reproduces the standard polar LHY
  result (Lavoine-Bourdel 2021 / Petrov 2014 form).

**Do NOT use for FM (m=±F) states.** For maximally-stretched FM the
broken generators are non-commuting (S_x, S_y with ⟨S_z⟩ ≠ 0) →
**1 Type-B Goldstone with ω∝k²**, and the FM magnon Bogoliubov modes
have anomalous coupling κ = 0 — they vanish from the LHY zero-point
integral after UV subtraction. The FM closed form is single-mode:
ε_LHY^FM = (8/15π²)(g_{2F} n)^(5/2), implemented in `FMContactLHY` via
`compute_spinor_lhy_fm_contact`. Using the two-channel formula on a FM
state with `c0=10, c1=-0.5` would spuriously add a non-zero spin term.

**Regimes of validity** (polar state assumed):
- **F = 1**: exact (Yi-You 2001 / Lavoine-Bourdel; even-S channels are
  {0, 2} only, fully parameterised by (c0, c1)).
- **F = 2**: approximate (~0.3-1.5% error vs `compute_spinor_lhy_polar_contact`
  at higher-rank=0 and natural parameter scales). Acceptable for rough
  estimates; prefer the closed form for production work.
- **F ≥ 3**: increasingly inaccurate. At F=3, error ~3-9% vs PolarContact.
  At F=6 the error reaches **30-70%** because TwoChannel only captures
  the m=0 phonon + 2 (m=±1) SO(3) Goldstones (3 of 2F+1 = 13 modes for
  F=6), dropping all m=±2..±F gapped modes whose anomalous coupling
  is non-zero whenever g_S varies across S. The c0/c1 → g_S relation
  `g_S = c0 + c1·(S(S+1)−2F(F+1))/2` produces a non-trivial g_S spread
  even at higher-rank=0, so the gapped-mode contributions are NOT zero.

For F ≥ 2 polar use `compute_spinor_lhy_polar_contact` (paper #1
F-generic closed form) instead. For F ≥ 2 with higher-rank couplings (higher-S
channels independently set) the TwoChannel approximation deteriorates
further — PolarContact is the right tool.

The potential V_LHY = dε_LHY/dn is tabulated via central differences.
"""
function compute_spinor_lhy_polar_two_channel(;
    F::Int,
    c0::Float64,
    c1::Float64,
    c_dd::Float64=0.0,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    F >= 1 || throw(ArgumentError("F must be ≥ 1 (got F=$F)"))
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))

    eps_dd = is_active(c0) ? c_dd / c0 : 0.0
    Q5 = lima_pelster_Q5(eps_dd)

    densities = collect(range(0.0, n_max; length=n_points))

    prefactor = 8.0 / (15.0 * Float64(π)^2)
    energy = zeros(Float64, n_points)

    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        n52 = n^2 * sqrt(n)
        density_part = is_active(c0) ? abs(c0)^(5 / 2) * n52 * Q5 : 0.0
        spin_part = is_active(c1) ? 2.0 * F * abs(c1)^(5 / 2) * n52 : 0.0
        energy[i] = prefactor * (density_part + spin_part)
    end

    potential_values = _numerical_derivative(densities, energy)
    PolarTwoChannelLHY(densities, potential_values)
end

"""
    compute_spinor_lhy_table(; spinor, F, interactions, zeeman, c_dd,
                               n_max, n_points, k_max, n_k) → FullBdGLHY

Full BdG-based spinor LHY: at each density, compute zero-point energy from
the Bogoliubov spectrum and tabulate V_LHY = dε_LHY/dn.
"""
function compute_spinor_lhy_table(;
    spinor::Vector{ComplexF64},
    F::Int,
    interactions::InteractionParams,
    zeeman::ZeemanParams=ZeemanParams(),
    c_dd::Float64=0.0,
    n_max::Float64=100.0,
    n_points::Int=100,
    k_max::Float64=20.0,
    n_k::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    D = 2F + 1
    length(spinor) == D ||
        throw(DimensionMismatch("spinor length $(length(spinor)) != 2F+1 = $D"))

    # NOT GENERALIZABLE: FullBdG LHY produces a spurious 3000× offset for F=6 polar.
    # Reason: physics
    # Why: BdG diagonalisation of F=6 polar mean field produces λ<0 modes that
    #   break Petrov's UV regularisation (negative-eigenvalue branch picks up
    #   unphysical phase in zero-point integral). FullBdG remains correct for
    #   other phases; only F=6 + ζ_α = δ_{α,0} is broken.
    # See: memory/full_bdg_F6_polar_broken.md
    if F == 6 && _is_polar_spinor(spinor)
        @warn "FullBdG LHY (compute_spinor_lhy_table) is known to produce a ~3000× " *
            "spurious energy offset for F=6 polar (ζ_α = δ_{α,0}) initial states " *
            "due to λ<0 BdG modes breaking Petrov regularization. Use " *
            "compute_spinor_lhy_polar_contact (or compute_spinor_lhy_polar_dipolar " *
            "with DDI) for F=6 polar; FullBdG remains valid for other phases." maxlog=1
    end

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)

    for (i, n0) in enumerate(densities)
        n0 < 1e-30 && continue
        energy[i] = _compute_lhy_at_density(spinor, n0, F, interactions, zeeman, c_dd, k_max, n_k)
    end

    potential_values = _numerical_derivative(densities, energy)
    FullBdGLHY(densities, potential_values)
end

# Detect "polar" spinor: m=0 channel dominates (purity > 99%).
function _is_polar_spinor(spinor::Vector{ComplexF64}; purity_threshold::Float64=0.99)
    D = length(spinor)
    D % 2 == 1 || return false
    F = (D - 1) ÷ 2
    isapprox(sum(abs2, spinor), 0.0; atol=1e-12) && return false
    total = sum(abs2, spinor)
    abs2(spinor[F + 1]) / total >= purity_threshold
end

"""
Compute BdG zero-point energy at a single density:
ε_LHY(n) = (1/2) × (1/2π²) ∫ dk k² Σ_b [ω_b(k) - ε_k - μ_b + μ²_b/(2ε_k)]
"""
function _compute_lhy_at_density(
    spinor, n0, F, interactions, zeeman, c_dd, k_max, n_k;
    n_dir::Int=32,
)
    D = 2F + 1
    h_mf, M_anom, zee, _ = _bdg_contact_matrices(spinor, F, interactions, zeeman)

    if is_active(c_dd)
        # The LHY zero-point integral inherits the DDI's k̂-anisotropy via
        # `_q_tensor_direction(k̂)` — the spherical average of the per-mode
        # ω_b(k) is anisotropic, so direction sampling matters. The earlier
        # 6-axis octahedron is exact only for `ℓ ≤ 3`; the DDI Q-tensor
        # mixes `ℓ = 0, 2` and BdG correction adds `ℓ ≤ 4`. Switch to a
        # quasi-uniform Fibonacci-spiral grid (default 32 = 64 antipodal
        # samples) so the integration error stops dominating the absolute
        # LHY shift. Caller can tune `n_dir` for tight budget.
        sm = spin_matrices(F)
        dirs = fibonacci_sphere_directions(n_dir)
        n_dir = length(dirs)
    else
        n_dir = 1
        dirs = [(0.0, 0.0, 1.0)]
        sm = nothing
    end

    # μ = ⟨ψ|(Z + n0 h_mf)|ψ⟩ — the diagonal-only `sum(...|ψ_c|²)` form
    # was correct only for single-m states. Mirrors the matching fix in
    # phases/bogoliubov.jl (2026-04-26).
    H_mu_lhy = Diagonal(zee) .+ n0 .* h_mf
    mu = real(dot(spinor, H_mu_lhy * spinor))

    k_values = collect(range(1e-6, k_max; length=n_k))
    dk = k_values[2] - k_values[1]

    E_total = 0.0
    for dir in dirs
        h_total = copy(h_mf)
        M_total = copy(M_anom)

        if is_active(c_dd)
            k_hat = collect(dir)
            k_norm = norm(k_hat)
            k_norm > 0 && (k_hat ./= k_norm)
            Q_ab = _q_tensor_direction(k_hat)
            h_ddi, M_ddi = _bdg_ddi_matrices(spinor, F, D, sm, c_dd, Q_ab)
            h_total .+= h_ddi
            M_total .+= M_ddi
        end

        for k in k_values
            ek = k^2 / 2

            L = 2n0 .* h_total
            for i in 1:D
                L[i, i] += ek - mu + zee[i]
            end
            M_sc = n0 .* M_total

            H_bdg = zeros(ComplexF64, 2D, 2D)
            H_bdg[1:D, 1:D] .= L
            H_bdg[1:D, (D + 1):2D] .= M_sc
            H_bdg[(D + 1):2D, 1:D] .= .-conj.(M_sc)
            H_bdg[(D + 1):2D, (D + 1):2D] .= .-conj.(L)

            # mu_b is the per-branch large-k asymptote subtracted to make
            # the LHY k-integrand convergent. For each ω-branch we find
            # the dominant spinor component c* of the BdG eigenvector and
            # use the matching diagonal entry — was hard-coded to c=1
            # (m=+F), which only holds for a fully polarized GS along +z.
            evals_full = eigen(H_bdg)
            evals = evals_full.values
            evecs = evals_full.vectors
            zpe = 0.0
            for (eb, ev) in enumerate(evals)
                omega = real(ev)
                omega > 1e-10 || continue
                # particle-branch lives in the upper D rows; pick the
                # dominant component there to label the asymptote
                u_part = view(evecs, 1:D, eb)
                c_star = argmax(abs2.(u_part))
                mu_b = ek + n0 * real(h_total[c_star, c_star]) - mu + zee[c_star]
                correction = omega - ek - mu_b + mu_b^2 / (2.0 * max(ek, 1e-30))
                zpe += 0.5 * correction
            end

            E_total += k^2 * zpe * dk / (2.0 * Float64(π)^2)
        end
    end

    E_total / n_dir
end

# =================================================================
# Closed-form polar LHY wrappers (PhiOneReg + PolarContactMod + PolarDipolarMod)
# =================================================================
#
# These produce a TabulatedLHY identical in shape to :polar_two_channel /
# :full_bdg, so the downstream evaluator (apply_lhy_step!) treats them
# uniformly.

"""
    compute_spinor_lhy_polar_contact(; F, g_dict, n_max, n_points) → PolarContactLHY

F-polar contact LHY closed form (paper #1 main result, F-generic).
`g_dict` maps even total-spin channels S → g_S. Returns a `PolarContactLHY`
with `mode = :polar_contact`.

Two orders of magnitude faster than `compute_spinor_lhy_table` (`:full_bdg`)
because the BdG diagonalisation collapses to per-mode eigvals via the
σ/δ algebra. Restricted to polar phases (ζ_α = δ_{α,0}); for non-polar
spinors fall back to `:full_bdg`.
"""
function compute_spinor_lhy_polar_contact(;
    F::Int,
    g_dict,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))
    coefs = PolarContactMod.build_polar_lhy_coefs(F, g_dict)

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        energy[i] = PolarContactMod.lhy_energy_polar(n, coefs)
    end
    potential_values = _numerical_derivative(densities, energy)
    PolarContactLHY(densities, potential_values)
end

"""
    compute_spinor_lhy_polar_dipolar(; F, g_dict, eps_tilde_dd, n_max, n_points) → PolarDipolarLHY

F-polar contact + DDI LHY closed form (paper #1 with dipolar extension,
F-generic). `eps_tilde_dd` is the dimensionless DDI/contact ratio for the
|m|=1 antisym channel (caller convention). `eps_tilde_dd = 0` reduces to
the contact-only result exactly.
"""
function compute_spinor_lhy_polar_dipolar(;
    F::Int,
    g_dict,
    eps_tilde_dd::Float64,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))
    coefs = PolarContactMod.build_polar_lhy_coefs(F, g_dict)

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        energy[i] = PolarDipolarMod.lhy_energy_polar_dipolar(n, coefs, eps_tilde_dd)
    end
    potential_values = _numerical_derivative(densities, energy)
    PolarDipolarLHY(densities, potential_values)
end

"""
    compute_spinor_lhy_fm_dipolar(; F, g_dict, eps_dd, n_max, n_points) → FMDipolarLHY

F-FM contact + DDI LHY closed form via Lima-Pelster Q_5 angular average
(Stage C scalar reduction, Saito-Li 2024 convention). Single-mode at
m=+F dressed by `Q_5(eps_dd)`. `eps_dd = 0` reduces to the pure-contact
FM closed form (`compute_spinor_lhy_fm_contact`) exactly.
"""
function compute_spinor_lhy_fm_dipolar(;
    F::Int,
    g_dict,
    eps_dd::Real,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))
    coefs = FMContactMod.build_fm_lhy_coefs(F, g_dict)

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        energy[i] = FMDipolarMod.lhy_energy_fm_dipolar(n, coefs, eps_dd)
    end
    potential_values = _numerical_derivative(densities, energy)
    FMDipolarLHY(densities, potential_values)
end

"""
    compute_spinor_lhy_fm_contact(; F, g_dict, n_max, n_points) → FMContactLHY

F-FM contact LHY closed form (paper #2 contact-only piece, F=6 for now).
For an FM-polarised condensate (ζ_α = δ_{α,+F}), the closed form collapses
to a single mode at m=+F: ε = (8/15π²) (g_{2F} n)^(5/2). For uniform
g_S = c_0 this is identical to scalar Lima-Pelster (no DDI). The mode
adds value with non-uniform g_S (realistic a_S per S channel) or for
the "Stage C" DDI extension once that closed form lands.
"""
function compute_spinor_lhy_fm_contact(;
    F::Int,
    g_dict,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))
    coefs = FMContactMod.build_fm_lhy_coefs(F, g_dict)

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        energy[i] = FMContactMod.lhy_energy_fm(n, coefs)
    end
    potential_values = _numerical_derivative(densities, energy)
    FMContactLHY(densities, potential_values)
end

"""
    compute_spinor_lhy_icosahedral(; F, g_dict, n_max, n_points) → IcosahedralLHY

F=6 icosahedral (I_h) phase contact LHY closed form (Stage D, parallel-
session derivation 2026-05-07). Universal structure
`ε = (8/15π²) n^(5/2) (c_0^(5/2) + 3 |λ_spin|^(5/2))` with stiffnesses
`(c_0, λ_spin) = compute_c0_lambda_F6_Ih(g_dict)`. Restricted to F=6.

`g_2`, `g_4`, `g_8` cancel exactly under I_h harmonic decomposition —
non-zero values are accepted but do not affect the LHY potential.
Scalar limit (uniform `g_S = g`) reduces to `(8/15π²)(g·n)^(5/2)`.
"""
function compute_spinor_lhy_icosahedral(;
    F::Int,
    g_dict,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    F == 6 || throw(
        ArgumentError(
            "compute_spinor_lhy_icosahedral is F=6 only (got F=$F); the I_h closed " *
            "form is specific to the F=6 even-S channel structure"),
    )
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        energy[i] = IcosahedralMod.epsilon_LHY_F6_Ih(n, g_dict)
    end
    potential_values = _numerical_derivative(densities, energy)
    IcosahedralLHY(densities, potential_values)
end

"""
    make_lhy(state::Symbol; ddi::Bool=false, F::Int, kwargs...) → TabulatedLHY

Factory dispatcher for spinor LHY tables. Routes to the appropriate closed-form
or BdG implementation based on `(state, ddi)` and validates F-range constraints.

| state         | ddi=false                          | ddi=true                          |
|---------------|------------------------------------|-----------------------------------|
| :polar        | `compute_spinor_lhy_polar_contact` | `compute_spinor_lhy_polar_dipolar`|
| :fm           | `compute_spinor_lhy_fm_contact`    | `compute_spinor_lhy_fm_dipolar`   |
| :icosahedral  | `compute_spinor_lhy_icosahedral`   | (no closed form yet — errors)     |
| :polar_two_channel  | `compute_spinor_lhy_polar_two_channel`   | (eps_dd via kwarg)                |
| :full_bdg     | `compute_spinor_lhy_table`         | (c_dd via kwarg)                  |

Constraints (mirrored from per-function checks):
- `:icosahedral` requires `F == 6`.
- `:polar_two_channel` warns above `F=2` (~30-70% off at F=6; see this file's
  docstring on `compute_spinor_lhy_polar_two_channel`).

Existing `compute_spinor_lhy_*` functions remain the underlying implementations
and direct callers (incl. `make_workspace` Val-dispatch) are unchanged. This
factory is a thin convenience wrapper for callers that prefer `(state, ddi, F)`
over remembering the per-mode function name.
"""
function make_lhy(state::Symbol; ddi::Bool=false, F::Int, kwargs...)
    if state === :polar
        return if ddi
            compute_spinor_lhy_polar_dipolar(; F, kwargs...)
        else
            compute_spinor_lhy_polar_contact(; F, kwargs...)
        end
    elseif state === :fm
        return if ddi
            compute_spinor_lhy_fm_dipolar(; F, kwargs...)
        else
            compute_spinor_lhy_fm_contact(; F, kwargs...)
        end
    elseif state === :icosahedral
        F == 6 || throw(
            ArgumentError(
                "make_lhy(:icosahedral) is F=6 only (got F=$F); the I_h closed " *
                "form is specific to the F=6 even-S channel structure"),
        )
        ddi && throw(
            ArgumentError(
                ":icosahedral + ddi=true has no closed form yet; use ddi=false " *
                "or fall back to make_lhy(:polar_two_channel, ddi=true)"),
        )
        return compute_spinor_lhy_icosahedral(; F, kwargs...)
    elseif state === :polar_two_channel
        F <= 2 || @warn (
            "make_lhy(:polar_two_channel) above F=2 is approximate " *
            "(~30-70% error at F=6); prefer :polar (paper #1 closed form) for F≥2."
        ) maxlog=1
        return compute_spinor_lhy_polar_two_channel(; F, kwargs...)
    elseif state === :full_bdg
        return compute_spinor_lhy_table(; F, kwargs...)
    else
        throw(
            ArgumentError(
                "make_lhy: unknown state=:$state. Known: " *
                ":polar, :fm, :icosahedral, :polar_two_channel, :full_bdg"),
        )
    end
end

function _numerical_derivative(x::Vector{Float64}, y::Vector{Float64})
    n = length(x)
    dy = zeros(Float64, n)
    n < 2 && return dy

    dy[1] = (y[2] - y[1]) / (x[2] - x[1])
    dy[n] = (y[n] - y[n - 1]) / (x[n] - x[n - 1])
    for i in 2:(n - 1)
        dy[i] = (y[i + 1] - y[i - 1]) / (x[i + 1] - x[i - 1])
    end
    dy
end
