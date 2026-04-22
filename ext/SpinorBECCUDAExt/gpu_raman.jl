# GPU-native Raman step: eliminates _run_on_host! device↔host transfer.
#
# Uses the same Euler spin rotation as gpu_spin_mixing.jl, but with
# position-dependent field: phi_x = Ω cos(k·r), phi_y = -Ω sin(k·r), phi_z = δ.

mutable struct GPURamanCache{D}
    V::CuArray{ComplexF64,2}
    Vt::CuArray{ComplexF64,2}
    λ::Vector{Float64}
    m_vals::Vector{Float64}
    F::Float64
    tmp::CuArray{ComplexF64,2}
    β::CuArray{Float64,1}
    α::CuArray{Float64,1}
    θ::CuArray{Float64,1}
    kr::CuArray{Float64,1}           # k_eff · r per spatial point
end

const _GPU_RAMAN_CACHE = Dict{UInt64,Any}()

function _get_gpu_raman_cache(
    psi::CuArray{ComplexF64},
    sm::SpinorBEC.SpinMatrices{D},
    raman::SpinorBEC.RamanCoupling{N},
    grid::SpinorBEC.Grid{N},
    ndim::Int,
) where {D,N}
    N_spatial = prod(ntuple(d -> size(psi, d), ndim))
    key = hash((objectid(sm), objectid(raman), N_spatial, D))
    cache = get(_GPU_RAMAN_CACHE, key, nothing)
    cache !== nothing && return cache::GPURamanCache{D}

    F = Float64(sm.system.F)
    m_vals = Float64[F - (c - 1) for c in 1:D]

    # Precompute k_eff · r for all spatial points
    n_pts = ntuple(d -> size(psi, d), ndim)
    kr_host = zeros(Float64, N_spatial)
    for I in CartesianIndices(n_pts)
        lin = LinearIndices(n_pts)[I]
        kr_host[lin] = sum(ntuple(d -> raman.k_eff[d] * grid.x[d][I[d]], Val(N)))
    end

    cache = GPURamanCache{D}(
        CuArray(ComplexF64.(Matrix(sm.Fy_eigvecs))),
        CuArray(ComplexF64.(Matrix(sm.Fy_eigvecs_adj))),
        Float64.(sm.Fy_eigvals),
        m_vals,
        F,
        CUDA.zeros(ComplexF64, N_spatial, D),
        CUDA.zeros(Float64, N_spatial),
        CUDA.zeros(Float64, N_spatial),
        CUDA.zeros(Float64, N_spatial),
        CuArray(kr_host),
    )
    _GPU_RAMAN_CACHE[key] = cache
    cache
end

function SpinorBEC.apply_raman_step!(
    psi::CuArray{ComplexF64},
    sm::SpinorBEC.SpinMatrices{D},
    raman::SpinorBEC.RamanCoupling{N},
    grid::SpinorBEC.Grid{N},
    dt_frac::Float64;
    imaginary_time::Bool = false,
) where {D,N}
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

    Omega_R = raman.Omega_R
    delta = raman.delta

    # Raman field: phi = (Ω cos(kr), -Ω sin(kr), δ)
    # phi_mag = sqrt(Ω² + δ²) — constant for all points
    phi_mag_val = sqrt(Omega_R^2 + delta^2)
    if phi_mag_val < 1e-30
        return nothing
    end

    # β = acos(δ / |phi|), α = atan(-Ω sin(kr), Ω cos(kr)) = atan(-sin(kr), cos(kr)) = -kr
    # θ = |phi| * dt
    β .= acos(clamp(delta / phi_mag_val, -1.0, 1.0))
    α .= .-kr
    θ .= phi_mag_val * dt_frac

    # Step 1: Rz(-α) = Rz(kr)
    for c in 1:D
        m = cache.m_vals[c]
        view(psi_2d, :, c) .*= cis.(m .* α)
    end

    # Step 2: Ry(-β) = V · diag(exp(iβλ)) · V†
    CUDA.CUBLAS.gemm!('N', 'T', ComplexF64(1), psi_2d, cache.Vt, ComplexF64(0), tmp)
    for j in 1:D
        λj = cache.λ[j]
        view(tmp, :, j) .*= cis.(β .* λj)
    end
    CUDA.CUBLAS.gemm!('N', 'T', ComplexF64(1), tmp, cache.V, ComplexF64(0), psi_2d)

    # Step 3: exp(-iθFz)
    for c in 1:D
        m = cache.m_vals[c]
        if imaginary_time
            view(psi_2d, :, c) .*= exp.(θ .* (m - F))
        else
            view(psi_2d, :, c) .*= cis.(-θ .* m)
        end
    end

    # Step 4: Ry(β) = V · diag(exp(-iβλ)) · V†
    CUDA.CUBLAS.gemm!('N', 'T', ComplexF64(1), psi_2d, cache.Vt, ComplexF64(0), tmp)
    for j in 1:D
        λj = cache.λ[j]
        view(tmp, :, j) .*= cis.(-β .* λj)
    end
    CUDA.CUBLAS.gemm!('N', 'T', ComplexF64(1), tmp, cache.V, ComplexF64(0), psi_2d)

    # Step 5: Rz(α) = Rz(-kr)
    for c in 1:D
        m = cache.m_vals[c]
        view(psi_2d, :, c) .*= cis.(-m .* α)
    end

    nothing
end
