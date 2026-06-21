# --- StabilitySpec — three-valued energetic-stability gate ---
#
# `check(spec::StabilitySpec, ws, ψ) → CheckResult` answers "is this
# trapped ψ a stable minimum?" and is built to REFUSE to judge when its
# preconditions are unmet, rather than emit a false PASS/FAIL. Three
# independent axes, each with its own convergence sub-certificate:
#
#   stationarity — ψ must be a critical point (‖g − 2μψ‖/‖g‖ < ε_stat)
#                  before the second-variation verdict means anything.
#                  The historical false verdict (memory:
#                  mistake_stability_verdict_from_nonstationary_point) was
#                  a λ_min read off a non-stationary ψ; this axis gates it.
#   energetic    — sign of the lowest constrained-Hessian eigenvalue
#                  (λ_min < 0 ⇒ saddle / anomalous direction). The sign is
#                  trusted ONLY if (a) the Lanczos Ritz residual is small
#                  (converged) AND (b) |λ_min| is resolvable above the
#                  stationarity error — a slightly-off ψ builds the operator
#                  at the wrong point and can flip a small λ_min's sign.
#   dynamical    — complex BdG frequency ⇒ exponential growth. The TRAPPED
#                  non-Hermitian BdG is not built yet (phase 2), so this
#                  axis returns :indeterminate; overall status therefore
#                  never reaches :pass until it exists. A half-built
#                  verifier abstains; it does not over-claim.
#
# overall = :fail if any axis fails; else :indeterminate if any axis is
# indeterminate; else :pass.

export StabilitySpec

"""
    StabilitySpec(; ε_stat=1e-4, tol_ritz=1e-2, λ_tol=1e-6, couple=10.0, niter=60)

Bounds for the three-valued stability gate. `ε_stat` = relative
stationarity residual bound; `tol_ritz` = Lanczos Ritz residual relative
to |λ_min| for the energetic sign to count as converged; `λ_tol` = |λ_min|
below which the curvature is treated as marginal (not a saddle); `couple`
= require |λ_min| > couple·‖g−2μψ‖ for the sign to be resolvable above the
stationarity error; `niter` = Lanczos iterations.
"""
struct StabilitySpec
    ε_stat::Float64
    tol_ritz::Float64
    λ_tol::Float64
    couple::Float64
    niter::Int

    StabilitySpec(;
        ε_stat::Real=1.0e-4, tol_ritz::Real=1.0e-2, λ_tol::Real=1.0e-6,
        couple::Real=10.0, niter::Integer=60,
    ) = new(
        Float64(ε_stat), Float64(tol_ritz), Float64(λ_tol),
        Float64(couple), Int(niter),
    )
end

function check(spec::StabilitySpec, ws, ψ; rng=Random.default_rng())
    details = Pair{Symbol, Any}[]

    # --- stationarity axis ---------------------------------------------
    dV = cell_volume(ws.grid)
    n2 = real(sum(abs2, ψ)) * dV
    g = similar(ψ)
    fill!(g, 0)
    energy_gradient!(g, ψ, ws)
    μ = real(sum(conj.(ψ) .* g)) * dV / (2 * n2)
    gproj = g .- 2μ .* ψ
    stat_abs = sqrt(real(sum(abs2, gproj)) * dV)
    g_abs = sqrt(real(sum(abs2, g)) * dV)
    stat_rel = stat_abs / max(g_abs, 1e-30)
    stat_status = stat_rel < spec.ε_stat ? :pass : :indeterminate
    push!(details, :stationarity => (
        got=stat_rel, bound=spec.ε_stat, status=stat_status))

    # --- energetic axis (constrained-Hessian λ_min, self-certifying) ---
    bdg = trapped_bdg_lowest_eigenvalue(
        ws, ψ; niter=spec.niter, tol_ritz=spec.tol_ritz, rng)
    energetic = if !bdg.converged
        :indeterminate                      # Ritz residual not ≪ |λ_min|
    elseif bdg.λ_min < -spec.λ_tol
        :fail                               # saddle / anomalous direction
    else
        :pass                               # energetic minimum (λ_min ≥ −λ_tol)
    end
    # joint resolution: a slightly-off ψ can flip a small λ_min's sign.
    if energetic !== :indeterminate && abs(bdg.λ_min) < spec.couple * stat_abs
        energetic = :indeterminate
    end
    push!(
        details,
        :energetic => (
            λ_min=bdg.λ_min, ritz_residual=bdg.ritz_residual,
            niter_used=bdg.niter_used, converged=bdg.converged, status=energetic),
    )

    # --- dynamical axis (trapped non-Hermitian BdG — phase 2, abstain) -
    dyn_status = :indeterminate
    push!(details, :dynamical => (
        got="trapped non-Hermitian BdG not built", status=dyn_status))

    # --- combine -------------------------------------------------------
    axes = (stat_status, energetic, dyn_status)
    overall = if any(==(:fail), axes)
        :fail
    elseif any(==(:indeterminate), axes)
        :indeterminate
    else
        :pass
    end
    summary =
        "StabilitySpec: $(uppercase(string(overall))) " *
        "[stationarity=$(stat_status) energetic=$(energetic) " *
        "dynamical=$(dyn_status)] " *
        "λ_min=$(round(bdg.λ_min, sigdigits=4)) " *
        "ritz=$(round(bdg.ritz_residual, sigdigits=3)) " *
        "stat_rel=$(round(stat_rel, sigdigits=3))"
    CheckResult(overall, details, summary)
end
