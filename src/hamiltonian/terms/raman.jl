# --- Raman HamTerm ---
#
# Raman coupling via ws.raman. Sign convention is encoded in
# apply_raman_step! + _raman_energy. Gradient not implemented.

"""Raman two-photon coupling."""
struct RamanTerm <: HamTerm end

function apply_step!(::RamanTerm, psi, dt::Real, imaginary_time::Bool, ws)
    ws.raman === nothing && return nothing
    raman_now = raman_at(ws.raman, ws.state.t)
    apply_raman_step!(psi, ws.spin_matrices, raman_now, ws.grid, dt; imaginary_time)
    return nothing
end

# ============================================================================
# Canonical energy kernel. Propagator `apply_raman_step!` stays in
# `potentials/raman.jl` — that file owns the rotation-cache subsystem.
# ============================================================================

"""
    _raman_energy(psi, sm, raman, grid, ndim, n_pts, dV)

`E_Raman = ∫ d³r [δ·⟨F_z⟩ + Ω_R·Re(e^{ik·r}·⟨F_+⟩)]` per voxel.
Manual per-voxel reduction inlines the kr phase + Fz/F+ contractions.
"""
function _raman_energy(psi, sm::SpinMatrices{D}, raman::RamanCoupling{N},
    grid::Grid{N}, ndim, n_pts, dV) where {D, N}
    F = sm.system.F
    Ff1 = Float64(F * (F + 1))
    m_vals = ntuple(c -> Float64(F - (c - 1)), Val(D))
    fp_coeffs = ntuple(c -> c == 1 ? 0.0 : sqrt(Ff1 - m_vals[c] * (m_vals[c] + 1.0)), Val(D))

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
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    return _raman_energy(
        psi, ws.spin_matrices, ws.raman, ws.grid, N, n_pts, cell_volume(ws.grid)
    )
end

# Operator-trinity KNOWN-LIMIT: Raman gradient not implemented in legacy
# (LBFGS skip). apply_operator! nil to match; ITP path (apply_step!)
# remains active.
apply_operator!(out, ::RamanTerm, ws, psi) = (fill!(out, zero(eltype(out))); out)
add_gradient!(grad, ::RamanTerm, psi, ws) = nothing

sign_oracle(::Type{RamanTerm}) = (
    name="RamanTerm: KNOWN-LIMIT (no gradient implemented)",
    predicate=(_, _) -> true,
)
