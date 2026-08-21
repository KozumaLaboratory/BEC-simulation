# Second-variation operator — the single source.
#
# `energy_gradient!` is the gated single-source gradient (= 2·δE/δψ̄,
# master oracle). The SECOND variation — the Hessian the BdG stability
# verdict, the Ω>0 conditioning diagnosis, and the Newton-CG optimiser
# all ride on — is stated ONCE here; `test/oracles/test_bdg_fd_hessian.jl`
# anchors it to the hand-built BdG matrices (both blocks, F-swept to Eu
# F=6), and every consumer calls it.
#
# Three layered faces, each the SAME physics:
#   hessian_vector_product       — bare Euclidean H·δ (the anchored primitive)
#   constrained_hessian_params   — (μ, dV, n2) at a stationary ψ
#   constrained_hessian_action   — P(H − 2μ)P · δ, the constrained operator
# The constrained operator is the ONE object behind BOTH the gate-2
# eigenvalue query (`trapped_bdg_lowest_eigenvalue`, Lanczos) AND the
# Newton-CG linear solve (`newton_cg_ground_state`). They differ only in
# the query (smallest eigenvalue vs. solve Hc p = −g_proj); the operator,
# the −2μ shift, and the complex-ψ tangent projection are shared. Building
# a separate operator for Newton-CG would risk drift in a load-bearing
# object and let the solve dig the singular phase-Goldstone direction.

export hessian_vector_product,
    constrained_hessian_params, constrained_hessian_action,
    trapped_bdg_lowest_eigenvalue, trapped_bdg_low_modes

"""
    hessian_vector_product(ws, ψ, δ; ε=1e-5) → array

Central-difference action of the energy second variation on `δ`:

    H·δ ≈ (energy_gradient!(ψ+εδ) − energy_gradient!(ψ−εδ)) / (2ε).

Since `energy_gradient!` returns `2·δE/δψ̄`, this carries BOTH the normal
(δ²E/δψ̄δψ) and anomalous (δ²E/δψ̄δψ̄) blocks via the real representation
(perturb along `δ` and `iδ` to separate them — see the L_op/M_op
extraction in the anchor test). Central difference ⇒ O(ε²) truncation;
ε=1e-5 sits the roundoff/truncation optimum for the gated gradient.
Anchored: `test/oracles/test_bdg_fd_hessian.jl` (≡ the hand-built BdG).

**The step is taken along the NORMALISED direction and rescaled.** `ε` calibrates
the size of the PERTURBATION, so it is only the optimum when ‖δ‖ ≈ 1. Until
2026-07-29 the difference was taken at `ψ ± ε·δ` with `ε` absolute, which is fine
for the Lanczos consumer (`trapped_bdg_lowest_eigenvalue` passes unit Lanczos
vectors) and wrong for Newton-CG, which passes CG iterates whose norm spans
decades: after an L-BFGS stage ‖δ‖ ~ 1e-6, so the perturbation was ~1e-11, the
two gradients differed in their 11th digit, and dividing by 2ε amplified their
~1e-16 noise by 5e4. The HvP was then noise, the trust-region ratio ρ was noise,
and `newton_polish` came out non-deterministic across processes — measured ratio
polish/lbfgs spanning 5.5e-4 … 1.000 (bit-identical no-op) … 1.998 (worse) on
the same commit and problem.

Normalising restores the property the exact Hessian action has and the fixed-ε
form did not: homogeneity, `H·(cδ) = c·(H·δ)`. Gated by the homogeneity testset
in `test/oracles/test_bdg_fd_hessian.jl`.
"""
function hessian_vector_product(ws, ψ, δ; ε::Float64=1e-5, order::Int=2)
    nδ = sqrt(sum(abs2, δ))
    nδ == 0 && return zero(δ)
    d = δ ./ nδ
    _g(s) = (out=similar(ψ); fill!(out, 0); energy_gradient!(out, ψ .+ s .* d, ws); out)
    if order == 4
        # 5-point stencil: truncation O(ε⁴), so the finite-difference HvP
        # cancellation floor drops from eps^(2/3)≈2e-11 (3-point) to
        # eps^(4/5)≈1.6e-13, at a larger ε* ~ eps^(1/5)≈6e-4 (farther from the
        # roundoff cliff). Only matters once the energy-comparison floor is
        # removed (see residual_newton_refine); under an energy-gated step it
        # is invisible. Costs 4 gradient evals.
        return ((_g(-2ε) .- 8 .* _g(-ε) .+ 8 .* _g(ε) .- _g(2ε)) ./ (12ε)) .* nδ
    end
    ((_g(ε) .- _g(-ε)) ./ (2ε)) .* nδ   # 3-point central, O(ε²)
