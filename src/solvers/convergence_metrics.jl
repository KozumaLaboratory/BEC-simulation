# Convergence metrics shared across the ITP / LBFGS / Newton-CG solvers.
# Single source so the relative-energy stopping test cannot drift between
# the fixed-dt and adaptive ITP loops.

# Relative energy change, scale-invariant so one `tol` works across systems
# whose E spans orders of magnitude. Falls back to the absolute change when
# E ≈ 0.
@inline function _relative_energy_change(E::Real, E_prev::Real)
    dE_abs = abs(E - E_prev)
    abs(E) > 0 ? dE_abs / abs(E) : dE_abs
end
