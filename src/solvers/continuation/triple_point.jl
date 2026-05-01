# --- Triple-point hunting via AL × pseudo-arclength (R37, 2026-05-02) ---
#
# Combines `active_learn_phase_scan` (R36) with `trace_phase_boundary`
# (R35) to find points in parameter space where 3+ phases coexist (the
# "triple point" of a phase diagram, where 3 boundary curves meet) and
# trace the curves emanating from each.
#
# Strategy
# ========
# 1. AL scan with entropy acquisition. The entropy peaks at points
#    where 3+ phase candidates have nearly equal distances — these
#    are exactly the triple-point candidates.
# 2. For each candidate, identify the top-3 phase names. Build the
#    3 pairwise difference closures `F_AB`, `F_AC`, `F_BC` from a
#    single eval_fn via `pair_F_factory`.
# 3. From the candidate point, trace each `F_XY` outward via
#    `trace_phase_boundary`. The initial tangent for each curve is
#    derived from `tangent_at(F_XY, θ_triple)` (perpendicular to ∇F_XY).
# 4. Return the candidate location plus the 3 boundary traces.
#
# Novel combination
# =================
# AL × continuation for triple-point detection is, to my knowledge,
# not documented in spinor-BEC literature. F=6 phase diagrams have
# multiple potential triple-points (KU §5: polar / cyclic / FM / D-2v
# possible coexistences) — automatically detecting them with this
# pipeline is a research-paper-class capability beyond what `bisection`
# or single-axis scans offer.

using LinearAlgebra: norm

"""
    pair_F_factory(eval_fn, name_A::Symbol, name_B::Symbol) → Function

Build a closure `F(θ)::Float64` that returns
`distance_to_A(θ) − distance_to_B(θ)`, where `distance_to_X` is read
out of `eval_fn(θ).scores` (the `classify_phase_distance`-shaped output).

Suitable as the `F` argument of [`trace_phase_boundary`](@ref) when
hunting the boundary between two specific phases.

Throws if either phase name is missing from the scores at any θ
(silently propagates `NaN` would mask bugs).
"""
function pair_F_factory(eval_fn::Function, name_A::Symbol, name_B::Symbol)
    function F(θ::AbstractVector{<:Real})
        result = eval_fn(θ)
        scores = if hasproperty(result, :scores)
            result.scores
        elseif hasproperty(result, :ranking)
            result.ranking
        else
            throw(ArgumentError("eval_fn output has no :scores / :ranking field"))
        end
        d_A = nothing
        d_B = nothing
        for s in scores
            haskey(s, :name) && haskey(s, :distance) || continue
            s.name == name_A && (d_A = Float64(s.distance))
            s.name == name_B && (d_B = Float64(s.distance))
        end
        d_A === nothing &&
            throw(ArgumentError("phase :$name_A not in scores at θ = $θ"))
        d_B === nothing &&
            throw(ArgumentError("phase :$name_B not in scores at θ = $θ"))
        d_A - d_B
    end
    F
end

"""
    TriplePointCandidate

A single candidate triple-point and its top-3 phase names plus
a tie-quality metric. Returned by [`detect_triple_points`](@ref).

`tie_ratio = (d₃ − d₁) / max(d₁, 1e-10)` — smaller is tighter
(better triple-point candidate). 0.1 is a typical cutoff.
"""
struct TriplePointCandidate
    θ::Vector{Float64}
    phases::Vector{Symbol}              # top-3 phase names by distance
    distances::Vector{Float64}          # corresponding distances
    entropy::Float64                    # AL entropy at this θ
    tie_ratio::Float64                  # (d3 - d1) / d1
end

