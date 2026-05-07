# --- Pipeline parser & runner ---

function parse_pipeline(data::Dict)
    pipe_data = data["pipeline"]
    (pipe_data isa AbstractVector && !isempty(pipe_data)) ||
        throw(ArgumentError("pipeline: must be a non-empty list of steps"))

    # `defaults:` (top-level, optional): a flat dict whose keys seed every
    # pipeline step's inner block. Step-level entries override defaults.
    # E.g. `defaults: {kind: rotating_basis, save_every: 30, epsilon: 1e-6}`
    # applies to ground_state + every dynamics block. Useful for DRY across
    # multi-phase Klaus / Berry configs.
    defaults = haskey(data, "defaults") ? data["defaults"] : nothing
    if defaults !== nothing
        defaults isa AbstractDict || throw(ArgumentError(
            "defaults: must be a mapping, got $(typeof(defaults))"))
        pipe_data = [_apply_step_defaults(s, defaults) for s in pipe_data]
    end

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

"""
Seed an unkeyed step entry's inner block with `defaults`. Step-level keys
override defaults. Returns a new Dict (immutable input).
"""
function _apply_step_defaults(step::Dict, defaults::AbstractDict)
    keys_list = collect(keys(step))
    length(keys_list) == 1 || return step  # malformed; let _parse_step error
    key = keys_list[1]
    inner = step[key]
    inner isa AbstractDict || return step  # e.g. analyze: <list> doesn't get defaults

    seeded = Dict{Any, Any}()
    for (k, v) in defaults
        seeded[k] = v
    end
    for (k, v) in inner
        seeded[k] = v   # step-level wins
    end
    Dict{Any, Any}(key => seeded)
end

function _parse_step(d::Dict)
    keys_list = collect(keys(d))
    length(keys_list) == 1 || throw(ArgumentError(
        "Each pipeline step must have exactly one key, got: $keys_list"))
    key = Symbol(keys_list[1])
    val = d[keys_list[1]]

    if key == :ground_state
        params = Dict{String, Any}(string(k) => v for (k, v) in val)
        kind = get(params, "kind", nothing)
        if kind == "binary" || kind == :binary
            BinaryGroundStateStep(params)
        elseif kind == "rotating_basis" || kind == :rotating_basis ||
            kind == "option_gamma" || kind == :option_gamma
            RotatingBasisGroundStateStep(params)
        else
            GroundStateStep(params)
        end
    elseif key == :dynamics
        params = Dict{String, Any}(string(k) => v for (k, v) in val)
        kind = get(params, "kind", nothing)
        if kind == "binary" || kind == :binary
            BinaryDynamicsStep(params)
        elseif kind == "rotating_basis" || kind == :rotating_basis ||
            kind == "option_gamma" || kind == :option_gamma
            RotatingBasisDynamicsStep(params)
        else
            DynamicsStep(params)
        end
    elseif key == :analyze
        analyzers = Pair{Symbol, Dict{String, Any}}[]
        for entry in val
            if entry isa Dict
                for (ak, av) in entry
                    params = if av isa Dict
                        Dict{String, Any}(string(k) => v for (k, v) in av)
                    else
                        Dict{String, Any}()
                    end
                    push!(analyzers, Symbol(ak) => params)
                end
            end
        end
        AnalyzeStep(analyzers)
    else
        throw(
            ArgumentError("Unknown pipeline step: $key. Supported: ground_state, dynamics, analyze")
        )
    end
end

"""
    run_pipeline(config::PipelineConfig; verbose=true) -> NamedTuple

Execute a pipeline sequentially. Each step receives the current psi
and produces a new one. Analysis steps don't modify psi but accumulate
results.
"""
function run_pipeline(config::PipelineConfig; verbose::Bool=true, psi_init=nothing,
    checkpoint_dir::Union{Nothing, String}=nothing,
    live_status_path::Union{Nothing, String}=nothing)
    psi = psi_init
    grid = nothing
    atom = nothing
    workspace = nothing
    results = Dict{Symbol, Any}()
    if live_status_path !== nothing
        results[:_live_status_path] = live_status_path
    end

    for (i, step) in enumerate(config.steps)
        if verbose
            println("Step $i/$(length(config.steps)): $(nameof(typeof(step)))")
            flush(stdout);
            ccall(:fflush, Cint, (Ptr{Cvoid},), C_NULL)
        end
        # Push the per-iteration dispatch + tuple destructuring into a
        # @nospecialize-tagged helper. Without that, Julia specialises
        # this loop body across every PipelineStep concrete type AND
        # every _run_step return-tuple shape, which compounds into a
        # multi-minute JIT cascade once the binary GP path is in the
        # union (CLAUDE.md "Type stability boundaries"). The helper
        # treats step as Any, so dispatch happens at runtime and the
        # surrounding inference world stays narrow.
        psi, grid, atom, workspace = _step_dispatch!(
            results, step, psi, grid, atom, workspace,
            verbose, checkpoint_dir, live_status_path,
        )
    end

    # Auto-save dynamics pipelines into the dashboard-canonical layout
    # whenever the caller supplied a `checkpoint_dir`. Fires for both
    # `kind: rotating_basis` (`:rotating_basis_history`) and `kind: spinor`
    # (`:dynamics_history`) so downstream launchers don't need to call
    # `save_rotating_basis_result!` by hand.
    has_dyn = haskey(results, :rotating_basis_history) ||
              haskey(results, :dynamics_history)
    if checkpoint_dir !== nothing && has_dyn
        # The auto-save target is the run directory (parent of the checkpoint
        # subdirectory) so `result.jld2` lives next to `point_001.jld2`.
        run_dir = dirname(dirname(checkpoint_dir))
        try
            save_rotating_basis_result!(run_dir, results)
            verbose && println(
                "  auto-saved canonical dynamics result -> ",
                joinpath(run_dir, "result.jld2"),
            )
        catch err
            @warn "dynamics auto-save failed; downstream launcher should " *
                "call save_rotating_basis_result! manually" exception = (err, catch_backtrace())
        end
    end

    (psi=psi, grid=grid, atom=atom, results...)
