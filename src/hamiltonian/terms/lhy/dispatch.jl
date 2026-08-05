export compute_spinor_lhy_polar_two_channel
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
# See: src/hamiltonian/terms/lhy/polar_contact.jl, dispatch.jl docstring below

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
    n_atoms::Int=1,
)
    F >= 1 || throw(ArgumentError("F must be ≥ 1 (got F=$F)"))

    eps_dd = is_active(c0) ? c_dd / c0 : 0.0
    Q5 = lima_pelster_Q5(eps_dd)
    prefactor = 8.0 / (15.0 * Float64(π)^2)
    density_coef = is_active(c0) ? abs(c0)^(5 / 2) * Q5 : 0.0
    spin_coef = is_active(c1) ? 2.0 * F * abs(c1)^(5 / 2) : 0.0

    _tabulate_lhy(PolarTwoChannelLHY; n_max, n_points, n_atoms) do n
        prefactor * (density_coef + spin_coef) * n^2 * sqrt(n)
    end
end

# =================================================================
# Closed-form polar LHY wrappers (phi_one_reg + polar_contact + polar_dipolar)
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
    n_atoms::Int=1,
)
    coefs = build_polar_lhy_coefs(F, g_dict)
    _tabulate_lhy(n -> lhy_energy_polar(n, coefs), PolarContactLHY; n_max, n_points, n_atoms)
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
    n_atoms::Int=1,
)
    coefs = build_polar_lhy_coefs(F, g_dict)
    _tabulate_lhy(n -> lhy_energy_polar_dipolar(n, coefs, eps_tilde_dd),
        PolarDipolarLHY; n_max, n_points, n_atoms)
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
    n_atoms::Int=1,
)
    coefs = build_fm_lhy_coefs(F, g_dict)
    _tabulate_lhy(n -> lhy_energy_fm_dipolar(n, coefs, eps_dd),
        FMDipolarLHY; n_max, n_points, n_atoms)
end

"""
    compute_spinor_lhy_fm_contact(; F, g_dict, n_max, n_points) → FMContactLHY

F-FM contact LHY closed form (paper #2 contact-only piece). Any F: the
single-mode collapse is gated against `full_bdg` at F = 1..8.
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
    n_atoms::Int=1,
)
    coefs = build_fm_lhy_coefs(F, g_dict)
    _tabulate_lhy(n -> lhy_energy_fm(n, coefs), FMContactLHY; n_max, n_points, n_atoms)
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
    n_atoms::Int=1,
)
    F == 6 || throw(
        ArgumentError(
            "compute_spinor_lhy_icosahedral is F=6 only (got F=$F); the I_h closed " *
            "form is specific to the F=6 even-S channel structure"),
    )
    _tabulate_lhy(n -> epsilon_LHY_F6_Ih(n, g_dict), IcosahedralLHY; n_max, n_points, n_atoms)
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

# Shared tabulation skeleton for every density-only LHY closed form:
# sample n ∈ [0, n_max], evaluate ε_LHY(n) via `energy_fn`, then tabulate
# V_LHY = dε_LHY/dn by central differences. Cold path (called once at
# workspace setup), so the `energy_fn` closure costs nothing in the hot
# loop. Keeping the derivative path in ONE place means a future change to
# the finite-difference scheme can't silently drift between modes.
function _tabulate_lhy(energy_fn, ::Type{ResultT};
    n_max::Float64, n_points::Int, n_atoms::Int=1) where {ResultT}
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))
    n_atoms >= 1 || throw(ArgumentError("n_atoms must be >= 1"))
    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        # The closed forms are ε = (8/15π²)(g n)^(5/2) with `n` the PHYSICAL
        # density and `g` the SI coupling. Here `n = |ψ|²` is normalised to
        # ∫|ψ|²dV = 1 and `g` comes from the dimensionless `c₀ = 4π(a_s/a_ho)N`,
        # which already carries N. Carrying it twice at the 5/2 power leaves the
        # tabulated energy a factor **N too large**:
        #
        #     (2/5)·c_lhy = (8/15π²)·c₀^(5/2) / N      [scalar Lima-Pelster]
        #
        # Measured in the uniform-g_S limit, `fm/scalar` and `polar/scalar` were
        # EXACTLY N for N = 1e3, 3e4, 1e5. On a 2026-05 Eu run that made E_LHY
        # 96% of the total energy — impossible for a beyond-mean-field term; the
        # SI-anchored scalar path gives 0.05% for the same state.
        #
        # V = dε/dn, so dividing ε here divides the tabulated V too.
        energy[i] = energy_fn(n) / n_atoms
    end
    # A closed form that refuses to answer returns NaN (see epsilon_LHY_F6_Ih:
    # c_0 < 0, λ_spin < 0). Without this check the NaN propagates through
    # _numerical_derivative into every table entry and then into ψ, so the run
    # reports NaN dynamics far from the parameter choice that caused it. Fail
    # where the cause is visible instead.
    bad = findfirst(!isfinite, energy)
    bad === nothing || throw(
        ArgumentError(
            "$(nameof(ResultT)): the closed form is not applicable at these couplings " *
            "— ε is $(energy[bad]) at n = $(densities[bad]). This is the closed form " *
            "refusing to extrapolate (I_h: c_0 < 0 means the state is not the ground " *
            "state; λ_spin < 0 means its spin-Goldstone branch is dynamically " *
            "unstable. polar_contact: σ₀ < 0 is the same thing for the density " *
            "Goldstone branch, and it is what c₁ < 0 gives — the sign Eu F=6 " *
            "production uses). ε_LHY is scheme-dependent in all of them. Use " *
            "`kind: full_bdg`, which diagonalises instead of assuming the branch " *
            "structure — but check `lhy_mean_field_max_growth` first, since with " *
            "an active dipole that has no stable point either."),
    )
    ResultT(densities, _numerical_derivative(densities, energy))
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
