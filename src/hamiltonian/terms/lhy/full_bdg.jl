# full_bdg.jl
# =================================================================
# General-spinor LHY from the Bogoliubov-de Gennes zero-point integral.
#
# The closed forms in this directory each assume ONE symmetric ansatz
# (polar / FM / I_h), because only then does the BdG matrix block-
# diagonalise and collapse to per-mode (ξ_m, κ_m). For an arbitrary
# spinor — a canted or textured F=6 state, say — no such reduction
# exists, and the momentum integral has to be done over the coupled
# 2D × 2D problem. This file is that path.
#
# Renormalisation follows Uchino-Kobayashi-Ueda, PRA 81, 063632 (2010)
# [arXiv:0912.0355] Eqs. (16)-(19): per Bogoliubov branch the divergent
# pieces are the free dispersion, the first-order mean-field shift, and
# the second-order Born term,
#
#     ½ [ ω_b(k) − ε_k − n ξ_b + (n κ_b)² / (2 ε_k) ]
#
# with ξ_b the NORMAL and κ_b the ANOMALOUS stiffness. Those coincide
# in the scalar case, which is exactly why the distinction is easy to
# lose; they do not coincide for gapped spinor modes.
#
# Summed over branches, the counterterms are traces of the two
# k-independent stiffness matrices, so no per-branch labelling is
# needed anywhere:
#
#     Σ_b n ξ_b = tr C        Σ_b (n κ_b)² = tr(B B̄) = ‖B‖_F²
#
#     I(k) = Σ_b ω_b(k) − D ε_k − tr C + ‖B‖_F² / (2 ε_k)
#     ε_LHY = (1 / 4π²) ∫₀^∞ dk k² I(k)
#
# where C = 2n h + diag(z) − μ (Hermitian) and B = n M_anom (complex
# symmetric) — see `_lhy_bdg_stiffness`. Verified against all three
# closed forms (polar F=1,2,6; FM F=6; scalar limit) to ~1e-4 for every
# dynamically stable configuration.
#
# Two things this replaced, both of which produced wrong numbers:
#   - a counterterm that folded ε_k into the per-branch asymptote and
#     then subtracted ε_k again, leaving I(k) → −ε_k/2 and a k_max⁵
#     divergence at EVERY F and EVERY phase (F=1 polar came out at
#     −3.8e5 against a closed-form +17.09);
#   - branch selection by |Re ω|, which flips the sign of negative-
#     energy branches. Branches are selected by positive symplectic
#     norm |u|² − |v|² > 0 instead, which is what makes the FM-at-c₁>0
#     case agree (89% error → 2.6e-4).

export compute_spinor_lhy_table

