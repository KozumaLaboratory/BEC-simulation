# Structured logging system

using Dates
using JSON

mutable struct SimulationLogger
    log_dir::String
    log_file::String
    json_file::String
    enabled::Bool
    events::Vector{Dict{String,Any}}
end

function SimulationLogger(output_dir::String; enabled::Bool=true)
    mkpath(output_dir)
    timestamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
    log_file = joinpath(output_dir, "simulation_$(timestamp).log")
    json_file = joinpath(output_dir, "simulation_$(timestamp).json")

    logger = SimulationLogger(output_dir, log_file, json_file, enabled, Dict{String,Any}[])

    if enabled
        # Write header
        open(log_file, "w") do io
            println(io, "="^80)
            println(io, "Simulation Log - Started at $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
            println(io, "="^80)
            println(io)
        end
    end

    logger
end

function log_event!(logger::SimulationLogger, level::String, message::String; kwargs...)
    !logger.enabled && return

    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS.sss")

    # Create event
    event = Dict{String,Any}(
        "timestamp" => timestamp,
        "level" => level,
        "message" => message,
    )

    # Add any additional fields
    for (k, v) in kwargs
        event[String(k)] = v
    end

    push!(logger.events, event)

    # Write to log file
    open(logger.log_file, "a") do io
        level_str = rpad("[$level]", 10)
        println(io, "[$timestamp] $level_str $message")

        # Write additional fields
        for (k, v) in kwargs
            println(io, "  $(k): $(v)")
        end
    end
end

log_info!(logger, msg; kwargs...) = log_event!(logger, "INFO", msg; kwargs...)
log_warning!(logger, msg; kwargs...) = log_event!(logger, "WARNING", msg; kwargs...)
log_error!(logger, msg; kwargs...) = log_event!(logger, "ERROR", msg; kwargs...)
log_debug!(logger, msg; kwargs...) = log_event!(logger, "DEBUG", msg; kwargs...)

function log_phase_start!(logger::SimulationLogger, phase_name::String, duration::Float64, dt::Float64, n_steps::Int)
    log_info!(logger, "Phase started: $phase_name",
              duration=duration, dt=dt, n_steps=n_steps)
end

function log_phase_end!(logger::SimulationLogger, phase_name::String, elapsed::Float64, E_final::Float64)
    log_info!(logger, "Phase completed: $phase_name",
              elapsed=elapsed, final_energy=E_final)
end

function log_progress!(logger::SimulationLogger, step::Int, total::Int, observables::Dict)
    log_debug!(logger, "Progress update",
               step=step, total=total, observables...)
end

function log_anomaly!(logger::SimulationLogger, anomaly_type::String, details::String)
    log_warning!(logger, "Anomaly detected: $anomaly_type",
                 details=details)
end

function finalize_log!(logger::SimulationLogger)
    !logger.enabled && return

    # Write summary to log file
    open(logger.log_file, "a") do io
        println(io)
        println(io, "="^80)
        println(io, "Simulation Log - Ended at $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
        println(io, "Total events: $(length(logger.events))")
        println(io, "="^80)
    end

    # Write JSON file
    open(logger.json_file, "w") do io
        JSON.print(io, Dict(
            "start_time" => logger.events[1]["timestamp"],
            "end_time" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS.sss"),
            "events" => logger.events
        ), 2)
    end

    println("Logs saved:")
    println("  Text: $(logger.log_file)")
    println("  JSON: $(logger.json_file)")
end
