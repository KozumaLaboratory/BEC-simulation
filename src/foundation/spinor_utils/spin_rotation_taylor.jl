# CPU spin rotation `exp(z · (v·F)) ψ` per voxel, by Taylor–Horner.
#
# Same operator, same accuracy contract and same tridiagonal generator as the
# GPU kernel in `ext/SpinorBECCUDAExt/gpu_spin_rotation_taylor.jl`; a DIFFERENT
# realization, because the GPU form is warp-cooperative (one spin component per
# lane, neighbours by `shfl`) and a CPU core has no such thing. Here the whole
# spinor sits in stack buffers and the tridiagonal matvec is written out.
#
# What it replaces: `_apply_euler_5stage_batched_{real,imag}!`, which moves ψ
# through cache ~18 times per rotation (5 phase passes + 4 gemms) and needs an
# `atan`/`acos`/`sqrt` pre-pass to turn v into Euler angles. Horner moves ψ
# twice and needs no trigonometry at all. Measured on TSUBAME (cpu_4, Eu F=6
# D=13, 32³) the Euler core plus its pre-pass was ~67 % of an ITP step.
#
# The accuracy contract is NOT restated here — `SPIN_TAYLOR_TOL` / `_RSAFE` /
# `_RK_MAX` below are the ones the GPU kernel reads, so the two devices cannot
# drift to different tolerances. Likewise the generator bands come from
# `spin_tridiag_bands`, which both devices call; the spin algebra is stated once
# in `sm.Fx/Fy/Fz`.
#
# Degree and angle halving are decided PER VOXEL from that voxel's own
# `R = |scale|·|v(r)|·F`, exactly as on the GPU. The CPU has no warp to round up
# to, so its degrees are if anything slightly lower; both satisfy the same
# backward-error bound, which is why CPU↔GPU parity is a tolerance and not `==`.

using StaticArrays: MVector

"""Master switch for the Taylor realization of a spin rotation. `false` routes
every caller back to the exact Euler form, which is what the parity gates
compare against. Honoured by BOTH the CPU kernel here and the CUDA one."""
const SPIN_TAYLOR_ENABLED = Ref(true)

"""Backward-error target for the per-voxel Taylor degree: the smallest `k ≥ 2`
with `R^k / k! ≤ tol` is used.

This is NOT a knob to expose. `bench/taylor_tolerance_sweep.jl` measured it
against the thing that actually binds the answer — the splitting error the
caller already accepted when they chose `dt`. At Eu F=6, 32³, dt = 0.002, that
splitting error (`|E(dt) − E(dt/2)|`, exact rotation both arms) is 7.6e-3, and
the Taylor truncation sits at:

    tol     |ΔE| vs exact   as a fraction of the splitting error   mean degree
    1e-5      2.5e-7                     3.3e-5                       2.00
    1e-9      2.9e-12                    3.9e-10                      2.26
    1e-13     2.4e-13                    3.1e-11                      2.65
    1e-15     2.4e-13                    3.2e-11                      2.82

Three things follow. The answer SATURATES at 1e-11 — below that ΔE stops
falling, so a tighter tolerance buys nothing. The cost is flat: the degree grows
like log(1/tol)/log(1/R), which over ten decades is 2.00 → 2.82 terms, and the
whole-run times (5.2–6.0 s) show no trend above the scatter of single runs. And
even at the LOOSEST tolerance tested the rotation contributes 4.5 orders of
magnitude less error than `dt` does.

So the tolerance is not a decision the caller should be asked to make; `dt` is
the decision, and this follows from it. 1e-13 is kept because it is free and
leaves a decade of margin past saturation, and because one number for both
devices is one declaration. The CUDA kernel's "Accuracy contract" block records
the same conclusion measured on that device.

The relationship, not this number, is what is gated:
`test_cpu_spin_rotation_taylor_parity.jl` fails if the truncation error stops
being negligible against the splitting error."""
# 1e-15, not 1e-13. The tighter value is FREE — the degree is floored at 2 and at
# production `R ≈ 1e-5` the schedule returns 2 for every tolerance over ten
# decades — so shipping the loose one offered a choice that could only ever be
# equal or worse. A setting that gives accuracy away without buying speed is not a
# trade, and the way to remove one is to stop shipping it.
#
# The knob stays registered because it CAN bind at large rotation angles, where it
# is a real control; it is simply not one at any angle this code runs at.
const SPIN_TAYLOR_TOL = Ref(1.0e-15)

"""Angle above which a voxel halves its rotation and applies it twice (repeated
squaring — exact). Production `R` is 0.01–0.2 so no voxel ever halves; the
branch exists so the Taylor path is exact at ANY `R` and the caller never has
to ask."""
const SPIN_TAYLOR_RSAFE = Ref(1.0)

"""Degree ceiling. With the halving above it is never approached."""
const SPIN_TAYLOR_RK_MAX = 40

