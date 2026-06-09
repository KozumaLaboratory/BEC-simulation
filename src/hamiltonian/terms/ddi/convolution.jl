# --- DDI params + buffers + 6-FFT convolution ---

export make_ddi_params, make_ddi_buffers, compute_ddi_potential!

function make_ddi_params(
    grid::Grid{N, T},
    atom::AtomSpecies;
    c_dd::Float64=compute_c_dd(atom),
    secular::Bool=false,
    quasi_2d::Bool=false,
    l_z::Float64=0.0,
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
) where {N, T <: AbstractFloat}
    U = dtype === nothing ? T : dtype
    if quasi_2d
        N == 2 || throw(ArgumentError("quasi_2d DDI requires a 2D grid (N=2), got N=$N"))
        l_z > 0.0 || throw(ArgumentError("quasi_2d DDI requires l_z > 0, got l_z=$l_z"))
        return _make_ddi_params_quasi2d(grid, c_dd, l_z; dtype=U)
    end
    _make_ddi_params_full(grid, atom; c_dd, secular, dtype=U)
end

function _make_ddi_params_quasi2d(
    grid::Grid{2}, c_dd::Float64, l_z::Float64;
    dtype::Type{U}=Float64,
) where {U <: AbstractFloat}
    n_pts = grid.config.n_points
    rk_shape = rfft_output_shape(n_pts)

    Q_xx = zeros(U, rk_shape)
    Q_xy = zeros(U, rk_shape)
    Q_xz = zeros(U, rk_shape)
    Q_yy = zeros(U, rk_shape)
    Q_yz = zeros(U, rk_shape)
    Q_zz = zeros(U, rk_shape)

    kx_r = collect(U, rfftfreq(n_pts[1], n_pts[1] * grid.dk[1]))
    ky = U.(grid.k[2])

    k_sq_rk = zeros(U, rk_shape)
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
        U(l_z),
    )

    DDIParams(c_dd, Q_xx, Q_xy, Q_xz, Q_yy, Q_yz, Q_zz)
end

function _make_ddi_params_full(
    grid::Grid{N, T},
    atom::AtomSpecies;
    c_dd::Float64=compute_c_dd(atom),
    secular::Bool=false,
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
) where {N, T <: AbstractFloat}
    U = dtype === nothing ? T : dtype
    if secular
        @warn "DDI secular approximation: ensure ω_Larmor ≫ c_dd × peak_density" maxlog=1
    end
    C_dd = c_dd
    n_pts = grid.config.n_points
    rk_shape = rfft_output_shape(n_pts)

    Q_xx = zeros(U, rk_shape)
    Q_xy = zeros(U, rk_shape)
    Q_xz = zeros(U, rk_shape)
    Q_yy = zeros(U, rk_shape)
    Q_yz = zeros(U, rk_shape)
    Q_zz = zeros(U, rk_shape)

    kx_r = collect(U, rfftfreq(n_pts[1], n_pts[1] * grid.dk[1]))
    ky = N >= 2 ? U.(grid.k[2]) : U[]
    kz = N >= 3 ? U.(grid.k[3]) : U[]

    k_sq_rk = zeros(U, rk_shape)
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
        full_n=n_pts,
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
    n_pts::NTuple{N, Int}, backend::AbstractBackend=CPUBackend();
    flags=FFTW.MEASURE,
    dtype::Type{U}=Float64,
) where {N, U <: AbstractFloat}
    rk_shape = rfft_output_shape(n_pts)
    rplans = make_rfft_plans(n_pts, backend; flags=flags, dtype=U)
    DDIBuffers(
        rplans,
        _zeros(backend, U, n_pts...),             # Fx_r
        _zeros(backend, U, n_pts...),             # Fy_r
        _zeros(backend, U, n_pts...),             # Fz_r
        _zeros(backend, Complex{U}, rk_shape...), # Fx_rk
        _zeros(backend, Complex{U}, rk_shape...), # Fy_rk
        _zeros(backend, Complex{U}, rk_shape...), # Fz_rk
        _zeros(backend, Complex{U}, rk_shape...), # Phi_x_rk
        _zeros(backend, Complex{U}, rk_shape...), # Phi_y_rk
        _zeros(backend, Complex{U}, rk_shape...), # Phi_z_rk
        _zeros(backend, U, n_pts...),             # Phi_x
        _zeros(backend, U, n_pts...),             # Phi_y
        _zeros(backend, U, n_pts...),             # Phi_z
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
) where {D, N}
    _compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r, psi, sm, Val(D), ndim, n_pts)

    # Full Orszag 2/3 rule companion (see dealias.jl + ddi_padded.jl). Filter
    # bilinear F to (2/3)·k_Nyq to suppress aliased fold-back into low-k F.
    if DEALIAS_2_3_ENABLED[]
        apply_orszag_2_3_F_filter!(bufs.Fx_r, n_pts)
        apply_orszag_2_3_F_filter!(bufs.Fy_r, n_pts)
        apply_orszag_2_3_F_filter!(bufs.Fz_r, n_pts)
    end

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
    # Match scalar to Q eltype so F32 arrays stay F32 through the broadcast.
    Ct = convert(eltype(Q_xx), C)
    if is_cpu
        Threads.@threads for I in CartesianIndices(rk_shape)
            @inbounds begin
                fk_x = Fx_rk[I]
                fk_y = Fy_rk[I]
                fk_z = Fz_rk[I]
                Phi_x_rk[I] = Ct * (Q_xx[I] * fk_x + Q_xy[I] * fk_y + Q_xz[I] * fk_z)
                Phi_y_rk[I] = Ct * (Q_xy[I] * fk_x + Q_yy[I] * fk_y + Q_yz[I] * fk_z)
                Phi_z_rk[I] = Ct * (Q_xz[I] * fk_x + Q_yz[I] * fk_y + Q_zz[I] * fk_z)
            end
        end
    else
        @. Phi_x_rk = Ct * (Q_xx * Fx_rk + Q_xy * Fy_rk + Q_xz * Fz_rk)
        @. Phi_y_rk = Ct * (Q_xy * Fx_rk + Q_yy * Fy_rk + Q_yz * Fz_rk)
        @. Phi_z_rk = Ct * (Q_xz * Fx_rk + Q_yz * Fy_rk + Q_zz * Fz_rk)
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
