# --- LHY HamTerm ---
#
# Lee-Huang-Yang correction. Multiple LHY models share a HamTerm:
# the propagator/energy/gradient go through ws.lhy.

"""LHY beyond-mean-field correction. Repulsive by physics."""
struct LHY <: HamTerm end

function apply_step!(::LHY, psi, dt::Real, imaginary_time::Bool, ws)
    # LHY is folded into the diagonal step in the legacy implementation;
    # at the HamTerm level we delegate via apply_lhy_step! if available.
    ws.lhy === nothing && ws.interactions.c_lhy == 0.0 && return nothing
    apply_lhy_step!(psi, ws, dt; imaginary_time=imaginary_time)
    return nothing
end

function energy_contribution(::LHY, psi::AbstractArray{<:Complex}, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    if ws.lhy !== nothing
        return _lhy_energy(psi, ws.lhy, n_comp, N, n_pts, cell_volume(ws.grid))
    elseif ws.interactions.c_lhy != 0.0
        return _lhy_energy(psi, ws.interactions.c_lhy, n_comp, N, n_pts, cell_volume(ws.grid))
    end
    return 0.0
end

function add_gradient!(grad, ::LHY, psi, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    n_density = total_density(psi, N)
    _grad_lhy!(grad, psi, ws, n_density, n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{LHY}) = (name="LHY: repulsive", predicate=(_, _) -> true)
