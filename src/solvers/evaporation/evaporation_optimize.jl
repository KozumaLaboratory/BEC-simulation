# --- Bayesian optimization of the FORT evaporation ramp ---
#
# Wraps the existing `bayesian_optimize` (module Optimization) to find the FORT
# power ramp that MAXIMIZES the BEC atom number. The ramp is a 3-parameter
# transform of a base (experimental) ramp — duration scale, final-power scale,
# and a time-axis warp exponent — keeping the optimizer's dimensionality ≤ 3
# (its acquisition is maximized on an n_grid^d mesh). The optimizer is injected
# as a kwarg so this file does not depend on the load position of module
# Optimization.

export ramp_from_params, optimize_evaporation_ramp, scan_ramp_param, scan_ramp_2d
export ramp_scale_powers, optimize_ramp_coordinate

"""
    ramp_from_params(x, base) -> FortRamp

Transform a base `FortRamp` by `x = [duration_scale, final_power_scale, warp_γ]`:
the total duration is scaled by `x[1]`, the breakpoint times are warped by
`u → u^γ` (γ>1 lingers at high power early, γ<1 drops fast then dwells), and the
final breakpoint powers are scaled by `x[2]`. Intermediate breakpoints keep their
base powers.
"""
function ramp_from_params(x::AbstractVector{<:Real}, base::FortRamp)
    dur_scale, final_scale, γ = Float64(x[1]), Float64(x[2]), Float64(x[3])
    t0 = base.times[1]
    span = base.times[end] - t0
    new_times = [t0 + dur_scale * span * ((t - t0) / span)^γ for t in base.times]
    new_powers = copy(base.powers_W)
    @views new_powers[:, end] .*= final_scale
    FortRamp(new_times, new_powers)
end

"""
    optimize_evaporation_ramp(trap, p, base_ramp; N0, T0, bounds, n_init, n_iter, optimizer)
        -> (; bo, ramp, result)

Optimize the FORT ramp (a 3-parameter transform of `base_ramp`) to maximize the
BEC atom number for the evaporation model `(trap, p)` starting from `(N0, T0)`.
Returns the `bayesian_optimize` named tuple, the best `FortRamp`, and its
`EvapResult`. Each evaluation is a millisecond-scale `run_evaporation`, so
`n_iter` can be large.

`bounds` default to `[(0.5, 3), (0.3, 2), (0.5, 2)]` (duration scale, final-power
scale, warp γ) — bracketing the baseline `[1, 1, 1]` (the unmodified `base_ramp`),
so the optimizer can recover or beat it. `optimizer` is injected (default `bayesian_optimize`)
so the call is load-order independent and stubbable in tests. Ramps that never
reach BEC score `max(PSD)/ζ(3) − 1 ∈ [−1, 0)`, guiding the search toward onset;
any ramp that reaches BEC (`N_BEC ≥ 1`) outranks all failures.
"""
function optimize_evaporation_ramp(
    trap::EvapTrap, p::EvapParams, base_ramp::FortRamp;
    N0::Float64, T0::Float64,
    bounds::Vector{Tuple{Float64, Float64}}=[(0.5, 3.0), (0.3, 2.0), (0.5, 2.0)],
    n_init::Int=8, n_iter::Int=40, n_grid::Int=15, optimizer::Function=bayesian_optimize)
    function objective(x::AbstractVector{<:Real})
        ramp = ramp_from_params(x, base_ramp)
        res = run_evaporation(trap, ramp, p; N0=N0, T0=T0)
        res.reached_bec && return res.N_BEC
        ρmax = isempty(res.psd) ? 0.0 : maximum(res.psd)
        ρmax / _ZETA3 - 1.0
    end
    # n_grid kept small: bayesian_optimize evaluates EI on an n_grid^d candidate mesh,
    # so the default 100 would be 10⁶ points (OOM) for this d=3 ramp parametrization.
    bo = optimizer(objective, bounds; n_init=n_init, n_iter=n_iter, minimise=false, n_grid=n_grid)
    best_ramp = ramp_from_params(bo.best_p, base_ramp)
    best_res = run_evaporation(trap, best_ramp, p; N0=N0, T0=T0)
    (bo=bo, ramp=best_ramp, result=best_res)
end

"""
    scan_ramp_param(trap, p, base_ramp; index, values, base_params=[1,1,1], N0, T0)
        -> Vector{NamedTuple}

Sweep one ramp-transform parameter (`index` ∈ 1:3 = duration scale / final-power
scale / warp γ) over `values`, holding the others at `base_params`, and return per
value `(; value, N_BEC, reached, gamma_eff)`. A cheap 1-D landscape to sanity-check
the dependence before (or instead of) the Bayesian optimizer. `N_BEC` is `NaN`
where BEC is not reached.
"""
function scan_ramp_param(
    trap::EvapTrap, p::EvapParams, base_ramp::FortRamp;
    index::Int, values, base_params=[1.0, 1.0, 1.0], N0::Float64, T0::Float64)
    map(values) do v
        x = collect(Float64, base_params)
        x[index] = Float64(v)
        res = run_evaporation(trap, ramp_from_params(x, base_ramp), p; N0=N0, T0=T0)
        (value=Float64(v),
            N_BEC=res.reached_bec ? res.N_BEC : NaN,
            reached=res.reached_bec,
            gamma_eff=res.gamma_eff)
    end
