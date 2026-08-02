# --- Pulse sequence DSL ---
#
# Compiles a YAML pulse_sequence into TimeDep* fields for make_workspace.
# Each pulse event specifies a time window and parameter overrides using Waveforms.
# The compiler merges all events into composite waveforms per parameter.

struct PulseEvent
    t_start::Float64
    t_end::Float64
    target::Symbol
    params::Dict{String, Any}
end

"""
The targets `compile_pulse_sequence` actually compiles. An `apply:` outside this
set used to parse fine, group fine, and then compile to nothing — so
`apply: zeeman` (the pre-`B`-block spelling) and `apply: trap` (documented in
`yaml_schema_reference.md` but never implemented) were both silent no-ops.
"""
const PULSE_TARGETS = (:B, :raman, :interactions)

"""
    parse_pulse_sequence(raw::Vector, duration::Float64) -> Vector{PulseEvent}

Parse a YAML pulse_sequence list into PulseEvent objects.
Each entry: {t: Float64, apply: String, duration: Float64, ...params}

An unrecognised `apply:` throws rather than being dropped: the compiler simply
has no branch for it, so the event would have no effect at all.
"""
function parse_pulse_sequence(raw::Vector, duration::Float64)
    events = PulseEvent[]
    for entry in raw
        entry isa Dict || continue
        t_start = Float64(entry["t"])
        dur = Float64(get(entry, "duration", duration - t_start))
        t_end = min(t_start + dur, duration)
        target = Symbol(entry["apply"])
        target in PULSE_TARGETS || throw(
            ArgumentError(
                "pulse_sequence apply: $(entry["apply"]) is not compiled. \
                 Use one of $(PULSE_TARGETS). (`zeeman` became `B` with the unified \
                 B block; `trap` has never been implemented.)"),
        )
        params = Dict{String, Any}(
            string(k) => v for (k, v) in entry
                               if !(string(k) in ("t", "apply", "duration"))
        )
        push!(events, PulseEvent(t_start, t_end, target, params))
    end
    sort!(events; by=e -> e.t_start)
    events
end

"""
    compile_pulse_sequence(events::Vector{PulseEvent}, duration::Float64, defaults::Dict)
        -> Dict{Symbol,Any}

Compile events into a Dict keyed by what the CONSUMER reads —
`:zeeman`, `:raman`, `:time_dep_interactions` — not by the `apply:` target the
events were grouped under. `_apply_pulse_sequence` read `:B` here for a while and
threw the Zeeman overlay away.
Each value is the appropriate TimeDep* struct ready for make_workspace.
"""
function compile_pulse_sequence(
    events::Vector{PulseEvent}, duration::Float64, defaults::Dict{Symbol, Any}=Dict{Symbol, Any}()
)
    result = Dict{Symbol, Any}()

    # Group events by target
    groups = Dict{Symbol, Vector{PulseEvent}}()
    for e in events
        push!(get!(groups, e.target, PulseEvent[]), e)
    end

    # --- Zeeman ---
    if haskey(groups, :B)
        p_wf = _compile_windowed_waveform(groups[:B], "p", duration, get(defaults, :p, 0.0))
        q_wf = _compile_windowed_waveform(groups[:B], "q", duration, get(defaults, :q, 0.0))
        bx_wf = _compile_windowed_waveform_optional(groups[:B], "bx", duration)
        by_wf = _compile_windowed_waveform_optional(groups[:B], "by", duration)
        result[:zeeman] = TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf)
    end

    # --- Raman ---
    if haskey(groups, :raman)
        evts = groups[:raman]
        first_k_eff = get(evts[1].params, "k_eff", [0.0])
        k_eff = Tuple(Float64.(first_k_eff))
        omega_wf = _compile_windowed_waveform(evts, "Omega", duration, 0.0)
        delta_wf = _compile_windowed_waveform(evts, "delta", duration, 0.0)
        N = length(k_eff)
        result[:raman] = TimeDependentRaman{N}(omega_wf, delta_wf, k_eff)
    end

    # --- Interactions ---
    if haskey(groups, :interactions)
        c0_wf = _compile_windowed_waveform(
            groups[:interactions], "c0", duration, get(defaults, :c0, 0.0)
        )
        c1_wf = _compile_windowed_waveform(
            groups[:interactions], "c1", duration, get(defaults, :c1, 0.0)
        )
        result[:time_dep_interactions] = TimeDependentInteractions(c0_wf, c1_wf)
    end

    result
