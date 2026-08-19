export apply_uniform_spin_rotation!

# Spatially uniform spin rotation kernel.
#
# Serves both the Raman propagator (hamiltonian/terms/raman.jl) and the
# transverse-Zeeman step (hamiltonian/integrator/split_step.jl), and is
# borrowed by rotating_basis_propagators.jl for frame-change rotations.
# Lives in foundation alongside its Euler-rotation siblings (euler_*.jl)
# since every dependency is foundation-level and it is shared across terms.

"""
    apply_uniform_spin_rotation!(psi, sm, phi_x, phi_y, phi_z, dt_frac, ndim; imaginary_time)

Apply a spatially uniform spin rotation exp(-i dt (phi_x Fx + phi_y Fy + phi_z Fz)).
Used for transverse Zeeman fields (Bx, By).
"""
function apply_uniform_spin_rotation!(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    phi_x::Float64,
    phi_y::Float64,
    phi_z::Float64,
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
    scratch::Union{Nothing, AbstractArray}=nothing,
) where {D}
    abs(phi_x) + abs(phi_y) + abs(phi_z) < COUPLING_TOL && return nothing

    # The rotation is spatially uniform — the same D×D unitary is applied at
    # every grid point. Build R once (D² scalar ops on host), then apply it
    # to the spin axis of psi via broadcast-only slab multiplications. This
    # is GPU-safe: no scalar indexing into the (possibly CuArray) psi.
    #
    # `scratch` (typically `ws.state.psi_scratch`) avoids allocating a fresh
    # full-size buffer per call. For fast-Larmor runs with ~10⁶ rotation
    # calls this matters — without scratch the CUDA pool eats GC pressure
    # equivalent to ~70 TB total allocations on a 64×64×32 Dy164 grid.
    R = _compute_uniform_rotation_matrix(sm, phi_x, phi_y, phi_z, dt_frac, imaginary_time)
    _apply_rotation_to_spin_axis!(psi, R, ndim; scratch=scratch)
    nothing
end

"""Build the D×D rotation matrix R such that ψ_new[c] = Σ_j R[c,j] · ψ[j]
matches `_apply_euler_spin_rotation`. Extract it by feeding unit vectors
through the existing per-spinor routine, so physics stays identical to the
scalar path."""
@inline function _compute_uniform_rotation_matrix(
    sm::SpinMatrices{D}, phi_x::Float64, phi_y::Float64, phi_z::Float64,
    dt::Float64, imaginary_time::Bool,
) where {D}
    F = sm.system.F
    m_vals = SVector{D, Float64}(ntuple(c -> F - (c - 1), Val(D)))
    V_Fy = sm.Fy_eigvecs
    Vt_Fy = sm.Fy_eigvecs_adj
    λ_Fy = sm.Fy_eigvals
    cols = ntuple(Val(D)) do j
        ej = SVector{D, ComplexF64}(ntuple(c -> ComplexF64(c == j ? 1 : 0), Val(D)))
        _apply_euler_spin_rotation(ej, phi_x, phi_y, phi_z, dt, F, m_vals,
            V_Fy, Vt_Fy, λ_Fy, sm, imaginary_time)
    end
    # Assemble as SMatrix column-major
    mat = MMatrix{D, D, ComplexF64}(undef)
    @inbounds for j in 1:D, i in 1:D
        mat[i, j] = cols[j][i]
    end
    SMatrix{D, D, ComplexF64}(mat)
end

"""Apply a spatially uniform D×D rotation R to the spin axis of psi
(shape `(n_pts..., D)`). Reformulated as a single dense matrix product
`buf_2d = psi_2d · Rᵀ` where psi_2d/buf_2d are `(N_spatial, D)` views;
on GPU this is one CUBLAS gemm instead of D² per-slab broadcasts
(D=17, i.e. Dy164 → ~289× kernel-launch reduction). On CPU it dispatches to
BLAS gemm.

`scratch`, if supplied, is reused as the gemm output buffer (must be
same shape + device + eltype as psi). The D×D `Rᵀ` is materialized once
per call into a tiny device buffer (D² complexes ≈ few KB) and that
buffer is cached per-`scratch`-objectid so subsequent calls re-use the
same allocation — required for any future CUDA Graph capture, since
a per-call `similar()` would invalidate the captured argument pointer.
"""

# Per-scratch-buffer cache for the small D×D R^T device matrix. Keyed by
# `objectid(scratch)` so callers passing distinct workspace scratches
# get distinct cached buffers. Falls back to per-call alloc when scratch
# is nothing.
const _ROTATION_RT_CACHE = Dict{UInt, AbstractArray}()

