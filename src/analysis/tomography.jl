# --- Synthetic Spin Tomography ---
#
# Simulates the experimental spin tomography protocol:
#   1. Rotate the spinor by angle θ around axis n̂ (= change quantization axis)
#   2. Apply TOF expansion (far-field approximation)
#   3. Apply Stern-Gerlach separation
#   4. Column-integrate to get the 2D image for each m_F
#
# By sweeping θ, we reconstruct the full spin state — identical to
# what the experiment does. This is the "bridge" between simulation
# wavefunctions and experimental SG images.

"""
    spin_tomography(psi, grid, F; kwargs...) → TomographyResult

Compute synthetic spin tomography images for a given spinor wavefunction.

Sweeps the spin rotation angle `θ` from `theta_min` to `theta_max` in
`n_angles` steps around the specified `rotation_axis` (:x, :y, or :z),
applies TOF+SG at each angle, and returns the resulting image stack.

# Arguments
- `psi`: spinor wavefunction array [x, y, z, component]
- `grid`: spatial grid
- `F`: total spin quantum number

# Keyword Arguments
- `rotation_axis::Symbol = :y`: axis to rotate around
- `theta_min::Float64 = 0.0`: starting angle (rad)
- `theta_max::Float64 = π`: ending angle (rad)
- `n_angles::Int = 19`: number of angles (0° to 180° in 10° steps)
- `tof_params::TOFParams`: TOF + SG parameters
- `reference_m::Int = -F`: reference component for subtraction (or nothing)

# Returns
`NamedTuple` with fields:
- `angles`: Vector{Float64} of rotation angles
- `images`: Dict{Int, Vector{Matrix{Float64}}} — `images[m][i]` = 2D density of
  component m at angle i
- `populations`: Matrix{Float64} — `populations[i, c]` = integrated population of
  component c at angle i
- `differential`: Dict{Int, Vector{Matrix{Float64}}} — difference images relative
  to the reference component (if `reference_m` given)
"""
function spin_tomography(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    F::Int;
    rotation_axis::Symbol=:y,
    theta_min::Float64=0.0,
    theta_max::Float64=Float64(π),
    n_angles::Int=19,
    tof_params::TOFParams=TOFParams(11.0, 0.0, 3),  # 16ms TOF, no SG, axis 3
    reference_m::Union{Nothing, Int}=nothing,
) where {N}
    D = 2F + 1
    sys = SpinSystem(F)
    angles = collect(range(theta_min, theta_max; length=n_angles))

    images = Dict{Int, Vector{Array{Float64}}}(m => Array{Float64}[] for m in sys.m_values)
    populations = zeros(Float64, n_angles, D)

    for (i, theta) in enumerate(angles)
        # Rotate spinor
        psi_rot = if abs(theta) < 1e-15
            psi
        else
            tx, ty, tz = _rotation_angles(rotation_axis, theta)
            rotate_quantization_axis(psi, F, tx, ty, tz)
        end

        # TOF + SG imaging
        tof_images = simulate_tof(psi_rot, grid, sys, tof_params)

        # Store images and populations
        for (c, m) in enumerate(sys.m_values)
            img = get(tof_images, m, nothing)
            if img !== nothing
                push!(images[m], img)
                populations[i, c] = sum(img)
            end
        end
    end

    # Normalize populations (each row sums to 1)
    for i in 1:n_angles
        row_sum = sum(populations[i, :])
        if row_sum > 0
            populations[i, :] ./= row_sum
        end
    end

    # Differential images: subtract scaled reference
    differential = if reference_m !== nothing
        ref_idx = findfirst(==(reference_m), sys.m_values)
        ref_idx === nothing && throw(ArgumentError("reference_m=$reference_m not in m_values"))
        _compute_differential(images, populations, sys.m_values, ref_idx)
    else
        nothing
    end

    (
        angles=angles,
        images=images,
        populations=populations,
        differential=differential,
        F=F,
        rotation_axis=rotation_axis,
        tof_params=tof_params,
    )
end

"""
    _rotation_angles(axis, theta) → (tx, ty, tz)

Convert a rotation around a named axis to Euler angles for spin_rotation_matrix.
"""
function _rotation_angles(axis::Symbol, theta::Float64)
    axis == :x && return (theta, 0.0, 0.0)
    axis == :y && return (0.0, theta, 0.0)
    axis == :z && return (0.0, 0.0, theta)
    throw(ArgumentError("Unknown rotation axis: $axis. Use :x, :y, or :z"))
end

"""
    _compute_differential(images, populations, m_values, ref_idx)

Compute difference images: Δρ_m(r; θ) = ρ_m(r; θ) - C(θ) × ρ_ref(r; 0)
where C(θ) is the population ratio normalizing the reference.
"""
function _compute_differential(images, populations, m_values, ref_idx)
    ref_m = m_values[ref_idx]
    ref_images = images[ref_m]
    isempty(ref_images) && return nothing

    ref_img_0 = ref_images[1]  # reference at θ=0

    diff = Dict{Int, Vector{Array{Float64}}}()
    for (c, m) in enumerate(m_values)
        diff[m] = Array{Float64}[]
        for i in eachindex(images[m])
            C_theta = populations[i, ref_idx]
            delta = images[m][i] .- C_theta .* ref_img_0
            push!(diff[m], delta)
        end
    end
    diff
end

"""
    tomography_sinogram(tomo_result, m::Int) → Matrix{Float64}

Extract the sinogram (angle × position) for component `m` from a
tomography result. For 2D images, takes the central row.
"""
function tomography_sinogram(tomo_result, m::Int)
    imgs = tomo_result.images[m]
    n_angles = length(imgs)
    n_pixels = if ndims(imgs[1]) == 1
        length(imgs[1])
    else
        size(imgs[1], 1)  # take first spatial dimension
    end

    sino = zeros(Float64, n_angles, n_pixels)
    for (i, img) in enumerate(imgs)
        if ndims(img) == 1
            sino[i, :] = img
        else
            mid = size(img, 2) ÷ 2 + 1
            sino[i, :] = img[:, mid]
        end
    end
    sino
end
