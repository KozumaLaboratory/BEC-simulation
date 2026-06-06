# --- Fisher identifiability (preflight instrument) ---
#
# The third column of the trust ledger
# (docs/design/hamiltonian_layered_architecture.md §5): in the regime
# of the unknown 7 Eu channels — the SBI target itself — no code
# oracle of any class reaches. A convergent error there survives
# everything except (a) the CG projection-structure gate (shipped,
# T-CG) and (b) THIS instrument: before an SBI / calibration campaign
# runs, check that the chosen observable set actually CONSTRAINS the
# parameters — a well-conditioned Fisher information over the free-θ
# subspace. This catches "the experiment design cannot identify the
# physics", which is a protocol bug, not a code bug; a green test
# suite plus an unidentifiable protocol still yields confidently wrong
# posteriors.
#
# Cost regimes (arch doc §4.7): static observables (energies, moments
# of a fixed or ground state) are cheap — the FD-in-θ below with ws
# rebuilt per evaluation; dynamic observables need 2·n_θ forward runs
# per protocol point (trivially parallel, TSUBAME territory). The
# machinery here is regime-agnostic: `f` is any θ ↦ observables map.
#
# Coefficient-linearity is CHECKED, never assumed (§3 anchor rule):
# for parameters that enter linearly (all contact couplings, c_dd, p),
# central FD is exact and ∂E_T/∂c = E_T/c provides a free identity
# anchor — the test suite asserts it. Parameters entering nonlinearly
# (trap ω², rotation angles) simply fall back to the FD value; the
# θ-valley (valley_scan over rel_step) certifies the trust region.

using LinearAlgebra: Symmetric, eigen

"""
    fd_jacobian(f, θ0; rel_step=1e-4, abs_floor=1e-8) -> Matrix

Central-difference Jacobian `J[i, j] = ∂f_i/∂θ_j` of an observable map
`f(θ::Vector) -> Vector` at `θ0`. Per-parameter step
`max(rel_step·|θ_j|, abs_floor)`. 2·n_θ evaluations of `f`.
"""
function fd_jacobian(
    f, θ0::AbstractVector{Float64}; rel_step::Float64=1e-4, abs_floor::Float64=1e-8
)
    nθ = length(θ0)
    cols = Vector{Vector{Float64}}(undef, nθ)
    for j in 1:nθ
        h = max(rel_step * abs(θ0[j]), abs_floor)
        θp = copy(θ0)
        θm = copy(θ0)
        θp[j] += h
        θm[j] -= h
        cols[j] = (f(θp) .- f(θm)) ./ (2h)
    end
    return reduce(hcat, cols)
end

"""
    fisher_information(J; sigma=ones(...)) -> Matrix

`I(θ) = Jᵀ Σ⁻¹ J` for diagonal noise `Σ = diag(sigma.^2)` — `sigma[i]`
is the measurement uncertainty of observable i.
"""
function fisher_information(J::AbstractMatrix; sigma::AbstractVector=ones(size(J, 1)))
    W = J ./ sigma
    return W' * W
end

"""
    identifiability_report(f, θ0; sigma, param_names, null_rtol=1e-8,
                           rel_step=1e-4) -> NamedTuple

Preflight verdict for a protocol: builds J and I(θ), eigen-decomposes,
and reports

- `eigvals`, `eigvecs` — information spectrum (ascending),
- `cond` — λ_max/λ_min over the full θ space,
- `null_directions` — eigenvectors with λ < null_rtol·λ_max: the
  parameter combinations this observable set CANNOT constrain (each a
  vector in θ space; with `param_names` these are physically readable),
- `identifiable::Bool` — no null directions.

An SBI / calibration campaign over θ_free should not launch while
`identifiable == false` for its protocol — the posterior along a null
direction is the prior, reported with whatever confidence the sampler
hallucinates.
"""
function identifiability_report(
    f, θ0::AbstractVector{Float64};
    sigma::AbstractVector=ones(length(f(copy(θ0)))),
    param_names::Union{Nothing, Vector{String}}=nothing,
    null_rtol::Float64=1e-8,
    rel_step::Float64=1e-4,
)
    J = fd_jacobian(f, θ0; rel_step)
    fisher = fisher_information(J; sigma)
    eig = eigen(Symmetric(fisher))
    λ = eig.values
    λmax = maximum(λ)
    null_mask = λ .< null_rtol * max(λmax, eps())
    return (;
        J, fisher,
        eigvals=λ, eigvecs=eig.vectors,
        cond=λmax / max(minimum(λ), eps()),
        null_directions=[eig.vectors[:, k] for k in findall(null_mask)],
        identifiable=!any(null_mask),
        param_names,
    )
end
