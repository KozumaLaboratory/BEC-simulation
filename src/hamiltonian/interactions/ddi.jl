"""
    _build_q_tensor!(Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz, k_vectors, k_squared, n_pts; secular=false)

Shared Q tensor construction for both padded and unpadded DDI.
Q_αβ(k) = k̂_α k̂_β - δ_αβ/3 (or secular approximation).
"""
function _build_q_tensor!(
    Q_xx,
    Q_xy,
    Q_xz,
    Q_yy,
    Q_yz,
    Q_zz,
    kx,
    ky,
    kz,
    k_squared,
    n_pts::NTuple{N,Int};
    secular::Bool = false,
) where {N}
    @inbounds for I in CartesianIndices(n_pts)
        k2 = k_squared[I]
        if k2 == 0.0
            Q_xx[I] = 0.0;
            Q_yy[I] = 0.0;
            Q_zz[I] = 0.0
            Q_xy[I] = 0.0;
            Q_xz[I] = 0.0;
            Q_yz[I] = 0.0
            continue
        end

        kv_x = kx[I[1]]
        kv_y = N >= 2 ? ky[I[2]] : 0.0
        kv_z = N >= 3 ? kz[I[3]] : 0.0

        inv_k2 = 1.0 / k2

        if secular
            qzz = kv_z * kv_z * inv_k2 - 1.0 / 3.0
            Q_zz[I] = qzz
            Q_xx[I] = -qzz / 2.0
            Q_yy[I] = -qzz / 2.0
        else
            Q_xx[I] = kv_x * kv_x * inv_k2 - 1.0 / 3.0
            Q_yy[I] = kv_y * kv_y * inv_k2 - 1.0 / 3.0
            Q_zz[I] = kv_z * kv_z * inv_k2 - 1.0 / 3.0
            Q_xy[I] = kv_x * kv_y * inv_k2
            Q_xz[I] = kv_x * kv_z * inv_k2
            Q_yz[I] = kv_y * kv_z * inv_k2
        end
    end
    nothing
end

"""
    _quasi_2d_kernel(k_perp, l_z) → Float64

Quasi-2D DDI kernel h(k⊥ l_z) from z-integrated dipolar interaction.

    h(u) = 2/3 - u√(π/2) erfcx(u/√2)

where u = k⊥ · l_z.

Limits: h(0) = 2/3 (repulsive), h(∞) → -1/3 (attractive).
"""
function _quasi_2d_kernel(k_perp::Float64, l_z::Float64)
    u = k_perp * l_z
    u < 1e-15 && return 2.0 / 3.0
    2.0 / 3.0 - u * sqrt(π / 2.0) * erfcx(u / sqrt(2.0))
end

"""
Build Q tensor for quasi-2D DDI (secular approximation) on a 2D grid.

Q_zz = h(k⊥ l_z), Q_xx = Q_yy = -Q_zz/2, off-diagonal = 0.
"""
function _build_q_tensor_quasi2d!(
    Q_xx,
    Q_xy,
    Q_xz,
    Q_yy,
    Q_yz,
    Q_zz,
    kx,
    ky,
    k_squared,
    n_pts::NTuple{2,Int},
    l_z::Float64,
)
    @inbounds for I in CartesianIndices(n_pts)
        k2 = k_squared[I]
        k_perp = sqrt(k2)
        qzz = _quasi_2d_kernel(k_perp, l_z)
        Q_zz[I] = qzz
        Q_xx[I] = -qzz / 2.0
        Q_yy[I] = -qzz / 2.0
        Q_xy[I] = 0.0
        Q_xz[I] = 0.0
        Q_yz[I] = 0.0
    end
    nothing
end

function make_ddi_params(
    grid::Grid{N},
    atom::AtomSpecies;
    c_dd::Float64 = compute_c_dd(atom),
    secular::Bool = false,
    quasi_2d::Bool = false,
    l_z::Float64 = 0.0,
) where {N}
    if quasi_2d
        N == 2 || throw(ArgumentError("quasi_2d DDI requires a 2D grid (N=2), got N=$N"))
        l_z > 0.0 || throw(ArgumentError("quasi_2d DDI requires l_z > 0, got l_z=$l_z"))
        return _make_ddi_params_quasi2d(grid, c_dd, l_z)
    end
    _make_ddi_params_full(grid, atom; c_dd, secular)
end