"""
    compute_spinor_lhy_table(; spinor, F, interactions, zeeman, c_dd,
                               n_max, n_points, rtol, k_max, n_k, n_dir) → FullBdGLHY

Spinor LHY for an ARBITRARY uniform spinor, from the BdG zero-point
integral. This is the general-`F`, general-state path; prefer the closed
forms (`compute_spinor_lhy_polar_contact`, `compute_spinor_lhy_fm_contact`,
`compute_spinor_lhy_icosahedral`) when the state matches one of their
ansatze, since those are ~two orders of magnitude cheaper.

`rtol` is the requested relative accuracy of `ε_LHY`; `k_max` and `n_k` are
DERIVED from it unless pinned explicitly. Those two are not independent knobs,
and the previous fixed defaults (`k_max = 20`, `n_k = 200`) had them backwards.
Measured, contact-only at F=6 against the exact closed form:

    k_max = 20   rel 2.7e-3  — and FLAT in n_k from 16 to 256
    k_max = 60   rel 1.0e-4  — likewise flat
    k_max = 200  rel 2.8e-6  — needs only n_k ≥ 32

The whole error is cutoff truncation, falling as `k_max^-3` (measured 2.66e-3,
3.42e-4, 4.30e-5, 5.39e-6 at k_max = 20, 40, 80, 160). `n_k` buys nothing past
the point where it resolves the integrand.

A fixed `k_max` cannot be right in any case, because the momentum that has to
be reached is set by the STIFFNESS: the natural scale is
`k_s = √(2 n λ_max(C))` and the truncation depends on `k_max / k_s`, not on
`k_max`. Measured across F = 1, 6, polar and FM, `c₀ = 10` and `100`, and
`n = 1` and `10`, the cutoff needed for `rel ≤ 1e-4` was a constant multiple of
that scale — ratio 17.9 to 19.1, i.e. flat while `k_s` itself moved 3×. So

    k_max = 19 · k_s · (1e-4 / rtol)^(1/3)

and the dimensionless range `k_max / k_s` then depends on `rtol` alone, which is
why `n_k` can too. A fixed `k_max = 20` silently degraded for large `c₀`.

That formula is only the STARTING cutoff. `rtol` is then enforced by measuring
truncation, not modelling it: the integral is extended by an outer panel to
`2·k_max` and the shift in the answer is the error estimate. (The analytic tail
term is the size of the correction, not of the residual after it — using that as
the estimate came out ~30× conservative, 2.6% claimed against 8.1e-4 actual, and
would have pushed `k_max` far past need. A doubling comparison carries no fitted
constant.)

The starting-cutoff constant travels better than expected: measured with the
DDI active, `x = 15` already reaches 1e-4, against 19 contact-only. An earlier
note here claimed the fit was ~8× optimistic under DDI; that was a
misattribution — the residual it was based on came from a REFERENCE that had
itself been computed at a large pinned `k_max` and corrupted by the round-off
cliff described below.

Refinement stops at the round-off floor as well as at `rtol`. The integrand is a
cancelling difference `Σω − D·ε_k − tr C` whose terms grow as `D k²/2` while the
result decays as `k⁻²`, so Float64 cancellation noise grows roughly as `k⁶`; an
unguarded loop asked for `rtol = 1e-6` ran off that cliff and returned answers
wrong by factors of 4 to 120. **Validated range: `rtol` from 1e-3 to 1e-5**,
where the delivered error measures 1/40 to 1/3 of the request across F = 1, 2, 6,
polar and FM, `c₀ = 10` and `100`, `n = 1` and `10`. Below that the call warns
and reports what it actually achieved.

Truncation is CERTIFIED rather than assumed: the analytic tail term already
computed for `[k_max, ∞)` is the leading estimate of what was cut off, so if it
exceeds `rtol` of the total the result is not at the requested accuracy and the
call says so, with the `k_max` that would fix it.

`zeeman` enters the branch energies, so a non-uniform Zeeman splitting
genuinely changes the LHY correction (UKU 2010, Appendix A). When the
Zeeman energies are degenerate — the common case, including `q = 0` —
the stiffness matrices are exactly proportional to `n`, so
`ε_LHY(n) = n^(5/2) ε_LHY(1)` holds identically and the momentum
integral is done once instead of `n_points` times.

Emits a warning when the mean field is DYNAMICALLY unstable
(`Im ω ≠ 0`): the zero-point sum then omits the complex branches while
the counterterms still subtract all `D` of them, so the result is
scheme-dependent. That is a property of the state, not of this
implementation — the closed forms are equally meaningless there.
"""
function compute_spinor_lhy_table(;
    spinor::Vector{ComplexF64},
    F::Int,
    interactions::InteractionParams,
    zeeman::ZeemanParams=ZeemanParams(),
    c_dd::Float64=0.0,
    n_max::Float64=100.0,
    n_points::Int=100,
    n_atoms::Int=1,
    rtol::Float64=1e-4,
    k_max::Union{Nothing, Float64}=nothing,
    n_k::Union{Nothing, Int}=nothing,
    n_dir::Union{Nothing, Int}=nothing,
)
    D = 2F + 1
    length(spinor) == D ||
        throw(DimensionMismatch("spinor length $(length(spinor)) != 2F+1 = $D"))

    zee = zeeman_energies(zeeman, SpinSystem(F))
    if _zeeman_is_degenerate(zee)
        # Exact n^(5/2) scaling — one integral covers the whole table, and
        # V_LHY = dε/dn = (5/2) ε₁ n^(3/2) is then exact too. Going through
        # `_tabulate_lhy`'s central difference throws accuracy away for nothing:
        # measured against the closed form at F=6 FM, n_points=200, n_max=4,
        # rtol=1e-5, the FD costs 2.4-4.0x in V_LHY —
        #     n = 0.5:  6.9e-5 analytic  vs  2.7e-4 FD
        #     n = 1.0:  3.1e-5           vs  8.1e-5
        #     n = 2.0:  1.2e-5           vs  2.4e-5
        n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
        n_max > 0 || throw(ArgumentError("n_max must be positive"))
        n_atoms >= 1 || throw(ArgumentError("n_atoms must be >= 1"))
        eps_1 = _lhy_bdg_energy_density(spinor, 1.0, F, interactions, zeeman,
            c_dd, k_max, n_k, n_dir; rtol)
        densities = collect(range(0.0, n_max; length=n_points))
        # `/ n_atoms` for the same reason `_tabulate_lhy` divides: `g` comes from
        # the dimensionless c₀ = 4π(a_s/a_ho)N, which already carries N, while
        # `n = |ψ|²` is normalised to ∫|ψ|²dV = 1. This branch bypasses
        # `_tabulate_lhy` for accuracy and used to bypass its division with it,
        # so `full_bdg` was exactly N too large for every DEGENERATE Zeeman
        # config — i.e. the whole weak-field regime. Dividing V is equivalent to
        # dividing ε, since V = dε/dn and the scaling is exactly n^(5/2) here.
        return FullBdGLHY(densities, (2.5 * eps_1 / n_atoms) .* densities .^ 1.5)
    end

    _tabulate_lhy(FullBdGLHY; n_max, n_points, n_atoms) do n0
        _lhy_bdg_energy_density(spinor, n0, F, interactions, zeeman,
            c_dd, k_max, n_k, n_dir; rtol)
    end
