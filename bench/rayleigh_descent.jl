# Rayleigh-quotient descent on the constrained GP Hessian.
#
# Shared by `probe_lbfgs_lambda_min_bound.jl` (which wants the value) and
# `probe_lbfgs_soft_mode_structure.jl` (which wants the vector), so the two
# cannot drift apart about what "the soft mode" means.
#
# The step is an exact 2×2 Rayleigh-Ritz in `span{v, Hv − qv}`, not a guessed
# step size: a stall has to be readable as a stall rather than as a step too
# small, and reading the stall is the point.

using SpinorBEC: constrained_hessian_action, _realdot, _tangent_project,
    _sobolev_precondition!
using Printf
using LinearAlgebra: eigen, Symmetric

"""
    rayleigh_descent(ws, psi, v0; μ, dV, n2, n_iter, verbose=true)
        → (; v, q, resid, converged)

Minimise `⟨v,Hv⟩/⟨v,v⟩` over the constrained tangent space from `v0`.

`converged` is `resid ≤ 0.2·|q|`, and callers must honour it: `q` is a valid
UPPER BOUND on `λ_min` either way — any `v` gives one — but it is only close to
`λ_min` when the descent has actually stopped moving.
"""
function rayleigh_descent(ws, psi, v0; μ, dV, n2, n_iter::Int, verbose::Bool=true)
    H(v) = constrained_hessian_action(ws, psi, v; μ, dV, n2, ε=1.0e-5, order=4)
    proj(v) = _tangent_project(v, psi, dV, n2)
    rq(v, Hv) = _realdot(v, Hv) * dV / (_realdot(v, v) * dV)

    v = proj(v0)
    v ./= sqrt(_realdot(v, v) * dV)
    Hv = H(v)
    qv = rq(v, Hv)
    nw = Inf
    verbose && @printf("  %5s %14s %12s\n", "iter", "Rayleigh q", "|resid|")
    for it in 1:n_iter
        w = proj(Hv .- qv .* v)
        nw = sqrt(_realdot(w, w) * dV)
        verbose && (it % 10 == 1 || it == n_iter) &&
            (@printf("  %5d %14.6e %12.3e\n", it - 1, qv, nw); flush(stdout))
        nw < 1.0e-12 && break
        w ./= nw
        Hw = H(w)
        a, b, d = qv, _realdot(v, Hw) * dV, _realdot(w, Hw) * dV
        θ = 0.5 * atan(2b, a - d)
        cs, sn = cos(θ), sin(θ)
        v1, v2 = cs .* v .+ sn .* w, -sn .* v .+ cs .* w
        H1, H2 = cs .* Hv .+ sn .* Hw, -sn .* Hv .+ cs .* Hw
        q1, q2 = rq(v1, H1), rq(v2, H2)
        v, Hv, qv = q1 <= q2 ? (v1, H1, q1) : (v2, H2, q2)
        nv = sqrt(_realdot(v, v) * dV)
        v ./= nv
        Hv ./= nv
    end
    (; v, q=qv, resid=nw, converged=(nw <= 0.2 * abs(qv)))
end

"The softest stored curvature direction, or `nothing` if the history is empty."
function softest_history_direction(hist, dV)
    hist === nothing && return (nothing, Inf)
    isempty(hist[3]) && return (nothing, Inf)
    s_h, y_h, _ = hist
    best, bestλ = nothing, Inf
    for i in eachindex(s_h)
        ss = _realdot(s_h[i], s_h[i]) * dV
        sy = _realdot(s_h[i], y_h[i]) * dV
        (ss > 0 && sy > 0) || continue
        λi = sy / ss
        λi < bestλ && (bestλ = λi; best = s_h[i])
    end
    (best, bestλ)
end

