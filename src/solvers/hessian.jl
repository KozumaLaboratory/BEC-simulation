# Second-variation operator — the single source.
#
# `energy_gradient!` is the gated single-source gradient (= 2·δE/δψ̄,
# master oracle). The SECOND variation — the Hessian the BdG stability
# verdict, the Ω>0 conditioning diagnosis, and the Newton-CG optimiser
# all ride on — was being hand-written as a finite-difference snippet in
# every consumer (test_bdg_fd_hessian, m1_gate2_stability, …). That is
# the ungated-duplication class the redundancy audit forbids: a drift
# between copies is a silent bug in a load-bearing operator. This file
# is the ONE statement; `test/oracles/test_bdg_fd_hessian.jl` anchors it
# to the hand-built BdG matrices (both blocks, F-swept to Eu F=6), and
# every consumer calls it.

export hessian_vector_product, trapped_bdg_lowest_eigenvalue

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

"""
    trapped_bdg_lowest_eigenvalue(ws, ψ; niter=24, ε=1e-5, rng=…) → (λ_min, μ)

Lowest eigenvalue of the constrained second variation `P(H−2μ)P` at a
STATIONARY ψ — the gate-2 minimum-vs-saddle verdict for a trapped state.
`P` removes the complex-ψ gauge direction (norm + phase) and `μ =
Re⟨ψ,g⟩/(2‖ψ‖²)` is the chemical potential (`g = 2μψ` at a stationary
point). Hand-rolled fully-reorthogonalised Lanczos on
`hessian_vector_product` (no KrylovKit dependency); `λ_min ≥ −tol` ⇒
energetic minimum, `< −tol` ⇒ saddle. The phase Goldstone is the `2μ`
eigenvector of the raw `H`, zeroed by the `−2μ` shift and removed by `P`.

Requires ψ converged (`g ∥ ψ`); on a non-stationary ψ the `μ` and the
verdict are not meaningful.
"""
function trapped_bdg_lowest_eigenvalue(
    ws, ψ; niter::Int=24, ε::Float64=1e-5, rng=Random.default_rng()
)
    dV = cell_volume(ws.grid)
    ipR(a, b) = real(sum(conj.(a) .* b)) * dV
    n2 = ipR(ψ, ψ)
    g0 = similar(ψ)
    fill!(g0, 0)
    energy_gradient!(g0, ψ, ws)
    μ = ipR(ψ, g0) / (2 * n2)
    proj(δ) = δ .- ψ .* (sum(conj.(ψ) .* δ) * dV / n2)
    Hc(δ) = (pδ = proj(δ); proj(hessian_vector_product(ws, ψ, pδ; ε) .- 2μ .* pδ))

    V = [proj(randn(rng, ComplexF64, size(ψ)))]
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
    minimum(eigvals(SymTridiagonal(α, β[1:(length(α) - 1)]))), μ
end
