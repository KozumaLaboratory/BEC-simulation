# Enhanced Progress Reporting System

using Printf

# Terminal colors
const COLORS = (
    reset = "\033[0m",
    red = "\033[31m",
    green = "\033[32m",
    yellow = "\033[33m",
    blue = "\033[34m",
    magenta = "\033[35m",
    cyan = "\033[36m",
    bold = "\033[1m",
)

const USE_COLOR = get(ENV, "TERM", "") != "dumb" && isinteractive()

function colorize(text::String, color::String)
    USE_COLOR ? color * text * COLORS.reset : text
end

# Observable history for trend detection
mutable struct ObservableHistory
    values::Vector{Float64}
    max_length::Int
end

ObservableHistory(max_length::Int=10) = ObservableHistory(Float64[], max_length)

function push_value!(h::ObservableHistory, val::Float64)
    push!(h.values, val)
    if length(h.values) > h.max_length
        popfirst!(h.values)
    end
end

function trend(h::ObservableHistory)
    length(h.values) < 2 && return "→"
    recent = h.values[max(1, end-4):end]
    if length(recent) < 2
        return "→"
    end
    slope = (recent[end] - recent[1]) / length(recent)
    abs(slope) < 1e-10 && return "→"
    slope > 0 ? "↗" : "↘"
end

# Enhanced progress reporter
mutable struct ProgressReporter
    phase_name::String
    total_steps::Int
    print_every::Int
    compact_mode::Bool

    # Timing
    start_time::Float64
    last_print_time::Float64
    last_print_step::Int

    # Observable history
    energy_hist::ObservableHistory
    norm_hist::ObservableHistory
    mag_hist::ObservableHistory

    # Performance tracking
    steps_times::Vector{Float64}  # Time for recent steps

    # Anomaly detection
    last_energy::Union{Nothing,Float64}
    energy_drift_threshold::Float64
    norm_violation_threshold::Float64

    # Phase comparison
    avg_step_time::Union{Nothing,Float64}
end

function ProgressReporter(
    phase_name::String,
    total_steps::Int;
    print_every::Int=100,
    compact_mode::Bool=false,
)
    t = time()
    ProgressReporter(
        phase_name,
        total_steps,
        print_every,
        compact_mode,
        t,
        t,
        0,
        ObservableHistory(),
        ObservableHistory(),
        ObservableHistory(),
        Float64[],
        nothing,
        0.02,  # 2% energy drift threshold
        0.005, # 0.5% norm violation
        nothing,
    )
end

function should_print(pr::ProgressReporter, step::Int)
    step >= pr.last_print_step + pr.print_every || step == pr.total_steps
end

function update_performance!(pr::ProgressReporter, elapsed::Float64, steps_done::Int)
    if steps_done > 0
        step_time = elapsed / steps_done
        push!(pr.steps_times, step_time)
        if length(pr.steps_times) > 10
            popfirst!(pr.steps_times)
        end
    end
end

function avg_step_rate(pr::ProgressReporter)
    isempty(pr.steps_times) && return 0.0
    avg_time = sum(pr.steps_times) / length(pr.steps_times)
    avg_time > 0 ? 1.0 / avg_time : 0.0
end

function draw_progress_bar(current::Int, total::Int, width::Int=20)
    fraction = current / total
    filled = round(Int, fraction * width)
    bar = "█"^filled * "░"^(width - filled)
    bar
end

function format_time(seconds::Float64)
    if seconds < 60
        return @sprintf("%.0fs", seconds)
    elseif seconds < 3600
        mins = div(seconds, 60)
        secs = mod(seconds, 60)
        return @sprintf("%dm %ds", mins, secs)
    else
        hours = div(seconds, 3600)
        mins = div(mod(seconds, 3600), 60)
        return @sprintf("%dh %dm", hours, mins)
    end
end

function format_number(x::Float64, digits::Int=4)
    abs(x) < 1e-10 && return "0.0"
    abs(x) >= 1000 ? @sprintf("%.1e", x) : @sprintf("%.*f", digits, x)
end

