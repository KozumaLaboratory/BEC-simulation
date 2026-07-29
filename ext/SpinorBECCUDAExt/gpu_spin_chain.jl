# Fused realization of the whole V half-step: diag · SM · DDI · SM · diag.
#
# The contract, the eligibility rules and the reason this is bit-identical to
# applying the five operators separately live in
# `src/hamiltonian/integrator/spin_chain.jl`. This file only supplies the GPU
# realization: the same `_rot_generator` / `_rot_schedule` / `_horner_rot`
# pieces the single-rotation kernel uses, run three times on one register-
# resident amplitude instead of three times through HBM.
#
# The two diagonal halves come along because their phase is IDENTICAL on both
# sides: a spin rotation is unitary, so it leaves the total density Σ_c|ψ_c|²
# alone, and with ψ_mf frozen both diagonal steps read the same density anyway.
# So the voxel phase is computed once, in a prepass over ψ_mf, and multiplied in
# on the way into the kernel and out of it — only the per-component Zeeman
# factor differs between the two sides.
#
# What it removes, per V half-step at D = 13 (i.e. ×4 per RTP step):
#   * 8 ψ passes → 3 (one prepass read of ψ_mf, one read+write here)
#   * 3 spin-density passes over ψ_mf → 1 (⟨F⟩ feeds spin-mixing directly and
#     DDI through the convolution, and the midpoint freezes ψ_mf, so all three
#     substeps were computing the same ⟨F⟩)
#   * 5 kernel launches → 2
#
# A zero-padded (open-boundary) DDI changes none of that. Both ⟨F⟩ and Φ then
# live in the `[1:n_pts...]` corner of the padded buffers, which is one index map
# in the rotation — the same `_voxel_index` the standalone DDI rotation reads
# through — not a reason to unfuse.

@inline function _spin_chain_warp_kernel!(
    P, fx, fy, fz, px, py, pz, vph, zph_fwd, zph_bwd, mz, sxu, syu, rk_sm, rk_dd,
    K::Int32, tol2, F2, rsafe2, ::Val{D}, ::Val{RT}, src,
) where {D, RT}
    T = real(eltype(P))
    CT = Complex{T}
    vox, c, cdn, active = _rot_lane_map(Val(D))
    in_range = vox <= size(P, 1)
    live = active && in_range

    # `src` maps voxel → index in the field buffers, exactly as in
    # `_spin_taylor_warp_kernel!`: `nothing` when ⟨F⟩ and Φ are contiguous, a
    # `CartesianIndices(n_pts)` when they are the corner of a zero-padded DDI
    # buffer. `vph` is this kernel's own scratch and is always contiguous.
    j = in_range ? _voxel_index(src, vox) : _voxel_index(src, 1)
    Fx = in_range ? (@inbounds fx[j]) : zero(T)
    Fy = in_range ? (@inbounds fy[j]) : zero(T)
    Fz = in_range ? (@inbounds fz[j]) : zero(T)
    Px = in_range ? (@inbounds px[j]) : zero(T)
    Py = in_range ? (@inbounds py[j]) : zero(T)
    Pz = in_range ? (@inbounds pz[j]) : zero(T)

    ds, bs, bms, gs = _rot_generator(Fx, Fy, Fz, mz, sxu, syu, c, cdn, F2, Val(16))
    dd, bd, bmd, gd = _rot_generator(Px, Py, Pz, mz, sxu, syu, c, cdn, F2, Val(16))
    hs, shs, kvs = _rot_schedule(gs, rk_sm, K, tol2, rsafe2)
    hd, shd, kvd = _rot_schedule(gd, rk_dd, K, tol2, rsafe2)

    # Associate as `ψ · (vph · zph)`, exactly as `_diag_step_kernel!` does
    # (`P[i, c] *= vph * zph[c]`). Floating-point multiplication is not
    # associative, and this gate demands bit-identity.
    vp = in_range ? (@inbounds vph[vox]) : one(CT)
    w = live ? (@inbounds P[vox, c]) * (vp * (@inbounds zph_fwd[c])) : zero(CT)
    w = _horner_rot(w, ds, bs, bms, c, cdn, rk_sm, kvs, hs, shs, Val(16), Val(RT))
    w = _horner_rot(w, dd, bd, bmd, c, cdn, rk_dd, kvd, hd, shd, Val(16), Val(RT))
    w = _horner_rot(w, ds, bs, bms, c, cdn, rk_sm, kvs, hs, shs, Val(16), Val(RT))

    live && (@inbounds P[vox, c] = w * (vp * (@inbounds zph_bwd[c])))
    nothing
end

SpinorBEC._spin_chain_available(psi::CuArray, ws::SpinorBEC.Workspace) =
    _spin_taylor_plan(psi, ws.spin_matrices) !== nothing

