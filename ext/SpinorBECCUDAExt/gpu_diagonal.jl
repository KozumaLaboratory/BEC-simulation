# Fused GPU diagonal potential step.
#
# The generic `_diagonal_step_svec!(::AbstractArray, …)` builds the density
# with D `abs2` broadcasts and then applies the per-component phase with D
# more `cis`/`exp` broadcasts — 2D ≈ 26 kernel launches per call at D=13,
# ×4 calls/step. This single kernel does one launch: each thread computes
# its voxel density once and applies all D component phases from registers.
#
# Handles the scalar / no-LHY contact term (covers the Eu DDI production
# path). Non-scalar LHY (Tabulated, Quasi2D, …) does not match the c_lhy
# type bound and falls back to the generic broadcast method.

using StaticArrays: SVector

# zph: per-component Zeeman phase exp/cis(-(zee_c-shift)·dt) as a DEVICE array
# (all threads read the same D values → L2/constant-cached), NOT a by-value
# SVector (26 Float64 at D=13 → register pressure that regressed this kernel
# +40% when tried). One transcendental per voxel (exp/cis of the voxel-dependent
# base) instead of D. Machine-precision equivalent to the direct per-component form.
# The voxel-dependent half of the diagonal phase, declared ONCE: this kernel
# and the fused V half-step (gpu_spin_chain.jl, which multiplies the
# same phase in and out around its rotations) both call it.
@inline function _diag_voxel_density(Pmf, i, ::Type{T}, ::Val{D}) where {T, D}
    n = zero(T)
    @inbounds for c in 1:D
        n += abs2(Pmf[i, c])
    end
    n
end

# The voxel-dependent phase, given an ALREADY-EVALUATED V_LHY. Split out so the
# scalar and tabulated kernels differ only in how they get that one number and
# cannot drift on the rest of the diagonal.
@inline function _diag_phase_from(
    n::T, Vt_i::T, c0::T, lhy::T, dt::T, ::Val{IT}
) where {T, IT}
    varg = (Vt_i + c0 * n + lhy) * dt
    # one transcendental per voxel instead of D
    IT ? Complex{T}(exp(-varg), zero(T)) : cis(-varg)
end

@inline function _diag_voxel_phase(
    Pmf, i, Vt, c0::T, clhy::T, dt::T, ::Val{D}, ::Val{IT}
) where {T, D, IT}
    n = _diag_voxel_density(Pmf, i, T, Val(D))
    lhy = clhy == zero(T) ? zero(T) : clhy * n * sqrt(n)
    (n, _diag_phase_from(n, (@inbounds Vt[i]), c0, lhy, dt, Val(IT)))
end

@inline function _diag_step_kernel!(
    P, Pmf, Vt, db, zph, c0::T, clhy::T, dt::T, ::Val{D}, ::Val{IT}
) where {T, D, IT}
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > size(P, 1) && return nothing
    n, vph = _diag_voxel_phase(Pmf, i, Vt, c0, clhy, dt, Val(D), Val(IT))
    @inbounds db[i] = n
    @inbounds for c in 1:D
        P[i, c] *= vph * zph[c]
    end
    return nothing
end

# Tabulated LHY in the SAME fused kernel. Until now every `TabulatedLHY` missed
# this kernel's `c_lhy` bound and fell to the generic broadcast propagator — 2D
# ≈ 26 launches per call plus a materialised V_LHY array, four calls per ITP
# step. Measured on an H100 at 24³ Eu F=6: 0.336 ms/step with no LHY against
# 1.021 with a table, i.e. 0.685 ms of the step was the fallback and not the
# physics. Every production Eu run is tabulated (polar_contact / icosahedral /
# full_bdg / …), so that is the common case.
#
# `_lhy_interp_uniform` is the SAME device lookup the generic path calls
# (gpu_lhy_field.jl), so the two cannot disagree on the table — only on how the
# Zeeman factor associates, which is why the gate is machine precision and not
# bit-identity, exactly as for the scalar arm.
@inline function _diag_step_kernel_tab!(
    P, Pmf, Vt, db, zph, c0::T, x0::T, dxi::T, ys, m::Int32, dt::T,
    ::Val{D}, ::Val{IT},
) where {T, D, IT}
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > size(P, 1) && return nothing
    n = _diag_voxel_density(Pmf, i, T, Val(D))
    lhy = _lhy_interp_uniform(n, x0, dxi, ys, Int(m))
    vph = _diag_phase_from(n, (@inbounds Vt[i]), c0, lhy, dt, Val(IT))
    @inbounds db[i] = n
    @inbounds for c in 1:D
        P[i, c] *= vph * zph[c]
    end
    return nothing
end

