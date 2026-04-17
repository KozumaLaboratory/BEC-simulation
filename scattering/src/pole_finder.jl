"""
Find parameter values at which the s-wave scattering length `a(λ)`
diverges (zero-energy bound-state crossings). Works on any real function
`λ → a(λ)`; typical use is to scan `λ` = potential rescale factor or a
magnetic-field strength.

Method: scan a user-provided grid, detect sign changes in `a` that
correspond to a divergence (i.e. `|a|` is large on both sides, so the
zero is in `1/a`, not in `a` itself). Each such adjacent-index pair is a
bracket. Bisect `1/a(λ)` within every bracket.
"""

"""
    PoleBracket(λ_lo, λ_hi, a_lo, a_hi)

Bracket returned by `bracket_poles`. Contains the two grid points that
straddle a pole along with the measured `a` at each endpoint.
"""
struct PoleBracket
    λ_lo::Float64
    λ_hi::Float64
    a_lo::Float64
    a_hi::Float64
end

"""
    bracket_poles(a_fn, λ_grid; min_abs_a = 0.0) → Vector{PoleBracket}

Scan `λ_grid`, calling `a_fn(λ)` at each point, and collect adjacent-pair
brackets where `sign(a)` flips and both `|a|` exceed `min_abs_a`. The
threshold suppresses spurious brackets around zeros of `a`, where |a|
would be small on both sides of the sign flip.

Keyword `avals` lets callers pass pre-computed scattering lengths
instead of re-evaluating: `bracket_poles((_,)->nothing, λ_grid;
avals=my_avals, min_abs_a=...)`. The `a_fn` is ignored in that case.
"""
function bracket_poles(
    a_fn,
    λ_grid::AbstractVector;
    min_abs_a::Real = 0.0,
    avals::Union{Nothing,AbstractVector{<:Real}} = nothing,
)
    if avals === nothing
        avals_ = Float64[Float64(a_fn(λ)) for λ in λ_grid]
    else
        length(avals) == length(λ_grid) ||
            throw(ArgumentError("avals length must match λ_grid"))
        avals_ = Float64.(avals)
    end
    out = PoleBracket[]
    for i in 1:(length(λ_grid) - 1)
        a1, a2 = avals_[i], avals_[i+1]
        (a1 == 0.0 || a2 == 0.0) && continue
        sign(a1) == sign(a2) && continue
        (abs(a1) < min_abs_a || abs(a2) < min_abs_a) && continue
        push!(out, PoleBracket(Float64(λ_grid[i]), Float64(λ_grid[i+1]), a1, a2))
    end
    out
end

"""
    bisect_pole(a_fn, bracket; atol = 1e-8, rtol = 1e-6, max_iter = 60)
        → (λ_pole, a_lo, a_hi, iters)

Bisect `1/a` on a `PoleBracket`. Each iteration evaluates `a(λ_mid)`:

- if `sign(a_mid) == sign(a_lo)`: `λ_mid` is on the low side of the
  pole, so replace `λ_lo`;
- otherwise replace `λ_hi`.

Stops when `λ_hi − λ_lo < atol + rtol·max(|λ_lo|, |λ_hi|)` or after
`max_iter` evaluations. Returns the midpoint of the final bracket and
the `a` values just outside on either side.

If `a(λ_mid)` is numerically zero the bracket no longer contains a pole
in the `1/a` sense; the routine still proceeds by assigning the midpoint
to the low endpoint, which will then terminate on tolerance.
"""
function bisect_pole(
    a_fn,
    br::PoleBracket;
    atol::Real = 1e-8,
    rtol::Real = 1e-6,
    max_iter::Int = 60,
)
    λ_lo, λ_hi, a_lo, a_hi = br.λ_lo, br.λ_hi, br.a_lo, br.a_hi
    iters = 0
    while (λ_hi - λ_lo) > atol + rtol * max(abs(λ_lo), abs(λ_hi))
        iters += 1
        iters > max_iter && break
        λ_mid = 0.5 * (λ_lo + λ_hi)
        a_mid = Float64(a_fn(λ_mid))
        if a_mid == 0.0
            λ_lo = λ_mid
            a_lo = a_mid
        elseif sign(a_mid) == sign(a_lo)
            λ_lo = λ_mid
            a_lo = a_mid
        else
            λ_hi = λ_mid
            a_hi = a_mid
        end
    end
    (0.5 * (λ_lo + λ_hi), a_lo, a_hi, iters)
end

"""
    find_poles(a_fn, λ_grid; min_abs_a = 0.0, atol = 1e-8, rtol = 1e-6,
               max_iter = 60, avals = nothing) → Vector{Float64}

Convenience: bracket and bisect all poles of `λ → a(λ)` on `λ_grid`.
Returns the refined pole locations. Caller-supplied `avals` skips the
first scan.
"""
function find_poles(
    a_fn,
    λ_grid::AbstractVector;
    min_abs_a::Real = 0.0,
    atol::Real = 1e-8,
    rtol::Real = 1e-6,
    max_iter::Int = 60,
    avals::Union{Nothing,AbstractVector{<:Real}} = nothing,
)
    brackets = bracket_poles(a_fn, λ_grid; min_abs_a, avals)
    [bisect_pole(a_fn, br; atol, rtol, max_iter)[1] for br in brackets]
end
