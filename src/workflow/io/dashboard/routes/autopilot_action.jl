# POST /api/queue/action — operator action on a queue entry.
#
# Request JSON:
#   { "content_id": "<cid>",
#     "action":     "promote" | "cancel",
#     "session_id": "<dashboard tab id>"  (optional, recorded in kill_reason) }
#
# promote: :pending+:propose → :pending+:dispatch (autonomy_level only)
# cancel:  :pending          → :killed_bug ("cancelled by operator")
#
# Refuses transitions that violate state invariants (409). All other
# states reject — modifying running/done/killed_* via UI is not in scope.

using ..SpinorBEC: get_entry, set_status!, save_entry!

function _route_autopilot_action(body_bytes, base_dir;
    authed_user::AbstractString="",
)
    req = try
        JSON.parse(String(body_bytes))
    catch e
        return (400, "application/json",
            _act_err("invalid JSON body: $(typeof(e).name.name)"))
    end
    req isa AbstractDict || return (400, "application/json",
        _act_err("body must be a JSON object"))

    cid = String(get(req, "content_id", ""))
    action = String(get(req, "action", ""))
    session_id = String(get(req, "session_id", "anon"))
    # Same provenance policy as enqueue: upstream-proxy > body session > anon.
    provenance = isempty(authed_user) ?
                 "dashboard:$(session_id)" :
                 String(authed_user)

    isempty(cid) && return (400, "application/json",
        _act_err("content_id is required"))
    action in ("promote", "cancel") || return (400, "application/json",
        _act_err("action must be 'promote' or 'cancel'"))

    # Resolve cid → run_dir. The autopilot queue root has run dirs named
    # by content_id (CAS), so we can construct the path directly.
    qr = autopilot_queue_root()
    run_dir = joinpath(qr.path, cid)
    entry = get_entry(run_dir)
    if entry === nothing
        return (404, "application/json",
            _act_err("entry not found for content_id $cid"))
    end

    if action == "promote"
        if entry.status !== :pending
            return (409, "application/json",
                _act_err("can only promote :pending entries; this one is :$(entry.status)"))
        end
        if entry.autonomy_level === :dispatch
            return (409, "application/json",
                _act_err("already :dispatch — nothing to promote"))
        end
        entry.autonomy_level = :dispatch
        save_entry!(entry)
        return (200, "application/json",
            "{\"ok\":true,\"content_id\":\"$cid\"," *
            "\"status\":\"pending\",\"autonomy_level\":\"dispatch\"," *
            "\"action\":\"promote\"}")
    else    # cancel
        if entry.status !== :pending
            return (409, "application/json",
                _act_err(
                    "can only cancel :pending entries; this one is :$(entry.status). " *
                    "Use the CLI to scancel a running job.",
                ))
        end
        set_status!(entry, :killed_bug;
            kill_reason="cancelled by operator ($(provenance))")
        return (200, "application/json",
            "{\"ok\":true,\"content_id\":\"$cid\"," *
            "\"status\":\"killed_bug\"," *
            "\"action\":\"cancel\"}")
    end
end

_act_err(msg::AbstractString) = "{\"ok\":false,\"error\":\"$(_jsonesc(String(msg)))\"}"
