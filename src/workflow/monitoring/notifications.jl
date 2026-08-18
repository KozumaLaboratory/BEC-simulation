# Slack webhook notifications.
#
# `send_slack_notification` is a stub here; the real method is supplied
# by ext/SpinorBECHTTPExt when the user `using HTTP`s. Without HTTP
# loaded, Slack webhooks are silently skipped (with one @info hint).

export notify_slack

const _SLACK_HTTP_HINT_SHOWN = Ref(false)

"""
    SLACK_STATUSES

The status vocabulary, declared ONCE. `ext/SpinorBECHTTPExt` maps each to a
Slack attachment colour and every other symbol to the default blue, so a caller
passing `:warn` instead of `:warning` got an info-coloured alert with no
complaint — the writer/reader vocabulary mismatch this repository keeps hitting.
`notify_slack` now rejects anything outside this tuple at the call site.
"""
const SLACK_STATUSES = (:info, :success, :warning, :error)

"True for a status that must not fail silently — an alert nobody needs to act on."
_slack_is_quiet(status::Symbol) = status === :info || status === :success

"""
    send_slack_notification(webhook_url, title, message, status)

POST a Slack-formatted JSON payload to `webhook_url`. Real implementation
lives in ext/SpinorBECHTTPExt with the concrete signature
`(::String, ::String, ::String, ::Symbol)`. This fallback uses untyped
args so the ext's typed method dispatches first when HTTP is loaded;
otherwise we log a one-shot hint and return.
"""
function send_slack_notification(_url, _title, _msg, _status)
    if !_SLACK_HTTP_HINT_SHOWN[]
        @info "Slack webhook skipped: load `using HTTP` to enable real POST."
        _SLACK_HTTP_HINT_SHOWN[] = true
    end
    # `false` — NOT DELIVERED. This returned `nothing`, and so did the ext's
    # success path and the empty-URL path, so no caller could tell a posted
    # alert from a dropped one. Nothing in `src/` or `scripts/` does
    # `using HTTP`, so in practice every alert took this branch: a tripped
    # circuit breaker paused the queue and told nobody, and the fleet idled
    # until someone read the journal.
    return false
end

"""
    notify_slack(msg; url=ENV["SLACK_WEBHOOK_URL"], title="SpinorBEC", status=:info)

One-shot Slack notifier — emits `msg` as a plain attachment to `url`.
Returns `true` only when the message was actually POSTed. `false` means it was
not — no `SLACK_WEBHOOK_URL`, or the HTTP extension is not loaded. Every path
returned `nothing` until 2026-08-07, so a caller could not distinguish delivered
from dropped and every alert in this repository was silently the latter.

Useful from shell scripts:

    julia --project=. -e 'using HTTP, SpinorBEC; notify_slack(ARGS[1])' "\$msg"
"""
function notify_slack(
    msg::AbstractString;
    url::AbstractString=get(ENV, "SLACK_WEBHOOK_URL", ""),
    title::AbstractString="SpinorBEC",
    status::Symbol=:info,
)
    status in SLACK_STATUSES || throw(
        ArgumentError(
            "notify_slack status $(repr(status)) is not one of $(SLACK_STATUSES); " *
            "the HTTP extension would silently colour it as :info"),
    )
    # NOTE the ordering: the empty-URL case used to `return` here, so an
    # unconfigured webhook took the quietest exit of all three — and "no
    # SLACK_WEBHOOK_URL in the environment" is the single most likely reason an
    # alert is lost. Fall through to the same verdict every other path reaches.
    delivered = if isempty(url)
        @info "SLACK_WEBHOOK_URL unset, skipping notify_slack"
        false
    else
        send_slack_notification(String(url), String(title), String(msg), status) === true
    end
    # An UNDELIVERED alert about something that needs attention must itself be
    # visible. `:info`/`:success` stay quiet — that is chatter — but a
    # warning/error that could not be sent is exactly the case where silence is
    # the failure. `docs/guides/autopilot.md` documents this as the alerting
    # mechanism for a breaker trip.
    if !delivered && !_slack_is_quiet(status)
        @warn "Slack alert NOT delivered (no HTTP extension loaded, or POST " *
            "failed); this message exists only in the log" status title msg
    end
    delivered
end
