# POST /api/queue/enqueue — submit a new run from the dashboard.
#
# Request JSON (all fields except yaml are optional):
#
#   { "preview":          true | false,
#     "yaml":             "<inline yaml content>",
#     "backend":          "local" | "slurm",
#     "priority":         5,
#     "autonomy_level":   "propose" | "suggest" | "dispatch",
#     "recipe_name":      "next_random_in_bounds" | "",
#     "recipe_params":    { ... },
#     "recipe_version":   "1.0",
#     "profile":          "default",
#     "estimated_walltime_hours": 2.0,
#     "session_id":       "abcd1234"
#   }
#
# `preview: true` returns the inspector findings + budget impact + the
# would-be content_id WITHOUT writing state.toml. `preview: false`
# commits. Dashboard's 2-step preview-confirm flow calls preview first,
# then commit. autonomy_level defaults to :propose so a Web-driven
# enqueue does not auto-dispatch.

using ..SpinorBEC: ConfigInspection, ConfigWarning, to_dict

function _route_autopilot_enqueue(body_bytes, base_dir;
    authed_user::AbstractString="",
)
    req = try
        JSON.parse(String(body_bytes))
    catch e
        return (400, "application/json",
            _enq_err("invalid JSON body: $(typeof(e).name.name)"))
    end
    req isa AbstractDict || return (400, "application/json",
        _enq_err("body must be a JSON object"))

    yaml_src = String(get(req, "yaml", ""))
    isempty(yaml_src) && return (400, "application/json",
        _enq_err("yaml field is required"))

    preview = Bool(get(req, "preview", true))
    backend_str = String(get(req, "backend", "local"))
    if !(backend_str in ("local", "slurm"))
        return (400, "application/json",
            _enq_err("backend must be 'local' or 'slurm', got '$(backend_str)'"))
    end
    priority = Int(get(req, "priority", 5))
    autonomy_str = String(get(req, "autonomy_level", "propose"))
    if !(autonomy_str in ("suggest", "propose", "dispatch"))
        return (400, "application/json",
            _enq_err("autonomy_level must be suggest|propose|dispatch"))
    end
    recipe_name_str = String(get(req, "recipe_name", ""))
    recipe_params = Dict{String, Any}(get(req, "recipe_params", Dict()))
    recipe_version = String(get(req, "recipe_version", "1"))
    profile = String(get(req, "profile", "default"))
    if !haskey(PROFILE_DIRECTIVES, profile)
        return (400, "application/json",
            _enq_err(
                "unknown profile '$(profile)'; known: " *
                join(collect(keys(PROFILE_DIRECTIVES)), ","),
            ))
    end
    walltime = Float64(get(req, "estimated_walltime_hours", 2.0))
    session_id = String(get(req, "session_id", "anon"))
    # Provenance priority: upstream-proxy username > body session_id > "anon".
    # When Caddy/oauth2-proxy is in front, `enqueued_by` reflects the real
    # operator identity; direct access falls back to the per-tab session id.
    provenance = isempty(authed_user) ?
                 "dashboard:$(session_id)" :
                 String(authed_user)

    # Inspector pre-flight on the YAML before doing anything else.
    ins = try
        inspect_config_string(yaml_src)
    catch e
        return (400, "application/json",
            _enq_err("inspector threw: $(typeof(e).name.name): $(e)"))
    end

    blocked_findings = filter(w -> w.severity === :block, ins.warnings)
    warn_findings = filter(w -> w.severity === :warn, ins.warnings)
    error_findings = filter(w -> w.severity === :error, ins.warnings)

    # Compute the content_id by routing through Experiment construction.
    cid = ""
    try
        spec = YAML.load(yaml_src)
        cid = content_id(spec)
    catch e
        return (400, "application/json",
            _enq_err("could not compute content_id: $(e)"))
    end

    # Budget projection (predicted impact = this entry's walltime).
    budget_d = try
        refresh_budget!()
        budget_gate()
    catch
        nothing
    end

    if preview
        body = _preview_json(cid, ins, blocked_findings, warn_findings,
            error_findings, budget_d, walltime, profile)
        return (200, "application/json", body)
    end

    # Commit path — refuse if anything is :block.
    if !isempty(blocked_findings)
        return (409, "application/json",
            _enq_err(
                "inspector :block — refusing to enqueue. " *
                "Findings: " * join([w.kind for w in blocked_findings], ","),
            ))
    end

    # Build Experiment + enqueue!. Provenance tag carries session id.
    exp = try
        store = default_store()
        spec = YAML.load(yaml_src)
        Experiment(spec; store=store)
    catch e
        return (500, "application/json",
            _enq_err("Experiment construction failed: $(e)"))
    end

    entry = try
        backend_sym = Symbol(backend_str)
        recipe_sym = isempty(recipe_name_str) ? nothing : Symbol(recipe_name_str)
        enqueue!(exp;
            priority=priority,
            enqueued_by=provenance,
            recipe_name=recipe_sym,
            recipe_params=recipe_params,
            autonomy_level=Symbol(autonomy_str),
            profile=profile,
            estimated_walltime_hours=walltime,
            backend_type=backend_sym,
        )
    catch e
        return (500, "application/json",
            _enq_err("enqueue! threw: $(typeof(e).name.name): $(e)"))
    end

    body = _commit_json(entry)
    return (200, "application/json", body)
