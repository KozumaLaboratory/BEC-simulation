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
using LinearAlgebra: eigen, Symmetric

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
    # Previous iterate, carried so the search space is span{v, w, v_prev} —
    # LOBPCG's three-term form. Plain 2×2 steepest descent on a Rayleigh
    # quotient converges at (κ-1)/(κ+1) per step, which at κ ~ 5e3 is 0.9996:
    # 300 iterations left every mode at 150-200 % residual and the verdict was
    # read off bounds that had not settled. The third term is what makes this
    # affordable.
    vp = nothing
    Hvp = nothing
    verbose && @printf("  %5s %14s %12s\n", "iter", "Rayleigh q", "|resid|")
    for it in 1:n_iter
        w = proj(Hv .- qv .* v)
        nw = sqrt(_realdot(w, w) * dV)
        verbose && (it % 10 == 1 || it == n_iter) &&
            (@printf("  %5d %14.6e %12.3e\n", it - 1, qv, nw); flush(stdout))
        nw < 1.0e-12 && break
        w ./= nw
        Hw = H(w)
        # Rayleigh-Ritz over the basis, orthonormalised in the real inner
        # product the whole solver uses. Two vectors on the first step, three
        # afterwards.
        basis = vp === nothing ? [v, w] : [v, w, vp]
        hbas = vp === nothing ? [Hv, Hw] : [Hv, Hw, Hvp]
        for i in eachindex(basis)
            for j in 1:(i - 1)
                c = _realdot(basis[j], basis[i]) * dV
                basis[i] = basis[i] .- c .* basis[j]
                hbas[i] = hbas[i] .- c .* hbas[j]
            end
            nb = sqrt(_realdot(basis[i], basis[i]) * dV)
            nb < 1.0e-10 && (nb = Inf)
            basis[i] = basis[i] ./ nb
            hbas[i] = hbas[i] ./ nb
        end
        keep = [i for i in eachindex(basis) if all(isfinite, basis[i])]
        nb = length(keep)
        A = [_realdot(basis[keep[i]], hbas[keep[j]]) * dV for i in 1:nb, j in 1:nb]
        A = (A .+ A') ./ 2
        F = eigen(Symmetric(A))
        cvec = F.vectors[:, 1]
        vnew = sum(cvec[i] .* basis[keep[i]] for i in 1:nb)
        Hnew = sum(cvec[i] .* hbas[keep[i]] for i in 1:nb)
        vp, Hvp = v, Hv
        v, Hv = vnew, Hnew
        nv = sqrt(_realdot(v, v) * dV)
        v ./= nv
        Hv ./= nv
        qv = rq(v, Hv)
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
