export make_ddi_padded

"""
    _padded_grid_size(factor, n) -> Int

Padded length for one axis at zero-pad `factor` (≥ 1). `factor == 2` keeps the
exact `2n` (historical default; preserves bit-for-bit the existing padded path).
Any other factor rounds `factor·n` UP to the next FFT-friendly size (product of
2,3,5,7) so the padded FFT stays fast for anisotropic / optimal padding.
"""
function _padded_grid_size(factor::Real, n::Int)
    factor == 2 && return 2n
    factor >= 1 || throw(ArgumentError("pad_factor must be ≥ 1, got $factor"))
    nextprod((2, 3, 5, 7), max(n + 1, ceil(Int, factor * n)))
end

"""
Build zero-padded DDI context for reduced aliasing.

`pad_factor` (a scalar or per-axis `NTuple`) sets the zero-pad multiple per
dimension; default `2` reproduces the historical `2n` padded grid. Smaller
factors on thin axes (anisotropic padding, e.g. `(2.73, 2.73, 1.5)` for a
pancake) cut memory — valid as long as the truncation radius obeys
`R ≤ (factor_d − 1)·L_d` on every axis (the caller's auto-`trunc_radius`
enforces this). Builds the Q tensor and rFFT plans on the padded grid.
"""
function make_ddi_padded(
    grid::Grid{N, T},
    atom::AtomSpecies;
    c_dd::Float64=compute_c_dd(atom),
    fft_flags=FFTW.MEASURE,
    secular::Bool=false,
    quasi_2d::Bool=false,
    l_z::Float64=0.0,
    trunc_radius::Union{Nothing, Float64}=nothing,
    pad_factor::Union{Real, NTuple{N, Real}}=2,
    backend::AbstractBackend=CPUBackend(),
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
) where {N, T <: AbstractFloat}
    U = dtype === nothing ? T : dtype
    n_pts = grid.config.n_points
    pf = pad_factor isa Real ? ntuple(_ -> pad_factor, N) : pad_factor
    padded_shape = ntuple(d -> _padded_grid_size(pf[d], n_pts[d]), N)
    rk_shape = rfft_output_shape(padded_shape)

    dx = grid.dx
    kx_r = collect(U, rfftfreq(padded_shape[1], padded_shape[1] * 2π / (padded_shape[1] * dx[1])))
    k_full = ntuple(N) do d
        n = padded_shape[d]
        dk = 2π / (n * dx[d])
        collect(U, fftfreq(n, n * dk))
    end
    ky = N >= 2 ? k_full[2] : U[]
    kz = N >= 3 ? k_full[3] : U[]

    Q_xx = zeros(U, rk_shape)
    Q_xy = zeros(U, rk_shape)
    Q_xz = zeros(U, rk_shape)
    Q_yy = zeros(U, rk_shape)
    Q_yz = zeros(U, rk_shape)
    Q_zz = zeros(U, rk_shape)

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

    if quasi_2d && N == 2
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
    else
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
            full_n=padded_shape,
            trunc_radius,
        )
    end

    rplans = make_rfft_plans(padded_shape, backend; flags=fft_flags, dtype=U)

    DDIPaddedContext(
        padded_shape,
        rplans,
        _to_device(backend, Q_xx),
        _to_device(backend, Q_xy),
        _to_device(backend, Q_xz),
        _to_device(backend, Q_yy),
        _to_device(backend, Q_yz),
        _to_device(backend, Q_zz),
        _zeros(backend, U, padded_shape...),
        _zeros(backend, U, padded_shape...),
        _zeros(backend, U, padded_shape...),
        _zeros(backend, Complex{U}, rk_shape...),
        _zeros(backend, Complex{U}, rk_shape...),
        _zeros(backend, Complex{U}, rk_shape...),
        _zeros(backend, Complex{U}, rk_shape...),
        _zeros(backend, Complex{U}, rk_shape...),
        _zeros(backend, Complex{U}, rk_shape...),
        _zeros(backend, U, padded_shape...),
        _zeros(backend, U, padded_shape...),
        _zeros(backend, U, padded_shape...),
    )
end

