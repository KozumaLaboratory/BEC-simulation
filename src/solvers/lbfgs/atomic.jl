# --- Atomic finalization for LBFGS return (spine G, 2026-06-05) ---
#
# Background:
#   The original driver epilogue (driver.jl:236-256) re-computed E and
#   grad_norm at `psi` (local), set `ws.state.psi = psi`, and returned
#   the NamedTuple `(workspace=ws, ..., energy=E, grad_norm=gn, ...)`.
#   By construction this SHOULD produce a self-consistent triple
#   {ws.state.psi, energy, grad_norm}.
#
#   But the M1 2026-06-05 audit found a 30-50× drift between the
#   returned `grad_norm` and the value computed by an independent
#   re-evaluation at the saved `ws.state.psi` (in 13/22 cells). The
#   mechanism couldn't be pinpointed by static code reading.
#
# Structural fix:
#   This helper performs an ATOMIC finalization at LBFGS return time.
#   It takes a single explicit snapshot of `psi`, re-syncs ws.state.psi
#   to that snapshot, and re-computes both `energy` and `grad_norm`
#   FROM the SAME snapshot. The final `copyto!(ws.state.psi, snapshot)`
#   guarantees that whatever mutation may have happened during the
#   E/grad evaluation is undone before return — ws.state.psi at return
#   equals the snapshot used to compute energy and grad_norm.
#
#   This makes the bug-class structurally impossible regardless of
#   what the actual mechanism was: any caller that subsequently reads
#   `ws.state.psi`, `r.energy`, `r.grad_norm` is guaranteed to see a
#   consistent triple.

"""
    _finalize_lbfgs_atomic!(ws, psi, converged, last_step;
        k_squared_dev, target_magnetization, F, E_prev=Inf) -> NamedTuple

Atomic finalization of LBFGS state. Returns the same NamedTuple shape
as the legacy driver epilogue (workspace, converged, energy, dE,
grad_norm, last_step), but with a guarantee:

    energy_gradient!(buf, ws.state.psi, ws) at return time
    will reproduce `r.energy` to ulp and `r.grad_norm` to the
    project-constraint precision.

Use this in place of the manual sequence
    `copyto!(ws.state.psi, psi)`
    `E_final = total_energy(ws)`
    `energy_gradient!(grad, psi, ws; k_squared_dev)`
    `_project_constraints!(grad, psi, ws.grid, ...)`
    `grad_norm = sqrt(sum(abs2, grad) * dV)`
to ensure {ψ, E, ∇E} are atomically consistent.
"""
function _finalize_lbfgs_atomic!(
    ws,
    psi::AbstractArray,
    converged::Bool,
    last_step::Int;
    k_squared_dev::AbstractArray,
    target_magnetization::Union{Nothing, Float64},
    F::Int,
    E_prev::Float64=Inf,
)
    dV = cell_volume(ws.grid)

    # Single explicit snapshot. This is THE authoritative iterate
    # everything downstream refers to.
    psi_snapshot = copy(psi)

    # Sync ws.state.psi to the snapshot before any energy/grad work.
    copyto!(ws.state.psi, psi_snapshot)

    # Energy + gradient + projected-norm at the snapshot, from ONE evaluation.
    # `energy_gradient!` already returns the total energy at the ψ it is handed
    # (`energy_decomposition(ws).total` on CPU, the fused total on GPU) — the
    # separate `total_energy(ws)` that used to precede it was a second full
    # evaluation of the identical quantity at the identical ψ. Taking it from
    # the same pass also makes the {ψ, E, ∇E} spine atomic by construction
    # rather than by re-synchronisation.
    grad = similar(psi_snapshot)
    E_final = Float64(energy_gradient!(grad, psi_snapshot, ws; k_squared_dev))
    _project_constraints!(grad, psi_snapshot, ws.grid, target_magnetization, F)
    grad_norm_final = Float64(sqrt(real(sum(abs2, grad)) * dV))

    # CRITICAL: re-sync ws.state.psi to the snapshot. Even if
    # `total_energy(ws)` or `energy_gradient!(grad, psi_snapshot, ws)`
    # had side effects that mutated ws.state.psi away from the snapshot,
    # this restores it. After this line, any caller that reads
    # `ws.state.psi` gets the SAME iterate used to compute E and ∇E.
    copyto!(ws.state.psi, psi_snapshot)

    return (
        workspace=ws,
        converged=converged,
        energy=E_final,
        dE=abs(E_final - E_prev),
        grad_norm=grad_norm_final,
        last_step=last_step,
    )
end