end

# Tangent projection: remove the complex-ψ gauge direction (norm AND phase
# Goldstone iψ) from `δ`. This is the tangent of the ‖ψ‖²=N manifold under
# the global U(1) phase — both must leave for the constrained Hessian to be
# non-singular on the working space.
_tangent_project(δ, ψ, dV, n2) = δ .- ψ .* (sum(conj.(ψ) .* δ) * dV / n2)

"""
    constrained_hessian_params(ws, ψ) → (; μ, dV, n2, g)

Manifold scalars at a (near-)stationary `ψ`: the chemical potential
`μ = Re⟨ψ,g⟩/(2‖ψ‖²)` (`g = energy_gradient! = 2μψ` at a stationary
point), the cell volume `dV`, `n2 = ‖ψ‖²`, and the gradient `g` itself
(returned so callers needing the stationarity residual `‖g−2μψ‖` reuse
this single evaluation rather than recomputing `energy_gradient!`).
Calibrated by the gate-2 self-check `H·(iψ) = 2μ·(iψ)` (the phase
Goldstone is the 2μ eigenvector of the raw H). The SINGLE source of `μ`
for every consumer of the constrained Hessian.
"""
function constrained_hessian_params(ws, ψ)
    dV = cell_volume(ws.grid)
    n2 = real(sum(abs2, ψ)) * dV
    g0 = similar(ψ)
    fill!(g0, 0)
    energy_gradient!(g0, ψ, ws)
    μ = (real(sum(conj.(ψ) .* g0)) * dV) / (2 * n2)
    (; μ, dV, n2, g=g0)
end

"""
    constrained_hessian_action(ws, ψ, δ; μ, dV, n2, ε=1e-5) → array

The constrained second-variation operator `P(H − 2μ)P · δ`, where `P` is
the complex-ψ tangent projection and `H` the Euclidean
`hessian_vector_product`. This is the Riemannian Hessian of the energy on
the ‖ψ‖²=N manifold at a stationary `ψ` — the SINGLE operator behind both
the gate-2 minimum-vs-saddle eigenvalue query and the Newton-CG linear
solve. Pass `(μ, dV, n2)` from `constrained_hessian_params`.
"""
function constrained_hessian_action(ws, ψ, δ; μ, dV, n2, ε::Float64=1e-5, order::Int=2)
    pδ = _tangent_project(δ, ψ, dV, n2)
    _tangent_project(
        hessian_vector_product(ws, ψ, pδ; ε, order) .- 2μ .* pδ, ψ, dV, n2
    )
end

