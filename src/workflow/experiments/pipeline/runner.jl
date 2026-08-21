# --- Pipeline parser & runner ---

export parse_pipeline, run_pipeline

function parse_pipeline(data::Dict)
    pipe_data = data["pipeline"]
    (pipe_data isa AbstractVector && !isempty(pipe_data)) ||
        throw(ArgumentError("pipeline: must be a non-empty list of steps"))

    # `defaults:` (top-level, optional): a flat dict whose keys seed every
    # pipeline step's inner block. Step-level entries override defaults.
    # E.g. `defaults: {kind: rotating_basis, save_every: 30, epsilon: 1e-6}`
    # applies to ground_state + every dynamics block. Useful for DRY across
    # multi-phase fast-Larmor / Berry configs.
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

"""
Refuse `dynamics:` keys that the schema validates and no step reads.

`adaptive_dt` declared five numeric fields with ranges — `dt_init`, `dt_min`,
`dt_max`, `tol`, `error_mode` — so a config asking for adaptive stepping
validated cleanly, and then ran at fixed `dt`. Nothing under `src/workflow`
constructs `AdaptiveDtParams` or calls `run_simulation_yoshida!` at all; the
adaptive runners are a Julia-API path only. An accuracy knob that is accepted
and discarded is worse than one that does not exist, and it is the same defect
as the rotating handler sizing `dt` for an integrator it would not run.

Unknown keys are only a `:warn`, which is right for a typo and too quiet for
this: the user gets what they asked for spelled correctly and not honoured. No
config under `runs/` sets it and `docs/reference/yaml_schema_reference.md` never
documented it, so refusing breaks nothing in the tree.
"""
function _reject_inert_dynamics_keys(params::AbstractDict)
    haskey(params, "adaptive_dt") && throw(
        ArgumentError(
            "`dynamics.adaptive_dt` is validated by the schema but read by " *
            "nothing — the run would proceed at fixed dt. Adaptive stepping " *
            "is a Julia-API path: call `run_simulation_yoshida!(ws; " *
            "adaptive=AdaptiveDtParams(...))` directly. Remove the key to " *
            "confirm you want fixed-dt dynamics.",
        ),
    )
    nothing
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
        elseif kind in ("rotating_basis", "option_gamma") ||
            kind in (:rotating_basis, :option_gamma)
            RotatingBasisGroundStateStep(params)
        elseif kind == "scalar_egpe" || kind == :scalar_egpe
            ScalarEGPEGroundStateStep(params)
        else
            GroundStateStep(params)
        end
    elseif key == :dynamics
        params = Dict{String, Any}(string(k) => v for (k, v) in val)
        _reject_inert_dynamics_keys(params)
        kind = get(params, "kind", nothing)
        if kind == "binary" || kind == :binary
            BinaryDynamicsStep(params)
        elseif kind in ("rotating_basis", "option_gamma") ||
            kind in (:rotating_basis, :option_gamma)
            RotatingBasisDynamicsStep(params)
        elseif kind == "scalar_egpe" || kind == :scalar_egpe
            ScalarEGPEDynamicsStep(params)
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
_is_nan_error(err) =
    err isa DomainError ||
    (err isa ErrorException && occursin(r"NaN|Inf"i, err.msg))

# Matched by type NAME, not by `isa`: CUDA is a weak dependency, so
# `CUDA.OutOfGPUMemoryError` cannot be referenced from core. It was therefore not
# recognised at all until 2026-08-07 — a GPU OOM set `oom_killed=false`, was
# classified PERMANENT rather than RESOURCE_PERMANENT, and `retry.jl` re-queued
# it at the SAME memory class until the retry budget ran out. Chained with the
# VRAM estimate that under-sized 16 of 23 atoms, that is a job priced to fail and
# then paid for again on every attempt.
_is_oom_error(err) =
    err isa OutOfMemoryError ||
    occursin(r"OutOfGPUMemory|OutOfMemory"i, string(typeof(err).name.name)) ||
    (err isa ErrorException && occursin(r"out of memory|OOM"i, err.msg))

