# Notification system for simulation completion/errors

using HTTP
using JSON

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

function send_slack_notification(
    webhook_url::String, title::String, message::String, status::Symbol
)
    try
        # Slack message color
        color = if status == :success
            "good"
        elseif status == :error
            "danger"
        elseif status == :warning
            "warning"
        else
            "#439FE0"
        end

        # Construct payload
        payload = Dict(
            "attachments" => [
                Dict(
                    "color" => color,
                    "title" => title,
                    "text" => message,
                    "footer" => "SpinorBEC.jl",
                    "ts" => round(Int, time()),
                ),
            ],
        )

        # Send POST request
        response = HTTP.post(
            webhook_url,
            ["Content-Type" => "application/json"],
            JSON.json(payload),
        )

        if response.status != 200
            @warn "Slack notification failed with status $(response.status)"
        end
    catch e
        @warn "Slack notification failed: $e"
    end
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