function _get_rt_buffer(scratch::AbstractArray, ::Type{T}, D::Int) where {T}
    key = objectid(scratch)
    haskey(_ROTATION_RT_CACHE, key) && return _ROTATION_RT_CACHE[key]
    buf = similar(scratch, T, D, D)
    _ROTATION_RT_CACHE[key] = buf
    buf
end

function _apply_rotation_to_spin_axis!(
    psi::AbstractArray{<:Complex, M}, R::SMatrix{D, D, ComplexF64}, ndim::Int;
    scratch::Union{Nothing, AbstractArray}=nothing,
) where {D, M}
    T = eltype(psi)
    buf = scratch === nothing ? similar(psi) : scratch::typeof(psi)

    n_spatial = 1
    @inbounds for i in 1:ndim
        n_spatial *= size(psi, i)
    end
    psi_2d = reshape(psi, n_spatial, D)
    buf_2d = reshape(buf, n_spatial, D)

    # buf[k,i] = Σⱼ R[i,j]·psi[k,j] = Σⱼ psi[k,j]·(Rᵀ)[j,i] → buf = psi · Rᵀ.
    # CPU: populate Rᵀ in-place. GPU: build on host, single h2d copy
    # (~5 KB at D=17). Dispatch on `psi` type since the rotation scratch
    # cache is keyed by `objectid(scratch)` and stored under an abstract
    # `Dict{UInt, AbstractArray}` value type — annotating the retrieved
    # buffer keeps inference concrete in the per-element fill loop.
    R_T = _populate_rt_buffer!(psi, R, T, Val(D), scratch)

    mul!(buf_2d, psi_2d, R_T)
    copyto!(psi, buf)
    nothing
end

"""
    _apply_rotation_to_spin_axis_to!(dst, src, R, ndim) → dst

Same as `_apply_rotation_to_spin_axis!` but reads `src`, writes `dst`.
Lets the caller pipeline two rotations through a separate buffer
without the per-call `copyto!` back to the source array (used by the
Û_B → DDI → Û_B† chain in `apply_ddi_step_rotating!`).

`dst` and `src` must be distinct arrays (no aliasing) of the same
shape and eltype. The Rᵀ buffer is keyed off `dst` so it doesn't
collide with the `_apply_rotation_to_spin_axis!(scratch=...)` cache
on the same workspace.
"""
function _apply_rotation_to_spin_axis_to!(
    dst::AbstractArray{<:Complex, M}, src::AbstractArray{<:Complex, M},
    R::SMatrix{D, D, ComplexF64}, ndim::Int,
) where {D, M}
    T = eltype(dst)
    n_spatial = 1
    @inbounds for i in 1:ndim
        n_spatial *= size(dst, i)
    end
    src_2d = reshape(src, n_spatial, D)
    dst_2d = reshape(dst, n_spatial, D)
    R_T = _populate_rt_buffer!(dst, R, T, Val(D), dst)
    mul!(dst_2d, src_2d, R_T)
    dst
end

# CPU branch: write Rᵀ entries directly into a typed Array. The `::Matrix{T}`
# annotation defeats the abstract-value-type erasure of `_ROTATION_RT_CACHE`
# (`Dict{UInt, AbstractArray}`).
function _populate_rt_buffer!(
    psi::Array{<:Complex}, R::SMatrix{D, D, ComplexF64}, ::Type{T}, ::Val{D}, scratch
) where {T, D}
    R_T::Matrix{T} =
        scratch === nothing ?
        Matrix{T}(undef, D, D) :
        _get_rt_buffer(scratch, T, D)::Matrix{T}
    @inbounds for j in 1:D, i in 1:D
        R_T[j, i] = T(R[i, j])
    end
    R_T
end

# Generic / GPU fallback: build Rᵀ on host then `copyto!` into the device
# buffer. Per-element scalar writes against a CuArray would launch D²
# kernels — unacceptable.
function _populate_rt_buffer!(
    psi::AbstractArray{<:Complex}, R::SMatrix{D, D, ComplexF64}, ::Type{T}, ::Val{D}, scratch
) where {T, D}
    R_T_host = Matrix{T}(undef, D, D)
    @inbounds for j in 1:D, i in 1:D
        R_T_host[j, i] = T(R[i, j])
    end
    R_T = scratch === nothing ? similar(psi, T, D, D) : _get_rt_buffer(scratch, T, D)
    copyto!(R_T, R_T_host)
    R_T
end
