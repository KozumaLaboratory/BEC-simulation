# GPU-native Raman step: eliminates _run_on_host! device↔host transfer.
#
# Uses the same Euler spin rotation as gpu_spin_mixing.jl, but with
# position-dependent field: phi_x = Ω cos(k·r), phi_y = -Ω sin(k·r), phi_z = δ.

mutable struct GPURamanCache{D,T<:AbstractFloat}
    V::CuArray{Complex{T},2}
    Vt::CuArray{Complex{T},2}
    λ::Vector{T}
    m_vals::Vector{T}
    F::T
    tmp::CuArray{Complex{T},2}
    β::CuArray{T,1}
    α::CuArray{T,1}
    θ::CuArray{T,1}
    kr::CuArray{T,1}                # k_eff · r per spatial point
end

const _GPU_RAMAN_CACHE = Dict{UInt64,Any}()

function _get_gpu_raman_cache(
    psi::CuArray{Complex{T}},
    sm::SpinorBEC.SpinMatrices{D},
    raman::SpinorBEC.RamanCoupling{N},
    grid::SpinorBEC.Grid{N},
    ndim::Int,
) where {D,N,T<:AbstractFloat}
    N_spatial = prod(ntuple(d -> size(psi, d), ndim))
    key = hash((objectid(sm), raman.k_eff, N_spatial, D, T))
    cache = get(_GPU_RAMAN_CACHE, key, nothing)
    cache !== nothing && return cache::GPURamanCache{D,T}

    F = T(sm.system.F)
    m_vals = T[F - T(c - 1) for c in 1:D]

    n_pts = ntuple(d -> size(psi, d), ndim)
    kr_host = zeros(T, N_spatial)
    for I in CartesianIndices(n_pts)
        lin = LinearIndices(n_pts)[I]
        kr_host[lin] = sum(ntuple(d -> T(raman.k_eff[d]) * T(grid.x[d][I[d]]), Val(N)))
    end

    cache = GPURamanCache{D,T}(
        CuArray(Matrix{Complex{T}}(sm.Fy_eigvecs)),
        CuArray(Matrix{Complex{T}}(sm.Fy_eigvecs_adj)),
        T.(sm.Fy_eigvals),
        m_vals,
        F,
        CUDA.zeros(Complex{T}, N_spatial, D),
        CUDA.zeros(T, N_spatial),
        CUDA.zeros(T, N_spatial),
        CUDA.zeros(T, N_spatial),
        CuArray(kr_host),
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
    imaginary_time::Bool = false,
) where {D,N,T<:AbstractFloat}
    ndim = N
    n_pts = ntuple(d -> size(psi, d), ndim)
    N_spatial = prod(n_pts)
    cache = _get_gpu_raman_cache(psi, sm, raman, grid, ndim)
    F = cache.F

    psi_2d = reshape(psi, N_spatial, D)
    tmp = cache.tmp
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
    α .= .-kr
    θ .= phi_mag_val * dt_t

    for c in 1:D
        m = cache.m_vals[c]
        view(psi_2d, :, c) .*= cis.(m .* α)
    end

    CUDA.CUBLAS.gemm!('N', 'T', Complex{T}(1), psi_2d, cache.Vt, Complex{T}(0), tmp)
    for j in 1:D
        λj = cache.λ[j]
        view(tmp, :, j) .*= cis.(β .* λj)
    end
    CUDA.CUBLAS.gemm!('N', 'T', Complex{T}(1), tmp, cache.V, Complex{T}(0), psi_2d)

    for c in 1:D
        m = cache.m_vals[c]
        if imaginary_time
            view(psi_2d, :, c) .*= exp.(θ .* (m - F))
        else
            view(psi_2d, :, c) .*= cis.(-θ .* m)
        end
    end

    CUDA.CUBLAS.gemm!('N', 'T', Complex{T}(1), psi_2d, cache.Vt, Complex{T}(0), tmp)
    for j in 1:D
        λj = cache.λ[j]
        view(tmp, :, j) .*= cis.(-β .* λj)
    end
    CUDA.CUBLAS.gemm!('N', 'T', Complex{T}(1), tmp, cache.V, Complex{T}(0), psi_2d)

    for c in 1:D
        m = cache.m_vals[c]
        view(psi_2d, :, c) .*= cis.(-m .* α)
    end

    nothing
end
