# --- Is the verdict TRUE of the payload it is attached to? ---
#
# `MarkerVerdict` is copied verbatim from what the solver returned, and that is
# deliberate — it cannot disagree with the solver. But it also means nothing
# compares it to the ARTIFACT. Every one of the marker gates checks presence,
# shape, round-trip and internal consistency; none of them reads `psi`. Forcing
# `Bool(gs.converged)` to `true` at `run_step_ground_state.jl:711` leaves all 168
# marker assertions green.
#
# That is not a hypothetical failure mode in this repository. From
# `solvers/lbfgs/atomic.jl:418`: on 2026-06-05, 13 of 22 M1 cells had a disk
# `grad_norm` that did not survive a fresh re-evaluation at the ψ stored beside
# it. `_finalize_lbfgs_atomic!` was written to make {ψ, E, ∇E} atomic AT RETURN
# TIME. Nothing re-checks the triple after it has been through a file, a
# content-addressed rename and a `make_workspace` rebuilt from a different
# resolution path.
#
# The re-derivation is the check. `energy_gradient!` at the stored ψ in the
# workspace the CACHE HIT built reproduces the recorded energy iff the two
# workspaces state the same Hamiltonian — which is exactly what the #236 defect
# violated, where a hit dropped LHY, the light shift and the rotating frame. A
# verdict is true of its payload, or the payload is not served.
#
# Not on the admission path by accident either: `admit_payload` decides from
# bytes and their sizes and must stay a filesystem question. This needs a
# workspace and a gradient evaluation, so it belongs where the workspace already
# exists — the cache-hit branch — and it is expressed as a function of
# (verdict, ψ, ws) so the gate can call it without a pipeline.

export VerdictAudit, verify_verdict

"""
    VerdictAudit

The result of re-deriving a payload's spine and comparing it with the verdict
recorded beside it.

`checked = false` is not a pass. It means no comparison was possible — no
verdict in the marker, or no recorded energy — and the caller decides what that
is worth. Separating it from `agrees` is the difference between "the instrument
read zero" and "the instrument was not switched on".
"""
struct VerdictAudit
    checked::Bool
    agrees::Bool
    energy_recorded::Float64
    energy_rederived::Float64
    grad_norm_recorded::Float64
    grad_norm_rederived::Float64
    reason::String
end

# Tolerances, derived rather than fitted.
#
# ENERGY. Re-deriving E at the same ψ with the same code is the same arithmetic
# in a possibly different reduction order. The energy is a sum over
# N = prod(n_points) * D terms; pairwise summation (what Julia's `sum` and FFTW
# both do) carries a relative error of order sqrt(N) * eps. At 64^3 * 13 = 3.4e6
# that is 1.8e3 * 2.2e-16 ≈ 4e-13. Two decades of headroom puts the gate at
# 1e-10 — tight enough that a dropped Hamiltonian term (the #236 defect moved
# the energy by 0.64 %, i.e. 3e9 times this) cannot hide, loose enough that a
# thread-count change cannot redden it.
const _VERDICT_ENERGY_RTOL = 1.0e-10

# GRADIENT. Not the same problem. Near convergence ‖∇E‖ is a catastrophically
# cancelled quantity: its terms are O(1) and their sum is O(1e-8), so eight
# digits are gone before the reduction starts and the relative precision of the
# RESULT is ~1e-8 even when every input is exact. This repo has the measurement
# — `gotcha_lbfgs_grad_floor_not_reproducible`: 5.7e-10 / 1.4e-8 / 2.8e-8 at the
# same commit, a 25x spread, with the energy bit-exact throughout.
#
# So a tight relative gate on grad_norm would be a flake generator, and a gate
# loose enough to be safe would be a gate that passes anything. It is therefore
# ORDER OF MAGNITUDE only, and its job is correspondingly modest: catch a
# verdict describing a DIFFERENT state, where the residual is not 25x off but
# 1e6x off. The energy comparison above is the sharp instrument; this one is the
# coarse one, and saying so is more useful than a number that pretends
# otherwise.
const _VERDICT_GRAD_RATIO = 100.0

