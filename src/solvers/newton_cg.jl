# Trust-region Newton-CG ground-state refinement on the ‖ψ‖²=N manifold.
#
# WHY this tool, positively (not by elimination): gate-2 shows the Ω>0
# conditioning floor is NUMERICAL — the constrained spectrum is GAPPED
# (λ_min ~ 2.3-4.1, no trend to zero). A gap means a well-defined minimum
# with positive curvature in every tangent direction; the only pathology
# is L-BFGS's first-order rate at a large condition number. Newton-CG
# (uses the curvature) + a Sobolev preconditioner (compresses the kinetic
# block) match that exactly. A genuine soft mode would defeat both — the
# spectrum says gapped, so the second-order tool wins.
#
# CRITICAL reuse: the inner operator IS the gate-2 stability operator,
# `constrained_hessian_action` = P(H − 2μ)P (src/solvers/hessian.jl), NOT
# a bare Euclidean HvP. The minimisation is on ‖ψ‖²=N, so the Riemannian
# Hessian is exactly the projected, μ-shifted Hessian. gate-2 (smallest
# eigenvalue) and Newton-CG (solve Hc p = −g_proj) are the SAME operator —
# the −2μ shift and the complex-ψ tangent projection are shared, and μ is
# already calibrated by the gate-2 `H·(iψ)=2μ·(iψ)` self-check. A bare HvP
# would break normalisation and let CG dig the singular phase-Goldstone
# direction.
#
# Newton-CG is a CONVERGENCE ENGINE, NOT A GATE. Reaching ‖∇E‖<tol is a
# stationary point, not a gated ground state: a converged Ω>0 cell still
# needs gate-1 (multi-seed global-min) + gate-2 (minimum vs saddle) +
# gate-3 (texture resolution), exactly as Ω=0 — otherwise the Ω>0 half
# inherits the "bare table ≠ gated phase diagram" trap the Ω=0 half
# avoided. Ω=0 regression is judged by STATE FIDELITY (returns to the same
# state), not by ‖∇E‖, since Newton-CG can land on a different stationary
# point. The atomic return ({psi, energy, grad_norm, μ}) is the input to
# those separate gates, never the verdict itself.

export newton_cg_ground_state, residual_newton_refine

# In-place Sobolev metric M = (1 + α(−∇²)): per spinor component, k-space
# multiply by (1 + α k²). The forward partner of `_sobolev_precondition!`
# (which divides → M⁻¹); needed for the M-norm trust region.
function _sobolev_metric!(v::AbstractArray{<:Complex}, ws, k2, α::Float64)
    α > 0 || return v
    N = ndims(ws.grid.k_squared)
    n_pts = ntuple(d -> size(v, d), N)
    n_comp = ws.spin_matrices.system.n_components
    buf = ws.state.fft_buf
    @inbounds for c in 1:n_comp
        idx = _component_slice(N, n_pts, c)
        buf .= view(v, idx...)
        ws.fft_plans.forward * buf
        buf .*= (1 .+ α .* k2)
        ws.fft_plans.inverse * buf
        view(v, idx...) .= buf
    end
    v
end

