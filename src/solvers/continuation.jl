"""
    _normalize_sweep_result(result) → NamedTuple

Convert sweep callback return value to a NamedTuple of find_ground_state kwargs.
Accepts InteractionParams (legacy) or NamedTuple (new API).
"""
_normalize_sweep_result(ip::InteractionParams) = (interactions=ip,)
_normalize_sweep_result(nt::NamedTuple) = nt

"""
    scan_continuation(; param_values, make_params, grid, atom, ...) → Vector{NamedTuple}

Sweep a parameter using continuation: use previous ground state as initial guess for
next point. Falls back to multistart search on energy jumps.

`make_params(val)` returns either:
- `InteractionParams` (legacy — varies interactions only)
- `NamedTuple` of `find_ground_state` kwargs to override at each point
  e.g. `p -> (zeeman = ZeemanParams(p, 0.0),)` or
  `c -> (c_dd = c, enable_ddi = c > 0)`

All other kwargs are forwarded to `find_ground_state` as fixed defaults.

# Legacy keyword

`make_interactions` is accepted as an alias for `make_params` (backward compat).
"""
function scan_continuation(;
    param_values::AbstractVector{Float64},
    make_params::Union{Function, Nothing}=nothing,
    make_interactions::Union{Function, Nothing}=nothing,
    grid,
    atom,
    initial_state::Symbol=:polar,
    energy_jump_threshold::Float64=0.1,
    n_steps_continuation::Int=500,
    n_steps_fresh::Int=5000,
    kwargs...,
)
    sweep_fn = _resolve_sweep_fn(make_params, make_interactions)

    results = NamedTuple[]
    prev_psi = nothing
    prev_energy = NaN

    sm = spin_matrices(atom.F)

    for (i, val) in enumerate(param_values)
        overrides = _normalize_sweep_result(sweep_fn(val))
        base = Dict{Symbol, Any}(kwargs)
        for (k, v) in pairs(overrides)
            base[k] = v
        end
        delete!(base, :n_steps)
        delete!(base, :initial_state)
        delete!(base, :psi_init)

        r = if prev_psi !== nothing
            find_ground_state(;
                grid,
                atom,
                psi_init=copy(prev_psi),
                n_steps=n_steps_continuation,
                base...,
            )
        else
            find_ground_state(;
                grid,
                atom,
                initial_state,
                n_steps=n_steps_fresh,
                base...,
            )
        end

        if !isnan(prev_energy) &&
            abs(r.energy - prev_energy) / max(abs(prev_energy), 1e-30) >
           energy_jump_threshold
            r = find_ground_state_multistart(;
                grid,
                atom,
                n_steps=n_steps_fresh,
                base...,
            )
        end

        ws = r.workspace
        psi_host = _to_host(ws.state.psi)
        phase_info = classify_phase(psi_host, atom.F, grid, sm)
        detailed = classify_phase_detailed(psi_host, atom.F, grid, sm)

        push!(
            results,
            (
                param=val,
                energy=r.energy,
                converged=r.converged,
                phase=phase_info.phase,
                phase_info=detailed,
                psi=copy(psi_host),
            ),
        )

        prev_psi = copy(ws.state.psi)
        prev_energy = r.energy
    end

    results
end

function _resolve_sweep_fn(make_params, make_interactions)
    if make_params !== nothing
        make_params
    elseif make_interactions !== nothing
        make_interactions
    else
        throw(ArgumentError("Either `make_params` or `make_interactions` must be provided"))
    end
end

function _detect_hysteresis(
    param_values::AbstractVector{Float64},
    forward::Vector{NamedTuple},
    backward::Vector{NamedTuple},
)
    n = length(param_values)
    in_hysteresis = false
    lo = 0.0
    intervals = Tuple{Float64, Float64}[]

    for i in 1:n
        mismatch = forward[i].phase != backward[i].phase
        if mismatch && !in_hysteresis
            lo = param_values[i]
            in_hysteresis = true
        elseif !mismatch && in_hysteresis
            push!(intervals, (lo, param_values[i - 1]))
            in_hysteresis = false
        end
    end
    if in_hysteresis
        push!(intervals, (lo, param_values[n]))
    end

    transition_points = [(a + b) / 2 for (a, b) in intervals]
    (intervals, transition_points)
end

