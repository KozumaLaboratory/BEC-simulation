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
#   dynamical    — complex BdG frequency ⇒ exponential growth. The trapped
#                  non-Hermitian BdG (`trapped_bdg_spectrum`) is dense
#                  (phase 2a): real spectrum ⇒ :pass, complex ω ⇒ :fail.
#                  Systems past the dense cap abstain (:indeterminate) until
#                  the matrix-free Arnoldi (phase 2b) lands — a half-built
#                  verifier abstains, it does not over-claim.
#
# overall = :fail if any axis fails; else :indeterminate if any axis is
# indeterminate; else :pass.

export StabilitySpec

"""
    StabilitySpec(; ε_stat=1e-4, tol_ritz=1e-2, λ_tol=1e-6, couple=10.0, niter=300)

Bounds for the three-valued stability gate. `ε_stat` = relative
stationarity residual bound; `tol_ritz` = Lanczos Ritz residual relative
to |λ_min| for the energetic sign to count as converged; `λ_tol` = |λ_min|
below which the curvature is treated as marginal (not a saddle); `couple`
= require |λ_min| > couple·‖g−2μψ‖ for the sign to be resolvable above the
stationarity error; `niter` = Lanczos iteration CAP (adaptive early-stop ⇒
gapped cells finish in tens of iters; soft cells near a phase boundary, where
λ_min→0, need the larger cap — production strong-coupling Eu needed ~400, so
the default is 300 with the `converged` flag honestly reporting when even that
is short); `tol_dyn` = growth-rate
threshold RELATIVE to the spectral radius; `tol_quartet` = BdG symmetry
self-check bound; `bdg_dim_cap` = max dense BdG dimension before the
dynamical axis abstains.

CONTRACT NOTE: unlike the jld2-target specs (`check(::ConservationSpec,
::RunResult)` etc.), `check(::StabilitySpec, ws, ψ)` operates on a LIVE
`(Workspace, ψ)` because the second-variation operator needs the
Hamiltonian, which a `RunResult` does not carry. It is therefore invoked
directly, not through the single-target collection funnel
(`check(spec, exp::Experiment)`).
"""
struct StabilitySpec
    ε_stat::Float64
    tol_ritz::Float64
    λ_tol::Float64
    couple::Float64
    niter::Int
    tol_dyn::Float64
    tol_quartet::Float64
    bdg_dim_cap::Int

    StabilitySpec(;
        ε_stat::Real=1.0e-4, tol_ritz::Real=1.0e-2, λ_tol::Real=1.0e-6,
        couple::Real=10.0, niter::Integer=60,
        tol_dyn::Real=1.0e-6, tol_quartet::Real=1.0e-6, bdg_dim_cap::Integer=4000,
    ) = new(
        Float64(ε_stat), Float64(tol_ritz), Float64(λ_tol),
        Float64(couple), Int(niter),
        Float64(tol_dyn), Float64(tol_quartet), Int(bdg_dim_cap),
    )
end

function check(spec::StabilitySpec, ws, ψ; rng=Random.default_rng())
    details = Pair{Symbol, Any}[]

    # --- stationarity axis ---------------------------------------------
    # ONE constrained_hessian_params call is the single source of (μ, dV, n2)
    # and the gradient g; the energetic axis reuses `p` (params=) so the
    # expensive energy_gradient! runs once. The stationarity residual is the
    # tangent projection of g (= g − 2μψ, since μ = ⟨ψ,g⟩dV/2n2), reusing the
    # constrained-Hessian's own _tangent_project rather than open-coding it.
    p = constrained_hessian_params(ws, ψ)
    gproj = _tangent_project(p.g, ψ, p.dV, p.n2)
    stat_abs = sqrt(real(sum(abs2, gproj)) * p.dV)
    g_abs = sqrt(real(sum(abs2, p.g)) * p.dV)
    stat_rel = stat_abs / max(g_abs, 1e-30)
    stat_status = stat_rel < spec.ε_stat ? :pass : :indeterminate
    push!(details, :stationarity => (
        got=stat_rel, bound=spec.ε_stat, status=stat_status))

    # --- energetic axis (constrained-Hessian λ_min, self-certifying) ---
    bdg = trapped_bdg_lowest_eigenvalue(
        ws, ψ; niter=spec.niter, tol_ritz=spec.tol_ritz, params=p, rng)
    energetic = if !bdg.converged
        :indeterminate                      # Ritz residual not ≪ |λ_min|
    elseif bdg.λ_min < -spec.λ_tol
        :fail                               # saddle / anomalous direction
    else
        :pass                               # energetic minimum (λ_min ≥ −λ_tol)
    end
    # Joint resolution: a slightly-off ψ can flip a small λ_min's sign. This
    # is a HEURISTIC guard, not a derived bound — it compares the curvature
    # |λ_min| against `couple ×` the absolute stationarity residual `stat_abs`
    # (= ‖g−2μψ‖). The two are commensurate only under the fixed-norm
    # convention (‖ψ‖²dV = N), so `couple` is a dimensionless safety factor
    # tuned for N≈1; revisit if a campaign normalises ψ differently.
    if energetic !== :indeterminate && abs(bdg.λ_min) < spec.couple * stat_abs
        energetic = :indeterminate
    end
    push!(
        details,
        :energetic => (
            λ_min=bdg.λ_min, ritz_residual=bdg.ritz_residual,
            niter_used=bdg.niter_used, converged=bdg.converged, status=energetic),
    )

    # --- dynamical axis (trapped non-Hermitian BdG, dense) -------------
    # `dense_ok` is checked FIRST and is load-bearing: on abstain the spectrum
    # fields are NaN, and `NaN > tol` is false, so a reordering that read
    # max_growth before dense_ok would silently report :pass. The growth
    # threshold is RELATIVE to the spectral radius so it scales with the
    # problem; near the FD noise floor (see trapped_bdg_spectrum) the verdict
    # is noise-limited — phase 2b removes that floor.
    dynbdg = trapped_bdg_spectrum(ws, ψ; μ=p.μ, dim_cap=spec.bdg_dim_cap)
    dyn_status = if !dynbdg.dense_ok
        :indeterminate                      # too large for dense; Arnoldi unbuilt
    elseif dynbdg.quartet_residual > spec.tol_quartet
        :indeterminate                      # ω↦−conj(ω) symmetry broken: solve suspect
    elseif dynbdg.max_growth > spec.tol_dyn * dynbdg.radius
        :fail                               # complex ω ⇒ exponential growth
    else
        :pass                               # spectrum real ⇒ dynamically stable
    end
    push!(
        details,
        :dynamical => (
            max_growth=dynbdg.max_growth, quartet_residual=dynbdg.quartet_residual,
            bdg_dim=dynbdg.dim, dense_ok=dynbdg.dense_ok, status=dyn_status),
    )

    # --- combine -------------------------------------------------------
    # Stationarity is a PRECONDITION, not a co-equal axis: the energetic and
    # dynamical (second-variation) verdicts are built at ψ and are only
    # meaningful AT a stationary point — a :fail from them at a non-stationary ψ
    # is an artifact (the operator is built at the wrong point; cf.
    # mistake_stability_verdict_from_nonstationary_point). So when stationarity
    # is not :pass the gate ABSTAINS regardless of the other axes (which stay in
    # `details` as diagnostics) — it does not REJECT on an untrustworthy reading.
    overall = if stat_status !== :pass
        :indeterminate
    elseif energetic === :fail || dyn_status === :fail
        :fail
    elseif energetic === :indeterminate || dyn_status === :indeterminate
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
