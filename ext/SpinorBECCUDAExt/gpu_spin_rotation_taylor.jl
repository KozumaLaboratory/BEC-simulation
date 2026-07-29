# Shared GPU propagator for a spin rotation `exp(z · (v·F)) ψ`, per voxel.
#
# Three substeps in the V half-step apply exactly this operator and differ only
# in what supplies the vector field `v(r)` and the scalar `z`:
#
#   DDI          v = Φ(r)        (dipolar field)      z = -i·dt
#   spin-mixing  v = c₁⟨F⟩(r)    (contact spin field) z = -i·dt
#   Raman        v = Ω(r)        (coupling field)     z = -i·dt
#
# so they share one kernel rather than one per term. The generator A = v·F is
# Hermitian TRIDIAGONAL in the F_z basis (F_z diagonal, F_x/F_y ladder bands),
# built here directly from `sm.Fx/Fy/Fz` — the single physics declaration, no
# second statement of the spin algebra.
#
# `exp(zA)ψ` is evaluated by Taylor–Horner: w ← ψ; for k = K..1, w ← ψ + (z/k)(A·w).
# `A·w` is a nearest-neighbour `shfl` matvec, warp-cooperative with one spin
# component per lane, so there is no local-memory spill at D = 13, no D×D
# eigenvector matrices, and no atan/acos. The degree is chosen PER VOXEL from
# the backward-error bound R^{K+1}/(K+1)! ≤ tol with that voxel's own
# R = |z|·|v(r)|·F; at the Eu production peak R ≈ 0.01–0.2 that is K ≈ 2–6.
#
# The alternative realization — the exact Euler 5-stage
# (`apply_ddi_euler_fused_kernel!` / `apply_euler_5stage_fused_kernel!`) — stays
# as the D > 16 fallback and as the parity reference. It is
# machine-precision at every R, and ~3.6× slower at D = 13 (measured 64³ Eu:
# 10.3 ms vs 2.85 ms per call), because it moves ψ through HBM nine times
# (5 phase stages + 4 gemms) where Horner moves it twice.

using StaticArrays: SVector

# --- Tridiagonal generator coefficients (DEVICE arrays) ---
# Held as small CuArrays, NOT by-value SVectors: each lane loads only its own
# (mz_c, sxu_c, syu_c) via a cached global read. A by-value SVector indexed by
# the lane-dependent component would stage all D entries into per-thread local
# memory and was measured ~4× slower (gotcha_warp_kernel_byvalue_svector…).
struct SpinTridiagCoef{T}
    mz::CuArray{T, 1}               # F_z diagonal m_c
    sxu::CuArray{Complex{T}, 1}     # F_x super-diagonal [c,c+1] (0 at c=D)
    syu::CuArray{Complex{T}, 1}     # F_y super-diagonal [c,c+1] (0 at c=D)
end

const _SPIN_TRIDIAG_CACHE = Dict{UInt64, Any}()

function _get_spin_tridiag_coef(
    ::CuArray{Complex{T}}, sm::SpinorBEC.SpinMatrices{D},
) where {D, T <: AbstractFloat}
    key = hash((objectid(sm), D, T))
    c = get(_SPIN_TRIDIAG_CACHE, key, nothing)
    c !== nothing && return c::SpinTridiagCoef{T}
    Fx = sm.Fx
    Fy = sm.Fy
    Fz = sm.Fz
    mz = T[T(real(Fz[i, i])) for i in 1:D]
    sxu = Complex{T}[i < D ? Complex{T}(Fx[i, i + 1]) : zero(Complex{T}) for i in 1:D]
    syu = Complex{T}[i < D ? Complex{T}(Fy[i, i + 1]) : zero(Complex{T}) for i in 1:D]
    coef = SpinTridiagCoef{T}(CuArray(mz), CuArray(sxu), CuArray(syu))
    _SPIN_TRIDIAG_CACHE[key] = coef
    coef
end

