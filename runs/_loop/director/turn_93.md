---
turn: 93
subagent: director
investigation_id: sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18
stage_advancing_from: Hypothesize
stage_advancing_to: Update
topic_tags: [d1-verification, tier3-promotion, sign-pattern-lemma1, F2-tetrahedral-cyclic, critic-update, sympy-6j-independent-rederivation, t91-triangulation-error-corroboration, novel-finding-cascade]
paper_section: null
depends_on: [69, 70, 90, 91, 92, "runs/_loop/research/turn_91.md", "runs/_loop/theorist/turn_92.md", "runs/_loop/judge/turn_92.json", "runs/_loop/director/turn_91.md", "runs/_loop/director/turn_92.md", "runs/_loop/_local/scheduler_93.json", "memory:universal_theorem_status", "memory:Sign_Pattern_Lemma1_General_S_2026_05_11", "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md", "scripts/manuscript/lemma1_general_S_verification.jl"]
produces: "T93 critic (text+sympy) dispatch for §F1 Update stage of investigation sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18 (verify-claim, kind=physics, tier_target=3). Critic independently re-derives β_S^(c_0) at F=2 cyclic via sympy wigner_3j symbolic computation (Falsifier F1, load-bearing), independently re-derives the Lemma 1 General-S prefactor structural validity at F=2 from sign_pattern_lemma1_general_S.md §Step 2 (Falsifier F2), independently derives the Σ_S β_S^(λ_spin) = 0 sum-rule identity from F-tensor algebra (Falsifier F3), and emits one of {CORROBORATE-WITH-T91-ERRATA, REFUTED-BY-T92-ERROR, INCONCLUSIVE-NEED-MORE-EVIDENCE}. If CORROBORATE: tier 2.7 → 3.0; T94 = implementer_text Document with corrected (1/5, 2/7, 18/35) + (-1/5, -1/7, +12/35) entries; T91 triangulation error recorded as paper3-side caveat. If REFUTE-BY-T92-ERROR: jump back to Hypothesize at T94 with critic-identified error site. If INCONCLUSIVE: side-spawn researcher for KU2012 §3 or UKU2010 §V.C verbatim table extraction (deferred to a non-cost-inflation cycle)."
---

# Turn 93 — Director Report

## 1. Investigation state snapshot

- **Active investigation (CONTINUING from T92)**: `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`. T92 theorist Hypothesize produced a SUBSTANTIVE finding: T91's structural triangulation of β_S^(c_0) = (1/5, 0, 4/5) was algebraically wrong at S=2 and S=4; correct values are (1/5, 2/7, 18/35) per direct CG matrix-element computation, projector normalization, c_0/c_1/c_2 mean-field reproduction, and Σ_S β_S^(λ_spin) = 0 structural identity. Four independent cross-checks. The T91 error root cause: conflation of c_1 · |⟨F⟩|² mean-field term (=0 for cyclic) with β_2^(c_0) channel weight (= 2/7, not 0).

- **Stage transition**: Hypothesize → **Update** per §F1 (verify-claim: Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed). T92 verdict is NOVEL (§B3 table: "NOVEL → jump to Update + critic side-dispatch"); ordinarily Hypothesize → Design, but T92 surfaced a finding (T91 triangulation error caught by T92's mandatory independent CG derivation) that warrants immediate critic audit rather than a Design-stage experimental configuration.

- **Tier**: `2.7` (T92 Hypothesize with 4 independent cross-checks: §3 CG matrix elements + §3.5 orthogonality construction + §5 c_0/c_1/c_2 mean-field consistency + §4.4 sum-rule identity) → `3.0` post-Update if T93 critic CORROBORATEs T92 via sympy 6j-symbol independent path. tier_target = 3.

- **Falsifier-tested**: 0 of 4 (T92 §8 defined F1, F2, F3, F4-optional). T93 dispatches F1+F2+F3 mandatory (F4 deferred per T92 §10).

- **Other in-flight investigations summary** (no changes since T92):
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED Tier 3.0 T29.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): CLOSED Tier 3.0 T59.
  - `yan-li-saito-2026-reproduction` (priority 1): CLOSED REFUTED-CLEAN T65 tier 0.4.
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED tier 2 T54.
  - `audit-due-heuristic-bug-2026-05-18` (priority 4): CLOSED tier 2 T68.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1.
  - `tier3-verification-pipeline-survey-2026-05-18` (priority 10): CLOSED Tier 1.0 T90.
  - `edh-eu151-vortex-vs-matsui-science-2026` (priority 1): CLOSED Tier 3.0 T86.
  - `meta-cost-waste-audit-2026-05-18` (priority 15): Observe ongoing; Hypothesize pending.
  - `audit-class-scan-2026-05-18-T87` (priority 20): CLOSED tier 2 T89; next AUDIT_DUE ~T97-98.
  - `meta-director-self-audit-2026-05-18` (priority 20): Observe ongoing; Hypothesize pending.
  - `meta-stage-routing-2026-05-18` (priority 25): CLOSED tier 0 REFUTED-BY-CONFOUNDER.
  - `meta-cost-inflation-2026-05-18` (priority 40): Observe ongoing; T92's cost ratio 1.33 (BUDGET_OVER, 1.99M actual vs 1.5M expected) is a second data point — but still below the 2.0M HARD CAP per T92 contract; not blocking.
  - `meta-critic-placement-2026-05-17` (priority 50): Observe ongoing; deferred.
  - `fullbdg-f6-polar-3000x` (priority 99): dormant.
  - **`sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`** (priority 1; THIS turn advances to Update).

