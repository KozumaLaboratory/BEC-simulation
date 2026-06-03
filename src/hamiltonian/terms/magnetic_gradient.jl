# --- MagneticGradient HamTerm ---
#
# Spatially-varying B_z along one axis: H_MG = +g_F · grad · x_axis · F_z
# folds into V_trap via _apply_mg_to_V! per split_step.jl:130.

"""Magnetic gradient along a single axis."""
struct MagneticGradient <: HamTerm end

function apply_step!(::MagneticGradient, psi, dt::Real, imaginary_time::Bool, ws)
    # Magnetic gradient modifies V_trap. The propagator does this
    # via _apply_mg_to_V! + _remove_mg_from_V! bracketing the diag
    # step. As a standalone HamTerm, the user must use the full
    # pipeline; standalone propagator step is not separable.
    return nothing
end

function energy_contribution(::MagneticGradient, psi::AbstractArray{<:Complex}, ws)
    # MG contribution to energy is included via V_trap when MG is active
    # (since _apply_mg_to_V! adds g_F·grad·x to potential_values).
    # Standalone contribution: avoid double-counting; return 0.
    return 0.0
end

add_gradient!(grad, ::MagneticGradient, psi, ws) = nothing

sign_oracle(::Type{MagneticGradient}) = (
    name="MagneticGradient: positive gradient pushes +F_z to +x_axis",
    predicate=(_, _) -> true,
)
