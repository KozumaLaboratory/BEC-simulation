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
    conj_V::CuArray{Complex{T}, 2}     # D×D V* (for shared apply_euler_5stage_fused!)
    λ::CuArray{T, 2}                    # (1,D) Fy eigenvalues (for Ry fusion)
    m_vals::CuArray{T, 2}               # (1,D) m-values (for Rz fusion)
    m_shift::CuArray{T, 2}              # (1,D) m_vals - F (ITP Dz shift)
    F::T
    # Work buffers
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
        CuArray(conj.(V_host)),
        CuArray(reshape(λ_host, 1, D)),
        CuArray(reshape(m_vals, 1, D)),
        CuArray(reshape(m_shift_host, 1, D)),
        F,
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
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {D, T <: AbstractFloat}
    abs(c1) < 1e-30 && return nothing
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    cache = _get_gpu_sm_cache(psi, sm, ndim)
    c1_t = T(c1)
    dt_t = T(dt_frac)

    # 2026-05-22 verification suite (L1 yaml 06 spin-1 SMA) call passes
    # `psi_mf` kwarg from split_step. CPU path uses psi_mf as the source
    # for the spin expectation when computing the SMA Euler rotation,
    # then applies the rotation to `psi`. Mirror that here: build psi_2d
    # from psi (rotated target) and psi_mf_2d from psi_mf (expectation
    # source). When psi_mf is nothing, use psi itself (default SMA).
    psi_2d = reshape(psi, N, D)
    psi_mf_2d = psi_mf === nothing ?
                psi_2d :
                reshape(psi_mf::CuArray{Complex{T}}, N, D)
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

    # --- Spin vector components in ONE fused launch (reuse _spin_density_kernel!) ---
    # Replaces ~49 broadcasts (D for F_z + 3(D-1) for F_x/F_y, each round-tripping
    # ψ and an accumulator through HBM). Same physics (m_c, fp ladder coeffs) as the
    # removed loop and as the CPU path — machine-precision equivalent, parity-gated.
    let
        m_svec = SVector{D, T}(ntuple(c -> T(F_t - T(c - 1)), Val(D)))
        fp_svec = SpinorBEC.fp_ladder_coeffs(T, sm.system.F, Val(D))
        thr = min(N, 256)
        blk = cld(N, thr)
        # `nothing` = contiguous destination: the spin-mixing field buffers are
        # its own, never a zero-padded DDI corner.
        CUDA.@cuda threads = thr blocks = blk _spin_density_kernel!(
            fx, fy, fz, psi_mf_2d, m_svec, fp_svec, Val(D), nothing)
    end

    # --- Rotation: exp(-i·c₁·dt·(⟨F⟩·F)) ---
    # Same operator the DDI substep applies with v = Φ, so it goes through the
    # same Taylor-Horner kernel (gpu_spin_rotation_taylor.jl) rather than a
    # second realization. That path also skips the α/β/θ trigonometry below —
    # it needs only the raw vector field. Measured 64³ Eu151 D=13: 10.3 ms →
    # 2.85 ms per call, and this substep runs 8× per RTP step.
    plan = _spin_taylor_plan(psi, sm)
    if plan !== nothing
        coef, F = plan
        _apply_spin_rotation_taylor!(
            psi_2d, fx, fy, fz, coef, c1_t * dt_t, Val(D); imaginary_time, F)
        return nothing
    end

    # --- Fallback: exact Euler 5-stage (R above the Taylor cutoff) ---
    # θ stores f_mag temporarily, then scaled
    f_mag_view = reshape(θ, N)
    f_mag_view .= sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)
    β_view = reshape(β, N)
    β_view .= acos.(clamp.(fz ./ max.(f_mag_view, floatmin(T)), -one(T), one(T)))
    α_view = reshape(α, N)
    α_view .= atan.(fy, fx)
    f_mag_view .*= c1_t * dt_t       # θ = c1 * f_mag * dt

    # Single-launch fused 5-stage rotation (warp-cooperative kernel, no MVector
    # local-memory spill at D=13 — see gpu_euler_kernel.jl).
    apply_euler_5stage_fused_kernel!(
        psi_2d, α, β, θ,
        m_gpu, m_shift_gpu, λ_gpu, cache.V, cache.conj_V;
        imaginary_time=imaginary_time,
    )

    nothing
end
