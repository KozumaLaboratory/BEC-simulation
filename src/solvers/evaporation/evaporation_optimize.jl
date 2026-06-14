# --- Bayesian optimization of the FORT evaporation ramp ---
#
# Wraps the existing `bayesian_optimize` (module Optimization) to find the FORT
# power ramp that MAXIMIZES the BEC atom number. The ramp is a 3-parameter
# transform of a base (experimental) ramp — duration scale, final-power scale,
# and a time-axis warp exponent — keeping the optimizer's dimensionality ≤ 3
# (its acquisition is maximized on an n_grid^d mesh). The optimizer is injected
# as a kwarg so this file does not depend on the load position of module
# Optimization.

export ramp_from_params, optimize_evaporation_ramp, scan_ramp_param

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

`bounds` default to `[(1, 5), (0.005, 0.05), (0.5, 3)]` (duration scale,
final-power scale, warp γ). `optimizer` is injected (default `bayesian_optimize`)
so the call is load-order independent and stubbable in tests. Ramps that never
reach BEC score `max(PSD)/ζ(3) − 1 ∈ [−1, 0)`, guiding the search toward onset;
any ramp that reaches BEC (`N_BEC ≥ 1`) outranks all failures.
"""
function optimize_evaporation_ramp(
    trap::EvapTrap, p::EvapParams, base_ramp::FortRamp;
    N0::Float64, T0::Float64,
    bounds::Vector{Tuple{Float64, Float64}}=[(1.0, 5.0), (0.005, 0.05), (0.5, 3.0)],
    n_init::Int=8, n_iter::Int=40, optimizer::Function=bayesian_optimize)
    function objective(x::AbstractVector{<:Real})
        ramp = ramp_from_params(x, base_ramp)
        res = run_evaporation(trap, ramp, p; N0=N0, T0=T0)
        res.reached_bec && return res.N_BEC
        ρmax = isempty(res.psd) ? 0.0 : maximum(res.psd)
        ρmax / _ZETA3 - 1.0
    end
    bo = optimizer(objective, bounds; n_init=n_init, n_iter=n_iter, minimise=false)
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
