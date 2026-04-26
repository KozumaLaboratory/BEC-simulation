# Adaptive advice system - suggests fixes for common problems

struct SimulationAdvice
    problem::String
    severity::Symbol  # :info, :warning, :critical
    suggestions::Vector{String}
    auto_fixable::Bool
end

function analyze_simulation_health(
    ws::Workspace, energy_history::Vector{Float64}, norm_history::Vector{Float64}
)
    advice = SimulationAdvice[]

    # Check energy drift
    if length(energy_history) >= 10
        recent = energy_history[(end - 9):end]
        energy_trend = (recent[end] - recent[1]) / length(recent)
        energy_volatility = std(diff(recent))

        if energy_volatility > 0.1 * abs(mean(recent))
            push!(
                advice,
                SimulationAdvice(
                    "High energy volatility detected",
                    :warning,
                    [
                        "Reduce dt by factor of 2 (current: $(ws.sim_params.dt))",
                        "Enable adaptive integrator",
                        "Check if DDI padding is enabled (reduces aliasing)",
                        "Verify LHY correction is appropriate for current density",
                    ],
                    true,  # Can auto-fix by reducing dt
                ),
            )
        end

        if abs(energy_trend) > 0.01 * abs(mean(recent))
            direction = energy_trend > 0 ? "increasing" : "decreasing"
            push!(
                advice,
                SimulationAdvice(
                    "Energy $direction rapidly",
                    :warning,
                    [
                        "System may be unstable",
                        "Check if dt is too large",
                        "Verify initial state is near ground state",
                        "Consider using imaginary time propagation first",
                    ],
                    false,
                ),
            )
        end
    end

    # Check norm conservation
    if length(norm_history) >= 2
        norm_drift = abs(norm_history[end] - 1.0)
        if norm_drift > 0.01
            push!(
                advice,
                SimulationAdvice(
                    "Norm conservation violated (norm = $(round(norm_history[end], digits=5)))",
                    :critical,
                    [
                        "Reduce dt immediately (current: $(ws.sim_params.dt))",
                        "Check for numerical instabilities",
                        "Verify FFT precision settings",
                        "May need to restart with smaller dt",
                    ],
                    true,
                ),
            )
        end
    end

    # Check for negative density
    try
        n = total_density(ws.state.psi, length(ws.grid.config.n_points))
        if any(n .< -1e-10)
            push!(
                advice,
                SimulationAdvice(
                    "Negative density detected",
                    :critical,
                    [
                        "Simulation is numerically unstable",
                        "STOP and reduce dt by factor of 4",
                        "Check if interactions are too strong",
                        "May need adaptive step size control",
                    ],
                    false,
                ),
            )
        end
    catch
    end

    # Check step rate
    if isdefined(ws, :resource_monitor) && !isempty(ws.resource_monitor.cpu_usage)
        cpu = ws.resource_monitor.cpu_usage[end]
        if cpu < 20.0
            push!(
                advice,
                SimulationAdvice(
                    "Low CPU utilization ($(round(Int, cpu))%)",
                    :info,
                    [
                        "Simulation may be I/O bound",
                        "Reduce save_every to save less frequently",
                        "Check if disk is slow",
                        "Consider using GPU backend for better performance",
                    ],
                    false,
                ),
            )
        end
    end

    # Check DDI padding recommendation
    if ws.ddi !== nothing && ws.ddi_padded === nothing
        grid_size = prod(ws.grid.config.n_points)
        if grid_size >= 32^3
            push!(
                advice,
                SimulationAdvice(
                    "DDI enabled without padding on large grid",
                    :info,
                    [
                        "Enable DDI padding to reduce aliasing errors",
                        "Add ddi_padding=true to make_workspace",
                        "Increases memory ~8x but improves accuracy",
                    ],
                    false,
                ),
            )
        end
    end

    advice
end

function print_advice(advice::Vector{SimulationAdvice})
    isempty(advice) && return nothing

    println()
    println(colorize("═"^80, COLORS.bold))
    println(colorize("🔍 Simulation Health Analysis", COLORS.cyan * COLORS.bold))
    println(colorize("═"^80, COLORS.bold))

    for (i, adv) in enumerate(advice)
        # Color code by severity
        icon_color = if adv.severity == :critical
            COLORS.red
        elseif adv.severity == :warning
            COLORS.yellow
        else
            COLORS.blue
        end

        icon = if adv.severity == :critical
            "❗"
        elseif adv.severity == :warning
            "⚠️ "
        else
            "ℹ️ "
        end

        println()
        println(colorize("$icon Problem: $(adv.problem)", icon_color * COLORS.bold))
        println(colorize("Suggestions:", COLORS.cyan))

        for (j, suggestion) in enumerate(adv.suggestions)
            prefix =
                j == 1 && adv.auto_fixable ? colorize("   → [Auto-fixable]", COLORS.green) : "   →"
            println("$prefix $suggestion")
        end
    end

    println()
    println(colorize("═"^80, COLORS.bold))
end

function auto_fix_suggestions(ws::Workspace, advice::Vector{SimulationAdvice})
    fixes_applied = String[]

    for adv in advice
        if !adv.auto_fixable
            continue
        end

        if contains(adv.problem, "energy volatility") || contains(adv.problem, "Norm conservation")
            # Auto-reduce dt
            old_dt = ws.sim_params.dt
            new_dt = old_dt / 2

            # Note: This would need to create a new workspace
            # For now, just record the recommendation
            push!(fixes_applied, "Recommend reducing dt: $old_dt → $new_dt")
        end
    end

    if !isempty(fixes_applied)
        println()
        println(colorize("🔧 Auto-fix recommendations:", COLORS.green * COLORS.bold))
        for fix in fixes_applied
            println("  • $fix")
        end
        println()
    end

    fixes_applied
end
