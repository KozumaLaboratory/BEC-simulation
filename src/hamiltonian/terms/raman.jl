# --- Raman: engine (uniform spin rotation propagator) + RamanTerm face ---
#
# Engine `apply_raman_step!` is the production propagator (called by
# integrator/split_step.jl and the GPU ext); `RamanTerm` is the registry
# face (energy + KNOWN-LIMIT nil gradient). One file = engine + face
# cohesion.

# ============================================================================
# Engine — Raman propagator + time-dependent resolution
# ============================================================================

export apply_raman_step!, raman_at

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

# ============================================================================
# RamanTerm — registry face. Sign convention is encoded in
# apply_raman_step! + _raman_energy above. Gradient not implemented.
# ============================================================================

"""Raman two-photon coupling."""
struct RamanTerm <: HamTerm end

function apply_step!(::RamanTerm, psi, dt::Real, imaginary_time::Bool, ws)
    ws.raman === nothing && return nothing
    raman_now = raman_at(ws.raman, ws.state.t)
    apply_raman_step!(psi, ws.spin_matrices, raman_now, ws.grid, dt; imaginary_time)
    return nothing
end

"""
    _raman_energy(psi, sm, raman, grid, ndim, n_pts, dV)

`E_Raman = ∫ d³r [δ·⟨F_z⟩ + Ω_R·Re(e^{ik·r}·⟨F_+⟩)]` per voxel.
Manual per-voxel reduction inlines the kr phase + Fz/F+ contractions.
"""
function _raman_energy(psi, sm::SpinMatrices{D}, raman::RamanCoupling{N},
    grid::Grid{N}, ndim, n_pts, dV) where {D, N}
    F = sm.system.F
    m_vals = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp_coeffs = fp_ladder_coeffs(F, Val(D))

    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        kr = sum(ntuple(d -> raman.k_eff[d] * grid.x[d][I[d]], Val(N)))
        phase = exp(1im * kr)

        fz_val = 0.0
        for c in 1:D
            fz_val += m_vals[c] * abs2(psi[I, c])
        end

        fp_val = zero(ComplexF64)
        for c in 2:D
            fp_val += fp_coeffs[c] * conj(psi[I, c - 1]) * psi[I, c]
        end

        E += (raman.delta * fz_val + raman.Omega_R * real(phase * fp_val)) * dV
    end
    E
end

function energy_contribution(::RamanTerm, psi::AbstractArray{<:Complex}, ws)
    ws.raman === nothing && return 0.0
    # Resolve at ws.state.t — the SAME resolution apply_step! uses above.
    # Passing raw ws.raman MethodErrors on TimeDependentRaman (post-B1
    # the registry is the only CPU energy path, so that was a reachable
    # crash — arch doc App. A defect 3).
    raman_now = raman_at(ws.raman, ws.state.t)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    return _raman_energy(
        psi, ws.spin_matrices, raman_now, ws.grid, N, n_pts, cell_volume(ws.grid)
    )
end

# Operator-trinity KNOWN-LIMIT: Raman gradient not implemented in legacy
# (LBFGS skip). apply_operator! nil to match; ITP path (apply_step!)
# remains active.
apply_operator!(out, ::RamanTerm, ws, psi) = out

# Directional oracle anchored on the PROPAGATOR (apply_raman_step!), since the
# gradient face is a declared no-op. With δ·F_z the dominant term, ITP minimises
# the energy δ·⟨F_z⟩, so the converged ⟨F_z⟩ takes the sign opposite to δ. A
# flipped δ sign in the propagator inverts ⟨F_z⟩ and trips this. (δ = 0 — pure
# transverse drive — has no F_z anchor and short-circuits to true.)
function sign_oracle(::Type{RamanTerm})
    return (
        name="RamanTerm: +δ ⇒ ⟨F_z⟩ < 0 (energy δ⟨F_z⟩ minimised by ITP)",
        predicate=function (psi, ws)
            ws.raman === nothing && return true
            r = raman_at(ws.raman, ws.state.t)
            abs(r.delta) <= 1e-30 && return true
            sm = ws.spin_matrices
            _, _, fz = spin_density_vector(psi, sm, ndims(psi) - 1)
            return sign(sum(fz) * cell_volume(ws.grid)) == -sign(r.delta)
        end,
    )
end