end

"""
    scan_ramp_2d(trap, p, base_ramp; index1, values1, index2, values2,
                 base_params=[1,1,1], N0, T0) -> Matrix{Float64}

2-D `N_BEC` landscape over two ramp-transform parameters (`index1`/`index2` ∈ 1:3),
holding the third at `base_params`. Returns `M[i,j] = N_BEC` at
`(values1[i], values2[j])` (`NaN` where BEC is not reached) — for contour/heatmap
inspection of the optimization surface before the Bayesian optimizer.
"""
function scan_ramp_2d(
    trap::EvapTrap, p::EvapParams, base_ramp::FortRamp;
    index1::Int, values1, index2::Int, values2,
    base_params=[1.0, 1.0, 1.0], N0::Float64, T0::Float64)
    [
        begin
            x = collect(Float64, base_params)
            x[index1] = Float64(v1)
            x[index2] = Float64(v2)
            res = run_evaporation(trap, ramp_from_params(x, base_ramp), p; N0=N0, T0=T0)
            res.reached_bec ? res.N_BEC : NaN
        end for v1 in values1, v2 in values2
    ]
end

# Objective shared by the optimizers: maximise N_BEC; ramps that never reach BEC
# score in [−1, 0) by how close their peak PSD came to ζ(3), guiding the search.
function _ramp_score(trap::EvapTrap, p::EvapParams, ramp::FortRamp, N0::Float64, T0::Float64)
    res = run_evaporation(trap, ramp, p; N0=N0, T0=T0)
    res.reached_bec && return (res.N_BEC, res)
    ρmax = isempty(res.psd) ? 0.0 : maximum(res.psd)
    (ρmax / _ZETA3 - 1.0, res)
end

"""
    ramp_scale_powers(mults, base) -> FortRamp

Scale every beam's power at breakpoint `i` by `mults[i]` (length = n_breakpoints),
keeping the breakpoint times. The full per-breakpoint reshaping the
3-parameter `ramp_from_params` cannot express.
"""
function ramp_scale_powers(mults::AbstractVector{<:Real}, base::FortRamp)
    length(mults) == length(base.times) ||
        throw(ArgumentError("mults length must equal the number of breakpoints"))
    new_powers = copy(base.powers_W)
    @inbounds for i in eachindex(mults)
        @views new_powers[:, i] .*= Float64(mults[i])
    end
    FortRamp(base.times, new_powers)
end

"""
    optimize_ramp_coordinate(trap, p, base_ramp; N0, T0, mult_bounds=(0.3, 2.5),
                             n_sweeps=4, n_line=13, free=:) -> (; mults, ramp, result, N_BEC, score)

Coordinate-descent over the per-breakpoint power multipliers (a `d = n_breakpoints`
search the grid-mesh `bayesian_optimize` cannot reach), starting from the unmodified
lab ramp (all multipliers 1). Each sweep line-searches every free breakpoint over
`n_line` points in `mult_bounds`, keeping the best; sweeps repeat until no
improvement or `n_sweeps`. `free` selects which breakpoints to vary (default all;
pass e.g. `2:9` to pin the first/last). Deterministic; ~`n_sweeps·|free|·n_line`
model runs (each ms-scale). This is the genuine test of whether the lab ramp is
optimal — a richer family than the 3-parameter transform.
"""
function optimize_ramp_coordinate(
    trap::EvapTrap, p::EvapParams, base_ramp::FortRamp;
    N0::Float64, T0::Float64, mult_bounds::Tuple{Float64, Float64}=(0.3, 2.5),
    n_sweeps::Int=4, n_line::Int=13, free=:)
    nb = length(base_ramp.times)
    idxs = free === Colon() ? collect(1:nb) : collect(free)
    mults = ones(nb)
    best_score, best_res = _ramp_score(trap, p, ramp_scale_powers(mults, base_ramp), N0, T0)
    line = collect(range(mult_bounds[1], mult_bounds[2]; length=n_line))
    for _ in 1:n_sweeps
        improved = false
        for i in idxs
            orig = mults[i]
            local_best, local_val = best_score, orig
            for v in line
                v == orig && continue
                mults[i] = v
                sc, _ = _ramp_score(trap, p, ramp_scale_powers(mults, base_ramp), N0, T0)
                if sc > local_best
                    local_best, local_val = sc, v
                end
            end
            mults[i] = local_val
            local_best > best_score && (best_score=local_best; improved=true)
        end
        improved || break
    end
    best_ramp = ramp_scale_powers(mults, base_ramp)
    _, best_res = _ramp_score(trap, p, best_ramp, N0, T0)
    (mults=mults, ramp=best_ramp, result=best_res,
        N_BEC=best_res.reached_bec ? best_res.N_BEC : NaN, score=best_score)
end
