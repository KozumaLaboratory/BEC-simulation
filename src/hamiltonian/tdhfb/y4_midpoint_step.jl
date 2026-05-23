# TDHFB Yoshida-4 wrapper around the Strang sub-step.
#
# Status: **A4 acceptance ACHIEVED via `picard_midpoint=true`** — order 4
# measured (test `Y7`, state-error vs reference: ~4.05). Default off
# because the wall-time / accuracy trade is regime-dependent (see below).
#
# Why a palindromic substep is required
# --------------------------------------
# Yoshida-4 composition `S(w1·dt) ∘ S(w0·dt) ∘ S(w1·dt)` is order 4 IFF
# the base integrator S is order 2 AND time-reversible (palindromic):
# `S(−dt) ∘ S(dt) = I + O(dt^5)`. The plain TDHFB Strang substep has an
# O(dt²) palindrome residual: the inner HF triple
# `φ-sub(dt/2; ρ_a,κ_a) → R-sub(dt) → φ-sub(dt/2; ρ_b,κ_b)` reads
# (ρ, κ) BEFORE the R update on the first φ-step and AFTER on the second
# — under time reversal those tags swap, but the BdG matrix exponential
# acts as the upper half of a Nambu rotation, so the φ subupdate is NOT
# exactly the inverse of its negative-dt counterpart.
#
# Palindrome residual is state-dependent (B-1 diagnostic, 2026-05-13):
# the leading O(dt²) commutator coefficient is *linear* in the Nambu
# anomalous source (ρ, κ). Concretely:
#   - vacuum ρ=κ=0:  coefficient vanishes → slope 4 (not 2). Special case.
#   - pre-evolved / random:  slope 2.00 (production regime).
# Memo: [[integrator-palindrome-state-dependent]] +
# `scripts/diagnostic/palindrome_residual_probe.jl`. Don't confuse the
# vacuum-init unit test slope with the production palindromicity.
#
# How `picard_midpoint=true` fixes it (A4 acceptance path)
# ---------------------------------------------------------
# Routes through `_tdhfb_hf_step_picard_midpoint!` instead of
# `_tdhfb_hf_step!`. The inner HF substep iterates a midpoint-
# state Picard fixed point on (φ_mid, ρ_mid, κ_mid) at tol=1e-12,
# converges in 4-6 iterations, and the resulting substep is palindromic
# to machine eps (verified `/tmp/picard_mrmdag_no_doublet.jl`). Combined
# with the M·R·M† bosonic Bogoliubov fix in `strang_step.jl`, this
# unlocks the Y4 composition's order-4 scaling.
#
# Cost & trade-off (see `tdhfb_a4_default_decision.md`):
#   - `picard_midpoint=true` runs ~5× per HF substep (Picard ~5 iter).
#     Total Y4+Picard step is ~12-15× plain Strang.
#   - Pays off for long-time accuracy / large-dt regimes where dt⁴
#     resolution clears the Strang dt² floor (~1e-8 error threshold).
#   - Loose tolerance (>1e-6) or short-time: plain `tdhfb_strang_step!`
#     is more wall-time efficient.
#
# State-averaged midpoint Picard on (φ, ρ, κ) simultaneously is a
# KNOWN anti-pattern (`§3.7.4.b`, cos(Hτ/2) family) — NOT what
# `picard_midpoint=true` does. The A4 fix iterates Picard on the
# midpoint state only, with the M·R·M† Nambu update guaranteeing
# Hermiticity preservation.
#
# Reference: Yoshida 1990, Phys. Lett. A 150, 262.
# Internal narrative: docs/integrator_ch3_8_narrative.md (Track A1).
# Memo: tdhfb_a4_closed.md, tdhfb_a4_picard_minimal_scope.md.

export tdhfb_y4_midpoint_step!

# Yoshida-4 composition coefficients (Yoshida 1990, eq. 4.4).
# 2·w1 + w0 = 1 (sum-of-substeps) AND 2·w1³ + w0³ = 0 (fourth-order condition).
const _TDHFB_Y4_W1 = 1.0 / (2.0 - 2.0^(1.0 / 3.0))
const _TDHFB_Y4_W0 = 1.0 - 2.0 * _TDHFB_Y4_W1

