# GPU-native spin_mixing with pre-allocated buffers + broadcast fusion.
#
# Euler decomposition: R_z(α) R_y(β) exp(-iθFz) R_y(-β) R_z(-α)
# Uses CUBLAS gemm for V†·ψ and V·ψ. For the diagonal column phases,
# we fuse D per-column broadcasts into a single (N,D)×(1,D) broadcast —
# on D=13 this cuts ~60 kernel launches per step (measured: spin_mixing
# was 71% of GPU F32 Eu151 128³ split_step total).

# Per-workspace cache. Parameterised on T (Float32 / Float64).
mutable struct GPUSMCache{D, T <: AbstractFloat}
    V::CuArray{Complex{T}, 2}          # D×D Fy eigenvectors V
    Vt::CuArray{Complex{T}, 2}         # D×D V_adj = (V^T)* (legacy gemm path)
    conj_V::CuArray{Complex{T}, 2}     # D×D V* (for shared apply_euler_5stage_fused!)
    V_T::CuArray{Complex{T}, 2}        # D×D V^T (for shared helper)
    λ::CuArray{T, 2}                    # (1,D) Fy eigenvalues (for Ry fusion)
    m_vals::CuArray{T, 2}               # (1,D) m-values (for Rz fusion)
    m_shift::CuArray{T, 2}              # (1,D) m_vals - F (ITP Dz shift)
    F::T
    # Work buffers
    tmp::CuArray{Complex{T}, 2}        # (N, D)
    fz::CuArray{T, 1}                   # (N,)
    fx::CuArray{T, 1}                   # (N,)
    fy::CuArray{T, 1}                   # (N,)
    β::CuArray{T, 2}                    # (N, 1)  shape for fused broadcast
    α::CuArray{T, 2}                    # (N, 1)
    θ::CuArray{T, 2}                    # (N, 1)
    phase_buf::CuArray{Complex{T}, 1}  # (N,)
end

const _GPU_SM_CACHE = Dict{UInt64, Any}()

function _get_gpu_sm_cache(
    psi::CuArray{Complex{T}}, sm::SpinorBEC.SpinMatrices{D}, ndim::Int
) where {D, T <: AbstractFloat}
    N = prod(ntuple(d -> size(psi, d), ndim))
    key = hash((objectid(sm), N, D, T))
    cache = get(_GPU_SM_CACHE, key, nothing)
    cache !== nothing && return cache::GPUSMCache{D, T}

    F = T(sm.system.F)
    m_vals = T[F - T(c - 1) for c in 1:D]
    λ_host = T.(sm.Fy_eigvals)
    m_shift_host = T[m_vals[c] - F for c in 1:D]

    V_host = Matrix{Complex{T}}(sm.Fy_eigvecs)
    cache = GPUSMCache{D, T}(
        CuArray(V_host),
        CuArray(Matrix{Complex{T}}(sm.Fy_eigvecs_adj)),
        CuArray(conj.(V_host)),
        CuArray(transpose(V_host) |> Matrix),
        CuArray(reshape(λ_host, 1, D)),
        CuArray(reshape(m_vals, 1, D)),
        CuArray(reshape(m_shift_host, 1, D)),
        F,
        CUDA.zeros(Complex{T}, N, D),
        CUDA.zeros(T, N),
        CUDA.zeros(T, N),
        CUDA.zeros(T, N),
        CUDA.zeros(T, N, 1),
        CUDA.zeros(T, N, 1),
        CUDA.zeros(T, N, 1),
        CUDA.zeros(Complex{T}, N),
    )
    _GPU_SM_CACHE[key] = cache
    cache
end

function SpinorBEC.apply_spin_mixing_step!(
    psi::CuArray{Complex{T}},
    sm::SpinorBEC.SpinMatrices{D},
    c1::Float64,
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
) where {D, T <: AbstractFloat}
    abs(c1) < 1e-30 && return nothing
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    cache = _get_gpu_sm_cache(psi, sm, ndim)
    c1_t = T(c1)
    dt_t = T(dt_frac)

    psi_2d = reshape(psi, N, D)
    tmp = cache.tmp
    fz = cache.fz
    fx = cache.fx
    fy = cache.fy
    β = cache.β                 # (N, 1)
    α = cache.α                 # (N, 1)
    θ = cache.θ                 # (N, 1)
    pb = cache.phase_buf
    m_gpu = cache.m_vals        # (1, D)
    λ_gpu = cache.λ             # (1, D)
    m_shift_gpu = cache.m_shift # (1, D)
    F_t = cache.F

    # --- Compute spin vector components (O(D) broadcasts, each over (N,)) ---
    fz .= zero(T)
    for c in 1:D
        m = T(F_t - T(c - 1))
        fz .+= m .* abs2.(view(psi_2d, :, c))
    end

    fx .= zero(T)
    fy .= zero(T)
    for c in 2:D
        # fp = sqrt(F(F+1) - m(m+1)) where m = F - (c-1)
        m = F_t - T(c - 1)
        fp = sqrt(F_t * (F_t + one(T)) - m * (m + one(T)))
        pb .= conj.(view(psi_2d, :, c-1)) .* view(psi_2d, :, c)
        fx .+= fp .* real.(pb)
        fy .+= fp .* imag.(pb)
    end

    # --- Angles (reshape to (N,1) for later fusion with (1,D) diag ---
    # θ stores f_mag temporarily, then scaled
    f_mag_view = reshape(θ, N)
    f_mag_view .= sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)
    β_view = reshape(β, N)
    β_view .= acos.(clamp.(fz ./ max.(f_mag_view, floatmin(T)), -one(T), one(T)))
    α_view = reshape(α, N)
    α_view .= atan.(fy, fx)
    f_mag_view .*= c1_t * dt_t       # θ = c1 * f_mag * dt

    # Single-launch fused 5-stage rotation (gpu_euler_kernel.jl). Replaces
    # 7 broadcast + gemm launches with one kernel that processes every
    # spatial point in registers and reads V/conj_V from shared memory.
    # Measured 1.47× over the broadcast path on F=6 96³ F32; up to 4×
    # at smaller grids where launch overhead dominates.
    apply_euler_5stage_fused_kernel!(
        psi_2d, α, β, θ,
        m_gpu, m_shift_gpu, λ_gpu, cache.V, cache.conj_V;
        imaginary_time=imaginary_time,
    )

    nothing
end
