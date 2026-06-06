# Slack webhook notifications.
#
# `send_slack_notification` is a stub here; the real method is supplied
# by ext/SpinorBECHTTPExt when the user `using HTTP`s. Without HTTP
# loaded, Slack webhooks are silently skipped (with one @info hint).

export notify_slack

const _SLACK_HTTP_HINT_SHOWN = Ref(false)

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
    return nothing
end

"""
    notify_slack(msg; url=ENV["SLACK_WEBHOOK_URL"], title="SpinorBEC", status=:info)

One-shot Slack notifier — emits `msg` as a plain attachment to `url`.
Returns silently (with a one-time hint) when the webhook URL is empty
or when HTTP is not loaded. Useful from shell scripts:

    julia --project=. -e 'using HTTP, SpinorBEC; notify_slack(ARGS[1])' "\$msg"
"""
function notify_slack(
    msg::AbstractString;
    url::AbstractString=get(ENV, "SLACK_WEBHOOK_URL", ""),
    title::AbstractString="SpinorBEC",
    status::Symbol=:info,
)
    if isempty(url)
        @info "SLACK_WEBHOOK_URL unset, skipping notify_slack"
        return nothing
    end
    send_slack_notification(String(url), String(title), String(msg), status)
end