end

# Cutoff in units of the stiffness momentum k_s = sqrt(2 n λ_max(C)) needed for
# rel ≤ 1e-4, measured flat at 17.9-19.1 across F, phase, c₀ and n. The extra
# factor 2 in the error target keeps the delivered accuracy comfortably inside
# rtol instead of landing on it (uncorrected it came out at 1.0-1.1 × rtol).
const _LHY_X_AT_1E4 = 19.0
const _LHY_SAFETY = 2.0
# Largest dimensionless cutoff that Float64 can carry. Beyond it the cancelling
# difference in the integrand loses more to round-off than the extra range buys:
# x = 51 (rtol 1e-5) is clean, x = 111 (rtol 1e-6) is already degrading. The
# STARTING cutoff has to respect this too — the refinement floor only guards the
# doublings, and at rtol = 1e-10 the derived x was 2400, past the cliff before a
# single refinement step.
const _LHY_X_MAX = 60.0

# Angular (k̂) quadrature is an error axis of its own, and the DDI is what makes
# it one — with c_dd = 0 a single direction is exact. Measured pure angular
# error at converged k, F=6 FM, c_dd = 0.05 (the demanding case; polar sits at
# ≤1e-5 for any n_dir ≥ 8): 3.0e-3, 7.8e-4, 2.3e-4, 8.3e-5, 5.6e-5 at n_dir =
# 4, 8, 16, 32, 48 — i.e. about 3.0e-3·(4/n_dir)^1.5, so
# n_dir ≈ 4·(3.0e-3/rtol)^(2/3). Capped at 64: past there the residual stops
# falling (at c_dd = 0.2 it plateaus near 5e-4 for every n_dir, because that
# mean field is dynamically unstable and the integrand is not smooth in k̂).
const _LHY_NDIR_AT_4 = 3.0e-3
const _LHY_NDIR_MAX = 64

