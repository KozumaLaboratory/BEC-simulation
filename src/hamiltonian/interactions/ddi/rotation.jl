# --- DDI Euler 5-stage spinor rotation step (CPU + GPU paths + cache) ---

# --- DDI Euler spin rotation ---

"""
Apply Euler spin rotation from DDI dipolar field to the wavefunction.
Operates on CPU arrays only (uses scalar indexing via _get_spinor/_set_spinor!).
"""
function _apply_ddi_rotation!(
    psi::Array{<:Complex},
    phi_x::Array{<:AbstractFloat},
    phi_y::Array{<:AbstractFloat},
    phi_z::Array{<:AbstractFloat},
    sm::SpinMatrices{D},
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
) where {D}
    N = ndim
    n_pts = ntuple(d -> size(psi, d), Val(N))
    F = sm.system.F
    m_vals = SVector{D, Float64}(ntuple(c -> F - (c - 1), Val(D)))

    V_Fy = sm.Fy_eigvecs
    Vt_Fy = sm.Fy_eigvecs_adj
    λ_Fy = sm.Fy_eigvals

    Threads.@threads for I in CartesianIndices(n_pts)
        @inbounds begin
            spinor = _get_spinor(psi, I, Val(D))
            new_spinor = _apply_euler_spin_rotation(
                spinor,
                phi_x[I],
                phi_y[I],
                phi_z[I],
                dt_frac,
                F,
                m_vals,
                V_Fy,
                Vt_Fy,
                λ_Fy,
                sm,
                imaginary_time,
            )
            _set_spinor!(psi, I, new_spinor, Val(D))
        end
    end
    nothing
end

"""
GPU Euler spin rotation using CUBLAS gemm for V†·psi and V·w matmuls.
Reshapes psi from (spatial..., D) to (N_spatial, D) for efficient BLAS.
Replaces 4×D² broadcast calls with 4 CUBLAS gemm calls.
"""
function _gpu_matmul_Vdag!(W, P, conj_V, ::Val{D}) where {D}
    # GPU: always use mul! (single cuBLAS call >> many broadcast launches).
    # CPU small-D: manual unroll avoids BLAS overhead on tiny matrices.
    if D > 7 || !(W isa Array)
        mul!(W, P, conj_V)
    else
        for i in 1:D
            wi = view(W, :, i)
            cV_1i = conj_V[1, i]
            p1 = view(P, :, 1)
            @. wi = cV_1i * p1
            for j in 2:D
                cV_ji = conj_V[j, i]
                pj = view(P, :, j)
                @. wi += cV_ji * pj
            end
        end
    end
end

function _gpu_matmul_V!(P, W, V_T, ::Val{D}) where {D}
    if D > 7 || !(P isa Array)
        mul!(P, W, V_T)
    else
        for i in 1:D
            pi = view(P, :, i)
            vT_1i = V_T[1, i]
            w1 = view(W, :, 1)
            @. pi = vT_1i * w1
            for j in 2:D
                vT_ji = V_T[j, i]
                wj = view(W, :, j)
                @. pi += vT_ji * wj
            end
        end
    end
end

struct _DDIRotationCache
    W::AbstractArray{<:Complex, 2}
    conj_V::AbstractArray{<:Complex, 2}
    V_T::AbstractArray{<:Complex, 2}
    phi_mag::AbstractArray{<:AbstractFloat, 1}
    alpha::AbstractArray{<:AbstractFloat, 1}
    beta::AbstractArray{<:AbstractFloat, 1}
    theta::AbstractArray{<:AbstractFloat, 1}
    # (1,D) row vectors for fused broadcasts — present on GPU only.
    # CPU path uses scalar loop anyway so these stay nothing.
    m_row::Any           # AbstractArray{<:AbstractFloat,2} or nothing
    λ_row::Any           # AbstractArray{<:AbstractFloat,2} or nothing
    m_shift_row::Any     # AbstractArray{<:AbstractFloat,2} or nothing
    # (N×D) Complex scratch for the per-step fused-Euler `cis(...)`
    # broadcasts. Lets `apply_euler_5stage_fused!` write the phase
    # factor in-place instead of allocating a fresh CuArray temporary
    # each `P .*= cis.(...)` line — required for any future CUDA Graph
    # capture, and an alloc reduction independently. Sized to match P.
    # Always allocated (CPU and GPU); CPU path's scalar loop ignores it.
    cis_PD::Any          # AbstractArray{<:Complex,2}