"""
Compute DDI potential using zero-padded rFFT convolution.
Pads spin density into 2× grid, convolves in k-space, crops back.
"""
function _compute_and_convolve_ddi_padded!(
    psi,
    sm,
    ddi::DDIParams{N},
    ctx::DDIPaddedContext{N},
    ::Val{D},
    ndim,
    n_pts,
) where {D, N}
    ctx.Fx_pad .= 0
    ctx.Fy_pad .= 0
    ctx.Fz_pad .= 0

    _compute_spin_density!(ctx.Fx_pad, ctx.Fy_pad, ctx.Fz_pad, psi, sm, Val(D), ndim, n_pts)

    # Full Orszag 2/3 rule: ψ pre-filter (in split_step) reduces ψ bandwidth
    # to (2/3)·k_Nyq, but bilinear F still has bandwidth (4/3)·k_Nyq and
    # aliases on the N grid. Filter F to (2/3)·k_Nyq here to complete the
    # rule. The first n_pts entries of F_pad are modified; the
    # convolution-pad (the rest) stays zero.
    if DEALIAS_2_3_ENABLED[]
        apply_orszag_2_3_F_filter!(ctx.Fx_pad, n_pts, ddi.box_size)
        apply_orszag_2_3_F_filter!(ctx.Fy_pad, n_pts, ddi.box_size)
        apply_orszag_2_3_F_filter!(ctx.Fz_pad, n_pts, ddi.box_size)
    end

    rp = ctx.rfft_plans
    mul!(ctx.Fx_pad_rk, rp.forward, ctx.Fx_pad)
    mul!(ctx.Fy_pad_rk, rp.forward, ctx.Fy_pad)
    mul!(ctx.Fz_pad_rk, rp.forward, ctx.Fz_pad)

    C = ddi.C_dd  # C_dd from unpadded DDIParams; both are constructed with the same value
    # Same unnormalised-brfft + fold-1/N as the unpadded paths (drops 3 cuFFT
    # scaling kernels). Normalisation is 1/prod(padded_shape) for the padded irfft.
    pad_shape = size(ctx.Phi_x_pad)
    _ddi_padded_k_contraction!(ctx, C / prod(pad_shape))
    bp = _get_ddi_brfft_plan(ctx.Phi_x_pad_rk, pad_shape[1])
    mul!(ctx.Phi_x_pad, bp, ctx.Phi_x_pad_rk)
    mul!(ctx.Phi_y_pad, bp, ctx.Phi_y_pad_rk)
    mul!(ctx.Phi_z_pad, bp, ctx.Phi_z_pad_rk)
    nothing
end

"""
Apply DDI step using zero-padded rFFT convolution when DDIPaddedContext is available.
"""
function apply_ddi_step!(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    ddi::DDIParams{N},
    bufs::DDIBuffers,
    dt_frac::Float64,
    ndim::Int,
    ddi_padded::DDIPaddedContext{N};
    imaginary_time::Bool=false,
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {D, N}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    psi_mf_eff = psi_mf === nothing ? psi : psi_mf

    @timeit_debug TIMER "ddi_convolve_padded" _compute_and_convolve_ddi_padded!(
        psi_mf_eff,
        sm,
        ddi,
        ddi_padded,
        Val(D),
        ndim,
        n_pts,
    )

    # Phi_*_pad are 2n-sized (padded) arrays. _apply_ddi_rotation!
    # crops them to psi's physical [1:n...] corner via `_ddi_crop_phi`
    # (rotation.jl) before computing Euler angles. (Pre-2026-06-07 this
    # comment claimed an "implicit crop" via CartesianIndices(n_pts) —
    # true before the 2026-05-10 batched-gemm rewrite, which silently
    # switched to linear indexing and broke 2D/3D: App. A defect 9.)
    @timeit_debug TIMER "ddi_rotation" _apply_ddi_rotation!(
        psi, ddi_padded.Phi_x_pad, ddi_padded.Phi_y_pad, ddi_padded.Phi_z_pad,
        sm, dt_frac, ndim;
        imaginary_time,
    )
    nothing
end

function _ddi_padded_k_contraction!(ctx::DDIPaddedContext, C)
    _ddi_k_contraction_core!(
        ctx.Phi_x_pad_rk, ctx.Phi_y_pad_rk, ctx.Phi_z_pad_rk,
        ctx.Fx_pad_rk, ctx.Fy_pad_rk, ctx.Fz_pad_rk,
        ctx.Q_xx, ctx.Q_xy, ctx.Q_xz, ctx.Q_yy, ctx.Q_yz, ctx.Q_zz,
        C, ctx.rfft_plans.rk_shape, ctx.Fx_pad isa Array,
    )
end