"""
    detect_triple_points(eval_fn, bounds;
                         n_init=10, n_iter=50,
                         temperature=0.1, tie_ratio_max=0.15,
                         min_phases=3, seed=42, verbose=true)
        → Vector{TriplePointCandidate}

Run an AL phase scan and filter the visited θ points for 3-way (or
N-way) distance ties. Each candidate is sorted by tie quality so the
caller can pick the strictest triple-point as the seed for
[`trace_triple_point_curves`](@ref).

Arguments mostly forwarded to [`active_learn_phase_scan`](@ref).
`tie_ratio_max` controls how strict the "tie" is: with the default
0.15, the third-closest phase must be within 15 % of the first.
`min_phases` requires at least that many candidate phases in the
scores list (3 for a triple, 4 for a quadruple, …).

Verbose prints one line per detected candidate.
"""
function detect_triple_points(
    eval_fn::Function,
    bounds::Vector{Tuple{Float64, Float64}};
    n_init::Int=10,
    n_iter::Int=50,
    temperature::Float64=0.1,
    tie_ratio_max::Float64=0.15,
    min_phases::Int=3,
    ℓ::Union{Nothing, Float64}=nothing,
    n_grid::Int=50,
    seed::Int=42,
    verbose::Bool=true,
)
    al = active_learn_phase_scan(eval_fn, bounds;
        n_init, n_iter, temperature, ℓ, n_grid, seed, verbose=false,
    )

    candidates = TriplePointCandidate[]
    for i in 1:size(al.X_history, 1)
        θ_i = collect(al.X_history[i, :])
        result = eval_fn(θ_i)
        scores = if hasproperty(result, :scores)
            result.scores
        elseif hasproperty(result, :ranking)
            result.ranking
        else
            continue
        end
        length(scores) >= min_phases || continue

        # Need scores sorted by distance ascending.
        sorted = sort(collect(scores); by=s -> Float64(s.distance))

        d1 = Float64(sorted[1].distance)
        d_n = Float64(sorted[min_phases].distance)
        tie = (d_n - d1) / max(d1, 1.0e-10)

        if tie <= tie_ratio_max
            push!(candidates,
                TriplePointCandidate(
                    θ_i,
                    Symbol[s.name for s in sorted[1:min_phases]],
                    Float64[Float64(s.distance) for s in sorted[1:min_phases]],
                    al.y_history[i],
                    tie,
                ),
            )
        end
    end

    sort!(candidates; by=c -> c.tie_ratio)

    if verbose
        if isempty(candidates)
            println("detect_triple_points: 0 candidates with tie_ratio ≤ $tie_ratio_max " *
                    "out of $(size(al.X_history, 1)) AL samples")
        else
            println("detect_triple_points: $(length(candidates)) candidate(s) " *
                    "(best tie_ratio = $(round(candidates[1].tie_ratio; sigdigits=3)))")
            for (i, c) in enumerate(candidates[1:min(5, length(candidates))])
                println("  $i: θ=$(round.(c.θ; digits=4)), phases=$(c.phases), tie=$(round(c.tie_ratio; sigdigits=3))")
            end
        end
    end
    candidates
end

"""
    trace_triple_point_curves(candidate, eval_fn;
                              arc_step=0.05, max_steps=80,
                              kwargs_for_trace...) → Dict{Symbol, BoundaryTrace}

Given a triple-point candidate (output of [`detect_triple_points`](@ref)),
trace the 3 pairwise phase boundaries emanating from it.

Returns a `Dict{Symbol, BoundaryTrace}` keyed by the phase pair
(e.g. `:polar_FM`, `:polar_BN`, `:FM_BN`) — one [`BoundaryTrace`](@ref)
per pair. Each trace starts from `candidate.θ` and walks outward via
[`trace_phase_boundary`](@ref).

If the candidate has more than 3 close phases (`length(phases) > 3`),
all C(N, 2) = N(N−1)/2 pairs are traced.

`kwargs_for_trace` are forwarded to `trace_phase_boundary` (e.g.
`newton_tol`, `arc_step_max`, `verbose`).
"""
function trace_triple_point_curves(
    candidate::TriplePointCandidate,
    eval_fn::Function;
    arc_step::Float64=0.05,
    max_steps::Int=80,
    verbose::Bool=true,
    kwargs_for_trace...,
)
    phases = candidate.phases
    n = length(phases)
    n >= 2 ||
        throw(ArgumentError("need at least 2 phases to trace pairwise boundaries"))

    out = Dict{Symbol, BoundaryTrace}()
    for i in 1:n, j in (i + 1):n
        a, b = phases[i], phases[j]
        F_ab = pair_F_factory(eval_fn, a, b)
        # Tangent at the candidate, perpendicular to ∇F_ab
        t_init = try
            tangent_at(F_ab, candidate.θ)
        catch e
            verbose && println("  pair $(a)_$(b): tangent_at failed ($(e)), skipping")
            continue
        end
        verbose && println("  tracing $(a)_$(b) from θ=$(round.(candidate.θ; digits=4)) tangent=$(round.(t_init; digits=3))")
        trace = trace_phase_boundary(F_ab, candidate.θ, t_init;
            arc_step, max_steps, verbose=false, kwargs_for_trace...,
        )
        out[Symbol("$(a)_$(b)")] = trace
    end
    out
end