function _make_ddi_params_quasi2d(grid::Grid{2}, c_dd::Float64, l_z::Float64)
    n_pts = grid.config.n_points
    rk_shape = rfft_output_shape(n_pts)

    Q_xx = zeros(Float64, rk_shape)
    Q_xy = zeros(Float64, rk_shape)
    Q_xz = zeros(Float64, rk_shape)
    Q_yy = zeros(Float64, rk_shape)
    Q_yz = zeros(Float64, rk_shape)
    Q_zz = zeros(Float64, rk_shape)

    kx_r = collect(rfftfreq(n_pts[1], n_pts[1] * grid.dk[1]))
    ky = grid.k[2]

    k_sq_rk = zeros(Float64, rk_shape)
    @inbounds for I in CartesianIndices(rk_shape)
        k_sq_rk[I] = kx_r[I[1]]^2 + ky[I[2]]^2
    end

    _build_q_tensor_quasi2d!(
        Q_xx,
        Q_xy,
        Q_xz,
        Q_yy,
        Q_yz,
        Q_zz,
        kx_r,
        ky,
        k_sq_rk,
        rk_shape,
        l_z,
    )

    DDIParams(c_dd, Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz)
end

function _make_ddi_params_full(
    grid::Grid{N},
    atom::AtomSpecies;
    c_dd::Float64 = compute_c_dd(atom),
    secular::Bool = false,
) where {N}
    if secular
        @warn "DDI secular approximation: ensure ω_Larmor ≫ c_dd × peak_density" maxlog=1
    end
    C_dd = c_dd
    n_pts = grid.config.n_points
    rk_shape = rfft_output_shape(n_pts)

    Q_xx = zeros(Float64, rk_shape)
    Q_xy = zeros(Float64, rk_shape)
    Q_xz = zeros(Float64, rk_shape)
    Q_yy = zeros(Float64, rk_shape)
    Q_yz = zeros(Float64, rk_shape)
    Q_zz = zeros(Float64, rk_shape)

    kx_r = collect(rfftfreq(n_pts[1], n_pts[1] * grid.dk[1]))
    ky = N >= 2 ? grid.k[2] : Float64[]
    kz = N >= 3 ? grid.k[3] : Float64[]

    k_sq_rk = zeros(Float64, rk_shape)
    @inbounds for I in CartesianIndices(rk_shape)
        k2 = kx_r[I[1]]^2
        if N >= 2
            ;
            k2 += ky[I[2]]^2;
        end
        if N >= 3
            ;
            k2 += kz[I[3]]^2;
        end
        k_sq_rk[I] = k2
    end

    _build_q_tensor!(
        Q_xx,
        Q_xy,
        Q_xz,
        Q_yy,
        Q_yz,
        Q_zz,
        kx_r,
        ky,
        kz,
        k_sq_rk,
        rk_shape;
        secular,
    )

    DDIParams(C_dd, Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz)
end

function _ddi_params_to_device(ddi::DDIParams, backend::CPUBackend)
    ddi
end

function _ddi_params_to_device(ddi::DDIParams, backend::AbstractBackend)
    DDIParams(
        ddi.C_dd,
        _to_device(backend, ddi.Q_xx),
        _to_device(backend, ddi.Q_xy),
        _to_device(backend, ddi.Q_xz),
        _to_device(backend, ddi.Q_yy),
        _to_device(backend, ddi.Q_yz),
        _to_device(backend, ddi.Q_zz),
    )
end

function make_ddi_buffers(
    n_pts::NTuple{N,Int}, backend::AbstractBackend = CPUBackend(); flags = FFTW.MEASURE,
) where {N}
    rk_shape = rfft_output_shape(n_pts)
    rplans = make_rfft_plans(n_pts, backend; flags = flags)
    DDIBuffers(
        rplans,
        _zeros(backend, Float64, n_pts...),       # Fx_r
        _zeros(backend, Float64, n_pts...),       # Fy_r
        _zeros(backend, Float64, n_pts...),       # Fz_r
        _zeros(backend, ComplexF64, rk_shape...), # Fx_rk
        _zeros(backend, ComplexF64, rk_shape...), # Fy_rk
        _zeros(backend, ComplexF64, rk_shape...), # Fz_rk
        _zeros(backend, ComplexF64, rk_shape...), # Phi_x_rk
        _zeros(backend, ComplexF64, rk_shape...), # Phi_y_rk
        _zeros(backend, ComplexF64, rk_shape...), # Phi_z_rk
        _zeros(backend, Float64, n_pts...),       # Phi_x
        _zeros(backend, Float64, n_pts...),       # Phi_y
        _zeros(backend, Float64, n_pts...),       # Phi_z
    )
end

