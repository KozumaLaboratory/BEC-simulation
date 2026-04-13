# GPU-native spin_mixing with pre-allocated buffers
#
# Euler decomposition: R_z(α) R_y(β) exp(-iθFz) R_y(-β) R_z(-α)
# Uses CUBLAS gemm for V†·ψ and V·ψ, fused broadcasts for diagonal phases.

# Per-workspace cache to avoid allocation in hot loop
mutable struct GPUSMCache{D}
    V::CuArray{ComplexF64,2}     # D×D Fy eigenvectors
    Vt::CuArray{ComplexF64,2}    # D×D Fy eigenvectors adjoint
    λ::Vector{Float64}            # D Fy eigenvalues (host)
    m_vals::Vector{Float64}       # D m-values (host)
    fp_coeffs::Vector{Float64}    # D F+ coefficients (host)
    F::Float64
    # Work buffers (allocated once, reused)
    tmp::CuArray{ComplexF64,2}   # (N, D)
    fz::CuArray{Float64,1}       # (N,)
    fx::CuArray{Float64,1}       # (N,)
    fy::CuArray{Float64,1}       # (N,)
    β::CuArray{Float64,1}        # (N,)
    α::CuArray{Float64,1}        # (N,)
    θ::CuArray{Float64,1}        # (N,)
    phase_buf::CuArray{ComplexF64,1}  # (N,)
end

const _GPU_SM_CACHE = Dict{UInt64,Any}()

function _get_gpu_sm_cache(psi::CuArray{ComplexF64}, sm::SpinorBEC.SpinMatrices{D}, ndim::Int) where {D}
    N = prod(ntuple(d -> size(psi, d), ndim))
    key = hash((objectid(sm), N, D))
    cache = get(_GPU_SM_CACHE, key, nothing)
    cache !== nothing && return cache::GPUSMCache{D}

    F = Float64(sm.system.F)
    Ff1 = F * (F + 1)
    m_vals = Float64[F - (c - 1) for c in 1:D]
    fp_coeffs = Float64[c == 1 ? 0.0 : sqrt(Ff1 - (F - c + 1) * (F - c + 2)) for c in 1:D]

    cache = GPUSMCache{D}(
        CuArray(ComplexF64.(Matrix(sm.Fy_eigvecs))),
        CuArray(ComplexF64.(Matrix(sm.Fy_eigvecs_adj))),
        Float64.(sm.Fy_eigvals),
        m_vals,
        fp_coeffs,
        F,
        CUDA.zeros(ComplexF64, N, D),
        CUDA.zeros(Float64, N),
        CUDA.zeros(Float64, N),
        CUDA.zeros(Float64, N),
        CUDA.zeros(Float64, N),
        CUDA.zeros(Float64, N),
        CUDA.zeros(Float64, N),
        CUDA.zeros(ComplexF64, N),
    )
    _GPU_SM_CACHE[key] = cache
    cache
end

function SpinorBEC.apply_spin_mixing_step!(
    psi::CuArray{ComplexF64},
    sm::SpinorBEC.SpinMatrices{D},
    c1::Float64,
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool = false,
) where {D}
    abs(c1) < 1e-30 && return nothing
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    cache = _get_gpu_sm_cache(psi, sm, ndim)
    F = cache.F

    psi_2d = reshape(psi, N, D)
    tmp = cache.tmp
    fz = cache.fz
    fx = cache.fx
    fy = cache.fy
    β = cache.β
    α = cache.α
    θ = cache.θ
    pb = cache.phase_buf

    # --- Compute spin vector (fused broadcasts, no temp alloc) ---
    fz .= 0.0
    for c in 1:D
        m = cache.m_vals[c]
        # fz[i] += m * |psi[i,c]|²  (fused into one kernel per component)
        fz .+= m .* abs2.(view(psi_2d, :, c))
    end

    fx .= 0.0
    fy .= 0.0
    for c in 2:D
        fp = cache.fp_coeffs[c]
        # pb = conj(psi[:,c-1]) * psi[:,c]
        pb .= conj.(view(psi_2d, :, c-1)) .* view(psi_2d, :, c)
        fx .+= fp .* real.(pb)
        fy .+= fp .* imag.(pb)
    end

    # --- Angles (fused) ---
    # f_mag, β, α, θ in minimal broadcasts
    # θ stores f_mag temporarily
    θ .= sqrt.(fx.^2 .+ fy.^2 .+ fz.^2)  # f_mag
    β .= acos.(clamp.(fz ./ max.(θ, 1e-30), -1.0, 1.0))
    α .= atan.(fy, fx)
    θ .*= c1 * dt_frac  # θ = c1 * f_mag * dt

    # --- R_z(-α) ---
    for c in 1:D
        m = cache.m_vals[c]
        view(psi_2d, :, c) .*= cis.(-m .* α)
    end

    # --- R_y(-β): V · diag(exp(iβλ)) · V† · ψ ---
    # tmp = ψ · Vt^T  (CUBLAS gemm, no alloc — write into pre-allocated tmp)
    CUDA.CUBLAS.gemm!('N', 'T', ComplexF64(1), psi_2d, cache.Vt, ComplexF64(0), tmp)
    for j in 1:D
        λj = cache.λ[j]
        view(tmp, :, j) .*= cis.(β .* λj)
    end
    # psi_2d = tmp · V^T
    CUDA.CUBLAS.gemm!('N', 'T', ComplexF64(1), tmp, cache.V, ComplexF64(0), psi_2d)

    # --- exp(-iθFz) ---
    for c in 1:D
        m = cache.m_vals[c]
        if imaginary_time
            view(psi_2d, :, c) .*= exp.(θ .* (m - F))
        else
            view(psi_2d, :, c) .*= cis.(-θ .* m)
        end
    end

    # --- R_y(β): V · diag(exp(-iβλ)) · V† · ψ ---
    CUDA.CUBLAS.gemm!('N', 'T', ComplexF64(1), psi_2d, cache.Vt, ComplexF64(0), tmp)
    for j in 1:D
        λj = cache.λ[j]
        view(tmp, :, j) .*= cis.(-β .* λj)
    end
    CUDA.CUBLAS.gemm!('N', 'T', ComplexF64(1), tmp, cache.V, ComplexF64(0), psi_2d)

    # --- R_z(α) ---
    for c in 1:D
        m = cache.m_vals[c]
        view(psi_2d, :, c) .*= cis.(m .* α)
    end

    nothing
end