"""
    verify_verdict(verdict, psi, ws; energy_recorded, target_magnetization=nothing, F) -> VerdictAudit

Re-derive `(E, ‖∇E‖)` at `psi` in `ws` and compare with what `verdict` and
`energy_recorded` claim.

The re-derivation mirrors `_finalize_lbfgs_atomic!` exactly — one
`energy_gradient!` pass, `_project_constraints!`, then `sqrt(sum(abs2, g) * dV)`
— because a second way of computing the same certificate is a second thing that
can drift, which is the failure class this file exists to close.

`verdict === nothing` or a non-finite `energy_recorded` yields
`checked = false`: absent is absent, and inventing a pass for a payload that
declared nothing is the behaviour being removed, not added.

A `NaN` recorded `grad_norm` is normal — the ITP reports none — and is not a
failure. The energy arm still runs, which is the arm that catches a workspace
stating a different Hamiltonian.
"""
function verify_verdict(
    verdict::Union{Nothing, MarkerVerdict},
    psi::AbstractArray,
    ws;
    energy_recorded::Real,
    target_magnetization::Union{Nothing, Float64}=nothing,
    F::Union{Nothing, Int}=nothing,
)
    E_rec = Float64(energy_recorded)
    verdict === nothing && return VerdictAudit(false, false, E_rec, NaN, NaN, NaN,
        "no verdict recorded; nothing to verify against")
    isfinite(E_rec) || return VerdictAudit(false, false, E_rec, NaN,
        verdict.grad_norm, NaN, "recorded energy is not finite")

    Fv = F === nothing ? ws.atom.F : F
    # Audit where the workspace lives. The stored psi is a host `Array` even
    # when `ws` is a GPU workspace -- `_save_gs_artifact` writes `_to_host`.
    psi_ws = _is_gpu(ws.state.psi) ? _to_device(ws.backend, psi) : psi
    g = similar(ws.state.psi)
    E_new = Float64(energy_gradient!(g, psi_ws, ws))
    _project_constraints!(g, psi_ws, ws.grid, target_magnetization, Fv)
    gn_new = Float64(sqrt(real(sum(abs2, g)) * cell_volume(ws.grid)))

    gn_rec = verdict.grad_norm
    # Relative to the recorded energy's own scale. `abs(E_rec)` and not
    # `max(abs(E_rec), 1)`: a ground-state energy in these units is never near
    # zero, and hard-coding a floor would silently widen the gate for the one
    # case where it did.
    e_off = abs(E_new - E_rec) / max(abs(E_rec), eps())
    e_ok = e_off <= _VERDICT_ENERGY_RTOL

    # NaN recorded ⇒ the method reported no residual. Not a disagreement.
    g_ok = if isnan(gn_rec)
        true
    elseif gn_rec == 0 || gn_new == 0
        gn_rec == gn_new
    else
        r = gn_new / gn_rec
        (1 / _VERDICT_GRAD_RATIO) <= r <= _VERDICT_GRAD_RATIO
    end

    reason = if e_ok && g_ok
        "verdict reproduces at the stored state"
    elseif !e_ok
        # The energy arm first: it is the sharp one, and when it fires the
        # gradient arm's opinion is a consequence, not independent evidence.
        "energy does not reproduce: recorded $E_rec, re-derived $E_new " *
        "(relative $e_off > $(_VERDICT_ENERGY_RTOL)). The workspace that served " *
        "this payload states a different Hamiltonian from the one that wrote it."
    else
        "gradient does not reproduce: recorded $gn_rec, re-derived $gn_new " *
        "(ratio beyond $(_VERDICT_GRAD_RATIO)x). The verdict likely describes a " *
        "different state from the one stored."
    end
    VerdictAudit(true, e_ok && g_ok, E_rec, E_new, gn_rec, gn_new, reason)
end