function detect_anomalies(pr::ProgressReporter, E::Float64, norm::Float64)
    warnings = String[]

    # Energy drift check
    if pr.last_energy !== nothing
        drift = abs(E - pr.last_energy) / max(abs(pr.last_energy), 1e-10)
        if drift > pr.energy_drift_threshold
            msg = @sprintf("Energy drift %.1f%% over last %d steps",
                          drift * 100, pr.print_every)
            push!(warnings, colorize("⚠️  $msg", COLORS.yellow))
        end
    end

    # Norm violation check
    norm_error = abs(norm - 1.0)
    if norm_error > pr.norm_violation_threshold
        msg = @sprintf("Norm violation: %.4f (should be ~1.0)", norm)
        push!(warnings, colorize("⚠️  $msg", COLORS.yellow))
    end

    # Extreme energy check
    if abs(E) > 1e6
        push!(warnings, colorize("❗ Alert: Extreme energy value detected", COLORS.red))
    end

    pr.last_energy = E

    warnings
end

function get_populations(ws::Workspace)
    F = ws.atom.F
    D = 2F + 1
    dV = cell_volume(ws.grid)

    pops = Dict{Int,Float64}()
    for c in 1:D
        m = F - (c - 1)
        p = sum(component_density(ws.state.psi, length(ws.grid.config.n_points), c)) * dV
        pops[m] = p
    end
    pops
end

function get_angular_momentum(ws::Workspace)
    # Simple estimate: ⟨Lz⟩ ≈ sum of vorticity
    # For now, return 0.0 (full implementation would need vorticity calculation)
    0.0
end

function print_progress(pr::ProgressReporter, ws::Workspace, step::Int)
    if !should_print(pr, step)
        return
    end

    t_now = time()
    elapsed = t_now - pr.start_time
    steps_done = step - pr.last_print_step
    update_performance!(pr, elapsed, step)

    # Calculate ETA
    if step > 0
        time_per_step = elapsed / step
        remaining_steps = pr.total_steps - step
        eta = time_per_step * remaining_steps
    else
        eta = 0.0
    end

    # Get observables
    E = total_energy(ws)
    norm = total_norm(ws.state.psi, ws.grid)
    mag = magnetization(ws.state.psi, ws.grid, ws.spin_matrices.system)
    t_sim = ws.state.t

    # Update history
    push_value!(pr.energy_hist, E)
    push_value!(pr.norm_hist, norm)
    push_value!(pr.mag_hist, mag)

    # Get populations for key states
    F = ws.atom.F
    pops = get_populations(ws)

    # Detect anomalies
    warnings = detect_anomalies(pr, E, norm)

    # Calculate performance
    step_rate = avg_step_rate(pr)

    # Memory usage (approximate)
    mem_mb = @sprintf("%.0f", Base.summarysize(ws) / 1e6)

    if pr.compact_mode
        # Compact single-line mode
        bar = draw_progress_bar(step, pr.total_steps, 10)
        pct = round(Int, 100 * step / pr.total_steps)

        # Key populations
        p_main = haskey(pops, -F) ? pops[-F] : 0.0
        p_next = haskey(pops, -F+1) ? pops[-F+1] : 0.0

        line = @sprintf("\r%s %3d%% | t=%.2f/%.2f | E=%s%s | P(%d)=%.2f%s P(%d)=%.2f%s | %.1fst/s | ETA:%s",
                       bar, pct, t_sim, t_sim + (pr.total_steps - step) * ws.sim_params.dt,
                       format_number(E, 2), trend(pr.energy_hist),
                       -F, p_main, trend(ObservableHistory()),
                       -F+1, p_next, trend(ObservableHistory()),
                       step_rate, format_time(eta))

        print(line)
        flush(stdout)
    else
        # Full multi-line mode
        bar = draw_progress_bar(step, pr.total_steps, 30)
        pct = round(Int, 100 * step / pr.total_steps)

        # Format main line
        phase_colored = colorize(pr.phase_name, COLORS.cyan * COLORS.bold)
        bar_colored = colorize(bar, pct < 100 ? COLORS.blue : COLORS.green)

        println("  $phase_colored: $bar_colored $pct% ($step/$(pr.total_steps))")

        # Observables line
        E_str = format_number(E, 4) * " " * trend(pr.energy_hist)
        mag_str = format_number(mag, 4) * " " * trend(pr.mag_hist)

        obs_parts = [
            "t=$(format_number(t_sim, 3)) ω⁻¹",
            "E=$E_str",
            "⟨mz⟩=$mag_str",
            "norm=$(format_number(norm, 5))",
        ]

        # Add key populations (m=-F and m=-F+1 for the experiment)
        if haskey(pops, -F)
            p_str = format_number(pops[-F], 3)
            obs_parts = push!(obs_parts, "P(m=$(-F))=$p_str")
        end
        if haskey(pops, -F+1)
            p_str = format_number(pops[-F+1], 3)
            obs_parts = push!(obs_parts, "P(m=$(-F+1))=$p_str")
        end

        println("    " * join(obs_parts, " | "))

        # Performance line
        perf_parts = [
            colorize("$(format_number(step_rate, 1)) step/s", COLORS.green),
            "$(mem_mb)MB",
            "elapsed: $(format_time(elapsed))",
            "ETA: $(format_time(eta))",
        ]
        println("    " * join(perf_parts, " | "))

        # Print warnings
        for warning in warnings
            println("    $warning")
        end
    end

    pr.last_print_step = step
    pr.last_print_time = t_now

    # Store average for phase comparison
    if step == pr.total_steps
        pr.avg_step_time = elapsed / pr.total_steps
    end
