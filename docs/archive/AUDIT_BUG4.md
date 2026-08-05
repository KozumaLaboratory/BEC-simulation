# AUDIT — Bug-4 (ITP merged-loop DDI half-rate)

> **FROZEN 2026-05-11.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Status**: bug fixed 2026-05-02 in `src/solvers/ground_state/itp_loop.jl`. **Scope**: every ITP ground state computed with `kind: spinor` and DDI on where `save_every > 1` ran with effective DDI integrated at less than its nominal value.

## What was wrong

`_run_itp_loop!` had two integration branches inside its loop:

- **`need_split` branch** (taken when `step % save_every == 0` or on the last step): correct — close + reopen pair gave two `_ddi_step!(ws, dt/2, …)` calls per step, summing to `dt` total DDI integration time.
- **`merged` branch** (taken otherwise): emitted

_outer_potential_fwd!(ws, dt/2, …) _ddi_step!(ws, dt/2, …) _outer_potential_bwd!(ws, dt/2, …)

This collapsed the outer operators (diag, c1, c2, tensor, Raman) to `dt` total per step (correct merge) but the inner DDI to only `dt/2` per step (**wrong** — Strang requires `dt`).

`_compute_and_convolve_ddi!` rebuilds φ\_{x,y,z} from the current ψ each call, so two `_ddi_step!(dt/2)` calls per step are *not* equivalent to one `_ddi_step!(dt)` call (substepping is the more accurate form). The merged branch effectively halved the DDI coupling for non-checkpoint steps and made the converged ψ dependent on `save_every`.

## Effective DDI rate per step

Across `save_every = N`, exactly `1/N` steps go through the correct need_split branch and `(N-1)/N` go through the buggy merge:

eff_DDI / true_DDI  =  (1/N) · 1  +  ((N-1)/N) · (1/2) =  (N + 1) / (2N)

| save_every | eff/true | shift          |
|------------|----------|----------------|
| 1          | 1.000    | none           |
| 2          | 0.750    | −25 %          |
| 5          | 0.600    | −40 %          |
| 10         | 0.550    | −45 %          |
| 40         | 0.5125   | −48.75 %       |
| 100        | 0.5050   | −49.5 %        |
| 1000       | 0.5005   | −49.95 %       |

For runs with `save_every ≥ 100` the effective `c_dd` was essentially half of the configured value. For Eu151 (configured `c_dd ≈ 7647`), the effective dipolar interaction was integrated as if `c_dd ≈ 3823`, and the dimensionless ε\_dd dropped from ≈ 0.54 to ≈ 0.27 — i.e. the ground state was equilibrated in a regime that was barely dipolar rather than the strongly-dipolar regime the config specified.

## Empirical confirmation

`/tmp/test_itp_ddi_half_rate.jl` (test/test_itp_ddi_strang_save_every.jl in the repo) compared GS energies and ψ for `save_every ∈ {1, 100}` with F=1, c_dd=2000, dt=0.005, 2000 ITP steps:

| | pre-fix | post-fix |
|---|---|---|
| E (save_every=1)    | −4.7910 | −4.7910 |
| E (save_every=100)  | −5.1217 | −4.7910 |
| max\|ψ₁ − ψ₁₀₀\|   | 0.166   | 0.000   |
| Control (c_dd=0)    | 6e-12   | 8e-12   |

Post-fix: bytewise identical ψ across `save_every`, confirming the fix is algebraically exact (not just an accuracy improvement).

## Affected runs

`runs/` configs with DDI active and the effective DDI shift each ran at:

| run                              | atom   | kind            | n_steps | save_every | eff_DDI / true | severity |
|----------------------------------|--------|-----------------|---------|------------|----------------|----------|
| eu151\_edh/                      | Eu151  | spinor          | 100 000 | 1 000      | 0.5005         | 🔴       |
| eu151\_lab\_calibrated/          | Eu151  | spinor          |   4 000 |    40      | 0.5125         | 🔴       |
| eu151\_phase\_diagram\_lbfgs/    | Eu151  | rotating\_basis |     500 |     5      | 0.600          | 🟡       |
| berry\_crossover\_scan/          | Eu151  | rotating\_basis | —       |     1      | 1.000          | ✅       |
| klaus\_baseline/                 | Eu151  | rotating\_basis | —       |     1      | 1.000          | ✅       |
| phi\_omega\_scan/                | Eu151  | rotating\_basis | —       |     1      | 1.000          | ✅       |

