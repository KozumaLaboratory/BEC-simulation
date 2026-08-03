# GPU-native Raman step: eliminates _run_on_host! device↔host transfer.
#
# Uses the same Euler spin rotation as gpu_spin_mixing.jl, but with
# position-dependent field: phi_x = Ω cos(k·r), phi_y = -Ω sin(k·r), phi_z = δ.

mutable struct GPURamanCache{D, T <: AbstractFloat}
    V::CuArray{Complex{T}, 2}
    conj_V::CuArray{Complex{T}, 2}    # D×D V* (for shared apply_euler_5stage_fused!)
    λ::CuArray{T, 2}                  # (1, D) — fused with (N, 1) for D-wide broadcast
    m_vals::CuArray{T, 2}             # (1, D)
    m_shift::CuArray{T, 2}            # (1, D)  m_vals - F
    F::T
    β::CuArray{T, 2}                  # (N, 1)
    α::CuArray{T, 2}                  # (N, 1)
    θ::CuArray{T, 2}                  # (N, 1)
    kr::CuArray{T, 2}                 # (N, 1)  k_eff · r per spatial point
end

const _GPU_RAMAN_CACHE = Dict{UInt64, Any}()

function _get_gpu_raman_cache(
    psi::CuArray{Complex{T}},
    sm::SpinorBEC.SpinMatrices{D},
    raman::SpinorBEC.RamanCoupling{N},
    grid::SpinorBEC.Grid{N},
    ndim::Int,
) where {D, N, T <: AbstractFloat}
    N_spatial = prod(ntuple(d -> size(psi, d), ndim))
    key = hash((objectid(sm), raman.k_eff, N_spatial, D, T))
    cache = get(_GPU_RAMAN_CACHE, key, nothing)
    cache !== nothing && return cache::GPURamanCache{D, T}

    F = T(sm.system.F)
    m_vals = T[F - T(c - 1) for c in 1:D]
    m_shift = T[m_vals[c] - F for c in 1:D]
    λ_host = T.(sm.Fy_eigvals)

    n_pts = ntuple(d -> size(psi, d), ndim)
    kr_host = zeros(T, N_spatial)
    for I in CartesianIndices(n_pts)
        lin = LinearIndices(n_pts)[I]
        kr_host[lin] = sum(ntuple(d -> T(raman.k_eff[d]) * T(grid.x[d][I[d]]), Val(N)))
    end

    V_host = Matrix{Complex{T}}(sm.Fy_eigvecs)
    cache = GPURamanCache{D, T}(
        CuArray(V_host),
        CuArray(conj.(V_host)),
        CuArray(reshape(λ_host, 1, D)),
        CuArray(reshape(m_vals, 1, D)),
        CuArray(reshape(m_shift, 1, D)),
        F,
        CUDA.zeros(T, N_spatial, 1),
        CUDA.zeros(T, N_spatial, 1),
        CUDA.zeros(T, N_spatial, 1),
        CuArray(reshape(kr_host, N_spatial, 1)),
    )
    _GPU_RAMAN_CACHE[key] = cache
    cache
end

function SpinorBEC.apply_raman_step!(
    psi::CuArray{Complex{T}},
    sm::SpinorBEC.SpinMatrices{D},
    raman::SpinorBEC.RamanCoupling{N},
    grid::SpinorBEC.Grid{N},
    dt_frac::Float64;
    imaginary_time::Bool=false,
) where {D, N, T <: AbstractFloat}
    ndim = N
    n_pts = ntuple(d -> size(psi, d), ndim)
    N_spatial = prod(n_pts)
    cache = _get_gpu_raman_cache(psi, sm, raman, grid, ndim)
    F = cache.F

    psi_2d = reshape(psi, N_spatial, D)
    β = cache.β
    α = cache.α
    θ = cache.θ
    kr = cache.kr

    Omega_R = T(raman.Omega_R)
    delta = T(raman.delta)
    dt_t = T(dt_frac)

    phi_mag_val = sqrt(Omega_R^2 + delta^2)
    if phi_mag_val < floatmin(T)
        return nothing
    end

    β .= acos(clamp(delta / phi_mag_val, -one(T), one(T)))
    # α = atan2(phi_y, phi_x) where phi_x = Ω cos(kr), phi_y = -Ω sin(kr).
    α .= atan.(.-Omega_R .* sin.(kr), Omega_R .* cos.(kr))
    θ .= phi_mag_val * dt_t

    # Single source of truth for the Euler 5-stage rotation lives in
    # `foundation/spinor_utils.jl::apply_euler_5stage_fused!`. Same call
    # site as gpu_spin_mixing and DDI.
    # Single-launch fused 5-stage rotation kernel (gpu_euler_kernel.jl).
    apply_euler_5stage_fused_kernel!(
        psi_2d, α, β, θ,
        cache.m_vals, cache.m_shift, cache.λ, cache.V, cache.conj_V;
        imaginary_time=imaginary_time,
    )

    nothing
end

# RamanTerm gradient face on GPU — CPU fallback, the same shape as the tensor
# one in `gpu_tensor.jl`. The per-voxel ladder loop is scalar-indexed, and the
# energy face already pays a host round-trip for this term, so correctness comes
# first and a device kernel is a perf follow-on. Gate-first: an inactive Raman
# term is the common L-BFGS case and must not pay a copy. ACCUMULATES, matching
# the CPU contract.
function SpinorBEC.apply_operator!(
    out::CuArray, term::SpinorBEC.RamanTerm, ws, psi::CuArray
)
    ws.raman === nothing && return out
    out_h = Array(out)
    SpinorBEC.apply_operator!(out_h, term, ws, Array(psi))
    copyto!(out, out_h)
    out
end
