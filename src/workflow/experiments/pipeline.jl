# --- Pipeline-based experiment config ---
#
# An experiment is an ordered list of steps. Each step transforms state
# (typically psi). Steps are typed by their single YAML key:
#
#   pipeline:
#     - ground_state: {atom: Eu151, ...}
#     - dynamics: {duration: 3.0, ...}
#     - analyze: [{tomography: {...}}, {faraday: {...}}]
#
# scan: is orthogonal — overrides paths like `pipeline.1.zeeman.p`.

# --- Step types ---

struct GroundStateStep
    params::Dict{String,Any}    # raw YAML dict for this step
end

struct DynamicsStep
    params::Dict{String,Any}
end

struct AnalyzeStep
    analyzers::Vector{Pair{Symbol,Dict{String,Any}}}
end

const PipelineStep = Union{GroundStateStep, DynamicsStep, AnalyzeStep}

struct PipelineConfig
    steps::Vector{PipelineStep}
    scan::Union{Nothing,AbstractScanSpec}
    raw_data::Dict                   # full YAML dict for override re-parse
end

# --- Parser ---

function parse_pipeline(data::Dict)
    pipe_data = data["pipeline"]
    (pipe_data isa AbstractVector && !isempty(pipe_data)) ||
        throw(ArgumentError("pipeline: must be a non-empty list of steps"))
    steps = PipelineStep[_parse_step(s) for s in pipe_data]

    scan = if haskey(data, "scan")
        scan_d = data["scan"]
        if get(scan_d, "type", nothing) == "constrained_jz"
            _parse_constrained_jz_scan(scan_d)
        else
            _parse_override_scan(scan_d)
        end
    else
        nothing
    end

    PipelineConfig(steps, scan, data)
end

function _parse_step(d::Dict)
    keys_list = collect(keys(d))
    length(keys_list) == 1 || throw(ArgumentError(
        "Each pipeline step must have exactly one key, got: $keys_list"))
    key = Symbol(keys_list[1])
    val = d[keys_list[1]]

    if key == :ground_state
        GroundStateStep(Dict{String,Any}(string(k) => v for (k, v) in val))
    elseif key == :dynamics
        DynamicsStep(Dict{String,Any}(string(k) => v for (k, v) in val))
    elseif key == :analyze
        analyzers = Pair{Symbol,Dict{String,Any}}[]
        for entry in val
            if entry isa Dict
                for (ak, av) in entry
                    params = av isa Dict ? Dict{String,Any}(string(k) => v for (k, v) in av) : Dict{String,Any}()
                    push!(analyzers, Symbol(ak) => params)
                end
            end
        end
        AnalyzeStep(analyzers)
    else
        throw(ArgumentError("Unknown pipeline step: $key. Supported: ground_state, dynamics, analyze"))
    end
end

# --- Runner ---

"""
    run_pipeline(config::PipelineConfig; verbose=true) → NamedTuple

Execute a pipeline sequentially. Each step receives the current psi
and produces a new one. Analysis steps don't modify psi but accumulate
results.
"""
function run_pipeline(config::PipelineConfig; verbose::Bool = true, psi_init = nothing)
    psi = psi_init
    grid = nothing
    atom = nothing
    workspace = nothing   # last workspace (carries interactions/ddi/potential)
    results = Dict{Symbol,Any}()

    for (i, step) in enumerate(config.steps)
        verbose && println("Step $i/$(length(config.steps)): $(nameof(typeof(step)))")
        psi, grid, atom, workspace, step_result = _run_step(step, psi, grid, atom, workspace; verbose)
        if step_result !== nothing
            merge!(results, step_result)
        end
    end

    (psi = psi, grid = grid, atom = atom, results...)
end

# --- Step dispatch ---

