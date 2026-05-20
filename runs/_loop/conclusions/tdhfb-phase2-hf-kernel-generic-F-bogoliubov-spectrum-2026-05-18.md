# Conclusions index — tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18

Durable record of [Established] / [Plausible] / falsifier-tested claims for this investigation.
Director reads this before dispatching next subagent so claims aren't re-derived.

### T99 [Established] 2026-05-18T23:45:35.280622+09:00

[Established] Tier-2 regression — escalate to critic audit).


### T100 [Established] (Execute PASS — Tier 2.5)

F=1 Bogoliubov dispersions at small k in 6x6 Nambu L(k) via `hf_matrix_generic` + `channel_kernel` match KU2012 §4.2 / §5 phonon closed-forms at c_0=1.0:

- F1 polar phonon (c_0=1.0, c_1=+0.1): cs_measured=1.000007862, cs_expected=1.0, rel_err=7.86e-6 (PASS < 1e-3).
- F2 FM phonon (c_0=1.0, c_1=-0.1): cs_measured=0.9486915852, cs_expected=0.948683, rel_err=8.74e-6 (PASS < 1e-3).
- F3 BdG/GP factor-2 ratio: 2.0000000000000013, abs_err=1.33e-15 (PASS < 1e-12).
- F4 Goldstone gap: 0.0 (exact; advisory confirming mu choice).

Diagnostic script: `scripts/diagnostic/tdhfb_f1_bogoliubov_cross_check.jl` (35 lines). Wall time 2.15s warm JIT.

### T101 [Corroborate_with_errata] (critic Route I independent re-derivation — Tier 2.75)

T101 critic delivered Route I (GP-linearization, KU2012 §5.1.2) independent re-derivation reproducing polar phonon, FM phonon, and polar magnon dispersions via structurally different route from T99's CG-orthogonality route. Factor-2 identified differently (diagonal_Hartree + anomalous_Hartree sum vs Sigma^HF Bose-symmetrization); same algebraic value. Audit C1/C2/C3 all clean. Caveat: Deliverable B (numerical recompute at fresh parameters) delivered by symbolic substitution only — critic Read-only harness could not execute Julia.

### T102 [Established] (tier 3.0 — caveat resolved by empirical recompute)

Caveat from T101 resolved. T102 implementer ran /tmp/ parameter-override copy of the diagnostic script at two fresh parameter points:

**F1 polar fresh (c_0=2.0, c_1=+0.05, mu=2.0):**
- cs_measured = 1.414219121593437
- cs_expected = sqrt(2) = 1.4142135623730951
- rel_err = 3.93e-6 (PASS < 1e-3; predicted range by T101 symbolic substitution: 3e-6 to 1e-5)

**F2 FM fresh (c_0=0.5, c_1=-0.2, mu=0.3, |c_1/c_0|=0.4):**
- cs_measured = 0.5477369110060551
- cs_expected = sqrt(0.3) = 0.5477225575051661
- rel_err = 2.62e-5 (PASS < 1e-3; predicted range by T101 symbolic substitution: 1e-5 to 4e-5)

**F3 BdG/GP factor-2 ratio (fresh polar c_0=2.0, c_1=+0.05):**
- ratio_measured = 2.000000000000001
- abs_err = 8.88e-16 (PASS < 1e-12; parameter-independent structural confirmation)

all_recompute_falsifiers_passed: true. Julia wall time 2.2s (warm JIT). Return code 0.

**Conclusion**: TDHFB Phase 2 generic-F HF kernel (`hf_matrix_generic` + un-symmetrized `channel_kernel`) is [Established] to reproduce KU2012 F=1 Bogoliubov phonon dispersions at small k to relative tolerance ~3-26e-6 (well below 1e-3 threshold) across two independent parameter points, with BdG/GP factor-2 ratio confirmed at machine-epsilon precision. Tier 2.75 -> 3.0. Investigation closed.

### T102 [Established] 2026-05-19T00:53:30.073542+09:00

[Established]` block: polar phonon + FM phonon + BdG/GP factor-2 ratio with measured values at T100 (c_0=1) and T102 (c_0=2 polar, c_0=0.5 FM) parameter points.
- Independent corroboration section: T101 critic Route I GP-linearization re-derivation description.
- Arc summary: T98…

### T102 [Established] 2026-05-19T00:53:30.073542+09:00

[Established], T101 [Corroborate_with_errata], and T102 [Established] entries to
`runs/_loop/conclusions/tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18.md`.
File: 384 bytes -> 3046 bytes (APPEND only; prior T99 placeholder preserved).

### T102 [Established] 2026-05-19T00:53:30.073542+09:00

[Established] Tier-2 regression — escalate to critic audit)"). Preserved for audit trail; the T100/T101/T102 entries appended here are complete.