"""
    newton_cg_ground_state(ws, ψ0; kwargs...) → (; psi, energy, grad_norm, converged, iterations, mu)

Trust-region (Steihaug-Toint) Newton-CG refinement of `ψ0` toward the
constrained stationary point on the ‖ψ‖²=N manifold. The inner linear
solve uses `constrained_hessian_action` (the gate-2 operator) with a
Sobolev preconditioner `M⁻¹ = (1+α(−∇²))⁻¹`; the trust region is measured
in the M-norm. See the file header for why this is a convergence engine,
not a gate, and for the operator-sharing rationale.

Keywords: `tol` (projected ‖∇E‖ stop), `max_outer`, `max_cg`,
`sobolev_alpha` (0 ⇒ plain Euclidean Steihaug), `trust_radius`/`trust_max`,
`cg_tol` (inner CG relative residual), `ε` (HvP step), `verbose`.
"""
function newton_cg_ground_state(
    ws, ψ0;
    tol::Float64=1e-6,
    max_outer::Int=50,
    max_cg::Int=40,
    sobolev_alpha::Float64=0.04,
    trust_radius::Float64=1.0,
    trust_max::Float64=100.0,
    cg_tol::Float64=0.1,
    ε::Float64=1e-5,
    verbose::Bool=false,
)
    ψ = copy(ψ0)
    k2 = _to_device(ws.backend, ws.grid.k_squared)
    dV = cell_volume(ws.grid)
    ipR(a, b) = real(sum(conj.(a) .* b)) * dV
    n2_init = ipR(ψ, ψ)
    Δ = trust_radius

    energy_at(ϕ) = (copyto!(ws.state.psi, ϕ); total_energy(ws))
    # M-inner-product pieces (fresh M·v so callers never alias fft_buf).
    Mmul(v) = (mv=copy(v); _sobolev_metric!(mv, ws, k2, sobolev_alpha); mv)
    Mdot(a, b) = ipR(a, Mmul(b))
    function Minv(r, prm)               # preconditioned residual, re-projected
        z = copy(r)
        _sobolev_precondition!(z, ws, k2, sobolev_alpha)
        _tangent_project(z, ψ, prm.dV, prm.n2)
    end

    E = energy_at(ψ)
    converged = false
    gnorm = Inf
    iters = 0
    t0 = time()

    for outer in 1:max_outer
        iters = outer
        prm = constrained_hessian_params(ws, ψ)            # (μ, dV, n2)
        g = similar(ψ)
        fill!(g, 0)
        energy_gradient!(g, ψ, ws)
        gp = _tangent_project(g, ψ, prm.dV, prm.n2)
        gnorm = sqrt(ipR(gp, gp))
        if verbose
            @printf("  NCG %2d/%d | E=%.8g |∇E|=%.3e Δ=%.2g μ=%.4f | %.1fs\n",
                outer, max_outer, E, gnorm, Δ, prm.μ, time() - t0)
            flush(stdout)
        end
        if gnorm < tol
            converged = true
            break
        end

        Hc(δ) = constrained_hessian_action(ws, ψ, δ; prm.μ, prm.dV, prm.n2, ε)
        p = _steihaug_cg(Hc, gp, prm, Minv, Mmul, Mdot, ipR, Δ, max_cg, cg_tol)

        # quadratic-model predicted reduction at p
        Hp = Hc(p)
        pred = -(ipR(gp, p) + 0.5 * ipR(p, Hp))

        # trial + retraction back to the ‖ψ‖²=N sphere (p ⊥ ψ ⇒ scale down)
        ψtrial = ψ .+ p
        ψtrial .*= sqrt(n2_init / ipR(ψtrial, ψtrial))
        Etrial = energy_at(ψtrial)
        ared = E - Etrial
        ρ = pred > 0 ? ared / pred : (ared > 0 ? 1.0 : -1.0)

        pM = sqrt(max(Mdot(p, p), 0.0))                    # ‖p‖_M
        if ρ < 0.25
            Δ = 0.25 * Δ
        elseif ρ > 0.75 && pM >= 0.9 * Δ
            Δ = min(2 * Δ, trust_max)
        end
        if ρ > 0.1
            ψ = ψtrial
            E = Etrial
        end
    end

    # atomic finalisation — {psi, energy, grad_norm, μ} all from one ψ
    copyto!(ws.state.psi, ψ)
    Efinal = total_energy(ws)
    prm = constrained_hessian_params(ws, ψ)
    g = similar(ψ)
    fill!(g, 0)
    energy_gradient!(g, ψ, ws)
    gp = _tangent_project(g, ψ, prm.dV, prm.n2)
    gnorm = sqrt(ipR(gp, gp))
    # Re-sync ws.state.psi to ψ: total_energy / energy_gradient! may mutate
    # ws.state.psi away from the returned iterate (same guard as
    # _finalize_lbfgs_atomic!). Without it ws.state.psi can drift from the
    # reported {energy, grad_norm}.
    copyto!(ws.state.psi, ψ)
    (; psi=ψ, energy=Efinal, grad_norm=gnorm, converged, iterations=iters, mu=prm.μ)
end