"""Upper clamp on the Horner degree. Defaults to no clamp.

Exists because the accuracy criterion needs a positive control and nothing else
could provide one. `SPIN_TAYLOR_TOL` cannot degrade the rotation — the degree is
floored at 2 and at production `R = |scale|·|v|·F ≈ 1e-5` the schedule returns 2
for every tolerance over ten decades. Neither can the floor: measured, an
order-1 rotation is still ~1e-8 relative, four orders inside the splitting
error. The rotation is simply nowhere near binding, and the only way to make the
observable notice it is to REMOVE it — `cap = 0` skips the Horner loop entirely,
leaving ψ untouched.

That is the honest control for "this approximation is negligible": show that the
observable moves when the operator is absent. If it does not, the claim was
vacuous. See `test/hamiltonian/test_taylor_tolerance_criterion.jl`."""
const SPIN_TAYLOR_DEGREE_CAP = Ref(SPIN_TAYLOR_RK_MAX)

"""
    spin_tridiag_bands(sm, ::Type{T}) -> (mz, sxu, syu)

The three bands of `A = v·F`, which is Hermitian TRIDIAGONAL in the `F_z`
basis: `mz[c] = F_z[c,c]` (real), `sxu[c] = F_x[c,c+1]`, `syu[c] = F_y[c,c+1]`,
both zero at `c = D`. The sub-diagonal is `conj` of the super-diagonal and is
not stored.

Read straight off `sm.Fx/Fy/Fz` — the single declaration of the spin algebra.
The CUDA extension uploads exactly these vectors, so the two devices cannot
state the generator differently.
"""
function spin_tridiag_bands(sm::SpinMatrices{D}, ::Type{T}) where {D, T}
    Fx, Fy, Fz = sm.Fx, sm.Fy, sm.Fz
    mz = T[T(real(Fz[i, i])) for i in 1:D]
    sxu = Complex{T}[i < D ? Complex{T}(Fx[i, i + 1]) : zero(Complex{T}) for i in 1:D]
    syu = Complex{T}[i < D ? Complex{T}(Fy[i, i + 1]) : zero(Complex{T}) for i in 1:D]
    (mz, sxu, syu)
end

"""
    _spin_field_scratch(T, n_pts) -> (fx, fy, fz)

Three `n_pts`-shaped real buffers for a spin-density field, cached per
`(eltype, shape)`. The spin-mixing rotation needs ⟨F⟩ as a field and would
otherwise allocate it on every substep — four per ITP step.
"""
function _spin_field_scratch(::Type{T}, n_pts::NTuple{N, Int}) where {T, N}
    scratch_get!(:spin_field, (T, n_pts)) do
        (
            zeros(T, n_pts), zeros(T, n_pts), zeros(T, n_pts)
        )
    end::Tuple{Array{T, N}, Array{T, N}, Array{T, N}}
end

# Bands are a property of (spin algebra, eltype) only, so they are built once.
const _SPIN_BANDS_CACHE = Dict{Tuple{UInt64, DataType}, Any}()

function spin_tridiag_bands_cached(sm::SpinMatrices{D}, ::Type{T}) where {D, T}
    key = (objectid(sm), T)
    hit = get(_SPIN_BANDS_CACHE, key, nothing)
    hit !== nothing &&
        return hit::Tuple{Vector{T}, Vector{Complex{T}}, Vector{Complex{T}}}
    b = spin_tridiag_bands(sm, T)
    _SPIN_BANDS_CACHE[key] = b
    b
end

"""
    _taylor_rot_schedule(g, rk, K, tol2, rsafe2) -> (h, sh, kv)

This voxel's angle halving `h = 2^-sh` and Horner degree `kv`, from
`g = |v|²F²`. Both tests run on SQUARES so no `sqrt` is needed:
`(R/2^sh/k)² = (rk[k]·h)²·g`. `cap` clamps the result from above — see
[`SPIN_TAYLOR_DEGREE_CAP`](@ref); it exists for the accuracy gate's positive
control and is unclamped in production.
"""
@inline function _taylor_rot_schedule(
    g::T, rk, K::Int, tol2::T, rsafe2::T, cap::Int=SPIN_TAYLOR_DEGREE_CAP[]
) where {T}
    scale1 = @inbounds rk[1]          # rk[1] = scale ⇒ r2 starts as R²
    r2 = scale1 * scale1 * g
    sh = 0
    while r2 > rsafe2 && sh < 30
        r2 *= T(0.25)
        sh += 1
    end
    h = one(T)
    for _ in 1:sh
        h *= T(0.5)
    end
    gh = g * h * h

    kv = K
    u = one(T)
    kk = 1
    while kk < K
        a = @inbounds rk[kk]
        u *= a * a * gh
        if kk >= 2 && u <= tol2
            kv = kk
            break
        end
        kk += 1
    end
    (h, sh, min(kv, cap))
end