# --- Accuracy contract ---
#
# The degree and, above `_SPIN_TAYLOR_RSAFE[]`, the angle halving are decided
# PER VOXEL inside the kernel from that voxel's own `R = |scale|·|v(r)|·F`.
# Nothing about the field is needed on the host.
#
# That is a performance property, not a cosmetic one. The previous design read
# `R = max_r |v(r)|` back to the host to pick one degree for the whole array —
# a device-to-host reduction, i.e. a full stream drain, once per rotation and so
# 12× per RTP step. Measured on an RTX 5070 Ti at 64³ (bench/rtp_sync_ab.jl):
# 50.4 → 27.3 ms/step, 46 % of the step spent with the GPU idle waiting for the
# host. It was also pessimistic in the other direction — a trapped cloud is
# mostly dilute tail, and paying the peak's degree everywhere is most of the
# arithmetic (bench/micro_spin_taylor.jl).
const _SPIN_TAYLOR_ENABLED = Ref(true)
const _SPIN_TAYLOR_TOL = Ref(1.0e-13)  # backward-error target
# 1e-13 because the per-voxel degree made this number BINDING. It used to be
# slack: one degree was chosen from max|v| and then applied everywhere, so
# every voxel below the peak got far more accuracy than 1e-9 asked for, and the
# delivered norm drift was 3e-15 - 7e-14 per rotation. Choosing per voxel
# collects that slack as speed — and at 1e-9 the drift duly rose to 9.6e-13,
# a hundredfold, while still satisfying the stated contract. That is the
# failure mode of a tolerance nobody was standing on.
#
# Measured at 64³ D=13, peak R ≈ 0.8 (norm drift per rotation / rel-vs-Euler):
#   1e-9  → 9.6e-13 / 4.3e-12      1e-11 → 2.1e-15 / 3.8e-14
#   1e-13 → 2.2e-16 / 3.0e-15      1e-15 → 2.2e-16 / 3.0e-15  (saturated)
# so 1e-13 buys machine precision — better than the pre-per-voxel code — and
# tightening past it buys nothing. Measured cost of the extra degrees: 1.088×
# at 64³ on a card where the Horner is FP64-compute-bound, and 1.024× at 128³
# on an H100 (14.224 → 14.566 ms/step) where the kernel is memory-bound and the
# degree is nearly free. The parity gate is the safety net: relax this and the
# machine-precision norm bound in
# `test/gpu/test_gpu_spin_rotation_taylor_parity.jl` goes red.
#
# Angle above which a voxel halves its rotation and applies it twice (repeated
# squaring). Production R is 0.01–0.2 so no voxel ever halves; the branch exists
# so that the Taylor path is exact at ANY R and the caller never has to ask.
# 1.0 keeps the degree at ≤ 12 for tol = 1e-9, comfortably inside the table.
const _SPIN_TAYLOR_RSAFE = Ref(1.0)

# --- Horner coefficient table ---
# `w ← ψ + (z/k)(A·w)` needs z/k for k = K…1. Computed per call as a device
# vector rather than in the loop body: `z/T(k)` is TWO FP64 divisions, and the
# kernel is compute-bound (bench/micro_spin_taylor.jl measures time exactly
# linear in K with a zero memory intercept, so every op in the body is on the
# critical path). `z` is purely imaginary in real time and purely real in
# imaginary time, so the table is REAL — `scale/k`, sign included — and the
# multiply by ∓i is folded into the body as a component swap. That removes
# 2 divisions + 2 multiplies + 2 additions per degree per lane.
#
# Values are identical to what the in-body expression produced: for real time
# `Complex(0,-scale/k)·(a+bi) = (scale/k)·(b - ai)` exactly, and likewise for
# imaginary time. Filled by a device kernel (no host allocation, no HtoD).
#
# `_SPIN_RK_MAX = 40` is the degree ceiling. With the halving above it is never
# approached: R ≤ 1 needs 12 terms at tol = 1e-9 and 24 at tol = 1e-24.
const _SPIN_RK_MAX = 40
# Keyed by the SCALE, not just the eltype: a fixed-dt run uses a handful of
# distinct scales (c₁·τ/2 and τ for each of the predictor's and corrector's
# half-steps) and then never refills. That matters out of proportion to the
# kernel's size — an empty launch costs 32-190 µs under WSL2's paravirtualised
# submission path, so eight 40-thread launches per step were ~0.5 ms of pure
# overhead. An adaptive-dt run will miss; the cache is cleared past a bound so
# it cannot grow without limit.
const _SPIN_RK_CACHE = Dict{Tuple{DataType, Float64}, Any}()
const _SPIN_RK_CACHE_MAX = 64

