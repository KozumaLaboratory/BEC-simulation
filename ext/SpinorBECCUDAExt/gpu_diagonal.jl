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

@inline function _diag_step_kernel!(
    P, Pmf, Vt, db, zee, c0::T, clhy::T, shift::T, dt::T, ::Val{D}, ::Val{IT},
) where {T, D, IT}
    i = (CUDA.blockIdx().x - 1) * CUDA.blockDim().x + CUDA.threadIdx().x
    i > size(P, 1) && return nothing

    n = zero(T)
    @inbounds for c in 1:D
        v = Pmf[i, c]
        n += abs2(v)
    end
    @inbounds db[i] = n

    lhy = clhy == zero(T) ? zero(T) : clhy * n * sqrt(n)
    base = @inbounds(Vt[i]) + c0 * n + lhy
    @inbounds for c in 1:D
        arg = (base + (zee[c] - shift)) * dt
        P[i, c] *= IT ? exp(-arg) : cis(-arg)
    end
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
    shift = imaginary_time ? T(minimum(zeeman_diag)) : zero(T)
    zee = SVector{D, T}(ntuple(c -> T(zeeman_diag[c]), Val(D)))

    P = reshape(psi, Ns, D)
    Pmf = reshape(psi_mf === nothing ? psi : psi_mf::CuArray{Complex{T}}, Ns, D)
    Vt = reshape(V_trap, Ns)
    db = reshape(density_buf, Ns)

    threads = min(Ns, 256)
    blocks = cld(Ns, threads)
    CUDA.@cuda threads = threads blocks = blocks _diag_step_kernel!(
        P, Pmf, Vt, db, zee, T(c0), clhy, shift, T(dt_frac),
        Val(D), Val(imaginary_time === true),
    )
    nothing
end
