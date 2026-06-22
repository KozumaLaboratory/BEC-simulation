# Adaptive timestep control for split_step_midpoint! and compatible step
# functions. Implements the Hairer-Wanner defect estimator (Richardson via
# ψ_full = S(dt) ψ vs ψ_half = S(dt/2)² ψ) combined with the Söderlind PI3.4
# step-size controller (α = 0.7/p, β = -0.4/p; negative β dampens dt
# oscillation seen with naive α=β=1/(p+1)).
#
# Bench validation:
#   - scripts/bench/track_a3_adaptive_y4mid.jl (smooth Phase 2a)
#   - scripts/bench/track_a3_adaptive_burst.jl (Gaussian Zeeman pulse)
#
# Status (2026-05-12): bench-validated for the Y4-mid / split_step_midpoint!
# pair on Rb87 F=1 16³ lab path. Defect overhead is 3× per accepted step
# (one S(dt) + two S(dt/2)), so adaptive wins only on problems with
# steep local stiffness contrast.

export AdaptiveDtState, adaptive_step!, adaptive_run!

"""
    AdaptiveDtState(dt_init)

State for the adaptive step-size controller. Tracks the previous defect
(used by the PI controller's derivative term) and accumulators for
accepted / rejected step counts. `dt` is the current step-size estimate
that `adaptive_step!` updates after each accepted step.

Reset between independent integration runs by constructing a fresh state.
"""
mutable struct AdaptiveDtState
    defect_prev::Float64
    n_accept::Int
    n_reject::Int
    dt::Float64
end

AdaptiveDtState(dt_init::Real) = AdaptiveDtState(NaN, 0, 0, Float64(dt_init))

"""
    adaptive_step!(ws, state; tol_abs, tol_rel, ...) -> dt_used

Take one adaptive timestep on `ws` using the Hairer-Wanner defect
estimator and the Söderlind PI3.4 controller.

Defect: `defect = ‖S(dt) ψ - S(dt/2)² ψ‖` where S is the `step!` function
(default `split_step_yoshida4_midpoint!`, a genuine 4th-order step on the DDI
path). This estimates the local truncation error of the full step at order p
(default 4, consistent with the 4th-order default step). Pass
`step!=split_step_midpoint!` with `p=2` for the cheaper 2nd-order adaptive.

Tolerance: accept when `defect ≤ tol_abs + tol_rel · ‖ψ_half‖`.

On accept: ψ is set to ψ_half (slightly more accurate than ψ_full).
`state.dt` is updated with the PI-controller proposal for the next step.

On reject: ψ is restored to entry value, dt is shrunk, retry. Maximum
`max_rejects` retries before raising `error`.

Returns the dt actually used (may differ from `state.dt` if rejections
occurred).

Cost: 3× the cost of one `step!(ws)` per accepted step (one full + two
halves).
"""
function adaptive_step!(ws::Workspace{N}, state::AdaptiveDtState;
    tol_abs::Float64=1e-9,
    tol_rel::Float64=1e-7,
    safety::Float64=0.9,
    p::Int=4,
    pi_alpha::Float64=0.7 / p,
    pi_beta::Float64=-0.4 / p,
    max_factor::Float64=5.0,
    min_factor::Float64=0.05,
    max_rejects::Int=12,
    step!::F=(split_step_yoshida4_midpoint!),
) where {N, F}
    α = pi_alpha
    β = pi_beta
    dt = state.dt
    t_entry = ws.state.t
    step_entry = ws.state.step

    psi_backup = similar(ws.state.psi)
    psi_full = similar(ws.state.psi)
    psi_backup .= ws.state.psi

    n_rejects = 0
    while n_rejects ≤ max_rejects
        # Full step at dt
        ws.state.psi .= psi_backup
        ws.state.t = t_entry
        ws.state.step = step_entry
        step!(ws; dt=dt)
        psi_full .= ws.state.psi

        # Two half-steps at dt/2 → ψ_half (kept in ws.state.psi)
        ws.state.psi .= psi_backup
        ws.state.t = t_entry
        ws.state.step = step_entry
        step!(ws; dt=dt / 2)
        step!(ws; dt=dt / 2)

        # Defect from Richardson comparison
        defect = sqrt(sum(abs2, psi_full .- ws.state.psi))
        normψ = sqrt(sum(abs2, ws.state.psi))
        tol = tol_abs + tol_rel * normψ

        if defect ≤ tol
            # Accept: ψ_half (in ws.state.psi) is the result. Time/step
            # already advanced by the two half-steps.
            if isnan(state.defect_prev) || state.defect_prev == 0.0
                factor = safety * (tol / defect)^α
            else
                factor = safety * (tol / defect)^α * (state.defect_prev / defect)^β
            end
            factor = clamp(factor, min_factor, max_factor)
            state.dt = dt * factor
            state.defect_prev = defect
            state.n_accept += 1
            state.n_reject += n_rejects
            return dt
        end

        # Reject: restore and shrink dt
        ws.state.psi .= psi_backup
        ws.state.t = t_entry
        ws.state.step = step_entry
        factor = clamp(safety * (tol / defect)^α, min_factor, 0.5)
        dt *= factor
        n_rejects += 1
    end
    error(
        "adaptive_step!: exceeded max_rejects=$max_rejects at t=$t_entry, " *
        "trial dt=$dt. Tighten tol or check problem stiffness.",
    )
end

"""
    adaptive_run!(ws; t_end, dt_init, tol_abs, tol_rel, save_history, kwargs...) -> NamedTuple

Outer adaptive loop: integrate from current `ws.state.t` to `t_end` using
`adaptive_step!` repeatedly. The final dt of each step is clamped so the
trajectory lands exactly at `t_end`.

Returns a NamedTuple `(n_accept, n_reject, t_history, dt_history,
defect_history)`. History vectors are populated when `save_history=true`
(default) and are empty otherwise.

`kwargs` are forwarded to `adaptive_step!` (e.g., `tol_abs`, `tol_rel`,
`safety`, `p`, `pi_alpha`, `pi_beta`, `max_factor`, `min_factor`,
`max_rejects`, `step!`).
"""
function adaptive_run!(ws::Workspace{N};
    t_end::Float64,
    dt_init::Float64=ws.sim_params.dt,
    tol_abs::Float64=1e-9,
    tol_rel::Float64=1e-7,
    save_history::Bool=true,
    kwargs...,
) where {N}
    state = AdaptiveDtState(dt_init)
    t_history = Float64[]
    dt_history = Float64[]
    defect_history = Float64[]

    while ws.state.t < t_end - 1e-12
        # Clip dt so we don't overshoot t_end.
        dt_try = min(state.dt, t_end - ws.state.t)
        state.dt = dt_try
        dt_used = adaptive_step!(ws, state;
            tol_abs=tol_abs, tol_rel=tol_rel, kwargs...)
        if save_history
            push!(t_history, ws.state.t)
            push!(dt_history, dt_used)
            push!(defect_history, state.defect_prev)
        end
    end

    (
        n_accept=state.n_accept,
        n_reject=state.n_reject,
        t_history=t_history,
        dt_history=dt_history,
        defect_history=defect_history,
    )
end