"""
Compute spin density into Float64 buffers, rfft, tensor contraction at half-shape, irfft.
Uses 6 rFFTs (3 forward + 3 inverse), each ~2× cheaper than full FFT.
"""
function _compute_and_convolve_ddi!(
    psi,
    sm,
    ddi::DDIParams{N},
    bufs::DDIBuffers,
    ::Val{D},
    ndim,
    n_pts,
) where {D,N}
    _compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r, psi, sm, Val(D), ndim, n_pts)

    rp = bufs.rfft_plans
    mul!(bufs.Fx_rk, rp.forward, bufs.Fx_r)
    mul!(bufs.Fy_rk, rp.forward, bufs.Fy_r)
    mul!(bufs.Fz_rk, rp.forward, bufs.Fz_r)

    C = ddi.C_dd
    _ddi_k_contraction!(bufs, ddi, C)

    mul!(bufs.Phi_x, rp.inverse, bufs.Phi_x_rk)
    mul!(bufs.Phi_y, rp.inverse, bufs.Phi_y_rk)
    mul!(bufs.Phi_z, rp.inverse, bufs.Phi_z_rk)
    nothing
end

function _ddi_k_contraction_core!(
    Phi_x_rk, Phi_y_rk, Phi_z_rk,
    Fx_rk, Fy_rk, Fz_rk,
    Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz,
    C, rk_shape, is_cpu::Bool,
)
    if is_cpu
        Threads.@threads for I in CartesianIndices(rk_shape)
            @inbounds begin
                fk_x = Fx_rk[I]
                fk_y = Fy_rk[I]
                fk_z = Fz_rk[I]
                Phi_x_rk[I] = C * (Q_xx[I] * fk_x + Q_xy[I] * fk_y + Q_xz[I] * fk_z)
                Phi_y_rk[I] = C * (Q_xy[I] * fk_x + Q_yy[I] * fk_y + Q_yz[I] * fk_z)
                Phi_z_rk[I] = C * (Q_xz[I] * fk_x + Q_yz[I] * fk_y + Q_zz[I] * fk_z)
            end
        end
    else
        @. Phi_x_rk = C * (Q_xx * Fx_rk + Q_xy * Fy_rk + Q_xz * Fz_rk)
        @. Phi_y_rk = C * (Q_xy * Fx_rk + Q_yy * Fy_rk + Q_yz * Fz_rk)
        @. Phi_z_rk = C * (Q_xz * Fx_rk + Q_yz * Fy_rk + Q_zz * Fz_rk)
    end
end

function _ddi_k_contraction!(bufs::DDIBuffers, ddi, C)
    _ddi_k_contraction_core!(
        bufs.Phi_x_rk, bufs.Phi_y_rk, bufs.Phi_z_rk,
        bufs.Fx_rk, bufs.Fy_rk, bufs.Fz_rk,
        ddi.Q_xx, ddi.Q_xy, ddi.Q_xz, ddi.Q_yy, ddi.Q_yz, ddi.Q_zz,
        C, bufs.rfft_plans.rk_shape, bufs.Fx_r isa Array,
    )
end

"""
Compute DDI potential Φ_α(r) via rfft k-space convolution.
Writes result into bufs.Phi_x, Phi_y, Phi_z (Float64).
"""
function compute_ddi_potential!(ddi::DDIParams{N}, bufs::DDIBuffers) where {N}
    rp = bufs.rfft_plans
    mul!(bufs.Fx_rk, rp.forward, bufs.Fx_r)
    mul!(bufs.Fy_rk, rp.forward, bufs.Fy_r)
    mul!(bufs.Fz_rk, rp.forward, bufs.Fz_r)

    _ddi_k_contraction!(bufs, ddi, ddi.C_dd)

    mul!(bufs.Phi_x, rp.inverse, bufs.Phi_x_rk)
    mul!(bufs.Phi_y, rp.inverse, bufs.Phi_y_rk)
    mul!(bufs.Phi_z, rp.inverse, bufs.Phi_z_rk)
    nothing
end

# --- DDI Euler spin rotation ---

"""
Apply Euler spin rotation from DDI dipolar field to the wavefunction.
Operates on CPU arrays only (uses scalar indexing via _get_spinor/_set_spinor!).
"""
function _apply_ddi_rotation!(
    psi::Array{ComplexF64},
    phi_x::Array{Float64},
    phi_y::Array{Float64},
    phi_z::Array{Float64},
    sm::SpinMatrices{D},
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool = false,
) where {D}
    N = ndim
    n_pts = ntuple(d -> size(psi, d), Val(N))
    F = sm.system.F
    m_vals = SVector{D,Float64}(ntuple(c -> F - (c - 1), Val(D)))

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
    if D > 7
        mul!(W, P, conj_V)
    else
        for i = 1:D
            wi = view(W, :, i)
            cV_1i = conj_V[1, i]
            p1 = view(P, :, 1)
            @. wi = cV_1i * p1
            for j = 2:D
                cV_ji = conj_V[j, i]
                pj = view(P, :, j)
                @. wi += cV_ji * pj
            end
        end
    end
end

function _gpu_matmul_V!(P, W, V_T, ::Val{D}) where {D}
    if D > 7
        mul!(P, W, V_T)
    else
        for i = 1:D
            pi = view(P, :, i)
            vT_1i = V_T[1, i]
            w1 = view(W, :, 1)
            @. pi = vT_1i * w1
            for j = 2:D
                vT_ji = V_T[j, i]
                wj = view(W, :, j)
                @. pi += vT_ji * wj
            end
        end
    end
