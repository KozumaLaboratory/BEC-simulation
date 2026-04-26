# GPU-native spin_mixing with pre-allocated buffers + broadcast fusion.
#
# Euler decomposition: R_z(α) R_y(β) exp(-iθFz) R_y(-β) R_z(-α)
# Uses CUBLAS gemm for V†·ψ and V·ψ. For the diagonal column phases,
# we fuse D per-column broadcasts into a single (N,D)×(1,D) broadcast —
# on D=13 this cuts ~60 kernel launches per step (measured: spin_mixing
# was 71% of GPU F32 Eu151 128³ split_step total).

# Per-workspace cache. Parameterised on T (Float32 / Float64).
mutable struct GPUSMCache{D,T<:AbstractFloat}
    V::CuArray{Complex{T},2}          # D×D Fy eigenvectors
    Vt::CuArray{Complex{T},2}         # D×D Fy eigenvectors adjoint
    λ::CuArray{T,2}                    # (1,D) Fy eigenvalues (for Ry fusion)
    m_vals::CuArray{T,2}               # (1,D) m-values (for Rz fusion)
    m_shift::CuArray{T,2}              # (1,D) m_vals - F (ITP Dz shift)
    F::T
    # Work buffers
    tmp::CuArray{Complex{T},2}        # (N, D)
    fz::CuArray{T,1}                   # (N,)
    fx::CuArray{T,1}                   # (N,)
    fy::CuArray{T,1}                   # (N,)
    β::CuArray{T,2}                    # (N, 1)  shape for fused broadcast
    α::CuArray{T,2}                    # (N, 1)
    θ::CuArray{T,2}                    # (N, 1)
    phase_buf::CuArray{Complex{T},1}  # (N,)
end

const _GPU_SM_CACHE = Dict{UInt64,Any}()

function _get_gpu_sm_cache(psi::CuArray{Complex{T}}, sm::SpinorBEC.SpinMatrices{D}, ndim::Int) where {D,T<:AbstractFloat}
    N = prod(ntuple(d -> size(psi, d), ndim))
    key = hash((objectid(sm), N, D, T))
    cache = get(_GPU_SM_CACHE, key, nothing)
    cache !== nothing && return cache::GPUSMCache{D,T}

    F = T(sm.system.F)
    m_vals = T[F - T(c - 1) for c in 1:D]
    λ_host = T.(sm.Fy_eigvals)
    m_shift_host = T[m_vals[c] - F for c in 1:D]

    cache = GPUSMCache{D,T}(
        CuArray(Matrix{Complex{T}}(sm.Fy_eigvecs)),
        CuArray(Matrix{Complex{T}}(sm.Fy_eigvecs_adj)),
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
    imaginary_time::Bool = false,
) where {D,T<:AbstractFloat}
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
    f_mag_view .= sqrt.(fx.^2 .+ fy.^2 .+ fz.^2)
    β_view = reshape(β, N)
    β_view .= acos.(clamp.(fz ./ max.(f_mag_view, floatmin(T)), -one(T), one(T)))
    α_view = reshape(α, N)
    α_view .= atan.(fy, fx)
    f_mag_view .*= c1_t * dt_t       # θ = c1 * f_mag * dt

    # --- Step 1: R_z(-α) → psi_2d[i,c] *= cis(+m[c] * α[i]) ---
    # Matches CPU spinor_utils.jl `_apply_euler_spin_rotation` (line 121-129):
    # the initial phase is `cis(F·α)` and the per-component recurrence
    # multiplies by `cis(-α)`, giving `cis(m_c · α)` per column. ddi.jl
    # line 592 uses the same `cis(+m_c · alpha)` convention. The earlier
    # GPU code shipped `cis(-m_c · α)` here (and likewise at Step 5 below),
    # which is α → -α — that flipped the sign of the F_y component of the
    # spin-mixing field and gave wrong dynamics for any state with
    # ⟨F_y⟩ ≠ 0 on GPU. Fixed 2026-04-26 after audit.
    psi_2d .*= cis.(m_gpu .* α)

    # --- Step 2: R_y(-β) = V · diag(exp(+iβλ)) · V† · ψ ---
    CUDA.CUBLAS.gemm!('N', 'T', Complex{T}(1), psi_2d, cache.Vt, Complex{T}(0), tmp)
    tmp .*= cis.(β .* λ_gpu)  # fused (N,D) × (N,1)*(1,D)
    CUDA.CUBLAS.gemm!('N', 'T', Complex{T}(1), tmp, cache.V, Complex{T}(0), psi_2d)

    # --- Step 3: exp(-iθF_z) (diagonal in spin) ---
    if imaginary_time
        # Shift by -F so largest factor is exp(0)=1 (m=-F gets factor 1)
        psi_2d .*= exp.(θ .* m_shift_gpu)
    else
        psi_2d .*= cis.(.-θ .* m_gpu)
    end

    # --- Step 4: R_y(β) = V · diag(exp(-iβλ)) · V† · ψ ---
    CUDA.CUBLAS.gemm!('N', 'T', Complex{T}(1), psi_2d, cache.Vt, Complex{T}(0), tmp)
    tmp .*= cis.(.-β .* λ_gpu)
    CUDA.CUBLAS.gemm!('N', 'T', Complex{T}(1), tmp, cache.V, Complex{T}(0), psi_2d)

    # --- Step 5: R_z(α) → psi_2d[i,c] *= cis(-m[c] * α[i]) ---
    # See Step 1 note. ddi.jl line 632 uses the same `cis(-m_c · alpha)`.
    psi_2d .*= cis.(.-m_gpu .* α)

    nothing
end
