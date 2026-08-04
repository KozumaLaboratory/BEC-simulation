# Integrator: state-averaged trap step and the AVF distinction

> **FROZEN 2026-06-06.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Provenance**: physics content extracted from docstrings of
`_half_potential_step_trap!` and `split_step_trap!` in
`src/hamiltonian/integrator/split_step.jl`, deleted 2026-06-06.
See git history for the implementation.

## What the scheme does

`_half_potential_step_trap!` uses `(psi_orig + psi_exit_est) / 2`
as the mean-field source, with Picard iteration on `psi_exit_est`:

1. Initial exit estimate = entry state (crude).
2. Each Picard round: re-evaluate the V step from `psi_orig` with
   the mean-field frozen at the discrete average of entry and current
   exit estimate.
3. Commit the converged exit estimate back to the live state.

`split_step_trap!` is a drop-in replacement for `split_step!` that
substitutes `_half_potential_step_trap!` for `_half_potential_step!`
in both V(dt/2) sandwich positions.

## Important distinction: state-average is NOT Quispel-McLaren AVF

This implements `(psi_n + psi_{n+1}) / 2` as the MF **source** — i.e.
the field evaluation point is the average of the wavefunctions at the
V-step entry and exit.

This is **NOT** the Quispel-McLaren Average Vector Field (AVF) method,
which averages the gradient field:

- Trapezoidal AVF: `grad_tilde_H = (1/2) * (grad_H(psi_n) + grad_H(psi_{n+1}))`
- True AVF: `grad_tilde_H = int_0^1 grad_H((1-s)*psi_n + s*psi_{n+1}) ds`

For a quadratic Hamiltonian all three coincide. For the non-quadratic
GPE (which has `c0|psi|^4 + c_dd psi^2 Phi + c1 <F>^2` quartic terms)
they differ at O(tau^2).

## Empirical order collapse (Rb87 F=1 16^3, Phase 2a bench)

With Picard converged to fixed point (verified by
`scripts/bench/trap_picard_diag.jl`: trap Picard residual at
n_picard >= 4 reaches ~1e-14), Y4 composition of this V step gives
**global order 2**, not 4.

Diagnostic via linear-H analysis:

```
(psi_n + psi_{n+1}) / 2  =  psi_n * cos(H*tau/2) * exp(-i*H*tau/2)
psi_midpoint             =  psi_n * exp(-i*H*tau/2)
```

The state-average carries an extra `cos(H*tau/2) = 1 - (H*tau)^2/8 + ...`
factor — an **even-power-in-tau correction**. The corresponding H
evaluation in the V step is shifted by tau^2 * O(H^2), which Y4's
odd-only Richardson cancellation cannot remove. This collapses the
composed order to 2.

In contrast, `_half_potential_step_midpoint!` (run-the-predictor-to-
the-midpoint scheme) gives Y4 order 4 because the midpoint MF differs
from the true midpoint only at odd powers of tau.

## What this scheme is good for

State-averaged trap is **implicit and time-reversible** (verified) and
its single-V-step local error has different higher-order structure than
midpoint. The drift behaviour vs implicit-midpoint at long times is open
empirically — see `scripts/bench/avf_drift_phase5_smoke.jl` (cited as
historical; the bench script was not committed).

Useful as a benchmark methodology data point, less so as a production
high-order integrator. Use Y4-midpoint for that.

## Path to true AVF

True trapezoidal AVF or 2-pt Gauss-Legendre AVF (which DO preserve energy
on quartic H) requires per-substep "averaged field" buffer plumbing:
modify `density_buf`, alpha/beta/theta cache, Phi_x/y/z to be the
average of 2 evaluations. This is a research-grade addition, not a patch;
deferred to a separate effort.

## Cost

`n_picard` V-step invocations per call. Picard converges to fixed point
in 2-4 iterations on the lab path (trap residual ~1e-6 -> 1e-14 between
Picard 1 and 4). Default `n_picard=2`; callers needing Picard-converged
trap should pass `n_picard=4`.

Allocation: 2 `similar(psi)` per call.