function _fill_rk_kernel!(rk, scale::T) where {T}
    k = CUDA.threadIdx().x
    @inbounds rk[k] = scale / T(k)
    nothing
end

function _get_spin_rk(::CuArray{Complex{T}}, scale::T) where {T}
    key = (T, Float64(scale))
    hit = get(_SPIN_RK_CACHE, key, nothing)
    hit !== nothing && return hit::CuArray{T, 1}
    length(_SPIN_RK_CACHE) >= _SPIN_RK_CACHE_MAX && empty!(_SPIN_RK_CACHE)
    rk = CUDA.zeros(T, _SPIN_RK_MAX)
    CUDA.@cuda threads = _SPIN_RK_MAX blocks = 1 _fill_rk_kernel!(rk, scale)
    _SPIN_RK_CACHE[key] = rk
    rk
end

# --- Taylor–Horner pieces (one spin component per lane) ---
#
# Declared once here as three `@inline` steps, so the single-rotation kernel and
# the fused half-step kernel (gpu_spin_chain.jl) run the SAME Horner rather than
# two statements of it.
#
#   _rot_generator  build the tridiagonal A = v·F for this lane, and |v|²F²
#   _rot_schedule   pick this voxel's angle halving and Horner degree
#   _horner_rot     apply exp(z·A) to one lane's amplitude
#
# `RT` selects the real-time (multiply by -i) vs imaginary-time (real weight)
# form of the Horner coefficient; both read the same real `rk` table.
#
# The load/store keeps the compute layout's addressing — a lane reads P[vox, c]
# with the D components N·16 B apart. Staging ψ through shared memory so the
# load/store run over consecutive VOXELS instead was tried and measured 5-15 %
# SLOWER at 64³ D=13 (1.21 → 1.27-1.37 ms): the kernel is not actually limited
# by that pattern. `CUDA.registers` says 48 with no spill, so it is not
# occupancy-limited either — at production degrees ~74 % of this card's FP64
# peak is in the Horner body itself.

# A = v·F is Hermitian tridiagonal in the F_z basis. Returns this lane's
# diagonal entry, its super-diagonal entry A[c,c+1], the conjugate of the
# sub-diagonal entry A[c-1,c] (shuffled down from lane c-1), and g = |v|²F².
@inline function _rot_generator(
    Vx::T, Vy::T, Vz::T, mz, sxu, syu, c, cdn, F2, ::Val{W},
) where {T, W}
    CT = Complex{T}
    diag_c = Vz * (@inbounds mz[c])                          # real F_z diagonal
    b_c = Vx * (@inbounds sxu[c]) + Vy * (@inbounds syu[c])  # A[c,c+1]
    # lower coupling conj(A[c-1,c]) = conj(b_{c-1}); b_{c-1} from lane c-1
    bm_raw = _shfl_c(b_c, cdn, Val(W))
    bm = c > 1 ? bm_raw : zero(CT)
    (diag_c, b_c, conj(bm), (Vx * Vx + Vy * Vy + Vz * Vz) * F2)
end