# `scale / k` for k = 1…K, cached per (eltype, scale). Two FP64 divisions per
# degree per voxel is not free, and a fixed-dt run asks for a handful of
# distinct scales and then never refills — the same reasoning (and the same
# bound) as the CUDA table.
const _CPU_SPIN_RK_CACHE = Dict{Tuple{DataType, Float64}, Any}()
const _CPU_SPIN_RK_CACHE_MAX = 64

function _cpu_spin_rk(::Type{T}, scale::T) where {T}
    key = (T, Float64(scale))
    hit = get(_CPU_SPIN_RK_CACHE, key, nothing)
    hit !== nothing && return hit::Vector{T}
    length(_CPU_SPIN_RK_CACHE) >= _CPU_SPIN_RK_CACHE_MAX && empty!(_CPU_SPIN_RK_CACHE)
    rk = T[scale / T(k) for k in 1:SPIN_TAYLOR_RK_MAX]
    _CPU_SPIN_RK_CACHE[key] = rk
    rk
end

"""
    apply_spin_rotation_taylor!(P, vx, vy, vz, bands, scale, Val(D);
                                imaginary_time, F, src)

`P[vox, :] ← exp(z · (v(vox)·F)) · P[vox, :]` for every voxel, with
`z = -i·scale` (real time) or `-scale` (imaginary time). `P` is the
`(N_spatial, D)` reshape of ψ; `bands` is `spin_tridiag_bands`'s tuple.

`src` maps voxel → index in `vx/vy/vz` (`nothing` = contiguous; a
`CartesianIndices` when the field is the corner of a zero-padded DDI buffer).
"""
function apply_spin_rotation_taylor!(
    P::AbstractMatrix{Complex{T}}, vx, vy, vz,
    bands::Tuple{Vector{T}, Vector{Complex{T}}, Vector{Complex{T}}},
    scale::T, ::Val{D};
    imaginary_time::Bool=false, F::T=one(T), src=nothing,
) where {T, D}
    if imaginary_time
        _spin_taylor_cpu_kernel!(P, vx, vy, vz, bands, scale, Val(D), Val(false), F, src)
    else
        _spin_taylor_cpu_kernel!(P, vx, vy, vz, bands, scale, Val(D), Val(true), F, src)
    end
    nothing
end

# `Val{RT}` (real time) is a type parameter, not a Bool argument: it selects the
# Horner coefficient's form, and the branch has to vanish from a loop body that
# runs K·D times per voxel.
function _spin_taylor_cpu_kernel!(
    P::AbstractMatrix{Complex{T}}, vx, vy, vz,
    bands::Tuple{Vector{T}, Vector{Complex{T}}, Vector{Complex{T}}},
    scale::T, ::Val{D}, ::Val{RT}, F::T, src,
) where {T, D, RT}
    mz, sxu, syu = bands
    N = size(P, 1)
    rk = _cpu_spin_rk(T, scale)
    tol2 = T(SPIN_TAYLOR_TOL[])^2
    rsafe2 = T(SPIN_TAYLOR_RSAFE[])^2
    F2 = F * F
    K = SPIN_TAYLOR_RK_MAX
    CT = Complex{T}
    z0 = zero(CT)

    _voxel_loop!(N) do i
        @inbounds begin
            j = _voxel_index(src, i)
            Vx = T(vx[j])
            Vy = T(vy[j])
            Vz = T(vz[j])
            g = (Vx * Vx + Vy * Vy + Vz * Vz) * F2
            h, sh, kv = _taylor_rot_schedule(g, rk, K, tol2, rsafe2)

            # Per-voxel stack buffers (MVector, the same idiom
            # `_apply_euler_spin_rotation` uses to keep D=13 off the heap).
            base = MVector{D, CT}(undef)
            w = MVector{D, CT}(undef)
            bu = MVector{D, CT}(undef)     # h·A[c,c+1], reused across degrees

            for c in 1:D
                base[c] = P[i, c]
                bu[c] = (Vx * sxu[c] + Vy * syu[c]) * h
            end
            for c in 1:D
                w[c] = base[c]
            end

            for _rep in 1:(1 << sh)
                for k in kv:-1:1
                    a = rk[k]
                    prev_old = z0            # w_{c-1} BEFORE this degree's update
                    for c in 1:D
                        cur_old = w[c]
                        up_old = c < D ? w[c + 1] : z0
                        # A[c,c-1] = conj(A[c-1,c]) = conj(bu[c-1])
                        low = c > 1 ? conj(bu[c - 1]) : z0
                        Aw = (Vz * mz[c] * h) * cur_old + bu[c] * up_old + low * prev_old
                        # RT: (-i·a)·Aw = a·(imag Aw − i·real Aw);  IT: −a·Aw
                        w[c] = RT ? base[c] + a * CT(imag(Aw), -real(Aw)) :
                               base[c] - a * Aw
                        prev_old = cur_old
                    end
                end
                if sh > 0
                    for c in 1:D
                        base[c] = w[c]
                    end
                end
            end

            for c in 1:D
                P[i, c] = w[c]
            end
        end
    end
    nothing
end
