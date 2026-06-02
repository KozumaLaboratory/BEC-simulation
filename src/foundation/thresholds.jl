"""
Shared "is this coupling / rotation rate active?" thresholds and helper.

Across the codebase, calls of the form `if abs(c) > 1e-30 ... end` gate
operator substeps on coupling magnitude (skip the FFT pair when c1 is
zero, skip the Coriolis substep when Ω is zero, etc.). The thresholds
were inconsistent — `1e-30` for coupling strengths, `1e-15` for angular
frequencies, occasionally `1e-300` for adaptive step-size denominators
— and individually buried at each call site.

This module pins the two physically-meaningful thresholds (couplings vs.
rotations) as named constants and provides `is_active(x, tol)` so
callers read as a sentence and tuning is a one-line change.

```julia
using SpinorBEC: is_active, COUPLING_TOL, ROTATION_TOL

if is_active(c1)           # coupling default → COUPLING_TOL = 1e-30
    apply_spin_mixing_step!(...)
end
if is_active(Ω, ROTATION_TOL)   # rotation rate → 1e-15
    apply_coriolis_step!(...)
end
```

The bare values are kept available for legacy call sites; new code
should prefer `is_active`.
"""

"Threshold below which a coupling strength is treated as zero (units: dimensionless g_S, c_k, c_dd)."
const COUPLING_TOL = 1e-30

"Threshold below which a rotation rate is treated as zero (units: ω/ω_ref)."
const ROTATION_TOL = 1e-15

"""
    is_active(x::Real, tol::Real = COUPLING_TOL) → Bool

Test whether `x` is non-negligibly different from zero — i.e. whether
the operator gated on `x` should actually run. Defaults to the coupling
threshold; pass `ROTATION_TOL` for angular frequencies.
"""
@inline is_active(x::Real, tol::Real=COUPLING_TOL) = abs(x) > tol
