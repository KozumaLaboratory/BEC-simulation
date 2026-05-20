# Investigation thread — tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18

**Title**: TDHFB Phase 2 generic-F HF kernel: Tier-3 cross-validation vs KU2012 F=1 Bogoliubov closed-forms

**Hypothesis**: TDHFB generic-F Hartree-Fock kernel (hf_matrix_generic, BdG self-energy convention with factor-2 Bose symmetrization) reproduces KU2012 F=1 polar phonon, polar magnon, and FM phonon Bogoliubov dispersions to relative tolerance 1e-3 in small-k regime, AND the BdG-vs-GP factor-2 ratio at the F=1 polar self-pair diagonal element equals exactly 2.0 within machine epsilon.

**Flow template**: verify-claim

**Tier target**: 3

## Turn-by-turn narrative

### T99 (2026-05-18T23:45:35.129830+09:00) — PASS — `tdhfb-phase2-tier3-T99-execute-state-json-registration-patch`

- Stage: **Hypothesize**, tier: 1.5
- Cost: 2744k effective tokens
- Contract: PASS
- Budget audit: BUDGET_OVER (actual/expected = 1.72)

### T100 (2026-05-19T00:02:50.710856+09:00) — PASS — `tdhfb-phase2-tier3-T100-execute-f1-f2-f3-falsifiers-julia-cpu-light`

- Stage: **Execute-complete**, tier: 1.5
- Cost: 1838k effective tokens
- Contract: PASS

### T102 (2026-05-19T00:53:29.922906+09:00) — PASS — `tdhfb-phase2-tier3-T102-document-with-julia-recompute-caveat-resolve`

- Stage: **closed**, tier: 3.0
- Cost: 2148k effective tokens
- Contract: PASS

