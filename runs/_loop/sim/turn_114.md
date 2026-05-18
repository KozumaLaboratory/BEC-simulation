---
turn: 114
subagent: implementer
investigation_id: sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19
stage_advancing_from: "Hypothesize (theorist drafted multiplicity-aware Schur restoration)"
stage_advancing_to: "Hypothesize (validated; ready for Test/Execute at T115+)"
---

# Turn 114 — Implementer theorist-validation (text-mode, no julia)

## 1. Directive received

Verbatim from `runs/_loop/director/turn_114.md` §6:

> action: text-mode validation of theorist Hypothesize output at `runs/_loop/theorist/turn_114.md` for investigation `sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19`. Run the precondition_check and the 8 success_criteria check_cmds from director's §6.observable_manifest. Do NOT create `scripts/manuscript/f9_TA_mult2_schur_restore.jl`. Do NOT execute Julia or modify src/. Emit sim report + commit only the report to an auto-branch.

Director observable_manifest summary:
- `precondition_check`: file existence + 'T:A' grep in f9_f11_verification_result.md
- 8 success criteria, all grep/test (no julia, no python, no h5py)
- expected exit_code: 0 for all criteria
- budget: expected_cost_eff 1.5M, expected_wall_time_sec 1100

## 2. Branch / commit

- branch: `auto/turn_114_f9_TA_theorist_validation`
- parent: `2bf7710` (main HEAD; auto(loop): T113 NOOP_DIRECTOR noop)
- commit: (this report; sim-only; no src/ changes, no scripts/ changes, no julia executions, no h5py executions)

## 3. Schema/sibling audit