end

function print_phase_header(phase_name::String, duration::Float64, dt::Float64, n_steps::Int)
    println()
    println(colorize("═"^80, COLORS.bold))
    title = "Phase: $phase_name"
    println(colorize(title, COLORS.cyan * COLORS.bold))
    println("  Duration: $duration ω⁻¹ | dt: $dt | steps: $n_steps")
    println(colorize("═"^80, COLORS.bold))
end

function print_phase_summary(
    phase_name::String,
    elapsed::Float64,
    E_initial::Float64,
    E_final::Float64,
    step_rate::Float64,
)
    println()
    println(colorize("─"^80, COLORS.bold))

    status = colorize("✓", COLORS.green * COLORS.bold)
    println("$status Phase '$phase_name' completed in $(format_time(elapsed))")

    dE = E_final - E_initial
    dE_str = dE >= 0 ? "+$(format_number(abs(dE), 6))" : "-$(format_number(abs(dE), 6))"
    dE_colored = dE >= 0 ?
        colorize(dE_str, abs(dE) > 0.01 ? COLORS.yellow : COLORS.green) :
        colorize(dE_str, COLORS.green)

    println("  Energy: $(format_number(E_initial, 4)) → $(format_number(E_final, 4)) (ΔE = $dE_colored)")
    println("  Performance: $(format_number(step_rate, 1)) steps/s")
    println(colorize("─"^80, COLORS.bold))
end

function print_simulation_summary(
    total_time::Float64,
    phase_names::Vector{String},
    phase_times::Vector{Float64},
    phase_rates::Vector{Float64},
)
    println()
    println(colorize("═"^80, COLORS.bold))
    title = "SIMULATION COMPLETE"
    println(colorize(title, COLORS.green * COLORS.bold))
    println("  Total time: $(format_time(total_time))")
    println()
    println("  Phase summary:")

    for (i, (name, t, rate)) in enumerate(zip(phase_names, phase_times, phase_rates))
        pct = 100 * t / total_time
        comparison = ""
        if i > 1 && phase_rates[i-1] > 0
            speedup = rate / phase_rates[i-1]
            if speedup > 1.05
                comparison = colorize(@sprintf(" (%.0f%% faster)", (speedup - 1) * 100), COLORS.green)
            elseif speedup < 0.95
                comparison = colorize(@sprintf(" (%.0f%% slower)", (1 - speedup) * 100), COLORS.yellow)
            end
        end

        bar_width = round(Int, pct / 100 * 40)
        bar = "▓"^bar_width * "░"^(40 - bar_width)

        println(@sprintf("    %d. %-20s %s %.1f%% (%s, %.1f st/s)%s",
                        i, name, bar, pct, format_time(t), rate, comparison))
    end

    println(colorize("═"^80, COLORS.bold))
    println()
end

# Compact mode cleanup
function finish_compact_line()
    println()  # Move to next line after compact progress
end
