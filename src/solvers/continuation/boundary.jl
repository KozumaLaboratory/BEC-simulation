# --- Phase-boundary bisection ---

"""
    scan_phase_boundary(; param_range, make_params, initial_states,
                          n_coarse, bisection_tol, max_iter, ...) → NamedTuple

Locate a first-order phase boundary along a 1D parameter axis by
running each candidate initial state's ITP at every grid point and
bisecting the parameter value where their ground-state energies cross.

Designed for the Eu / spin-1 c₁ scan studied in Matsui 2026 ("FL vs
uniform polarization energy crossing"): ferromagnetic-like initial
states relax to the FL branch, polar / random initial states relax to
the uniform branch, and the first-order transition lives where their
ITP-converged energies tie.

Arguments
=========
- `param_range::NTuple{2,Float64}` — `(p_lo, p_hi)` window to scan.
- `make_params(p) → NamedTuple` — same hook as `scan_continuation`;
  returns the `find_ground_state` kwargs for parameter value `p`.
- `initial_states::Vector{Symbol}` — competing branches (e.g.
  `[:ferromagnetic, :polar]`). At least 2 required.
- `n_coarse::Int=9` — coarse grid resolution for the initial pass.
- `bisection_tol::Float64=1e-3` — stop bisection once ΔE / |E| < tol
  AND `(p_hi − p_lo) / range < tol`.
- `max_iter::Int=8` — bisection step cap.
- `n_steps::Int=2000` — passed through to `find_ground_state`.

Plus any kwargs forwarded as fixed defaults to `find_ground_state`
(grid, atom, potential, c_dd, …).

Returns
=======
NamedTuple with fields
- `param_critical::Union{Float64, Nothing}` — bisection result, or
  `nothing` when no crossing was detected on the coarse grid (all
  branches monotonic / parallel).
- `lower_branch::Symbol`, `upper_branch::Symbol` — the two states
  whose energies crossed (the lowest-energy pair at the endpoints).
- `coarse::Vector{NamedTuple}` — every coarse-grid point with energies
  for every state.
- `iterations::Vector{NamedTuple}` — bisection trace.
"""
function scan_phase_boundary(;
    param_range::NTuple{2, Float64},
    make_params::Function,
    initial_states::Vector{Symbol},
    grid,
    atom,
    n_coarse::Int=9,
    bisection_tol::Float64=1e-3,
    max_iter::Int=8,
    n_steps::Int=2000,
    kwargs...,
)
    length(initial_states) >= 2 ||
        throw(ArgumentError("scan_phase_boundary needs >=2 initial_states"))
    n_coarse >= 3 ||
        throw(ArgumentError("scan_phase_boundary needs n_coarse >= 3"))
    p_lo, p_hi = param_range
    p_lo < p_hi || throw(ArgumentError("param_range must be (lo, hi) with lo < hi"))

    function _gs_energies_at(p::Float64)
        overrides = _normalize_sweep_result(make_params(p))
        base = Dict{Symbol, Any}(kwargs)
        for (k, v) in pairs(overrides)
            base[k] = v
        end
        delete!(base, :initial_state)
        delete!(base, :psi_init)
        delete!(base, :n_steps)
        energies = Dict{Symbol, Float64}()
        for state in initial_states
            r = find_ground_state(;
                grid, atom,
                initial_state=state,
                n_steps=n_steps,
                base...,
            )
            energies[state] = r.energy
        end
        energies
    end

    coarse_p = collect(range(p_lo, p_hi; length=n_coarse))
    coarse = NamedTuple[]
    for p in coarse_p
        es = _gs_energies_at(p)
        push!(coarse, (param=p, energies=es,
            best=argmin(s -> es[s], collect(keys(es)))))
    end

    # Find the first adjacent pair whose minimum-energy branch swaps
    crossing_idx = 0
    for i in 1:(length(coarse) - 1)
        if coarse[i].best != coarse[i + 1].best
            crossing_idx = i
            break
        end
    end
    if crossing_idx == 0
        return (param_critical=nothing,
            lower_branch=coarse[1].best,
            upper_branch=coarse[end].best,
            coarse=coarse,
            iterations=NamedTuple[])
    end

    lo_state = coarse[crossing_idx].best
    hi_state = coarse[crossing_idx + 1].best
    lo_p = coarse[crossing_idx].param
    hi_p = coarse[crossing_idx + 1].param
    range_span = p_hi - p_lo

    iters = NamedTuple[]
    p_critical = (lo_p + hi_p) / 2
    for k in 1:max_iter
        mid_p = (lo_p + hi_p) / 2
        es = _gs_energies_at(mid_p)
        ΔE = es[hi_state] - es[lo_state]
        push!(iters, (iter=k, lo=lo_p, hi=hi_p, mid=mid_p,
            energies=es, deltaE=ΔE))
        # ΔE > 0 means lo_state is still cheaper at mid → boundary lies between mid and hi
        if ΔE > 0
            lo_p = mid_p
        else
            hi_p = mid_p
        end
        p_critical = (lo_p + hi_p) / 2
        rel_dE = abs(ΔE) / max(abs(es[lo_state]), abs(es[hi_state]), 1e-30)
        rel_dp = (hi_p - lo_p) / max(range_span, 1e-30)
        if rel_dE < bisection_tol && rel_dp < bisection_tol
            break
        end
    end
    (param_critical=p_critical,
        lower_branch=lo_state,
        upper_branch=hi_state,
        coarse=coarse,
        iterations=iters)
end
