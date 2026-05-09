# --- P4.11: Topological observables ---
#
# Winding number density (2D), monopole charge (3D), and non-Abelian
# holonomy (Wilson loop) computed from a spinor wavefunction. All three are
# local / path-based analyzers — they do not touch the GP solver and can run

export winding_number_field, monopole_charge_3d, total_monopole_charge
export non_abelian_holonomy
# on any post-ITP or post-dynamics snapshot.
#
# Conventions follow Kawaguchi-Ueda §9 for ferromagnetic vortices and
# §13.4 for nematic-phase textures.

using LinearAlgebra: det

"""
    winding_number_field(psi, grid; component=nothing, threshold=1e-6)
        -> Matrix{Int}

Compute the per-plaquette integer winding number of the phase of a single
component (or of the dominant component at each point). For a (nx, ny, ...)
ψ this returns a matrix of shape (nx-1, ny-1, ...) whose entry (i,j) is the
discrete circulation of ∇(arg ψ) around the (i, i+1, j, j+1) plaquette.
Values ∈ {-1, 0, +1} modulo 2π rounding — rare multi-winding plaquettes are
detected when the rounded sum ≠ 0.

`threshold`: density below which phase is set to zero (avoids phase noise
at vacuum sites). Spatial dims must be ≥ 2.
"""
function winding_number_field(
    psi::AbstractArray{<:Complex}, grid::Grid{N};
    component::Union{Nothing, Int}=nothing,
    threshold::Real=1e-6,
) where {N}
    N >= 2 || throw(ArgumentError("winding_number_field requires N ≥ 2"))
    D = size(psi, N + 1)
    n_pts = grid.config.n_points
    # Pick the phase source: a single component or the one with peak density.
    c = component === nothing ? argmax_component_density(psi, N) :
        clamp(Int(component), 1, D)

    # Output shape:
    # - 2D: one plaquette winding per (i, j) interior cell → (nx-1, ny-1)
    # - 3D: same per-z-slice → (nx-1, ny-1, nz). Only the in-plane axes
    #   shrink; we keep one entry per z so the slab indices line up with
    #   `1:n_pts[3]` in the loop below.
    if N == 2
        winding = zeros(Int, n_pts[1] - 1, n_pts[2] - 1)
        _fill_winding_2d!(winding, psi, c, Float64(threshold))
    elseif N == 3
        winding = zeros(Int, n_pts[1] - 1, n_pts[2] - 1, n_pts[3])
        for k in 1:n_pts[3]
            sub = view(winding,:,:,k)
            psi_xy = view(psi,:,:,k,c)
            _fill_winding_2d_slice!(sub, psi_xy, Float64(threshold))
        end
    else
        throw(ArgumentError("winding_number_field supports N=2 or N=3, got N=$N"))
    end
    winding
end

function _fill_winding_2d!(out::AbstractMatrix{Int}, psi, c::Int, threshold::Float64)
    nx, ny = size(psi, 1), size(psi, 2)
    psi_xy = view(psi,:,:,c)
    _fill_winding_2d_slice!(out, psi_xy, threshold)
end

function _fill_winding_2d_slice!(out, psi_xy, threshold::Float64)
    nx, ny = size(psi_xy)
    @inbounds for j in 1:(ny - 1), i in 1:(nx - 1)
        # Phases at the 4 corners of this plaquette (CCW order)
        ϕ_00 = _masked_phase(psi_xy[i, j], threshold)
        ϕ_10 = _masked_phase(psi_xy[i + 1, j], threshold)
        ϕ_11 = _masked_phase(psi_xy[i + 1, j + 1], threshold)
        ϕ_01 = _masked_phase(psi_xy[i, j + 1], threshold)
        # Circulation = sum of phase differences (wrapped to (-π, π])
        Δ = _wrap(ϕ_10 - ϕ_00) + _wrap(ϕ_11 - ϕ_10) +
            _wrap(ϕ_01 - ϕ_11) + _wrap(ϕ_00 - ϕ_01)
        out[i, j] = round(Int, Δ / (2π))
    end
end

@inline function _masked_phase(z::Complex, threshold::Float64)
    abs(z) < threshold ? 0.0 : atan(imag(z), real(z))
end

@inline function _wrap(Δϕ::Float64)
    x = mod(Δϕ + π, 2π) - π
    x == -π ? π : x   # wrap convention keeps +π
