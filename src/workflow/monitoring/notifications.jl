# Notification system for simulation completion/errors.
#
# `send_slack_notification` is a stub here; the real method is supplied
# by ext/SpinorBECHTTPExt when the user `using HTTP`s. Without HTTP
# loaded, Slack webhooks are silently skipped (with one @info hint).

using JSON

export notify_slack

struct NotificationConfig
    enabled::Bool
    slack_webhook::Union{Nothing, String}
    email::Union{Nothing, String}
    desktop::Bool
end

NotificationConfig() = NotificationConfig(false, nothing, nothing, false)

function send_notification(
    config::NotificationConfig, title::String, message::String; status::Symbol=:info
)
    !config.enabled && return nothing

    # Desktop notification
    if config.desktop
        send_desktop_notification(title, message, status)
    end

    # Slack notification
    if config.slack_webhook !== nothing
        send_slack_notification(config.slack_webhook, title, message, status)
    end

    # Email notification (placeholder - would need SMTP setup)
    if config.email !== nothing
        @warn "Email notifications not yet implemented"
    end
end

function send_desktop_notification(title::String, message::String, status::Symbol)
    try
        if Sys.islinux()
            # Use notify-send on Linux
            icon = if status == :success
                "dialog-information"
            elseif status == :error
                "dialog-error"
            elseif status == :warning
                "dialog-warning"
            else
                "dialog-information"
            end

            run(`notify-send -u normal -i $icon $title $message`)

        elseif Sys.isapple()
            # Use osascript on macOS
            script = """display notification "$message" with title "$title\""""
            run(`osascript -e $script`)

        elseif Sys.iswindows()
            # Use PowerShell on Windows
            ps_script = """
            [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
            [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
            [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

            \$template = @"
            <toast>
                <visual>
                    <binding template="ToastText02">
                        <text id="1">$title</text>
                        <text id="2">$message</text>
                    </binding>
                </visual>
            </toast>
            "@

            \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
            \$xml.LoadXml(\$template)
            \$toast = New-Object Windows.UI.Notifications.ToastNotification \$xml
            [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Julia").Show(\$toast)
            """

            run(`powershell -Command $ps_script`)
        end
    catch e
        @debug "Desktop notification failed: $e"
    end
end

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

function notify_simulation_complete(
    config::NotificationConfig, phase_names::Vector{String}, total_time::Float64
)
    title = "✓ Simulation Complete"
    message =
        "Completed $(length(phase_names)) phases in $(format_time(total_time))\n" *
        "Phases: " * join(phase_names, ", ")

    send_notification(config, title, message; status=:success)
end

function notify_simulation_failed(config::NotificationConfig, error_msg::String)
    title = "✗ Simulation Failed"
    message = "Error: $error_msg"

    send_notification(config, title, message; status=:error)
end

function notify_checkpoint_saved(config::NotificationConfig, checkpoint_path::String)
    title = "💾 Checkpoint Saved"
    message = "Checkpoint: $checkpoint_path"

    send_notification(config, title, message; status=:info)
end