"""
    _lhy_n_dir(rtol, c_dd, n_dir) -> Int

Directions for the `k̂` average. One when the DDI is off (the integrand has no
angular dependence then), otherwise derived from `rtol`; an explicit `n_dir` is
passed through.
"""
function _lhy_n_dir(rtol::Float64, c_dd, n_dir)
    n_dir !== nothing && return Int(n_dir)
    is_active(c_dd) || return 1
    clamp(ceil(Int, 4 * (_LHY_NDIR_AT_4 / rtol)^(2 / 3)), 4, _LHY_NDIR_MAX)
end

"""
    _lhy_quadrature(rtol, k_scale, k_max, n_k) -> (k_max, n_k)

Momentum cutoff and node count for a requested relative accuracy, given the
stiffness scale `k_scale = √(2 n λ_max(C))`. Truncation falls as `k_max^-3`, so

    k_max = 19 · k_scale · (2 · 1e-4 / rtol)^(1/3)

and the dimensionless range `x = k_max / k_scale` depends only on `rtol`, so
`n_k ∝ √x` closes the quadrature independently of the couplings. Either knob
may be pinned; the other is still derived.
"""
function _lhy_quadrature(rtol::Float64, k_scale::Float64, k_max, n_k)
    rtol > 0 || throw(ArgumentError("rtol must be positive, got $rtol"))
    ks = max(k_scale, 1e-12)
    x = min(_LHY_X_AT_1E4 * cbrt(_LHY_SAFETY * 1e-4 / rtol), _LHY_X_MAX)
    km = k_max === nothing ? ks * x : Float64(k_max)
    nk = n_k === nothing ? max(32, ceil(Int, 8 * sqrt(km / ks))) : Int(n_k)
    nk >= 3 || throw(ArgumentError("n_k must be ≥ 3, got $nk"))
    km, nk
end

# `diag(z) − μ` drops out of C exactly when the Zeeman energies are all
# equal, which is what makes the n^(5/2) scaling exact.
_zeeman_is_degenerate(zee) =
    maximum(zee) - minimum(zee) <= 1e-14 * max(1.0, maximum(abs, zee))

"""
    _lhy_bdg_stiffness(h_contact, M_contact, zee, spinor, n0, F, c_dd, sm, k_hat)
        → (C, B, mu)

The two k-INDEPENDENT stiffness matrices of the BdG problem at density
`n0`, for propagation direction `k_hat` (which only matters through the
DDI Q-tensor):

    A(k) = ε_k·I + C,   C = 2 n₀ h − μ·I + diag(z)   (Hermitian)
    B    = n₀ M_anom                                  (complex symmetric)

so that `H_BdG(k) = [A B; −B̄ −Ā]`. Every UV counterterm is a trace of
these, which is why the zero-point sum needs no branch labelling.

The CONTACT parts are passed in, not rebuilt: they carry no `k̂` dependence.
`instability_angular_map` and `bogoliubov/scan.jl` hoist the same way; this
was the odd one out.

Worth what it is and no more. Measured at F=6, `n_dir = 32`, `n_k = 200`
(breakdown reconciled against the end-to-end time, see `bench/reconcile.jl`):

    contact build  x1     0.001 s    0.1%
    DDI matrices   x32    0.000 s    0.0%
    k-loop         x32    1.376 s   ~100%
    ------------------------------------------
    measured total        1.353 s

so hoisting the rebuild saves 31 x 1.0 ms = 0.031 s, or 2.3%. Everything else
is the `_bdg_branch_sum` eigendecomposition, and it is a cold path — one
k-integral per workspace, since the `n^(5/2)` scaling collapses the density
axis — so it is left alone deliberately.

One number in that table is worth keeping: the k-loop costs 0.0059 s/direction
at `c_dd = 0` and 0.0430 s/direction at `c_dd = 0.05`, a 7x jump for an
anomalous matrix that goes from 1 to 4 non-zeros out of 169. Benchmarking this
kernel on the contact-only matrices therefore understates the dipolar cost by
~7x; use a `k̂` direction with the DDI actually switched on.

`sm` is the `spin_matrices(F)` cache, likewise direction-independent; pass
`nothing` when `c_dd` is inactive.
"""
function _lhy_bdg_stiffness(h_contact, M_contact, zee, spinor, n0, F, c_dd, sm, k_hat)
    D = 2F + 1
    h_mf, M_anom = if is_active(c_dd)
        h_ddi, M_ddi = _bdg_ddi_matrices(spinor, F, D, sm, c_dd,
            _q_tensor_direction(k_hat))
        (h_contact .+ h_ddi, M_contact .+ M_ddi)
    else
        (h_contact, M_contact)
    end

    # μ = ⟨ψ|(Z + n₀ h)|ψ⟩ — the full quadratic form, not the diagonal
    # (mirrors the 2026-04-26 fix in phases/bogoliubov.jl). It depends on the
    # direction through the DDI part of h, so it stays inside the loop.
    mu = real(dot(spinor, (Diagonal(zee) .+ n0 .* h_mf) * spinor))

    C = 2n0 .* h_mf
    @inbounds for i in 1:D
        C[i, i] += zee[i] - mu
    end
    C, n0 .* M_anom, mu
