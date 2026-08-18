# --- Exact Thomas-Fermi aspect ratio of a dipolar BEC ---
#
# O'Dell, Giovanazzi & Eberlein, PRL 92, 250401 (2004); Eberlein, Giovanazzi &
# O'Dell, PRA 71, 033618 (2005). A harmonically trapped dipolar condensate in
# the Thomas-Fermi limit has an exactly parabolic density, and its aspect ratio
# κ = R_⊥/R_z solves a transcendental equation in (ε_dd, λ) alone — independent
# of N and of the trap frequency scale.
#
# This is a closed-form ANCHOR FOR A MAGNITUDE, which the repo did not have for
# the dipolar kernel. `test/rotating_basis/test_scalar_egpe_dipole_kernel.jl`
# pins symmetry and direction only, and a kernel scaled by any constant passes
# every assertion in it. Magnetostriction magnitude is exactly what a
# reproduction of a magnetostirring experiment rests on.

export dipolar_tf_aspect_ratio, dipolar_tf_shape_residual

"""Anisotropy function `f(κ)` of the dipolar TF solution. Analytic through
κ = 1 (both branches → 0); the two square roots swap which one is real."""
function _tf_f(κ::Real)
    κ ≈ 1 && return 0.0
    if κ < 1
        s = sqrt(1 - κ^2)
        return (1 + 2κ^2 - 3κ^2 * atanh(s) / s) / (1 - κ^2)
    end
    s = sqrt(κ^2 - 1)
    (1 + 2κ^2 - 3κ^2 * atan(s) / s) / (1 - κ^2)
end

"""
    dipolar_tf_shape_residual(κ, ε_dd, λ)

Left-hand side of the TF shape equation; zero at the equilibrium `κ = R_⊥/R_z`.

    3κ²ε_dd[(λ²/2 + 1)·f(κ)/(1−κ²) − 1] + (ε_dd − 1)(κ² − λ²) = 0
"""
dipolar_tf_shape_residual(κ::Real, ε_dd::Real, λ::Real) =
    3κ^2 * ε_dd * ((λ^2 / 2 + 1) * _tf_f(κ) / (1 - κ^2) - 1) +
    (ε_dd - 1) * (κ^2 - λ^2)

"""
    dipolar_tf_aspect_ratio(ε_dd, λ; tol=1e-10) -> κ = R_⊥/R_z

Equilibrium Thomas-Fermi aspect ratio. `λ = ω_z/ω_⊥`; `ε_dd = a_dd/a_s`.
`ε_dd = 0` returns `λ` exactly (the cloud takes the trap's shape, inverted).
Returns `NaN` when no equilibrium exists on the physical branch — for
`ε_dd > 1` the residual has a second root at small κ that is NOT the trapped
solution, so the search starts at `κ = λ` and walks toward the first sign
change rather than bisecting the whole axis. Bisecting blindly returns the
spurious branch, which is how this was first got wrong.
"""
function dipolar_tf_aspect_ratio(ε_dd::Real, λ::Real; tol::Real=1e-10)
    λ > 0 || throw(ArgumentError("λ must be > 0, got $λ"))
    ε_dd == 0 && return float(λ)
    r_at_λ = dipolar_tf_shape_residual(λ, ε_dd, λ)
    isfinite(r_at_λ) || return NaN
    # Walk from κ = λ in the direction of decreasing residual magnitude.
    step = 0.98
    r_at_λ > 0 && (step = 1 / 0.98)
    a = float(λ)
    b = a
    for _ in 1:2000
        b = a * step
        (b > 1e3 || b < 1e-4) && return NaN
        rb = dipolar_tf_shape_residual(b, ε_dd, λ)
        isfinite(rb) || return NaN
        sign(rb) != sign(r_at_λ) && break
        a = b
    end
    sign(dipolar_tf_shape_residual(b, ε_dd, λ)) == sign(r_at_λ) && return NaN
    lo, hi = min(a, b), max(a, b)
    for _ in 1:200
        m = (lo + hi) / 2
        (hi - lo) < tol && break
        if sign(dipolar_tf_shape_residual(m, ε_dd, λ)) ==
            sign(dipolar_tf_shape_residual(lo, ε_dd, λ))
            lo = m
        else
            hi = m
        end
    end
    (lo + hi) / 2
end
