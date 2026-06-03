# --- Loss HamTerm ---
#
# Three-body loss (K3) is non-Hermitian, applied in RT only.
# Energy/gradient contributions are undefined (the loss is not a
# Hamiltonian piece in the standard sense).

"""Three-body K3 loss. RT only; non-Hermitian."""
struct Loss <: HamTerm end

function apply_step!(::Loss, psi, dt::Real, imaginary_time::Bool, ws)
    (imaginary_time || ws.loss === nothing) && return nothing
    N = ndims(psi) - 1
    F = ws.spin_matrices.system.F
    D = ws.spin_matrices.system.n_components
    apply_loss_step!(psi, ws.loss, F, dt, D, N, ws.density_buf)
    return nothing
end

energy_contribution(::Loss, psi, ws) = 0.0
add_gradient!(grad, ::Loss, psi, ws) = nothing

sign_oracle(::Type{Loss}) = (name="Loss: non-Hermitian, RT-only", predicate=(_, _) -> true)