function _run_step(step::GroundStateStep, psi_prev, grid_prev, atom_prev, ws_prev; verbose=true)
    p = step.params
    atom = resolve_atom(Symbol(p["atom"]))
    grid, ndim = _setup_grid_from_params(p)
    interactions = _parse_gs_interactions(get(p, "interactions", Dict()), atom)
    enable_ddi, c_dd_val, secular, q2d, lz = _parse_gs_ddi(get(p, "ddi", Dict()), get(p, "interactions", Dict()), atom)
    zeeman = _parse_constant_zeeman(get(p, "zeeman", Dict()))
    potential = _parse_and_build_potential(
        get(p, "potential", Dict("type" => "harmonic", "omega" => ones(ndim))), ndim)
    backend = _resolve_backend(Symbol(get(p, "backend", "cpu")))

    dt = Float64(get(p, "dt", 0.001))
    n_steps = Int(get(p, "n_steps", 5000))
    tol = Float64(get(p, "tol", 1e-8))
    initial_state = Symbol(get(p, "initial_state", "polar"))
    target_mz = _get_optional_float(p, "target_magnetization")
    temp_ratio = _get_optional_float(p, "temperature_ratio")

    psi_init = psi_prev
    if psi_init === nothing && temp_ratio !== nothing
        psi_base = init_psi(grid, SpinSystem(atom.F); state = initial_state)
        psi_init = add_thermal_noise(psi_base, atom.F;
            T_over_Tc = temp_ratio, seed = Int(get(p, "noise_seed", 42)))
    end

    gs = find_ground_state(;
        grid, atom, interactions, zeeman, potential,
        dt, n_steps, tol, initial_state, psi_init,
        enable_ddi, c_dd = c_dd_val,
        secular_ddi = secular, quasi_2d_ddi = q2d, l_z_ddi = lz,
        target_magnetization = target_mz, backend,
    )

    psi_out = copy(gs.workspace.state.psi)
    verbose && _print_gs_summary(psi_out, grid, atom, gs)

    step_result = Dict{Symbol,Any}(
        :ground_state_energy => gs.energy,
        :ground_state_converged => gs.converged,
        :workspace => gs.workspace,
    )
    (psi_out, grid, atom, gs.workspace, step_result)
end

function _run_step(step::DynamicsStep, psi_prev, grid, atom, ws_prev; verbose=true)
    psi_prev !== nothing || throw(ArgumentError("dynamics step requires a preceding ground_state step"))
    grid !== nothing || throw(ArgumentError("dynamics step requires grid from preceding step"))
    p = step.params
    ndim = length(grid.config.n_points)
    F = atom.F

    duration = Float64(p["duration"])
    dt = Float64(p["dt"])
    save_every = Int(get(p, "save_every", max(1, round(Int, duration / dt / 20))))

    # Inherit from previous workspace (GS step) as defaults
    prev_interactions = ws_prev !== nothing ? ws_prev.interactions : InteractionParams(0.0, 0.0)
    prev_potential = ws_prev !== nothing ? ws_prev.potential : HarmonicTrap(ntuple(_ -> 1.0, ndim))
    prev_ddi = ws_prev !== nothing ? ws_prev.ddi : nothing
    prev_c_dd = prev_ddi !== nothing ? prev_ddi.C_dd : NaN
    prev_enable_ddi = prev_ddi !== nothing

    # DDI: explicit in dynamics step overrides inherited
    ddi_raw = get(p, "ddi", nothing)
    enable_ddi = if ddi_raw === nothing
        prev_enable_ddi
    elseif ddi_raw isa Bool
        ddi_raw
    elseif ddi_raw isa Dict
        Bool(get(ddi_raw, "enabled", prev_enable_ddi))
    else
        prev_enable_ddi
    end
    c_dd_val = if ddi_raw isa Dict && haskey(ddi_raw, "c_dd")
        Float64(ddi_raw["c_dd"])
    else
        prev_c_dd
    end

    # Zeeman (supports ramp)
    zeeman_wrapper = Dict{String,Any}("ground_state" => Dict{String,Any}("zeeman" => get(p, "zeeman", Dict())))
    zeeman = _build_phase_zeeman(zeeman_wrapper, 0.0, duration)

    # Potential: explicit overrides inherited
    pot_d = get(p, "potential", nothing)
    potential = pot_d !== nothing ? _parse_and_build_potential(pot_d, ndim) : prev_potential

    # Noise
    temp_ratio = let v = get(p, "temperature_ratio", nothing)
        v === nothing ? nothing : Float64(v)
    end

    n_steps = round(Int, duration / dt)
    sp = SimParams(; dt, n_steps, save_every)

    # Interactions: explicit overrides inherited
    inter = get(p, "interactions", nothing)
    interactions = inter !== nothing ? _parse_gs_interactions(inter, atom) : prev_interactions

    ws = make_workspace(;
        grid, atom, interactions,
        zeeman, potential,
        sim_params = sp,
        psi_init = psi_prev,
        enable_ddi, c_dd = c_dd_val,
    )

    if temp_ratio !== nothing
        psi_noisy = add_thermal_noise(ws.state.psi, F; T_over_Tc = temp_ratio, seed = Int(get(p, "noise_seed", 42)))
        ws.state.psi .= psi_noisy
    end

    result = run_simulation!(ws)

    verbose && println("  $(n_steps) steps, E_final=$(round(result.energies[end]; sigdigits=6))")

    psi_out = copy(ws.state.psi)
    step_result = Dict{Symbol,Any}(
        :dynamics_result => result,
        :dynamics_workspace => ws,
    )
    (psi_out, grid, atom, ws, step_result)
