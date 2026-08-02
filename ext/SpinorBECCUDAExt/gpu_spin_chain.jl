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
# What it removes, per V half-step at D = 13. A plain `split_step!` takes two of
# them per V half (predictor + corrector, n_picard = 1) and two V halves, so ×4
# per RTP step:
#   * 8 ψ passes → 2 (one prepass read of ψ_mf, one read+write here)
#   * 3 spin-density passes over ψ_mf → 1 (⟨F⟩ feeds spin-mixing directly and
#     DDI through the convolution, and the midpoint freezes ψ_mf, so all three
#     substeps were computing the same ⟨F⟩)
#   * 5 kernel launches → 2
#
# Every lane reads its own (voxel, component) once, before it writes it, so the
# kernel takes a separate SOURCE array at no cost. That is what lets the Picard
# midpoint hand its ψ_orig in as `Pin` instead of memcpy-ing it into the scratch
# buffer first — see `_half_potential_step_midpoint!`.
#
# A zero-padded (open-boundary) DDI changes none of that. Both ⟨F⟩ and Φ then
# live in the `[1:n_pts...]` corner of the padded buffers, which is one index map
# in the rotation — the same `_voxel_index` the standalone DDI rotation reads
# through — not a reason to unfuse.

using StaticArrays: SVector