# W4. The cache's fail-safes were `@warn` and nothing else: no `Record`, no
# `_exit_summary.json`, no `run_summary`. That is sccache's documented real-world
# failure — workspaces that stopped caching entirely because `CARGO_INCREMENTAL`
# was set, discoverable only through `--show-stats`. ccache's answer is a
# persisted per-reason counter (28 named uncacheable reasons behind
# `--show-stats -v`), and this is that, in the file the autopilot already reads.
#
# Two things a person reading a finished run needs and could not get:
#
#   `no_id_reasons`  which configs could never be served a cached ground state,
#                    by REASON — the string names the slot that did not resolve.
#   `admission`      how many payloads were served with a verified marker
#                    (`marked`), served WITHOUT one (`unmarked`, i.e. arm (b)),
#                    thrown away (`rejected`), or simply not there (`absent`).
#
# `scope` is stated in the file because both are PROCESS-cumulative: a scan calls
# `run_pipeline` once per point into the same run directory, so the last write
# wins and it carries the totals for the whole process — which is the useful
# reading, and a wrong one if a reader assumes per-point.
function _cache_stats_payload()
    Dict{String, Any}(
        "scope" => "process-cumulative",
        "no_id_reasons" => no_artifact_id_reasons(),
        "admission" => Dict{String, Any}(
            String(k) => v for (k, v) in admission_counts()),
    )
end

function _write_exit_summary(path::Union{Nothing, String};
    completed::Bool, exception_type::Union{Nothing, AbstractString},
    last_step::Int, runtime_seconds::Real,
    nan_encountered::Bool, oom_killed::Bool,
)
    path === nothing && return nothing
    payload = Dict{String, Any}(
        "completed" => completed,
        "exception_type" => exception_type,
        "last_step" => last_step,
        "runtime_seconds" => runtime_seconds,
        "nan_encountered" => nan_encountered,
        "oom_killed" => oom_killed,
        "written_at" => string(now()),
        # Stamped on BOTH the success and the failure path: a run that threw is
        # exactly the one whose cache behaviour someone will want to reconstruct.
        "cache" => _cache_stats_payload(),
    )
    try
        open(path, "w") do io
            JSON.print(io, payload, 2)
        end
    catch e
        @warn "_write_exit_summary failed" path=path exception=e
    end
    return path
end

function run_pipeline(config::PipelineConfig; verbose::Bool=_default_solver_verbose(),
    psi_init=nothing,
    checkpoint_dir::Union{Nothing, String}=nothing,
    live_status_path::Union{Nothing, String}=nothing)
    # Cutover step 4. The one ambient `Ref` left on a kernel path that can move
    # a number, and it is not in any `Stage` because no run sets it — so a
    # leaked assignment would file an artifact under an id describing a
    # different computation. One integer comparison per pipeline.
    _assert_taylor_degree_cap_unclamped()
    psi = psi_init
    grid = nothing
    atom = nothing
    workspace = nothing
    results = Dict{Symbol, Any}()
    if live_status_path !== nothing
        results[:_live_status_path] = live_status_path
    end

    # Exit summary — derive path from live_status_path (same dir) so the
    # autopilot can classify transient vs permanent failures without log
    # scraping. See docs/guides/autopilot.md.
    exit_summary_path = if live_status_path === nothing
        nothing
    else
        joinpath(dirname(live_status_path), "_exit_summary.json")
    end
    t_start = time_ns()
    last_step = 0
    # Declared OUTSIDE the try: `try` opens a scope in Julia, so a binding made
    # inside it is not visible at the `_write_exit_summary` call below.
    interrupted_at_step = 0
    exit_exception = nothing

    try
        for (i, step) in enumerate(config.steps)
            if verbose
                println("Step $i/$(length(config.steps)): $(nameof(typeof(step)))")
                flush(stdout);
                ccall(:fflush, Cint, (Ptr{Cvoid},), C_NULL)
            end
            last_step = i
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

            # AN INTERRUPTED STEP ENDS THE PIPELINE.
            #
            # `run_step_ground_state.jl` already handles its own interrupt
            # carefully — it refuses to cache the partial ψ, because the key is
            # content-addressed and a tombstone would poison the cell for every
            # other config resolving to the same physics — and records
            # `:interrupted => true`. Nothing read it here, so the loop carried
            # the unconverged ψ straight into the next step.
            #
            # Observed 2026-08-21 on a deliberately short walltime: ITP stopped at
            # 794/3000 with `conv=false`, and the dynamics step began evolving that
            # state. Left alone it would have produced a full result.jld2 for a
            # ground state nobody reached — which is WORSE than the reaped job it
            # was meant to replace, because a reaped job leaves nothing and this
            # leaves something that looks finished.
            #
            # Stopping here rather than throwing: the earlier steps' results are
            # real and worth keeping, the exit summary records why, and the
            # `:interrupted` flag is already on the step result for anything
            # downstream that reads it.
            if !isempty(results) && get(results[end], :interrupted, false) === true
                interrupted_at_step = i
                verbose && println(
                    "  PIPELINE STOPPED: step $i reported `interrupted`. " *
                    "Later steps would run on a state nobody finished computing.")
                break
            end
        end
    catch err
        exit_exception = err
        _write_exit_summary(exit_summary_path; completed=false,
            exception_type=string(typeof(err).name.name),
            last_step=last_step, runtime_seconds=elapsed_s(t_start),
            nan_encountered=_is_nan_error(err),
            oom_killed=_is_oom_error(err))
        rethrow(err)
    end

    _write_exit_summary(exit_summary_path; completed=(interrupted_at_step == 0),
        exception_type=interrupted_at_step == 0 ? nothing : "InterruptedStep",
        last_step=last_step,
        runtime_seconds=elapsed_s(t_start),
        nan_encountered=false, oom_killed=false)

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

