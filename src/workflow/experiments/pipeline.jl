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
    results = Dict{Symbol,Any}()

    for (i, step) in enumerate(config.steps)
        verbose && println("Step $i/$(length(config.steps)): $(nameof(typeof(step)))")
        psi, grid, atom, step_result = _run_step(step, psi, grid, atom; verbose)
        if step_result !== nothing
            merge!(results, step_result)
        end
    end

    (psi = psi, grid = grid, atom = atom, results...)
end

# --- Step dispatch ---

function _run_step(step::GroundStateStep, psi_prev, grid_prev, atom_prev; verbose=true)
    p = step.params
    atom_name = Symbol(p["atom"])
    atom = resolve_atom(atom_name)
    F = atom.F

    # Grid
    g = p["grid"]
    n_raw = g isa Dict ? get(g, "n", get(g, "n_points", 32)) : g
    box_raw = g isa Dict ? get(g, "box", get(g, "box_size", 12.0)) : 12.0
    n_pts, box_size = _normalize_grid(n_raw, box_raw)
    ndim = length(n_pts)
    grid = make_grid(GridConfig(NTuple{ndim,Int}(n_pts), NTuple{ndim,Float64}(box_size)))

    # Interactions
    inter = get(p, "interactions", Dict())
    interactions = _parse_gs_interactions(inter, atom)

    # DDI
    ddi_d = get(p, "ddi", Dict())
    enable_ddi, c_dd_val, secular, q2d, lz = _parse_gs_ddi(ddi_d, inter, atom)

    # Zeeman
    z = get(p, "zeeman", Dict())
    zeeman_p = z isa Dict ? Float64(get(z, "p", 0.0)) : 0.0
    zeeman_q = z isa Dict ? Float64(get(z, "q", 0.0)) : 0.0

    # Potential (single or composite list)
    pot_d = get(p, "potential", Dict("type" => "harmonic", "omega" => ones(ndim)))
    potential = if pot_d isa Vector
        components = [PotentialConfig(Symbol(get(c, "type", "harmonic")),
            Dict{String,Any}(string(k) => v for (k, v) in c if k != "type")) for c in pot_d]
        _build_potential(PotentialConfig(:composite, Dict{String,Any}("components" => components)), ndim)
    else
        _build_potential(PotentialConfig(Symbol(get(pot_d, "type", "harmonic")),
            Dict{String,Any}(string(k) => v for (k, v) in pot_d if k != "type")), ndim)
    end

    # ITP params
    dt = Float64(get(p, "dt", 0.001))
    n_steps = Int(get(p, "n_steps", 5000))
    tol = Float64(get(p, "tol", 1e-8))
    initial_state = Symbol(get(p, "initial_state", "polar"))
    target_mz = let v = get(p, "target_magnetization", nothing)
        v === nothing ? nothing : Float64(v)
    end
    backend_name = Symbol(get(p, "backend", "cpu"))
    backend = _resolve_backend(backend_name)

    # Temperature noise
    temp_ratio = let v = get(p, "temperature_ratio", nothing)
        v === nothing ? nothing : Float64(v)
    end

    psi_init = psi_prev  # continuation from previous step
    if psi_init === nothing && temp_ratio !== nothing
        sys = SpinSystem(F)
        psi_base = init_psi(grid, sys; state = initial_state)
        psi_init = add_thermal_noise(psi_base, F; T_over_Tc = temp_ratio, seed = Int(get(p, "noise_seed", 42)))
    end

    gs = find_ground_state(;
        grid, atom, interactions,
        zeeman = ZeemanParams(zeeman_p, zeeman_q),
        potential,
        dt, n_steps, tol,
        initial_state,
        psi_init,
        enable_ddi, c_dd = c_dd_val,
        secular_ddi = secular,
        quasi_2d_ddi = q2d, l_z_ddi = lz,
        target_magnetization = target_mz,
        backend,
    )

    verbose && println("  E=$(round(gs.energy; sigdigits=6)) conv=$(gs.converged)")

    psi_out = copy(gs.workspace.state.psi)
    step_result = Dict{Symbol,Any}(
        :ground_state_energy => gs.energy,
        :ground_state_converged => gs.converged,
        :workspace => gs.workspace,
    )
    (psi_out, grid, atom, step_result)
end

