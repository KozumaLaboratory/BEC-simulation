# HF substep composition on GPU — Phase 5c completion.
#
# Wires together:
#   - gpu_tdhfb_channel.jl (V_flat cache + source builders + contraction)
#   - gpu_tdhfb_w_assembly.jl (W block assembly)
#   - gpu_tdhfb_expm.jl (batched_expm_neg_i_dt!)
#   - gpu_tdhfb_r_update.jl (Nambu R build + batched matinv + M·R·M^{-1} + project)
#
# Provides CuArray dispatch for:
#   - _tdhfb_phi_subupdate!  : φ Nambu doublet rotation
#   - _tdhfb_R_subupdate!    : (ρ, κ) Nambu matrix rotation
#   - _tdhfb_hf_step!        : symmetric Strang composition φ(dt/2) → R(dt) → φ(dt/2)

# Per-workspace scratch cache. Keyed on `(N_vox, D, T_complex)`.
mutable struct GPUTDHFBScratch{TC <: Complex, TR <: AbstractFloat}
    # Channel-build scratch
    source_flat::CuArray{TC, 2}        # (D², N_vox)
    out_flat::CuArray{TC, 2}           # (D², N_vox)
    U::CuArray{TC, 3}                  # (D, D, N_vox)
    Delta_phi::CuArray{TC, 3}          # (D, D, N_vox)
    Delta_R::CuArray{TC, 3}            # (D, D, N_vox)

    # W and matrix-exp scratch (2D × 2D × N_vox)
    W::CuArray{TC, 3}
    M::CuArray{TC, 3}
    Minv::CuArray{TC, 3}
    A_scratch::CuArray{TC, 3}          # matrix-exp Taylor scratch
    A_tmp::CuArray{TC, 3}
    P_tmp::CuArray{TC, 3}

    # R update scratch
    R::CuArray{TC, 3}
    R_new::CuArray{TC, 3}
    R_tmp::CuArray{TC, 3}

    # φ doublet (2D, N_vox)
    phi_doublet::CuArray{TC, 2}
    phi_doublet_new::CuArray{TC, 2}
end

const _GPU_TDHFB_SCRATCH = Dict{UInt64, Any}()

function _get_or_build_scratch(
    ::Type{TC},
    ::Type{TR},
    D::Int,
    N_vox::Int,
) where {TC <: Complex, TR <: AbstractFloat}
    key = hash((TC, TR, D, N_vox))
    cached = get(_GPU_TDHFB_SCRATCH, key, nothing)
    cached !== nothing && return cached::GPUTDHFBScratch{TC, TR}
    twoD = 2 * D
    sc = GPUTDHFBScratch{TC, TR}(
        CUDA.zeros(TC, D * D, N_vox),
        CUDA.zeros(TC, D * D, N_vox),
        CUDA.zeros(TC, D, D, N_vox),
        CUDA.zeros(TC, D, D, N_vox),
        CUDA.zeros(TC, D, D, N_vox),
        CUDA.zeros(TC, twoD, twoD, N_vox),
        CUDA.zeros(TC, twoD, twoD, N_vox),
        CUDA.zeros(TC, twoD, twoD, N_vox),
        CUDA.zeros(TC, twoD, twoD, N_vox),
        CUDA.zeros(TC, twoD, twoD, N_vox),
        CUDA.zeros(TC, twoD, twoD, N_vox),
        CUDA.zeros(TC, twoD, twoD, N_vox),
        CUDA.zeros(TC, twoD, twoD, N_vox),
        CUDA.zeros(TC, twoD, twoD, N_vox),
        CUDA.zeros(TC, twoD, N_vox),
        CUDA.zeros(TC, twoD, N_vox),
    )
    _GPU_TDHFB_SCRATCH[key] = sc
    sc
end

# ----- φ doublet apply: phi_new = top half of M · (phi, conj(phi)) -----