end

"""
    argmax_component_density(psi, ndim) -> Int

Return the index of the component with the largest spatially-integrated
|ψ_c|². Used as a default source for phase-based analyzers.
"""
function argmax_component_density(psi::AbstractArray{<:Complex}, ndim::Int)
    D = size(psi, ndim + 1)
    best = 0.0
    c_best = 1
    for c in 1:D
        idx = _component_slice(ndim, ntuple(d -> size(psi, d), ndim), c)
        s = sum(abs2, view(psi, idx...))
        if s > best
            best = s
            c_best = c
        end
    end
    c_best
end

"""
    monopole_charge_3d(psi, grid; smooth=false) -> Array{Float64,3}

Compute the local monopole (hedgehog) charge density of the spin-texture
`n̂(r) = ⟨F⟩(r) / |⟨F⟩(r)|`. For unit-modulus n̂ the charge is

    q(r) = (1/4π) · n̂ · (∂_y n̂ × ∂_z n̂)

summed over cyclic permutations. Returns a Float64 array sized
`(nx-2, ny-2, nz-2)` — one less grid point per dimension for centred
derivatives.

Integrating `q(r)` over a closed surface gives the total monopole charge.
"""
function monopole_charge_3d(
    psi::AbstractArray{<:Complex}, grid::Grid{3};
    smooth::Bool=false,
)
    n_pts = grid.config.n_points
    # Compute spin expectation values Fx, Fy, Fz at each grid point.
    fx_field, fy_field, fz_field = _spin_expectation_fields(psi, grid)

    # Normalise to unit vectors (where density > threshold)
    nhat_x = similar(fx_field)
    nhat_y = similar(fy_field)
    nhat_z = similar(fz_field)
    @inbounds for i in eachindex(fx_field)
        mag = sqrt(fx_field[i]^2 + fy_field[i]^2 + fz_field[i]^2)
        if mag > 1e-10
            nhat_x[i] = fx_field[i] / mag
            nhat_y[i] = fy_field[i] / mag
            nhat_z[i] = fz_field[i] / mag
        else
            nhat_x[i] = 0.0;
            nhat_y[i] = 0.0;
            nhat_z[i] = 0.0
        end
    end

    nx, ny, nz = n_pts
    dx, dy, dz = grid.dx
    q = zeros(Float64, nx-2, ny-2, nz-2)
    inv4π = 1.0 / (4π)
    @inbounds for k in 2:(nz - 1), j in 2:(ny - 1), i in 2:(nx - 1)
        # Centred differences for the three partials
        ∂x_nx = (nhat_x[i + 1, j, k] - nhat_x[i - 1, j, k]) / (2dx)
        ∂x_ny = (nhat_y[i + 1, j, k] - nhat_y[i - 1, j, k]) / (2dx)
        ∂x_nz = (nhat_z[i + 1, j, k] - nhat_z[i - 1, j, k]) / (2dx)
        ∂y_nx = (nhat_x[i, j + 1, k] - nhat_x[i, j - 1, k]) / (2dy)
        ∂y_ny = (nhat_y[i, j + 1, k] - nhat_y[i, j - 1, k]) / (2dy)
        ∂y_nz = (nhat_z[i, j + 1, k] - nhat_z[i, j - 1, k]) / (2dy)
        ∂z_nx = (nhat_x[i, j, k + 1] - nhat_x[i, j, k - 1]) / (2dz)
        ∂z_ny = (nhat_y[i, j, k + 1] - nhat_y[i, j, k - 1]) / (2dz)
        ∂z_nz = (nhat_z[i, j, k + 1] - nhat_z[i, j, k - 1]) / (2dz)
        # Cross product ∂_y n̂ × ∂_z n̂
        cx = ∂y_ny * ∂z_nz - ∂y_nz * ∂z_ny
        cy = ∂y_nz * ∂z_nx - ∂y_nx * ∂z_nz
        cz = ∂y_nx * ∂z_ny - ∂y_ny * ∂z_nx
        # n̂ · (cross) — pointwise
        q[i - 1, j - 1, k - 1] =
            inv4π * (nhat_x[i, j, k] * cx +
                     nhat_y[i, j, k] * cy +
                     nhat_z[i, j, k] * cz)
    end

    if smooth
        # Simple 3x3x3 box smoothing to reduce grid noise
        q = _box_smooth_3d(q)
    end
    q
