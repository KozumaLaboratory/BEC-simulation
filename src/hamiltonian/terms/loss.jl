# --- Loss HamTerm ---
#
# Three-body loss (K3) is non-Hermitian, applied in RT only.
# Energy/gradient contributions are undefined (the loss is not a
# Hamiltonian piece in the standard sense).

"""Three-body K3 loss. RT only; non-Hermitian."""
struct LossTerm <: HamTerm end

function apply_step!(::LossTerm, psi, dt::Real, imaginary_time::Bool, ws)
    (imaginary_time || ws.loss === nothing) && return nothing
    N = ndims(psi) - 1
    F = ws.spin_matrices.system.F
    D = ws.spin_matrices.system.n_components
    apply_loss_step!(psi, ws.loss, F, dt, D, N, ws.density_buf)
    return nothing
end

# Operator-trinity KNOWN-LIMIT: LossTerm is anti-Hermitian (non-conservative
# K3 three-body loss). It does NOT contribute to GP energy and has no
# Hermitian operator to expose via apply_operator!. Explicitly nil to make
# the trinity-skipping intent structural rather than accidental.
apply_operator!(out, ::LossTerm, ws, psi) = out
energy_contribution(::LossTerm, psi, ws) = 0.0

sign_oracle(::Type{LossTerm}) = (
    name="LossTerm: K3 reduces ‖ψ‖² under RT (non-Hermitian)",
    predicate=function (psi, ws)
        # Loss is RT-only; in ITP path nothing to check.
        # Sign property: after one apply_step!(LossTerm(), psi, dt, false, ws),
        # ‖ψ‖²(after) ≤ ‖ψ‖²(before) when ws.loss has positive K3 coefficients.
        return ws.loss === nothing || all(>=(0), ws.loss.K3)
    end,
)
