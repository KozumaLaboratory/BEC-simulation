# --- Binary (two-component) GP step dispatch ---

"""
Binary (two-component) ground-state YAML entry point. Returns a result
shape compatible with the standard spinor `_run_step` path so analyzers
that only need ψ can still consume it.

Currently F=0 + F=0 via `find_binary_ground_state`. Spinor binary,
DDI, and YAML-side analyzer integration are next-session work — see
`docs/design/two_component_gp_design.md`.
"""
function _run_binary_ground_state_step(p::AbstractDict; verbose::Bool=true)
    grid_node = p["grid"]
    n = Int.(grid_node["n"])
    box = Float64.(grid_node["box"])
    grid = make_grid(GridConfig(Tuple(n), Tuple(box)))

    inter = p["interactions"]
    couplings = BinaryCouplings(;
        g_AA=Float64(inter["g_AA"]),
        g_BB=Float64(inter["g_BB"]),
        g_AB=Float64(inter["g_AB"]),
        omega_coupling=Float64(get(inter, "omega_coupling", 0.0)),
        delta_coupling=Float64(get(inter, "delta_coupling", 0.0)),
    )

    pot_node = get(p, "potential", Dict())
    potential = if pot_node isa AbstractDict && get(pot_node, "type", "") == "harmonic"
        ω_vec = Float64.(pot_node["omega"])
        length(ω_vec) == length(n) ||
            throw(ArgumentError("potential.omega length must match grid ndim"))
        HarmonicTrap(Tuple(ω_vec))
    else
        NoPotential()
    end

    state = find_binary_ground_state(
        grid;
        couplings=couplings,
        potential_A=potential,
        potential_B=potential,
        dt=Float64(get(p, "dt", 0.005)),
        n_steps=Int(get(p, "n_steps", 1000)),
        tol=Float64(get(p, "tol", 1e-6)),
        verbose=verbose,
    )

    # Stash ψ_A as the "psi" downstream so phase_classify etc. don't break;
    # ψ_B is in the binary-specific result. Atom / interactions are
    # placeholders — binary path doesn't carry a single AtomSpecies.
    placeholder_atom = AtomSpecies("Binary", 1.66e-25, 0, 0.0, 0.0, 0.0)
    psi_4d = reshape(state.psi_A, (size(state.psi_A)..., 1))
    step_result = Dict{Symbol, Any}(
        :binary_state => state,
        :binary_couplings => couplings,
    )
    return (psi_4d, grid, placeholder_atom, nothing, step_result)
end

# Concrete-type dispatch for binary GP. Both methods are tagged
# @noinline so the abstract reads from the YAML Dict{String,Any} stay
# inside this file's compilation unit and don't widen the inference
# world of the regular spinor steps.

@noinline function _run_step(
    step::BinaryGroundStateStep,
    psi_prev,
    grid_prev,
    atom_prev,
    ws_prev;
    verbose=true,
    checkpoint_dir=nothing,
)
    return _run_binary_ground_state_step(step.params; verbose=verbose)
end

@noinline function _run_step(
    step::BinaryDynamicsStep,
    psi_prev,
    grid,
    atom,
    ws_prev;
    verbose=true,
    checkpoint_dir=nothing,
    pipeline_results::Union{Nothing, Dict}=nothing,
    live_status_path::Union{Nothing, String}=nothing,
)
    grid !== nothing || throw(ArgumentError(
        "binary dynamics step requires grid from preceding ground_state step"))
    pipeline_results !== nothing || throw(ArgumentError(
        "binary dynamics step requires preceding ground_state results"))
    return _run_binary_dynamics_inner(step.params, grid, pipeline_results;
        verbose=verbose)
end

