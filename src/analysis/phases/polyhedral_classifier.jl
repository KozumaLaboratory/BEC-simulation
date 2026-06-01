# --- Polyhedral-invariant phase classifier for spin-F BEC ---
#
# Built on the channel-projected weights σ_S(ζ) = Σ_M |Σ_{m₁,m₂}
# ⟨S,M|F,m₁;F,m₂⟩ ζ_{m₁} ζ_{m₂}|² (see `F6_phase_diagram.jl::_f6_pd_sigma_S`).
# These are SO(3)-rotation invariants of the spinor ζ, so two states
# related by a spatial rotation share the same σ_S fingerprint. Distinct
# polyhedral inert states (polar, cyclic-tetrahedral, biaxial, I_h, ...)
# have *distinct* fingerprints and are correctly separated — ⟨F⟩-only
# classifiers cannot.
#
# Solves the A1 v2 "nematic = manifold" issue: two states classified as
# "nematic" by the ⟨F⟩-based classifier may be orthogonal polyhedral
# inert states with distinct point-group symmetry; the σ_S fingerprint
# tells them apart.
#
# Also exposes `direct_eff_coupling` g_eff(ζ) = Σ_S g_S σ_S(ζ), the
# load-bearing quantity for catastrophic-cancellation-free ΔE between
# candidate inert states (E_a - E_b at fixed n profile is ∝ (g_eff_a -
# g_eff_b), computed as a single small number rather than the difference
# of two large total energies).

export polyhedral_fingerprint, polyhedral_candidate_spinors
export classify_polyhedral, direct_eff_coupling, direct_eff_coupling_delta

"""
    polyhedral_fingerprint(ζ::AbstractVector{<:Complex}, F::Int)
        -> Dict{Int, Float64}

The σ_S fingerprint of a constant spinor ζ (length 2F+1). Returns
`Dict(S => σ_S(ζ))` for all even S ∈ 0:2:2F. The fingerprint is
SO(3)-rotation invariant and bilinear in ζ.

`σ_S(ζ) = Σ_M |Σ_{m₁,m₂} ⟨S,M|F,m₁;F,m₂⟩ ζ_{m₁} ζ_{m₂}|²`,
with ζ indexed so that `ζ[F + 1 - m]` is the m-component.
"""
function polyhedral_fingerprint(ζ::AbstractVector{<:Complex}, F::Int)
    length(ζ) == 2F + 1 || throw(DimensionMismatch(
        "ζ length $(length(ζ)) ≠ 2F+1 = $(2F + 1)"))
    Dict{Int, Float64}(S => _f6_pd_sigma_S(F, S, Complex{Float64}.(ζ))
                       for S in 0:2:(2F))
end

"""
    polyhedral_candidate_spinors(F::Int) -> Dict{Symbol, Vector{ComplexF64}}

Canonical inert-state spinors at given F. For F=6, returns
`(:polar, :FM, :cyclic, :biaxial_nematic, :I_h)` matching the state_zoo
builder names. Wraps the existing `_f6_pd_candidate_spinors` and adds the
biaxial_nematic that the F6 phase diagram code currently omits — A1 v2
found this state at E ≈ 2.567 (orthogonal to cyclic, both classified
"nematic" by the ⟨F⟩-only classifier).
"""
function polyhedral_candidate_spinors(F::Int)
    if F == 6
        base = _f6_pd_candidate_spinors()
        D = 2F + 1
        biaxial = zeros(ComplexF64, D)
        # |+2⟩ + |−2⟩ over √2 — matches init_psi(:biaxial_nematic) for F=6
        inv_sqrt2 = 1.0 / sqrt(2.0)
        biaxial[F - 2 + 1] = inv_sqrt2     # m=+2
        biaxial[F + 2 + 1] = inv_sqrt2     # m=−2
        base[:biaxial_nematic] = biaxial
        return base
    elseif F == 1
        D = 3
        polar = zeros(ComplexF64, D);
        polar[2] = 1
        fm_plus = zeros(ComplexF64, D);
        fm_plus[1] = 1
        return Dict(:polar => polar, :FM => fm_plus)
    else
        throw(ArgumentError("polyhedral_candidate_spinors not yet defined for F=$F"))
    end
