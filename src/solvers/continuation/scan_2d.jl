# --- 2D phase-diagram scan ---

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
