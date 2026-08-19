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

## Why there are FOUR names and not one number

`1e-30` appeared 121 times in 60 files on 2026-08-19 while `COUPLING_TOL`
had 7 references — and the reason is not laziness. The literal was doing
**two unrelated jobs** and only one of them had a name:

  1. *"is this coupling active?"*  — `abs(c1) > 1e-30`, gating a substep.
     This is `is_active`, and that migration WORKED: 122 uses against 10
     survivors.
  2. *"floor this denominator"*    — `num / max(den, 1e-30)`, keeping a
     ratio finite when the cloud is empty. `is_active` cannot express it,
     so every one of these sites kept the bare literal, and the count of
     bare literals read as "the migration failed" when in fact the
     migration had no name for half its territory.

The lesson is in `CLAUDE.md` commitment 11: an SSoT that covers part of a
pattern leaves the rest looking like debt. Name both jobs.

These are ALSO deliberately not shared with `src/validation/` — the dumb
reference and the reference RHS must restate every constant they use, or
they stop being an independent statement. Their bare `1e-30`s are the
oracle working as designed, and `test_threshold_single_statement.jl`
excludes that directory by name rather than by accident.
"""

"""
Threshold below which a magnitude is treated as numerically zero: a coupling
strength (dimensionless `g_S`, `c_k`, `c_dd`), a Clebsch-Gordan product, a
per-voxel density, a transverse field magnitude.

Named for its first use, but the predicate is the general one — `is_active` is
the reader for all of them.
"""
const COUPLING_TOL = 1e-30

"Threshold below which a rotation rate is treated as zero (units: ω/ω_ref)."
const ROTATION_TOL = 1e-15

"""
Floor for a denominator that is a MAGNITUDE (a norm, a density, a sum of
`abs2`), so that a ratio stays finite where the quantity vanishes.

Numerically equal to `COUPLING_TOL` and semantically unrelated: this one
answers "what do I divide by when the cloud is empty", not "should this
operator run". They are separate names so that either can be retuned
without silently moving the other — the bug that a shared literal makes
invisible.

Assumes `den ≥ 0`; apply `abs` first if that is not guaranteed.
"""
const DENOM_FLOOR = 1e-30

"Floor for an adaptive step-size denominator, at the edge of Float64 range."
const UNDERFLOW_FLOOR = 1e-300

"""
    is_active(x::Real, tol::Real = COUPLING_TOL) → Bool

Test whether `x` is non-negligibly different from zero — i.e. whether
the operator gated on `x` should actually run. Defaults to the coupling
threshold; pass `ROTATION_TOL` for angular frequencies.
"""
@inline is_active(x::Real, tol::Real=COUPLING_TOL) = abs(x) > tol

"""
    safe_div(num, den) → num / max(den, DENOM_FLOOR)

Ratio against a magnitude denominator that may be zero. `den` is assumed
non-negative — this is the `norm`/`density`/`sum(abs2)` case, which is
every caller in the tree.
"""
@inline safe_div(num::Real, den::Real) = num / max(den, DENOM_FLOOR)