function _kernel_build_phi_doublet!(doublet, phi, D::Int, twoD::Int, N_vox::Int)
    r = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    v = (CUDA.blockIdx().y - 1) * CUDA.blockDim().y + CUDA.threadIdx().y
    if r <= twoD && v <= N_vox
        @inbounds begin
            if r <= D
                doublet[r, v] = phi[v, r]
            else
                doublet[r, v] = conj(phi[v, r - D])
            end
        end
    end
    return nothing
end

function _kernel_unbuild_phi_doublet!(phi, doublet_new, D::Int, N_vox::Int)
    c = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    v = (CUDA.blockIdx().y - 1) * CUDA.blockDim().y + CUDA.threadIdx().y
    if c <= D && v <= N_vox
        @inbounds phi[v, c] = doublet_new[c, v]
    end
    return nothing
end

function _apply_M_to_phi_doublet!(
    phi::CuArray{TC, M},
    M_mat::CuArray{TC, 3},
    sc::GPUTDHFBScratch{TC, TR},
    D::Int,
) where {TC <: Complex, TR, M}
    twoD = 2 * D
    N_vox = size(M_mat, 3)
    spatial = size(phi)[1:end-1]
    @assert prod(spatial) == N_vox
    phi_v = reshape(phi, N_vox, D)

    # Build (phi, conj(phi)) doublet
    threads_r = min(twoD, 32)
    threads_v = min(N_vox, 8)
    blocks_r = cld(twoD, threads_r)
    blocks_v = cld(N_vox, threads_v)
    CUDA.@cuda(
        threads=(threads_r, threads_v), blocks=(blocks_r, blocks_v),
        _kernel_build_phi_doublet!(sc.phi_doublet, phi_v, D, twoD, N_vox),
    )

    # phi_doublet_new[r, v] = Σ_c M_mat[r, c, v] · phi_doublet[c, v]
    # Use gemv-strided-batched: per voxel, M_mat[:, :, v] @ phi_doublet[:, v]
    # CUDA.CUBLAS supports gemv_strided_batched! with separate scalar args.
    CUDA.CUBLAS.gemv_strided_batched!(
        'N', one(TC), M_mat, sc.phi_doublet, zero(TC), sc.phi_doublet_new,
    )

    # Read back top half into phi
    threads_c = min(D, 32)
    blocks_c = cld(D, threads_c)
    CUDA.@cuda(
        threads=(threads_c, threads_v), blocks=(blocks_c, blocks_v),
        _kernel_unbuild_phi_doublet!(phi_v, sc.phi_doublet_new, D, N_vox),
    )
    phi
end

# ----- φ subupdate -----

function SpinorBEC._tdhfb_phi_subupdate!(
    state::SpinorBEC.TDHFBState{N, A, B, T},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V_arg,
    dt::Float64;
    hfb_mode::Symbol=:full_hfb,
) where {N, A <: CuArray, B <: CuArray, T}
    D = 2 * F + 1
    TC = eltype(state.phi)
    TR = real(TC)
    N_vox = prod(size(state.phi)[1:end-1])

    V_flat = _get_or_build_V_flat(F, g_S, TC)
    sc = _get_or_build_scratch(TC, TR, D, N_vox)

    # 1. Build source_U = φ*φ + ρ and contract → U
    _build_source_U!(sc.source_flat, state.phi, state.rho, D)
    _contract_V_source!(sc.out_flat, V_flat, sc.source_flat)
    sc.U .= reshape(sc.out_flat, D, D, N_vox)

    # 2. Build source_Δphi = κ and contract → Δ_phi (skip if Popov)
    if hfb_mode === :popov
        fill!(sc.Delta_phi, zero(TC))
    else
        _build_source_kappa!(sc.source_flat, state.kappa, D)
        _contract_V_source!(sc.out_flat, V_flat, sc.source_flat)
        sc.Delta_phi .= reshape(sc.out_flat, D, D, N_vox)
    end

    # 3. Assemble W = [[U, Δ]; [-Δ̄, -Ū]]
    _assemble_w_blocks!(sc.W, sc.U, sc.Delta_phi)

    # 4. M = exp(-i W dt) via batched Taylor
    # n_taylor=8: for typical TDHFB regime ‖W·dt‖ < 0.05, Taylor accuracy
    # = (0.05)^8 / 8! ≈ 1e-15 (F64 machine eps) / 6e-12 (F32 eps × condition).
    # Drop from 14 to 8 saves 6 batched gemms per HF substep (~40% faster).
    batched_expm_neg_i_dt!(
        sc.M, sc.W, dt;
        n_taylor=8,
        A_scratch=sc.A_scratch, A_tmp=sc.A_tmp, P_tmp=sc.P_tmp,
    )

    # 5. Apply M to (φ, conj(φ)) doublet; read back top half into φ.
    _apply_M_to_phi_doublet!(state.phi, sc.M, sc, D)
    return state
