"""
    ensemble_correlation(results_a, results_b) → corr

Connected correlation ⟨AB⟩ - ⟨A⟩⟨B⟩ from two sets of per-trajectory results.
Each input is a Vector of Array (one per trajectory, same shape).
"""
function ensemble_correlation(
    results_a::Vector{<:AbstractArray{<:AbstractFloat}},
    results_b::Vector{<:AbstractArray{<:AbstractFloat}},
)
    n = length(results_a)
    n == length(results_b) || throw(DimensionMismatch("trajectory count mismatch"))
    n > 0 || throw(ArgumentError("need at least one trajectory"))

    mean_a = sum(results_a) ./ n
    mean_b = sum(results_b) ./ n
    mean_ab = sum(a .* b for (a, b) in zip(results_a, results_b)) ./ n
    mean_ab .- mean_a .* mean_b
end

"""
    wigner_correct_density(mean_density_k, grid) → corrected

Subtract ½-particle-per-mode Wigner correction from density in k-space.

In k-space, the vacuum noise contributes D/(2V) per mode to the density,
where D = number of spinor components. Since the caller may not know D,
this function subtracts 1/(2V) per call — call D times or pass the
pre-summed density over components.

For total density: correction = D/(2V) per k-mode.
"""
function wigner_correct_density(
    mean_density_k::AbstractArray{<:AbstractFloat},
    grid::Grid{N};
    n_components::Int=1,
) where {N}
    V = prod(grid.config.box_size)
    correction = n_components / (2.0 * V)
    mean_density_k .- correction
end

"""
    ensemble_stderr(var, n_traj) → stderr

Standard error of the ensemble mean: √(var / n_traj).
"""
function ensemble_stderr(var::AbstractArray{<:AbstractFloat}, n_traj::Int)
    n_traj > 0 || throw(ArgumentError("n_traj must be positive"))
    sqrt.(var ./ n_traj)
end
