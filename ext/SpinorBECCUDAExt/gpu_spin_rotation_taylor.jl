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
# eigenvector matrices, and no atan/acos. The degree K is chosen per call from
# the backward-error bound R^{K+1}/(K+1)! ≤ tol with R = |z|·max|v|·F; at the Eu
# production R ≈ 0.01–0.2 that is K ≈ 4–9.
#
# The alternative realization — the exact Euler 5-stage
# (`apply_ddi_euler_fused_kernel!` / `apply_euler_5stage_fused_kernel!`) — stays
# as the fallback above `_SPIN_TAYLOR_RMAX[]` and as the parity reference. It is
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

# --- Adaptive degree selection ---
const _SPIN_TAYLOR_ENABLED = Ref(true)
const _SPIN_TAYLOR_RMAX = Ref(1.0)     # R above which we fall back to Euler
const _SPIN_TAYLOR_TOL = Ref(1.0e-9)   # backward-error target
# 1e-9 measured: parity vs the Euler-exact CPU rotation 3.5e-13, ≈300× under the
# 1e-10 GPU=CPU gate. The first omitted term R^{K+1}/(K+1)! is ~2e-12 per
# rotation at production R, i.e. 6-7 orders below the split-step's own O(dt²)
# error. The parity gate is the safety net: relax too far and it goes red.
const _SPIN_TAYLOR_R_OVERRIDE = Ref(NaN)   # set to skip the max|v| reduction

# smallest K with R^K/K! ≤ tol (⇒ omitted term R^{K+1}/(K+1)! < tol), K ≥ 2.
function _taylor_degree(R::Real, tol::Real)
    t = 1.0
    k = 0
    while k < 40
        k += 1
        t *= R / k
        t <= tol && return max(k, 2)
    end
    return 40
end

# Reused scratch for the |v|² max-reduction, keyed by (length, T). Avoids the
# ~N·8 B temporary that `maximum(vx.*vx .+ …)` allocates on every rotation call
# (16.7 MB × 2/step at 128³). R is bit-identical → K unchanged → gates trivially
# pass; this only removes transient allocation (gpu_allocs_bytes ratchet).
const _SPIN_R_SCRATCH = Dict{Tuple{Int, DataType}, Any}()

"""
    _spin_rotation_R(vx, vy, vz, scale, F) -> R

Spectral radius of `scale·(v·F)`: `scale · max_r|v(r)| · F`. Drives the Taylor
degree; `scale` is `|z|` (i.e. dt for DDI, |c₁|·dt for spin-mixing).
"""
function _spin_rotation_R(vx, vy, vz, scale::T, F::T) where {T <: AbstractFloat}
    s = get!(() -> similar(vx, T, length(vx)), _SPIN_R_SCRATCH, (length(vx), T))
    s .= vx .* vx .+ vy .* vy .+ vz .* vz   # in-place into reused scratch, no temp
    scale * sqrt(maximum(s)) * F
end

# --- Taylor–Horner warp kernel (one spin component per lane) ---
@inline function _spin_taylor_warp_kernel!(
    P, vx, vy, vz, mz, sxu, syu, z::Complex{T}, K::Int32, ::Val{D},
) where {T, D}
    CT = Complex{T}
    W = 16
    tib = CUDA.threadIdx().x
    lane0 = (tib - 1) & 31
    sg = lane0 >> 4
    sl = lane0 & 15
    warp_in_block = (tib - 1) >> 5
    gwarp = (CUDA.blockIdx().x - 1) * (CUDA.blockDim().x >> 5) + warp_in_block
    vox = gwarp * 2 + sg + 1
    N = size(P, 1)
    active = sl < D
    in_range = vox <= N
    c = active ? sl + 1 : 1

    Vx = in_range ? (@inbounds vx[vox]) : zero(T)
    Vy = in_range ? (@inbounds vy[vox]) : zero(T)
    Vz = in_range ? (@inbounds vz[vox]) : zero(T)

    diag_c = Vz * (@inbounds mz[c])                          # real F_z diagonal
    b_c = Vx * (@inbounds sxu[c]) + Vy * (@inbounds syu[c])  # A[c,c+1]
    # lower coupling conj(A[c-1,c]) = conj(b_{c-1}); b_{c-1} from lane c-1
    cdn = c > 1 ? c - 1 : 1
    bm_raw = _shfl_c(b_c, cdn, Val(W))
    bm = c > 1 ? bm_raw : zero(CT)

    psi0 = (active && in_range) ? (@inbounds P[vox, c]) : zero(CT)
    w = psi0
    k = K
    while k >= one(Int32)
        wup = _shfl_c(w, c + 1, Val(W))                  # w_{c+1} (idle→0 at c=D)
        wdn_raw = _shfl_c(w, cdn, Val(W))
        wdn = c > 1 ? wdn_raw : zero(CT)
        Aw = diag_c * w + b_c * wup + conj(bm) * wdn
        w = psi0 + (z / T(k)) * Aw
        k -= one(Int32)
    end

    if active && in_range
        @inbounds P[vox, c] = w
    end
    nothing
end

