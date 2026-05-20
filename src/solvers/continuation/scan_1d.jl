# --- 1D parameter sweep with continuation (psi reuse) ---

export scan_continuation, scan_continuation_bidirectional

# `scan_continuation` walks a 1D vector of parameter values, reusing the
# previous psi as initial condition for the next point. Multistart fallback
# fires on energy jumps. `scan_continuation_bidirectional` runs both
# forward + backward sweeps to detect hysteresis.

"""
    _normalize_sweep_result(result) → NamedTuple

Convert sweep callback return value to a NamedTuple of find_ground_state kwargs.
Accepts InteractionParams (struct-form) or NamedTuple (kwarg-form).
"""
_normalize_sweep_result(ip::InteractionParams) = (interactions=ip,)
_normalize_sweep_result(nt::NamedTuple) = nt

"""
    scan_continuation(; param_values, make_params, grid, atom, ...) → Vector{NamedTuple}

Sweep a parameter using continuation: use previous ground state as initial guess for
next point. Falls back to multistart search on energy jumps.

`make_params(val)` returns either:
- `InteractionParams` (struct-form — varies interactions only)
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
