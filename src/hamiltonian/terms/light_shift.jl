# --- LightShift HamTerm ---
#
# Light shift via ws.light_shift. Per-component diagonal or full
# off-diagonal matrix per voxel. Energy was MISSING in pre-2026-06-04
# GPU implementation (fixed as part of the GAP analysis).

"""Optical light-shift potential."""
struct LightShift <: HamTerm end

function apply_step!(::LightShift, psi, dt::Real, imaginary_time::Bool, ws)
    ws.light_shift === nothing && return nothing
    # Light shift is folded into the diagonal step with `_diagonal_step_with_ls!`.
    # Standalone application: per-component for diagonal LightShift.
    ls = ws.light_shift
    N = ndims(psi) - 1
    D = size(psi, N + 1)
    if ls.is_diagonal
        for c in 1:D
            phase = ls.eigvals[c] .* ls.profile
            if imaginary_time
                view(psi, ntuple(_ -> :, Val(N))..., c) .*= exp.(.-phase .* dt)
            else
                view(psi, ntuple(_ -> :, Val(N))..., c) .*= cis.(.-phase .* dt)
            end
        end
    else
        error(
            "Off-diagonal LightShift propagator not yet exposed as a standalone HamTerm; use legacy path"
        )
    end
    return nothing
end

function energy_contribution(::LightShift, psi::AbstractArray{<:Complex}, ws)
    ws.light_shift === nothing && return 0.0
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    return _light_shift_energy(psi, ws.light_shift, n_comp, N, n_pts, cell_volume(ws.grid))
end

function add_gradient!(grad, ::LightShift, psi, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    _grad_light_shift!(grad, psi, ws, n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{LightShift}) = (
    name="LightShift: per-state eigval-defined sign",
    predicate=(_, _) -> true,
)
