# --- Pseudo-arclength continuation for tracing phase-boundary curves ---

export trace_phase_boundary, tangent_at, BoundaryTrace, make_phase_diff_eval

# `scan_phase_boundary` (boundary.jl) does 1-D bisection: hunt the
# crossing of two phase energies along a single parameter axis. This
# file extends to **2-D parameter space** (e.g. `(c₁, c_dd)`) and
# traces the *curve* `ΔE = E_A − E_B = 0` continuously.
#
# Each step is a predictor (move along the tangent) + corrector
# (Newton onto the manifold). A 2-step Newton solve at warm-started ψ
# is ~ 50× cheaper than a fresh `find_ground_state` from random
# initialisation, so a 100-point boundary curve costs roughly the
# same as a 2-point Latin-hypercube grid scan would on each parameter
# — except the resulting curve is dense and ordered, which is what
# the B-1 experiment (FL vs uniform polarisation crossing in
# `(c₁, c_dd)`) needs.
#
# Currently 2-D specific: in `d > 2` the `ΔE = 0` set is a `(d − 1)`-
# dimensional manifold and the tangent picker has to choose a
# direction within an `(d − 1)`-D null space — out of scope for the
# first implementation. The tangent update for `d = 2` reduces to
# rotating `∇F` by 90°; we exploit that here for clarity.

using LinearAlgebra: dot, norm, I as IDENT

"""
    BoundaryTrace

Output of [`trace_phase_boundary`](@ref). Stores every accepted boundary
point (one per row of `points`), the residual `|F(θ)|` at the corrector
exit, the actual arc-step taken (may shrink under Newton failure), and
the per-step convergence flag.
"""
struct BoundaryTrace
    points::Matrix{Float64}            # (n × d) — accepted boundary points
    residuals::Vector{Float64}         # `|F(θ_i)|` at exit
    step_taken::Vector{Float64}        # actual arc-step at step i
    converged::Vector{Bool}            # corrector convergence flag
    tangents::Matrix{Float64}          # (n × d) — tangent at each point
end

"""
    trace_phase_boundary(F, θ_init, t_init; …) → BoundaryTrace

Pseudo-arclength continuation of the curve `F(θ) = 0` in 2-D parameter
space, starting from a known on-curve point `θ_init` with initial
tangent direction `t_init`.

Arguments
=========
- `F::Function`  — `F(θ::Vector{Float64})::Real` returns `ΔE(θ) = E_A(θ) − E_B(θ)`.
                   Must satisfy `|F(θ_init)| ≪ newton_tol`.
- `θ_init`       — initial boundary point (length-2 vector)
- `t_init`       — initial unit tangent (length-2 vector). Must satisfy
                   `⟨∇F(θ_init), t_init⟩ ≈ 0`. Pass `tangent_at(F, θ_init)` to derive.

Keyword arguments
=================
- `arc_step = 0.1`            — initial predictor step length
- `max_steps = 100`           — maximum continuation steps
- `newton_tol = 1e-8`         — corrector convergence tolerance on `|F|`
- `newton_max_iter = 20`      — Newton iterations per corrector
- `finite_diff_h = 1e-4`      — central-FD step for `∇F`
- `step_shrink = 0.5`         — multiplier when Newton fails
- `step_grow = 1.2`           — multiplier on accepted step
- `arc_step_min = 1e-6`       — terminate when shrinking past this
- `arc_step_max = 0.5`        — cap on grown step
- `verbose = true`            — per-step status

Algorithm
=========
At each step:
  predictor:  `θ_pred = θ + h · t`
  corrector:  Newton on the augmented 2×2 system
      [ ∇F  ] [δθ] = [ −F(θ + δθ) ]
      [  tᵀ ] [   ]   [ −⟨θ + δθ − θ_pred, t⟩ ]
  After acceptance, the tangent is rotated 90° from `∇F` (2-D specific)
  with sign chosen to maintain direction continuity, and the step is
  multiplicatively grown / shrunk.

Falls back gracefully when `∇F` is near-singular: a nearly-vertical
boundary curve (`∂F/∂θ₁ → 0`) forces the augmented system to use the
arc-length row to disambiguate.

See `scan_phase_boundary` (in `boundary.jl`) for the 1-D bisection
counterpart.
"""
function trace_phase_boundary(
    F::Function,
    θ_init::AbstractVector{<:Real},
    t_init::AbstractVector{<:Real};
    arc_step::Float64=0.1,
    max_steps::Int=100,
    newton_tol::Float64=1.0e-8,
    newton_max_iter::Int=20,
    finite_diff_h::Float64=1.0e-4,
    step_shrink::Float64=0.5,
    step_grow::Float64=1.2,
    arc_step_min::Float64=1.0e-6,
    arc_step_max::Float64=0.5,
    verbose::Bool=_default_solver_verbose(),
)
    d = length(θ_init)
    d == 2 || throw(
        ArgumentError(
            "trace_phase_boundary currently supports d = 2 (got d = $d). " *
            "Higher-d would need the (d-1)-D tangent subspace logic.",
        ),
    )
    length(t_init) == d ||
        throw(DimensionMismatch("t_init length $(length(t_init)) ≠ d = $d"))

    # Initial tangent (normalised)
    t = collect(Float64, t_init)
    t ./= max(norm(t), 1.0e-30)

    pts = [collect(Float64, θ_init)]    # row-list to avoid pre-allocating max_steps+1
    res = Float64[abs(F(θ_init))]
    steps = Float64[0.0]
    convs = Bool[true]
    tans = [copy(t)]

    h = arc_step
    θ = collect(Float64, θ_init)

    for step in 1:max_steps
        θ_pred = θ .+ h .* t
        θ_new, n_iter, conv = _newton_corrector(
            F, θ_pred, t;
            newton_tol, newton_max_iter, finite_diff_h,
        )

        if conv
            θ = θ_new
            push!(pts, copy(θ))
            push!(res, abs(F(θ)))
            push!(steps, h)
            push!(convs, true)
            t_new = _tangent_2d(F, θ; finite_diff_h)
            dot(t_new, t) < 0 && (t_new .= .-t_new)
            t = t_new
            push!(tans, copy(t))
            h = min(arc_step_max, h * step_grow)
            verbose && @info("step=$step accepted",
                θ=round.(θ; digits=4),
                F=round(res[end]; sigdigits=3),
                h=round(h; sigdigits=3),
                newton=n_iter)
        else
            h *= step_shrink
            verbose && @info("step=$step Newton failed, shrinking h",
                h=round(h; sigdigits=3))
            if h < arc_step_min
                verbose && @info("step=$step arc_step below minimum, terminating")
                break
            end
        end
    end

    n_pts = length(pts)
    points = zeros(Float64, n_pts, d)
    tangents = zeros(Float64, n_pts, d)
    for i in 1:n_pts
        points[i, :] = pts[i]
        tangents[i, :] = tans[i]
    end
    BoundaryTrace(points, res, steps, convs, tangents)
