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
const _SPIN_RK_MAX = 40
const _SPIN_RK_CACHE = Dict{DataType, Any}()

function _fill_rk_kernel!(rk, scale::T, K::Int32) where {T}
    k = CUDA.threadIdx().x
    k <= K && (@inbounds rk[k] = scale / T(k))
    nothing
end

function _get_spin_rk(::CuArray{Complex{T}}, scale::T, K::Integer) where {T}
    rk = get!(() -> CUDA.zeros(T, _SPIN_RK_MAX), _SPIN_RK_CACHE, T)::CuArray{T, 1}
    CUDA.@cuda threads = _SPIN_RK_MAX blocks = 1 _fill_rk_kernel!(rk, scale, Int32(K))
    rk
end

# --- Taylor–Horner warp kernel (one spin component per lane) ---
# `RT` selects the real-time (multiply by -i) vs imaginary-time (real weight)
# form of the Horner coefficient; both read the same real `rk` table.
@inline function _spin_taylor_warp_kernel!(
    P, vx, vy, vz, mz, sxu, syu, rk, K::Int32, ::Val{D}, ::Val{RT},
) where {D, RT}
    T = real(eltype(P))
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
    bmc = conj(bm)
    w = psi0
    k = K
    while k >= one(Int32)
        wup = _shfl_c(w, c + 1, Val(W))                  # w_{c+1} (idle→0 at c=D)
        wdn_raw = _shfl_c(w, cdn, Val(W))
        wdn = c > 1 ? wdn_raw : zero(CT)
        Aw = diag_c * w + b_c * wup + bmc * wdn
        a = @inbounds rk[k]
        # RT: (0 - i·a)·Aw = a·(imag(Aw) - i·real(Aw));  IT: (-a)·Aw
        w = RT ? psi0 + a * CT(imag(Aw), -real(Aw)) : psi0 - a * Aw
        k -= one(Int32)
    end

    if active && in_range
        @inbounds P[vox, c] = w
    end
    nothing
end

"""
    _apply_spin_rotation_taylor!(P, vx, vy, vz, coef, scale, K, Val(D); imaginary_time)

`P[vox, :] ← exp(z · (v(vox)·F)) · P[vox, :]` for every voxel, degree-`K`
Taylor–Horner, with `z = -i·scale` (real time) or `-scale` (imaginary time).
`P` is the `(N_spatial, D)` reshape of ψ.
"""
function _apply_spin_rotation_taylor!(
    P, vx, vy, vz, coef::SpinTridiagCoef{T}, scale::T, K::Integer, ::Val{D};
    imaginary_time::Bool=false,
) where {T, D}
    N = size(P, 1)
    voxels_per_block = 16
    threads = 256
    blocks = cld(N, voxels_per_block)
    rk = _get_spin_rk(P, scale, K)
    CUDA.@cuda threads = threads blocks = blocks _spin_taylor_warp_kernel!(
        P, vx, vy, vz, coef.mz, coef.sxu, coef.syu, rk, Int32(K), Val(D),
        Val(!imaginary_time))
    nothing
end

"""
    _spin_taylor_plan(psi, sm, vx, vy, vz, scale, imaginary_time)
        -> (coef, scale, K) or nothing

Shared entry decision for the three call sites. Returns `nothing` when the
Taylor path is disabled or `R` exceeds `_SPIN_TAYLOR_RMAX[]`, in which case the
caller must use its exact Euler realization.

`scale` is the real prefactor multiplying `(v·F)` in the exponent — `dt` for
DDI, `c₁·dt` for spin-mixing — and carries its own sign; it is returned
unchanged so the caller passes it straight to `_apply_spin_rotation_taylor!`.
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
    # condition above). Both forms are carried by the real `scale`; the kernel's
    # `Val{RT}` picks which one it means.
    (_get_spin_tridiag_coef(psi, sm), scale, K)
end
