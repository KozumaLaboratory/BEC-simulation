# TDHFB Yoshida-4 wrapper around the Strang sub-step (Phase 4, WIP).
#
# Status (2026-05-12, this commit): **order-4 NOT achieved**.
# Empirical convergence is order 2 with a worse prefactor than plain Strang
# at small dt. The integrator is committed as documented work-in-progress so
# downstream code (and a future palindromic substep) can plug in cleanly.
#
# Why Y4 does not deliver order 4 here
# -------------------------------------
# Yoshida-4 composition `S(w1·dt) ∘ S(w0·dt) ∘ S(w1·dt)` with
#
#     w1 = 1 / (2 − 2^(1/3)) ≈ 1.3512
#     w0 = 1 − 2·w1          ≈ −1.7024
#
# is order 4 IF the base integrator S is order 2 AND time-reversible
# (palindromic): `S(−dt) ∘ S(dt) = I + O(dt^5)`. Direct measurement on the
# current TDHFB Strang substep (see `/tmp/debug_palindrome.jl` reproducer
# in PR notes) shows the palindrome residual is `O(dt²)`, not `O(dt^5)`:
#
#     dt        |S(-dt)S(dt) - I|_∞ (ρ component)
#     0.04      7.5e-6
#     0.02      1.9e-6   (4× smaller — O(dt²))
#     0.01      4.6e-7   (4× smaller — O(dt²))
#     0.005     1.2e-7   (4× smaller — O(dt²))
#
# The asymmetry sits in the inner HF triple
# `φ-sub(dt/2; ρ_a,κ_a) → R-sub(dt) → φ-sub(dt/2; ρ_b,κ_b)`: the first
# φ-step reads (ρ, κ) BEFORE the R update; the second reads them AFTER.
# Under time reversal those (ρ, κ) tags swap, which is fine for a true
# palindrome — but the BdG matrix exponential applied as
# `(φ_new, conj(φ)_new) = top( exp(-iW^φ dt) · (φ, conj(φ)) )`
# is the upper half of a Nambu rotation and `conj(φ)_new ≠
# conj(applied result lower half)` in general (only when Δ^φ → 0). So
# the φ subupdate is NOT exactly the inverse of its negative-dt
# counterpart, leaving an O(dt²) palindrome remainder.
#
# What would fix this
# --------------------
# A genuinely palindromic TDHFB substep is needed before Y4 (or any
# Yoshida composition) can climb to order 4. Two known routes, both
# multi-session work outside Phase 4 scope:
#
#   1. **State-averaged midpoint Picard** for `(φ, ρ, κ)` simultaneously
#      (= implicit midpoint). Symmetric by construction but the prompt
#      explicitly warns this is the `§3.7.4.b AVF anti-pattern` — it
#      breaks order through a different mechanism (cos(Hτ/2) §3.3.2
#      family) and FAILS empirically per Ch.3.
#
#   2. **Full BdG-Nambu rotation** that evolves the doublet (φ, conj(φ))
#      AS the upper half of a (φ, ρ, κ)-coupled rotation that exactly
#      preserves the Nambu conjugation constraint. Equivalent to writing
#      the TDHFB EOMs in full HFB-doubled basis and matrix-exponentiating
#      the whole `(2D + 2D²) × (2D + 2D²)` generator per voxel. Order 4
#      then follows from Y4 of the symmetric ABA splitting around this
#      single dressed exponential.
#
# What this file IS useful for right now
# ---------------------------------------
#   - A documented Yoshida-4 wrapper, drop-in over `tdhfb_strang_step!`
#     and exporting the same kwargs (incl. `hfb_mode`).
#   - The `picard_iters` keyword is wired (defaults to 1 = pure Y4 on
#     top of the existing symmetric Strang triple); raising it activates
#     an endpoint-Picard loop on the inner HF substep. **EMPIRICALLY
#     this does not improve absolute error and at picard_iters ≥ 2 makes
#     it WORSE** — the endpoint (ρ, κ) used in the first φ-half-step
#     becomes biased toward the post-R values, which is an O(dt) bias
#     (not a refinement). Kept for diagnostic / follow-up use but
#     defaulted off.
#
# Reference: Yoshida 1990, Phys. Lett. A 150, 262.
# Internal narrative: docs/integrator_ch3_8_narrative.md (Track A1).

export tdhfb_y4_midpoint_step!

# Yoshida-4 composition coefficients (Yoshida 1990, eq. 4.4).
# 2·w1 + w0 = 1 (sum-of-substeps) AND 2·w1³ + w0³ = 0 (fourth-order condition).
const _TDHFB_Y4_W1 = 1.0 / (2.0 - 2.0^(1.0 / 3.0))
const _TDHFB_Y4_W0 = 1.0 - 2.0 * _TDHFB_Y4_W1

