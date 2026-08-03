# Rayleigh-quotient descent on the constrained GP Hessian.
#
# Shared by `probe_lbfgs_lambda_min_bound.jl` (which wants the value) and
# `probe_lbfgs_soft_mode_structure.jl` (which wants the vector), so the two
# cannot drift apart about what "the soft mode" means.
#
# The step is an exact 2×2 Rayleigh-Ritz in `span{v, Hv − qv}`, not a guessed
# step size: a stall has to be readable as a stall rather than as a step too
# small, and reading the stall is the point.

using SpinorBEC: constrained_hessian_action, _realdot, _tangent_project
using Printf

"""
    rayleigh_descent(ws, psi, v0; μ, dV, n2, n_iter, verbose=true)
        → (; v, q, resid, converged)

Minimise `⟨v,Hv⟩/⟨v,v⟩` over the constrained tangent space from `v0`.

`converged` is `resid ≤ 0.2·|q|`, and callers must honour it: `q` is a valid
UPPER BOUND on `λ_min` either way — any `v` gives one — but it is only close to
`λ_min` when the descent has actually stopped moving.
"""
function rayleigh_descent(ws, psi, v0; μ, dV, n2, n_iter::Int, verbose::Bool=true,
    deflate=())
    H(v) = constrained_hessian_action(ws, psi, v; μ, dV, n2, ε=1.0e-5, order=4)
    # Deflation is folded into the projector rather than applied afterwards, so
    # every iterate stays in the complement — a descent that re-enters the
    # deflated subspace between steps would quietly return λ₁ again and read as
    # a cluster.
    function proj(v)
        w = _tangent_project(v, psi, dV, n2)
        for u in deflate
            w = w .- u .* (_realdot(u, w) * dV / (_realdot(u, u) * dV))
        end
        w
    end
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
