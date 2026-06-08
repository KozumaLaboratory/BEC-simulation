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

export newton_cg_ground_state

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
    k2 = ws.grid.k_squared
    dV = cell_volume(ws.grid)
    ipR(a, b) = real(sum(conj.(a) .* b)) * dV
    n2_init = ipR(ψ, ψ)
    Δ = trust_radius

    energy_at(ϕ) = (copyto!(ws.state.psi, ϕ); total_energy(ws))
    # M-inner-product pieces (fresh M·v so callers never alias fft_buf).
    Mmul(v) = (mv = copy(v); _sobolev_metric!(mv, ws, k2, sobolev_alpha); mv)
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