# --- Taylor–Horner thread kernel (one VOXEL per thread) ---
#
# Same recurrence as the warp variant; the difference is purely how ψ is
# addressed. ψ is `(N_spatial, D)` column-major, so component c of voxel i sits
# at `i + (c-1)·N`: with one component per LANE the 13 lanes of a voxel touch 13
# addresses N·16 B apart, and a warp issues 13 separate 32-byte transactions
# instead of contiguous 128-byte lines. Measured on H100 at 128³ that capped the
# kernel at ~0.93 TB/s while the (thread-per-voxel, coalesced) diagonal kernel
# reached ~2.2 TB/s on the same array.
#
# One voxel per thread makes consecutive threads read consecutive `P[i, c]`, so
# each component sweep is fully coalesced. The price is register pressure: the
# whole spinor must stay live (ψ₀ and w, 2·D complex), which is why this is a
# separate kernel selected by `_SPIN_TAYLOR_THREAD_PER_VOXEL[]` rather than a
# replacement — at large D the warp variant may still win.
@inline function _spin_taylor_thread_kernel!(
    P, vx, vy, vz, mz, sxu, syu, z::Complex{T}, K::Int32, ::Val{D},
) where {T, D}
    CT = Complex{T}
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > size(P, 1) && return nothing

    Vx = @inbounds vx[i]
    Vy = @inbounds vy[i]
    Vz = @inbounds vz[i]

    # Band of A = v·F. `d[c]` = A[c,c], `b[c]` = A[c,c+1] (b[D] ≡ 0);
    # A[c+1,c] = conj(b[c]) since A is Hermitian.
    d = ntuple(c -> Vz * (@inbounds mz[c]), Val(D))
    b = ntuple(c -> Vx * (@inbounds sxu[c]) + Vy * (@inbounds syu[c]), Val(D))

    psi0 = ntuple(c -> (@inbounds P[i, c]), Val(D))
    w = psi0
    k = K
    while k >= one(Int32)
        zk = z / T(k)
        wl = w
        w = ntuple(
            c -> psi0[c] + zk * (
                d[c] * wl[c] +
                b[c] * (c < D ? wl[c + 1] : zero(CT)) +
                (c > 1 ? conj(b[c - 1]) * wl[c - 1] : zero(CT))
            ),
            Val(D),
        )
        k -= one(Int32)
    end

    _store_spinor!(P, i, w, Val(D))
    nothing
end

# Compile-time-unrolled store. A `for c in 1:D` loop would index the tuple `w`
# with a runtime value, which forces it out of registers and into local memory —
# the spill this kernel exists to avoid.
@inline _store_spinor!(P, i, w, ::Val{0}) = nothing
@inline function _store_spinor!(P, i, w, ::Val{C}) where {C}
    _store_spinor!(P, i, w, Val(C - 1))
    @inbounds P[i, C] = w[C]
    nothing
end

# Which addressing scheme the rotation uses. Both are the same recurrence and
# agree to round-off; the parity gate covers both.
const _SPIN_TAYLOR_THREAD_PER_VOXEL = Ref(true)

"""
    _apply_spin_rotation_taylor!(P, vx, vy, vz, coef, z, K, Val(D))

`P[vox, :] ← exp(z · (v(vox)·F)) · P[vox, :]` for every voxel, degree-`K`
Taylor–Horner. `P` is the `(N_spatial, D)` reshape of ψ.
"""
function _apply_spin_rotation_taylor!(
    P, vx, vy, vz, coef::SpinTridiagCoef{T}, z::Complex{T}, K::Integer, ::Val{D},
) where {T, D}
    N = size(P, 1)
    if _SPIN_TAYLOR_THREAD_PER_VOXEL[]
        threads = 128
        blocks = cld(N, threads)
        CUDA.@cuda threads = threads blocks = blocks _spin_taylor_thread_kernel!(
            P, vx, vy, vz, coef.mz, coef.sxu, coef.syu, z, Int32(K), Val(D))
        return nothing
    end
    voxels_per_block = 16
    threads = 256
    blocks = cld(N, voxels_per_block)
    CUDA.@cuda threads = threads blocks = blocks _spin_taylor_warp_kernel!(
        P, vx, vy, vz, coef.mz, coef.sxu, coef.syu, z, Int32(K), Val(D))
    nothing
end

"""
    _spin_taylor_plan(psi, sm, vx, vy, vz, scale, imaginary_time)
        -> (coef, z, K) or nothing

Shared entry decision for the three call sites. Returns `nothing` when the
Taylor path is disabled or `R` exceeds `_SPIN_TAYLOR_RMAX[]`, in which case the
caller must use its exact Euler realization.

`scale` is the real prefactor multiplying `(v·F)` in the exponent — `dt` for
DDI, `c₁·dt` for spin-mixing — and carries its own sign, so `z` is built here
and the caller never re-derives it.
"""
function _spin_taylor_plan(
    psi::CuArray{Complex{T}}, sm::SpinorBEC.SpinMatrices{D},
    vx, vy, vz, scale::T, imaginary_time::Bool,
) where {T <: AbstractFloat, D}
    _SPIN_TAYLOR_ENABLED[] || return nothing
    # The warp layout puts one spin component per lane of a width-16 subgroup,
    # so D > 16 (F ≥ 8) has no lane to hold the upper components. Fall back.
    D <= 16 || return nothing
    F = T(sm.system.F)
    R = isnan(_SPIN_TAYLOR_R_OVERRIDE[]) ?
        _spin_rotation_R(vx, vy, vz, abs(scale), F) : T(_SPIN_TAYLOR_R_OVERRIDE[])
    R <= T(_SPIN_TAYLOR_RMAX[]) || return nothing
    K = _taylor_degree(R, _SPIN_TAYLOR_TOL[])
    # Real-time: exp(-i·scale·(v·F)). Imaginary time: exp(-scale·(v·F)) — a real
    # weight, so no overflow shift is needed (scale·|v|·F = R ≲ 1 by the branch
    # condition above).
    z = imaginary_time ? Complex{T}(-scale, zero(T)) : Complex{T}(zero(T), -scale)
    (_get_spin_tridiag_coef(psi, sm), z, K)
end
