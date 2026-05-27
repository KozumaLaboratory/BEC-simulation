# Profile an Eu (or any spinor) ITP run to determine whether it is
#   (a) integrator-limited:  dE/dpsi decay exponentially, dt sits at
#                            its ceiling → higher-order integrator helps
#   (b) landscape-limited:   dE/dpsi plateau or noise floor → integrator
#                            order doesn't help; fix initial state /
#                            Mz pinning / basin hopping
#   (mixed):                 partial signatures of both
#
# This script is a TEMPLATE. The default `_demo_eu_itp_setup` runs a
# small 16³ Eu config to validate the trace-capture + classifier
# machinery. For production diagnosis (64³+, real production runs)
# replace the setup call with your own workspace builder, or read
# trace history out of an existing JLD2 result file.
#
# Run:
#   julia --project=. scripts/bench/itp_profile.jl
#
# Output: console report + CSV of the trace at /tmp/itp_profile_trace.csv
# Pair with scripts/bench/plot_itp_profile.py for log-scale visualisation.

using SpinorBEC
using Printf
using Statistics: mean

# ---------------------------------------------------------------------------
# Trace capture
# ---------------------------------------------------------------------------

mutable struct ItpTrace
    iter::Vector{Int}
    t_wall::Vector{Float64}    # cumulative wall-clock seconds
    dt::Vector{Float64}
    E::Vector{Float64}
    dE::Vector{Float64}        # |E_k - E_{k-1}|
    dpsi::Vector{Float64}      # ‖ψ_k - ψ_{k-1}‖ (rough proxy for ‖∇E‖)
    norm::Vector{Float64}
    Mz::Vector{Float64}
end
ItpTrace() = ItpTrace([], [], [], [], [], [], [], [])

function _make_logging_callback(trace::ItpTrace; every::Int=1)
    last_E = Ref{Float64}(NaN)
    last_psi = Ref{Any}(nothing)
    t0 = Ref{Float64}(NaN)

    function on_step(ws, step, n_steps)
        if isnan(t0[])
            t0[] = time()
        end
        step % every == 0 || return nothing

        E_now = SpinorBEC.total_energy(ws)
        nrm = SpinorBEC.total_norm(ws.state.psi, ws.grid)
        sys = ws.spin_matrices.system
        Mz_now = SpinorBEC.magnetization(ws.state.psi, ws.grid, sys)

        psi_now = Array(ws.state.psi)
        dpsi_val = if last_psi[] === nothing
            0.0
        else
            sqrt(sum(abs2, psi_now .- last_psi[])) / sqrt(sum(abs2, psi_now))
        end
        dE_val = isnan(last_E[]) ? 0.0 : abs(E_now - last_E[])

        push!(trace.iter, step)
        push!(trace.t_wall, time() - t0[])
        push!(trace.dt, ws.sim_params.dt)
        push!(trace.E, E_now)
        push!(trace.dE, dE_val)
        push!(trace.dpsi, dpsi_val)
        push!(trace.norm, nrm)
        push!(trace.Mz, Mz_now)

        last_E[] = E_now
        last_psi[] = psi_now
        nothing
    end
    on_step
end

# ---------------------------------------------------------------------------
# Classifier
# ---------------------------------------------------------------------------

# Fit a log-linear decay rate from the second half of the trace
# (avoids transient at start). Returns slope and an "exponentiality"
# score in [0, 1] (1 = perfect log-linear, 0 = pure plateau / noise).
function _log_decay_fit(y::Vector{Float64})
    valid = filter(>(0), y)
    length(valid) < 8 && return (slope=NaN, exp_score=NaN)
    half = (length(valid) ÷ 2) + 1
    tail = log.(valid[half:end])
    iters = collect(0:(length(tail) - 1))
    n = length(tail)
    x̄ = mean(iters);
    ȳ = mean(tail)
    Sxx = sum((iters .- x̄) .^ 2)
    Sxy = sum((iters .- x̄) .* (tail .- ȳ))
    slope = Sxy / Sxx
    intercept = ȳ - slope * x̄
    yfit = slope .* iters .+ intercept
    ss_tot = sum((tail .- ȳ) .^ 2)
    ss_res = sum((tail .- yfit) .^ 2)
    r2 = ss_tot > 0 ? max(0.0, 1.0 - ss_res / ss_tot) : 0.0
    (slope=slope, exp_score=r2)
end