end

const _DDI_ROTATION_CACHE = Dict{UInt64, _DDIRotationCache}()

function _get_ddi_rotation_cache(
    psi::AbstractArray{<:Complex}, sm::SpinMatrices{D}, ndim::Int
) where {D}
    n_pts = ntuple(d -> size(psi, d), ndim)
    N_spatial = prod(n_pts)
    CT = eltype(psi)
    RT = real(CT)
    key = hash((objectid(sm), N_spatial, D, typeof(psi).name, CT))
    cache = get(_DDI_ROTATION_CACHE, key, nothing)
    cache !== nothing && return cache

    P = reshape(psi, N_spatial, D)
    W = similar(P)
    # Always materialise V/V† on the same device as psi so mul!(W, P, V)
    # stays pure-GPU for CuArrays (avoids cuBLAS fallback to scalar loops).
    conj_V_cpu = Matrix{CT}(conj(sm.Fy_eigvecs))
    V_T_cpu = Matrix{CT}(transpose(sm.Fy_eigvecs))
    conj_V = similar(P, CT, D, D)
    V_T = similar(P, CT, D, D)
    copyto!(conj_V, conj_V_cpu)
    copyto!(V_T, V_T_cpu)

    phi_template = similar(psi, RT, N_spatial)
    F = sm.system.F
    on_gpu = !(psi isa Array)
    m_row, λ_row, m_shift_row = if on_gpu
        # Build plain `Vector{RT}` (not SVector) — CUDA.jl's copyto! into a
        # device array needs an IndexLinear host source it knows how to memcpy.
        m_host = Vector{RT}(undef, D)
        λ_host_vec = Vector{RT}(undef, D)
        m_shift_host = Vector{RT}(undef, D)
        @inbounds for c in 1:D
            m_host[c] = RT(F - (c - 1))
            λ_host_vec[c] = RT(sm.Fy_eigvals[c])
            m_shift_host[c] = m_host[c] + RT(F)
        end
        mr_dev = similar(P, RT, 1, D)
        λr_dev = similar(P, RT, 1, D)
        ms_dev = similar(P, RT, 1, D)
        copyto!(vec(mr_dev), m_host)
        copyto!(vec(λr_dev), λ_host_vec)
        copyto!(vec(ms_dev), m_shift_host)
        (mr_dev, λr_dev, ms_dev)
    else
        (nothing, nothing, nothing)
    end

    cis_PD = similar(P)   # (N_spatial, D) Complex scratch
    c = _DDIRotationCache(W, conj_V, V_T,
        similar(phi_template), similar(phi_template),
        similar(phi_template), similar(phi_template),
        m_row, λ_row, m_shift_row, cis_PD)
    _DDI_ROTATION_CACHE[key] = c
    c
end

