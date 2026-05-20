---
turn: 92
subagent: theorist
workload_class: theorist
experiment_kind: text_only
directive_label: sign-pattern-lemma1-tier3-T92-hypothesize-F2-cyclic-cg-derivation
depends_on: [director/turn_92, theorist/turn_92, research/turn_91]
produces: "Shim mirroring theorist §11 Metrics into §4 so judge.py contract evaluation can run. Full derivation in runs/_loop/theorist/turn_92.md."
---

# Turn 92 — Sim shim (theorist-routed Hypothesize-stage turn)

This turn was dispatched by the director (route (a) theorist) as a verify-claim
flow `Hypothesize` stage closure. There is no implementer phase: theorist
directly produced the CG-algebra derivation, Lemma 1 application, and
falsifier list as the deliverable.

The director's §6 declarative contract (`runs/_loop/director/turn_92.md` §6)
specifies success_criteria that judge.py evaluates against the theorist's
§11 Metrics block. To keep the judge.py invocation pattern uniform (it
reads sim/turn_${N}.md §4), this file mirrors theorist §11 verbatim into
the canonical §4 Metrics location below.

## 1. Result narrative (one-paragraph)

Theorist independently re-derived β_S^(c_0) at F=2 cyclic-tetrahedral A_1
via CG algebra (singlet projector for S=0, direct CG matrix element ⟨2,0|ζ⊗ζ⟩
for S=2, and complement-by-normalization for S=4). The derivation refutes
T91 researcher's structural triangulation at S=2 and S=4: the corrected
β_S^(c_0) is (1/5, 2/7, 18/35), not (1/5, 0, 4/5). Root cause: T91 §3.3
conflated the c_1·|⟨F⟩|² mean-field term (= 0 for cyclic since ⟨F⟩=0) with
the β_2^(c_0) channel projector weight (≠ 0). Applying the Lemma 1
General-S closed-form prefactor (S(S+1)−2F(F+1))/(2F(F+1)) at F=2 yields
β_S^(λ_spin) = (−1/5, −1/7, +12/35). The S=0 endpoint cross-anchor
β_0^(λ_spin) = −1/(2F+1) = −1/5 matches, and Σ_S β_S^(λ_spin) = 0 (sum
identity) is preserved with the corrected values (T91's values violated
this identity, giving +1/3). Provisional verdict
HYPOTHESIS_DERIVATION_ERROR (T91_TRIANGULATION_ERROR class) — the
corrected Hypothesize is ready for T93 critic Update independent
re-derivation via 6j-symbol path.

## 2. Files touched

- `runs/_loop/theorist/turn_92.md` (created by theorist subagent)
- `runs/_loop/sim/turn_92.md` (this shim, created by orchestrator)

No src/, manuscript, state.json, .claude/agents/, or scripts/ files modified.
No julia executed. No WebFetch performed.

## 3. Reproduction

Read `runs/_loop/theorist/turn_92.md` §3 for the CG derivation and §4 for
the Lemma 1 application. Appendix A self-checks each numerical value;
Appendix B addresses the polar/cyclic mean-field degeneracy.

## 4. Metrics

```json
{
  "experiment_kind": "text_only",
  "investigation_kind": "physics",
  "src_files_modified": 0,
  "new_analysis_scripts_written": 0,
  "agents_md_files_modified": 0,
  "patterns_yaml_modified": false,
  "state_json_modified": false,
  "manuscript_edited": false,
  "src_edited": false,
  "julia_executed": false,
  "webfetch_used": false,
  "investigation_id": "sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18",
  "stage_advancing_to": "Hypothesize",
  "flow_template": "verify-claim",
  "f2_cyclic_canonical_form_stated": true,
  "cg_derived_beta_s_c0_S0": 0.2,
  "cg_derived_beta_s_c0_S2": 0.2857142857142857,
  "cg_derived_beta_s_c0_S4": 0.5142857142857142,
  "cg_derivation_matches_t91_triangulation": false,
  "lemma1_prefactor_S0_at_F2": -1.0,
  "lemma1_prefactor_S2_at_F2": -0.5,
  "lemma1_prefactor_S4_at_F2": 0.6666666666666666,
  "predicted_beta_s_lambda_spin_S0": -0.2,
  "predicted_beta_s_lambda_spin_S2": -0.14285714285714285,
  "predicted_beta_s_lambda_spin_S4": 0.34285714285714286,
  "s0_endpoint_cross_anchor_match": true,
  "sign_boundary_S_bd_at_F2_evaluated": 3.4641016151377544,
  "sign_pattern_h3_consistent": true,
  "bogoliubov_cross_check_attempted": true,
  "bogoliubov_cross_check_completed": true,
  "convention_reconciliation_completed": true,
  "formal_claim_h1_stated": true,
  "formal_claim_h2_stated": true,
  "formal_claim_h3_stated": true,
  "falsifiers_count": 4,
  "falsifier_ids_list": [
    "F1_6j_symbol_re_derivation",
    "F2_lemma1_prefactor_structural_F2",
    "F3_sum_lambda_zero_identity",
    "F4_bogoliubov_stiffness_cross_check_optional"
  ],
  "each_falsifier_has_concrete_threshold": true,
  "provisional_verdict": "HYPOTHESIS_DERIVATION_ERROR",
  "recommended_t93_critic_scope_described": true,
  "references_cited_count": 6,
  "references_cited_list": [
    "runs/_loop/research/turn_91.md (T91 researcher_shallow F=2 cyclic triangulation; REFUTED at S=2 and S=4 entries)",
    "runs/_loop/director/turn_92.md (T92 dispatch brief and pre-routing)",
    "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md (Lemma 1 General-S closed-form formula + 26-channel verification at F=3/4/6/8/10)",
    "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_L1_v2_BdG_signs.md (rigorous S=0 endpoint proof: \u03b2_0^(\u03bb) = -1/(2F+1))",
    "scripts/manuscript/lemma1_general_S_verification.jl (26/26 PASS regression baseline at F=3/4/6/8/10; F=2 case absent)",
    "Kawaguchi & Ueda 2012 (arXiv:1001.2072) \u00a72 c_0/c_1/c_2 convention used in \u00a75 cross-check (KU2012 \u00a73 PDF binary blocked verbatim extraction, per T91 \u00a73.1)"
  ],
  "no_invention": true,
  "a00_calculation_verified": true,
  "projector_normalization_verified": true,
  "prior_lemma1_verification_at_F345610_referenced": true,
  "t91_triangulation_error_class": "channel_weight_vs_meanfield_term_conflation",
  "t91_error_at_S2_T91_value": 0.0,
  "t91_error_at_S2_T92_value": 0.2857142857142857,
  "t91_error_at_S4_T91_value": 0.8,
  "t91_error_at_S4_T92_value": 0.5142857142857142,
  "sum_lambda_zero_identity_T92": 0.0,
  "sum_lambda_zero_identity_T91": 0.3333333333333333,
  "tier_current_estimated": 2.7,
  "tier_target": 3,
  "tests_passed": true,
  "warnings": [],
  "physical_red_flags": [],
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 13533904,
    "total": 13533904,
    "effective_full_rate": 1990718,
    "breakdown": {
      "input_fresh": 7815,
      "cache_creation": 427751,
      "cache_read": 13070097,
      "output": 28241
    },
    "n_messages": 88,
    "n_message_starts": 88
  }
}
```