@inline function _spin_chain_warp_kernel!(
    P, fx, fy, fz, px, py, pz, vph, zph_fwd, zph_bwd, mz, sxu, syu, rk_sm, rk_dd,
    K::Int32, tol2, F2, rsafe2, cap::Int32, ::Val{D}, ::Val{RT}, src, Pin,
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
    hs, shs, kvs = _rot_schedule(gs, rk_sm, K, tol2, rsafe2, cap)
    hd, shd, kvd = _rot_schedule(gd, rk_dd, K, tol2, rsafe2, cap)

    # Associate as `ψ · (vph · zph)`, exactly as `_diag_step_kernel!` does
    # (`P[i, c] *= vph * zph[c]`). Floating-point multiplication is not
    # associative, and this gate demands bit-identity.
    vp = in_range ? (@inbounds vph[vox]) : one(CT)
    w = live ? (@inbounds Pin[vox, c]) * (vp * (@inbounds zph_fwd[c])) : zero(CT)
    w = _horner_rot(w, ds, bs, bms, c, cdn, rk_sm, kvs, hs, shs, Val(16), Val(RT))
    w = _horner_rot(w, dd, bd, bmd, c, cdn, rk_dd, kvd, hd, shd, Val(16), Val(RT))
    w = _horner_rot(w, ds, bs, bms, c, cdn, rk_sm, kvs, hs, shs, Val(16), Val(RT))

    live && (@inbounds P[vox, c] = w * (vp * (@inbounds zph_bwd[c])))
    nothing
end

# ⟨F⟩(ψ_mf) and the diagonal voxel phase, from ONE pass over ψ_mf.
#
# `_spin_density_kernel!` and `_diag_phase_kernel!` are both per-voxel reductions
# over the same D components of the same array, and the half-step launched them
# back to back with the same geometry — so the second re-read from HBM a sum the
# first already had in registers (Σ_c|ψ_c|² is a term of both). At 128³ D = 13
# F64 that re-read is 436 MB, four times per RTP step.
#
# Each accumulator is written exactly as its own kernel writes it — same terms,
# same order — so the fused result is bit-identical rather than merely close, and
# the fusion oracle asserts that with `==`. `dst` is the same voxel → buffer map
# `_spin_density_kernel!` takes, so the padded corner is one argument, not a
# second kernel.
@inline function _chain_prepass_kernel!(
    Fx, Fy, Fz, vph, db, Pmf, Vt, m_vals, fp, c0::T, clhy::T, dt::T,
    ::Val{D}, ::Val{IT}, dst,
) where {T, D, IT}
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > size(Pmf, 1) && return nothing
    n = zero(T)
    fz = zero(T)
    fxr = zero(T)
    fyi = zero(T)
    prev = @inbounds Pmf[i, 1]
    n += abs2(prev)
    fz += m_vals[1] * abs2(prev)
    @inbounds for c in 2:D
        cur = Pmf[i, c]
        n += abs2(cur)
        fz += m_vals[c] * abs2(cur)
        pr = conj(prev) * cur
        fxr += fp[c] * real(pr)
        fyi += fp[c] * imag(pr)
        prev = cur
    end
    lhy = clhy == zero(T) ? zero(T) : clhy * n * sqrt(n)
    varg = (@inbounds(Vt[i]) + c0 * n + lhy) * dt
    @inbounds begin
        j = _voxel_index(dst, i)
        Fx[j] = fxr
        Fy[j] = fyi
        Fz[j] = fz
        db[i] = n
        vph[i] = IT ? Complex{T}(exp(-varg), zero(T)) : cis(-varg)
    end
    return nothing
end

@inline function _launch_chain_prepass!(
    Fx, Fy, Fz, vph, db, Pmf, Vt, m_vals, fp, c0::T, clhy::T, dt::T,
    ::Val{D}, it::Bool, dst, N,
) where {T, D}
    threads = min(N, 256)
    CUDA.@cuda threads = threads blocks = cld(N, threads) _chain_prepass_kernel!(
        Fx, Fy, Fz, vph, db, Pmf, Vt, m_vals, fp, c0, clhy, dt,
        Val(D), Val(it), dst)
    nothing
end

# Tabulated LHY in the fused chain.
#
# `_spin_chain_reason` used to decline every `TabulatedLHY` — "a tabulated LHY is
# not the closed-form diagonal phase" — and since EVERY production Eu run is
# tabulated (polar_contact / icosahedral / full_bdg / …), no production run has
# ever taken the fused half-step. That is the same bound the fused DIAGONAL
# kernel carried until 2026-07-28, and it is closed the same way: the table is a
# lookup, not a different phase.
#
# `_lhy_interp_uniform` is the SAME device lookup the generic path and the fused
# diagonal both call, so the three cannot disagree about the table.
#
# Note what the old bound was protecting: `clhy` above collapses a non-scalar
# `c_lhy` to `zero(T)`, so a table reaching that kernel would have run with NO
# LHY and said nothing — the exact defect that hit the GPU diagonal. The refusal
# was load-bearing, which is why this adds a path rather than widening `clhy`.
@inline function _chain_prepass_kernel_tab!(
    Fx, Fy, Fz, vph, db, Pmf, Vt, m_vals, fp, c0::T, dt::T,
    x0::T, dxi::T, ys, m::Int32, ::Val{D}, ::Val{IT}, dst,
) where {T, D, IT}
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > size(Pmf, 1) && return nothing
    n = zero(T)
    fz = zero(T)
    fxr = zero(T)
    fyi = zero(T)
    prev = @inbounds Pmf[i, 1]
    n += abs2(prev)
    fz += m_vals[1] * abs2(prev)
    @inbounds for c in 2:D
        cur = Pmf[i, c]
        n += abs2(cur)
        fz += m_vals[c] * abs2(cur)
        pr = conj(prev) * cur
        fxr += fp[c] * real(pr)
        fyi += fp[c] * imag(pr)
        prev = cur
    end
    lhy = _lhy_interp_uniform(n, x0, dxi, ys, Int(m))
    varg = (@inbounds(Vt[i]) + c0 * n + lhy) * dt
    @inbounds begin
        j = _voxel_index(dst, i)
        Fx[j] = fxr
        Fy[j] = fyi
        Fz[j] = fz
        db[i] = n
        vph[i] = IT ? Complex{T}(exp(-varg), zero(T)) : cis(-varg)
    end
    nothing
end

@inline function _launch_chain_prepass_tab!(
    Fx, Fy, Fz, vph, db, Pmf, Vt, m_vals, fp, c0::T, dt::T,
    x0::T, dxi::T, ys, m::Int32, ::Val{D}, it::Bool, dst, N,
) where {T, D}
    threads = min(N, 256)
    CUDA.@cuda threads = threads blocks = cld(N, threads) _chain_prepass_kernel_tab!(
        Fx, Fy, Fz, vph, db, Pmf, Vt, m_vals, fp, c0, dt,
        x0, dxi, ys, m, Val(D), Val(it), dst)
    nothing
end

"""Device table for the fused chain, or `nothing` when the LHY is not tabulated.

Returns the same `(x0, dx, ys, m)` quadruple the fused diagonal uses, from the
same cache — one upload per table `objectid`, not one per step.
"""
function _chain_lhy_table(c_lhy, ::Type{T}, proto::CUDA.CuArray) where {T}
    c_lhy isa SpinorBEC.TabulatedLHY || return nothing
    xs = c_lhy.densities
    m = length(xs)
    m >= 2 || return nothing
    _assert_uniform_lhy_grid(xs, m)
    (T(xs[1]), T(xs[2] - xs[1]), _device_lhy_table(c_lhy, T, proto), Int32(m))
end

SpinorBEC._spin_chain_available(psi::CuArray, ws::SpinorBEC.Workspace) =
    _spin_taylor_plan(psi, ws.spin_matrices) !== nothing

function SpinorBEC._apply_spin_chain!(
    psi::CuArray{Complex{T}}, ws::SpinorBEC.Workspace, dt_half, ndim,
    imaginary_time, ip, psi_mf, zeeman_diag_fwd, zeeman_diag_bwd,
    psi_in::CuArray{Complex{T}}=psi,
) where {T <: AbstractFloat}
    sm = ws.spin_matrices
    D = sm.system.n_components
    bufs = ws.ddi_bufs
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    it = imaginary_time === true
    dt_outer = T(dt_half) / 2                # the outer chain's substep dt

    # ⟨F⟩(ψ_mf) feeds the two spin-mixing rotations directly AND the convolution
    # on its way to Φ, and the midpoint freezes ψ_mf, so all three substeps want
    # the same field — that is the point of fusing. It is bit-identical to what
    # the separate spin-mixing substep computes: same terms, same order, same
    # frozen ψ_mf.
    #
    # With `ddi_padding` on — which is `DDI_PADDED_DEFAULT`, i.e. every `run_yaml`
    # run — ⟨F⟩ and Φ live in the `[1:n_pts...]` corner of the padded buffers
    # rather than in contiguous arrays of their own. That changes where they are
    # written and read, which is an index map, not a reason to fall back to five
    # separate operators. `_compute_spin_density!` dispatches on buffer shape and
    # differs only in that index, so the corner and contiguous forms are the same
    # kernel over the same values — `test/gpu/test_gpu_padded_corner_parity.jl`
    # asserts that with `==`, and the padded arm of the fusion oracle asserts the
    # consequence here.
    pad = ws.ddi_padded

    P = reshape(psi, N, D)
    Pin = psi_in === psi ? P : reshape(psi_in, N, D)
    Pmf = reshape(psi_mf::CuArray{Complex{T}}, N, D)

    c_lhy = ws.lhy !== nothing ? ws.lhy : ip.c_lhy
    clhy = c_lhy isa SpinorBEC.ScalarLHY ? T(c_lhy.c_lhy) :
           (c_lhy isa Float64 ? T(c_lhy) : zero(T))
    vph = _get_chain_vph(psi, N)
    db = reshape(ws.density_buf, N)
    Vt = reshape(ws.potential_values, N)
    m_vals = SVector{D, T}(ntuple(c -> T(sm.system.F - (c - 1)), Val(D)))
    fp = SVector{D, T}(SpinorBEC.fp_ladder_coeffs(T, sm.system.F, Val(D)))

    # One pass over ψ_mf for ⟨F⟩ and the diagonal phase, then the k-space half of
    # the convolution on the ⟨F⟩ just written. Two call sites rather than one
    # with a Union-typed buffer/map tuple, so each launches a concretely-typed
    # kernel.
    tab = _chain_lhy_table(c_lhy, T, psi)
    if pad === nothing
        if tab === nothing
            _launch_chain_prepass!(
                reshape(bufs.Fx_r, N), reshape(bufs.Fy_r, N), reshape(bufs.Fz_r, N),
                vph, db, Pmf, Vt, m_vals, fp, T(ip[0]), clhy, dt_outer,
                Val(D), it, nothing, N)
        else
            _launch_chain_prepass_tab!(
                reshape(bufs.Fx_r, N), reshape(bufs.Fy_r, N), reshape(bufs.Fz_r, N),
                vph, db, Pmf, Vt, m_vals, fp, T(ip[0]), dt_outer,
                tab..., Val(D), it, nothing, N)
        end
        SpinorBEC._convolve_ddi!(ws.ddi, bufs, n_pts)
    else
        if tab === nothing
            _launch_chain_prepass!(
                pad.Fx_pad, pad.Fy_pad, pad.Fz_pad,
                vph, db, Pmf, Vt, m_vals, fp, T(ip[0]), clhy, dt_outer,
                Val(D), it, CartesianIndices(n_pts), N)
        else
            _launch_chain_prepass_tab!(
                pad.Fx_pad, pad.Fy_pad, pad.Fz_pad,
                vph, db, Pmf, Vt, m_vals, fp, T(ip[0]), dt_outer,
                tab..., Val(D), it, CartesianIndices(n_pts), N)
        end
        SpinorBEC._convolve_ddi_padded!(ws.ddi, pad)
    end

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
            vph, zf, zb, coef, rk_sm, rk_dd, F, N, Val(D), it, nothing, Pin)
    else
        _launch_spin_chain!(
            P, pad.Fx_pad, pad.Fy_pad, pad.Fz_pad,
            pad.Phi_x_pad, pad.Phi_y_pad, pad.Phi_z_pad,
            vph, zf, zb, coef, rk_sm, rk_dd, F, N, Val(D), it,
            CartesianIndices(n_pts), Pin)
    end
    nothing
end

@inline function _launch_spin_chain!(
    P, fx, fy, fz, px, py, pz, vph, zf, zb, coef, rk_sm, rk_dd, F::T, N,
    ::Val{D}, it::Bool, src, Pin,
) where {T, D}
    CUDA.@cuda threads = 256 blocks = cld(N, 16) _spin_chain_warp_kernel!(
        P, fx, fy, fz, px, py, pz, vph, zf, zb, coef.mz, coef.sxu, coef.syu,
        rk_sm, rk_dd, Int32(SPIN_TAYLOR_RK_MAX), T(SPIN_TAYLOR_TOL[])^2, F * F,
        T(SPIN_TAYLOR_RSAFE[])^2, Int32(SPIN_TAYLOR_DEGREE_CAP[]), Val(D),
        Val(!it), src, Pin)
    nothing
end

const _CHAIN_VPH_CACHE = Dict{Tuple{Int, DataType}, Any}()
_get_chain_vph(psi::CuArray{Complex{T}}, N::Int) where {T} =
    get!(() -> similar(psi, Complex{T}, N), _CHAIN_VPH_CACHE, (N, T))::CuArray{Complex{T}, 1}
