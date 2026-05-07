# --- Scan specs + ITP checkpoint ---
#
# AbstractScanSpec hierarchy (OverrideScan / ConstrainedJzScan) and the
# pause/resume checkpoint type. Pure data; expansion logic lives in
# `src/workflow/experiments/config_override.jl`.

# --- Phase Scan Types ---

abstract type AbstractScanSpec end

"""
    OverrideScan

Scan spec built from path-based config overrides. Each scan point is one
override map (a dict of dotted YAML paths → values) that the runner applies
to the raw YAML dict and re-parses before running.

Fields:
- `points`: list of override maps, one per scan point. Generated from a
  YAML `zip:` or `product:` block (see `expand_scan_points`).
- `comparison_runs`: list of `(name, override)` pairs. When non-empty, every
  scan point is run once per comparison run; the comparison override is
  merged on top of the scan point override.
- `continuation`: when true, the previous point's converged psi is reused
  as the initial condition for the next point.
- `auto_rotate_on_mz`: when true and `ground_state.target_magnetization`
  changes between adjacent points, the carried-over psi is rotated by
  Δα around y so the constraint normalization can redistribute populations.
"""
struct OverrideScan <: AbstractScanSpec
    points::Vector{Dict{String, Any}}
    comparison_runs::Vector{Tuple{String, Dict{String, Any}}}
    continuation::Bool
    auto_rotate_on_mz::Bool

    function OverrideScan(
        points::Vector{<:Dict},
        comparison_runs::Vector{<:Tuple{<:AbstractString, <:Dict}}=Tuple{
            String, Dict{String, Any}
        }[],
        continuation::Bool=false,
        auto_rotate_on_mz::Bool=false,
    )
        isempty(points) && throw(ArgumentError("OverrideScan requires at least one point"))
        new(
            Dict{String, Any}[Dict{String, Any}(p) for p in points],
            Tuple{String, Dict{String, Any}}[
                (String(n), Dict{String, Any}(o)) for (n, o) in comparison_runs
            ],
            continuation,
            auto_rotate_on_mz,
        )
    end
end

"""
    ConstrainedJzScan

Scan a list of target `J_z` values, bisecting on the rotating-frame `Ω`
inside `find_ground_state` until the actual `J_z` matches the target within
`tolerance`. This is the one scan type that does NOT fit the
override-reparse model because the parameter being tuned (`Ω`) is resolved
by a runtime feedback loop, not by patching the config tree.
"""
struct ConstrainedJzScan <: AbstractScanSpec
    target_values::Vector{Float64}
    tolerance::Float64
    max_iter::Int
    omega_range::Tuple{Float64, Float64}

    function ConstrainedJzScan(
        target_values::Vector{Float64},
        tolerance::Float64,
        max_iter::Int,
        omega_range::Tuple{Float64, Float64},
    )
        !isempty(target_values) || throw(ArgumentError("target_values must not be empty"))
        tolerance > 0 || throw(ArgumentError("tolerance must be positive"))
        max_iter > 0 || throw(ArgumentError("max_iter must be positive"))
        omega_range[1] < omega_range[2] ||
            throw(ArgumentError("omega_range must satisfy lo < hi"))
        new(target_values, tolerance, max_iter, omega_range)
    end
end

# --- ITP Checkpoint (for pause/resume/refine) ---

struct ITPCheckpoint
    psi::Array{ComplexF64}
    step::Int
    n_steps::Int
    energy::Float64
    dE::Float64
    dpsi::Float64
    converged::Bool
    dt::Float64
    tol::Float64
end