end

# ----- R subupdate -----

function SpinorBEC._tdhfb_R_subupdate!(
    state::SpinorBEC.TDHFBState{N, A, B, T},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V_arg,
    dt::Float64,
) where {N, A <: CuArray, B <: CuArray, T}
    D = 2 * F + 1
    TC = eltype(state.phi)
    TR = real(TC)
    N_vox = prod(size(state.phi)[1:end-1])

    V_flat = _get_or_build_V_flat(F, g_S, TC)
    sc = _get_or_build_scratch(TC, TR, D, N_vox)

    # 1. U = V·(φ*φ + ρ)  (same as in φ subupdate; rebuild for current ψ)
    _build_source_U!(sc.source_flat, state.phi, state.rho, D)
    _contract_V_source!(sc.out_flat, V_flat, sc.source_flat)
    sc.U .= reshape(sc.out_flat, D, D, N_vox)

    # 2. Δ_R = V·(φφ + κ)
    _build_source_DeltaR!(sc.source_flat, state.phi, state.kappa, D)
    _contract_V_source!(sc.out_flat, V_flat, sc.source_flat)
    sc.Delta_R .= reshape(sc.out_flat, D, D, N_vox)

    # 3. Assemble W^R
    _assemble_w_blocks!(sc.W, sc.U, sc.Delta_R)

    # 4. M^R = exp(-i W^R dt)
    # n_taylor=8: for typical TDHFB regime ‖W·dt‖ < 0.05, Taylor accuracy
    # = (0.05)^8 / 8! ≈ 1e-15 (F64 machine eps) / 6e-12 (F32 eps × condition).
    # Drop from 14 to 8 saves 6 batched gemms per HF substep (~40% faster).
    batched_expm_neg_i_dt!(
        sc.M, sc.W, dt;
        n_taylor=8,
        A_scratch=sc.A_scratch, A_tmp=sc.A_tmp, P_tmp=sc.P_tmp,
    )

    # 5. Build Nambu R from (ρ, κ)
    _build_R_nambu!(sc.R, state, D)

    # 6. R_new = M · R · M†  (bosonic Heisenberg evolution of ⟨ψ_b† ψ_a⟩)
    _apply_mrm!(sc.R_new, sc.M, sc.R, sc.R_tmp)

    # 7. Read R_new back into (ρ, κ); no projection needed (Hermitian by M·R·M†).
    _project_R_to_rho_kappa!(state, sc.R_new, D)
    return state
end

# ----- Full HF substep -----

function SpinorBEC._tdhfb_hf_step!(
    state::SpinorBEC.TDHFBState{N, A, B, T},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    dt::Float64;
    hfb_mode::Symbol=:full_hfb,
) where {N, A <: CuArray, B <: CuArray, T}
    # Symmetric inner Strang: φ(dt/2) → R(dt) → φ(dt/2)
    half = dt / 2
    SpinorBEC._tdhfb_phi_subupdate!(state, F, g_S, nothing, half; hfb_mode=hfb_mode)
    SpinorBEC._tdhfb_R_subupdate!(state, F, g_S, nothing, dt)
    SpinorBEC._tdhfb_phi_subupdate!(state, F, g_S, nothing, half; hfb_mode=hfb_mode)
    state
end
