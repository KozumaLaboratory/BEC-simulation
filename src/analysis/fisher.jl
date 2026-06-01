# --- Fisher information utilities for SBI / inverse-problem diagnostics ---
#
# Compute the linearised Fisher matrix I(θ) = (∂y/∂θ)ᵀ Σ⁻¹ (∂y/∂θ) around a
# nominal parameter point θ₀, via central finite difference on the forward
# model. SVD/eigen-decomposition exposes identifiable directions (large
# eigenvalues = tightly constrained parameter combinations) and the null
# space (small eigenvalues = data-degenerate directions, where the experiment
# cannot disentangle a given linear combination of parameters).
#
# Use case (Sprint 2 of the Eu SBI plan): probe whether the EdH ring-stage
# observables determine all 7 spin-6 channel scattering lengths, or only a
# low-rank subspace. The null directions then dictate what additional
# experimental knobs (interferometer fringes, microwave Feshbach, alternate
# trap geometry) are needed.

using LinearAlgebra: Diagonal, Symmetric, eigen

export fisher_jacobian, fisher_information, identifiable_directions

"""
    fisher_jacobian(forward, nominal, summary; delta_frac=1e-3, delta_floor=1e-10)
        -> Matrix{Float64}

Central finite-difference Jacobian J[i, j] = ∂y_i / ∂θ_j around θ = `nominal`.

- `forward(θ)`: user-supplied forward model, takes a parameter vector and
  returns *anything* (workspace, NamedTuple, raw psi, ...).
- `summary(out)`: reduces the forward output to `AbstractVector{<:Real}` of
  observables y. The output length determines the row count of J.
- `delta_frac`: relative step per parameter (δ_j = max(|θ_j|·delta_frac, delta_floor)).
- `delta_floor`: absolute floor so zero-valued nominal parameters still get a
  finite step.

The Jacobian eats 2·length(nominal) forward calls. Caller is responsible for
ensuring `forward` is deterministic (no Monte Carlo) — for noisy forwards,
seed before each call or wrap.
"""
function fisher_jacobian(
    forward::Function, nominal::AbstractVector{<:Real}, summary::Function;
    delta_frac::Real=1e-3, delta_floor::Real=1e-10,
)
    n_params = length(nominal)
    y0 = summary(forward(collect(Float64, nominal)))
    y0 isa AbstractVector ||
        throw(ArgumentError("summary must return AbstractVector, got $(typeof(y0))"))
    n_obs = length(y0)
    J = zeros(Float64, n_obs, n_params)
    @inbounds for j in 1:n_params
        delta = max(abs(nominal[j]) * delta_frac, delta_floor)
        θp = collect(Float64, nominal);
        θp[j] += delta
        θm = collect(Float64, nominal);
        θm[j] -= delta
        yp = Float64.(summary(forward(θp)))
        ym = Float64.(summary(forward(θm)))
        length(yp) == n_obs && length(ym) == n_obs ||
            throw(DimensionMismatch("summary length changed across FD points"))
        J[:, j] .= (yp .- ym) ./ (2 * delta)
    end
    J
end

