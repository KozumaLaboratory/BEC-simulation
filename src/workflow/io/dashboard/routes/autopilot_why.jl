# GET /api/queue/why/<content_id> — failure analysis for a single entry.
#
# Wraps `analyze_failure(entry)` so the dashboard can render a
# one-line "what broke?" summary on the row, with the matched evidence
# in a hover-tooltip. Read-only.

using ..SpinorBEC: get_entry, analyze_failure

function _route_autopilot_why(path::String)
    prefix = "/api/queue/why/"
    if !startswith(path, prefix)
        return (404, "application/json", "{\"error\":\"bad path\"}")
    end
    cid = path[(length(prefix) + 1):end]
    isempty(cid) && return (400, "application/json",
        "{\"error\":\"missing content_id\"}")
    qr = autopilot_queue_root()
    entry = get_entry(joinpath(qr.path, cid))
    if entry === nothing
        return (404, "application/json",
            "{\"error\":\"entry not found for content_id $cid\"}")
    end
    analysis = analyze_failure(entry)
    body =
        "{" *
        "\"content_id\":\"$cid\"," *
        "\"category\":\"$(String(analysis.category))\"," *
        "\"summary\":\"$(_jsonesc(analysis.summary))\"," *
        "\"details\":\"$(_jsonesc(analysis.details))\"" *
        "}"
    return (200, "application/json", body)
end
