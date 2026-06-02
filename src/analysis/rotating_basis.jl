# --- Option γ post-evolution analysis: per-m norms, total density, Lz, coord buffers ---

function evolve_rotating!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    t0::T=zero(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    t = t0
    for step in 1:n_steps
        split_step_rotating!(ws, dt, t)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

"""Per-component density (for diagnostics). GPU-safe via sum(abs2, slab)."""
function rotating_per_m_norms(ws::RotatingBasisWS{T, N, D}) where {T, N, D}
    dV = prod(ws.grid.dx)
    norms = zeros(T, D)
    @inbounds for m_idx in 1:D
        slab = selectdim(ws.psi_tilde, N + 1, m_idx)
        norms[m_idx] = T(sum(abs2, slab)) * dV
    end
    norms
end

"""Total density (summed across all m components)."""
function rotating_total_density(ws::RotatingBasisWS{T, N, D}) where {T, N, D}
    # Build on device, then return host array (CPU) for downstream analyzers.
    rho_dev = _zeros(ws.backend, T, ws.grid.config.n_points...)
    @inbounds for m_idx in 1:D
        slab = selectdim(ws.psi_tilde, N + 1, m_idx)
        @. rho_dev += abs2(slab)
    end
    Array(rho_dev)
end

"""z-component of orbital angular momentum L_z = -i ⟨ψ̃|x∂_y - y∂_x|ψ̃⟩.
Computed in tilde basis; equals lab-frame L_z because Û_B is spin-only and
∂_x, ∂_y commute with spin rotations.
3D only."""
function rotating_Lz(ws::RotatingBasisWS{T, 3, D}) where {T, D}
    n_pts = ws.grid.config.n_points
    Nx, Ny, Nz = n_pts
    # Lift coordinate / wavenumber 1D arrays to the device. Cached so
    # repeated calls don't copy.
    kx_dev = _coord_buffer(ws, :kx, ws.grid.k[1])
    ky_dev = _coord_buffer(ws, :ky, ws.grid.k[2])
    x_dev = _coord_buffer(ws, :x, ws.grid.x[1])
    y_dev = _coord_buffer(ws, :y, ws.grid.x[2])
    # Reshape for broadcast: (Nx,) → (Nx,1,1); (Ny,) → (1,Ny,1)
    kx_b = reshape(kx_dev, Nx, 1, 1)
    ky_b = reshape(ky_dev, 1, Ny, 1)
    x_b = reshape(x_dev, Nx, 1, 1)
    y_b = reshape(y_dev, 1, Ny, 1)

    Lz = zero(Complex{T})
    dpsi_dy = _zeros(ws.backend, Complex{T}, n_pts...)
    @inbounds for m_idx in 1:D
        copyto!(ws.spatial_buf, selectdim(ws.psi_tilde, 4, m_idx))
        ws.fft_fwd * ws.spatial_buf
        # ∂_y: copy spatial_buf, multiply by i·k_y broadcast, iFFT into dpsi_dy
        copyto!(dpsi_dy, ws.spatial_buf)
        @. dpsi_dy *= im * ky_b
        ws.fft_inv * dpsi_dy
        # ∂_x: multiply spatial_buf by i·k_x broadcast, iFFT in place
        @. ws.spatial_buf *= im * kx_b
        ws.fft_inv * ws.spatial_buf
        psi_m = selectdim(ws.psi_tilde, 4, m_idx)
        # Accumulate ⟨ψ_m|x∂_y - y∂_x|ψ_m⟩ via reduction
        Lz += sum(@. conj(psi_m) * (x_b * dpsi_dy - y_b * ws.spatial_buf))
    end
    real(-im * Lz) * prod(ws.grid.dx)
end

# Cache device-resident coordinate / wavenumber 1-D arrays.
const _ROTATING_COORD_CACHE = Dict{Tuple{UInt, Symbol}, AbstractArray}()
function _coord_buffer(ws::RotatingBasisWS{T}, key::Symbol, host_data) where {T}
    cache_key = (objectid(ws), key)
    haskey(_ROTATING_COORD_CACHE, cache_key) && return _ROTATING_COORD_CACHE[cache_key]
    dev_arr = _zeros(ws.backend, T, length(host_data))
    copyto!(dev_arr, T.(host_data))
    _ROTATING_COORD_CACHE[cache_key] = dev_arr
    dev_arr
end