end

"""
    tangent_at(F, θ; finite_diff_h=1e-4) → Vector{Float64}

Compute a unit-length tangent to the curve `F(θ) = 0` at `θ` (2-D
parameter space). Convenience helper so the caller can derive
`t_init` for [`trace_phase_boundary`](@ref) without re-implementing
the 90°-rotation logic.
"""
function tangent_at(F::Function, θ::AbstractVector{<:Real}; finite_diff_h::Float64=1.0e-4)
    _tangent_2d(F, collect(Float64, θ); finite_diff_h)
end

# 2-D: tangent ∝ rotate ∇F by 90°.
function _tangent_2d(F::Function, θ::Vector{Float64}; finite_diff_h::Float64=1.0e-4)
    g = _grad_F(F, θ; finite_diff_h)
    t = [-g[2], g[1]]
    n = norm(t)
    n < 1.0e-30 && throw(
        ArgumentError(
            "∇F vanishes at θ = $θ; cannot define a tangent (singular point or false boundary)"
        ),
    )
    t ./ n
end

# Central finite-difference gradient of a scalar-valued F at θ.
function _grad_F(F::Function, θ::Vector{Float64}; finite_diff_h::Float64=1.0e-4)
    d = length(θ)
    g = zeros(Float64, d)
    e = similar(θ)
    @inbounds for i in 1:d
        fill!(e, 0.0)
        e[i] = finite_diff_h
        g[i] = (F(θ .+ e) - F(θ .- e)) / (2 * finite_diff_h)
    end
    g
end