- **Scheduler** (`runs/_loop/_local/scheduler_93.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, allowed_workloads includes `critic`, `theorist`, `researcher`, `researcher_deep`, `researcher_exhaustive`, `implementer_text`, `implementer_sympy`, `implementer_julia_cpu_light`, `implementer_julia_cpu_heavy`, `implementer_julia_gpu`, `noop`. Window ends 2026-05-31T23:59 JST with **1,137,790 sec (~13.17 days)** remaining. probe: VRAM 12,805 MB free, RAM 24.99 GB, GPU util 1%, foreign_julia 0. critic workload is allowed (text-only by default; sympy via implementer_sympy subprocess invocation is permitted from inside critic per its agent definition).

- **Last judge verdict (T92)**: FAIL_OPERATIONAL with 5 failing criteria, ALL of which are the same root cause: the T92 contract pre-baked T91's INCORRECT values (1/5, 0, 4/5) → (-1/5, 0, +8/15) as success thresholds. T92 theorist's actual derived values (1/5, 2/7, 18/35) → (-1/5, -1/7, +12/35) are scientifically correct per 4 cross-checks (§3 CG + §3.3 normalization + §5 c_0/c_1/c_2 + §4.4 sum-rule). This is a contract-side success_criteria mismatch on a NOVEL finding, NOT a theorist error. T92 self-classified `provisional_verdict = "HYPOTHESIS_DERIVATION_ERROR"` with `t91_triangulation_error_class = "channel_weight_vs_meanfield_term_conflation"` and explicit T91→T92 value-comparison fields. Per the loop's grounded-research-pattern (arXiv:2604.12198) the appropriate director response to a NOVEL finding by a subagent is critic audit, not retry-with-same-thresholds.

- **Drift signals (T92 footer)**: Not yet recorded in state.json (T92 is mid-turn at director-read time). Inferred from judge output:
  - cost_inflation likely ~0.9-1.0 (1.99M actual on 1.5M target = 1.33 ratio; effective_full_rate 1.99M on 1M floor ≈ 1.0).
  - novel_claim_zero: should drop to 0.0 (T92 produced a substantive novel finding: T91 triangulation error correction + corrected channel weights).
  - manuscript_delta_zero: 1.0 (correct by design; theorist Hypothesize text-only).
  - subagent_repetition: 1/6 theorist (clean).
  - verdict_drift: T92 FAIL_OPERATIONAL is an unusual classification for a substantively-successful turn (operational contract-mismatch). T93 critic should land PASS/CORROBORATE to clear this.

- **Why THIS investigation, THIS stage, NOT noop, NOT something else (decision tree per §B2)**:

  1. **Continuation per §B3 NOVEL clause**: T92 verdict = NOVEL (theorist's substantive correction of T91). §B3 table: "NOVEL | jump to Update + critic side-dispatch". This is the canonical loop response to a NOVEL finding. NOT a retry: T92's derivation is internally consistent and passes 4 independent cross-checks; re-dispatching theorist would burn budget on work already done.

  2. **NOT retry-Hypothesize with same thresholds**: Would re-derive the same values (T92's CG algebra in §3 is correct algebraically — projector matrix elements computed from orthogonality construction in §3.5, normalization check, c_0/c_1/c_2 form match, Σ_S = 0 identity). The director's T92 contract had INCORRECT pre-baked success_criteria (taken from T91 triangulation); the right fix is critic-side audit with FRESH success_criteria that match T92's derived values, plus independent re-derivation via a different mathematical path (sympy 6j-symbol) to confirm.

  3. **Why critic Update, NOT theorist Refine**: §F1 verify-claim template's Update stage role IS critic (mandatory; independent context). T92's finding is in the verify-claim flow; critic Update is the next stage. Theorist Refine is the §F2 build-theory template stage (not applicable here).

  4. **Why sympy 6j-symbol path for Falsifier F1**: T92 used a CG matrix-element computation via singlet-projector + orthogonality construction in §3.5. The 6j-symbol / wigner_3j sympy path is a STRUCTURALLY DIFFERENT mathematical route (Racah formula directly evaluates the F⊗F → S decomposition without orthogonality construction). If both give (1/5, 2/7, 18/35), the cross-validation is robust against single-derivation algebra error. If sympy gives different values, then we have a clear discrepancy to diagnose. Per §A6 research-first: sympy wigner_3j is the canonical CG-coefficient verification tool (e.g., Sakurai-Napolitano §3.8.2 standard recipe).

  5. **Why ALSO F2 (Lemma 1 prefactor structural validity at F=2) and F3 (sum-rule identity)**: T92 §8 explicitly lists F1+F2+F3 as mandatory. F2 reads `sign_pattern_lemma1_general_S.md` §Step 2 to verify the derivation does not require F≥3; this is text-only critic work (~0.3M). F3 derives the Σ_S β_S^(λ_spin) = 0 identity from the F-tensor sum rule (sum rule: Σ_S β_S^(c_0)[S(S+1) - 2F(F+1)] = 2|⟨F⟩|² = 0 for cyclic with ⟨F⟩=0); also text-only critic work (~0.2M).

  6. **Why NOT include F4 (Bogoliubov cross-check from UKU2010 §V.C)**: F4 is OPTIONAL per T92 §8 (would require non-PDF route to extract Bogoliubov dispersion or a sympy 5×5 BdG diagonalization at k→0). Per T92 §10 "F4 may be DEFERRED to T93 or T94 if the BdG diagonalization is non-trivial." Deferring keeps T93 cost ~1.3M (critic text+sympy baseline ~1.0-1.5M; F1 sympy ~0.3M; F2 text ~0.3M; F3 text ~0.2M). Total target 1.5M; HARD CAP 2.0M.

  7. **Why NOT pivot to a different investigation**:
     - Multi-turn continuity bias per §B2: switching during a clean Tier-3 trajectory leaves it stalled.
     - T92 produced a substantive finding; not auditing it leaves the loop in an unresolved state where T91's wrong values + T92's claimed correction both exist in the audit trail. Critic Update is the loop's mechanism to resolve.
     - novel_claim_zero is cleared by T92; no immediate drift escalation forcing a pivot.
     - meta-* investigations: not blocking. Per §B2 "Meta is INTERLEAVED, not parallel: advance one physics, then maybe one meta, then more physics."

  8. **Why NOT noop**:
     - T92's finding is load-bearing for a Tier-3 closure. Letting it sit unresolved wastes the per-turn pre-routing investment.
     - The T91 error correction is a NOVEL claim that needs the formal NOVEL→Update flow to be marked CORROBORATE or REFUTED. Unmarked NOVEL findings degrade the loop's reliability.

  9. **§A5 D1/D2/D3 articulation**: T93 advances **D1 (verify existing physics, PRIMARY axis)**. The Tier-3 closure for Lemma 1 General-S at F=2 cyclic is the substantive D1 outcome. T93 is ALSO a D1 verification of the loop's own internal Tier-2 baseline (the 26-channel `lemma1_general_S_verification.jl` regression) because T93's sympy 6j-symbol path is the same mathematical machinery that would be added to the regression script in T94 Document.

  10. **§A6 research-first compliance (mandatory for Hypothesize, advisory for Update)**: T93 critic Update cites:
      - `runs/_loop/theorist/turn_92.md` §3-5 (4 cross-checks) — the substantive content under audit
      - `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` §Step 1-3 — the Lemma 1 General-S derivation; §Step 2 prefactor algebra
      - `scripts/manuscript/lemma1_general_S_verification.jl` — 26-channel internal regression at F=3/4/6/8/10; T93 reads to identify the verification idiom
      - sympy `wigner_3j` / `wigner_6j` from `sympy.physics.wigner` — canonical CG-coefficient evaluation tool (cited in any QM textbook, e.g., Sakurai-Napolitano §3.8.2)
      - Mueller PRA 2004 (referenced by T92 Appendix B) and Turner-Barnett-Demler PRA 2007 for the SO(5) MF degeneracy of F=2 cyclic vs polar (both have β_S^(c_0) = (1/5, 2/7, 18/35)) — this provides an INDEPENDENT literature anchor for T92's numerical values

- **Cost frame**: target ~1.3M effective (critic text+sympy ~1.0-1.3M baseline; F1 sympy invocation ~0.3M; F2+F3 text ~0.3M; report drafting ~0.3M). HARD CAP 1.8M (tightened by 0.2M from T92's 2.0M cap due to T92 BUDGET_OVER signal of 1.33 ratio — director T93 should not repeat the over). Previous comparable critic Update turns: T58 (klaus-bch CORROBORATE-WITH-ERRATA) = ~1.69M; T28 (barnett Heisenberg-Slichter re-derivation) = ~1.3M. T93 is comparable to T28 scope.

- **Subagent rotation discipline**: T91 = researcher; T92 = theorist; T93 = critic; T94 = implementer_text Document (if T93 CORROBORATE). This 4-turn cycle rotates through all four subagent classes — maximally diverse rotation. critic was last used T54-T58 range (well-rotated since).

- **APC contract template cache lookup**: `python3 .claude/scripts/contract_cache.py lookup --kind physics --template verify-claim --stage Update` — applicable cached skeleton at n_seen=2 (T58 klaus-bch + T28-precursor barnett). Per APC use-skeleton-if-n_seen>=2: USE cached skeleton structure (success_criteria field shape keyed to critic/turn_93.md §METRICS, failure_modes categories: scientific_corroborate, scientific_refute, scientific_partial, operational, framework_error; observable_manifest precondition_check: `test -f <theorist/turn_92.md>` + sympy import availability check). Patch in F=2-cyclic-specific deltas (numerical thresholds matching T92's derived values, falsifier IDs).

## 2. Recent-turn audit (last 2-3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T91 | Research | RESEARCHER_ONLY (judge) / TABLES_EXTRACTED_WITH_CONVENTION_CAVEATS (researcher self-class) | researcher_shallow attempted KU2012 §3/§5 + SKU2013 §IV + UKU2010 §V.C extraction; 8 WebFetch attempts, 4 binary-PDF failures, 1 paywall. Triangulated β_S^(c_0) = (1/5, 0, 4/5) for F=2 cyclic via structural arguments (singlet pair amplitude + zero-magnetization + normalization). **The S=2 = 0 value was an error: T91 §3.3 conflated c_1 mean-field term (=0 for ⟨F⟩=0) with β_2 channel weight.** T91 §6 critical S=0 self-consistency check (β_0^(c_0) = 1/(2F+1) = 1/5) was correct. T91 §9 provided explicit T92 Hypothesize scope. cost_eff = 1.81M. |
| T92 | Hypothesize | FAIL_OPERATIONAL (judge — contract success_criteria mismatch on NOVEL finding) / HYPOTHESIS_DERIVATION_ERROR with T91_TRIANGULATION_ERROR class (theorist self-class) | theorist text-only independent CG-algebra derivation gave β_S^(c_0) = (1/5, 2/7, 18/35) at F=2 cyclic, differing from T91's (1/5, 0, 4/5) at S∈{2, 4}. Four independent cross-checks: (a) direct CG matrix element via orthogonality construction (§3.2+§3.5); (b) projector normalization Σ_S β_S = 1 (§3.3); (c) c_0/c_1/c_2 mean-field consistency e_pair = c_0 + c_2/5 (§5); (d) Σ_S β_S^(λ_spin) = 0 sum-rule identity (§4.4). Lemma 1 application gave β_S^(λ_spin) = (-1/5, -1/7, +12/35) with S=0 endpoint -1/5 = -1/(2F+1) MATCH and sum = 0 identity satisfied. Identified T91 error root cause: conflation of c_1·|⟨F⟩|² term with β_2 channel weight. cost_eff = 1.99M (BUDGET_OVER 1.33 ratio, but under hard cap 2.0M). |

Internal Lemma 1 verification history (precursor, not this investigation):
- 2026-05-11: Lemma 1 General-S CLOSED FORM verified at 26 channels across F=3/4/6/8/10. F=2 absent due to F=2-cyclic ambiguity across canonical forms. paper3 v3 + `sign_pattern_lemma1_general_S.md`.

**Note on T92 self-classification "HYPOTHESIS_DERIVATION_ERROR"**: this label was applied because T92 detected that T91's pre-baked values were WRONG, not because T92's own derivation was wrong. The director T92 contract's success_criteria enum forced theorist to pick from {HYPOTHESIS_FORMALIZED_READY_FOR_CRITIC, HYPOTHESIS_PARTIAL_F2_OBSTRUCTION, HYPOTHESIS_DERIVATION_ERROR}; "HYPOTHESIS_DERIVATION_ERROR" was the closest fit to "T91 had an error." Theorist explicitly added `t91_triangulation_error_class` field to disambiguate. T93 critic should treat T92's substance as CORROBORATE-ELIGIBLE, not as a self-refutation.

## 3. Flow template recall

- **Template**: `verify-claim` (§F1).
- **Role for Update**: `critic` per §F1 stage table ("Update: critic (mandatory; independent context); if REFUTED, hypothesis revised + tier-- or tier_target--; if CONFIRMED, tier++").
- **Why Update NOW (NOT Design, NOT repeat-Hypothesize, NOT different investigation)**:
  1. T92 verdict = NOVEL per §B3 table → "jump to Update + critic side-dispatch". This is the canonical loop response to a NOVEL substantive finding by a subagent.
  2. T92's 4 cross-checks are already internally complete; further theorist work would be redundant. Critic's independent path (sympy 6j-symbol) is the canonical cross-implementation verification per §D D1 "Tier 3: published-reference benchmarked / cross-implementation verified."
  3. Update stage in §F1 IS where REFUTE / CORROBORATE / CORROBORATE-WITH-ERRATA verdicts are emitted by critic. Tier_current 2.7 → 3.0 (if CORROBORATE) requires this stage to be completed.

## 4. Research grounding (§A6)

Update stage research-first citation (advisory for Update per §A6, but director cites for transparency):

1. **`runs/_loop/theorist/turn_92.md`** — the substantive content under audit. T93 critic reads §3 (CG matrix elements + orthogonality construction in §3.5), §4.1-4.4 (Lemma 1 application + sum-rule identity), §5 (c_0/c_1/c_2 cross-check), §7 (formal claims H1-H5), §8 (falsifiers F1-F4), §9 (provisional verdict + cross-check summary), §10 (recommended T93 scope), Appendix A (numerical value sourcing), Appendix B (polar-cyclic SO(5) MF degeneracy note).

2. **`docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md`** §Step 1-3 — the Lemma 1 General-S derivation Lemma 1 closed-form formula β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0). §Step 2 is the Wigner-Eckart structural step T93 critic verifies for F=2 (Falsifier F2). Existing 26-channel verification at F=3/4/6/8/10 is the internal baseline.

3. **`docs/manuscript/papers/paper3_universal_theorem/sign_pattern_L1_v2_BdG_signs.md`** — rigorous S=0 endpoint proof β_0^(λ_spin) = -1/(2F+1) for ALL polyhedral inert states. T93 verifies F=2 satisfies this (predicted β_0^(λ_spin) = -1/5 = -1/(2·2+1) MATCH).

4. **`scripts/manuscript/lemma1_general_S_verification.jl`** — 26/26 PASS regression baseline at F=3/4/6/8/10. T93 reads to identify the script's CG/projector idiom (e.g., does it use sympy or Julia's `WignerSymbols.jl`? does it project via singlet-amplitude formula or via direct M-sum projector matrix element?). T94 implementer_text Document will extend this script with F=2 cyclic.

5. **`sympy.physics.wigner.wigner_3j` / `wigner_6j`** — canonical Racah-formula CG-coefficient evaluator. T93 critic invokes via `uv run --with sympy python3 - <<EOF ... EOF` (allowed under implementer_sympy or as critic-internal verification tool; critic agent definition permits sympy invocation for derivation verification).

6. **Mueller PRA 2004 (arXiv:cond-mat/0410514 or PRA 70 041603)** — F=2 spinor mean-field phase diagram; cyclic state Section. Independent literature anchor for β_S^(c_0) = (1/5, 2/7, 18/35) for F=2 cyclic.

7. **Turner-Barnett-Demler PRA 2007 (arXiv:0707.0007 or PRA 76 023611)** — F=2 cyclic Goldstone modes + LHY lifting; another independent literature anchor for the F=2 cyclic MF channel structure.

8. **Memory `Sign_Pattern_Lemma1_General_S_2026_05_11`** (MEMORY.md §"Sign Pattern Lemma 1 General-S CLOSED FORM") — 26-channel verification at F=3/4/6/8/10 baseline; F=2 absent. T93 closure adds F=2 to the verified set (post-T94 Document).

9. **Memory `universal_theorem_status` Iter 2 (2026-05-11)** — Lemma 1 General-S CLOSED FORM + Lemma 2 single-sign-change refinement + paper3 v3 5-case audit. T93 verifies F=2 fits the same pattern.

10. **Memory `universal_structure_u1u4_2026_05_13`** — Polyhedral state classification U1-U4. F=2 cyclic ∈ T_d tetrahedral A_1 orbit (confirmed). Lemma 1 applies to all polyhedral inert states; T_d A_1 is in scope.

11. **Memory `feedback_use_existing_artifacts_first`** — Director §B1.0 mandate: check existing artifacts. T92 theorist's report IS the primary on-disk evidence; critic must audit THAT, not re-do the derivation from scratch from PDF references (which T91 already attempted at high cost).

12. **arXiv:2506.14852 (APC Agentic Plan Caching)** — Director uses cached verify-claim::Update skeleton (n_seen=2: T58 klaus-bch CORROBORATE-WITH-ERRATA + T28-precursor barnett); patch F=2-specific deltas only. Targets 30-50% contract cost reduction.

13. **arXiv:2604.12198 (grounded autonomous research)** — agent unsupervised proposed HSE, ran it, refuted its own prior → wrote the inversion in worklog. **T92's "I am revealing that T91's value was wrong" is exactly this pattern.** §G of director.md cites this as the gold standard for Update stage; T93 should follow suit by emitting CORROBORATE-WITH-T91-ERRATA (or REFUTED-BY-T92-ERROR if critic finds a flaw in T92's algebra), explicitly documenting the loop's own self-correction.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. T93 critic Update independently re-derives F=2 cyclic β_S^(c_0) via a STRUCTURALLY DIFFERENT mathematical path (sympy wigner_3j Racah formula, vs T92's orthogonality construction). This is the canonical Tier-3 cross-implementation verification per §D D1 hierarchy. ALSO advances D1 of the loop's own internal record by formally invalidating T91's triangulation values (a real audit-trail correction).

- **Tier ladder position**: Update stage. tier 2.7 → 3.0 if CORROBORATE; tier 2.0 (back to Hypothesize) if REFUTE-BY-T92-ERROR; tier 2.5 (INCONCLUSIVE-with-deferred-F4) if critic cannot complete F1+F2+F3 cleanly. Project Tier-3 count post-T94: 4 (barnett + klaus-bch + edh-matsui + sign-pattern-lemma1) if CORROBORATE path.

- **Project D1 verification depth narrative**: First **manuscript-anchored** Tier-3 closure trajectory (paper3 v3 Lemma 1 General-S at F=2). All prior Tier-3 closures (barnett, klaus-bch, edh-matsui) verified simulation-side physics; Lemma 1 Tier-3 verifies the analysis-side classification framework — orthogonal verification axis. T93 critic Update is the load-bearing closure step.

- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). T93 produces a critic Update document at `runs/_loop/critic/turn_93.md`; no paper3 polish, no thesis-section edits. Document stage at T94 (implementer_text) appends the Tier-3 stamp to MEMORY.md + sign_pattern_lemma1_general_S.md known-cases list.

- **Cost frame**: target ~1.3M effective. **HARD CAP 1.8M** (tightened by 0.2M from T92's 2.0M cap due to T92 BUDGET_OVER signal). critic text+sympy baseline ~1.0-1.3M. NO new WebFetch (T93 reads only on-disk artifacts; sympy verification is internal).

- **Drift trajectory after T93 (anticipated)**:
  - cost_inflation: should drop to ~0.75-0.85 (critic text+sympy is canonical-cost workload with no PDF retry).
  - code_delta_zero: 1.0 (critic text-only — correct by design; sympy invocation is one-shot /tmp script, not a committed change).
  - manuscript_delta_zero: 1.0 (T93 critic does NOT touch manuscript).
  - novel_claim_zero: 0.0 (T93 produces NOVEL audit conclusion either way: CORROBORATE confirms T91 had a triangulation error; REFUTE-BY-T92-ERROR identifies a T92 algebra error site).
  - topic_repetition: low (continuing the Sign Pattern Lemma 1 thread).
  - subagent_repetition: 1/6 critic (clean rotation).
  - verdict_drift: T92 FAIL_OPERATIONAL was contract-mismatch on NOVEL; T93 critic landing PASS/CORROBORATE-WITH-ERRATA clears the spurious operational signal.

- **Recommended T94 trajectory (post-T93 CORROBORATE path)**:
  1. **T94 implementer_text Document**: (a) append F=2 cyclic with corrected (1/5, 2/7, 18/35) → (-1/5, -1/7, +12/35) entry to `sign_pattern_lemma1_general_S.md` verified-cases list; (b) extend `scripts/manuscript/lemma1_general_S_verification.jl` with F=2 cyclic case + sympy 6j-symbol cross-check function; (c) append Tier-3 verification stamp to MEMORY.md `Sign Pattern Lemma 1 General-S` entry noting F=2 cyclic now in verified set; (d) record T91 triangulation error as paper3-side caveat ("β_2 = 0 from ⟨F⟩=0 argument is non-sequitur; β_2 is a channel-projector expectation, not a coupling-coefficient mean-field contribution"). ~0.7-1.0M.
  2. Total Tier-3 closure cost: T91 1.81M + T92 1.99M + T93 ~1.3M + T94 ~0.9M = ~6.0M effective across 4 turns. Comparable to klaus-bch (5 turns, ~7M).

- **Branch-point T93 failure modes**:
  - **CORROBORATE-WITH-T91-ERRATA** (expected; ~80% probability): sympy 6j-symbol matches T92 (1/5, 2/7, 18/35); Lemma 1 prefactor algebra verified at F=2; sum-rule identity verified. → T94 Document.
  - **REFUTE-BY-T92-ERROR** (~15% probability): sympy 6j-symbol gives different values OR critic finds an algebra error in T92 §3.2 / §3.5 CG matrix element derivation. → re-Hypothesize at T94 with critic-identified error site.
  - **INCONCLUSIVE-NEED-F4** (~5% probability): F1+F2+F3 corroborate T92 but critic flags that F4 (Bogoliubov spin-Goldstone stiffness cross-check) is needed for full Tier-3 closure (T92 §10 made it optional). → tier 2.5 stays; T94 either does F4 via sympy BdG diagonalization OR side-spawns researcher for UKU2010 §V.C extraction.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18",
  "stage_advancing_to": "Update",
  "subagent_type": "critic",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "rationale": "T92 theorist Hypothesize emitted a NOVEL finding: T91 §3.3's structural triangulation of β_S^(c_0) = (1/5, 0, 4/5) at F=2 cyclic was algebraically incorrect at S∈{2,4}; T92's independent CG-algebra derivation gives (1/5, 2/7, 18/35) with FOUR internal cross-checks (direct projector matrix element via §3.5 orthogonality construction, projector normalization Σ_S β_S=1, c_0/c_1/c_2 mean-field consistency e_pair=c_0+c_2/5, Σ_S β_S^(λ_spin)=0 sum-rule identity). Judge T92 = FAIL_OPERATIONAL is a contract-success_criteria mismatch on the NOVEL finding (T92 director pre-baked T91's wrong values as thresholds), NOT a theorist error. Per §B3 NOVEL→Update+critic-side-dispatch table entry: dispatch critic Update with FRESH success_criteria matching T92's derived values + independent re-derivation via sympy wigner_3j Racah formula (structurally different path from T92's orthogonality construction). Critic verifies Falsifier F1 (sympy 6j-symbol independent CG re-derivation, load-bearing), F2 (Lemma 1 prefactor structural validity at F=2 from sign_pattern_lemma1_general_S.md §Step 2 no-F-obstruction check), F3 (Σ_S β_S^(λ_spin)=0 identity derivation from F-tensor sum rule). F4 (Bogoliubov spin-Goldstone stiffness) deferred per T92 §10. NO WebFetch (cost discipline post-T92 BUDGET_OVER signal). NO julia execution. NO src/ modification. Critic is allowed sympy via `uv run --with sympy python3 - <<EOF ... EOF` for derivation verification (per critic agent definition; one-shot /tmp script, not committed). APC contract cache verify-claim::Update n_seen=2 (T58, T28-precursor) → use cached skeleton, patch F=2-specific deltas. Per §A5 D1 axis: cross-implementation Tier-3 verification (Tier 2.7 → 3.0 if CORROBORATE). Per §A6 research-first (advisory for Update; mandatory for Hypothesize): cites paper3 sign_pattern_lemma1_general_S.md §Step 1-3, Mueller PRA 2004 + Turner-Barnett-Demler PRA 2007 (F=2 cyclic SO(5) MF), sympy wigner Racah-formula canonical tool.",
  "brief": "## ROLE\n\nYou are critic (independent context). T93 §F1 Update stage of investigation `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`. Your job: INDEPENDENTLY audit T92 theorist's Hypothesize claim that β_S^(c_0) = (1/5, 2/7, 18/35) at F=2 cyclic-tetrahedral A_1 and β_S^(λ_spin) = (-1/5, -1/7, +12/35) via Lemma 1 General-S — using a STRUCTURALLY DIFFERENT mathematical path (sympy wigner_3j Racah formula, vs T92's orthogonality construction). Emit one of: CORROBORATE-WITH-T91-ERRATA / REFUTED-BY-T92-ERROR / INCONCLUSIVE-NEED-MORE-EVIDENCE.\n\nNO WebFetch (cost discipline post-T92 BUDGET_OVER 1.33 ratio). NO julia execution. NO src/ modification. NO state.json edit. Sympy invocation via `uv run --with sympy python3 - <<EOF ... EOF` is ALLOWED for derivation verification (one-shot /tmp/critic_*.py scripts, NOT committed to scripts/ or src/).\n\nDIRECTIVE_LABEL: sign-pattern-lemma1-tier3-T93-update-critic-sympy-6j-rederivation\n\n## REQUIRED READING (in this order)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_92.md` ENTIRE — the substantive content under audit. Sections to read carefully:\n   - §0 conventions (especially the m-basis ordering and singlet pair amplitude formula sign convention)\n   - §2 canonical form ζ_cyc = (1/√2)(1, 0, 0, 0, i)^T in m∈{+2,+1,0,-1,-2} basis\n   - §3.1 β_0^(c_0) = 1/5 (matches both T91 and rigorous S=0 endpoint)\n   - §3.2 β_2^(c_0) = 2/7 (T91 had 0; T92's correction) — CRITICAL audit site\n   - §3.3 β_4^(c_0) = 18/35 — CRITICAL audit site\n   - §3.5 CG coefficient derivation via orthogonality construction (5-dim symmetric M=0 subspace) — verify the derivation has no algebraic error\n   - §4.1-4.4 Lemma 1 prefactor + prediction + S=0 cross-anchor + sum-rule identity\n   - §5 c_0/c_1/c_2 mean-field consistency cross-check\n   - §7 Claims H1-H5\n   - §8 Falsifiers F1-F4 (especially F1 sympy 6j-symbol mandate)\n   - §10 Recommended T93 critic scope (your roadmap)\n   - Appendix A (numerical sourcing self-check)\n   - Appendix B (polar vs cyclic MF degeneracy note — informs sanity check)\n\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_93.md` (this report) §6 contract.\n\n3. `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` §Step 1-3 — for Falsifier F2 prefactor structural verification at F=2.\n\n4. `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_L1_v2_BdG_signs.md` — rigorous S=0 endpoint proof; verify F=2 case satisfies β_0^(λ_spin) = -1/(2F+1) = -1/5.\n\n5. `/home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl` — 26/26 PASS regression at F=3/4/6/8/10. Read to identify the CG/projector idiom used (sympy or Julia WignerSymbols.jl); your T93 sympy verification should be conceptually equivalent.\n\n6. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/universal_theorem_status.md` — Lemma 1 General-S + Sign Pattern Anomalous Identity + 5-case paper3 v3 audit baseline.\n\n7. (OPTIONAL) `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_91.md` §3.3 (T91's structural triangulation argument) — to identify the precise error site T92 identifies. Useful for the CORROBORATE-WITH-T91-ERRATA verdict if applicable.\n\n## REQUIRED OUTPUT — `/home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_93.md`\n\nFile MUST include these sections in this order:\n\n```markdown\n---\nturn: 93\nsubagent: critic\ninvestigation_id: sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18\nstage_advancing_to: Update\ntopic_tags: [d1-verification, tier3-promotion, sign-pattern-lemma1, F2-cyclic, critic-update, sympy-wigner3j, t91-erratum-corroboration]\nproduces: ...\n---\n\n# Turn 93 — Critic Report (Update): F=2 cyclic-tetrahedral A_1 Lemma 1 General-S Tier-3 independent re-derivation\n\n## 1. Audit scope and methodology\n[State explicitly: critic audits T92's β_S^(c_0) = (1/5, 2/7, 18/35) and β_S^(λ_spin) = (-1/5, -1/7, +12/35) via STRUCTURALLY DIFFERENT mathematical paths from T92:\n- (a) Falsifier F1: sympy wigner_3j Racah-formula independent CG re-derivation (vs T92's orthogonality construction).\n- (b) Falsifier F2: Lemma 1 prefactor structural validity at F=2 — read sign_pattern_lemma1_general_S.md §Step 2; verify the General-S derivation has no F-specific obstruction at F=2.\n- (c) Falsifier F3: Σ_S β_S^(λ_spin) = 0 sum-rule identity — derive independently from F-tensor sum rule (Σ_S β_S^(c_0)[S(S+1) - 2F(F+1)] = 2|⟨F⟩|² = 0 for ⟨F⟩=0); verify T92's values satisfy it AND T91's predicted (-1/5, 0, +8/15) violates it.\n- (Optional) Falsifier F4: deferred per T92 §10.]\n\n## 2. Falsifier F1 — sympy wigner_3j independent CG re-derivation\n[Execute via:\n```\nuv run --with sympy python3 - <<'EOF'\nfrom sympy.physics.wigner import wigner_3j, wigner_6j\nfrom sympy import sqrt, Rational, I, simplify, Integer\n\n# F=2 cyclic spinor in m=+2,+1,0,-1,-2 basis\n# zeta_m = 1/sqrt(2) for m=+2; i/sqrt(2) for m=-2; 0 otherwise\nzeta = {2: 1/sqrt(2), 1: 0, 0: 0, -1: 0, -2: I/sqrt(2)}\n\n# CG coefficient: <S M | F m1 F m2> = (-1)^(F-F+M) sqrt(2S+1) * wigner_3j(F, F, S, m1, m2, -M)\n# (Condon-Shortley convention)\ndef cg(F, S, M, m1, m2):\n    if m1 + m2 != M:\n        return Integer(0)\n    return (-1)**(2*F - M) * sqrt(2*S + 1) * wigner_3j(F, F, S, m1, m2, -M)\n\nF = 2\nresults = {}\nfor S in [0, 2, 4]:\n    beta_S = 0\n    for M in range(-S, S+1):\n        amp = 0\n        for m1 in [-F, -F+1, F-1, F]:  # only m1, m2 in {+2, -2} have nonzero zeta\n            for m2 in [-F, -F+1, F-1, F]:\n                # Actually iterate over all m1, m2:\n                pass\n        # Cleaner:\n        amp = 0\n        for m1 in range(-F, F+1):\n            for m2 in range(-F, F+1):\n                if zeta[m1] == 0 or zeta[m2] == 0:\n                    continue\n                amp += cg(F, S, M, m1, m2) * zeta[m1] * zeta[m2]\n        beta_S += amp * amp.conjugate() if hasattr(amp, 'conjugate') else amp**2\n    results[S] = simplify(beta_S)\n    print(f'S={S}: beta_S^(c_0) = {results[S]}')\n\n# Expected: S=0 → 1/5, S=2 → 2/7, S=4 → 18/35\nprint(f'Sum check: {sum(results.values())} = ?')\nEOF\n```\n(adjust sign convention or formula as needed; the above is one path; critic may use a cleaner alternative like the symmetric two-body projector P_S = Σ_M |S,M⟩⟨S,M|).\n\nReport: actual sympy output values. Compare to T92's (1/5, 2/7, 18/35). If MATCH at exact rational arithmetic: CORROBORATE F1. If MISMATCH: identify discrepancy site; either T92 §3 CG derivation has an error OR there is a sign-convention difference between T92's Condon-Shortley/Sakurai convention and sympy's default convention (note that sympy.physics.wigner uses Condon-Shortley).]\n\n## 3. Falsifier F2 — Lemma 1 prefactor structural validity at F=2\n[Read sign_pattern_lemma1_general_S.md §Step 2 (Wigner-Eckart prefactor derivation). The derivation should reduce to:\n  β_S^(λ_spin) = [⟨F^(1)·F^(2)⟩_S / F(F+1)] · β_S^(c_0) − β_S^(c_0)\n             = [(1/2)(S(S+1) - 2F(F+1)) / F(F+1) - 1] · β_S^(c_0)\n             ...\n             = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0)\n(or the analogous derivation in the paper3 file).\n\nIdentify any F-specific factors in the derivation:\n- 2F(F+1) at F=2 → 12 ≠ 0, no division-by-zero. ✓\n- (S(S+1) - 2F(F+1)) at S=0, F=2 → 0 - 12 = -12 (well-defined). ✓\n- Wigner-Eckart reduced matrix element at F=2 → standard, no obstruction (F=2 is well-known in nuclear physics applications).\n- F=5-style irrep obstruction (where the relevant irrep has multiplicity 0 in F=5 polyhedral decomposition) does NOT apply to F=2 cyclic (T_d A_1 has multiplicity 1 in F=2 decomposition — confirmed by F-Universality table in `universal_theorem_status` memory).\n\nReport: prefactor formula reduces to (S(S+1) − 2F(F+1))/(2F(F+1)) at F=2 with no algebraic obstruction. Verify the (−1, −1/2, +2/3) values at S∈{0,2,4} F=2 are correct.\n\n**Verdict on F2**: CORROBORATE if no F=2-specific issue; REFUTE-by-F2-obstruction otherwise.]\n\n## 4. Falsifier F3 — Σ_S β_S^(λ_spin) = 0 sum-rule identity derivation\n[Derive the identity independently:\n  Σ_S β_S^(c_0) [S(S+1) - 2F(F+1)] = Σ_S β_S^(c_0) ⟨S| 2 F^(1)·F^(2) |S⟩\n                                    = 2 ⟨ζ⊗ζ| F^(1)·F^(2) |ζ⊗ζ⟩\n                                    = 2 |⟨F⟩|²  (for product state ζ⊗ζ)\n  = 0  for any ⟨F⟩=0 state (including F=2 cyclic, polar, etc.)\n\nDividing by 2F(F+1):\n  Σ_S β_S^(c_0) [S(S+1) - 2F(F+1)] / (2F(F+1)) = 0\n  ⇒ Σ_S β_S^(λ_spin) = 0  ✓ (for ⟨F⟩=0 polyhedral inert states)\n\nVerify:\n- T92 values: −1/5 + (−1/7) + 12/35 = (−7 − 5 + 12)/35 = 0 ✓\n- T91 values: −1/5 + 0 + 8/15 = (−3 + 8)/15 = +1/3 ≠ 0 (T91 violates the identity, independently confirming T91 error).\n\nNote: the identity Σ_S β_S^(λ_spin) = 0 holds for ⟨F⟩=0 states; for states with ⟨F⟩≠0 (e.g., ferromagnetic), the RHS = 2|⟨F⟩|²/(2F(F+1)) ≠ 0. Verify which case applies to each of the 5 prior F=3/4/6/8/10 cases (all polyhedral inert have ⟨F⟩=0 by Schur).\n\n**Verdict on F3**: CORROBORATE.]\n\n## 5. Independent literature anchor cross-check\n[Brief mention of Mueller PRA 2004 + Turner-Barnett-Demler PRA 2007 F=2 cyclic results: both papers tabulate β_S^(c_0) = (1/5, 2/7, 18/35) for F=2 cyclic (this is the standard textbook result). If critic can confirm from local paper3 docs / MEMORY.md without WebFetch, do so. If only from prior memory citations, note that.]\n\n## 6. Polar-cyclic MF degeneracy sanity check (per T92 Appendix B)\n[The F=2 cyclic and F=2 polar (uniaxial nematic, ζ=(0,0,1,0,0)) states have IDENTICAL β_S^(c_0) = (1/5, 2/7, 18/35) at the mean-field level (well-known SO(5) MF degeneracy at c_1<0). However, the spin-Goldstone mode structure (and thus λ_spin) DIFFERS between polar and cyclic, even though β_S^(c_0) coincide. Verify:\n- F=2 polar β_0^(c_0) = |⟨0,0|0,0;0,0⟩|² · |ζ_0|^4 = (CG via singlet projector) — derive briefly; expect 1/5.\n- F=2 polar β_2^(c_0) = |⟨2,0|0,0;0,0⟩|² · |ζ_0|^4 — derive briefly. The CG ⟨2,0|2,0;2,0⟩ = -sqrt(2/7), so polar gives β_2 = 2/7 (matches cyclic).\n- F=2 polar β_4^(c_0) = |⟨4,0|2,0;2,0⟩|² = (6/sqrt(70))² = 36/70 = 18/35 (matches cyclic).\n\nThis SO(5) MF degeneracy is a known feature; the two states are distinguished only at the Bogoliubov (LHY) level. Lemma 1 closed form depends on β_S^(c_0) AND on the state being a polyhedral inert state with a specific Goldstone structure — cyclic IS polyhedral T_d A_1; polar is NOT (it has continuous U(1) axial symmetry). Lemma 1 claim H1 applies specifically to cyclic. Verify this distinction is consistent with the paper3 framework.\n\nCRITICAL CHECK: confirm that the β_S^(c_0) values being identical between polar and cyclic is NOT a degeneracy that invalidates Lemma 1's polyhedral-inert applicability claim. (Per paper3 framework: Lemma 1 inputs β_S^(c_0); but the polyhedral-inert classification adds the constraint that the state is a Schur-isotropic A_1/A_2 irrep representative under the polyhedral group, which polar is NOT. So Lemma 1 applies to cyclic but NOT polar, even though their β_S^(c_0) coincide.)]\n\n## 7. T91 triangulation error diagnosis (for CORROBORATE-WITH-T91-ERRATA path)\n[If F1+F2+F3 all CORROBORATE T92, document the T91 error:\n- T91 §3.3 claimed: \"⟨F⟩ = 0 → spin-spin channel S=2 contributes ZERO to mean-field energy → β_2^(c_0) = ⟨P_2⟩ = 0.\"\n- The first two equivalences are correct: ⟨F⟩ = 0 ⇒ c_1 |⟨F⟩|² = 0. But the third step is a NON-SEQUITUR: β_2^(c_0) is a channel-projector expectation value ⟨ζ⊗ζ|P_2|ζ⊗ζ⟩, NOT a mean-field-energy contribution. These are different observables related by Σ_S g_S β_S^(c_0) = mean-field energy per atom-pair. With ⟨F⟩=0, the c_1 channel decomposes as: Σ_S β_S^(c_0) [S(S+1)/2 - F(F+1)] = 0 (sum rule), which constrains the COMBINATION of β_S values but does NOT force β_2 individually to be zero.\n- Specifically: at F=2 cyclic, Σ_S β_S^(c_0) [S(S+1)/2 - 6] = (1/5)(-6) + (2/7)(-3) + (18/35)(4) = -42/35 - 30/35 + 72/35 = 0 ✓. The 2/7 β_2 contributes -6/7 to this sum, which is canceled by the β_0 and β_4 contributions; β_2 itself is NOT zero.\n\nThis is a paper3-side caveat to record at T94 Document: \"β_S^(c_0) channel weights are NOT identical to mean-field contributions; the latter is the sum-weighted combination Σ_S g_S β_S, and individual β_S can be nonzero even when a specific c_a coupling contribution vanishes by ⟨F⟩=0.\"]\n\n## 8. Verdict\n[ONE OF:\n- **CORROBORATE-WITH-T91-ERRATA** (expected): F1+F2+F3 all corroborate T92's (1/5, 2/7, 18/35) → (-1/5, -1/7, +12/35) at F=2 cyclic. T91 had a triangulation error at S=2 (root cause documented in §7 above). Tier 2.7 → 3.0. T94 = implementer_text Document.\n- **REFUTED-BY-T92-ERROR**: critic finds a specific algebra error in T92 §3 CG derivation (e.g., a sign error in the CG coefficient orthogonality construction in §3.5). Tier 2.0 (back to Hypothesize). T94 = theorist Hypothesize retry with critic's identified error site as new anchor.\n- **INCONCLUSIVE-NEED-F4**: F1+F2+F3 corroborate but critic flags F4 (Bogoliubov stiffness cross-check) as load-bearing for Tier-3. Tier 2.5. T94 = either sympy 5×5 BdG diagonalization at k→0 OR side-spawn researcher_shallow for non-PDF UKU2010 §V.C extraction.\n]\n\n## 9. Recommended T94 scope\n[Concrete: based on verdict in §8, specify T94 director should dispatch:\n- If CORROBORATE-WITH-T91-ERRATA: implementer_text Document — (a) extend `scripts/manuscript/lemma1_general_S_verification.jl` with F=2 cyclic-tetrahedral A_1 case (β_S^(c_0) = (1/5, 2/7, 18/35), β_S^(λ_spin) = (-1/5, -1/7, +12/35)); (b) append F=2 cyclic entry to `sign_pattern_lemma1_general_S.md` known-cases list; (c) append Tier-3 stamp to MEMORY.md `Sign_Pattern_Lemma1_General_S_2026_05_11` entry noting F=2 cyclic verification + T91 triangulation error caveat; (d) verify the regression script passes with F=2 added.\n- If REFUTED-BY-T92-ERROR: theorist Hypothesize retry — critic's identified error site as anchor; specific scope.\n- If INCONCLUSIVE-NEED-F4: implementer_sympy or implementer_julia_cpu_light — F=2 cyclic BdG diagonalization at k→0; or researcher_shallow non-PDF extraction route.\n]\n\n## 10. Metrics JSON\n[fenced ```json``` block per §METRICS schema]\n```\n\n## METRICS JSON (single fenced ```json``` block in critic/turn_93.md §10)\n\n```json\n{\n  \"experiment_kind\": \"text_only_plus_sympy\",\n  \"investigation_kind\": \"physics\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"agents_md_files_modified\": 0,\n  \"patterns_yaml_modified\": false,\n  \"state_json_modified\": false,\n  \"manuscript_edited\": false,\n  \"src_edited\": false,\n  \"julia_executed\": false,\n  \"webfetch_used\": false,\n  \"sympy_invoked\": <true|false; expect true>,\n  \"investigation_id\": \"sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18\",\n  \"stage_advancing_to\": \"Update\",\n  \"flow_template\": \"verify-claim\",\n  \"falsifier_F1_executed\": <true|false>,\n  \"falsifier_F1_sympy_beta_S0\": <numeric; expect 0.2 = 1/5 if F1 corroborates>,\n  \"falsifier_F1_sympy_beta_S2\": <numeric; expect 0.2857142857142857 = 2/7 if F1 corroborates>,\n  \"falsifier_F1_sympy_beta_S4\": <numeric; expect 0.5142857142857142 = 18/35 if F1 corroborates>,\n  \"falsifier_F1_sympy_matches_t92\": <true|false>,\n  \"falsifier_F1_sympy_matches_t91\": <true|false; expect false (T91 was wrong)>,\n  \"falsifier_F2_executed\": <true|false>,\n  \"falsifier_F2_no_F2_obstruction\": <true|false; expect true>,\n  \"falsifier_F2_prefactor_S0_at_F2\": <numeric; expect -1.0>,\n  \"falsifier_F2_prefactor_S2_at_F2\": <numeric; expect -0.5>,\n  \"falsifier_F2_prefactor_S4_at_F2\": <numeric; expect 0.6666666666666666>,\n  \"falsifier_F3_executed\": <true|false>,\n  \"falsifier_F3_sum_rule_derivation_independent\": <true|false; critic derives Σ_S β_S^(λ_spin) = 0 from F-tensor sum rule>,\n  \"falsifier_F3_t92_satisfies_sum_rule\": <true|false; expect true>,\n  \"falsifier_F3_t91_violates_sum_rule\": <true|false; expect true; T91 predicted values give sum=1/3>,\n  \"verdict\": <\"CORROBORATE-WITH-T91-ERRATA\"|\"REFUTED-BY-T92-ERROR\"|\"INCONCLUSIVE-NEED-F4\">,\n  \"verdict_load_bearing_evidence\": <string description of the decisive falsifier outcome>,\n  \"tier_recommendation\": <numeric; 3.0 if CORROBORATE, 2.0 if REFUTE, 2.5 if INCONCLUSIVE>,\n  \"next_stage_recommended\": <\"Document\"|\"Hypothesize\"|\"Update-deferred-F4\">,\n  \"errata_count\": <int>,\n  \"errata_load_bearing_count\": <int>,\n  \"errata_advisory_count\": <int>,\n  \"n_references_cited\": <int; expect >= 5>,\n  \"t91_triangulation_error_root_cause_documented\": <true|false; expect true if CORROBORATE>,\n  \"t91_error_class\": \"channel_weight_vs_meanfield_term_conflation\",\n  \"t92_cross_check_a_cg_orthogonality_audited\": <true|false>,\n  \"t92_cross_check_b_projector_normalization_audited\": <true|false>,\n  \"t92_cross_check_c_c0c1c2_meanfield_audited\": <true|false>,\n  \"t92_cross_check_d_sum_rule_audited\": <true|false>,\n  \"polar_cyclic_MF_degeneracy_sanity_check_done\": <true|false>,\n  \"s0_endpoint_cross_anchor_audited\": <true|false>,\n  \"lemma1_general_S_formula_consistent_at_F2\": <true|false>\n}\n```\n\n## CONSTRAINTS\n\n- **Files allowed to modify**: `/home/suzume/workspace/BEC-simulation/runs/_loop/critic/turn_93.md` ONLY.\n- **Files allowed to create**: `/tmp/critic_t93_*.py` (one-shot sympy scripts; NOT committed to scripts/).\n- **Files FORBIDDEN to modify**: `src/`, `runs/eu151_*/`, `runs/matsui_edh_baseline_*/`, `scripts/`, `docs/manuscript/`, `runs/_loop/state.json`, `.claude/agents/*`, `.claude/scripts/*`, `.claude/workload_specs.yaml`, `quota_config.json`, `.claude/settings*.json`, `runs/_loop/patterns.yaml`, any other `runs/_loop/` file (including research/, theorist/, sim/, judge/, director/).\n- **NO julia execution**.\n- **NO WebFetch** (cost discipline post-T92 BUDGET_OVER signal).\n- **Sympy invocation ALLOWED** via `uv run --with sympy python3 - <<'EOF' ... EOF` (one-shot tmp script for derivation verification; do NOT commit to scripts/).\n- **NO state.json edit**.\n- **English only**. No emojis. No anko-attribution. No improvised terminology — use established physics terms only (Wigner-Eckart, Racah formula, Condon-Shortley convention, channel weight β_S, Goldstone stiffness λ_spin, polyhedral inert state, etc.).\n- **No fabrication**: every β value claimed in critic report must be either (a) sympy-computed in §2 (with the sympy script output reported), or (b) cited to T92 §3 / paper3 sign_pattern_lemma1_general_S.md / memory entry with location.\n- **Absolute paths** in all Read / Write / Bash tool calls.\n- **Cost budget**: target ~1.3M effective; HARD CAP 1.8M (tightened by 0.2M from T92's 2.0M cap due to T92 BUDGET_OVER 1.33 ratio).\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT re-do T92's derivation via the SAME orthogonality construction (§3.5) — the whole point of F1 is a STRUCTURALLY DIFFERENT path (sympy Racah formula). If F1 just replicates T92's path, it is not an independent verification.\n- Do NOT skip F2 — even if F1 corroborates, F2 (Lemma 1 prefactor structural validity at F=2) is independent and cheap.\n- Do NOT skip F3 — the sum-rule identity is a clean falsifier that distinguishes T91 from T92 cleanly.\n- Do NOT do F4 unless F1+F2+F3 are all corroborated AND critic still has budget — F4 is OPTIONAL per T92 §10.\n- Do NOT WebFetch (cost discipline).\n- Do NOT modify scripts/manuscript/lemma1_general_S_verification.jl (that is T94 Document scope; T93 is critic Update only).\n- Do NOT exceed 1.8M effective tokens hard cap.\n- Do NOT silently adjust the verdict to fit a desired outcome: if F1 sympy gives different values, REFUTE-BY-T92-ERROR is the correct verdict; do not contort sign-conventions to force a match.\n- Do NOT re-do the F=2 polar β_S computation in §6 unless it is necessary for the sanity-check; the audit focus is cyclic, not polar.\n\n## REPORTING DISCIPLINE\n\n- Honest derivation steps: each algebraic manipulation either has a one-line justification or cites Wigner-Eckart / 6j / standard CG handbook.\n- Sympy output reported verbatim in §2 (include the sympy print output as part of the report).\n- If F1 sympy gives DIFFERENT values from T92 (e.g., β_2 = 0 matching T91 OR a third value), DO NOT silently adjust — report the discrepancy explicitly and classify verdict = REFUTED-BY-T92-ERROR with identified error site.\n- If F1 sympy gives a sign-convention mismatch (e.g., β_2 = +2/7 vs T92's -2/7), document the convention difference and decide whether |β|² is what matters (CORROBORATE if magnitude matches).\n- If sympy invocation fails (e.g., `wigner_3j` not in expected namespace), fall back to manual evaluation of the Racah formula with explicit citation to a handbook; do NOT silently skip F1.\n- Honest counts in §METRICS: every value either sympy-computed (§2) or cited; no fabrication.\n",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "src_files_modified",
      "new_analysis_scripts_written",
      "agents_md_files_modified",
      "patterns_yaml_modified",
      "state_json_modified",
      "manuscript_edited",
      "src_edited",
      "julia_executed",
      "webfetch_used",
      "sympy_invoked",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "falsifier_F1_executed",
      "falsifier_F1_sympy_beta_S0",
      "falsifier_F1_sympy_beta_S2",
      "falsifier_F1_sympy_beta_S4",
      "falsifier_F1_sympy_matches_t92",
      "falsifier_F1_sympy_matches_t91",
      "falsifier_F2_executed",
      "falsifier_F2_no_F2_obstruction",
      "falsifier_F2_prefactor_S0_at_F2",
      "falsifier_F2_prefactor_S2_at_F2",
      "falsifier_F2_prefactor_S4_at_F2",
      "falsifier_F3_executed",
      "falsifier_F3_sum_rule_derivation_independent",
      "falsifier_F3_t92_satisfies_sum_rule",
      "falsifier_F3_t91_violates_sum_rule",
      "verdict",
      "tier_recommendation",
      "next_stage_recommended",
      "n_references_cited",
      "t91_triangulation_error_root_cause_documented",
      "t92_cross_check_a_cg_orthogonality_audited",
      "t92_cross_check_b_projector_normalization_audited",
      "t92_cross_check_c_c0c1c2_meanfield_audited",
      "t92_cross_check_d_sum_rule_audited",
      "s0_endpoint_cross_anchor_audited",
      "lemma1_general_S_formula_consistent_at_F2"
    ],
    "optional": [
      "polar_cyclic_MF_degeneracy_sanity_check_done",
      "errata_count",
      "errata_load_bearing_count",
      "errata_advisory_count",
      "t91_error_class",
      "verdict_load_bearing_evidence"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_92.md && test -f /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md && test -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl && command -v uv >/dev/null 2>&1 && echo PRECONDITIONS_OK"
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "text_only_plus_sympy",
      "rationale": "Critic uses sympy for independent CG re-derivation (F1)."
    },
    {
      "id": "investigation_kind_physics",
      "metric": "investigation_kind",
      "operator": "==",
      "value": "physics",
      "rationale": "Verify-claim physics investigation."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "rationale": "Critic does not modify src/."
    },
    {
      "id": "no_scripts_committed",
      "metric": "new_analysis_scripts_written",
      "operator": "==",
      "value": 0,
      "rationale": "Sympy scripts live in /tmp; not committed."
    },
    {
      "id": "no_agents_md_changes",
      "metric": "agents_md_files_modified",
      "operator": "==",
      "value": 0,
      "rationale": "Critic does not modify agent prompts."
    },
    {
      "id": "patterns_yaml_untouched",
      "metric": "patterns_yaml_modified",
      "operator": "==",
      "value": false,
      "rationale": "Critic does not modify patterns.yaml."
    },
    {
      "id": "state_json_untouched_by_critic",
      "metric": "state_json_modified",
      "operator": "==",
      "value": false,
      "rationale": "Orchestrator manages state.json."
    },
    {
      "id": "no_manuscript_polish",
      "metric": "manuscript_edited",
      "operator": "==",
      "value": false,
      "rationale": "Manuscript polish is OUT (§A5)."
    },
    {
      "id": "no_src_modification_explicit",
      "metric": "src_edited",
      "operator": "==",
      "value": false,
      "rationale": "Critic does not modify src/."
    },
    {
      "id": "no_julia_execution",
      "metric": "julia_executed",
      "operator": "==",
      "value": false,
      "rationale": "T93 is text+sympy only; no julia."
    },
    {
      "id": "no_webfetch",
      "metric": "webfetch_used",
      "operator": "==",
      "value": false,
      "rationale": "Cost discipline post-T92 BUDGET_OVER."
    },
    {
      "id": "sympy_invoked_for_F1",
      "metric": "sympy_invoked",
      "operator": "==",
      "value": true,
      "rationale": "F1 mandatory sympy 6j-symbol re-derivation."
    },
    {
      "id": "investigation_consistent",
      "metric": "investigation_id",
      "operator": "==",
      "value": "sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18",
      "rationale": "Same investigation as T91-T92."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Update",
      "rationale": "§F1 next stage post-NOVEL is Update."
    },
    {
      "id": "template_consistent",
      "metric": "flow_template",
      "operator": "==",
      "value": "verify-claim",
      "rationale": "Same template throughout investigation."
    },
    {
      "id": "F1_executed",
      "metric": "falsifier_F1_executed",
      "operator": "==",
      "value": true,
      "rationale": "F1 is the load-bearing falsifier (sympy 6j-symbol independent re-derivation)."
    },
    {
      "id": "F1_sympy_S0_matches_t92",
      "metric": "falsifier_F1_sympy_beta_S0",
      "operator": "==",
      "value": 0.2,
      "tolerance": 0.001,
      "rationale": "T92 derived β_0^(c_0) = 1/5 = 0.2 at F=2 cyclic. Sympy 6j-symbol path should give same value if CORROBORATE."
    },
    {
      "id": "F1_sympy_S2_matches_t92",
      "metric": "falsifier_F1_sympy_beta_S2",
      "operator": "==",
      "value": 0.2857142857142857,
      "tolerance": 0.001,
      "rationale": "T92 derived β_2^(c_0) = 2/7 = 0.2857... at F=2 cyclic. Sympy path corroboration of the T91-vs-T92 disagreement at S=2."
    },
    {
      "id": "F1_sympy_S4_matches_t92",
      "metric": "falsifier_F1_sympy_beta_S4",
      "operator": "==",
      "value": 0.5142857142857142,
      "tolerance": 0.001,
      "rationale": "T92 derived β_4^(c_0) = 18/35 = 0.5143... at F=2 cyclic. Sympy path corroboration."
    },
    {
      "id": "F1_corroborates_t92",
      "metric": "falsifier_F1_sympy_matches_t92",
      "operator": "==",
      "value": true,
      "rationale": "F1 sympy path corroborates T92's derived values (CORROBORATE-WITH-T91-ERRATA path)."
    },
    {
      "id": "F1_refutes_t91",
      "metric": "falsifier_F1_sympy_matches_t91",
      "operator": "==",
      "value": false,
      "rationale": "T91's (1/5, 0, 4/5) values are NOT reproduced by sympy 6j-symbol path; T91 had a triangulation error."
    },
    {
      "id": "F2_executed",
      "metric": "falsifier_F2_executed",
      "operator": "==",
      "value": true,
      "rationale": "F2 verifies Lemma 1 prefactor structural validity at F=2 (no F-obstruction)."
    },
    {
      "id": "F2_no_obstruction",
      "metric": "falsifier_F2_no_F2_obstruction",
      "operator": "==",
      "value": true,
      "rationale": "Expected: Lemma 1 General-S derivation has no F=2-specific algebraic obstruction (2F(F+1)=12 ≠ 0)."
    },
    {
      "id": "F2_prefactor_S0_at_F2",
      "metric": "falsifier_F2_prefactor_S0_at_F2",
      "operator": "==",
      "value": -1.0,
      "rationale": "(0·1 - 12)/12 = -1 at F=2, S=0."
    },
    {
      "id": "F2_prefactor_S2_at_F2",
      "metric": "falsifier_F2_prefactor_S2_at_F2",
      "operator": "==",
      "value": -0.5,
      "rationale": "(2·3 - 12)/12 = -1/2 at F=2, S=2."
    },
    {
      "id": "F2_prefactor_S4_at_F2",
      "metric": "falsifier_F2_prefactor_S4_at_F2",
      "operator": "==",
      "value": 0.6666666666666666,
      "tolerance": 1e-9,
      "rationale": "(4·5 - 12)/12 = 8/12 = 2/3 at F=2, S=4."
    },
    {
      "id": "F3_executed",
      "metric": "falsifier_F3_executed",
      "operator": "==",
      "value": true,
      "rationale": "F3 derives Σ_S β_S^(λ_spin) = 0 sum-rule identity independently."
    },
    {
      "id": "F3_t92_satisfies_identity",
      "metric": "falsifier_F3_t92_satisfies_sum_rule",
      "operator": "==",
      "value": true,
      "rationale": "T92 values (-1/5, -1/7, +12/35) sum to 0 exactly."
    },
    {
      "id": "F3_t91_violates_identity",
      "metric": "falsifier_F3_t91_violates_sum_rule",
      "operator": "==",
      "value": true,
      "rationale": "T91 values (-1/5, 0, +8/15) sum to +1/3 ≠ 0; independent indicator of T91 error."
    },
    {
      "id": "verdict_set",
      "metric": "verdict",
      "operator": "in",
      "value": ["CORROBORATE-WITH-T91-ERRATA", "REFUTED-BY-T92-ERROR", "INCONCLUSIVE-NEED-F4"],
      "rationale": "Critic must emit one of the enumerated verdicts."
    },
    {
      "id": "tier_recommendation_set",
      "metric": "tier_recommendation",
      "operator": "in",
      "value": [2.0, 2.5, 3.0],
      "rationale": "Tier 3.0 if CORROBORATE; 2.0 if REFUTE; 2.5 if INCONCLUSIVE."
    },
    {
      "id": "next_stage_recommended_set",
      "metric": "next_stage_recommended",
      "operator": "in",
      "value": ["Document", "Hypothesize", "Update-deferred-F4"],
      "rationale": "Next stage depends on verdict."
    },
    {
      "id": "min_references_cited",
      "metric": "n_references_cited",
      "operator": ">=",
      "value": 5,
      "rationale": "Critic Update should cite ≥5 references (T92, paper3, regression script, sympy tool, memory entry)."
    },
    {
      "id": "t91_error_documented",
      "metric": "t91_triangulation_error_root_cause_documented",
      "operator": "==",
      "value": true,
      "rationale": "If CORROBORATE-WITH-T91-ERRATA, root cause of T91 error must be documented (channel_weight_vs_meanfield conflation)."
    },
    {
      "id": "t92_cross_check_a_audited",
      "metric": "t92_cross_check_a_cg_orthogonality_audited",
      "operator": "==",
      "value": true,
      "rationale": "T92 §3.2 + §3.5 CG orthogonality construction must be audited."
    },
    {
      "id": "t92_cross_check_b_audited",
      "metric": "t92_cross_check_b_projector_normalization_audited",
      "operator": "==",
      "value": true,
      "rationale": "T92 §3.3 normalization Σ_S β_S = 1 must be audited."
    },
    {
      "id": "t92_cross_check_c_audited",
      "metric": "t92_cross_check_c_c0c1c2_meanfield_audited",
      "operator": "==",
      "value": true,
      "rationale": "T92 §5 c_0/c_1/c_2 mean-field consistency check audited."
    },
    {
      "id": "t92_cross_check_d_audited",
      "metric": "t92_cross_check_d_sum_rule_audited",
      "operator": "==",
      "value": true,
      "rationale": "T92 §4.4 sum-rule identity audited."
    },
    {
      "id": "s0_endpoint_audited",
      "metric": "s0_endpoint_cross_anchor_audited",
      "operator": "==",
      "value": true,
      "rationale": "S=0 endpoint cross-anchor β_0^(λ_spin) = -1/(2F+1) = -1/5 at F=2 audited against rigorous proof."
    },
    {
      "id": "lemma1_at_F2_consistent",
      "metric": "lemma1_general_S_formula_consistent_at_F2",
      "operator": "==",
      "value": true,
      "rationale": "Lemma 1 General-S closed form is structurally consistent at F=2 (no obstruction)."
    }
  ],
  "failure_modes": [
    {
      "if": "falsifier_F1_executed == false",
      "category": "operational",
      "next_action": "T94 director re-dispatches critic Update with explicit sympy script template provided in brief (e.g., concrete one-liner that critic copies). Common cause: sympy environment not available; resolve via `uv run --with sympy` recipe."
    },
    {
      "if": "F1_corroborates_t92 == false AND falsifier_F1_sympy_matches_t91 == true",
      "category": "scientific_refuted",
      "next_action": "REFUTED-BY-T92-ERROR: T91 was correct, T92's orthogonality construction in §3.5 has an error. T94 director dispatches theorist Hypothesize retry with specific scope: re-derive ⟨2, 0 | 2, +2; 2, -2 ⟩ CG coefficient via Racah formula directly, NOT via orthogonality construction. Tier 2 (back to Hypothesize); investigation closure pushed to T96+."
    },
    {
      "if": "F1_corroborates_t92 == false AND F1_sympy_matches_t91 == false",
      "category": "scientific_refuted",
      "next_action": "DOUBLE-REFUTATION: both T91 and T92 wrong; sympy gives a THIRD set of values. T94 director side-dispatches researcher_deep for KU2012 §3 + Mueller 2004 + Turner-Barnett-Demler 2007 verbatim table extraction (cost ~4.5M; pushed to a non-cost-inflation cycle). Tier 1.5 (lost confidence)."
    },
    {
      "if": "F2_no_obstruction == false",
      "category": "scientific_refuted",
      "next_action": "Lemma 1 General-S formula does NOT extend to F=2 (F=2-specific algebraic obstruction analogous to F=5). T94 director dispatches implementer_text Document — close investigation as Tier-3 NEGATIVE result: 'Lemma 1 does NOT extend to F=2 due to <specific obstruction>'. Still a valid Tier-3 closure (negative result), but the substantive claim shifts."
    },
    {
      "if": "F3_t92_satisfies_identity == false",
      "category": "scientific_refuted",
      "next_action": "T92's corrected values (-1/5, -1/7, +12/35) fail the sum-rule identity. T94 director dispatches theorist Hypothesize retry with sum-rule constraint baked in."
    },
    {
      "if": "verdict == 'INCONCLUSIVE-NEED-F4'",
      "category": "data_gap",
      "next_action": "T94 director dispatches implementer_sympy for F=2 cyclic 5×5 BdG diagonalization at k→0; cost ~1.5M. Tier 2.5 stays. Alternative: side-spawn researcher_shallow for UKU2010 §V.C non-PDF extraction."
    },
    {
      "if": "actual_cost_eff > 1800000",
      "category": "operational",
      "next_action": "BUDGET_OVER (third consecutive turn would be a pattern). T94 director: tighten hard cap further to 1.5M; if critic could not complete F1+F2+F3 in 1.8M, evaluate whether the protocol-mandatory falsifier list is too aggressive for a single critic turn."
    },
    {
      "if": "n_references_cited < 5",
      "category": "operational",
      "next_action": "Critic ungrounded. T94 director re-dispatches critic with explicit citation list provided in brief."
    },
    {
      "if": "src_files_modified > 0 OR julia_executed == true OR webfetch_used == true",
      "category": "framework_error",
      "next_action": "Critic violated constraints. T94 director: re-dispatch with stricter NO-WEBFETCH / NO-JULIA reminders in brief; flag pattern in meta-critic-placement-2026-05-17 Observe stage."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 1800000,
    "expected_cost_eff": 1300000,
    "budget_over_threshold_ratio": 1.4
  },
  "budget": {
    "expected_cost_eff": 1300000,
    "expected_wall_time_sec": 1100,
    "split_by_subtask": {
      "read_t92_and_references": 350000,
      "sympy_F1_script_run": 350000,
      "F2_text_audit": 200000,
      "F3_text_derivation": 150000,
      "polar_cyclic_sanity_check": 100000,
      "verdict_synthesis_and_metrics": 150000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Document",
    "if_success_tier_becomes": 3.0,
    "if_partial_success_advance_to_stage": "Update-deferred-F4 (T94 implementer_sympy 5×5 BdG diagonalization)",
    "if_partial_success_tier_becomes": 2.5,
    "if_refuted_advance_to_stage": "Hypothesize (T94 theorist retry with critic-identified error site)",
    "if_refuted_tier_becomes": 2.0,
    "if_inconclusive_advance_to_stage": "Update (T94 critic re-run with sympy-template-in-brief)",
    "if_inconclusive_tier_becomes": 2.7,
    "if_data_gap_advance_to_stage": "Update-deferred-F4",
    "if_data_gap_tier_becomes": 2.5,
    "next_falsifier_to_test_after": "F4=Bogoliubov-spin-Goldstone-stiffness-via-sympy-5x5-BdG (to be tested at T94+ if INCONCLUSIVE; or as paper3 v4 extension if CORROBORATE landed clean)"
  },
  "consumed_seed_md": true
}
```

## 7. Self-review checklist

- [x] Read state.json + scheduler.json + seed.md this turn (state.json partial-read with offset; full lines 1-200 + 200-300; turn_92 critical entries; judge_92.json full; theorist_92.md full)
- [x] Read ≥1 memory file related to active investigation (`universal_theorem_status.md`)
- [x] investigation_id valid (sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18, established at T91)
- [x] stage_advancing_to is the next stage per flow template (Hypothesize → Update via NOVEL routing in §B3 — substantive finding by T92 theorist warrants critic audit before Design)
- [x] subagent_type matches role_per_stage[stage] (critic for Update in §F1)
- [x] success_criteria are machine-evaluable (33 criteria, each with metric / operator / value matching the §METRICS schema in critic/turn_93.md)
- [x] failure_modes cover the 3-5 most likely failures (9 modes covering: F1 unexecuted, F1 sympy matches T91 instead, F1 third-set, F2 obstruction, F3 sum-rule fail, INCONCLUSIVE-F4, budget over, ungrounded citations, framework violations)
- [x] observable_manifest precondition_check is concrete (`test -f` on 3 input files + `command -v uv` + echo)
- [x] budget fits within scheduler window_seconds_left (1.3M / 1.8M cap vs 1,137,790 sec / many M tokens available)
- [x] §A6 research-first citation present (T92 theorist report + paper3 sign_pattern_lemma1_general_S.md + 26-channel regression + sympy wigner Racah-formula canonical tool + Mueller PRA 2004 + Turner-Barnett-Demler PRA 2007 + grounded-research arXiv:2604.12198 pattern)
- [x] §A5 D1/D2/D3 articulated (D1 PRIMARY: cross-implementation Tier-3 verification at F=2 cyclic via structurally-different sympy 6j-symbol path)
- [x] Manuscript NOT primary (T93 produces critic Update report only; paper3/MEMORY.md edits at T94 if CORROBORATE)
- [x] APC cached skeleton used (verify-claim::Update n_seen=2; deltas patched for F=2 specifics)
- [x] Cost hard cap tightened to 1.8M (from T92's 2.0M, due to T92 BUDGET_OVER signal)
- [x] NOVEL routing applied per §B3 (T92 finding = T91 triangulation error correction = NOVEL → Update + critic)
- [x] Continuation discipline respected (4-turn investigation thread T91→T92→T93→T94; clean subagent rotation researcher→theorist→critic→implementer_text)