"""
    block_lobpcg(ws, psi, X0; μ, dV, n2, n_iter, α_precond, verbose)
        → (; λ, V, resid, converged)

Lowest `length(X0)` eigenpairs of the constrained Hessian, by preconditioned
block LOBPCG.

Why a block. A one-vector Rayleigh descent separates λ₁ from λ₂ at a rate set by
their RELATIVE gap, so a cluster is exactly the case it cannot resolve at any
iteration count — and the sequential ladder came back λ₂/λ₁ = 1.08 in one run and
λ₂ BELOW λ₁ in another, both reporting NOT CONVERGED. That pattern was the
answer to why, not noise. A block converges to the whole cluster at once, so
clustering appears as near-equal eigenvalues instead of as a failure.

`α_precond` applies the Sobolev preconditioner `(1 + α(−∇²))⁻¹` to the
residuals; the Hessian's stiff end is kinetic, so that is the standard
accelerant and it is already in the package.

Costs `length(X0)` Hessian-vector products per iteration, each 4 gradient
evaluations at `order=4`.

`converged` is per mode, `‖Hv − λv‖ ≤ 0.05|λ|`. Every λ is a valid UPPER bound
whatever the residual; only a converged one may be compared with its neighbour
to claim a gap.
"""
function block_lobpcg(ws, psi, X0; μ, dV, n2, n_iter::Int, α_precond::Float64=0.5,
    verbose::Bool=true)
    H(v) = constrained_hessian_action(ws, psi, v; μ, dV, n2, ε=1.0e-5, order=4)
    proj(v) = _tangent_project(v, psi, dV, n2)
    ip(a, b) = _realdot(a, b) * dV

    b = length(X0)
    X = Any[proj(x) for x in X0]
    HX = Any[H(x) for x in X]
    P = Any[nothing for _ in 1:b]
    HP = Any[nothing for _ in 1:b]
    λ = zeros(b)
    res = fill(Inf, b)

    # Orthonormalise against the real inner product, dropping dependent
    # directions; returns the surviving indices.
    function orth!(vs, hs)
        keep = Int[]
        for i in eachindex(vs)
            vs[i] === nothing && continue
            for j in keep
                c = ip(vs[j], vs[i])
                vs[i] = vs[i] .- c .* vs[j]
                hs[i] = hs[i] .- c .* hs[j]
            end
            nv = sqrt(ip(vs[i], vs[i]))
            nv < 1.0e-9 && continue
            vs[i] = vs[i] ./ nv
            hs[i] = hs[i] ./ nv
            push!(keep, i)
        end
        keep
    end

    verbose && @printf("  %5s %14s %14s %12s\n", "iter", "λ₁", "λ_b", "max resid")
    for it in 1:n_iter
        basis = Any[X...]
        hbas = Any[HX...]
        for i in 1:b
            P[i] === nothing && continue
            push!(basis, P[i])
            push!(hbas, HP[i])
        end
        keep = orth!(basis, hbas)
        nb = length(keep)
        A = [ip(basis[keep[i]], hbas[keep[j]]) for i in 1:nb, j in 1:nb]
        A = (A .+ A') ./ 2
        F = eigen(Symmetric(A))
        nsel = min(b, nb)
        Xn = Any[]
        HXn = Any[]
        for s in 1:nsel
            cv = F.vectors[:, s]
            push!(Xn, sum(cv[i] .* basis[keep[i]] for i in 1:nb))
            push!(HXn, sum(cv[i] .* hbas[keep[i]] for i in 1:nb))
            λ[s] = F.values[s]
        end
        for s in 1:nsel
            r = proj(HXn[s] .- λ[s] .* Xn[s])
            res[s] = sqrt(ip(r, r))
            if α_precond > 0
                rr = copy(r)
                _sobolev_precondition!(rr, ws, ws.grid.k_squared, α_precond)
                r = proj(rr)
            end
            nr = sqrt(ip(r, r))
            if nr > 1.0e-12
                P[s] = r ./ nr
                HP[s] = H(P[s])
            end
            X[s] = Xn[s]
            HX[s] = HXn[s]
        end
        verbose && (it % 10 == 1 || it == n_iter) &&
            (@printf("  %5d %14.6e %14.6e %12.3e\n", it, λ[1], λ[nsel],
                maximum(res[1:nsel])); flush(stdout))
        all(i -> res[i] <= 0.05 * abs(λ[i]), 1:nsel) && break
    end
    (; λ, V=X, resid=res, converged=[res[i] <= 0.05 * abs(λ[i]) for i in 1:b])
end
