# A one-sided bound on the minimum of an energy functional.
#
# WHAT THIS IS FOR. `differential` grounding says two independent statements of
# the same physics disagree. It does not say WHICH is wrong, and when the other
# statement is a published number there is no third implementation to break the
# tie. A trial wave function does break it: evaluated on the SAME functional it
# is a strict upper bound on that functional's minimum, so anyone reporting a
# converged ground state ABOVE it is reporting something that is not the
# minimum. The bound needs no true answer, no agreement, and no trust in either
# solver -- only that both are minimizing the same functional.
#
# It is one-sided, which is the whole point and also the whole limitation:
#   * a claim ABOVE the bound is refuted;
#   * a claim BELOW the bound is not confirmed by this, it is merely allowed.
#
# A WEAK BOUND IS A STRONGER RESULT. If a crude trial family already beats the
# claim, the real minimum is further below still. Report the slack between the
# bound and your own solution so the reader can see how much room was left over.
#
# CAVEAT the caller owns: the trial family must lie in the same sector as the
# claim. A polarized Gaussian bounds the polarized branch; it says nothing
# about a vortex branch it cannot represent. `variational_bound` cannot check
# this and does not try.

export VariationalBound, variational_bound, exceeds, bound_report

"""
    VariationalBound

Result of [`variational_bound`](@ref).

`bound` is the value to compare claims against. When a `cross_check` was given
it is the LEAST BINDING (largest) of the two evaluations, so a verdict drawn
from it does not depend on which of the two statements is the more accurate.

Fields: `bound`, `params` (the minimizer), `primary`/`cross` (the two
evaluations at `params`, `cross === nothing` if none was supplied), `rel_gap`
(their relative difference), `n_eval`, `converged`.
"""
struct VariationalBound
    bound::Float64
    params::Vector{Float64}
    primary::Float64
    cross::Union{Float64, Nothing}
    rel_gap::Float64
    n_eval::Int
    converged::Bool
end