"""
    trapped_bdg_lowest_eigenvalue(ws, ψ; niter=300, atol=1e-6, ε=1e-5,
                                  tol_ritz=1e-2, params=nothing, rng=…)
        → (; λ_min, μ, ritz_residual, niter_used, converged, λ_lower, gap, width, goldstone)

Lowest eigenvalue of the constrained second variation `P(H−2μ)P` at a
STATIONARY ψ — the gate-2 minimum-vs-saddle verdict for a trapped state.
Hand-rolled fully-reorthogonalised Lanczos on `constrained_hessian_action`
(no KrylovKit dependency); `λ_min ≥ −tol` ⇒ energetic minimum, `< −tol` ⇒
saddle. Requires ψ converged (`g ∥ ψ`); on a non-stationary ψ the `μ` and
the verdict are not meaningful — `StabilitySpec` enforces that precondition
before reading the sign.

**Two-sided certificate (Kato–Temple).** The min Ritz value `λ_min = θ₁` is an
UPPER bound on the true eigenvalue (Ritz values converge from above); the
LOWER bound is `λ_lower = θ₁ − ρ²/δ` (`ρ` = ritz_residual, `δ` = Ritz gap to θ₂).
`ρ` enters SQUARED, so the certified interval `width = θ₁ − λ_lower` is far
tighter than the naive `±ρ`. **The convergence test is on `width`, not the
bare residual:** `converged = width < max(atol, tol_ritz·|λ_min|)`. This is the
fix for soft / Goldstone modes — a purely RELATIVE test `ρ < tol_ritz·|λ_min|`
is unsatisfiable as `λ_min → 0` (false negatives exactly where you care), while
the absolute `atol` floor certifies `λ_min` once it is pinned to `±atol`.

**Adaptive:** the Lanczos loop early-stops as soon as `converged`, so easy
(gapped) cells finish in tens of iterations while soft cells run to the `niter`
cap. The historical "λ_min still dropping at niter=200" verdict is exactly a
`converged=false` the bare value used to hide — trust the flag, not the value.

**Goldstone:** `goldstone=true` flags a converged `|λ_min| < atol` — a marginal
zero mode (e.g. the polar-phase spin Goldstone), classified as a minimum (NOT a
saddle). The complex-ψ tangent projection removes only the U(1) gauge `iψ`;
physical broken-symmetry Goldstones remain at `λ_min ≈ 0` and are correct.

`λ_min` and `μ` are the first two NamedTuple fields (legacy `[1]`/`[2]` and
`λ, _ = …` still yield λ_min, μ). Pass `params` to reuse `(μ, dV, n2)`.
`niter < 1` returns `converged=false` (λ_min=NaN) — the gate abstains, no crash.
"""
function trapped_bdg_lowest_eigenvalue(
    ws, ψ; niter::Int=300, atol::Float64=1e-6, ε::Float64=1e-5,
    tol_ritz::Float64=1e-2, params=nothing, rng=Random.default_rng(),
)
    p = params === nothing ? constrained_hessian_params(ws, ψ) : params
    if niter < 1
        return (; λ_min=NaN, μ=p.μ, ritz_residual=Inf, niter_used=0,
            converged=false, λ_lower=NaN, gap=NaN, width=Inf, goldstone=false)
    end
    ipR(a, b) = real(sum(conj.(a) .* b)) * p.dV
    Hc(δ) = constrained_hessian_action(ws, ψ, δ; p.μ, p.dV, p.n2, ε)

    _randvec() = _to_device(ws.backend, randn(rng, ComplexF64, size(ψ)))
    V = [_tangent_project(_randvec(), ψ, p.dV, p.n2)]
    V[1] ./= sqrt(ipR(V[1], V[1]))
    α = Float64[]
    β = Float64[]
    λ_min = NaN
    ritz_residual = Inf
    gap = NaN
    λ_lower = NaN
    width = Inf
    converged = false

    for _ in 1:niter
        w = Hc(V[end])
        push!(α, ipR(V[end], w))
        for u in V                              # full reorthogonalisation
            w = w .- u .* ipR(u, w)
        end
        βj = sqrt(max(ipR(w, w), 0.0))

        # Ritz value + Kato–Temple width of the CURRENT Krylov space, with the
        # candidate residual βj as the a-posteriori bound. Check convergence
        # in-loop so easy cells stop early (β has length(α)-1 here).
        if length(α) >= 2
            decomp = eigen(SymTridiagonal(copy(α), copy(β)))
            λ_min = decomp.values[1]
            s_min = @view decomp.vectors[:, 1]
            ritz_residual = abs(βj * s_min[end])
            θ2 = decomp.values[2]
            gap = θ2 - λ_min
            width = gap > ritz_residual ? ritz_residual^2 / gap : ritz_residual
            λ_lower = λ_min - width
            if width < max(atol, tol_ritz * abs(λ_min))
                converged = true
                break
            end
        elseif length(α) == 1
            λ_min = α[1]
            λ_lower = λ_min
        end

        βj < 1e-10 && break                     # invariant subspace ⇒ exact
        push!(β, βj)
        push!(V, w ./ βj)
    end

    goldstone = converged && abs(λ_min) < atol
    (; λ_min, μ=p.μ, ritz_residual, niter_used=length(α), converged,
        λ_lower, gap, width, goldstone)