end

"""Build a piecewise waveform from windowed events for a specific parameter."""
function _compile_windowed_waveform(
    events::Vector{PulseEvent}, key::String, duration::Float64, default_val
)
    segments = Tuple{Float64, Float64, Waveform}[]
    for e in events
        haskey(e.params, key) || continue
        spec = e.params[key]
        event_duration = e.t_end - e.t_start
        wf = _make_waveform(spec, event_duration)
        push!(segments, (e.t_start, e.t_end, wf))
    end
    isempty(segments) && return ConstantWaveform(Float64(default_val))
    _build_windowed_waveform(segments, duration, Float64(default_val))
end

function _compile_windowed_waveform_optional(
    events::Vector{PulseEvent}, key::String, duration::Float64
)
    has_key = any(haskey(e.params, key) for e in events)
    has_key || return nothing
    _compile_windowed_waveform(events, key, duration, 0.0)
end

"""
    _apply_pulse_sequence(ps_raw, duration, interactions, zeeman, raman, tdi)

Type-narrowed pulse-sequence overlay for `_run_step(::DynamicsStep,...)`.
Separated into its own function so the `Dict{Symbol,Any}` lookup results are
locally-scoped and the `::TimeDependentZeeman` / `::TimeDependentInteractions`
type assertions narrow them back to concrete types before they reach
`make_workspace`. Without this barrier, inline assignment of `zeeman = dict[:B]`
inside `_run_step` widens the local to `Any` and detonates inference through
`make_workspace`'s 23 type parameters (observed: 30+ min JIT hang).
"""
function _apply_pulse_sequence(ps_raw, duration::Float64, interactions,
    zeeman, raman, tdi)
    ps_raw isa Vector || return (zeeman, raman, tdi)
    defaults = Dict{Symbol, Any}(
        :p => 0.0, :q => 0.0,
        :c0 => interactions[0], :c1 => interactions[1],
    )
    events = parse_pulse_sequence(ps_raw, duration)
    compiled = compile_pulse_sequence(events, duration, defaults)
    # `haskey(compiled, :zeeman)`, not `:B`. `compile_pulse_sequence` groups
    # events by their `apply:` target (`:B`) but writes the compiled object under
    # `:zeeman`, so this read `haskey(compiled, :B)` — always false — and the
    # TimeDependentZeeman it had just built was thrown away on every run. The
    # `:raman` and `:time_dep_interactions` arms below use the key the compiler
    # writes and were unaffected. Gated by the `pulse_sequence` row of
    # test/workflow/test_yaml_physics_reaches_workspace.jl.
    zee_out = haskey(compiled, :zeeman) ?
              compiled[:zeeman]::TimeDependentZeeman : zeeman
    ram_out = haskey(compiled, :raman) ? compiled[:raman] : raman
    tdi_out = if haskey(compiled, :time_dep_interactions)
        compiled[:time_dep_interactions]::TimeDependentInteractions
    else
        tdi
    end
    (zee_out, ram_out, tdi_out)
end

function _eval_segments(
    segments::Vector{Tuple{Float64, Float64, Waveform}}, t::Float64, default_val::Float64
)
    for (t0, t1, wf) in segments
        if t0 <= t < t1
            return evaluate(wf, t - t0)
        end
    end
    default_val
end

"""Sample windowed segments to build a concrete-typed PiecewiseLinearWaveform.

Using a closure-based FunctionWaveform here would leak a unique closure type
into downstream `_run_step(::DynamicsStep,...)` dispatch, triggering a type
inference explosion in `run_pipeline` (via abstract dispatch over
`PipelineStep`). PiecewiseLinearWaveform keeps everything concretely typed."""
function _build_windowed_waveform(
    segments::Vector{Tuple{Float64, Float64, Waveform}},
    duration::Float64,
    default_val::Float64;
    n_samples::Int=1024,
)
    if length(segments) == 1 && segments[1][1] ≈ 0.0 && segments[1][2] ≈ duration
        return segments[1][3]
    end
    times = collect(range(0.0, duration; length=n_samples))
    values = Float64[_eval_segments(segments, t, default_val) for t in times]
    PiecewiseLinearWaveform(times, values)
end