"""
    scan_continuation_bidirectional(; param_values, make_params, grid, atom, ...) → HysteresisResult

Run forward and backward continuation scans to detect hysteresis in first-order transitions.

See `scan_continuation` for the `make_params` / `make_interactions` interface.
"""
function scan_continuation_bidirectional(;
    param_values::AbstractVector{Float64},
    make_params::Union{Function, Nothing}=nothing,
    make_interactions::Union{Function, Nothing}=nothing,
    grid,
    atom,
    initial_state_forward::Symbol=:polar,
    initial_state_backward::Symbol=:polar,
    energy_jump_threshold::Float64=0.1,
    n_steps_continuation::Int=500,
    n_steps_fresh::Int=5000,
    kwargs...,
)
    sweep_fn = _resolve_sweep_fn(make_params, make_interactions)

    forward = scan_continuation(;
        param_values,
        make_params=sweep_fn,
        grid,
        atom,
        initial_state=initial_state_forward,
        energy_jump_threshold,
        n_steps_continuation,
        n_steps_fresh,
        kwargs...,
    )

    backward_raw = scan_continuation(;
        param_values=reverse(param_values),
        make_params=sweep_fn,
        grid,
        atom,
        initial_state=initial_state_backward,
        energy_jump_threshold,
        n_steps_continuation,
        n_steps_fresh,
        kwargs...,
    )

    backward = reverse(backward_raw)
    intervals, transition_pts = _detect_hysteresis(param_values, forward, backward)

    HysteresisResult(
        collect(Float64, param_values),
        forward,
        backward,
        intervals,
        transition_pts,
    )
end

"""
    scan_phase_diagram_2d(; param1_values, param2_values, make_params, grid, atom, ...) → Matrix{NamedTuple}

2D parameter sweep with continuation from neighboring points.
Scans along param1 first (inner loop), using continuation from the previous param1 point.
At each new param2 value, restarts from the end of the previous param2 row.

`make_params(v1, v2)` returns either `InteractionParams` or a `NamedTuple` of overrides.

Returns a Matrix of NamedTuples with shape `(length(param1_values), length(param2_values))`.

See `scan_continuation` for the `make_params` / `make_interactions` interface.
"""
function scan_phase_diagram_2d(;
    param1_values::AbstractVector{Float64},
    param2_values::AbstractVector{Float64},
    make_params::Union{Function, Nothing}=nothing,
    make_interactions::Union{Function, Nothing}=nothing,
    grid,
    atom,
    initial_state::Symbol=:polar,
    n_steps_continuation::Int=500,
    n_steps_fresh::Int=5000,
    energy_jump_threshold::Float64=0.1,
    kwargs...,
)
    sweep_fn = _resolve_sweep_fn(make_params, make_interactions)

    n1 = length(param1_values)
    n2 = length(param2_values)
    sm = spin_matrices(atom.F)

    results = Matrix{NamedTuple}(undef, n1, n2)
    prev_row_psi = nothing

    for (j, v2) in enumerate(param2_values)
        prev_psi = prev_row_psi
        prev_energy = NaN

        for (i, v1) in enumerate(param1_values)
            overrides = _normalize_sweep_result(sweep_fn(v1, v2))
            base = Dict{Symbol, Any}(kwargs)
            for (k, v) in pairs(overrides)
                base[k] = v
            end
            delete!(base, :n_steps)
            delete!(base, :initial_state)
            delete!(base, :psi_init)

            r = if prev_psi !== nothing
                find_ground_state(;
                    grid,
                    atom,
                    psi_init=copy(prev_psi),
                    n_steps=n_steps_continuation,
                    base...,
                )
            else
                find_ground_state(;
                    grid,
                    atom,
                    initial_state,
                    n_steps=n_steps_fresh,
                    base...,
                )
            end

            if !isnan(prev_energy) &&
                abs(r.energy - prev_energy) / max(abs(prev_energy), 1e-30) >
               energy_jump_threshold
                r = find_ground_state_multistart(;
                    grid,
                    atom,
                    n_steps=n_steps_fresh,
                    base...,
                )
            end

            ws = r.workspace
            psi_host = _to_host(ws.state.psi)
            detailed = classify_phase_detailed(psi_host, atom.F, grid, sm)

            results[i, j] = (
                param1=v1,
                param2=v2,
                energy=r.energy,
                converged=r.converged,
                phase=detailed.phase,
                phase_info=detailed,
                psi=copy(psi_host),
            )

            prev_psi = copy(ws.state.psi)
            prev_energy = r.energy

            if i == 1
                prev_row_psi = copy(ws.state.psi)
            end
        end
    end

    results
end

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
