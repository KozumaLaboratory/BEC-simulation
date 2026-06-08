# Second-variation operator — the single source.
#
# `energy_gradient!` is the gated single-source gradient (= 2·δE/δψ̄,
# master oracle). The SECOND variation — the Hessian the BdG stability
# verdict, the Ω>0 conditioning diagnosis, and the Newton-CG optimiser
# all ride on — is stated ONCE here; `test/oracles/test_bdg_fd_hessian.jl`
# anchors it to the hand-built BdG matrices (both blocks, F-swept to Eu
# F=6), and every consumer calls it.
#
# Three layered faces, each the SAME physics:
#   hessian_vector_product       — bare Euclidean H·δ (the anchored primitive)
#   constrained_hessian_params   — (μ, dV, n2) at a stationary ψ
#   constrained_hessian_action   — P(H − 2μ)P · δ, the constrained operator
# The constrained operator is the ONE object behind BOTH the gate-2
# eigenvalue query (`trapped_bdg_lowest_eigenvalue`, Lanczos) AND the
# Newton-CG linear solve (`newton_cg_ground_state`). They differ only in
# the query (smallest eigenvalue vs. solve Hc p = −g_proj); the operator,
# the −2μ shift, and the complex-ψ tangent projection are shared. Building
# a separate operator for Newton-CG would risk drift in a load-bearing
# object and let the solve dig the singular phase-Goldstone direction.

export hessian_vector_product,
    constrained_hessian_params, constrained_hessian_action,
    trapped_bdg_lowest_eigenvalue

"""
    hessian_vector_product(ws, ψ, δ; ε=1e-5) → array

Central-difference action of the energy second variation on `δ`:

    H·δ ≈ (energy_gradient!(ψ+εδ) − energy_gradient!(ψ−εδ)) / (2ε).

Since `energy_gradient!` returns `2·δE/δψ̄`, this carries BOTH the normal
(δ²E/δψ̄δψ) and anomalous (δ²E/δψ̄δψ̄) blocks via the real representation
(perturb along `δ` and `iδ` to separate them — see the L_op/M_op
extraction in the anchor test). Central difference ⇒ O(ε²) truncation;
ε=1e-5 sits at the roundoff/truncation optimum for the gated gradient.
Anchored: `test/oracles/test_bdg_fd_hessian.jl` (≡ the hand-built BdG).
"""
function hessian_vector_product(ws, ψ, δ; ε::Float64=1e-5)
    gp = similar(ψ)
    fill!(gp, 0)
    energy_gradient!(gp, ψ .+ ε .* δ, ws)
    gm = similar(ψ)
    fill!(gm, 0)
    energy_gradient!(gm, ψ .- ε .* δ, ws)
    (gp .- gm) ./ (2ε)
end

# Tangent projection: remove the complex-ψ gauge direction (norm AND phase
# Goldstone iψ) from `δ`. This is the tangent of the ‖ψ‖²=N manifold under
# the global U(1) phase — both must leave for the constrained Hessian to be
# non-singular on the working space.
_tangent_project(δ, ψ, dV, n2) = δ .- ψ .* (sum(conj.(ψ) .* δ) * dV / n2)

"""
    constrained_hessian_params(ws, ψ) → (; μ, dV, n2)

Manifold scalars at a (near-)stationary `ψ`: the chemical potential
`μ = Re⟨ψ,g⟩/(2‖ψ‖²)` (`g = energy_gradient! = 2μψ` at a stationary
point), the cell volume `dV`, and `n2 = ‖ψ‖²`. Calibrated by the gate-2
self-check `H·(iψ) = 2μ·(iψ)` (the phase Goldstone is the 2μ eigenvector
of the raw H). Reuse-ready for any consumer of the constrained Hessian.
"""
function constrained_hessian_params(ws, ψ)
    dV = cell_volume(ws.grid)
    n2 = real(sum(abs2, ψ)) * dV
    g0 = similar(ψ)
    fill!(g0, 0)
    energy_gradient!(g0, ψ, ws)
    μ = (real(sum(conj.(ψ) .* g0)) * dV) / (2 * n2)
    (; μ, dV, n2)
end

"""
    constrained_hessian_action(ws, ψ, δ; μ, dV, n2, ε=1e-5) → array

The constrained second-variation operator `P(H − 2μ)P · δ`, where `P` is
the complex-ψ tangent projection and `H` the Euclidean
`hessian_vector_product`. This is the Riemannian Hessian of the energy on
the ‖ψ‖²=N manifold at a stationary `ψ` — the SINGLE operator behind both
the gate-2 minimum-vs-saddle eigenvalue query and the Newton-CG linear
solve. Pass `(μ, dV, n2)` from `constrained_hessian_params`.
"""
function constrained_hessian_action(ws, ψ, δ; μ, dV, n2, ε::Float64=1e-5)
    pδ = _tangent_project(δ, ψ, dV, n2)
    _tangent_project(
        hessian_vector_product(ws, ψ, pδ; ε) .- 2μ .* pδ, ψ, dV, n2
    )
end

"""
    trapped_bdg_lowest_eigenvalue(ws, ψ; niter=24, ε=1e-5, rng=…) → (λ_min, μ)

Lowest eigenvalue of the constrained second variation `P(H−2μ)P` at a
STATIONARY ψ — the gate-2 minimum-vs-saddle verdict for a trapped state.
Hand-rolled fully-reorthogonalised Lanczos on `constrained_hessian_action`
(no KrylovKit dependency); `λ_min ≥ −tol` ⇒ energetic minimum, `< −tol` ⇒
saddle. Requires ψ converged (`g ∥ ψ`); on a non-stationary ψ the `μ` and
the verdict are not meaningful.
"""
function trapped_bdg_lowest_eigenvalue(
    ws, ψ; niter::Int=24, ε::Float64=1e-5, rng=Random.default_rng()
)
    p = constrained_hessian_params(ws, ψ)
    ipR(a, b) = real(sum(conj.(a) .* b)) * p.dV
    Hc(δ) = constrained_hessian_action(ws, ψ, δ; p.μ, p.dV, p.n2, ε)

    V = [_tangent_project(randn(rng, ComplexF64, size(ψ)), ψ, p.dV, p.n2)]
    V[1] ./= sqrt(ipR(V[1], V[1]))
    α = Float64[]
    β = Float64[]
    for _ in 1:niter
        w = Hc(V[end])
        push!(α, ipR(V[end], w))
        for u in V                              # full reorthogonalisation
            w = w .- u .* ipR(u, w)
        end
        βj = sqrt(ipR(w, w))
        βj < 1e-10 && break
        push!(β, βj)
        push!(V, w ./ βj)
    end
    minimum(eigvals(SymTridiagonal(α, β[1:(length(α) - 1)]))), p.μ
end
