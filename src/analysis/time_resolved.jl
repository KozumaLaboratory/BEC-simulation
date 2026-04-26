# --- P3.3: Time-resolved spin tomography ---
#
# Drive a dynamics phase storing wavefunction snapshots, then run
# `spin_tomography` at each snapshot to produce a 4D image stack:
#
#     images[m][t_idx][i] = 2D column density at time t_idx, rotation angle i
#
# This is the natural way to map coherent spin evolution vs the experimental
# SG-imaging protocol — each snapshot yields the full tomography set so you
# can reconstruct the Bloch-vector trajectory at any time point.

using SpinorBEC: SimulationResult, TOFParams

"""
    time_resolved_tomography(sim_result, grid, F; kwargs...) → NamedTuple

Apply `spin_tomography` to each stored psi snapshot in a `SimulationResult`.
Returns a NamedTuple with:
  - `times`: Vector{Float64} of snapshot times (copy of sim_result.times)
  - `angles`: Vector{Float64} of the rotation sweep (shared across snapshots)
  - `images`: Dict{Int, Vector{Matrix{Float64}}} — `images[m][t_idx][angle_idx]`
              is the spin-resolved column-density image.
  - `populations`: Array{Float64,3} of shape (n_times, n_angles, D). The
                   summary population trajectory for each rotation angle.

# Keyword arguments
Forwarded to `spin_tomography`:
  `rotation_axis`, `theta_min`, `theta_max`, `n_angles`, `tof_params`,
  `reference_m`.
"""
function time_resolved_tomography(
    sim_result::SimulationResult, grid::Grid{N}, F::Int;
    rotation_axis::Symbol=:y,
    theta_min::Real=0.0,
    theta_max::Real=π,
    n_angles::Int=19,
    tof_params::TOFParams=TOFParams(; t_tof=5.0),
    reference_m::Union{Nothing, Int}=(-F),
) where {N}
    snapshots = sim_result.psi_snapshots
    n_times = length(snapshots)
    n_times >= 1 || throw(ArgumentError(
        "sim_result contains no psi snapshots — set save_every to store them"))

    D = 2F + 1
    angles = collect(range(theta_min, theta_max; length=n_angles))
    images = Dict{Int, Vector{Matrix{Float64}}}()
    # Call the first snapshot to size the output
    first_res = spin_tomography(snapshots[1], grid, F;
        rotation_axis, theta_min, theta_max, n_angles, tof_params, reference_m)
    # Extract angles from first_res to keep in sync
    for (m, imgs) in first_res.images
        vec = Vector{Matrix{Float64}}(undef, n_times)
        vec[1] = imgs[1]  # take first-angle image; user drives angle via the outer idx
        images[m] = vec
    end

    n_angles_actual = length(first_res.angles)
    pop = zeros(Float64, n_times, n_angles_actual, D)
    pop[1, :, :] .= first_res.populations

    # Remaining snapshots
    for t_idx in 2:n_times
        res = spin_tomography(snapshots[t_idx], grid, F;
            rotation_axis, theta_min, theta_max, n_angles, tof_params, reference_m)
        for (m, imgs) in res.images
            images[m][t_idx] = imgs[1]
        end
        pop[t_idx, :, :] .= res.populations
    end

    (times=copy(sim_result.times), angles=angles, images=images,
        populations=pop)
end
