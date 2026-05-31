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

using ..SpinorBEC:
    get_entry, set_status!, save_entry!,
    default_autopilot_config, resolve_backend, cancel!

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
        # :pending → just set killed_bug (no backend job to kill).
        # :running → resolve backend, call cancel! (qdel on UGE, kill
        #            on LocalBackend subprocess), THEN set killed_bug.
        # Terminal states → reject.
        if entry.status === :pending
            set_status!(entry, :killed_bug;
                kill_reason="cancelled by operator ($(provenance))")
            return (200, "application/json",
                "{\"ok\":true,\"content_id\":\"$cid\"," *
                "\"status\":\"killed_bug\"," *
                "\"action\":\"cancel\"}")
        elseif entry.status === :running
            cfg = default_autopilot_config()
            backend = try
                resolve_backend(cfg, entry)
            catch err
                return (500, "application/json",
                    _act_err("backend $(entry.backend_type) not registered: $(err)"))
            end
            killed_ok = try
                cancel!(backend, entry)
            catch err
                @warn "cancel! threw" cid=cid exception=err
                false
            end
            # Mark killed_bug regardless of backend response. cancel!
            # returning false means "couldn't reach the scheduler" —
            # the entry is still ours to mark; the scheduler-side job
            # might linger but the autopilot will reconcile on the
            # next reap tick.
            set_status!(entry, :killed_bug;
                kill_reason=if killed_ok
                    "cancelled by operator ($(provenance))"
                else
                    "cancelled by operator ($(provenance)); backend cancel failed"
                end)
            return (200, "application/json",
                "{\"ok\":true,\"content_id\":\"$cid\"," *
                "\"status\":\"killed_bug\"," *
                "\"action\":\"cancel\"," *
                "\"backend_killed\":$(killed_ok)}")
        else
            return (409, "application/json",
                _act_err("cannot cancel terminal entry (status :$(entry.status))"))
        end
    end
end

_act_err(msg::AbstractString) = "{\"ok\":false,\"error\":\"$(_jsonesc(String(msg)))\"}"