end

function _run_step(step::AnalyzeStep, psi, grid, atom, ws_prev; verbose=true)
    psi !== nothing || throw(ArgumentError("analyze step requires psi from preceding steps"))
    F = atom.F
    results = Dict{Symbol,Any}()

    for (name, params) in step.analyzers
        verbose && print("  $name... ")
        result = _run_analyzer(name, psi, grid, atom, params)
        results[name] = result
        verbose && println("done")
    end

    (psi, grid, atom, ws_prev, results)
end

# --- Analyzer dispatch ---

function _run_analyzer(name::Symbol, psi, grid, atom, params)
    F = atom.F
    if name == :tomography
        spin_tomography(psi, grid, F;
            rotation_axis = Symbol(get(params, "axis", "y")),
            n_angles = Int(get(params, "n_angles", 19)),
            theta_min = Float64(get(params, "theta_min", 0.0)),
            theta_max = Float64(get(params, "theta_max", Float64(π))),
            reference_m = let v = get(params, "reference_m", nothing); v === nothing ? nothing : Int(v) end,
            tof_params = let td = get(params, "tof", Dict())
                TOFParams(Float64(get(td, "t_tof", 11.0)),
                         Float64(get(td, "gradient", 0.0)),
                         Int(get(td, "imaging_axis", 3)))
            end,
        )
    elseif name == :faraday
        faraday_image(psi, grid, F;
            params = FaradayParams(;
                probe_axis = Int(get(params, "probe_axis", get(params, "axis", 3))),
                detuning = Float64(get(params, "detuning", -64.0)),
                polarization = Symbol(get(params, "polarization", "linear_x")),
            ),
        )
    elseif name == :energy_decomposition
        # Need workspace — use last one from results
        # For now, compute from psi directly
        sm = spin_matrices(F)
        ndim = length(grid.config.n_points)
        classify_phase_detailed(psi, F, grid, sm)
    elseif name == :phase_classify
        sm = spin_matrices(F)
        classify_phase_detailed(psi, F, grid, sm)
    elseif name == :stability
        ndim = length(grid.config.n_points)
        sp = SimParams(; dt = 0.0001, n_steps = 1, save_every = 1)
        ws = make_workspace(;
            grid, atom,
            interactions = InteractionParams(0.0, 0.0),
            potential = HarmonicTrap(ntuple(_ -> 1.0, ndim)),
            sim_params = sp,
            psi_init = psi,
        )
        perturbation = Float64(get(params, "perturbation", 1e-4))
        n_steps_stab = Int(get(params, "n_steps", 1000))
        sample_every = Int(get(params, "sample_every", 10))
        analyze_stability(ws; perturbation, n_steps = n_steps_stab, sample_every)
    else
        throw(ArgumentError("Unknown analyzer: $name. Supported: tomography, faraday, energy_decomposition, phase_classify, stability"))
    end
end

# --- Public API ---

"""Load a YAML file and return a PipelineConfig."""
function load_config(path::String)
    data = YAML.load_file(path)
    parse_pipeline(data)
end

"""Load a YAML string and return a PipelineConfig."""
function load_config_from_string(yaml_str::String)
    data = YAML.load(yaml_str)
    parse_pipeline(data)
end

"""Run a pipeline config (alias for run_pipeline)."""
run_config(config::PipelineConfig; verbose::Bool = true) = run_pipeline(config; verbose)
