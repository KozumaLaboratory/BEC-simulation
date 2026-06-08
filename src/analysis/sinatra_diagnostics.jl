# sinatra_diagnostics.jl
# =================================================================
# Helpers for the Sinatra criterion check on TWA validity.
#
# The truncated Wigner approximation samples the Wigner vacuum on a
# discrete momentum grid; each plane-wave mode contributes ½ particle
# of fluctuation to each spinor component. For the truncation
# (`δψ ~ stochastic, ψ̄ ~ classical`) to be a controlled approximation
# the effective number of populated noise modes must be small compared
# to the atom number:
#
#     N_modes_eff × D  ≪  N_atoms      (Sinatra 2002, Castin 2001)
#
# For F=6 (D=13) on a 32³ grid this is 32³·13 ≈ 4.3e5; with N=10⁴
# atoms the ratio is 43 — the weak inequality. Two remedies:
#
# 1. Grid coarsening — switch to 16³ → 4096·13 = 53k modes (ratio 5.3,
#    marginal but improved).
# 2. Energy-space mode cutoff — `cutoff_energy` in `add_vacuum_noise`
#    zeros out modes with `k²/2 > E_cut`. Conventional choice:
#    `k_cut = 2 / ξ` (twice the inverse healing length) keeps modes up
#    to twice the wavenumber where the GS density profile has measurable
#    structure, and discards purely-vacuum thermal-like populations
#    above that.
#
# These helpers convert physical scales (g·n, ξ) to the
# `cutoff_energy` knob that the YAML schema and `add_vacuum_noise` use.
# They do NOT touch the noise injection itself — that is already
# implemented in `src/workflow/initialization/vacuum_noise.jl`.
# =================================================================

export healing_length, cutoff_energy_from_xi, cutoff_energy_from_gn
export effective_n_modes, sinatra_ratio

"""
    healing_length(g, n; M=1.0, hbar=1.0) -> Float64

Healing length `ξ = ℏ / √(2 M g n)`. In dimensionless `ℏ = M = ω_ref = 1`
units (the SpinorBEC convention) this reduces to `1 / √(2 g n)`. `g` is
the single-particle scalar contact coupling (e.g. `c_total / N_atoms`,
or `g_2F` for FM-polarised condensates).

Returns `Inf` if `g·n ≤ 0`.
"""
function healing_length(g::Real, n::Real; M::Real=1.0, hbar::Real=1.0)::Float64
    gn = Float64(g) * Float64(n)
    gn <= 0 && return Inf
    Float64(hbar) / sqrt(2.0 * Float64(M) * gn)
end

"""
    cutoff_energy_from_xi(xi; factor=2.0, M=1.0, hbar=1.0) -> Float64

`E_cut = (factor / ξ)² ℏ² / (2 M)` — the `cutoff_energy` value that
zeros out plane-wave modes with `k > factor / ξ`. The default
`factor = 2` is the Sinatra-recommended k-cutoff at twice the inverse
healing length. In dimensionless units this is `(factor/ξ)² / 2`.
"""
function cutoff_energy_from_xi(xi::Real;
    factor::Real=2.0, M::Real=1.0, hbar::Real=1.0)::Float64
    xi <= 0 && throw(ArgumentError("xi must be positive (got $xi)"))
    k_cut = Float64(factor) / Float64(xi)
    Float64(hbar)^2 * k_cut^2 / (2.0 * Float64(M))
end

"""
    cutoff_energy_from_gn(g, n; factor=2.0, M=1.0, hbar=1.0) -> Float64

Convenience: combine `healing_length(g, n)` and `cutoff_energy_from_xi`
into one call. Returns the cutoff energy (in ω_ref units for the default
SpinorBEC dimensionless convention) corresponding to `k_cut = factor / ξ`.

For `factor = 2` this evaluates to `4 g n / (M / ℏ²)` — twice the
mean-field interaction energy per atom, which is the natural scale for
the noise-mode boundary.
"""
function cutoff_energy_from_gn(g::Real, n::Real;
    factor::Real=2.0, M::Real=1.0, hbar::Real=1.0)::Float64
    cutoff_energy_from_xi(healing_length(g, n; M, hbar); factor, M, hbar)
end

"""
    effective_n_modes(grid, cutoff_energy; D=1) -> Int

Count the number of plane-wave modes per spinor component that survive
`add_vacuum_noise` at the given `cutoff_energy`: every grid index `I`
with `k_squared[I] / 2 ≤ cutoff_energy`. Multiply by `D` (the number
of spinor components) to get the *total* effective mode count used in
the Sinatra ratio.

If `cutoff_energy` is `nothing` or `Inf`, all modes survive, so the
return value equals `prod(grid.config.n_points) × D`.
"""
function effective_n_modes(grid;
    cutoff_energy::Union{Nothing, Real}=nothing, D::Int=1)::Int
    if cutoff_energy === nothing || !isfinite(cutoff_energy)
        return prod(grid.config.n_points) * D
    end
    ec = Float64(cutoff_energy)
    n_kept = count(I -> grid.k_squared[I] / 2 <= ec, eachindex(grid.k_squared))
    return n_kept * D
end

"""
    sinatra_ratio(grid, D, N_atoms; cutoff_energy=nothing) -> Float64

The Sinatra check ratio: `(effective_n_modes / N_atoms)`. Should be
*small* (≪ 1) for the TWA expansion to be controlled. A ratio of 1-10
is marginal; > 10 is the danger regime where spurious classical
thermalisation can mask physical quantum fluctuations.
"""
function sinatra_ratio(grid, D::Int, N_atoms::Real;
    cutoff_energy::Union{Nothing, Real}=nothing)::Float64
    Float64(effective_n_modes(grid; cutoff_energy, D)) / Float64(N_atoms)
end