end

# In-place kinetic Fourier preconditioner M⁻¹ = (½k² + α)⁻¹ per spin component.
# The constrained Hessian's stiffness is the kinetic λ_max ~ 1/dx²; flattening
# it restores the relative gap (λ₂−λ₁)/(λ_max−λ₁) that an unpreconditioned
# Lanczos/LOBPCG is bound by. `α` ~ the low-mode scale (≈ μ).
function _kinetic_precondition!(v::AbstractArray{<:Complex}, ws, k2, α::Float64)
    N = ndims(ws.grid.k_squared)
    n_pts = ntuple(d -> size(v, d), N)
    n_comp = ws.spin_matrices.system.n_components
    buf = ws.state.fft_buf
    @inbounds for c in 1:n_comp
        idx = _component_slice(N, n_pts, c)
        buf .= view(v, idx...)
        ws.fft_plans.forward * buf
        buf ./= (0.5 .* k2 .+ α)
        ws.fft_plans.inverse * buf
        view(v, idx...) .= buf
    end
    v
end

# Modified Gram–Schmidt orthonormalisation in a given real inner product,
# dropping near-dependent directions (so [X, W, P_prev] can be fed raw).
#
# `refine` (a projector) is applied AFTER the normalising division, and that
# ordering is the whole point. `w ./ nw` with a small `nw` is an amplifier: the
# LOBPCG basis [X, W, X_prev] becomes near-dependent as it converges (‖W‖ → 0,
# X ≈ X_prev), so a component of size 1e-16 along a direction the caller
# projected out gets multiplied by 1/nw ~ 1e3 every iteration. Measured on the
# uniform F=1 polar box: max|⟨ψ,S⟩| ran 3e-16 → 1.5e-14 → 2.3e-13 over six
# iterations, i.e. geometric, reaching O(1) well inside `max_iter=80`.
#
# The consequence was not noise but a FALSE EIGENVALUE. `A = P(H−2μ)P` maps its
# own projector's null space (`ψ` and `iψ`) to exactly zero, so once that
# direction re-enters the basis the solver reports it as an eigenvalue 0 with
# residual ~1e-10 — a spurious mode carrying a PERFECT convergence certificate.
# At `nev=1` on a gapped state (all this used to be asked for) it was invisible;
# at the `nev` an excitation spectrum needs it produced two extra zero modes,
# which `trapped_bdg_frequencies` would then have labelled as physical
# Goldstones. Re-projecting each normalised basis vector holds the leak at
# roundoff instead of letting it grow, and costs one projection per vector.
function _mgs_ortho(vecs, ipR; tol::Float64=1e-10, refine=identity)
    out = empty(vecs)
    for v in vecs
        w = copy(v)
        for u in out
            w = w .- u .* ipR(u, w)
        end
        nw = sqrt(max(ipR(w, w), 0.0))
        nw > tol || continue
        w = refine(w ./ nw)
        nw2 = sqrt(max(ipR(w, w), 0.0))
        nw2 > tol && push!(out, w ./ nw2)
    end
    out