# Steihaug-Toint preconditioned CG: approximately solve `Hc p = −gp` inside
# the M-norm trust region ‖p‖_M ≤ Δ. Stops at the first of: inner residual
# tolerance, negative curvature (→ go to the boundary), or the TR boundary.
function _steihaug_cg(Hc, gp, prm, Minv, Mmul, Mdot, ipR, Δ, maxit, cg_tol)
    b = -gp
    z = zero(gp)
    r = copy(b)                       # b − Hc·0
    y = Minv(r, prm)
    d = copy(y)
    ry = ipR(r, y)
    rnorm0 = sqrt(ipR(r, r))
    rnorm0 < 1e-300 && return z

    for _ in 1:maxit
        Hd = Hc(d)
        dHd = ipR(d, Hd)
        if dHd <= 0                    # negative curvature → TR boundary along d
            return z .+ _tr_tau(z, d, Δ, Mmul, ipR) .* d
        end
        αcg = ry / dHd
        z_new = z .+ αcg .* d
        if sqrt(max(Mdot(z_new, z_new), 0.0)) >= Δ
            return z .+ _tr_tau(z, d, Δ, Mmul, ipR) .* d
        end
        z = z_new
        r = r .- αcg .* Hd
        sqrt(ipR(r, r)) <= cg_tol * rnorm0 && return z
        y = Minv(r, prm)
        ry_new = ipR(r, y)
        d = y .+ (ry_new / ry) .* d
        ry = ry_new
    end
    z
end

# Largest τ ≥ 0 with ‖z + τ d‖_M = Δ (M-norm quadratic, positive root).
function _tr_tau(z, d, Δ, Mmul, ipR)
    Md = Mmul(d)
    a = ipR(d, Md)
    b = 2 * ipR(z, Md)
    c = ipR(z, Mmul(z)) - Δ^2
    disc = max(b^2 - 4 * a * c, 0.0)
    (-b + sqrt(disc)) / (2 * a)
end

