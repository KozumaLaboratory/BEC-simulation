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

@inline function _spin_chain_warp_kernel!(
    P, fx, fy, fz, px, py, pz, vph, zph_fwd, zph_bwd, mz, sxu, syu, rk_sm, rk_dd,
    K::Int32, tol2, F2, rsafe2, cap::Int32, ::Val{D}, ::Val{RT},
) where {D, RT}
    T = real(eltype(P))
    CT = Complex{T}
    vox, c, cdn, active = _rot_lane_map(Val(D))
    in_range = vox <= size(P, 1)
    live = active && in_range

    Fx = in_range ? (@inbounds fx[vox]) : zero(T)
    Fy = in_range ? (@inbounds fy[vox]) : zero(T)
    Fz = in_range ? (@inbounds fz[vox]) : zero(T)
    Px = in_range ? (@inbounds px[vox]) : zero(T)
    Py = in_range ? (@inbounds py[vox]) : zero(T)
    Pz = in_range ? (@inbounds pz[vox]) : zero(T)

    ds, bs, bms, gs = _rot_generator(Fx, Fy, Fz, mz, sxu, syu, c, cdn, F2, Val(16))
    dd, bd, bmd, gd = _rot_generator(Px, Py, Pz, mz, sxu, syu, c, cdn, F2, Val(16))
    hs, shs, kvs = _rot_schedule(gs, rk_sm, K, tol2, rsafe2, cap)
    hd, shd, kvd = _rot_schedule(gd, rk_dd, K, tol2, rsafe2, cap)

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

    # ⟨F⟩(ψ_mf) into bufs.F*_r and Φ_DDI into bufs.Phi_* — ONE spin-density
    # pass feeding both, which is the point of fusing. The convolution leaves
    # F*_r intact, and it is bit-identical to what the separate spin-mixing
    # substep would have computed (same kernel, same coefficients, same frozen
    # ψ_mf).
    SpinorBEC._compute_and_convolve_ddi!(
        psi_mf, sm, ws.ddi, bufs, Val(D), ndim, n_pts)

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

    fv = reshape(bufs.Fx_r, N), reshape(bufs.Fy_r, N), reshape(bufs.Fz_r, N)
    pv = _gpu_phi_vec(bufs.Phi_x, n_pts, N),
    _gpu_phi_vec(bufs.Phi_y, n_pts, N),
    _gpu_phi_vec(bufs.Phi_z, n_pts, N)

    CUDA.@cuda threads = 256 blocks = cld(N, 16) _spin_chain_warp_kernel!(
        P, fv..., pv..., vph, zf, zb, coef.mz, coef.sxu, coef.syu, rk_sm, rk_dd,
        Int32(SPIN_TAYLOR_RK_MAX), T(SPIN_TAYLOR_TOL[])^2, F * F,
        T(SPIN_TAYLOR_RSAFE[])^2, Int32(SPIN_TAYLOR_DEGREE_CAP[]), Val(D), Val(!it))
    nothing
end

const _CHAIN_VPH_CACHE = Dict{Tuple{Int, DataType}, Any}()
_get_chain_vph(psi::CuArray{Complex{T}}, N::Int) where {T} =
    get!(() -> similar(psi, Complex{T}, N), _CHAIN_VPH_CACHE, (N, T))::CuArray{Complex{T}, 1}