end

"""
    _bdg_branch_sum(C, B, ek, D) → (sum_omega, max_growth)

`Σ_b Re ω_b(k)` over the D branches of positive symplectic norm, plus
`max Im ω` as the dynamical-instability diagnostic.

Selecting by norm rather than by `|Re ω|` matters: a branch may have
positive norm and NEGATIVE energy (an energetically unstable but
dynamically stable mean field). Taking `|Re ω|` there flips that
branch's sign and, for a free branch that should cancel against its own
counterterm exactly, turns a zero contribution into a large one.

That is only reachable when the Bogoliubov Hessian
`𝓗 = [A B; B̄ Ā]` (Hermitian, with `H_BdG = σ_z 𝓗`) is INDEFINITE. When
`𝓗 ≻ 0` the mean field is a strict local minimum, the spectrum is real,
and every positive-norm branch has `ω > 0` — so `Σ_b ω_b = ½ Σ_j |Re λ_j|`
and the eigenvectors are not needed at all. A Cholesky attempt costs
0.0067 ms against 0.22 ms for the eigendecomposition, and dropping the
eigenvectors makes that 1.56× cheaper, so the test pays for itself many
times over: measured positive definite at 100% of k-nodes for F=6 polar
and 89% for F=6 FM.
"""
function _bdg_branch_sum(C, B, ek::Float64, D::Int)
    A = copy(C)
    @inbounds for i in 1:D
        A[i, i] += ek
    end
    H = zeros(ComplexF64, 2D, 2D)
    H[1:D, 1:D] .= A
    H[1:D, (D + 1):(2D)] .= B
    H[(D + 1):(2D), 1:D] .= .-conj.(B)
    H[(D + 1):(2D), (D + 1):(2D)] .= .-conj.(A)

    if _bdg_hessian_posdef(A, B, D)
        # σ_z-Hermitian with 𝓗 ≻ 0 ⇒ real spectrum in ± pairs, positive-norm
        # branches carry the positive member. No eigenvectors needed.
        lam = eigvals(H)
        return 0.5 * sum(abs ∘ real, lam), 0.0
    end

    ef = eigen(H)
    sum_omega = 0.0
    max_growth = 0.0
    @inbounds for j in 1:(2D)
        v = view(ef.vectors, :, j)
        norm_j = sum(abs2, view(v, 1:D)) - sum(abs2, view(v, (D + 1):(2D)))
        norm_j > 0 && (sum_omega += real(ef.values[j]))
        max_growth = max(max_growth, imag(ef.values[j]))
    end
    sum_omega, max_growth
end

