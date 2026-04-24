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
    imaginary_time::Bool = false,
) where {D,N}
    n_pts = ntuple(d -> size(psi, d), Val(N))

    F = sm.system.F
    m_vals = SVector{D,Float64}(ntuple(c -> F - (c - 1), Val(D)))
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
raman_at(r::TimeDependentRaman{N}, t::Float64) where {N} =
    RamanCoupling{N}(evaluate(r.omega_wf, t), evaluate(r.delta_wf, t), r.k_eff)
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
    imaginary_time::Bool = false,
) where {D}
    abs(phi_x) + abs(phi_y) + abs(phi_z) < 1e-30 && return nothing

    # The rotation is spatially uniform — the same D×D unitary is applied at
    # every grid point. Build R once (D² scalar ops on host), then apply it
    # to the spin axis of psi via broadcast-only slab multiplications. This
    # is GPU-safe: no scalar indexing into the (possibly CuArray) psi.
    R = _compute_uniform_rotation_matrix(sm, phi_x, phi_y, phi_z, dt_frac, imaginary_time)
    _apply_rotation_to_spin_axis!(psi, R, ndim)
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
    m_vals = SVector{D,Float64}(ntuple(c -> F - (c - 1), Val(D)))
    V_Fy = sm.Fy_eigvecs
    Vt_Fy = sm.Fy_eigvecs_adj
    λ_Fy = sm.Fy_eigvals
    cols = ntuple(Val(D)) do j
        ej = SVector{D,ComplexF64}(ntuple(c -> ComplexF64(c == j ? 1 : 0), Val(D)))
        _apply_euler_spin_rotation(ej, phi_x, phi_y, phi_z, dt, F, m_vals,
                                   V_Fy, Vt_Fy, λ_Fy, sm, imaginary_time)
    end
    # Assemble as SMatrix column-major
    mat = MMatrix{D,D,ComplexF64}(undef)
    @inbounds for j = 1:D, i = 1:D
        mat[i, j] = cols[j][i]
    end
    SMatrix{D,D,ComplexF64}(mat)
end

"""Apply a spatially uniform D×D rotation R to the spin axis of psi
(which has shape `(n_pts..., D)`). Works on CPU and GPU arrays because
every op is either a broadcast on spatial slabs or an SMatrix scalar ×
array operation — no scalar indexing into psi."""
function _apply_rotation_to_spin_axis!(
    psi::AbstractArray{<:Complex}, R::SMatrix{D,D,ComplexF64}, ndim::Int,
) where {D}
    T = eltype(psi)
    # Output accumulator: same type, device, shape as psi
    buf = similar(psi)
    fill!(buf, zero(T))
    @inbounds for j = 1:D
        psi_j = selectdim(psi, ndim + 1, j)
        for i = 1:D
            Rij = T(R[i, j])
            Rij == zero(T) && continue
            buf_i = selectdim(buf, ndim + 1, i)
            buf_i .+= Rij .* psi_j
        end
    end
    copyto!(psi, buf)
    nothing
end