Notes:

- 🔴 = affected (re-run if the GS or any derivative is publication-bound).
- 🟡 = `rotating_basis` GS uses its own integrator (`split_step_rotating!`, not `_run_itp_loop!`), so the bug does NOT affect this run's GS path. Listed only to confirm it was checked. Effective DDI = 1.0 in practice.
- ✅ = either save_every=1 (need_split every step → always correct) or uses `kind: rotating_basis` exclusively.

### Re-run priority

1. **`runs/eu151_edh/`** — phase 0 (m = +F stretched GS at B = 1.0 μT, ε\_dd ~ 0.54 → ran at 0.27) feeds the EdH quench dynamics. The ψ handed to phase 1 was equilibrated at the wrong dipole strength, so any quoted ⟨L_z⟩, ⟨F_z⟩ trajectories are derived from a corrupted initial state. **Highest re-run priority** if EdH numbers feed a thesis figure or paper.

2. **`runs/eu151_lab_calibrated/`** — same class. Lab-calibrated B, FORT, and trap parameters were applied but to a GS that ran at half DDI. Re-run before publication-grade comparisons against lab data.

3. `eu151_phase_diagram_lbfgs/` — rotating_basis path; not affected directly by Bug-4. (See related concern below.)

### Not affected

Anything that ran in `kind: rotating_basis` is clean — `split_step_rotating!` and `apply_ddi_step_rotating!` apply DDI exactly once per step at full `dt` with no merge branching. Likewise `find_ground_state_lbfgs` (LBFGS path) does not pass through `_run_itp_loop!`. `scalar_egpe`'s `split_step_scalar!` is also a single DDI(dt) per step.

## Fix

`_run_itp_loop!` no longer merges DDI substeps. The merged branch is gone; every step now runs the close + reopen pair so DDI is integrated as `2 × _ddi_step!(ws, dt/2, …)` per step (algebraically the same as the previously-correct `need_split` branch — substepping with φ re-evaluation is also more accurate than a single dt-call would be). The outer (diag/c1/c2/tensor/Raman) merge is preserved (those operators are static across the substep boundary, so merging is exact).

Cost: ITP runs that previously hit the merged branch 99/100 of the time now do 2× DDI calls per step instead of 1×. Production runs typically already used `save_every ≈ n_steps/100`, so DDI was already called twice on every checkpoint step under the old code; the slowdown over a full run is bounded by ~2× DDI cost only on the merged steps, and DDI is dominated by FFT setup that is not fully doubled.

## Related — RTP merged-leapfrog accuracy degradation

Same audit looked at `_run_simulation_leapfrog!` (RTP) for an analogous rate bug. Verdict: **not a rate bug**. RTP's merged branch calls `_half_potential_step!(ws, dt, …)`, which correctly scales DDI to `dt` total per step (DDI rate = correct, both branches sum to `dt`).

However the substep difference *is* present: empirically, `save_every=1` vs `save_every=100` for an Eu-class RTP run with c_dd=2000 differs by ~30 % in ψ (vs ~1e-15 with c_dd=0), with the difference scaling quadratically-then-saturating with c_dd. This is the same type of substep-vs-merged accuracy difference the user identified for ITP, but it is a *2nd-order accuracy degradation* rather than a *halved coupling* — results are still mathematically Strang-correct, just less accurate at high `save_every` for stiff DDI.

Not auto-fixed: applying the same substep treatment to RTP would double the per-step DDI cost for production dynamics runs. Listed here so the user can weigh the trade-off; the structural change is identical to the ITP fix (always close + reopen, no merge for DDI) if it's decided to apply.

## Regression test

`test/test_itp_ddi_strang_save_every.jl` — pins `max|ψ(save_every=1) − ψ(save_every=100)| < 1e-10` for both DDI on (the regression target) and DDI off (numerical-noise control). Runs in 8.1 s.

## Memory note

`feedback_bug_4_itp_ddi_half_rate.md` (or `bug_4_itp_ddi_half_rate.md` per existing naming) — added to the `memory/` index alongside Bug-1, Bug-2, Bug-3 in CLAUDE.md.