# Is the Bogoliubov Hessian [A B; B̄ Ā] positive definite? Cholesky, so it
# answers without a spectrum. `check=false` keeps a failure on the cheap path
# rather than throwing.
function _bdg_hessian_posdef(A, B, D::Int)
    G = Matrix{ComplexF64}(undef, 2D, 2D)
    G[1:D, 1:D] .= A
    G[1:D, (D + 1):(2D)] .= B
    G[(D + 1):(2D), 1:D] .= conj.(B)
    G[(D + 1):(2D), (D + 1):(2D)] .= conj.(A)
    issuccess(cholesky!(Hermitian(G), NoPivot(); check=false))
end

# Σ over the k-panel [a, b] of w·k²·I(k), plus the running instability watch.
# Separated from the caller so a refinement pass can append an OUTER panel
# without recomputing the inner one.
function _lhy_k_panel(C, B, D::Int, a::Float64, b::Float64, n::Int,
    tr_C::Float64, B_fro2::Float64)
    nodes, weights = _gauss_legendre(n, a, b)
    acc = 0.0
    max_growth = 0.0
    for (k, w) in zip(nodes, weights)
        k <= 0 && continue
        ek = k * k / 2
        sum_omega, g = _bdg_branch_sum(C, B, ek, D)
        max_growth = max(max_growth, g)
        acc += w * k * k * (sum_omega - D * ek - tr_C + B_fro2 / (2ek))
    end
    acc, max_growth
end

