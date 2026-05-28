# GET  /api/tags   → list all tags (name → content_id pointers)
# POST /api/tags   → { "action": "add"|"remove", "name": "...",
#                      "content_id": "..." (add only) }
#
# Tags are the catalog's stable human pointers, the git-tag / nix-profile
# analogue layered over the CAS run store. The store is never touched;
# tags live in <runs>/.catalog/tags.toml. The router has no DELETE verb,
# so removal is a POST with action=remove (same shape as /api/queue/action).

using ..SpinorBEC: load_tags, tag_run!, untag!, TagRecord

function _route_tags_get(base_dir)
    recs = try
        load_tags(; runs_root=base_dir)
    catch e
        return (500, "application/json", _tag_err(string(e)))
    end
    io = IOBuffer()
    print(io, "[")
    for (i, t) in enumerate(recs)
        i > 1 && print(io, ",")
        print(io, "{", _tag_inner(t), "}")
    end
    print(io, "]")
    return (200, "application/json", String(take!(io)))
end

function _route_tags_post(body_bytes, base_dir; authed_user::AbstractString="")
    req = try
        JSON.parse(String(body_bytes))
    catch
        return (400, "application/json", _tag_err("invalid JSON body"))
    end
    req isa AbstractDict ||
        return (400, "application/json", _tag_err("body must be a JSON object"))

    action = String(get(req, "action", ""))
    name = String(get(req, "name", ""))
    isempty(name) && return (400, "application/json", _tag_err("name is required"))

    if action == "add"
        cid = String(get(req, "content_id", ""))
        isempty(cid) &&
            return (400, "application/json", _tag_err("content_id is required for add"))
        # Boundary check: never pin a name to a phantom run.
        isdir(joinpath(base_dir, cid)) ||
            return (404, "application/json", _tag_err("no run dir for content_id $cid"))
        provenance = isempty(authed_user) ? "dashboard" : String(authed_user)
        rec = try
            tag_run!(name, cid; created_by=provenance, runs_root=base_dir)
        catch e
            return (400, "application/json", _tag_err(string(e)))
        end
        return (200, "application/json",
            "{\"ok\":true,\"action\":\"add\"," * _tag_inner(rec) * "}")
    elseif action == "remove"
        removed = untag!(name; runs_root=base_dir)
        return (200, "application/json",
            "{\"ok\":true,\"action\":\"remove\",\"name\":\"$(_jsonesc(name))\"," *
            "\"removed\":$(removed)}")
    else
        return (400, "application/json", _tag_err("action must be 'add' or 'remove'"))
    end
end

_tag_inner(t::TagRecord) =
    "\"name\":\"$(_jsonesc(t.name))\"," *
    "\"content_id\":\"$(_jsonesc(t.content_id))\"," *
    "\"created_at\":\"$(t.created_at)\"," *
    "\"created_by\":\"$(_jsonesc(t.created_by))\""

_tag_err(msg::AbstractString) = "{\"ok\":false,\"error\":\"$(_jsonesc(String(msg)))\"}"
