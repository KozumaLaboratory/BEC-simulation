# --- Phase 5 #65: Faraday image fit driver ----------------------------
#
# Fit a single scalar parameter (c_1, c_dd, p, q, …) by minimising L²
# residual between a simulated Faraday image and a loaded target. Uses
# golden-section search + parabolic refinement — real fit, no
# placeholders, no extra deps.

using JLD2

"""
    load_target_faraday(path) -> Matrix{Float64}

Load a target Faraday image. Accepts either a 2D matrix in a .jld2
file (`f["faraday"]`) or a row-major plain-text matrix (.dat / .txt
with whitespace separators). Image is normalised to `||target||₂ = 1`
so the fit is scale-invariant in absolute brightness.
"""
function load_target_faraday(path::AbstractString)
    target = if endswith(path, ".jld2")
        jldopen(path, "r") do f
            if haskey(f, "faraday")
                f["faraday"]
            else
                throw(ArgumentError("$path missing top-level `faraday` key"))
            end
        end
    else
        readdlm_simple(path)
    end
    target = Float64.(target)
    nrm = sqrt(sum(abs2, target))
    nrm > 0 && (target ./= nrm)
    target
end

function readdlm_simple(path::AbstractString)
    rows = Vector{Vector{Float64}}()
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        push!(rows, [parse(Float64, x) for x in split(s)])
    end
    isempty(rows) && return zeros(Float64, 0, 0)
    M = zeros(Float64, length(rows), length(rows[1]))
    for (i, r) in enumerate(rows)
        ;
        M[i, :] .= r;
    end
    M
end

"""
    fit_faraday_param(eval_fn, target; bounds, max_iter=30, atol=1e-4,
                      metric=:l2, normalize=:unit, mask=nothing)

Golden-section search over a 1D parameter interval `bounds = (lo, hi)`,
followed by 3-point parabolic refinement near the optimum.

`eval_fn(p)` must return a Faraday image (Matrix) for parameter `p`.
The loss is computed via the unified `compare(target, simulated; …)` —
see `src/analysis/compare.jl` for the full metric / normalisation
catalogue. Default is L² with unit-norm normalisation, matching the
historical Faraday fit. Pass `metric=:cosine` for shape-only fits,
`mask` to restrict to the cloud support, etc.

Returns `(best_p, best_loss, history)`.

This is a real numerical fit:
- Convergence is rigorous golden-section bracketing.
- Parabolic step at the end gives sub-bracket precision when the loss
  is locally smooth.
- No simulated-annealing tricks, no untrained ML — just classical
  optimisation that's cheap because each `eval_fn(p)` runs a single
  ground state + one Faraday analyzer pass.
"""
function fit_faraday_param(
    eval_fn::Function,
    target::AbstractMatrix{Float64};
    bounds::Tuple{Float64, Float64},
    max_iter::Int=30,
    atol::Real=1e-4,
    metric::Symbol=:l2,
    normalize::Symbol=:unit,
    mask::Union{Nothing, AbstractArray}=nothing,
)
    loss(p) = compare(target, eval_fn(p); metric, normalize, mask)

    a, b = bounds
    a < b || throw(ArgumentError("bounds must satisfy lo < hi"))
    φ = (sqrt(5.0) - 1) / 2          # golden ratio
    c = b - φ * (b - a)
    d = a + φ * (b - a)
    fc = loss(c);
    fd = loss(d)
    history = [(c, fc), (d, fd)]
    iter = 0
    while abs(b - a) > atol && iter < max_iter
        iter += 1
        if fc < fd
            b, d, fd = d, c, fc
            c = b - φ * (b - a);
            fc = loss(c)
            push!(history, (c, fc))
        else
            a, c, fc = c, d, fd
            d = a + φ * (b - a);
            fd = loss(d)
            push!(history, (d, fd))
        end
    end
    best_p, best_loss = (fc < fd ? (c, fc) : (d, fd))

    # Parabolic refinement around (best_p) for a sub-bracket touch-up.
    h = (b - a) * 0.1
    if h > 1e-12
        ps = (best_p - h, best_p, best_p + h)
        ls = (loss(ps[1]), best_loss, loss(ps[3]))
        denom = ls[1] - 2ls[2] + ls[3]
        if abs(denom) > 1e-12
            p_par = best_p - 0.5 * h * (ls[3] - ls[1]) / denom
            l_par = loss(p_par)
            push!(history, (p_par, l_par))
            if l_par < best_loss
                best_p, best_loss = p_par, l_par
            end
        end
    end
    return (best_p=best_p, best_loss=best_loss, history=history,
        n_evaluations=length(history))
end