"""
    _lhy_bdg_energy_density(spinor, n0, F, interactions, zeeman, c_dd,
                            k_max, n_k, n_dir) → Float64

`ε_LHY(n₀)` for the given spinor: UV-subtracted BdG zero-point energy
density, spherically averaged over `k̂` when the DDI is active.
"""
function _lhy_bdg_energy_density(spinor, n0, F, interactions, zeeman, c_dd,
    k_max, n_k, n_dir; rtol::Float64=1e-4, max_refine::Int=5)
    D = 2F + 1
    nd = _lhy_n_dir(rtol, c_dd, n_dir)
    dirs = is_active(c_dd) ? fibonacci_sphere_directions(nd) :
           [(0.0, 0.0, 1.0)]

    # Direction-independent, so built once outside the loop.
    h_contact, M_contact, zee, _ = _bdg_contact_matrices(spinor, F, interactions,
        zeeman)
    sm = is_active(c_dd) ? spin_matrices(F) : nothing

    # Per-direction stiffness/anomalous matrices and their k-independent traces.
    per_dir = map(dirs) do dir
        k_hat = collect(dir)
        k_hat ./= norm(k_hat)
        C, B, _ = _lhy_bdg_stiffness(h_contact, M_contact, zee, spinor, n0, F,
            c_dd, sm, k_hat)
        (C=C, B=B, tr_C=real(tr(C)), B_fro2=real(sum(abs2, B)),
            tail_coef=real(tr(C * B * conj(B))))
    end
    scale = maximum(d -> abs(d.tr_C), per_dir; init=1.0)

    # Starting cutoff from the stiffness momentum (see `_lhy_quadrature`); the
    # refinement below is what actually enforces `rtol`.
    # A pinned k_max is a request for THAT cutoff, so refinement is off in that
    # case: it is what the oracle tests and any convergence study rely on, and
    # silently doubling past it walks into the round-off cliff below (a
    # reference computed at a pinned k_max = 900 came back 92% wrong before
    # this).
    refine = k_max === nothing
    k_scale = sqrt(2 * max(maximum(abs, eigvals(Hermitian(per_dir[1].C))), 0.0))
    k_max, n_k = _lhy_quadrature(rtol, k_scale, k_max, n_k)

    # ∫₀^b, per direction, as (inner sum, analytic tail beyond b).
    inner = zeros(Float64, length(per_dir))
    max_growth = 0.0
    b = k_max
    function extend!(a, bb, n)
        for (i, d) in enumerate(per_dir)
            acc, g = _lhy_k_panel(d.C, d.B, D, a, bb, n, d.tr_C, d.B_fro2)
            inner[i] += acc / (4π^2)
            max_growth = max(max_growth, g)
        end
    end
    total(bb) = sum(inner[i] + per_dir[i].tail_coef / (2π^2 * bb)
                    for i in eachindex(per_dir))

    extend!(0.0, b, n_k)
    E = total(b)

    # Truncation is MEASURED, not modelled: extend by one outer panel to 2b and
    # see how much the answer moves. The analytic tail term is the size of the
    # correction, not of the residual left after it — using it as the error
    # estimate came out ~30x conservative (2.6% claimed against 8.1e-4 actual),
    # which would push k_max far past what rtol needs. A doubling comparison
    # carries no fitted constant. The outer panel is cheap: the integrand is
    # tiny and smooth out there, so half the nodes resolve it.
    # Raising k_max is not free of danger, which is the second reason not to
    # model the error. The integrand is a DIFFERENCE, Σω − D·ε_k − tr C, whose
    # terms grow as D·k²/2 while the result decays as k⁻². Double-precision
    # cancellation noise therefore grows relative to the signal as roughly k⁶,
    # and past some cutoff an extra panel is pure noise.
    #
    # The guard has to be PREDICTIVE, refusing a panel before computing it. A
    # post-hoc "did the answer move less than the noise" test does not work:
    # when the noise is large the movement is large too, so the test passes on
    # both counts and the corrupted value gets accepted. That is exactly what
    # happened — with the DDI at rtol = 1e-5 the refinement returned 249.0
    # against a true 14.29, and references computed at a large pinned k_max
    # were corrupted the same way, which poisoned four separate error
    # attributions during this work before the cause was found.
    #
    # Panel [b, 2b] is worth computing while
    #     noise/signal ≈ eps·D·b⁶ / (2·|Σ tail_coef|)  ≲ 1/10.
    tail_abs = sum(d -> abs(d.tail_coef), per_dir; init=0.0)
    panel_is_signal(bb) =
        tail_abs > 0 && eps(Float64) * D * bb^6 / (2 * tail_abs) <= 0.1

    err = NaN
    hit_floor = false
    if refine && rtol > 0
        for _ in 1:max_refine
            if !panel_is_signal(2b)
                hit_floor = true
                break
            end
            extend!(b, 2b, max(8, n_k ÷ 2))
            E2 = total(2b)
            err = abs(E2 - E) / max(abs(E2), 1e-300)
            E, b = E2, 2b
            err <= rtol && break
        end
        if hit_floor
            @warn "FullBdG LHY: rtol=$rtol is past what Float64 can deliver here. " *
                "The integrand is a cancelling difference whose round-off grows " *
                "like k_max⁶, so refinement stopped at k_max=" *
                "$(round(b; sigdigits=4))" *
                (isnan(err) ? "" : " with an estimated accuracy of $(round(err; sigdigits=3))") *
                ". Ask for a looser rtol (≳1e-4 is reliably reachable), or reduce " *
                "the coupling scale." maxlog=1
        elseif !(err <= rtol) && !isnan(err)
            @warn "FullBdG LHY: after $max_refine cutoff doublings (k_max=" *
                "$(round(b; sigdigits=4))) the estimated truncation is still " *
                "$(round(100err; sigdigits=3))% > rtol=$rtol. Treat ε_LHY as " *
                "accurate to about that, or pin a larger k_max." maxlog=1
        end
    end

    if max_growth > 1e-8 * scale
        @warn "FullBdG LHY: mean field is dynamically unstable " *
            "(max Im ω = $(round(max_growth; sigdigits=3))). The zero-point sum " *
            "drops the complex branches while the counterterms still subtract " *
            "all $D of them, so ε_LHY is scheme-dependent here. This is a " *
            "property of the state — the closed forms are no better. Pick a " *
            "mean-field-stable (F, c₀, c₁, q) point." maxlog=1
    end

    E / length(dirs)
end