# Each voxel sizes its own rotation from its own R = |scale|·|v(r)|·F:
#
#   1. halve the angle `s` times until R/2^s ≤ √rsafe2 — the halved rotation is
#      then applied 2^s times (repeated squaring; exact, and s = 0 in production);
#   2. take the smallest degree k ≥ 2 with (R/2^s)^k/k! ≤ tol.
#
# Both tests run on SQUARES so no FP64 sqrt is needed: (R/2^s/k)² = (rk[k]·h)²·g
# with g = |v|²F² and h = 2^-s.
#
# `s` and the degree are raised to the WARP maximum. `_shfl_c` carries a
# full-warp mask, so the two voxels sharing a warp must execute the same trip
# count or the `shfl_sync` deadlocks; neighbouring voxels pick near-identical
# values, so rounding up costs almost nothing.
@inline function _rot_schedule(g::T, rk, K::Int32, tol2, rsafe2) where {T}
    scale1 = @inbounds rk[1]        # rk[1] = scale ⇒ r2 starts as R²
    r2 = scale1 * scale1 * g
    sh = zero(Int32)
    while r2 > rsafe2 && sh < Int32(30)
        r2 *= T(0.25)
        sh += one(Int32)
    end
    sh = max(sh, CUDA.shfl_xor_sync(0xffffffff, sh, 16))
    h = one(T)
    for _ in one(Int32):sh
        h *= T(0.5)
    end
    gh = g * h * h

    kv = K
    u = one(T)
    kk = one(Int32)
    while kk < K
        a = @inbounds rk[kk]
        u *= a * a * gh
        if kk >= Int32(2) && u <= tol2
            kv = kk
            break
        end
        kk += one(Int32)
    end
    (h, sh, max(kv, CUDA.shfl_xor_sync(0xffffffff, kv, 16)))
end

# `w ← exp(z·A) w`. The halving `h` is folded ONCE into the generator rather
# than into every Horner coefficient, so the inner loop is byte-for-byte the
# loop it was before the halving existed and the h = 1 case is bit-identical.
@inline function _horner_rot(
    w0::CT, diag_c, b_c, bmc, c, cdn, rk, kv::Int32, h, sh::Int32,
    ::Val{W}, ::Val{RT},
) where {CT, W, RT}
    dg = diag_c * h
    bu = b_c * h
    bd = bmc * h
    w = w0
    rep = one(Int32) << sh
    while rep >= one(Int32)
        base = w
        wk = base
        k = kv
        while k >= one(Int32)
            wup = _shfl_c(wk, c + 1, Val(W))             # w_{c+1} (idle→0 at c=D)
            wdn_raw = _shfl_c(wk, cdn, Val(W))
            wdn = c > 1 ? wdn_raw : zero(CT)
            Aw = dg * wk + bu * wup + bd * wdn
            a = @inbounds rk[k]
            # RT: (0 - i·a)·Aw = a·(imag(Aw) - i·real(Aw));  IT: (-a)·Aw
            wk = RT ? base + a * CT(imag(Aw), -real(Aw)) : base - a * Aw
            k -= one(Int32)
        end
        w = wk
        rep -= one(Int32)
    end
    w
end

# Lane → (voxel, spin component) for the width-16 subgroup layout. Two voxels
# per warp; lanes at or above D are idle passengers (their `b_c` is multiplied
# by sxu[D] = syu[D] = 0 at the top edge, so they cannot contaminate c = D).
@inline function _rot_lane_map(::Val{D}) where {D}
    tib = CUDA.threadIdx().x
    lane0 = (tib - 1) & 31
    sl = lane0 & 15
    gwarp = (CUDA.blockIdx().x - 1) * (CUDA.blockDim().x >> 5) + ((tib - 1) >> 5)
    vox = gwarp * 2 + (lane0 >> 4) + 1
    active = sl < D
    c = active ? sl + 1 : 1
    (vox, c, c > 1 ? c - 1 : 1, active)
end