end

# Linear combination of a vector list by columns of C: returns [Σⱼ C[j,k] S[j]].
_combine(S, C) = [reduce(.+, (C[j, k] .* S[j] for j in 1:length(S))) for k in 1:size(C, 2)]

"""
    trapped_bdg_low_modes(ws, ψ; nev=1, block=8, ...)
        → (; λ, λ_lower, residuals, converged, μ, iterations,
             converged_modes, widths, vectors)

Lowest `nev` eigenvalues of the constrained second variation `P(H−2μ)P` via
block **LOBPCG with a kinetic Fourier preconditioner** — the
preconditioned counterpart of `trapped_bdg_lowest_eigenvalue` (bare Lanczos).

The bare Lanczos is bound by the relative gap `(λ₂−λ₁)/(λ_max−λ₁)`, which the
kinetic `λ_max ~ 1/dx²` crushes; the preconditioner `M⁻¹ = (½k²+α)⁻¹`
flattens that span (THIS, not the solver name, is what makes it converge — at
a soft point it sets the certified-interval width, not just the speed). A
block larger than the low-mode cluster + a recycled previous block (the
conjugate term) handle clustered / crossing modes that defeat single-vector
iteration.

Returns the Ritz values `λ` (upper bounds), per-mode Kato–Temple lower bounds
`λ_lower` (`θₖ − ρₖ²/δₖ`), residual norms, and `converged` (all `nev`
residuals < `tol`). `extra_nullspace` projects out known Goldstone modes
beyond the gauge `iψ` (vortex rotation / free-space translation) — these are
DEFLATED (removed), the physical soft mode is NOT (the block grabs it).

**PER-MODE certificates, because a scalar flag is unreadable once `nev` > 1.**
`converged_modes[k]` and `widths[k] = λ[k] − λ_lower[k]` are reported for every
returned mode. Raising `nev` shrinks the Ritz gap `δₖ` that the Kato–Temple
width divides by, so the modes at the TOP of the returned block certify far
worse than `λ_min` does — a `converged=true` aggregate over `nev=30` is not a
statement about mode 30. Read `converged_modes` (and `widths`) mode by mode; the
aggregate is kept only for the gate-2 single-mode callers. The `λ_min` still
dropping at the iteration cap that #50 hid inside a plausible VALUE is exactly
a `converged_modes[k] == false`.

`vectors` are the Ritz VECTORS matching `λ` element-for-element — the basis
`trapped_bdg_frequencies` complexifies to reach the ω axis. They are
`⟨,⟩_R`-orthonormal (`ipR(vᵢ,vⱼ) = δᵢⱼ`) and live in the tangent space (the
gauge `iψ` and any `extra_nullspace` are projected out of them). A final
Rayleigh–Ritz refresh runs when the iteration ends at the cap rather than at
`tol`, so `λ`, `residuals` and `vectors` always describe the SAME block — before
that refresh the reported values lagged the returned block by one LOBPCG step.

Keywords: `nev`, `block` (≥ nev+2), `max_iter`, `tol` (residual stop),
`α_pre` (kinetic shift, defaults to `max(|μ|, 1e-3)`), `precond`
(**`:combined` default** — `P_V^½ P_K P_V^½`, which adds the real-space stiffness
`V_trap + c₀n` that the kinetic-only inverse leaves alone — or `:kinetic` for the
Fourier-only metric), `α_v` (the `P_V` regulariser, same default), `ε`+`order`
(HvP), `extra_nullspace`, `rng`. A preconditioner changes the iteration and not
the spectrum, so the two `precond` arms must agree on λ — gated by
`test/oracles/test_bdg_low_modes_lobpcg.jl`.

**THE DEFAULT IS `:combined` SINCE 2026-08-21 (#397), and the reason it was not
before is worth reading, because it was a wrong premise rather than a wrong
measurement.** The previous docstring said the default stayed `:kinetic`
"because changing it moves every gate-2 stability verdict". It cannot: this
function has exactly one consumer under `src/` — `trapped_bdg_frequencies`,
which uses its eigenVECTORS as a reduction subspace and never reads the sign of
λ — and `check(::StabilitySpec, ws, ψ)` runs `trapped_bdg_lowest_eigenvalue`, a
bare Lanczos with no `precond` keyword at all. Verified by execution, not by
grep: starving the Lanczos to `niter=1` moves the verdict (`pass` →
`indeterminate`) while the block's own knob cannot.

The three things #397 asked to measure before moving the default, measured
(¹⁵¹Eu 32³ × 13, six stored eu335 cells, H100, `nev=4`, `block=10`, same seed,
`scripts/eu_spectrum/precond_ab.jl`):

| B [µG] | `:kinetic` @ 2000 | `:combined` @ 2000 |
|---:|---|---|
| 5 | not converged, 760 s | not converged, 763 s |
| 20 | not converged, 810 s | **converged in 1479 it, 584 s** |
| 25 | not converged, 812 s | **converged in 1241 it, 492 s** |
| 60 | converged in 1508 it, 605 s | **converged in 525 it, 202 s** |
| 100 | converged in 647 it, 271 s | **converged in 264 it, 103 s** |
| 68.25 (flower) | converged in 1288 it, 518 s | **converged in 401 it, 167 s** |

`:combined` certifies 5 cells to `:kinetic`'s 3, is 1.4–3.1× faster where both
certify, and is never slower. Where both converge they agree — to 15 digits at
100 µG, 7 at 68.25, 5 at 60 — which is the equivalence claim holding at
production scale rather than only on the CI fixture. And on the small GAPPED
fixture, where the kinetic metric is already right and the extra 2 FFTs could
have cost, it still wins: 16 iterations / 0.041 s against 30 / 0.089 s. That was
the one stated reason to expect a loss.

VALIDITY REGIME: correctness gated (≡ Lanczos λ_min) on gapped states. **What
binds a production λ_min is now the OPERATOR, not the solver**: with widths down
to ~1e-14 the Hessian's own finite-difference construction (`ε`, default 1e-5)
is the larger error, so a SIGN read at |λ| ≲ 1e-7 needs an `ε` control before it
means anything. `converged=true` says the iteration finished, not that the
number is accurate to its width.
"""
function trapped_bdg_low_modes(
    ws, ψ;
    nev::Int=1, block::Int=8, max_iter::Int=30, tol::Float64=1e-6,
    α_pre::Union{Nothing, Float64}=nothing, precond::Symbol=:combined,
    α_v::Union{Nothing, Float64}=nothing, ε::Float64=1e-5, order::Int=2,
    extra_nullspace=nothing, params=nothing, rng=Random.default_rng(),
)
    precond in (:kinetic, :combined) || throw(
        ArgumentError(
            "trapped_bdg_low_modes: precond must be :kinetic or :combined, got :$precond"),
    )
    p = params === nothing ? constrained_hessian_params(ws, ψ) : params
    k2 = _to_device_cached(ws.backend, ws.grid.k_squared)
    ipR(a, b) = real(sum(conj.(a) .* b)) * p.dV
    α = α_pre === nothing ? max(abs(p.μ), 1e-3) : α_pre

    function project(v)
        w = _tangent_project(v, ψ, p.dV, p.n2)
        if extra_nullspace !== nothing
            for m in extra_nullspace
                w = w .- m .* (ipR(m, w) / ipR(m, m))
            end
        end
        w
    end
    # `:combined` reaches for the preconditioner this repo already has —
    # `P_C = P_V^½ P_K P_V^½` (`solvers/preconditioner.jl`), whose own header
    # names "the BdG eigensolver crawls" as the thing it exists for, and which
    # was never wired to this consumer. The kinetic-only inverse flattens ½k²
    # and leaves the REAL-space stiffness `V_trap + c₀n` untouched; on the
    # weak-field Eu manifold that is the stiffness that matters.
    #
    # A preconditioner changes the ITERATION, never the SPECTRUM — so the two
    # arms must return the same λ, and `test_bdg_low_modes_lobpcg.jl` asserts
    # exactly that. `:combined` is the DEFAULT since #397 measured it across the
    # six eu335 cells: 5 certified against 3, 1.4-3.1× faster where both
    # certify, never slower, and it also wins on the gapped fixture where the
    # extra 2 FFTs could have cost. `:kinetic` is kept as a knob and as the
    # other side of the equivalence gate, not as a fallback.
    α_V = α_v === nothing ? max(abs(p.μ), 1e-3) : α_v
    sqrt_pv = precond === :combined ? build_precond_sqrt_pv(ws, ψ, α_V) : nothing
    Tprec(v) = project(
        if sqrt_pv === nothing
            _kinetic_precondition!(copy(v), ws, k2, α)
        else
            combined_precondition!(copy(v), ws, sqrt_pv, k2, α)
        end,
    )
    A(v) = constrained_hessian_action(ws, ψ, v; p.μ, p.dV, p.n2, ε, order)

    b = max(block, nev + 2)
    _randvec() = _to_device(ws.backend, randn(rng, ComplexF64, size(ψ)))
    X = _mgs_ortho([project(_randvec()) for _ in 1:b], ipR; refine=project)
    AX = [A(x) for x in X]
    Xprev = typeof(ψ)[]
    θ = zeros(length(X))
    resn = fill(Inf, length(X))
    iters = 0

    # The Rayleigh–Ritz pass is the LAST thing the loop does, so the reported
    # (θ, resn) always describe the RETURNED X. The earlier for-form expanded
    # the block after its convergence test, so a run that ended at `max_iter`
    # returned values one step behind its own vectors.
    while true
        iters += 1
        # Rayleigh-Ritz on the current block → rotate X, AX to Ritz vectors.
        nb = length(X)
        Θ = [ipR(X[i], AX[j]) for i in 1:nb, j in 1:nb]
        e = eigen(Symmetric((Θ .+ Θ') ./ 2))
        X = _combine(X, e.vectors)
        AX = _combine(AX, e.vectors)
        θ = e.values
        R = [AX[i] .- θ[i] .* X[i] for i in 1:nb]
        resn = [sqrt(max(ipR(r, r), 0.0)) for r in R]
        (maximum(@view resn[1:min(nev, nb)]) < tol || iters >= max_iter) && break

        W = [Tprec(R[i]) for i in 1:nb]
        S = _mgs_ortho(vcat(X, W, Xprev), ipR; refine=project)
        AS = [A(s) for s in S]
        ns = length(S)
        Hs = [ipR(S[i], AS[j]) for i in 1:ns, j in 1:ns]
        es = eigen(Symmetric((Hs .+ Hs') ./ 2))
        keep = min(b, ns)
        C = es.vectors[:, 1:keep]
        Xprev = X
        X = _combine(S, C)
        AX = _combine(AS, C)
    end

    nb = length(X)
    m = min(nev, nb)
    λ = θ[1:m]
    λ_lower = map(1:m) do k
        δ = (k < nb ? θ[k + 1] : θ[k]) - θ[k]
        δ > resn[k] ? θ[k] - resn[k]^2 / δ : θ[k] - resn[k]
    end
    residuals = resn[1:m]
    (;
        λ, λ_lower, residuals, converged=maximum(residuals) < tol,
        μ=p.μ, iterations=iters,
        converged_modes=[r < tol for r in residuals],
        widths=[λ[k] - λ_lower[k] for k in 1:m],
        vectors=X[1:m],
    )
end