end

# Inference barrier for the per-step dispatch — see run_pipeline for
# rationale. `@nospecialize` on `step` is the load-bearing annotation:
# without it, Julia generates a fresh specialisation of this function
# (and the rest of the loop body) for each PipelineStep concrete type
# the YAML mentions, and the binary GP path's return-tuple type hits a
# combinatorial explosion that takes 10+ minutes of inference work to
# settle. With it, dispatch on step happens once at runtime per step.
@noinline function _step_dispatch!(
    results::Dict{Symbol, Any},
    @nospecialize(step),
    @nospecialize(psi),
    @nospecialize(grid),
    @nospecialize(atom),
    @nospecialize(workspace),
    verbose::Bool,
    checkpoint_dir,
    live_status_path::Union{Nothing, String},
)
    # Each branch hands back a 5-tuple from _run_step. We narrow to
    # `Tuple` immediately so the loop-local types stay maximally generic.
    out = if step isa AnalyzeStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, pipeline_results=results)
    elseif step isa BinaryDynamicsStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, pipeline_results=results)
    elseif step isa RotatingBasisDynamicsStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, pipeline_results=results)
    elseif step isa DynamicsStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, live_status_path)
    elseif step isa GroundStateStep ||
        step isa BinaryGroundStateStep ||
        step isa RotatingBasisGroundStateStep
        _run_step(step, psi, grid, atom, workspace; verbose, checkpoint_dir)
    else
        # Defensive: a new PipelineStep subtype must be added explicitly above
        # so the kwargs passed to its _run_step match its method signature.
        # Julia would otherwise raise MethodError, but the message would not
        # mention this dispatch site — easier to debug if we point here.
        throw(
            ArgumentError(
                "Unknown PipelineStep subtype $(typeof(step)) in _step_dispatch!. " *
                "Add an explicit branch in _step_dispatch! (pipeline_runner.jl:123) " *
                "and a matching _run_step(::$(typeof(step)), ...) method.",
            ),
        )
    end
    psi_out, grid_out, atom_out, workspace_out, step_result = out
    if step_result !== nothing
        if step isa DynamicsStep || step isa BinaryDynamicsStep
            history = get(results, :dynamics_history, NamedTuple[])
            push!(
                history,
                (
                    dynamics_result=get(step_result, :dynamics_result, nothing),
                    snapshot_tmp_path=get(step_result, :snapshot_tmp_path, nothing),
                    save_psi_snapshots=get(step_result, :save_psi_snapshots, false),
                    snapshot_count=get(step_result, :snapshot_count, 0),
                    ensemble_result=get(step_result, :ensemble_result, nothing),
                ),
            )
            results[:dynamics_history] = history
        elseif step isa RotatingBasisDynamicsStep
            # Each phase's dyn dict goes into a list so save_rotating_basis_result!
            # can concatenate the full GS → ramp → chirp → stir timeseries.
            # Without this the last `merge!` would overwrite earlier phases'
            # `:rotating_basis_dynamics` entry and on-disk results would only
            # cover the final phase.
            rb_history = get(results, :rotating_basis_history, Dict[])
            if haskey(step_result, :rotating_basis_dynamics)
                push!(rb_history, step_result[:rotating_basis_dynamics])
            end
            results[:rotating_basis_history] = rb_history
        end
        merge!(results, step_result)
    end
    return (psi_out, grid_out, atom_out, workspace_out)
end

# --- AnalyzeStep dispatch ---
"""
    _build_sgpe_callback(node, dt) -> Union{Nothing,Function}

Parse a `dynamics.sgpe:` block into an SGPE on-step callback. Accepts:

    sgpe: false | null            # disabled (returns nothing)
    sgpe: {gamma: 0.05, T: 0.1, mu: 0.0, k_cut: 6.0, every: 1, seed: 42}

`gamma` and `T` are required when sgpe is a Dict. `mu` defaults to 0,
`k_cut` to Inf (no projection), `every` to 1, `seed` to nothing (random).
"""
function _run_step(step::AnalyzeStep, psi, grid, atom, ws_prev; verbose=true,
    checkpoint_dir=nothing,
    pipeline_results::Dict{Symbol, Any}=Dict{Symbol, Any}())
    psi !== nothing || throw(ArgumentError("analyze step requires psi from preceding steps"))
    results = Dict{Symbol, Any}()

    for (name, params) in step.analyzers
        verbose && print("  $name... ")
        result = _run_analyzer(name, psi, grid, atom, params;
            ws_prev=ws_prev, pipeline_results=pipeline_results)
        results[name] = result
        verbose && println("done")
    end

    (psi, grid, atom, ws_prev, results)
end