function SpinorBEC._diagonal_step_svec!(
    ::Val{N},
    psi::CuArray{Complex{T}},
    V_trap,
    zeeman_diag::SVector{D, Float64},
    c0,
    c_lhy::SpinorBEC.TabulatedLHY,
    dt_frac,
    density_buf,
    imaginary_time;
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {N, T <: AbstractFloat, D}
    xs = c_lhy.densities
    m = length(xs)
    m >= 2 || throw(ArgumentError("a tabulated LHY needs ≥ 2 density nodes, got $m"))
    _assert_uniform_lhy_grid(xs, m)
    n_pts = ntuple(d -> size(psi, d), Val(N))
    Ns = prod(n_pts)
    dtf = T(dt_frac)
    it = imaginary_time === true
    zph = _get_diag_zph(psi, zeeman_diag, dtf, it)
    ys = _device_lhy_table(c_lhy, T, psi)

    P = reshape(psi, Ns, D)
    Pmf = reshape(psi_mf === nothing ? psi : psi_mf::CuArray{Complex{T}}, Ns, D)
    Vt = reshape(V_trap, Ns)
    db = reshape(density_buf, Ns)
    threads = min(Ns, 256)
    blocks = cld(Ns, threads)
    CUDA.@cuda threads = threads blocks = blocks _diag_step_kernel_tab!(
        P, Pmf, Vt, db, zph, T(c0), T(xs[1]), T(xs[2] - xs[1]), ys, Int32(m), dtf,
        Val(D), Val(it),
    )
    nothing
end

# Same phase, written out for a later kernel to consume rather than applied
# here. Used by the fused half-step, which needs it twice (once on each side of
# its rotations) from ONE pass over ψ_mf.
@inline function _diag_phase_kernel!(
    vph, db, Pmf, Vt, c0::T, clhy::T, dt::T, ::Val{D}, ::Val{IT}
) where {T, D, IT}
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > size(Pmf, 1) && return nothing
    n, ph = _diag_voxel_phase(Pmf, i, Vt, c0, clhy, dt, Val(D), Val(IT))
    @inbounds db[i] = n
    @inbounds vph[i] = ph
    return nothing
end

function SpinorBEC._diagonal_step_svec!(
    ::Val{N},
    psi::CuArray{Complex{T}},
    V_trap,
    zeeman_diag::SVector{D, Float64},
    c0,
    c_lhy::Union{Nothing, SpinorBEC.NoLHY, Float64, SpinorBEC.ScalarLHY},
    dt_frac,
    density_buf,
    imaginary_time;
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {N, T <: AbstractFloat, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    Ns = prod(n_pts)
    clhy = c_lhy isa SpinorBEC.ScalarLHY ? T(c_lhy.c_lhy) :
           (c_lhy isa Float64 ? T(c_lhy) : zero(T))
    dtf = T(dt_frac)
    it = imaginary_time === true
    # Precompute the D per-component Zeeman phases into a cached DEVICE vector
    # (reused, no per-call GPU alloc; host-side 208 B upload is uncounted).
    zph = _get_diag_zph(psi, zeeman_diag, dtf, it)

    P = reshape(psi, Ns, D)
    Pmf = reshape(psi_mf === nothing ? psi : psi_mf::CuArray{Complex{T}}, Ns, D)
    Vt = reshape(V_trap, Ns)
    db = reshape(density_buf, Ns)

    threads = min(Ns, 256)
    blocks = cld(Ns, threads)
    CUDA.@cuda threads = threads blocks = blocks _diag_step_kernel!(
        P, Pmf, Vt, db, zph, T(c0), clhy, dtf, Val(D), Val(it)
    )
    nothing
end

# `slot` lets the fused half-step hold the forward and backward Zeeman phases
# at the same time without either clobbering the standalone kernel's. Each slot
# remembers the (diagonal, dt, imaginary-time) it currently holds and skips the
# upload when asked for the same thing again — which a static field asks for on
# every one of the ~8 calls per step. A time-dependent field misses and pays the
# copy, as before.
const _DIAG_ZPH_CACHE = Dict{Tuple{Int, DataType, Int}, Any}()
const _DIAG_ZPH_KEY = Dict{Tuple{Int, DataType, Int}, Any}()

# exp/cis of the per-component Zeeman phase. `shift` is the ITP overflow guard
# (`min(zeeman_diag)`), a no-op in real time.
function _zeeman_phase_host(
    zeeman_diag::SVector{D, Float64}, dtf::T, it::Bool
) where {D, T}
    shift = it ? T(minimum(zeeman_diag)) : zero(T)
    Complex{T}[
        if it
            Complex{T}(exp(-(T(zeeman_diag[c]) - shift) * dtf), zero(T))
        else
            cis(-T(zeeman_diag[c]) * dtf)
        end for c in 1:D
    ]
end

function _get_diag_zph(
    psi::CuArray{Complex{T}}, zeeman_diag::SVector{D, Float64}, dtf::T, it::Bool,
    slot::Int=0,
) where {T, D}
    ck = (D, T, slot)
    zph = get!(() -> similar(psi, Complex{T}, D), _DIAG_ZPH_CACHE, ck)::CuArray{Complex{T}, 1}
    key = (zeeman_diag, dtf, it)
    get(_DIAG_ZPH_KEY, ck, nothing) == key && return zph
    copyto!(zph, _zeeman_phase_host(zeeman_diag, dtf, it))
    _DIAG_ZPH_KEY[ck] = key
    zph
end
