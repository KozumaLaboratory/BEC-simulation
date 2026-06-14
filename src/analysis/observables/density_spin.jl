# --- Density + spin density observables ---
#
# Single-point real-space observables: total/component density, norm,
# magnetization, local spin density vector. The expensive O(D²) spin
# density is reduced to O(D) by exploiting the tridiagonal sparsity of
# F_x/F_y and the diagonal F_z structure.

export total_density, component_density, total_norm, magnetization
export spin_density_vector
export population_inside_radius

function total_density(psi::AbstractArray{<:Complex}, ndim::Int)
    n_comp = size(psi, ndim + 1)
    n_pts = ntuple(d -> size(psi, d), ndim)
    _total_density(psi, n_comp, ndim, n_pts)
end

function component_density(psi::AbstractArray{<:Complex}, ndim::Int, c::Int)
    n_pts = ntuple(d -> size(psi, d), ndim)
    idx = _component_slice(ndim, n_pts, c)
    abs2.(view(psi, idx...))
end

function total_norm(psi::AbstractArray{<:Complex}, grid::Grid{N}) where {N}
    # ∫|ψ|² dV — sum |ψ|² across all components and spatial cells, no
    # need to materialise the per-cell density first.
    sum(abs2, psi) * cell_volume(grid)
end

"""
Split the norm into the part inside a region `r ≤ radius` and the part
that has spilled outside it. `r` is the Euclidean distance from `center`
(default the grid origin) using the real-space axes in `grid.x`.

Returns `(inside, outside, total, outside_fraction)` where each of the
first three is `∫|ψ|² dV` over the respective region. Particles absorbed
or lost are already gone from `ψ`; this only measures what remains — pair
it across the time series to quantify what leaked toward the boundary.
"""
function population_inside_radius(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    radius::Real;
    center::NTuple{N, <:Real}=ntuple(_ -> 0.0, Val(N)),
) where {N}
    dV = cell_volume(grid)
    r2_max = Float64(radius)^2
    axes_sq = ntuple(d -> (grid.x[d] .- center[d]) .^ 2, Val(N))
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)

    inside = 0.0
    total = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        r2 = 0.0
        for d in 1:N
            r2 += axes_sq[d][I[d]]
        end
        cell = 0.0
        for c in 1:n_comp
            cell += abs2(psi[I, c])
        end
        total += cell
        r2 <= r2_max && (inside += cell)
    end

    inside *= dV
    total *= dV
    outside = total - inside
    frac = total > 0 ? outside / total : 0.0
    (inside=inside, outside=outside, total=total, outside_fraction=frac)
end

"""
Magnetization ⟨Fz⟩ = Σ_m m |ψ_m|² integrated over space.
"""
function magnetization(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    sys::SpinSystem,
) where {N}
    dV = cell_volume(grid)
    Mz = 0.0
    n_pts = ntuple(d -> size(psi, d), Val(N))
    for (c, m) in enumerate(sys.m_values)
        idx = _component_slice(N, n_pts, c)
        Mz += m * sum(abs2, view(psi, idx...)) * dV
    end
    Mz
end

"""
Local spin density vector (Fx, Fy, Fz) at each spatial point.
Returns a tuple of 3 arrays.
"""
function spin_density_vector(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    ndim::Int,
) where {D}
    n_pts = ntuple(d -> size(psi, d), ndim)

    fx = zeros(Float64, n_pts)
    fy = zeros(Float64, n_pts)
    fz = zeros(Float64, n_pts)

    _compute_spin_density!(fx, fy, fz, psi, sm, Val(D), ndim, n_pts)

    (fx, fy, fz)
end

"""
Exploit spin matrix sparsity: Fz is diagonal, Fx/Fy are tridiagonal.

    Fz: ⟨ψ|Fz|ψ⟩ = Σ_c m_c |ψ_c|²
    Fx + iFy = ⟨ψ|F+|ψ⟩ = Σ_{c=2}^D f+(m_c) ψ*_{c-1} ψ_c

O(D) per point instead of O(D²).
"""
function _compute_spin_density!(fx, fy, fz, psi, sm, n_comp::Int, ndim, n_pts)
    _compute_spin_density!(fx, fy, fz, psi, sm, Val(n_comp), ndim, n_pts)
end

function _compute_spin_density!(fx, fy, fz, psi::Array, sm, ::Val{D}, ndim, n_pts) where {D}
    F = sm.system.F
    Ff1 = Float64(F * (F + 1))
    m_vals = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp_coeffs = ntuple(c -> c == 1 ? 0.0 : sqrt(Ff1 - m_vals[c] * (m_vals[c] + 1.0)), Val(D))

    Threads.@threads for I in CartesianIndices(n_pts)
        @inbounds begin
            fz_val = 0.0
            for c in 1:D
                fz_val += m_vals[c] * abs2(psi[I, c])
            end
            fz[I] = fz_val

            fxy_re = 0.0
            fxy_im = 0.0
            for c in 2:D
                prod = conj(psi[I, c - 1]) * psi[I, c]
                fxy_re += fp_coeffs[c] * real(prod)
                fxy_im += fp_coeffs[c] * imag(prod)
            end
            fx[I] = fxy_re
            fy[I] = fxy_im
        end
    end
end

function _compute_spin_density!(fx, fy, fz, psi::AbstractArray, sm, ::Val{D}, ndim, n_pts) where {D}
    F = sm.system.F
    Ff1 = Float64(F * (F + 1))
    m_vals = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp_coeffs = ntuple(c -> c == 1 ? 0.0 : sqrt(Ff1 - m_vals[c] * (m_vals[c] + 1.0)), Val(D))

    spatial_idx = ntuple(d -> 1:n_pts[d], ndim)
    fz_v = view(fz, spatial_idx...)
    fx_v = view(fx, spatial_idx...)
    fy_v = view(fy, spatial_idx...)

    psi1 = view(psi, _component_slice(ndim, n_pts, 1)...)
    @. fz_v = m_vals[1] * abs2(psi1)
    for c in 2:D
        psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
        @. fz_v += m_vals[c] * abs2(psi_c)
    end

    psi_p = view(psi, _component_slice(ndim, n_pts, 1)...)
    psi_c = view(psi, _component_slice(ndim, n_pts, 2)...)
    @. fx_v = fp_coeffs[2] * (real(psi_p) * real(psi_c) + imag(psi_p) * imag(psi_c))
    @. fy_v = fp_coeffs[2] * (real(psi_p) * imag(psi_c) - imag(psi_p) * real(psi_c))
    for c in 3:D
        psi_p = view(psi, _component_slice(ndim, n_pts, c - 1)...)
        psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
        @. fx_v += fp_coeffs[c] * (real(psi_p) * real(psi_c) + imag(psi_p) * imag(psi_c))
        @. fy_v += fp_coeffs[c] * (real(psi_p) * imag(psi_c) - imag(psi_p) * real(psi_c))
    end
end