@inline function _spin_taylor_warp_kernel!(
    P, vx, vy, vz, mz, sxu, syu, rk, K::Int32, tol2, F2, rsafe2, ::Val{D}, ::Val{RT},
    src,
) where {D, RT}
    T = real(eltype(P))
    CT = Complex{T}
    vox, c, cdn, active = _rot_lane_map(Val(D))
    in_range = vox <= size(P, 1)
    live = active && in_range

    # `src` maps voxel → index in the field buffers: `nothing` when they are
    # contiguous (spin-mixing, Raman, unpadded DDI), a `CartesianIndices(n_pts)`
    # when the field is the corner of a zero-padded DDI buffer. Reading through
    # it is what lets the padded DDI skip materialising a cropped copy of Φ.
    j = in_range ? _voxel_index(src, vox) : _voxel_index(src, 1)
    Vx = in_range ? (@inbounds vx[j]) : zero(T)
    Vy = in_range ? (@inbounds vy[j]) : zero(T)
    Vz = in_range ? (@inbounds vz[j]) : zero(T)

    diag_c, b_c, bmc, g = _rot_generator(Vx, Vy, Vz, mz, sxu, syu, c, cdn, F2, Val(16))
    h, sh, kv = _rot_schedule(g, rk, K, tol2, rsafe2)

    psi0 = live ? (@inbounds P[vox, c]) : zero(CT)
    w = _horner_rot(psi0, diag_c, b_c, bmc, c, cdn, rk, kv, h, sh, Val(16), Val(RT))

    live && (@inbounds P[vox, c] = w)
    nothing
end

"""
    _apply_spin_rotation_taylor!(P, vx, vy, vz, coef, scale, Val(D); imaginary_time)

`P[vox, :] ← exp(z · (v(vox)·F)) · P[vox, :]` for every voxel, degree-`K`
Taylor–Horner, with `z = -i·scale` (real time) or `-scale` (imaginary time).
`P` is the `(N_spatial, D)` reshape of ψ.

`src_idx` (default `nothing`) maps voxel → index in `vx/vy/vz` for callers whose
field lives in the corner of a larger buffer; see `gpu_index_map.jl`.
"""
function _apply_spin_rotation_taylor!(
    P, vx, vy, vz, coef::SpinTridiagCoef{T}, scale::T, ::Val{D};
    imaginary_time::Bool=false, F::T=one(T), src_idx=nothing,
) where {T, D}
    N = size(P, 1)
    voxels_per_block = 16
    threads = 256
    blocks = cld(N, voxels_per_block)
    rk = _get_spin_rk(P, scale)
    tol2 = T(_SPIN_TAYLOR_TOL[])^2
    rsafe2 = T(_SPIN_TAYLOR_RSAFE[])^2
    CUDA.@cuda threads = threads blocks = blocks _spin_taylor_warp_kernel!(
        P, vx, vy, vz, coef.mz, coef.sxu, coef.syu, rk, Int32(_SPIN_RK_MAX),
        tol2, F * F, rsafe2, Val(D), Val(!imaginary_time), src_idx)
    nothing
end

"""
    _spin_taylor_plan(psi, sm, scale) -> (coef, F) or nothing

Shared entry decision for the three call sites. Returns `nothing` only when the
Taylor path is switched off or the spinor is too wide for the warp layout, in
which case the caller uses its exact Euler realization. It does NOT inspect the
field: degree and angle halving are per-voxel decisions made inside the kernel,
so this costs no device reduction and no host stall.

`scale` is the real prefactor multiplying `(v·F)` in the exponent — `dt` for
DDI, `c₁·dt` for spin-mixing. Real time means `exp(-i·scale·(v·F))` and
imaginary time `exp(-scale·(v·F))`; the kernel's `Val{RT}` picks which.
"""
function _spin_taylor_plan(
    psi::CuArray{Complex{T}}, sm::SpinorBEC.SpinMatrices{D},
) where {T <: AbstractFloat, D}
    _SPIN_TAYLOR_ENABLED[] || return nothing
    # The warp layout puts one spin component per lane of a width-16 subgroup,
    # so D > 16 (F ≥ 8) has no lane to hold the upper components. Fall back.
    D <= 16 || return nothing
    (_get_spin_tridiag_coef(psi, sm), T(sm.system.F))
end
