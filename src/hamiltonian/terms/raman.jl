# --- Raman HamTerm ---
#
# Raman coupling via ws.raman. Sign convention is encoded in
# apply_raman_step! + _raman_energy. Gradient not implemented.

"""Raman two-photon coupling."""
struct Raman <: HamTerm end

function apply_step!(::Raman, psi, dt::Real, imaginary_time::Bool, ws)
    ws.raman === nothing && return nothing
    raman_now = raman_at(ws.raman, ws.state.t)
    apply_raman_step!(psi, ws.spin_matrices, raman_now, ws.grid, dt; imaginary_time)
    return nothing
end

function energy_contribution(::Raman, psi::AbstractArray{<:Complex}, ws)
    ws.raman === nothing && return 0.0
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    return _raman_energy(psi, ws.spin_matrices, ws.raman, ws.grid, N, n_pts, cell_volume(ws.grid))
end

# Raman gradient not covered in legacy energy_gradient! (LBFGS
# limitation). Mirror.
add_gradient!(grad, ::Raman, psi, ws) = nothing

sign_oracle(::Type{Raman}) = (name="Raman: KNOWN-LIMIT (no gradient)", predicate=(_, _) -> true)
