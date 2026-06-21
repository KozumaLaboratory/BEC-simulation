# QueueEntry ⇄ state.toml (de)serialization + schema migration chain.
# Pure transforms over a parsed TOML dict and a QueueEntry (defined in
# queue.jl); no queue state or locking here. Included immediately after
# queue.jl. save_entry! / get_entry (in queue.jl) call these at runtime.

const STATE_TOML_SCHEMA_VERSION = "1.1"

# Map: schema-version-string → migration function. Each migration takes
# the parsed TOML dict and returns the dict normalized to the NEXT
# version. Chain runs until current version is reached.
const _STATE_TOML_MIGRATIONS = Dict{String, Function}(
    # v1.0 → v1.1 (2026-05-31): added lifecycle timestamps to [timing]
    # block (dispatched_at / cluster_started_at / terminal_at /
    # cluster_state) for queue-wait display in the dashboard. Old
    # entries get nothings/`:unknown` for missing values; the tick
    # will fill in dispatched_at / cluster_started_at on next observation.
    "1.0" => function (d)
        haskey(d, "timing") || (
            d["timing"] = Dict{String, Any}(
                "dispatched_at" => "",
                "cluster_started_at" => "",
                "terminal_at" => "",
                "cluster_state" => "unknown",
            )
        )
        d["schema_version"] = "1.1"
        d
    end,
)

function _migrate_state_toml(d::AbstractDict)
    v = String(get(d, "schema_version", "1.0"))
    if v == STATE_TOML_SCHEMA_VERSION
        return d
    end
    out = d
    while v != STATE_TOML_SCHEMA_VERSION
        f = get(_STATE_TOML_MIGRATIONS, v, nothing)
        if f === nothing
            @warn "state.toml schema_version=$v has no migration; \
treating as current and proceeding"
            return out
        end
        out = f(out)
        v = String(get(out, "schema_version", STATE_TOML_SCHEMA_VERSION))
    end
    return out
end

function _entry_to_toml_dict(e::QueueEntry)
    Dict{String, Any}(
        "schema_version" => STATE_TOML_SCHEMA_VERSION,
        "state" => Dict{String, Any}(
            "status" => String(e.status),
            "kill_reason" => e.kill_reason,
            "attempt" => e.attempt,
            "priority" => e.priority,
        ),
        "provenance" => Dict{String, Any}(
            "content_id" => e.content_id,
            "enqueued_at" => string(e.enqueued_at),
            "enqueued_by" => e.enqueued_by,
            "parent_id" => e.parent_id === nothing ? "" : e.parent_id,
            "group_id" => e.group_id,
        ),
        "recipe" => Dict{String, Any}(
            "name" => e.recipe_name === nothing ? "" : String(e.recipe_name),
            "params" => e.recipe_params,
            "autonomy_level" => String(e.autonomy_level),
        ),
        "backend" => Dict{String, Any}(
            "type" => String(e.backend_type),
            "job_id" => e.job_id === nothing ? "" : e.job_id,
            "profile" => e.profile,
            "estimated_walltime_hours" => e.estimated_walltime_hours,
        ),
        "timing" => Dict{String, Any}(
            "dispatched_at" => e.dispatched_at === nothing ? "" : string(e.dispatched_at),
            "cluster_started_at" =>
                e.cluster_started_at === nothing ? "" : string(e.cluster_started_at),
            "terminal_at" => e.terminal_at === nothing ? "" : string(e.terminal_at),
            "cluster_state" => String(e.cluster_state),
        ),
        "budget" => Dict{String, Any}(
            "gpu_hours_realized" => e.gpu_hours_realized
        ),
        "spec" => Dict{String, Any}(
            "path" => e.spec_path
        ),
        "reproducibility" => Dict{String, Any}(
            "code_sha" => e.code_sha,
            "recipe_version" => e.recipe_version,
            "inspector_snapshot_hash" => e.inspector_snapshot_hash,
            "autopilot_config_hash" => e.autopilot_config_hash,
        ),
    )
end

function _entry_from_toml_dict(d::AbstractDict, run_dir::AbstractString)
    d = _migrate_state_toml(d)
    state = get(d, "state", Dict())
    prov = get(d, "provenance", Dict())
    rec = get(d, "recipe", Dict())
    bk = get(d, "backend", Dict())
    timing = get(d, "timing", Dict())
    bud = get(d, "budget", Dict())
    spec = get(d, "spec", Dict())
    repro = get(d, "reproducibility", Dict())

    job_raw = String(get(bk, "job_id", ""))
    parent_raw = String(get(prov, "parent_id", ""))
    name_raw = String(get(rec, "name", ""))
    _maybe_dt(s) = isempty(s) ? nothing : DateTime(String(s))
    QueueEntry(
        get(prov, "content_id", basename(run_dir));
        run_dir=run_dir,
        spec_path=get(spec, "path", joinpath(run_dir, "config.yaml")),
        status=Symbol(get(state, "status", "pending")),
        kill_reason=get(state, "kill_reason", ""),
        attempt=Int(get(state, "attempt", 1)),
        priority=Int(get(state, "priority", 5)),
        enqueued_at=DateTime(String(get(prov, "enqueued_at", string(now())))),
        enqueued_by=get(prov, "enqueued_by", "unknown"),
        parent_id=isempty(parent_raw) ? nothing : parent_raw,
        group_id=String(get(prov, "group_id", "")),
        recipe_name=isempty(name_raw) ? nothing : Symbol(name_raw),
        recipe_params=Dict{String, Any}(get(rec, "params", Dict())),
        autonomy_level=Symbol(get(rec, "autonomy_level", "dispatch")),
        backend_type=Symbol(get(bk, "type", "local")),
        job_id=isempty(job_raw) ? nothing : job_raw,
        profile=get(bk, "profile", "default"),
        estimated_walltime_hours=Float64(get(bk, "estimated_walltime_hours", 2.0)),
        dispatched_at=_maybe_dt(get(timing, "dispatched_at", "")),
        cluster_started_at=_maybe_dt(get(timing, "cluster_started_at", "")),
        terminal_at=_maybe_dt(get(timing, "terminal_at", "")),
        cluster_state=Symbol(get(timing, "cluster_state", "unknown")),
        gpu_hours_realized=Float64(get(bud, "gpu_hours_realized", 0.0)),
        code_sha=get(repro, "code_sha", ""),
        recipe_version=get(repro, "recipe_version", "1"),
        inspector_snapshot_hash=get(repro, "inspector_snapshot_hash", ""),
        autopilot_config_hash=get(repro, "autopilot_config_hash", ""),
    )
end
