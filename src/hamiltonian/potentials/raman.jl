"""
Raman coupling between spin states via two-photon transition.

H_R(r) = (Ω_R/2) * (e^{ik_eff·r} F_+ + e^{-ik_eff·r} F_-) + δ * Fz
       = Ω_R cos(k·r) Fx - Ω_R sin(k·r) Fy + δ Fz

Applied via Euler angle decomposition (O(D²), allocation-free for any D).
"""
function apply_raman_step!(
    psi::AbstractArray{ComplexF64},
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
    psi::AbstractArray{ComplexF64},
    sm::SpinMatrices{D},
    phi_x::Float64,
    phi_y::Float64,
    phi_z::Float64,
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool = false,
) where {D}
    abs(phi_x) + abs(phi_y) + abs(phi_z) < 1e-30 && return nothing

    F = sm.system.F
    m_vals = SVector{D,Float64}(ntuple(c -> F - (c - 1), Val(D)))
    V_Fy = sm.Fy_eigvecs
    Vt_Fy = sm.Fy_eigvecs_adj
    λ_Fy = sm.Fy_eigvals
    n_pts = ntuple(d -> size(psi, d), ndim)

    @inbounds for I in CartesianIndices(n_pts)
        spinor = _get_spinor(psi, I, Val(D))
        new_spinor = _apply_euler_spin_rotation(
            spinor, phi_x, phi_y, phi_z, dt_frac, F, m_vals,
            V_Fy, Vt_Fy, λ_Fy, sm, imaginary_time,
        )
        _set_spinor!(psi, I, new_spinor, Val(D))
    end
    nothing
end