end

"""
    total_monopole_charge(q_field, grid) -> Float64

Volume-integrate the monopole-charge density from `monopole_charge_3d`.
"""
function total_monopole_charge(q::Array{Float64, 3}, grid::Grid{3})
    dV = cell_volume(grid)
    sum(q) * dV
end

"""
    non_abelian_holonomy(psi, grid, loop_pts; component=nothing) -> ComplexF64

Wilson-loop-style holonomy around a user-specified closed path. `loop_pts`
is a `Vector{NTuple{N,Int}}` of grid-index points traversed in order
(matching the spatial dimensionality of `grid`), and the loop must close
(first == last). For a scalar / dominant-component phase field this
returns `exp(i·∮∇ϕ·dl) = exp(i·2π·winding)`, so it's a convenient smoke
test of integer winding along an arbitrary 2D or 3D loop — but it also
captures non-trivial U(1) × U(1) × … rotations when used over the full
spinor.

For full non-Abelian structure, extend this with the Bloch-basis transformation
at each grid point — left as a Phase 4.11+ follow-up.
"""
function non_abelian_holonomy(
    psi::AbstractArray{<:Complex}, grid::Grid{N},
    loop_pts::AbstractVector{<:NTuple};
    component::Union{Nothing, Int}=nothing,
) where {N}
    N >= 2 || throw(ArgumentError("non_abelian_holonomy requires N ≥ 2"))
    length(loop_pts) >= 2 || throw(ArgumentError("loop_pts needs ≥ 2 entries"))
    isempty(loop_pts) || length(loop_pts[1]) == N ||
        throw(ArgumentError(
            "loop_pts entry length $(length(loop_pts[1])) ≠ grid N=$N"))
    loop_pts[1] == loop_pts[end] || @warn "non_abelian_holonomy: loop is not closed"

    c = if component === nothing
        argmax_component_density(psi, N)
    else
        clamp(Int(component), 1, size(psi, N+1))
    end
    phase_acc = 0.0
    for k in 2:length(loop_pts)
        ψ0 = psi[loop_pts[k - 1]..., c]
        ψ1 = psi[loop_pts[k]..., c]
        # Parallel transport: exp(iϕ_1)·exp(-iϕ_0) factor
        abs(ψ0) < 1e-12 && continue
        phase_acc += _wrap(atan(imag(ψ1), real(ψ1)) - atan(imag(ψ0), real(ψ0)))
    end
    cis(phase_acc)
end

# --- Helpers ---

"""Compute ⟨F_α⟩(r) arrays. Thin wrapper dispatching via SpinMatrices."""
function _spin_expectation_fields(psi::AbstractArray{<:Complex}, grid::Grid{N}) where {N}
    D = size(psi, N + 1)
    F = (D - 1) ÷ 2
    sm = spin_matrices(F)
    n_pts = grid.config.n_points
    fx = zeros(Float64, n_pts)
    fy = zeros(Float64, n_pts)
    fz = zeros(Float64, n_pts)
    @inbounds for I in CartesianIndices(n_pts)
        spinor = _get_spinor_any(psi, I, D)
        fx[I] = real(_braket(spinor, sm.Fx))
        fy[I] = real(_braket(spinor, sm.Fy))
        fz[I] = real(_braket(spinor, sm.Fz))
    end
    fx, fy, fz
end

@inline function _get_spinor_any(psi, I::CartesianIndex, D::Int)
    ntuple(c -> psi[I, c], D)
end

@inline function _braket(spinor::NTuple{D, <:Complex}, Fop) where {D}
    # ⟨ψ|Fop|ψ⟩
    acc = zero(ComplexF64)
    for i in 1:D, j in 1:D
        acc += conj(spinor[i]) * Fop[i, j] * spinor[j]
    end
    acc
end

function _box_smooth_3d(q::Array{Float64, 3})
    nx, ny, nz = size(q)
    out = zeros(Float64, nx, ny, nz)
    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        s = 0.0;
        n = 0
        for dk in -1:1, dj in -1:1, di in -1:1
            ii = clamp(i+di, 1, nx);
            jj = clamp(j+dj, 1, ny);
            kk = clamp(k+dk, 1, nz)
            s += q[ii, jj, kk]
            n += 1
        end
        out[i, j, k] = s / n
    end
    out
end
