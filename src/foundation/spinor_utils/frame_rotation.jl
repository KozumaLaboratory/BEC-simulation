# Frame rotation Û_B(t) — the lab↔field-following ("tilde") basis transform.
#
# `ψ_lab = Û_B(t) ψ̃` with `Û_B = exp(-iφ F_z) exp(-iθ F_y)` aligns the
# quantization axis with B̂(t)=(θ,φ). After the rotating-basis engine was
# retired (2026-06-21, docs/design/rotating_basis_unification.md), the only
# remaining consumers are the magnetostir pipeline handlers
# (run_step_rotating/{ground_state,dynamics}.jl): they evolve in the LAB frame
# on the standard split-step path and use this transform purely to seed from /
# report in the field-following frame. Depends only on the uniform spin-rotation
# helpers (`_compute_uniform_rotation_matrix`, `_apply_rotation_to_spin_axis!` in
# spinor_utils/uniform_rotation.jl).

"""
ψ_lab = Û_B(t) ψ̃  with  Û_B = exp(-iφ F_z) exp(-iθ F_y).

`inverse=true` applies Û_B† (ψ_lab → ψ̃). Direction "tilde→lab": apply
exp(-iθ F_y) first, then exp(-iφ F_z).
"""
function _apply_UB!(
    psi::AbstractArray{<:Complex}, sm::SpinMatrices{D}, theta::T, phi::T, ndim::Int;
    inverse::Bool=false, scratch=nothing,
) where {T, D}
    θ = Float64(theta)
    φ = Float64(phi)
    abs(θ) + abs(φ) < 1e-30 && return nothing
    R = _UB_combined_rotation(sm, θ, φ, inverse)
    _apply_rotation_to_spin_axis!(psi, R, ndim; scratch=scratch)
    nothing
end

# Build the composed Û_B rotation R = R_z(±φ) · R_y(±θ) once. Forward
# (inverse=false) gives ψ̃ → ψ_lab; inverse=true gives ψ_lab → ψ̃ via
# the conj-order product R_y(-θ) · R_z(-φ).
@inline function _UB_combined_rotation(
    sm::SpinMatrices{D}, θ::Float64, φ::Float64, inverse::Bool
) where {D}
    sgn = inverse ? -1.0 : 1.0
    R_y = _compute_uniform_rotation_matrix(sm, 0.0, sgn * θ, 0.0, 1.0, false)
    R_z = _compute_uniform_rotation_matrix(sm, 0.0, 0.0, sgn * φ, 1.0, false)
    inverse ? R_y * R_z : R_z * R_y
end