@noinline function _run_binary_dynamics_inner(
    p::Dict{String, Any},
    grid,
    pipeline_results::Dict;
    verbose::Bool=true,
)
    haskey(pipeline_results, :binary_state) || throw(
        ArgumentError(
            "binary dynamics requires a preceding `ground_state` step with `kind: binary`"),
    )
    state = pipeline_results[:binary_state]::BinaryState
    base_couplings = pipeline_results[:binary_couplings]::BinaryCouplings

    duration = Float64(p["duration"])
    dt = Float64(p["dt"])
    save_every = Int(get(p, "save_every", max(1, round(Int, duration / dt / 20))))

    couplings = if haskey(p, "couplings")
        c_node = p["couplings"]::Dict
        BinaryCouplings(;
            g_AA=Float64(get(c_node, "g_AA", base_couplings.g_AA)),
            g_BB=Float64(get(c_node, "g_BB", base_couplings.g_BB)),
            g_AB=Float64(get(c_node, "g_AB", base_couplings.g_AB)),
            omega_coupling=Float64(get(c_node, "omega_coupling",
                    base_couplings.omega_coupling)),
            delta_coupling=Float64(get(c_node, "delta_coupling",
                    base_couplings.delta_coupling)),
        )
    else
        base_couplings
    end

    pot_node = get(p, "potential", nothing)
    potential::AbstractPotential =
        if pot_node isa AbstractDict &&
            get(pot_node, "type", "") == "harmonic"
            ω_vec = Float64.(pot_node["omega"])
            HarmonicTrap(Tuple(ω_vec))
        else
            NoPotential()
        end

    sim = make_binary_simulation(grid;
        couplings=couplings,
        potential_A=potential,
        potential_B=potential,
        psi_A_init=state.psi_A,
        psi_B_init=state.psi_B)

    save_block_binary = get(p, "save", Dict{Any, Any}())::AbstractDict
    save_psi = Bool(get(save_block_binary, "psi", false))
    times = Float64[]
    psi_A_snaps = Vector{Array{ComplexF64, ndims(sim.psi_A)}}()
    psi_B_snaps = Vector{Array{ComplexF64, ndims(sim.psi_B)}}()
    # Liveness for the autopilot's divergence kill. Until 2026-08-07 this path
    # wrote no `_live_status.json`, so a diverging binary run finished and
    # billed. Note the hook was ALSO conditional on `save_psi` — liveness must
    # not be, or turning snapshots off turns the safety off with them.
    dV_bin = prod(grid.dx)
    cb_live = _build_binary_live_callback(get(p, "live_monitor", true),
        live_status_path, dV_bin)
    # Progress + ETA (#408). Not conditional on `save_psi` and not on
    # `live_monitor:`, for the same reason liveness is not: a knob about output
    # must not be able to switch off the thing that tells you the run is alive.
    cb_progress = _build_progress_reporter(
        "binary", max(1, round(Int, duration / dt)), duration)
    n_saves = Ref(0)
    on_save = if (save_psi || cb_live !== nothing || cb_progress !== nothing)
        function _on(s)
            n_saves[] += 1
            if save_psi
                push!(times, s.t)
                push!(psi_A_snaps, copy(s.psi_A))
                push!(psi_B_snaps, copy(s.psi_B))
            end
            cb_live === nothing || cb_live(s, n_saves[])
            _progress!(cb_progress, s.step, s.t)
            return nothing
        end
    else
        nothing
    end
    verbose && println("  binary RTP: duration=$duration dt=$dt save_every=$save_every")
    run_binary_simulation!(sim; duration, dt, save_every, on_save)

    state.psi_A = sim.psi_A
    state.psi_B = sim.psi_B
    state.t = sim.t
    state.step = sim.step

    placeholder_atom = AtomSpecies("Binary", 1.66e-25, 0, 0.0, 0.0, 0.0)
    psi_4d = reshape(state.psi_A, (size(state.psi_A)..., 1))
    bdyn = Dict{Symbol, Any}(
        :duration => duration, :dt => dt,
        :final_t => sim.t, :final_step => sim.step,
        :norms => binary_norms(sim),
        :total_energy => binary_total_energy(sim),
    )
    if save_psi
        bdyn[:times] = times
        bdyn[:psi_A_snapshots] = psi_A_snaps
        bdyn[:psi_B_snapshots] = psi_B_snaps
    end
    step_result = Dict{Symbol, Any}(
        :binary_state => state,
        :binary_couplings => couplings,
        :binary_dynamics => bdyn,
    )
    return (psi_4d, grid, placeholder_atom, nothing, step_result)
end
