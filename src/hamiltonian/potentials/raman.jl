"""
Raman coupling between spin states via two-photon transition.

H_R(r) = (Ω_R/2) * (e^{ik_eff·r} F_+ + e^{-ik_eff·r} F_-) + δ * Fz
       = Ω_R cos(k·r) Fx - Ω_R sin(k·r) Fy + δ Fz

Applied via Euler angle decomposition (O(D²), allocation-free for any D).
"""
function apply_raman_step!(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    raman::RamanCoupling{N},
    grid::Grid{N},
    dt_frac::Float64;
    imaginary_time::Bool=false,
) where {D, N}
    n_pts = ntuple(d -> size(psi, d), Val(N))

    F = sm.system.F
    m_vals = SVector{D, Float64}(ntuple(c -> F - (c - 1), Val(D)))
    V_Fy = sm.Fy_eigvecs
    Vt_Fy = sm.Fy_eigvecs_adj
    λ_Fy = sm.Fy_eigvals

    @inbounds for I in CartesianIndices(n_pts)
        kr = sum(ntuple(d -> raman.k_eff[d] * grid.x[d][I[d]], Val(N)))

        phi_x = raman.Omega_R * cos(kr)
        phi_y = -raman.Omega_R * sin(kr)
        phi_z = raman.delta

        spinor = _get_spinor(psi, I, Val(D))
        new_spinor = _apply_euler_spin_rotation(
            spinor,
            phi_x,
            phi_y,
            phi_z,
            dt_frac,
            F,
            m_vals,
            V_Fy,
            Vt_Fy,
            λ_Fy,
            sm,
            imaginary_time,
        )
        _set_spinor!(psi, I, new_spinor, Val(D))
    end
    nothing
end

raman_at(r::RamanCoupling, ::Float64) = r
raman_at(r::TimeDependentRaman{N}, t::Float64) where {N} = RamanCoupling{N}(
    evaluate(r.omega_wf, t), evaluate(r.delta_wf, t), r.k_eff
)
raman_at(::Nothing, ::Float64) = nothing

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
    abs(phi_x) + abs(phi_y) + abs(phi_z) < 1e-30 && return nothing

    # The rotation is spatially uniform — the same D×D unitary is applied at
    # every grid point. Build R once (D² scalar ops on host), then apply it
    # to the spin axis of psi via broadcast-only slab multiplications. This
    # is GPU-safe: no scalar indexing into the (possibly CuArray) psi.
    #
    # `scratch` (typically `ws.state.psi_scratch`) avoids allocating a fresh
    # full-size buffer per call. For Klaus-style runs with ~10⁶ rotation
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
(D=17 Klaus → ~289× kernel-launch reduction). On CPU it dispatches to
BLAS gemm.

`scratch`, if supplied, is reused as the gemm output buffer (must be
same shape + device + eltype as psi). The D×D `Rᵀ` is materialized once
per call into a tiny device buffer (D² complexes ≈ few KB).
"""
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
    # Build Rᵀ on host (D² scalar ops), then copyto! to a small device buffer.
    R_T_host = Matrix{T}(undef, D, D)
    @inbounds for j in 1:D, i in 1:D
        R_T_host[j, i] = T(R[i, j])
    end
    R_T = similar(psi, T, D, D)
    copyto!(R_T, R_T_host)

    mul!(buf_2d, psi_2d, R_T)
    copyto!(psi, buf)
    nothing
end
