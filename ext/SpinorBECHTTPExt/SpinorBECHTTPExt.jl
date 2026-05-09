module SpinorBECHTTPExt

# HTTP is now an opt-in weak dep. Currently the only outbound HTTP call
# in SpinorBEC is the Slack-webhook POST inside the notifications
# subsystem. The stub of `send_slack_notification` lives in
# src/workflow/monitoring/notifications.jl.

using SpinorBEC
using HTTP
using JSON

function SpinorBEC.send_slack_notification(
    webhook_url::String, title::String, message::String, status::Symbol
)
    try
        color = if status == :success
            "good"
        elseif status == :error
            "danger"
        elseif status == :warning
            "warning"
        else
            "#439FE0"
        end

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
    return nothing
end

end # module
