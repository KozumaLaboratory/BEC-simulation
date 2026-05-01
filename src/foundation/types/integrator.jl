# --- Integrator config + simulation/ensemble result types ---
#
# `AdaptiveDtParams` parametrises the embedded-error / Richardson dt
# controller; `IntegratorConfig` selects between :strang / :yoshida /
# :adaptive. `SimulationResult` is the per-trajectory output bundle
# (times, energies, norms, magnetisations, snapshot tower);
# `TWAConfig` and `EnsembleResult` are the Truncated-Wigner ensemble
# wrappers.

# --- Adaptive Time Stepping ---

struct AdaptiveDtParams
    dt_init::Float64
    dt_min::Float64
    dt_max::Float64
    tol::Float64
    error_mode::Symbol

    function AdaptiveDtParams(;
        dt_init::Float64=0.001,
        dt_min::Float64=1e-5,
        dt_max::Float64=0.01,
        tol::Float64=1e-3,
        error_mode::Symbol=:step_change,
    )
        dt_init > 0 || throw(ArgumentError("dt_init must be positive"))
        dt_min > 0 || throw(ArgumentError("dt_min must be positive"))
        dt_max >= dt_min || throw(ArgumentError("dt_max must be >= dt_min"))
        tol > 0 || throw(ArgumentError("tol must be positive"))
        error_mode in (:step_change, :richardson, :embedded) || throw(
            ArgumentError(
                "error_mode must be :step_change, :richardson, or :embedded, got :$error_mode"
            ),
        )
        new(dt_init, dt_min, dt_max, tol, error_mode)
    end
end

struct IntegratorConfig
    method::Symbol
    params::Union{Nothing, AdaptiveDtParams}

    function IntegratorConfig(
        method::Symbol,
        params::Union{Nothing, AdaptiveDtParams}=nothing,
    )
        method in (:strang, :yoshida, :adaptive) || throw(
            ArgumentError(
                "integrator method must be :strang, :yoshida, or :adaptive, got :$method"
            ),
        )
        if method == :adaptive && params === nothing
            throw(ArgumentError("adaptive integrator requires AdaptiveDtParams"))
        end
        new(method, params)
    end
end

IntegratorConfig() = IntegratorConfig(:strang, nothing)

# --- Simulation Result ---

struct SimulationResult
    times::Vector{Float64}
    energies::Vector{Float64}
    norms::Vector{Float64}
    magnetizations::Vector{Float64}
    psi_snapshots::Vector{Array{ComplexF64}}
end

# --- TWA (Truncated Wigner Approximation) ---

struct TWAConfig
    n_trajectories::Int
    seed_base::Int
    cutoff_energy::Union{Nothing, Float64}
    observables::Vector{Symbol}

    function TWAConfig(
        n_trajectories::Int,
        seed_base::Int=42,
        cutoff_energy::Union{Nothing, Float64}=nothing,
        observables::Vector{Symbol}=[:density, :magnetization],
    )
        n_trajectories > 0 || throw(ArgumentError("n_trajectories must be positive"))
        new(n_trajectories, seed_base, cutoff_energy, observables)
    end
end

struct EnsembleResult
    times::Vector{Float64}
    mean::Dict{Symbol, Vector{<:AbstractArray}}
    var::Dict{Symbol, Vector{<:AbstractArray}}
    n_trajectories::Int
    trajectory_results::Union{Nothing, Vector{SimulationResult}}
    # Last trajectory's full SimulationResult (with psi_snapshots). Always
    # retained so the dashboard auto-save can stream dynamics frames even
    # when the user didn't request `store_trajectories=true`. Use
    # `last_trajectory.psi_snapshots[end]` for the post-evolution ψ when the
    # caller needs a representative state (the snapshot at the last step
    # IS `ws.state.psi` whenever `save_every` divides `n_steps`, which is
    # the typical case). Distinct from `trajectory_results` which holds
    # *every* trajectory and is opt-in.
    last_trajectory::Union{Nothing, SimulationResult}
end
EnsembleResult(times, mean, var, n_trajectories, trajectory_results) =
    EnsembleResult(times, mean, var, n_trajectories, trajectory_results, nothing)
