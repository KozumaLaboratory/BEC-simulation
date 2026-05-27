# FORTRESS spin-1 contact cross-check — scope (Task #16)

**Status: SCOPED, NOT EXECUTED.** Full install + run is a multi-hour
effort (Fortran 90 + OpenMP + native libs); this document is the
tracker for the next person (or session) that picks it up.

## Why this matters (post-pivot validation chain)

External code comparison with the Ueda lab is BLOCKED_EXTERNAL
(`docs/validation/ueda_status.md`). FORTRESS is the most feasible
*independent* spinor-GP reference (researcher report 2026-05-26).
Specifically:

- Covers F=1 and F=2 contact GP in 3D, ITP + RTP via split-step
  Fourier — same algorithm family as SpinorBEC.jl's standard path.
- Open source, OpenMP-parallelised, Fortran 90.
- Does NOT cover DDI, spinor LHY, or F=6.

So FORTRESS validates the **contact spinor sector** of SpinorBEC.jl
against an independent external implementation. It does not, and
cannot, validate Eu-specific physics.

## What we want to compare

For Rb-87 F=1 (contact only, no DDI, no LHY):

1. **Polar GS** (c₁ > 0): density profile + chemical potential + per-
   component populations.
2. **FM GS** (c₁ < 0): same observables.
3. **SMA spin-mixing dynamics**: population oscillation period and
   amplitude under a small initial spin imbalance, at the analytic
   period τ = 2π / sqrt(c_1 · n).

Tolerance: agreement at ≤ 1% for energies and populations (good
external benchmark). Higher tolerance acceptable for time-domain
oscillation amplitudes since each code's integrator differs.

## Where FORTRESS lives

- Paper: arXiv:2002.04365 (spin-1, 2020) + CPC 279 (2022) (spin-1+2 extension)
- DOI of CPC code release: `10.17632/<see CPC supplementary>`
- CPC programme library mirror: <not yet fetched; manual lookup>

## Install requirements (estimated)

- gfortran (or equivalent F90 compiler with OpenMP)
- FFTW3 (with OpenMP)
- `make` (Makefile provided in CPC release)
- Input file format: namelist-style `input.dat` (per CPC paper §3)

Estimated install + first-run time: 4-8 hours assuming a Linux box
with apt-installable deps.

## Suggested SpinorBEC.jl side preparation

1. Build a Rb-87 F=1 polar GS and FM GS in SpinorBEC.jl at the same
   grid / box / N as FORTRESS supports (typically 64-128 in each
   axis, box 12-16 a_ho).
2. Export the resulting ψ + density profile + (E_kin, E_trap, E_contact)
   to a JSON file under `runs/fortress_compare/spinorbec_side/`.
3. Document the conversion rules (FORTRESS uses different units
   internally — almost certainly different ω_ref normalisation).

Reuse `scripts/validation/export_operator_rhs.jl` shape — adapt to
emit FORTRESS-friendly density profile.

## What this is NOT

- Not an Eu validation. Eu (F=6 + DDI) has no public external code.
- Not a substitute for the L4 K3 ladder (Task #14). The K3 question
  is purely internal.
- Not high priority while internal validation chain is still being
  hardened.

## When to actually do it

After:
- L4 K3 ladder (Task #14) at 64³ at minimum has run
- The Case A/B/C/D physics judgement has been made
- A dedicated 1-2 day window opens for the install + comparison work

Until then, this document is the "next session pickup" pointer.

## References

- `runs/_loop/research/cross_code_benchmark_alternatives_T1.md` —
  full researcher survey
- arXiv:2002.04365 (FORTRESS spin-1 release paper)
- CPC 279 (2022) (FORTRESS spin-1+2 extension)