function _run_step(step::DynamicsStep, psi_prev, grid, atom; verbose=true)
    psi_prev !== nothing || throw(ArgumentError("dynamics step requires a preceding ground_state step"))
    grid !== nothing || throw(ArgumentError("dynamics step requires grid from preceding step"))
    p = step.params
    ndim = length(grid.config.n_points)
    F = atom.F

    duration = Float64(p["duration"])
    dt = Float64(p["dt"])
    save_every = Int(get(p, "save_every", max(1, round(Int, duration / dt / 20))))

    # DDI
    ddi_raw = get(p, "ddi", nothing)
    enable_ddi = ddi_raw isa Bool ? ddi_raw : (ddi_raw isa Dict ? Bool(get(ddi_raw, "enabled", false)) : false)
    c_dd_val = ddi_raw isa Dict ? Float64(get(ddi_raw, "c_dd", NaN)) : NaN

    # Zeeman (supports ramp)
    z = get(p, "zeeman", Dict())
    # _build_phase_zeeman expects {ground_state: {zeeman: ...}} structure
    zeeman_wrapper = Dict{String,Any}("ground_state" => Dict{String,Any}("zeeman" => get(p, "zeeman", Dict())))
    zeeman = _build_phase_zeeman(zeeman_wrapper, 0.0, duration)

    # Potential
    trap = get(p, "trap", nothing)
    potential = if trap !== nothing
        omega = trap isa Vector ? NTuple{ndim,Float64}(Float64.(trap)) :
                                  NTuple{ndim,Float64}(ntuple(_ -> 1.0, ndim))
        HarmonicTrap(omega)
    else
        HarmonicTrap(ntuple(_ -> 1.0, ndim))
    end

    # Noise
    temp_ratio = let v = get(p, "temperature_ratio", nothing)
        v === nothing ? nothing : Float64(v)
    end

    n_steps = round(Int, duration / dt)
    sp = SimParams(; dt, n_steps, save_every)

    # Read interactions from the workspace left by GS step (if available)
    # For simplicity, rebuild from params if provided
    inter = get(p, "interactions", nothing)
    interactions = if inter !== nothing
        _parse_gs_interactions(inter, atom)
    else
        # Fall through to workspace interactions (via caller)
        InteractionParams(0.0, 0.0)
    end

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
    (psi_out, grid, atom, step_result)
end

function _run_step(step::AnalyzeStep, psi, grid, atom; verbose=true)
    psi !== nothing || throw(ArgumentError("analyze step requires psi from preceding steps"))
    F = atom.F
    results = Dict{Symbol,Any}()

    for (name, params) in step.analyzers
        verbose && print("  $name... ")
        result = _run_analyzer(name, psi, grid, F, params)
        results[name] = result
        verbose && println("done")
    end

    (psi, grid, atom, results)
end

# --- Analyzer dispatch ---

function _run_analyzer(name::Symbol, psi, grid, F, params)
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
        # Stability analysis needs a workspace — build a minimal one
        ndim = length(grid.config.n_points)
        atom = resolve_atom(:Eu151)  # TODO: pass atom through
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
        @warn "Unknown analyzer: $name"
        nothing
    end
end

# --- Helpers ---

function _normalize_grid(n_raw, box_raw)
    n_pts = n_raw isa Vector ? Int.(n_raw) : n_raw isa Integer ? [n_raw, n_raw, n_raw] : Int.([n_raw])
    box_size = box_raw isa Vector ? Float64.(box_raw) : Float64.([box_raw for _ in n_pts])
    (n_pts, box_size)
end

function _parse_gs_interactions(inter::Dict, atom)
    F = atom.F
    c_extra = Float64[]
    if haskey(inter, "c_total")
        c_total = Float64(inter["c_total"])
        c1_ratio = Float64(get(inter, "c1_ratio", 0.0))
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        ip = interaction_params_from_constraint(; c_total, c1_ratio, F, c_extra)
        InteractionParams(ip.c0, ip.c1, c_lhy, ip.c_extra)
    elseif haskey(inter, "N_atoms") && haskey(inter, "omega_ref")
        N_atoms = Int(inter["N_atoms"])
        omega_ref = Float64(inter["omega_ref"])
        c_total = compute_c_total(atom; N_atoms, omega_ref)
        c1_ratio = Float64(get(inter, "c1_ratio", 0.0))
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        ip = interaction_params_from_constraint(; c_total, c1_ratio, F, c_extra)
        InteractionParams(ip.c0, ip.c1, c_lhy, ip.c_extra)
    else
        c0 = Float64(get(inter, "c0", 0.0))
        c1 = Float64(get(inter, "c1", 0.0))
        c_lhy = Float64(get(inter, "c_lhy", 0.0))
        InteractionParams(c0, c1, c_lhy, c_extra)
    end
end

function _parse_gs_ddi(ddi_d, inter, atom)
    if isempty(ddi_d) || ddi_d === nothing
        return (false, NaN, false, false, 0.0)
    end
    ddi_d = ddi_d isa Dict ? ddi_d : Dict{String,Any}("enabled" => ddi_d)
    enabled = Bool(get(ddi_d, "enabled", false))
    c_dd = if haskey(ddi_d, "c_dd")
        Float64(ddi_d["c_dd"])
    elseif haskey(inter, "N_atoms") && haskey(inter, "omega_ref")
        compute_c_dd_dimless(atom; N_atoms = Int(inter["N_atoms"]), omega_ref = Float64(inter["omega_ref"]))
    else
        NaN
    end
    secular = Bool(get(ddi_d, "secular", false))
    q2d = Bool(get(ddi_d, "quasi_2d", false))
    lz = Float64(get(ddi_d, "l_z", 0.0))
    (enabled, c_dd, secular, q2d, lz)
end

    # _build_phase_zeeman is in experiment_runner.jl (shared with config_runner)

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
