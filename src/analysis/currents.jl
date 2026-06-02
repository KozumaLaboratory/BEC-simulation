export probability_current, orbital_angular_momentum, superfluid_velocity
export total_angular_momentum, spin_texture_charge, circulation

"""
Probability current density j(r) = Σ_c Im(ψ_c* ∇ψ_c).
Returns NTuple{N, Array{Float64,N}} of current components.
"""
function probability_current(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    plans::FFTPlans,
) where {N}
    n_comp = size(psi, N + 1)
    n_pts = ntuple(d -> size(psi, d), N)

    j = ntuple(_ -> zeros(Float64, n_pts), N)
    psi_k = zeros(ComplexF64, n_pts)
    dpsi = zeros(ComplexF64, n_pts)

    for c in 1:n_comp
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)

        psi_k .= psi_c
        plans.forward * psi_k

        for d in 1:N
            @inbounds for I in CartesianIndices(n_pts)
                dpsi[I] = im * grid.k[d][I[d]] * psi_k[I]
            end
            plans.inverse * dpsi
            @inbounds for I in CartesianIndices(n_pts)
                j[d][I] += imag(conj(psi_c[I]) * dpsi[I])
            end
        end
    end

    j
end

"""
Orbital angular momentum ⟨Lz⟩ = ∫ Σ_c ψ_c* (-i)(x ∂_y - y ∂_x) ψ_c d^N r.
Returns 0.0 for 1D grids.
"""
function orbital_angular_momentum(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    plans::FFTPlans,
) where {N}
    N >= 2 || return 0.0

    n_comp = size(psi, N + 1)
    n_pts = ntuple(d -> size(psi, d), N)
    dV = cell_volume(grid)

    psi_k = zeros(ComplexF64, n_pts)
    dpsi_x = zeros(ComplexF64, n_pts)
    dpsi_y = zeros(ComplexF64, n_pts)

    # psi_k is always a CPU Array (from `zeros`); ensure plans match the
    # CPU array, not whatever backend `plans` was originally created for.
    # When called with `ws.fft_plans` from a GPU workspace, those are
    # CUFFT plans and applying them to a CPU array triggers massive
    # implicit transfers (saw 30 GB RSS spike at 24³ × D=13 before fix).
    local_plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)

    Lz = 0.0

    for c in 1:n_comp
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)

        psi_k .= psi_c
        local_plans.forward * psi_k

        @inbounds for I in CartesianIndices(n_pts)
            dpsi_x[I] = im * grid.k[1][I[1]] * psi_k[I]
            dpsi_y[I] = im * grid.k[2][I[2]] * psi_k[I]
        end
        local_plans.inverse * dpsi_x
        local_plans.inverse * dpsi_y

        @inbounds for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            Lz += real(conj(psi_c[I]) * (-im) * (x * dpsi_y[I] - y * dpsi_x[I])) * dV
        end
    end

    Lz
end

"""
Superfluid velocity v_d = j_d / n at each spatial point.
Returns `NTuple{N, Array{Float64,N}}`.
Points with density below `density_cutoff` are set to zero.
"""
function superfluid_velocity(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    plans::FFTPlans;
    density_cutoff::Float64=1e-10,
) where {N}
    j = probability_current(psi, grid, plans)
    n = total_density(psi, N)
    n_pts = ntuple(d -> size(psi, d), N)

    v = ntuple(_ -> zeros(Float64, n_pts), N)
    @inbounds for I in CartesianIndices(n_pts)
        if n[I] > density_cutoff
            inv_n = 1.0 / n[I]
            for d in 1:N
                v[d][I] = j[d][I] * inv_n
            end
        end
    end
    v
end

"""
Total angular momentum J_z = L_z + S_z.
L_z = `orbital_angular_momentum`, S_z = `magnetization`.
"""
function total_angular_momentum(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    plans::FFTPlans,
    sys::SpinSystem,
) where {N}
    Lz = orbital_angular_momentum(psi, grid, plans)
    Sz = magnetization(psi, grid, sys)
    Lz + Sz
end

# 2D bilinear interpolation of a vector field at a single point.
# Periodic wrap consistent with FFT-based grid.
@inline function _interp_velocity(
    v::NTuple{2, Array{Float64, 2}},
    grid::Grid{2},
    p::NTuple{2, Float64},
)
    nx, ny = grid.config.n_points
    tx = (p[1] - grid.x[1][1]) / grid.dx[1]
    ty = (p[2] - grid.x[2][1]) / grid.dx[2]
    ix = floor(Int, tx)
    iy = floor(Int, ty)
    fx = tx - ix
    fy = ty - iy
    ix0 = mod(ix, nx) + 1
    ix1 = mod(ix + 1, nx) + 1
    iy0 = mod(iy, ny) + 1
    iy1 = mod(iy + 1, ny) + 1
    w00 = (1 - fx) * (1 - fy)
    w10 = fx * (1 - fy)
    w01 = (1 - fx) * fy
    w11 = fx * fy
    @inbounds begin
        vx =
            w00 * v[1][ix0, iy0] +
            w10 * v[1][ix1, iy0] +
            w01 * v[1][ix0, iy1] +
            w11 * v[1][ix1, iy1]
        vy =
            w00 * v[2][ix0, iy0] +
            w10 * v[2][ix1, iy0] +
            w01 * v[2][ix0, iy1] +
            w11 * v[2][ix1, iy1]
    end
    (vx, vy)