"""
    tdhfb_y4_midpoint_step!(state, F, g_S, V_ext, dt;
                            k_squared=nothing,
                            hfb_mode=:full_hfb) -> state

Advance `state::TDHFBState{N}` by one **Yoshida-4 composition** of three
Strang sub-steps with widths `(w1·dt, w0·dt, w1·dt)`. Drop-in replacement
for `tdhfb_strang_step!`.

!!! note "Order 4 requires `picard_midpoint=true`"
    Without `picard_midpoint=true`, this wrapper inherits the underlying
    Strang substep's O(dt²) non-palindromicity → empirical convergence
    rate is ~order 1, *worse* than plain `tdhfb_strang_step!` (order 2).
    With `picard_midpoint=true`, the inner HF substep becomes palindromic
    via midpoint-state Picard iteration → order 4 measured (test `Y7`,
    state-error vs reference: 4.05).

    Cost: `picard_midpoint=true` runs ~5× per HF substep (Picard ~5 iter).
    Total Y4-Picard step is ~15× plain Strang step.

    Trade-off (use state-error vs reference, NOT energy drift — the
    latter is confounded by initial-state physics and saturates near
    F64 floor for equilibrium states):
    - Long-time state accuracy: Y4-Picard wins (order 4 vs order 2 of
      Strang) when error tolerance is below the dt² floor of Strang at
      affordable dt. dt⁴ resolution kicks in roughly at 1e-8 error.
    - Short-time / loose tolerance: plain `tdhfb_strang_step!` is more
      wall-time efficient (order 2 is plenty when tolerance > 1e-6).

# Arguments
Same as `tdhfb_strang_step!`. Extra keywords:

- `hfb_mode::Symbol = :full_hfb`: BdG generator mode for the φ subupdate;
  see `tdhfb_strang_step!` docstring for `:full_hfb` vs `:popov` semantics.
- `picard_midpoint::Bool = false`: enable midpoint-state Picard on the
  inner HF substep (A4 acceptance fix). Default off because the wall-
  time / accuracy trade is regime-dependent (see warning above).
- `picard_midpoint_max_iter::Int = 20`: Picard-midpoint iteration cap.
- `picard_midpoint_tol::Float64 = 1e-12`: Picard-midpoint convergence
  tolerance.
"""
function tdhfb_y4_midpoint_step!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V_ext::AbstractArray,
    dt::Float64;
    k_squared=nothing,
    hfb_mode::Symbol=:full_hfb,
    picard_midpoint::Bool=false,
    picard_midpoint_max_iter::Int=20,
    picard_midpoint_tol::Float64=1e-12,
) where {N}
    w1 = _TDHFB_Y4_W1
    w0 = _TDHFB_Y4_W0

    _tdhfb_strang_substep!(
        state, F, g_S, V_ext, w1 * dt;
        k_squared=k_squared, hfb_mode=hfb_mode,
        picard_midpoint=picard_midpoint,
        picard_midpoint_max_iter=picard_midpoint_max_iter,
        picard_midpoint_tol=picard_midpoint_tol,
    )
    _tdhfb_strang_substep!(
        state, F, g_S, V_ext, w0 * dt;
        k_squared=k_squared, hfb_mode=hfb_mode,
        picard_midpoint=picard_midpoint,
        picard_midpoint_max_iter=picard_midpoint_max_iter,
        picard_midpoint_tol=picard_midpoint_tol,
    )
    _tdhfb_strang_substep!(
        state, F, g_S, V_ext, w1 * dt;
        k_squared=k_squared, hfb_mode=hfb_mode,
        picard_midpoint=picard_midpoint,
        picard_midpoint_max_iter=picard_midpoint_max_iter,
        picard_midpoint_tol=picard_midpoint_tol,
    )

    return state
end

# One Strang sub-step (V/2 HF/2 K HF/2 V/2). At `picard_midpoint=false`
# this is byte-identical to `tdhfb_strang_step!`. `picard_midpoint=true`
# swaps the inner HF substeps to the midpoint-Picard variant (palindromic
# at Picard tolerance → unlocks Y4 order 4).
function _tdhfb_strang_substep!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V_ext::AbstractArray,
    dt::Float64;
    k_squared=nothing,
    hfb_mode::Symbol=:full_hfb,
    picard_midpoint::Bool=false,
    picard_midpoint_max_iter::Int=20,
    picard_midpoint_tol::Float64=1e-12,
) where {N}
    _tdhfb_v_step!(state.phi, V_ext, dt / 2)
    if picard_midpoint
        _tdhfb_hf_step_picard_midpoint!(
            state, F, g_S, dt / 2;
            hfb_mode=hfb_mode,
            max_iter=picard_midpoint_max_iter,
            tol=picard_midpoint_tol,
        )
    else
        _tdhfb_hf_step!(state, F, g_S, dt / 2; hfb_mode=hfb_mode)
    end
    _tdhfb_kinetic_step!(state.phi, dt; k_squared=k_squared)
    if picard_midpoint
        _tdhfb_hf_step_picard_midpoint!(
            state, F, g_S, dt / 2;
            hfb_mode=hfb_mode,
            max_iter=picard_midpoint_max_iter,
            tol=picard_midpoint_tol,
        )
    else
        _tdhfb_hf_step!(state, F, g_S, dt / 2; hfb_mode=hfb_mode)
    end
    _tdhfb_v_step!(state.phi, V_ext, dt / 2)

    state.t += dt
    state.step += 1
    return state
end
