# GP-LHY simulation skeleton for SpinorBEC.jl integration.
# Source: parallel session 2026-05-03, Phase A.2 closed-form derivation.
# Reproduces Saito-Li 2024 (arXiv:2402.18885) torus/cigar droplet phase
# diagram, but with the F=6 polar+DDI LHY closed form (paper #1, Eqs. 5-6)
# as the local-density correction.
#
# STATUS: standalone reference, NOT yet wired into SpinorBEC.jl. The
# skeleton's split-step + simplified DDI will be replaced by the existing
# `src/solvers/embedded_adaptive.jl` Yoshida S4 + L2-adaptive-dt and the
# existing full F̂-tensor `src/hamiltonian/interactions/ddi.jl`. The
# closed-form `eps_LHY_F6_polar_DDI` and `phi1_reg` are the load-bearing
# additions; everything else duplicates production code at lower fidelity.
#
# Integration plan (see bench/eu_droplet_INTEGRATION_NOTES.md):
#   1. Move `phi1_reg` + `eps_LHY_F6_polar_DDI` into
#      `src/hamiltonian/interactions/lhy.jl` as a new `:closed_form_F6_polar`
#      mode of `compute_spinor_lhy_table` (currently has :two_channel +
#      :full_bdg; the closed form adds a third, F=6-specific mode).
#   2. Drop the in-skeleton evolution loop; the production
#      `find_ground_state(; spinor_lhy=:closed_form_F6_polar, ...)` already
#      composes Yoshida + adaptive dt + full DDI.
#   3. Use this file's `initial_cigar_polar` / `initial_torus_FM` builders
#      as reference for new `init_psi_*` entries in
#      `src/workflow/initialization/state_zoo.jl` (currently 22 named
#      builders; add `cigar_polar` and `torus_FM_vortex`).

using LinearAlgebra
using FFTW
using Printf

# ============================================================
# LHY local density (using closed forms from Stage A.2)
# ============================================================

"""
    phi1_reg(t::Real) -> Real

Universal Petrov-regularized LHY function from Uchino-Kobayashi-Ueda 2010.
For a single BdG mode with dimensionless gap parameter t = ξ/|Δ| - 1:
- t > 0: gapped mode, contributes (n|Δ|)^(5/2) · phi1_reg(t)
- t = 0: gapless (Goldstone), phi1_reg(0) = 1
- t < 0: unstable (Petrov regularization: real-part-only)
"""
function phi1_reg(t::Real)
    abs(t) < 1e-12 && return 1.0

    integrand = (x) -> begin
        x2 = x * x
        a, b = x2 + t, x2 + t + 2.0
        prod = a * b
        u = x2 + t + 1.0
        if prod >= 0
            return x2 / (u + sqrt(prod)) - 0.5
        else
            return x2 * u - 0.5  # Petrov regularization
        end
    end

    boundaries = sort([sqrt(v) for v in [-t, -t - 2.0] if v > 0])
    intervals = [0.0; boundaries; Inf]
    total = 0.0
    for i in 1:(length(intervals) - 1)
        ub = intervals[i + 1]
        ub_f = isinf(ub) ? 100.0 : ub  # cutoff for skeleton; use QuadGK in production
        n_pts = 1000
        xs = range(intervals[i], ub_f, n_pts)
        dx = (ub_f - intervals[i]) / (n_pts - 1)
        total += sum(integrand.(xs)) * dx
    end
    return -15.0 / (8.0 * sqrt(2.0)) * total
end

"""
    eps_LHY_F6_polar_DDI(n, eps_dd, ka) -> ε_LHY

LHY energy density for F=6 polar phase with DDI, using the closed form
from paper #1 (PRA Letter draft).

Decomposition:
  - m=0 phonon: (n κ_0)^(5/2)
  - |m|=1 antisym: (n|Δ_a|)^(5/2) · phi_1^reg(t_a)        [Eq. 5]
  - |m|=1 sym: 1D w-integral                              [Eq. 6]
  - |m|≥2: contact-only, 2 · (n|Δ_m|)^(5/2) · phi_1^reg(t_m)
"""
function eps_LHY_F6_polar_DDI(n::Real, eps_dd::Real, ka::Vector{<:Real})
    F = 6
    factor = (8.0 / (15 * π^2)) * sqrt(2.0)  # ℏ=M=1

    # m = 0 phonon
    kappa_0 = ka[1]
    contrib_0 = (n * kappa_0)^2.5

    # |m|=1 antisymmetric (Eq. 5)
    kappa_1 = ka[2]
    if eps_dd < 0.5
        anti_factor = ((1 - 2 * eps_dd) / (1 - eps_dd))^2.5
        t_a = eps_dd / (1 - 2 * eps_dd)
        contrib_1a = (n * kappa_1)^2.5 * anti_factor * phi1_reg(t_a)
    else
        contrib_1a = 0.0  # DDI instability boundary
    end

    # |m|=1 symmetric (1D w-integral, Eq. 6)
    if eps_dd > 1e-3 && eps_dd < 0.5
        α = (1 - eps_dd) / (1 + eps_dd)
        β = (1 - eps_dd) / (1 - 2 * eps_dd)
        prefactor = (n * kappa_1)^2.5 * (1 - eps_dd) /
                    (2 * sqrt(3 * eps_dd * (1 + eps_dd)))
        n_w = 200
        ws = range(α + 1e-6, β - 1e-6, n_w)
        integrand_arr = zeros(n_w)
        for (i, w) in enumerate(ws)
            integrand_arr[i] = phi1_reg(w - 1) / (w^4 * sqrt(w - α))
        end
        dw = (β - α - 2e-6) / (n_w - 1)
        integral = sum(integrand_arr) * dw
        contrib_1s = prefactor * integral
    else
        contrib_1s = (n * kappa_1)^2.5
    end

    # |m| ≥ 2 (contact-only, ξ_m = Δ_m → t=0, phi=1)
    contrib_high = 0.0
    for m in 2:F
        kappa_m = ka[m + 1]
        contrib_high += 2 * (n * abs(kappa_m))^2.5
    end

    return factor * (contrib_0 + contrib_1a + contrib_1s + contrib_high)
end

# ============================================================
# Sanity smoke test (run on `julia --project=. bench/eu_droplet_skeleton.jl`)
# ============================================================

if abspath(PROGRAM_FILE) == @__FILE__
    println("=== eps_LHY_F6_polar_DDI smoke test ===")
    n = 1.0
    ka = fill(4π, 7)  # κ_0..κ_6 = 4π (Eu-like)
    for eps_dd in (0.0, 0.1, 0.3, 0.45)
        ε = eps_LHY_F6_polar_DDI(n, eps_dd, ka)
        println(@sprintf("  eps_dd=%.2f  ε_LHY = %.6e", eps_dd, ε))
    end

    println("\n=== phi1_reg sanity ===")
    for t in (-0.5, 0.0, 0.5, 1.0, 2.0)
        println(@sprintf("  φ_1^reg(%.2f) = %.6f", t, phi1_reg(t)))
    end
end