end

"""
    classify_polyhedral(ζ::AbstractVector{<:Complex}, F::Int;
                        tol::Float64=1e-3) -> NamedTuple

Project ζ onto the canonical-candidate fingerprints, return the best
match plus a normalised similarity score. The match is via L² distance
in σ_S space (which is rotation-invariant), so ζ may be in any frame
relative to the canonical.

Returns:
- `best::Symbol` — best-matching canonical label (or `:unknown` if no
  match within `tol`).
- `score::Float64` — L² distance to the best candidate (0 = identical
  fingerprint).
- `fingerprint::Dict{Int,Float64}` — σ_S of input ζ.
- `candidate_distances::Dict{Symbol,Float64}` — distance to each canonical.
"""
function classify_polyhedral(
    ζ::AbstractVector{<:Complex}, F::Int; tol::Float64=1e-3
)
    fp = polyhedral_fingerprint(ζ, F)
    candidates = polyhedral_candidate_spinors(F)
    dists = Dict{Symbol, Float64}()
    for (label, ζc) in candidates
        fp_c = polyhedral_fingerprint(ζc, F)
        d = sqrt(sum((fp[S] - fp_c[S])^2 for S in 0:2:(2F)))
        dists[label] = d
    end
    best_label, best_dist = first(dists), Inf
    for (label, d) in dists
        if d < best_dist
            best_dist = d
            best_label = label
        end
    end
    best = best_dist < tol ? best_label : :unknown
    (best=best, score=best_dist,
        fingerprint=fp, candidate_distances=dists)
end

"""
    direct_eff_coupling(ζ::AbstractVector{<:Complex}, F::Int,
                        g_S::AbstractDict{Int,<:Real}) -> Float64

Effective contact coupling `g_eff(ζ) = Σ_S g_S σ_S(ζ)`. The Eu phase
identification at GP mean-field reduces to ranking g_eff among
candidate inert spinors; the lowest g_eff gives the lowest Thomas-Fermi
energy per atom at fixed total atom number.

Use with `direct_eff_coupling_delta` to compute ΔE between two states
without subtracting full energies (avoids the catastrophic cancellation
that limited A1 v2's 1e-4 gap reading).
"""
function direct_eff_coupling(
    ζ::AbstractVector{<:Complex}, F::Int,
    g_S::AbstractDict{Int, <:Real},
)
    sum(get(g_S, S, 0.0) * _f6_pd_sigma_S(F, S, Complex{Float64}.(ζ))
        for S in 0:2:(2F))
end

"""
    direct_eff_coupling_delta(ζ_a, ζ_b, F, g_S) -> Float64

Δg_eff = g_eff(ζ_a) − g_eff(ζ_b) = Σ_S g_S (σ_S(ζ_a) − σ_S(ζ_b)).

Compute this directly via the channel-projected weights — NOT by
subtracting two large g_eff values. For polyhedral inert spinors of
order unity, σ_S(ζ) ∈ [0, O(1)] and Δσ_S can be of any sign and any
magnitude; the difference is a primary small number, no
cancellation.

Connection to total ΔE at fixed N in a harmonic trap: in the
Thomas-Fermi limit
`E(g_eff) = (5/14)^{2/5} · (2N)^{7/5} · (1/2 ω̄ ℏ)^{6/5} · g_eff^{2/5}`,
so `ΔE / E ≈ (2/5) Δg_eff / g_eff`. A 0.1 % g_eff gap maps to a 0.04 %
total-E gap.
"""
function direct_eff_coupling_delta(
    ζ_a::AbstractVector{<:Complex}, ζ_b::AbstractVector{<:Complex},
    F::Int, g_S::AbstractDict{Int, <:Real},
)
    s = 0.0
    for S in 0:2:(2F)
        σ_a = _f6_pd_sigma_S(F, S, Complex{Float64}.(ζ_a))
        σ_b = _f6_pd_sigma_S(F, S, Complex{Float64}.(ζ_b))
        s += get(g_S, S, 0.0) * (σ_a - σ_b)
    end
    s
end