end

# 3D trilinear interpolation.
@inline function _interp_velocity(
    v::NTuple{3, Array{Float64, 3}},
    grid::Grid{3},
    p::NTuple{3, Float64},
)
    nx, ny, nz = grid.config.n_points
    tx = (p[1] - grid.x[1][1]) / grid.dx[1]
    ty = (p[2] - grid.x[2][1]) / grid.dx[2]
    tz = (p[3] - grid.x[3][1]) / grid.dx[3]
    ix = floor(Int, tx)
    iy = floor(Int, ty)
    iz = floor(Int, tz)
    fx = tx - ix
    fy = ty - iy
    fz = tz - iz
    ix0 = mod(ix, nx) + 1
    ix1 = mod(ix + 1, nx) + 1
    iy0 = mod(iy, ny) + 1
    iy1 = mod(iy + 1, ny) + 1
    iz0 = mod(iz, nz) + 1
    iz1 = mod(iz + 1, nz) + 1
    w000 = (1 - fx) * (1 - fy) * (1 - fz)
    w100 = fx * (1 - fy) * (1 - fz)
    w010 = (1 - fx) * fy * (1 - fz)
    w110 = fx * fy * (1 - fz)
    w001 = (1 - fx) * (1 - fy) * fz
    w101 = fx * (1 - fy) * fz
    w011 = (1 - fx) * fy * fz
    w111 = fx * fy * fz
    @inbounds begin
        vx =
            w000 * v[1][ix0, iy0, iz0] +
            w100 * v[1][ix1, iy0, iz0] +
            w010 * v[1][ix0, iy1, iz0] +
            w110 * v[1][ix1, iy1, iz0] +
            w001 * v[1][ix0, iy0, iz1] +
            w101 * v[1][ix1, iy0, iz1] +
            w011 * v[1][ix0, iy1, iz1] +
            w111 * v[1][ix1, iy1, iz1]
        vy =
            w000 * v[2][ix0, iy0, iz0] +
            w100 * v[2][ix1, iy0, iz0] +
            w010 * v[2][ix0, iy1, iz0] +
            w110 * v[2][ix1, iy1, iz0] +
            w001 * v[2][ix0, iy0, iz1] +
            w101 * v[2][ix1, iy0, iz1] +
            w011 * v[2][ix0, iy1, iz1] +
            w111 * v[2][ix1, iy1, iz1]
        vz =
            w000 * v[3][ix0, iy0, iz0] +
            w100 * v[3][ix1, iy0, iz0] +
            w010 * v[3][ix0, iy1, iz0] +
            w110 * v[3][ix1, iy1, iz0] +
            w001 * v[3][ix0, iy0, iz1] +
            w101 * v[3][ix1, iy0, iz1] +
            w011 * v[3][ix0, iy1, iz1] +
            w111 * v[3][ix1, iy1, iz1]
    end
    (vx, vy, vz)
end

"""
    circulation(v, grid, loop) -> Float64

Line integral Γ = ∮ v · dl around a closed polyline. The last vertex connects
back to the first. Uses midpoint-rule integration with linear interpolation
of `v` at each segment midpoint; coordinates outside the grid wrap
periodically (consistent with FFT-based derivatives).

In units where ℏ=m=1, a quantum vortex enclosed by the loop gives
`Γ = 2π · w` where w ∈ ℤ is the winding number. The loop orientation
determines the sign.

Supported dimensions: N ∈ {2, 3}.
"""
function circulation(
    v::NTuple{N, Array{Float64, N}},
    grid::Grid{N},
    loop::AbstractVector{<:NTuple{N, <:Real}},
) where {N}
    N == 2 || N == 3 || throw(ArgumentError("circulation requires N ∈ {2,3}"))
    np = length(loop)
    np >= 3 || throw(ArgumentError("loop must have at least 3 vertices"))

    Γ = 0.0
    @inbounds for i in 1:np
        j = (i == np) ? 1 : i + 1
        p1 = ntuple(d -> Float64(loop[i][d]), N)
        p2 = ntuple(d -> Float64(loop[j][d]), N)
        mid = ntuple(d -> 0.5 * (p1[d] + p2[d]), N)
        vmid = _interp_velocity(v, grid, mid)
        for d in 1:N
            Γ += vmid[d] * (p2[d] - p1[d])
        end
    end
    Γ
end
