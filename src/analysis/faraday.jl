# --- Faraday Rotation Imaging ---
#
# Simulates dispersive Faraday rotation imaging of a spinor BEC.
#
# Physics: A linearly polarized probe beam propagating along axis z acquires
# a local Faraday rotation angle proportional to the column-integrated spin
# density ∫F_z dz (for propagation along z). At large detuning Δ from the
# D1 transition, the rotation angle per atom is:
#
#   φ(x,y) = σ₀ × g_F × Γ/(4Δ) × ∫ F_z(x,y,z) n(x,y,z) dz
#
# where σ₀ = 3λ²/(2π) is the resonant cross section, Γ is the natural
# linewidth, and Δ is the detuning.
#
# For vortex detection: phase singularities in the spinor manifest as
# zeros in the local Faraday signal where the spin texture winds around
# the vortex core.
#
# Reference:
#   Bradley et al., PRA 72, 053602 (2005)
#   Higbie et al., PRL 95, 050401 (2005)

"""
    FaradayParams

Parameters for Faraday rotation imaging simulation.

# Fields
- `probe_axis::Int`: propagation axis of probe beam (1=x, 2=y, 3=z)
- `detuning::Float64`: probe detuning Δ/Γ in units of natural linewidth
- `polarization::Symbol`: `:linear_x`, `:linear_y`, or `:circular`
- `include_vector_shift::Bool`: include tensor light shift (2nd order)
"""
struct FaradayParams
    probe_axis::Int
    detuning::Float64       # Δ/Γ (dimensionless ratio)
    polarization::Symbol
    include_vector_shift::Bool

    function FaradayParams(;
        probe_axis::Int=3,
        detuning::Float64=-320.0 / 5.0,   # -320 MHz / Γ≈5MHz for Eu
        polarization::Symbol=:linear_x,
        include_vector_shift::Bool=false,
    )
        1 <= probe_axis <= 3 || throw(ArgumentError("probe_axis must be 1, 2, or 3"))
        abs(detuning) > 1 || throw(ArgumentError("detuning must be >> Γ for dispersive regime"))
        new(probe_axis, detuning, polarization, include_vector_shift)
    end
end

"""
    faraday_image(psi, grid, F; params=FaradayParams()) → NamedTuple

Compute the Faraday rotation image of the spinor BEC.

Returns a NamedTuple with:
- `rotation_angle`: 2D array of Faraday rotation φ(x,y) [rad]
- `column_Fz`: 2D array of column-integrated local spin density ∫⟨F_z⟩·n dz
- `column_density`: 2D total column density ∫n dz
- `contrast`: normalized Faraday contrast φ/max(|φ|)
- `vortex_signal`: regions where |φ| < threshold (potential vortex cores)
"""
function faraday_image(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    F::Int;
    params::FaradayParams=FaradayParams(),
) where {N}
    N >= 2 || throw(ArgumentError("Faraday imaging requires at least 2D"))
    sm = spin_matrices(F)
    ndim = N
    ax = params.probe_axis
    ax <= N || throw(ArgumentError("probe_axis=$ax exceeds grid dimension $N"))

    # Local spin density f_α(r) = ⟨ψ|F_α|ψ⟩ = ⟨F_α⟩_local · n(r) — i.e. the
    # density-WEIGHTED expectation already. The Faraday formula
    # φ ∝ ∫⟨F_z⟩·n dz that the docstring quotes equals ∫f_z dz directly;
    # multiplying by `n_total` again would give ∫⟨F_z⟩·n² dz (off by one
    # factor of n, fixed 2026-05-02).
    Fz = spin_density_vector(psi, sm, ndim)
    n_total = total_density(psi, ndim)

    # Column-integrated quantities along probe axis
    dz = grid.dx[ax]
    if N == 3
        col_Fz = dropdims(sum(Fz[ax]; dims=ax); dims=ax) .* dz
        col_n = dropdims(sum(n_total; dims=ax); dims=ax) .* dz
    elseif N == 2
        # 2D: no integration along probe axis (treat as already column-integrated).
        col_Fz = copy(Fz[ax])
        col_n = copy(n_total)
    else
        throw(ArgumentError("unsupported dimension"))
    end

    # Faraday rotation angle: φ = σ₀ × g_F × Γ/(4Δ) × ∫F_z n dz
    # In dimensionless units, we absorb σ₀×Γ into a prefactor.
    # The physically meaningful quantity is the relative angle pattern.
    prefactor = 1.0 / (4.0 * params.detuning)
    rotation_angle = prefactor .* col_Fz

    # Contrast: normalized between [-1, 1]
    max_phi = maximum(abs, rotation_angle)
    contrast = max_phi > 0 ? rotation_angle ./ max_phi : zero(rotation_angle)

    # Vortex signal: where Faraday angle crosses zero with nonzero density
    # (phase singularity in spin texture)
    density_threshold = 0.01 * maximum(col_n)
    vortex_signal = (abs.(rotation_angle) .< 0.1 * max_phi) .& (col_n .> density_threshold)

    (
        rotation_angle=rotation_angle,
        column_Fz=col_Fz,
        column_density=col_n,
        contrast=contrast,
        vortex_signal=vortex_signal,
        params=params,
    )
end

"""
    faraday_differential(psi, psi_ref, grid, F; params=FaradayParams()) → NamedTuple

Compute differential Faraday image: subtract a reference (e.g. fully polarized)
to highlight spin texture changes. Useful for detecting weak signals on top
of a uniform background.

Returns same fields as `faraday_image` plus `differential` (φ - φ_ref).
"""
function faraday_differential(
    psi::AbstractArray{<:Complex},
    psi_ref::AbstractArray{<:Complex},
    grid::Grid{N},
    F::Int;
    params::FaradayParams=FaradayParams(),
) where {N}
    img = faraday_image(psi, grid, F; params)
    ref = faraday_image(psi_ref, grid, F; params)
    differential = img.rotation_angle .- ref.rotation_angle

    (
        rotation_angle=img.rotation_angle,
        column_Fz=img.column_Fz,
        column_density=img.column_density,
        contrast=img.contrast,
        vortex_signal=img.vortex_signal,
        differential=differential,
        params=params,
    )
end

"""
    detect_vortices_faraday(psi, grid, F; params=FaradayParams(), threshold=0.1) → Vector{Tuple}

Detect potential vortex positions from zero-crossings of the Faraday signal.
Returns a list of (x_index, y_index) positions where vortex cores are likely.
"""
function detect_vortices_faraday(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    F::Int;
    params::FaradayParams=FaradayParams(),
    threshold::Float64=0.1,
) where {N}
    img = faraday_image(psi, grid, F; params)
    max_phi = maximum(abs, img.rotation_angle)
    max_phi < 1e-15 && return Tuple{Int, Int}[]

    density_threshold = 0.01 * maximum(img.column_density)
    vortex_positions = Tuple{Int, Int}[]

    phi = img.rotation_angle
    nx, ny = size(phi)
    for j in 2:(ny - 1), i in 2:(nx - 1)
        img.column_density[i, j] < density_threshold && continue
        abs(phi[i, j]) > threshold * max_phi && continue

        # Check if surrounded by opposite signs (zero-crossing)
        neighbors = (phi[i - 1, j], phi[i + 1, j], phi[i, j - 1], phi[i, j + 1])
        has_pos = any(>(0), neighbors)
        has_neg = any(<(0), neighbors)
        if has_pos && has_neg
            push!(vortex_positions, (i, j))
        end
    end
    vortex_positions
end