"""
    variational_bound(f, x0; cross_check=nothing, maxiter=2000, tol=1e-12,
                      xtol=1e-9, step=0.1) -> VariationalBound

Minimize `f(x::Vector{Float64}) -> Real` from `x0` by Nelder-Mead and return a
one-sided upper bound on the functional's minimum.

`f` must evaluate the SAME functional the claim under test minimizes; that is
the one precondition the whole method rests on, and it is the caller's to
establish (term by term, against the source).

`cross_check`, if given, is a SECOND independent statement of the same
functional, evaluated once at the minimizer. Its purpose is not accuracy but
independence: if the two disagree, the returned `bound` is the least binding of
them, so the verdict survives not knowing which is right. Inspect `rel_gap`
and say what it was.

Parameterise `f` so the search is unconstrained -- pass log-widths rather than
widths if the widths must stay positive.

Non-finite values are treated as `+Inf`, so an infeasible trial simply loses.

Convergence needs BOTH the value spread (`tol`) and the simplex diameter
(`xtol`) to be small; the value test alone is satisfied by a simplex straddling
the minimum symmetrically. `converged` is a field, not an exception — check it.
"""
function variational_bound(f, x0::AbstractVector{<:Real};
    cross_check=nothing, maxiter::Int=2000, tol::Real=1e-12,
    xtol::Real=1e-9, step::Real=0.1)
    n = length(x0)
    n >= 1 || throw(ArgumentError("variational_bound needs at least one parameter"))
    neval = Ref(0)
    g = function (x)
        neval[] += 1
        v = f(x)
        isfinite(v) ? Float64(v) : Inf
    end

    # simplex: x0 plus one perturbed vertex per dimension
    simplex = [collect(float.(x0))]
    for i in 1:n
        v = collect(float.(x0))
        v[i] += step
        push!(simplex, v)
    end
    val = [g(s) for s in simplex]
    all(isinf, val) && throw(
        ArgumentError(
            "variational_bound: f is non-finite over the whole initial simplex; " *
            "check the parameterisation (log-widths?) and x0"),
    )

    converged = false
    for _ in 1:maxiter
        o = sortperm(val)
        simplex, val = simplex[o], val[o]
        # BOTH tests, not just the value one. A value-only test is satisfied by
        # a simplex straddling the minimum symmetrically -- its vertices have
        # equal f while sitting far apart -- so the search stops on the first
        # symmetric pair it stumbles into. Measured while writing this: from
        # x0 = [-1.0] the harmonic case then returned 0.51003 at s = 1.105
        # instead of 0.5 at s = 1, converged = true, in ten evaluations.
        spread = abs(val[end] - val[1]) <= tol * (abs(val[1]) + tol)
        diam = maximum(maximum(abs, s .- simplex[1]) for s in simplex)
        if spread && diam <= xtol
            converged = true
            break
        end
        centroid = sum(simplex[1:(end - 1)]) ./ n
        worst = simplex[end]
        xr = centroid .+ (centroid .- worst)          # reflect
        fr = g(xr)
        if fr < val[1]
            xe = centroid .+ 2 .* (centroid .- worst)  # expand
            fe = g(xe)
            simplex[end], val[end] = fe < fr ? (xe, fe) : (xr, fr)
        elseif fr < val[end - 1]
            simplex[end], val[end] = xr, fr
        else
            xc = centroid .+ 0.5 .* (worst .- centroid)   # contract
            fc = g(xc)
            if fc < val[end]
                simplex[end], val[end] = xc, fc
            else                                           # shrink
                for i in 2:length(simplex)
                    simplex[i] = (simplex[1] .+ simplex[i]) ./ 2
                    val[i] = g(simplex[i])
                end
            end
        end
    end

    i = argmin(val)
    xbest, primary = simplex[i], val[i]
    if cross_check === nothing
        return VariationalBound(primary, xbest, primary, nothing, 0.0,
            neval[], converged)
    end
    c = Float64(cross_check(xbest))
    gap = abs(c - primary) / max(abs(primary), eps())
    # LEAST BINDING of the two, so the verdict does not depend on which is right
    VariationalBound(max(primary, c), xbest, primary, c, gap, neval[], converged)
end

"""
    exceeds(b::VariationalBound, claim) -> Bool

Is `claim` ABOVE the bound, i.e. refuted? A claimed ground-state energy cannot
lie above an achievable trial energy of the same functional.

`false` does NOT mean the claim is confirmed — the bound is one-sided.
"""
exceeds(b::VariationalBound, claim::Real) = claim > b.bound

"""
    bound_report(b, claims::AbstractDict, ours=nothing) -> String

Render the verdict the way it must be read: each claim against the bound, and
the slack between the bound and `ours` when supplied, because a bound that a
crude trial family already achieves is a WEAK one and exceeding a weak bound is
the stronger statement.
"""
function bound_report(b::VariationalBound, claims::AbstractDict, ours=nothing)
    io = IOBuffer()
    println(io, "variational upper bound = ", round(b.bound; sigdigits=7),
        b.converged ? "" : "   (WARNING: minimizer did not converge)")
    if b.cross !== nothing
        println(io, "  two statements: ", round(b.primary; sigdigits=7), " and ",
            round(b.cross; sigdigits=7), "  (", round(100 * b.rel_gap; digits=3),
            " % apart; the least binding is used)")
    end
    for (name, v) in sort(collect(claims); by=first)
        println(io, "  ", rpad(String(name), 24),
            lpad(string(round(v; sigdigits=7)), 14), "   ",
            exceeds(b, v) ? "*** ABOVE the bound — refuted" : "below the bound")
    end
    if ours !== nothing
        println(io, "  slack below the bound (ours): ",
            round(b.bound - ours; sigdigits=4),
            " — the bound is weak by this much, which makes any claim above it",
            " the stronger result")
    end
    String(take!(io))
end