end

# --- JSON shaping helpers -------------------------------------------

_enq_err(msg::AbstractString) = "{\"ok\":false,\"error\":\"$(_jsonesc(String(msg)))\"}"

function _preview_json(cid::String, ins::ConfigInspection,
    blocked, warned, errored, budget_d, walltime, profile)
    io = IOBuffer()
    print(io, "{\"ok\":true,\"preview\":true,",
        "\"content_id\":\"$(cid)\",",
        "\"profile\":\"$(_jsonesc(profile))\",",
        "\"estimated_walltime_hours\":", walltime, ",")
    # Inspector findings — compact summary, full listing client can fetch
    # via /api/effective_config later.
    print(io, "\"inspector\":{",
        "\"block_count\":", length(blocked), ",",
        "\"warn_count\":", length(warned), ",",
        "\"error_count\":", length(errored), ",",
        "\"blocked\":[",
        join([_finding_json(w) for w in blocked], ","), "],",
        "\"warned\":[",
        join([_finding_json(w) for w in warned], ","), "],",
        "\"errored\":[",
        join([_finding_json(w) for w in errored], ","), "]},")
    # Budget impact
    print(io, "\"budget\":")
    if budget_d === nothing
        print(io, "{\"available\":false}")
    else
        print(io, "{",
            "\"available\":true,",
            "\"allow\":", budget_d.allow, ",",
            "\"reason\":\"$(_jsonesc(budget_d.reason))\",",
            "\"realized\":", budget_d.realized, ",",
            "\"predicted\":", budget_d.predicted, ",",
            "\"quarter_cap\":", budget_d.quarter_cap, ",",
            "\"daily_cap\":", budget_d.daily_cap,
            "}")
    end
    print(io, "}")
    return String(take!(io))
end

function _commit_json(e::QueueEntry)
    io = IOBuffer()
    print(io, "{\"ok\":true,\"preview\":false,",
        "\"content_id\":\"$(e.content_id)\",",
        "\"status\":\"$(String(e.status))\",",
        "\"autonomy_level\":\"$(String(e.autonomy_level))\",",
        "\"backend\":\"$(String(e.backend_type))\",",
        "\"profile\":\"$(_jsonesc(e.profile))\",",
        "\"run_dir\":\"$(_jsonesc(e.run_dir))\",",
        "\"enqueued_by\":\"$(_jsonesc(e.enqueued_by))\"}")
    return String(take!(io))
end

function _finding_json(w::ConfigWarning)
    "{\"kind\":\"$(String(w.kind))\"," *
    "\"severity\":\"$(String(w.severity))\"," *
    "\"step_index\":$(w.step_index)," *
    "\"title\":\"$(_jsonesc(w.title))\"}"
end