"""
    residual_newton_refine(ws, ψ0; kwargs...) → (; psi, energy, grad_norm, converged, iterations, mu)

In-basin residual-driven Newton refinement (a J-method / generalized inverse
iteration) that breaks the energy-comparison floor of `newton_cg_ground_state`.

`newton_cg_ground_state` accepts steps by an ENERGY decrease (trust region on
`ared = E − Etrial`); near the minimum the reduction `~‖∇E‖²/κ` drops below the
energy roundoff `~eps·|E|`, so `ρ = ared/pred` becomes noise, every step is
rejected, and the projected gradient floors at `√eps·‖g‖` (~6e-8 scalar). This
routine instead drives the projected gradient (which equals `2·P·r` for the
mean-field residual `r = (H[ψ]−μ)ψ`, since `g = 2H[ψ]ψ` and `Pψ = 0`) to zero
DIRECTLY: a damped Newton step `J p = −gp` (J = `constrained_hessian_action`,
the gate-2 Hessian incl. the anomalous block), with the step accepted by the
RESIDUAL-norm decrease `‖gp‖`, not energy. `‖gp‖` is evaluable to `~eps·κ_max`
(the kinetic-dominated `‖H‖`), so acceptance is no longer roundoff-limited and
the floor drops to the finite-difference HvP floor (`eps^(2/3)≈2e-11` at
`order=2`; `eps^(4/5)≈1.6e-13` at `order=4`).

PRECONDITION: `ψ0` must be in the convex basin (projected Hessian positive
definite — i.e. a Bogoliubov-stable stationary point). This is a polish, NOT a
globalized solver; seed it from L-BFGS / `newton_cg_ground_state`. On negative
curvature the inner PCG truncates and the damped step guards descent, but a
saddle seed will not converge. Use `extra_nullspace` to pass known Goldstone /
zero modes (vortex rotation, free-space translation) for explicit projection —
without it those near-singular directions stall the residual.

Keywords: `tol` (‖gp‖ stop), `max_outer`, `max_cg`, `sobolev_alpha`
(Fourier/kinetic preconditioner `(1+α k²)⁻¹`), `ε` + `hvp_order` (HvP step /
stencil), `cg_tol` (inner PCG relative residual), `extra_nullspace` (vector of
tangent modes to project out each iteration), `verbose`.
"""
function residual_newton_refine(
    ws, ψ0;
    tol::Float64=1e-12,
    max_outer::Int=40,
    max_cg::Int=80,
    sobolev_alpha::Float64=0.04,
    cg_tol::Float64=1e-3,
    ε::Float64=1e-5,
    hvp_order::Int=2,
    extra_nullspace=nothing,
    verbose::Bool=false,
)
    ψ = copy(ψ0)
    k2 = _to_device(ws.backend, ws.grid.k_squared)
    dV = cell_volume(ws.grid)
    ipR(a, b) = real(sum(conj.(a) .* b)) * dV
    n2_init = ipR(ψ, ψ)

    # Project out the gauge tangent (norm + phase Goldstone) AND any extra
    # supplied zero modes (vortex / translation Goldstone), orthogonalised.
    function project(v, prm)
        w = _tangent_project(v, ψ, prm.dV, prm.n2)
        if extra_nullspace !== nothing
            for m in extra_nullspace
                w = w .- m .* (ipR(m, w) / ipR(m, m))
            end
        end
        w
    end
    Minv(r, prm) = project(_sobolev_precondition!(copy(r), ws, k2, sobolev_alpha), prm)

    gnorm = Inf
    converged = false
    iters = 0
    t0 = time()

    # ‖gp‖ at the current ψ, reusing the constrained_hessian_params gradient.
    function residual_norm(prm)
        gp = project(prm.g, prm)
        (sqrt(ipR(gp, gp)), gp)
    end

    for outer in 1:max_outer
        iters = outer
        prm = constrained_hessian_params(ws, ψ)
        gnorm, gp = residual_norm(prm)
        if verbose
            @printf("  rNCG %2d/%d | ‖gp‖=%.3e μ=%.5f | %.1fs\n",
                outer, max_outer, gnorm, prm.μ, time() - t0)
            flush(stdout)
        end
        gnorm < tol && (converged=true; break)

        Hc(δ) = constrained_hessian_action(ws, ψ, δ; prm.μ, prm.dV, prm.n2, ε, order=hvp_order)
        p = _pcg_newton(Hc, -gp, r -> Minv(r, prm), ipR, max_cg, cg_tol)

        # Damped step accepted by RESIDUAL decrease (NOT energy), so the
        # acceptance test resolves to eps·κ_max, not eps·|E|.
        accepted = false
        t = 1.0
        for _ in 1:20
            ψt = ψ .+ t .* p
            ψt .*= sqrt(n2_init / ipR(ψt, ψt))
            prm_t = constrained_hessian_params(ws, ψt)
            gnorm_t, _ = residual_norm(prm_t)
            if gnorm_t < gnorm
                ψ = ψt
                accepted = true
                break
            end
            t *= 0.5
        end
        accepted || break    # no residual decrease (floor reached or out of basin)
    end

    copyto!(ws.state.psi, ψ)
    Efinal = total_energy(ws)
    prm = constrained_hessian_params(ws, ψ)
    gnorm, _ = residual_norm(prm)
    copyto!(ws.state.psi, ψ)
    (; psi=ψ, energy=Efinal, grad_norm=gnorm, converged, iterations=iters, mu=prm.μ)
end

# Preconditioned CG for the Newton step `Hc x = b` in the tangent space.
# Truncates on negative curvature (returns the current iterate, which is still
# a descent direction for the residual) — the damped outer step guards the rest.
function _pcg_newton(Hc, b, Minv, ipR, maxit, cg_tol)
    x = zero(b)
    r = copy(b)
    z = Minv(r)
    d = copy(z)
    rz = ipR(r, z)
    rnorm0 = sqrt(ipR(r, r))
    rnorm0 < 1e-300 && return x
    for _ in 1:maxit
        Hd = Hc(d)
        dHd = ipR(d, Hd)
        dHd <= 0 && break                 # negative curvature → stop
        α = rz / dHd
        x = x .+ α .* d
        r = r .- α .* Hd
        sqrt(ipR(r, r)) <= cg_tol * rnorm0 && break
        z = Minv(r)
        rz_new = ipR(r, z)
        d = z .+ (rz_new / rz) .* d
        rz = rz_new
    end
    x
end