function SpinorBEC._apply_spin_chain!(
    psi::CuArray{Complex{T}}, ws::SpinorBEC.Workspace, dt_half, ndim,
    imaginary_time, ip, psi_mf, zeeman_diag_fwd, zeeman_diag_bwd,
) where {T <: AbstractFloat}
    sm = ws.spin_matrices
    D = sm.system.n_components
    bufs = ws.ddi_bufs
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    it = imaginary_time === true
    dt_outer = T(dt_half) / 2                # the outer chain's substep dt

    # ⟨F⟩(ψ_mf) and Φ_DDI, from ONE spin-density pass feeding both — the point of
    # fusing. The convolution leaves ⟨F⟩ intact, and it is bit-identical to what
    # the separate spin-mixing substep would have computed (same kernel, same
    # coefficients, same frozen ψ_mf).
    #
    # With `ddi_padding` on — which is `DDI_PADDED_DEFAULT`, i.e. every
    # `run_yaml` run — both fields live in the `[1:n_pts...]` corner of the
    # padded buffers rather than in contiguous arrays of their own. That changes
    # where the rotation reads them, which is an index map, not a reason to fall
    # back to five separate operators. The corner ⟨F⟩ is the same kernel over the
    # same values as the contiguous one (`_compute_spin_density!` dispatches on
    # buffer shape and differs only in the destination index), so the
    # bit-identity claim carries over — pinned by
    # `test/gpu/test_gpu_padded_corner_parity.jl` on that side and by the padded
    # arm of the fusion oracle on this one.
    pad = ws.ddi_padded
    if pad === nothing
        SpinorBEC._compute_and_convolve_ddi!(
            psi_mf, sm, ws.ddi, bufs, Val(D), ndim, n_pts)
    else
        SpinorBEC._compute_and_convolve_ddi_padded!(
            psi_mf, sm, ws.ddi, pad, Val(D), ndim, n_pts)
    end

    P = reshape(psi, N, D)
    Pmf = reshape(psi_mf::CuArray{Complex{T}}, N, D)

    # Diagonal phase, once, from the same frozen ψ_mf.
    c_lhy = ws.lhy !== nothing ? ws.lhy : ip.c_lhy
    clhy = c_lhy isa SpinorBEC.ScalarLHY ? T(c_lhy.c_lhy) :
           (c_lhy isa Float64 ? T(c_lhy) : zero(T))
    vph = _get_chain_vph(psi, N)
    threads_v = min(N, 256)
    CUDA.@cuda threads = threads_v blocks = cld(N, threads_v) _diag_phase_kernel!(
        vph, reshape(ws.density_buf, N), Pmf, reshape(ws.potential_values, N),
        T(ip[0]), clhy, dt_outer, Val(D), Val(it))

    zf = _get_diag_zph(psi, zeeman_diag_fwd, dt_outer, it, 1)
    zb = _get_diag_zph(psi, zeeman_diag_bwd, dt_outer, it, 2)

    coef, F = _spin_taylor_plan(psi, sm)
    rk_sm = _get_spin_rk(psi, T(ip[1]) * dt_outer)
    rk_dd = _get_spin_rk(psi, T(dt_half))

    # Two call sites rather than one with a Union-typed field/map tuple, so each
    # launches a concretely-typed kernel — the shape `_ddi_rotate_taylor!` uses
    # for the standalone DDI rotation.
    if pad === nothing
        _launch_spin_chain!(
            P, reshape(bufs.Fx_r, N), reshape(bufs.Fy_r, N), reshape(bufs.Fz_r, N),
            reshape(bufs.Phi_x, N), reshape(bufs.Phi_y, N), reshape(bufs.Phi_z, N),
            vph, zf, zb, coef, rk_sm, rk_dd, F, N, Val(D), it, nothing)
    else
        _launch_spin_chain!(
            P, pad.Fx_pad, pad.Fy_pad, pad.Fz_pad,
            pad.Phi_x_pad, pad.Phi_y_pad, pad.Phi_z_pad,
            vph, zf, zb, coef, rk_sm, rk_dd, F, N, Val(D), it,
            CartesianIndices(n_pts))
    end
    nothing
end

@inline function _launch_spin_chain!(
    P, fx, fy, fz, px, py, pz, vph, zf, zb, coef, rk_sm, rk_dd, F::T, N,
    ::Val{D}, it::Bool, src,
) where {T, D}
    CUDA.@cuda threads = 256 blocks = cld(N, 16) _spin_chain_warp_kernel!(
        P, fx, fy, fz, px, py, pz, vph, zf, zb, coef.mz, coef.sxu, coef.syu,
        rk_sm, rk_dd, Int32(_SPIN_RK_MAX), T(_SPIN_TAYLOR_TOL[])^2, F * F,
        T(_SPIN_TAYLOR_RSAFE[])^2, Val(D), Val(!it), src)
    nothing
end

const _CHAIN_VPH_CACHE = Dict{Tuple{Int, DataType}, Any}()
_get_chain_vph(psi::CuArray{Complex{T}}, N::Int) where {T} =
    get!(() -> similar(psi, Complex{T}, N), _CHAIN_VPH_CACHE, (N, T))::CuArray{Complex{T}, 1}