"""
    tdhfb_y4_midpoint_step!(state, F, g_S, V_ext, dt;
                            k_squared=nothing, fft_plans=nothing,
                            picard_iters=1, picard_tol=1e-10) -> state

Advance `state::TDHFBState{N}` by one **Yoshida-4 composition** of three
Strang sub-steps with widths `(w1·dt, w0·dt, w1·dt)`. Drop-in replacement
for `tdhfb_strang_step!`.

!!! warning "Phase 4 status — order 4 NOT achieved"
    Empirical convergence is order 2 (matching the underlying Strang
    substep) with a worse prefactor at small dt. The TDHFB Strang
    substep is not time-reversible at O(dt²) — see the file header
    for the diagnostic and the route to a fully palindromic substep.
    This wrapper is committed as documented Phase-4 WIP so future
    palindromic substeps can plug in without API churn.

# Arguments
Same as `tdhfb_strang_step!`. Extra keywords:

- `picard_iters::Int = 1`: number of endpoint-Picard iterations on the
  inner HF substep. `picard_iters = 1` (default) reproduces the
  existing symmetric Strang triple. `picard_iters ≥ 2` activates a
  diagnostic Picard loop — see file header for why this does NOT help
  in practice and is defaulted off.
- `picard_tol::Real = 1e-10`: convergence tolerance for Picard.
"""
function tdhfb_y4_midpoint_step!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V_ext::AbstractArray,
    dt::Float64;
    k_squared=nothing,
    fft_plans=nothing,
    picard_iters::Int=1,
    picard_tol::Real=1e-10,
) where {N}
    w1 = _TDHFB_Y4_W1
    w0 = _TDHFB_Y4_W0

    _tdhfb_strang_substep!(
        state, F, g_S, V_ext, w1 * dt;
        k_squared=k_squared, fft_plans=fft_plans,
        picard_iters=picard_iters, picard_tol=picard_tol,
    )
    _tdhfb_strang_substep!(
        state, F, g_S, V_ext, w0 * dt;
        k_squared=k_squared, fft_plans=fft_plans,
        picard_iters=picard_iters, picard_tol=picard_tol,
    )
    _tdhfb_strang_substep!(
        state, F, g_S, V_ext, w1 * dt;
        k_squared=k_squared, fft_plans=fft_plans,
        picard_iters=picard_iters, picard_tol=picard_tol,
    )

    return state
end

# One Strang sub-step (V/2 HF/2 K HF/2 V/2). At `picard_iters = 1` this is
# byte-identical to `tdhfb_strang_step!`. At `picard_iters ≥ 2` the inner
# HF substep runs an endpoint-Picard loop (diagnostic; see file header).
function _tdhfb_strang_substep!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    V_ext::AbstractArray,
    dt::Float64;
    k_squared=nothing,
    fft_plans=nothing,
    picard_iters::Int=1,
    picard_tol::Real=1e-10,
) where {N}
    _tdhfb_v_step!(state.phi, V_ext, dt / 2)
    _tdhfb_hf_step_picard!(
        state, F, g_S, dt / 2;
        picard_iters=picard_iters, picard_tol=picard_tol,
    )
    _tdhfb_kinetic_step!(state.phi, dt; k_squared=k_squared)
    _tdhfb_hf_step_picard!(
        state, F, g_S, dt / 2;
        picard_iters=picard_iters, picard_tol=picard_tol,
    )
    _tdhfb_v_step!(state.phi, V_ext, dt / 2)

    state.t += dt
    state.step += 1
    return state
end

# Picard-iterated inner HF substep.
#
# `picard_iters = 1` reproduces the symmetric Strang triple of `_tdhfb_hf_step!`
# byte-for-byte (verified by the strang-substep equivalence smoke test).
#
# `picard_iters ≥ 2` runs the iteration: restart from saved (φ, ρ, κ), but
# rebuild the FIRST φ-half-step using endpoint (ρ, κ). Empirically this
# biases φ toward post-R (ρ, κ), introducing O(dt) error — kept as
# diagnostic / placeholder for a future state-averaged variant.
function _tdhfb_hf_step_picard!(
    state::TDHFBState{N},
    F::Int,
    g_S::AbstractDict{Int, Float64},
    dt::Float64;
    picard_iters::Int=1,
    picard_tol::Real=1e-10,
) where {N}
    V = channel_kernel(F, g_S)
    half = dt / 2

    if picard_iters <= 1
        _tdhfb_phi_subupdate!(state, F, g_S, V, half)
        _tdhfb_R_subupdate!(state, F, g_S, V, dt)
        _tdhfb_phi_subupdate!(state, F, g_S, V, half)
        return state
    end

    phi0 = copy(state.phi)
    rho0 = copy(state.rho)
    kappa0 = copy(state.kappa)

    _tdhfb_phi_subupdate!(state, F, g_S, V, half)
    _tdhfb_R_subupdate!(state, F, g_S, V, dt)
    _tdhfb_phi_subupdate!(state, F, g_S, V, half)

    phi_prev = copy(state.phi)

    for _ in 2:picard_iters
        rho_endpoint = copy(state.rho)
        kappa_endpoint = copy(state.kappa)

        state.phi .= phi0
        state.rho .= rho_endpoint
        state.kappa .= kappa_endpoint
        _tdhfb_phi_subupdate!(state, F, g_S, V, half)

        state.rho .= rho0
        state.kappa .= kappa0
        _tdhfb_R_subupdate!(state, F, g_S, V, dt)
        _tdhfb_phi_subupdate!(state, F, g_S, V, half)

        delta = zero(real(eltype(state.phi)))
        @inbounds for I in eachindex(state.phi)
            delta = max(delta, abs(state.phi[I] - phi_prev[I]))
        end
        if delta < picard_tol
            break
        end
        phi_prev .= state.phi
    end

    return state
end