"""
    fisher_information(J, sigma_y) -> NamedTuple

Construct the Fisher information matrix I = JᵀΣ⁻¹J with Σ = diag(σ_y²) and
return its symmetric eigendecomposition.

Returns:
- `matrix`: the I matrix (n_params × n_params)
- `eigenvalues`: ascending eigenvalues of I
- `eigenvectors`: corresponding eigenvectors (columns)
"""
function fisher_information(J::AbstractMatrix, sigma_y::AbstractVector{<:Real})
    length(sigma_y) == size(J, 1) || throw(DimensionMismatch(
        "sigma_y length $(length(sigma_y)) ≠ J rows $(size(J, 1))"))
    all(>(0), sigma_y) || throw(ArgumentError("sigma_y entries must be > 0"))
    Σ_inv_diag = 1.0 ./ (Float64.(sigma_y) .^ 2)
    I_mat = J' * (Σ_inv_diag .* J)
    Sym = Symmetric((I_mat + I_mat') / 2)
    F = eigen(Sym)
    (matrix=Matrix(I_mat), eigenvalues=F.values, eigenvectors=F.vectors)
end

"""
    identifiable_directions(fisher; cutoff_ratio=1e-3, cutoff_absolute=0.0,
                            param_names=nothing) -> NamedTuple

Classify each Fisher eigenvector as identifiable or null. A direction is
identifiable iff its eigenvalue passes EITHER cutoff:
- `cutoff_ratio`: relative threshold `λ_i / max(λ) > cutoff_ratio`. Default
  1e-3. Catches directions that are well-conditioned relative to the
  dominant direction.
- `cutoff_absolute`: absolute eigenvalue threshold `λ_i > cutoff_absolute`.
  Default 0.0 (disabled). When set to the inverse-square of a meaningful
  prior precision (e.g. `(1/σ_prior)^2`), this avoids the
  "relative-cutoff trap" where a single large eigenvalue (a tightly
  prior-constrained direction like a known scattering length) wipes out
  other directions that *are* informative against the prior baseline.

Always pass `cutoff_absolute = 1 / σ_prior²` for prior-aware Fisher
classification in physics applications. The relative cutoff alone
silently mis-reports "rank=1" when one eigenvalue (a known/prior-pinned
direction) dwarfs informative-but-smaller eigenvalues by orders of
magnitude.

The posterior σ is always reported as `1/√λ_i` (the Cramér-Rao bound for
that direction); `Inf` is only assigned when the eigenvalue is < both
cutoffs.

Returns:
- `measurable_count`: number of identifiable eigenvectors
- `eigenvalues`, `eigenvectors`: pass-through from `fisher`
- `is_identifiable::Vector{Bool}`: per-eigenvector flag
- `posterior_sigma::Vector{Float64}`: 1/√λ for identifiable, Inf for null
- `posterior_sigma_absolute::Vector{Float64}`: 1/√λ unconditionally, so
  the operator can compare against an external prior precision after-the-fact
- `summary::String`: human-readable summary (uses `param_names` if given)
"""
function identifiable_directions(
    fisher::NamedTuple; cutoff_ratio::Real=1e-3,
    cutoff_absolute::Real=0.0,
    param_names::Union{Nothing, AbstractVector{<:AbstractString}}=nothing,
)
    evals = Float64.(fisher.eigenvalues)
    evecs = Matrix{Float64}(fisher.eigenvectors)
    n_par = length(evals)
    evmax = maximum(evals)
    pass_rel = (evals ./ max(evmax, eps(Float64))) .> cutoff_ratio
    # cutoff_absolute > 0 enables the absolute test; default 0 = disabled
    # (otherwise all positive eigenvalues would pass and override the
    # relative cutoff).
    is_identifiable = cutoff_absolute > 0 ?
                      (pass_rel .| (evals .> cutoff_absolute)) :
                      pass_rel
    n_meas = sum(is_identifiable)
    posterior_sigma_absolute = [evals[i] > 0 ? 1 / sqrt(evals[i]) : Inf
                                for i in 1:n_par]
    posterior_sigma = [is_identifiable[i] ? posterior_sigma_absolute[i] : Inf
                       for i in 1:n_par]
    cutoff_str = if cutoff_absolute > 0
        "ratio=$cutoff_ratio OR absolute=$cutoff_absolute"
    else
        "ratio=$cutoff_ratio"
    end
    summary_str = if param_names === nothing
        "measurable rank = $n_meas / $n_par (cutoff $cutoff_str)"
    else
        length(param_names) == n_par || throw(
            DimensionMismatch(
                "param_names length $(length(param_names)) ≠ n_params $n_par"),
        )
        lines = String["measurable rank = $n_meas / $n_par (cutoff $cutoff_str)"]
        for i in 1:n_par
            v = view(evecs, :, i)
            dom_idx = argmax(abs.(v))
            tag = is_identifiable[i] ? "MEAS" : "NULL"
            σabs = round(posterior_sigma_absolute[i]; sigdigits=3)
            push!(lines,
                "  [$tag] eigval=$(round(evals[i]; sigdigits=3)) σ_abs=$σabs dominant=$(param_names[dom_idx])",
            )
        end
        join(lines, "\n")
    end
    (measurable_count=n_meas, eigenvalues=evals, eigenvectors=evecs,
        is_identifiable=is_identifiable, posterior_sigma=posterior_sigma,
        posterior_sigma_absolute=posterior_sigma_absolute,
        summary=summary_str)
end