end

function _apply_ddi_rotation!(
    psi::AbstractArray{ComplexF64},
    phi_x::AbstractArray{Float64},
    phi_y::AbstractArray{Float64},
    phi_z::AbstractArray{Float64},
    sm::SpinMatrices{D},
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool = false,
) where {D}
    n_pts = ntuple(d -> size(psi, d), ndim)
    N_spatial = prod(n_pts)
    F = sm.system.F

    P = reshape(psi, N_spatial, D)
    W = reshape(similar(psi), N_spatial, D)

    conj_V_cpu = conj(Matrix(sm.Fy_eigvecs))
    V_T_cpu = Matrix(transpose(sm.Fy_eigvecs))
    if D > 7
        conj_V = similar(P, ComplexF64, D, D)
        V_T = similar(P, ComplexF64, D, D)
        copyto!(conj_V, conj_V_cpu)
        copyto!(V_T, V_T_cpu)
    else
        conj_V = conj_V_cpu
        V_T = V_T_cpu
    end

    spatial_idx = ntuple(d -> 1:n_pts[d], ndim)
    phi_x_v = reshape(view(phi_x, spatial_idx...), N_spatial)
    phi_y_v = reshape(view(phi_y, spatial_idx...), N_spatial)
    phi_z_v = reshape(view(phi_z, spatial_idx...), N_spatial)

    phi_mag = similar(phi_x_v)
    alpha = similar(phi_x_v)
    beta = similar(phi_x_v)
    theta = similar(phi_x_v)
    @. phi_mag = sqrt(phi_x_v^2 + phi_y_v^2 + phi_z_v^2)
    @. alpha = atan(phi_y_v, phi_x_v)
    @. beta = acos(clamp(phi_z_v / max(phi_mag, 1e-30), -1.0, 1.0))
    @. theta = phi_mag * dt_frac

    # Step 1: Rz(-α)
    for c = 1:D
        m_c = Float64(F - (c - 1))
        pc = view(P, :, c)
        @. pc = pc * cis(m_c * alpha)
    end

    # Step 2: Ry(-β) = V · diag(exp(+iβλ)) · V†
    _gpu_matmul_Vdag!(W, P, conj_V, Val(D))
    for i = 1:D
        lam_i = Float64(-F + (i - 1))
        wi = view(W, :, i)
        @. wi = wi * cis(lam_i * beta)
    end
    _gpu_matmul_V!(P, W, V_T, Val(D))

    # Step 3: Dz(θ).
    # ITP applies a constant -F shift so the largest factor is exp(0)=1
    # (m=-F gets factor 1, m=+F gets exp(-2F·θ)). Without this shift the
    # m=-F component gets exp(+F·θ) and explodes (constant shift is removed
    # by the subsequent normalization step).
    if imaginary_time
        for c = 1:D
            m_c = Float64(F - (c - 1))
            pc = view(P, :, c)
            @. pc = pc * exp(-(m_c + F) * theta)
        end
    else
        for c = 1:D
            m_c = Float64(F - (c - 1))
            pc = view(P, :, c)
            @. pc = pc * cis(-m_c * theta)
        end
    end

    # Step 4: Ry(β) = V · diag(exp(-iβλ)) · V†
    _gpu_matmul_Vdag!(W, P, conj_V, Val(D))
    for i = 1:D
        lam_i = Float64(-F + (i - 1))
        wi = view(W, :, i)
        @. wi = wi * cis(-lam_i * beta)
    end
    _gpu_matmul_V!(P, W, V_T, Val(D))

    # Step 5: Rz(α)
    for c = 1:D
        m_c = Float64(F - (c - 1))
        pc = view(P, :, c)
        @. pc = pc * cis(-m_c * alpha)
    end

    nothing
end

"""
Full DDI sub-step: compute spin density, rfft convolve, apply Euler spin rotation.
"""
function apply_ddi_step!(
    psi::AbstractArray{ComplexF64},
    sm::SpinMatrices{D},
    ddi::DDIParams{N},
    bufs::DDIBuffers,
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool = false,
) where {D,N}
    n_pts = ntuple(d -> size(psi, d), Val(N))

    @timeit_debug TIMER "ddi_convolve" _compute_and_convolve_ddi!(
        psi,
        sm,
        ddi,
        bufs,
        Val(D),
        ndim,
        n_pts,
    )

    @timeit_debug TIMER "ddi_rotation" _apply_ddi_rotation!(
        psi, bufs.Phi_x, bufs.Phi_y, bufs.Phi_z, sm, dt_frac, ndim;
        imaginary_time,
    )
    nothing
end
