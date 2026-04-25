# Post a Slack notification when a long-running batch finishes.
#
# Usage:
#   julia --project=. scripts/notify_slack.jl "message text"
#
# Reads SLACK_WEBHOOK_URL from env. Silent no-op if unset (so wrapping
# scripts can call this unconditionally without setup pain).

using HTTP
using JSON

function main()
    url = get(ENV, "SLACK_WEBHOOK_URL", "")
    if isempty(url)
        @info "SLACK_WEBHOOK_URL unset, skipping notification"
        return
    end
    msg = isempty(ARGS) ? "(no message)" : join(ARGS, " ")
    payload = JSON.json(Dict("text" => msg))
    try
        r = HTTP.post(url, ["Content-Type" => "application/json"], payload;
                      readtimeout = 10)
        @info "Slack notify OK" status = r.status
    catch e
        @warn "Slack notify failed" error = e
    end
end

main()