N/A — this turn is theorist-validation (`workload_class: implementer_text`). No YAML, no `make_workspace`, no sim. The audit-relevant question is: did theorist try to circumvent the no-julia rule by writing a `scripts/manuscript/f9_TA_mult2_schur_restore.jl` stub? Verified absent (criterion #7).

Sibling artifacts inspected (read-only, for context only):
- `docs/manuscript/papers/paper3_universal_theorem/f9_f11_verification_result.md` — row F=9 T:A multiplicity 2, β_0 = 0.0524 vs 1/19 = 0.05263, dev ≈ 2e-4
- `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` — Lemma 1 General-S closed-form, single-multiplicity Schur-isotropy step
- `scripts/manuscript/f9_f11_polyhedral_verification.jl` (read-only, NOT executed)
- `scripts/manuscript/lemma1_general_S_verification.jl` (read-only, NOT executed)
- `runs/_loop/seed.md` — priority-0 `edh-eu151-vortex-vs-matsui-science-2026` still pinned (criterion #8 verifies)
- `runs/_loop/theorist/turn_114.md` — the theorist Hypothesize output under validation

## 4. Commands executed

All commands run with effective wall_time < 1 sec each (pure grep/test; no julia, no IO heavy work).

```
# precondition_check
test -f /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/f9_f11_verification_result.md \
  && test -f /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md \
  && test -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_f11_polyhedral_verification.jl \
  && test -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl \
  && grep -q 'T:A' /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/f9_f11_verification_result.md \
  && echo OK_T114_PIVOT_PRECONDITIONS_HOLD
# stdout: OK_T114_PIVOT_PRECONDITIONS_HOLD  (exit 0)

# criterion 1: theorist-output-exists
test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_114.md   # exit 0

# criterion 2: theorist-output-has-schur-isotropic-section
grep -E -i 'schur.isotropic|schur.basis|canonical.basis' \
  /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_114.md   # exit 0 (many matches)

# criterion 3: theorist-output-has-projector-orbit-section
grep -E -i 'projector.orbit|orbit.average|invariant.subspace' \
  /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_114.md   # exit 0 (many matches)

# criterion 4: theorist-output-states-prediction
grep -E '1/19|1/\(2F\+1\)|beta_0' \
  /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_114.md   # exit 0 (many matches incl. predicted bar_beta_0 = 1/(2F+1) = 1/19)

# criterion 5: theorist-output-has-falsifier-contract
grep -E -i 'falsifier|F1|CORROBORATE|REFUTED' \
  /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_114.md   # exit 0 (F1/F2/F3 falsifiers + CORROBORATE/REFUTED bands)

# criterion 6: theorist-output-mentions-tolerance
grep -E '1e-13|machine precision|tolerance' \
  /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_114.md   # exit 0 (1e-13 referenced 8+ times)

# criterion 7: no-julia-side-effects-in-runs
test ! -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/f9_TA_mult2_schur_restore.jl   # exit 0 (file absent, as required)

# criterion 8: seed-md-priority-0-still-held-edh-matsui-not-violated
grep -q 'edh-eu151-vortex-vs-matsui-science-2026' /home/suzume/workspace/BEC-simulation/runs/_loop/seed.md   # exit 0
```

All 8 criteria returned exit 0 (PASS). Precondition_check also passed.

## 5. Metrics

```json
{
  "experiment_kind": "theorist_validation",
  "workload_class": "implementer_text",
  "investigation_id": "sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19",
  "stage_advancing_to": "Hypothesize (validated, ready for Test at T115+)",
  "subagent_type": "theorist",
  "theorist_output_path": "runs/_loop/theorist/turn_114.md",
  "hypothesis_documented": true,
  "schur_isotropic_basis_criterion_proposed": true,
  "projector_orbit_average_proposed": true,
  "f1_falsifier_contract_specified": true,
  "f2_advisory_falsifier_specified": true,
  "generalization_scope_enumerated": true,
  "precondition_check_passed": true,
  "criterion_theorist-output-exists": true,
  "criterion_theorist-output-has-schur-isotropic-section": true,
  "criterion_theorist-output-has-projector-orbit-section": true,
  "criterion_theorist-output-states-prediction": true,
  "criterion_theorist-output-has-falsifier-contract": true,
  "criterion_theorist-output-mentions-tolerance": true,
  "criterion_no-julia-side-effects-in-runs": true,
  "criterion_seed-md-priority-0-still-held-edh-matsui-not-violated": true,
  "criteria_passed_count": 8,
  "criteria_total_count": 8,
  "tests_passed": true,
  "warnings": [],
  "physical_red_flags": [],
  "tokens_used": null
}
```

## 6. Observations (plot-ready, no LLM interpretation)

Theorist deliverable structure (from `runs/_loop/theorist/turn_114.md`):
- §1 Directive received: present
- §2 Derivation: present with §2.0 source-evidence, §2.1 single-multiplicity-assumption identification, §2.2 failing-proof-step quote (lines 137–140 of sign_pattern_lemma1_general_S.md), §2.3 small-deviation explanation, §2.4 two candidate fixes (§2.A projector-orbit + §2.B Schur-isotropic basis + §2.C equivalence argument), §2.5 strict-generalization regression check
- §3 Sanity checks: 5 sanity checks passed in-derivation (dim, mult-1 limit, symmetry, sign, order-of-magnitude, sum-rule)
- §4 Calibrated claims: 4 [Established] + 5 [Plausible] + 1 [Speculative]
- §5 Open questions: 3 falsifier definitions (F1 central, F2 advisory, F3 mult-1-regression) + 2 RESEARCH_NEEDED items (F=11 T:E_1 mult-2 construction; F=12 multiplicity audit)
- §6 Directive for implementer: 9-step algorithm with §2.A projector-orbit recipe
- §7 Metrics block: theorist's own metrics (lines 178–191)

Key theorist findings (verbatim where possible):
- F=9 T:A is the lowest-F multiplicity-≥2 odd-F polyhedral case in the existing test set; F=11 T:A is multiplicity 1 (not a second test case).
- Current `find_invariant_vector` (script lines 164–174) returns a single seed-dependent unit vector from a 2-dim invariant subspace.
- The failing proof step is `||F_a ζ||² = F(F+1)/3` (Schur isotropy) which holds automatically at multiplicity 1 but NOT for generic representatives at multiplicity 2.
- §2.A predicted recovery: $\bar\beta_0^{(c_0)} = 1/(2F+1) = 1/19$ exact, computed as `Tr[Π_S · (ρ_inv ⊗ ρ_inv)]` where `ρ_inv = (1/m_rep) · Σ_i |ζ_i⟩⟨ζ_i|` is the density matrix on the multiplicity space.
- Strict-generalization argument (§2.5): at mult 1, ρ_inv reduces to rank-1 `|ζ⟩⟨ζ|`, so the 29-channel regression remains intact.

Falsifier contract (theorist §5 + §6):
- F1 central: `|β_0 − 1/19| < 1e-13` → CORROBORATE; ∈ [1e-13, 1e-6] → INCONCLUSIVE; > 1e-6 → REFUTED
- F2 advisory: seed-spread across 10 RNG seeds < 1e-13
- F3 regression: existing 29-channel test must remain 29/29 PASS

## 7. Issues / deviations

None. All 8 success_criteria passed with exit_code 0; precondition_check passed; no julia executions; no new files in scripts/manuscript/ or src/; no commits to main; seed.md priority-0 on edh-matsui not violated.

The director's §6 brief explicitly authorized a `<RESEARCH_NEEDED>` honesty clause if theorist found a different diagnosis (§6 of theorist's brief). Theorist did NOT invoke that clause — the multiplicity-2 hypothesis was corroborated by source-file reading (theorist §2.0 + §2.3 explicitly identify the small-deviation magnitude as consistent with the multiplicity-2 mixing diagnosis, and rule out numerical conditioning via Schur isotropy at 6e-14 being already at machine precision). No honesty-clause routing required.

One theorist [Speculative] tag flagged: the §2.B existence-of-Schur-isotropic-basis argument relies on a rank-2 traceless symmetric tensor having no trivial H-irrep component for H = T. Theorist asserts this by representation-theory (rank-2 traceless decomposes as E + T₂ under O; under T, neither subduces a trivial); this is a verifiable group-theory claim, deferred to next-stage critic if it lands on Falsify routing. Not a blocker for T114 Hypothesize.

## 8. Falsification check

Director §6 success_criteria are the validation gate for T114 Hypothesize (not the science F1/F2/F3 falsifiers themselves — those will be tested at next Execute stage when implementer writes `scripts/manuscript/f9_TA_mult2_schur_restore.jl`).

| Criterion | Tested | Result |
|---|---|---|
| theorist-output-exists | yes | PASS (exit 0) |
| theorist-output-has-schur-isotropic-section | yes | PASS (exit 0) |
| theorist-output-has-projector-orbit-section | yes | PASS (exit 0) |
| theorist-output-states-prediction | yes | PASS (exit 0) |
| theorist-output-has-falsifier-contract | yes | PASS (exit 0) |
| theorist-output-mentions-tolerance | yes | PASS (exit 0) |
| no-julia-side-effects-in-runs | yes | PASS (exit 0) — `scripts/manuscript/f9_TA_mult2_schur_restore.jl` ABSENT as required |
| seed-md-priority-0-still-held-edh-matsui-not-violated | yes | PASS (exit 0) — `edh-eu151-vortex-vs-matsui-science-2026` still pinned in seed.md |

Per director's investigation_update block:
- `if_success_advance_to_stage`: "Test" → T115 director routes to implementer for Execute stage (julia run of `f9_TA_mult2_schur_restore.jl`)
- `if_success_tier_becomes`: 1.5
- `if_success_falsifier_update`: F1 stays PENDING (T114 only declares contract; actual β_0 measurement runs at next Execute stage)

Eight-of-eight PASS → success branch of investigation_update is taken. T115 may advance investigation to Test stage at its discretion (subject to seed.md priority-0 routing; if anko runs the wrapper between T114 and T115, edh-matsui critic re-audit takes precedence per director failure_modes entry #6 "scientific_progress_unblocked").
