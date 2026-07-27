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
                               n_max, n_points, k_max, n_k) → FullBdGLHY

Spinor LHY for an ARBITRARY uniform spinor, from the BdG zero-point
integral. This is the general-`F`, general-state path; prefer the closed
forms (`compute_spinor_lhy_polar_contact`, `compute_spinor_lhy_fm_contact`,
`compute_spinor_lhy_icosahedral`) when the state matches one of their
ansatze, since those are ~two orders of magnitude cheaper.

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
    k_max::Float64=20.0,
    n_k::Int=200,
    n_dir::Int=32,
)
    D = 2F + 1
    length(spinor) == D ||
        throw(DimensionMismatch("spinor length $(length(spinor)) != 2F+1 = $D"))

    zee = zeeman_energies(zeeman, SpinSystem(F))
    if _zeeman_is_degenerate(zee)
        # Exact n^(5/2) scaling — one integral covers the whole table.
        eps_1 = _lhy_bdg_energy_density(spinor, 1.0, F, interactions, zeeman,
            c_dd, k_max, n_k, n_dir)
        return _tabulate_lhy(n -> eps_1 * n^2.5, FullBdGLHY; n_max, n_points)
    end

    _tabulate_lhy(FullBdGLHY; n_max, n_points) do n0
        _lhy_bdg_energy_density(spinor, n0, F, interactions, zeeman,
            c_dd, k_max, n_k, n_dir)
    end
end

# `diag(z) − μ` drops out of C exactly when the Zeeman energies are all
# equal, which is what makes the n^(5/2) scaling exact.
_zeeman_is_degenerate(zee) =
    maximum(zee) - minimum(zee) <= 1e-14 * max(1.0, maximum(abs, zee))

"""
    _lhy_bdg_stiffness(spinor, n0, F, interactions, zeeman, c_dd, k_hat)
        → (C, B, mu)

The two k-INDEPENDENT stiffness matrices of the BdG problem at density
`n0`, for propagation direction `k_hat` (which only matters through the
DDI Q-tensor):

    A(k) = ε_k·I + C,   C = 2 n₀ h − μ·I + diag(z)   (Hermitian)
    B    = n₀ M_anom                                  (complex symmetric)

so that `H_BdG(k) = [A B; −B̄ −Ā]`. Every UV counterterm is a trace of
these, which is why the zero-point sum needs no branch labelling.
"""
function _lhy_bdg_stiffness(spinor, n0, F, interactions, zeeman, c_dd, k_hat)
    D = 2F + 1
    h_mf, M_anom, zee, _ = _bdg_contact_matrices(spinor, F, interactions, zeeman)

    if is_active(c_dd)
        sm = spin_matrices(F)
        h_ddi, M_ddi = _bdg_ddi_matrices(spinor, F, D, sm, c_dd,
            _q_tensor_direction(k_hat))
        h_mf = h_mf .+ h_ddi
        M_anom = M_anom .+ M_ddi
    end

    # μ = ⟨ψ|(Z + n₀ h)|ψ⟩ — the full quadratic form, not the diagonal
    # (mirrors the 2026-04-26 fix in phases/bogoliubov.jl).
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

"""
    _lhy_bdg_energy_density(spinor, n0, F, interactions, zeeman, c_dd,
                            k_max, n_k, n_dir) → Float64

`ε_LHY(n₀)` for the given spinor: UV-subtracted BdG zero-point energy
density, spherically averaged over `k̂` when the DDI is active.
"""
function _lhy_bdg_energy_density(spinor, n0, F, interactions, zeeman, c_dd,
    k_max::Float64, n_k::Int, n_dir::Int)
    D = 2F + 1
    dirs = is_active(c_dd) ? fibonacci_sphere_directions(n_dir) :
           [(0.0, 0.0, 1.0)]

    # Gauss-Legendre: the integrand is smooth and decays as k⁻², so a
    # rectangle rule on a uniform grid wastes most of its points.
    nodes, weights = _gauss_legendre(n_k, 0.0, k_max)

    E_total = 0.0
    max_growth = 0.0
    scale = 1.0
    for dir in dirs
        k_hat = collect(dir)
        k_hat ./= norm(k_hat)
        C, B, _ = _lhy_bdg_stiffness(spinor, n0, F, interactions, zeeman,
            c_dd, k_hat)

        tr_C = real(tr(C))
        B_fro2 = real(sum(abs2, B))          # tr(B B̄) for symmetric B
        tail_coef = real(tr(C * B * conj(B)))  # I(k) → 2·tail_coef / k⁴
        scale = max(scale, abs(tr_C))

        acc = 0.0
        for (k, w) in zip(nodes, weights)
            k <= 0 && continue
            ek = k * k / 2
            sum_omega, g = _bdg_branch_sum(C, B, ek, D)
            max_growth = max(max_growth, g)
            acc += w * k * k * (sum_omega - D * ek - tr_C + B_fro2 / (2ek))
        end
        # Analytic remainder ∫_{k_max}^∞ k²·(2·tail_coef/k⁴) dk, so the
        # truncation error falls as k_max⁻² instead of k_max⁻¹.
        E_total += acc / (4π^2) + tail_coef / (2π^2 * k_max)
    end

    if max_growth > 1e-8 * scale
        @warn "FullBdG LHY: mean field is dynamically unstable " *
            "(max Im ω = $(round(max_growth; sigdigits=3))). The zero-point sum " *
            "drops the complex branches while the counterterms still subtract " *
            "all $D of them, so ε_LHY is scheme-dependent here. This is a " *
            "property of the state — the closed forms are no better. Pick a " *
            "mean-field-stable (F, c₀, c₁, q) point." maxlog=1
    end

    E_total / length(dirs)
end