function classify_itp(trace::ItpTrace; dt_cap::Union{Nothing, Float64}=nothing)
    fit_dE = _log_decay_fit(trace.dE)
    fit_dpsi = _log_decay_fit(trace.dpsi)

    # dt cap signature: if max(dt) ≈ dt_cap throughout most of the run,
    # the integrator is at its stability/accuracy ceiling
    dt_cap_ratio = if dt_cap === nothing
        # No explicit cap given: use observed max
        isempty(trace.dt) ? NaN : maximum(trace.dt) / maximum(trace.dt)
    else
        isempty(trace.dt) ? NaN : maximum(trace.dt) / dt_cap
    end
    dt_at_cap_frac = if dt_cap === nothing || isempty(trace.dt)
        NaN
    else
        sum(abs.(trace.dt .- dt_cap) .< 0.01 * dt_cap) / length(trace.dt)
    end

    @printf("\n=== ITP profile classification ===\n")
    @printf("  iterations captured:     %d\n", length(trace.iter))
    @printf("  total wall-clock:        %.1f s\n",
        isempty(trace.t_wall) ? NaN : trace.t_wall[end])
    @printf("  E_final, dE_final:       % .6e, %.3e\n",
        isempty(trace.E) ? NaN : trace.E[end],
        isempty(trace.dE) ? NaN : trace.dE[end])
    @printf("  dpsi_final:              %.3e\n",
        isempty(trace.dpsi) ? NaN : trace.dpsi[end])
    @printf("  log-decay slope (dE):    %.4f  (R²=%.3f, 1=clean exp decay, 0=plateau)\n",
        fit_dE.slope, fit_dE.exp_score)
    @printf("  log-decay slope (dpsi):  %.4f  (R²=%.3f)\n",
        fit_dpsi.slope, fit_dpsi.exp_score)
    if !isnan(dt_at_cap_frac)
        @printf("  dt-at-cap fraction:      %.2f  (1=always at ceiling, 0=never)\n",
            dt_at_cap_frac)
    end

    # Heuristic classifier
    @printf("\n  Verdict:\n")
    if !isnan(fit_dE.exp_score) && fit_dE.exp_score > 0.85 && fit_dE.slope < -0.001
        if !isnan(dt_at_cap_frac) && dt_at_cap_frac > 0.5
            @printf("    (a) INTEGRATOR-LIMITED — clean exp decay AND dt at ceiling.\n")
            @printf("        Higher-order integrator (MPS-{4,6}) should reduce wall-clock\n")
            @printf("        for the same final tol.\n")
        else
            @printf("    Mixed / unclear — clean exp decay but dt has headroom.\n")
            @printf("        ITP is converging well already; higher-order may help wall-clock\n")
            @printf("        but is not a critical bottleneck.\n")
        end
    elseif !isnan(fit_dE.exp_score) && fit_dE.exp_score < 0.5
        @printf("    (b) LANDSCAPE-LIMITED — log(dE) is not a clean line. Likely plateau /\n")
        @printf("        oscillation / multi-mode. Higher-order integrator will not help.\n")
        @printf("        Consider: initial-state diversification, Mz pinning strategy,\n")
        @printf("        annealing, basin hopping.\n")
    else
        @printf("    Inconclusive — need longer trace or different metric.\n")
    end
end

# ---------------------------------------------------------------------------
# Trace export
# ---------------------------------------------------------------------------

function save_trace_csv(trace::ItpTrace, path::AbstractString)
    open(path, "w") do io
        println(io, "iter,t_wall_s,dt,E,dE,dpsi,norm,Mz")
        for k in eachindex(trace.iter)
            @printf(io, "%d,%.6f,%.6e,%.10e,%.6e,%.6e,%.10f,%.6e\n",
                trace.iter[k], trace.t_wall[k], trace.dt[k],
                trace.E[k], trace.dE[k], trace.dpsi[k],
                trace.norm[k], trace.Mz[k])
        end
    end
    println("Trace saved to ", path)
end

# ---------------------------------------------------------------------------
# Demo: small Eu ITP
# ---------------------------------------------------------------------------
# Replace this with your production setup (e.g. read a YAML config and
# call `find_ground_state` directly, or read a JLD2 trace from runs/).

function _demo_eu_itp_setup(; N::Int=16, n_steps::Int=500, dt::Float64=0.005)
    grid = make_grid(GridConfig((N, N, N), (8.0, 8.0, 8.0)))
    trace = ItpTrace()
    callback = _make_logging_callback(trace; every=5)

    result = find_ground_state(;
        grid=grid,
        atom=Eu151,
        interactions=InteractionParams(Dict(0 => 50.0, 1 => 1.0)),
        zeeman=ZeemanParams(0.5, 0.1),
        potential=HarmonicTrap(1.0, 1.0, 1.0),
        dt=dt,
        n_steps=n_steps,
        tol=1.0e-10,
        enable_ddi=true,
        c_dd=100.0,
        on_step=callback,
        verbose=false,
    )

    println("\nfind_ground_state returned:")
    println("  E_final = ", round(result.energy; digits=8))
    println("  dE_final = ", round(result.dE; sigdigits=4))
    println("  converged = ", result.converged)
    println("  last_step = ", result.last_step)

    trace, result, dt
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("=== ITP profiling — demo on small Eu ITP (16³) ===")
    println("(Replace `_demo_eu_itp_setup` with your production setup or JLD2 reader.)\n")
    trace, _result, dt_cap = _demo_eu_itp_setup()
    classify_itp(trace; dt_cap=dt_cap)
    save_trace_csv(trace, "/tmp/itp_profile_trace.csv")
end