# Inference barrier for the per-step dispatch — see run_pipeline for rationale.
#
# MEASURED 2026-08-04 and it does NOT reproduce. `code_typed(run_pipeline, …)`:
# 13.9 s with both annotations, 14.1 s without `@noinline`, 14.2 s without
# `@nospecialize`, 14.5 s with neither — against a 0.6 s spread between fresh
# processes. First-call JIT through `run_pipeline`: 25.9 s vs 25.6 s. The
# paragraph below describes a hang that was real when it was written; what
# defused it was removing the `Any`-typed local that reached `make_workspace`,
# not these annotations. They are kept because they cost nothing and the
# failure mode can return, but they are not what is holding the line.
# (`pitfall_pipeline_inference` recorded the same for `@noinline` — 258 s vs
# 251 s — and was right; this file's claim for `@nospecialize` was the
# unmeasured half.)
#
# Historical rationale, left as written:
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
            verbose, checkpoint_dir, pipeline_results=results, live_status_path)
    elseif step isa RotatingBasisDynamicsStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, pipeline_results=results, live_status_path)
    elseif step isa ScalarEGPEDynamicsStep
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, pipeline_results=results, live_status_path)
    elseif step isa DynamicsStep
        # `pipeline_results` joined the other three dynamics kinds here on
        # 2026-08-19: the spinor path needs the preceding `:gs_stage` to build
        # an `:evolve` Stage `from` it, and that is the only way the real-time
        # ambient switches reach an artifact id at all.
        _run_step(step, psi, grid, atom, workspace;
            verbose, checkpoint_dir, pipeline_results=results, live_status_path)
    elseif step isa GroundStateStep ||
        step isa BinaryGroundStateStep ||
        step isa RotatingBasisGroundStateStep ||
        step isa ScalarEGPEGroundStateStep
        _run_step(step, psi, grid, atom, workspace; verbose, checkpoint_dir)
    else
        # Defensive: a new PipelineStep subtype must be added explicitly above
        # so the kwargs passed to its _run_step match its method signature.
        # Julia would otherwise raise MethodError, but the message would not
        # mention this dispatch site — easier to debug if we point here.
        throw(
            ArgumentError(
                "Unknown PipelineStep subtype $(typeof(step)) in _step_dispatch!. " *
                "Add an explicit branch in _step_dispatch! (this file, ~line 293) " *
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
        # `:interrupted` is the ONE key that must survive `merge!` (cutover step
        # 2, invariant 4). Plain `merge!` is last-writer-wins, so a GS step that
        # was killed followed by a dynamics step that ran to completion would
        # end with `:interrupted => false` and the run would be marked complete
        # on a half-relaxed ψ. Accumulate with `|`. Gated by the second testset
        # in `test/model/test_interrupted_run_recomputes.jl`, which interrupts
        # the GS of a two-step pipeline and lets the dynamics step finish.
        was = get(results, :interrupted, false) === true
        merge!(results, step_result)
        now_ = get(step_result, :interrupted, false) === true
        results[:interrupted] = was || now_
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
