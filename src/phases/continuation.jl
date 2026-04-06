"""
    scan_continuation(; param_values, make_interactions, grid, atom, ...) → Vector{NamedTuple}

Sweep a parameter using continuation: use previous ground state as initial guess for
next point. Falls back to multistart search on energy jumps.
"""
function scan_continuation(;
    param_values::AbstractVector{Float64},
    make_interactions::Function,
    grid,
    atom,
    initial_state::Symbol = :polar,
    energy_jump_threshold::Float64 = 0.1,
    n_steps_continuation::Int = 500,
    n_steps_fresh::Int = 5000,
    kwargs...,
)
    results = NamedTuple[]
    prev_psi = nothing
    prev_energy = NaN

    sm = spin_matrices(atom.F)

    for (i, val) in enumerate(param_values)
        interactions = make_interactions(val)

        r = if prev_psi !== nothing
            find_ground_state(;
                grid,
                atom,
                interactions,
                psi_init = copy(prev_psi),
                n_steps = n_steps_continuation,
                kwargs...,
            )
        else
            find_ground_state(;
                grid,
                atom,
                interactions,
                initial_state,
                n_steps = n_steps_fresh,
                kwargs...,
            )
        end

        if !isnan(prev_energy) &&
           abs(r.energy - prev_energy) / max(abs(prev_energy), 1e-30) >
           energy_jump_threshold
            r = find_ground_state_multistart(;
                grid,
                atom,
                interactions,
                n_steps = n_steps_fresh,
                kwargs...,
            )
        end

        ws = r.workspace
        phase_info = classify_phase(ws.state.psi, atom.F, grid, sm)
        detailed = classify_phase_detailed(ws.state.psi, atom.F, grid, sm)

        push!(
            results,
            (
                param = val,
                energy = r.energy,
                converged = r.converged,
                phase = phase_info.phase,
                phase_info = detailed,
                psi = copy(ws.state.psi),
            ),
        )

        prev_psi = copy(ws.state.psi)
        prev_energy = r.energy
    end

    results
end

function _detect_hysteresis(
    param_values::AbstractVector{Float64},
    forward::Vector{NamedTuple},
    backward::Vector{NamedTuple},
)
    n = length(param_values)
    in_hysteresis = false
    lo = 0.0
    intervals = Tuple{Float64,Float64}[]

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
    scan_continuation_bidirectional(; param_values, make_interactions, grid, atom, ...) → HysteresisResult

Run forward and backward continuation scans to detect hysteresis in first-order transitions.
"""
function scan_continuation_bidirectional(;
    param_values::AbstractVector{Float64},
    make_interactions::Function,
    grid,
    atom,
    initial_state_forward::Symbol = :polar,
    initial_state_backward::Symbol = :polar,
    energy_jump_threshold::Float64 = 0.1,
    n_steps_continuation::Int = 500,
    n_steps_fresh::Int = 5000,
    kwargs...,
)
    forward = scan_continuation(;
        param_values,
        make_interactions,
        grid,
        atom,
        initial_state = initial_state_forward,
        energy_jump_threshold,
        n_steps_continuation,
        n_steps_fresh,
        kwargs...,
    )

    backward_raw = scan_continuation(;
        param_values = reverse(param_values),
        make_interactions,
        grid,
        atom,
        initial_state = initial_state_backward,
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
    scan_phase_diagram_2d(; param1_values, param2_values, make_interactions, grid, atom, ...) → Matrix{NamedTuple}

2D parameter sweep with continuation from neighboring points.
Scans along param1 first (inner loop), using continuation from the previous param1 point.
At each new param2 value, restarts from the end of the previous param2 row.

Returns a Matrix of NamedTuples with shape `(length(param1_values), length(param2_values))`.
"""
function scan_phase_diagram_2d(;
    param1_values::AbstractVector{Float64},
    param2_values::AbstractVector{Float64},
    make_interactions::Function,
    grid,
    atom,
    initial_state::Symbol = :polar,
    n_steps_continuation::Int = 500,
    n_steps_fresh::Int = 5000,
    energy_jump_threshold::Float64 = 0.1,
    kwargs...,
)
    n1 = length(param1_values)
    n2 = length(param2_values)
    sm = spin_matrices(atom.F)

    results = Matrix{NamedTuple}(undef, n1, n2)
    prev_row_psi = nothing

    for (j, v2) in enumerate(param2_values)
        prev_psi = prev_row_psi
        prev_energy = NaN

        for (i, v1) in enumerate(param1_values)
            interactions = make_interactions(v1, v2)

            r = if prev_psi !== nothing
                find_ground_state(;
                    grid,
                    atom,
                    interactions,
                    psi_init = copy(prev_psi),
                    n_steps = n_steps_continuation,
                    kwargs...,
                )
            else
                find_ground_state(;
                    grid,
                    atom,
                    interactions,
                    initial_state,
                    n_steps = n_steps_fresh,
                    kwargs...,
                )
            end

            if !isnan(prev_energy) &&
               abs(r.energy - prev_energy) / max(abs(prev_energy), 1e-30) >
               energy_jump_threshold
                r = find_ground_state_multistart(;
                    grid,
                    atom,
                    interactions,
                    n_steps = n_steps_fresh,
                    kwargs...,
                )
            end

            ws = r.workspace
            detailed = classify_phase_detailed(ws.state.psi, atom.F, grid, sm)

            results[i, j] = (
                param1 = v1,
                param2 = v2,
                energy = r.energy,
                converged = r.converged,
                phase = detailed.phase,
                phase_info = detailed,
                psi = copy(ws.state.psi),
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
