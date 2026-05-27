# /api/queue route — list autopilot queue contents.
#
# Returns JSON of the 5-state autopilot queue. Read-only here; operate
# via filesystem (the per-run state.toml is the truth) or via the
# operator CLI (scripts/autopilot.jl pause/drain/resume).

const _QUEUE_STATES_JSON = ("pending", "running", "done", "killed_data", "killed_bug")

function _route_autopilot_queue(path::String)
    # /api/queue            → all states
    # /api/queue/<state>    → one state's entries
    qr = autopilot_queue_root()
    parts = split(strip(path, '/'), '/')
    if !(length(parts) >= 2 && length(parts) <= 3 &&
         parts[1] == "api" && parts[2] == "queue")
        return (404, "application/json", "{\"error\":\"not found\"}")
    end
    wanted = length(parts) == 3 ? parts[3] : nothing
    if wanted !== nothing && !(wanted in _QUEUE_STATES_JSON)
        return (404, "application/json",
            "{\"error\":\"unknown state $(wanted); expected one of " *
            join(_QUEUE_STATES_JSON, "/") * "\"}")
    end

    out_io = IOBuffer()
    print(out_io, "{")
    first_block = true
    for st_str in (wanted === nothing ? _QUEUE_STATES_JSON : (wanted,))
        st = Symbol(st_str)
        entries = try
            list_queue(st; qr=qr)
        catch
            QueueEntry[]
        end
        first_block || print(out_io, ",")
        first_block = false
        print(out_io, "\"$(st_str)\":[")
        for (i, e) in enumerate(entries)
            i > 1 && print(out_io, ",")
            print(out_io, _entry_to_json(e))
        end
        print(out_io, "]")
    end
    print(out_io, "}")
    return (200, "application/json", String(take!(out_io)))
end

function _entry_to_json(e::QueueEntry)
    fields = [
        "\"content_id\":\"$(e.content_id)\"",
        "\"status\":\"$(String(e.status))\"",
        "\"kill_reason\":\"$(_jsonesc(e.kill_reason))\"",
        "\"attempt\":$(e.attempt)",
        "\"priority\":$(e.priority)",
        "\"enqueued_at\":\"$(string(e.enqueued_at))\"",
        "\"enqueued_by\":\"$(_jsonesc(e.enqueued_by))\"",
        "\"parent_id\":$(e.parent_id === nothing ? "null" : "\"$(e.parent_id)\"")",
        "\"recipe\":{" *
        "\"name\":$(e.recipe_name === nothing ? "null" : "\"$(String(e.recipe_name))\"")," *
        "\"autonomy_level\":\"$(String(e.autonomy_level))\"" *
        "}",
        "\"backend\":{" *
        "\"type\":\"$(String(e.backend_type))\"," *
        "\"job_id\":$(e.job_id === nothing ? "null" : "\"$(e.job_id)\"")," *
        "\"profile\":\"$(_jsonesc(e.profile))\"," *
        "\"estimated_walltime_hours\":$(e.estimated_walltime_hours)" *
        "}",
        "\"budget\":{" *
        "\"gpu_hours_realized\":$(e.gpu_hours_realized)" *
        "}",
        "\"run_dir\":\"$(_jsonesc(e.run_dir))\"",
    ]
    "{" * join(fields, ",") * "}"
end

function _jsonesc(s::AbstractString)
    replace(String(s), "\\" => "\\\\", "\"" => "\\\"")
end