# Newton corrector: solve
#   F(θ_new) = 0
#   ⟨θ_new − θ_pred, t⟩ = 0     (arc-length constraint, here 0 means
#                                we land exactly on the predictor's tangent line)
# augmented 2×2 Jacobian:
#   [ ∇F ]
#   [ tᵀ ]
function _newton_corrector(
    F::Function, θ_pred::Vector{Float64}, t::Vector{Float64};
    newton_tol::Float64, newton_max_iter::Int, finite_diff_h::Float64,
)
    θ = copy(θ_pred)
    for k in 1:newton_max_iter
        f_val = F(θ)
        c_val = dot(θ .- θ_pred, t)
        # 2-norm residual for convergence test
        if abs(f_val) < newton_tol && abs(c_val) < newton_tol
            return θ, k, true
        end
        ∇F = _grad_F(F, θ; finite_diff_h)
        # Augmented Jacobian:
        #  [ ∇F ; tᵀ ]
        J = vcat(∇F', t')
        rhs = -[f_val, c_val]
        local δθ
        try
            δθ = J \ rhs
        catch e
            # Singular: bail out
            return θ, k, false
        end
        # Damping: limit step to ‖δθ‖ ≤ 0.5 to avoid jumping off-manifold
        nδ = norm(δθ)
        nδ > 0.5 && (δθ .*= 0.5 / nδ)
        θ .+= δθ
    end
    # Failed to converge in newton_max_iter
    θ, newton_max_iter, false
end

# --- SpinorBEC adapter --------------------------------------------------
#
# `trace_phase_boundary` only needs a scalar `F(θ)`. The line below
# turns the SpinorBEC L-BFGS solver into one such `F` whose value is
# the energy difference between two competing phases. The closure
# carries warm-start state for both branches so consecutive `θ`s
# (the continuation pattern) skip full ITP convergence.

"""
    make_phase_diff_eval(grid, atom;
                         parameter_setter,
                         phase_A_init=:m_plus_F, phase_B_init=:polar,
                         n_steps=500, tol=1e-7,
                         sobolev_alpha=0.0,
                         verbose=false) → F::Function

Build a closure `F(θ::Vector{Float64})::Float64` that returns
`E_A(θ) − E_B(θ)`, where each `E_*` is computed via
`find_ground_state_lbfgs` from the corresponding initial state.
Suitable as the `F` argument of [`trace_phase_boundary`](@ref).

`parameter_setter(θ)` must return a `NamedTuple` of `find_ground_state_lbfgs`
kwargs (typically `interactions`, `c_dd`, `enable_ddi`, `zeeman`, …).
The grid + atom are fixed across the trace, so the `Workspace`
specialisation is hit once for each branch.

Warm-start
==========
The closure caches the converged ψ of each branch between calls.
When called at a new `θ` close to the previous one (the continuation
predictor lands near the manifold), the L-BFGS warm-start from the
cached ψ typically converges in 10-50 iterations instead of the
500-2000 of a cold start — that's the load-bearing speed-up for
`trace_phase_boundary` over a fresh full-grid scan.

Pass `phase_A_init` and `phase_B_init` as `Symbol`s recognised by
`init_psi` (e.g. `:m_plus_F`, `:polar`, `:m_minus_F`, …). The first
call uses these symbols; subsequent calls reuse the cached ψ.

Reset behaviour
===============
If a Newton corrector inside `trace_phase_boundary` shrinks the
arc-step and then succeeds, the cached ψ from the *previously
accepted* point is the correct warm-start — the closure is simply
called again at the new predictor and Newton converges. There's no
explicit reset hook; if the user wants to restart from cold (e.g.
crossing into a topologically different basin), construct a new
closure.
"""
function make_phase_diff_eval(
    grid::Grid{N}, atom::AtomSpecies;
    parameter_setter::Function,
    phase_A_init::Symbol=:m_plus_F,
    phase_B_init::Symbol=:polar,
    n_steps::Int=500,
    tol::Float64=1.0e-7,
    sobolev_alpha::Float64=0.0,
    verbose::Bool=false,
) where {N}
    psi_A_warm = Ref{Any}(nothing)
    psi_B_warm = Ref{Any}(nothing)

    function F(θ::AbstractVector{<:Real})
        kwargs = parameter_setter(collect(Float64, θ))

        # Branch A
        psi_init_A = psi_A_warm[]
        init_kwargs_A =
            psi_init_A === nothing ?
            (initial_state=phase_A_init,) :
            (psi_init=psi_init_A,)
        r_A = find_ground_state_lbfgs(;
            grid, atom,
            kwargs...,
            init_kwargs_A...,
            n_steps, tol, sobolev_alpha,
            verbose=verbose,
        )
        psi_A_warm[] = copy(r_A.workspace.state.psi)

        # Branch B
        psi_init_B = psi_B_warm[]
        init_kwargs_B =
            psi_init_B === nothing ?
            (initial_state=phase_B_init,) :
            (psi_init=psi_init_B,)
        r_B = find_ground_state_lbfgs(;
            grid, atom,
            kwargs...,
            init_kwargs_B...,
            n_steps, tol, sobolev_alpha,
            verbose=verbose,
        )
        psi_B_warm[] = copy(r_B.workspace.state.psi)

        Float64(r_A.energy - r_B.energy)
    end
    F
end