function _apply_ddi_rotation!(
    psi::AbstractArray{<:Complex},
    phi_x::AbstractArray{<:AbstractFloat},
    phi_y::AbstractArray{<:AbstractFloat},
    phi_z::AbstractArray{<:AbstractFloat},
    sm::SpinMatrices{D},
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
) where {D}
    n_pts = ntuple(d -> size(psi, d), ndim)
    N_spatial = prod(n_pts)
    F = sm.system.F

    rc = _get_ddi_rotation_cache(psi, sm, ndim)
    P = reshape(psi, N_spatial, D)
    W = rc.W

    conj_V = rc.conj_V
    V_T = rc.V_T

    spatial_idx = ntuple(d -> 1:n_pts[d], ndim)
    phi_x_v = reshape(view(phi_x, spatial_idx...), N_spatial)
    phi_y_v = reshape(view(phi_y, spatial_idx...), N_spatial)
    phi_z_v = reshape(view(phi_z, spatial_idx...), N_spatial)

    phi_mag = rc.phi_mag
    alpha = rc.alpha
    beta = rc.beta
    theta = rc.theta
    RT = eltype(phi_mag)
    guard = floatmin(RT)
    dt_t = RT(dt_frac)
    F_t = RT(F)
    if phi_x isa Array
        @inbounds @simd for i in 1:N_spatial
            px = phi_x[i];
            py = phi_y[i];
            pz = phi_z[i]
            pm = sqrt(px * px + py * py + pz * pz)
            phi_mag[i] = pm
            alpha[i] = atan(py, px)
            beta[i] = acos(clamp(pz / max(pm, guard), -one(RT), one(RT)))
            theta[i] = pm * dt_t
        end
    else
        @. phi_mag = sqrt(phi_x_v^2 + phi_y_v^2 + phi_z_v^2)
        @. alpha = atan(phi_y_v, phi_x_v)
        @. beta = acos(clamp(phi_z_v / max(phi_mag, guard), -one(RT), one(RT)))
        @. theta = phi_mag * dt_t
    end

    # GPU path: fuse D per-column broadcasts into one (N,D)×(1,D)*(N,1) broadcast.
    if rc.m_row !== nothing
        # Fused (N,1)·(1,D) Euler 5-stage rotation, shared with
        # `gpu_spin_mixing.jl` and `gpu_raman.jl` via
        # `apply_euler_5stage_fused!` (foundation/spinor_utils.jl). The
        # earlier inline copy here was bit-identical but invited the same
        # silent sign-convention drift the 2026-04-26 GPU audit caught.
        apply_euler_5stage_fused!(
            P, W,
            reshape(alpha, N_spatial, 1),
            reshape(beta, N_spatial, 1),
            reshape(theta, N_spatial, 1),
            rc.m_row, rc.m_shift_row, rc.λ_row,
            V_T, conj_V;
            imaginary_time=imaginary_time,
            cis_PD=rc.cis_PD,
        )
    else
        # CPU path: column-wise loop avoids large temporary (1,D) broadcast tables.
        # Step 1: Rz(-α)
        for c in 1:D
            m_c = RT(F - (c - 1))
            pc = view(P, :, c)
            @. pc = pc * cis(m_c * alpha)
        end

        # Step 2: Ry(-β) = V · diag(exp(+iβλ)) · V†
        _gpu_matmul_Vdag!(W, P, conj_V, Val(D))
        for i in 1:D
            lam_i = RT(-F + (i - 1))
            wi = view(W, :, i)
            @. wi = wi * cis(lam_i * beta)
        end
        _gpu_matmul_V!(P, W, V_T, Val(D))

        # Step 3: Dz(θ)
        if imaginary_time
            for c in 1:D
                m_c = RT(F - (c - 1))
                pc = view(P, :, c)
                @. pc = pc * exp(-(m_c + F_t) * theta)
            end
        else
            for c in 1:D
                m_c = RT(F - (c - 1))
                pc = view(P, :, c)
                @. pc = pc * cis(-m_c * theta)
            end
        end

        # Step 4: Ry(β)
        _gpu_matmul_Vdag!(W, P, conj_V, Val(D))
        for i in 1:D
            lam_i = RT(-F + (i - 1))
            wi = view(W, :, i)
            @. wi = wi * cis(-lam_i * beta)
        end
        _gpu_matmul_V!(P, W, V_T, Val(D))

        # Step 5: Rz(α)
        for c in 1:D
            m_c = RT(F - (c - 1))
            pc = view(P, :, c)
            @. pc = pc * cis(-m_c * alpha)
        end
    end

    nothing
end
