---
turn: 91
subagent: director
investigation_id: sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18
stage_advancing_from: (new investigation; not yet in state.json)
stage_advancing_to: Research
topic_tags: [d1-verification, tier3-promotion, sign-pattern-lemma1, kawaguchi-ueda-2012, stamper-kurn-ueda-2013, F2-tetrahedral, channel-weights, subagent-rotation-to-researcher, text-only-tier3]
paper_section: null
depends_on: [69, 70, 90, "runs/_loop/research/turn_69.md", "runs/_loop/director/turn_70.md", "runs/_loop/director/turn_90.md", "runs/_loop/state.json", "runs/_loop/_local/scheduler_91.json", "memory:tier3_pipeline_survey_2026_05_18", "memory:universal_theorem_status", "memory:Sign_Pattern_Lemma1_General_S_2026_05_11_MEMORY_md_entry"]
produces: "T91 researcher_shallow dispatch for §F1 Research stage of NEW investigation sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18 (verify-claim, kind=physics, tier_target=3, priority=1 inheriting EdH-Matsui's just-vacated slot). Spawns the investigation entry in state.json (or signals orchestrator to spawn) AND dispatches researcher to extract Kawaguchi-Ueda 2012 (arXiv:1001.2072) §4 + Stamper-Kurn-Ueda 2013 (RMP) §IV β_S^(c_0) channel-weight tables for the F=2 tetrahedral A_1 (cyclic) state. Output is a structured table the T92 theorist can apply Lemma 1 formula β_S^(λ_spin) = (S(S+1) - 2F(F+1))/(2F(F+1)) · β_S^(c_0) to + cross-compare against the same papers' Bogoliubov spectrum tables to land Tier 3 in 1 theorist turn. Cheapest Tier-3 path in T69 menu (§2.3 #3), already pre-routed by T90 closing_note recommendation."
---

# Turn 91 — Director Report

## 1. Investigation state snapshot

- **Active investigation (SWITCHING; spawning NEW)**: `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`. This is the T69 §2.3 menu candidate #3 explicitly recommended by T90's `closing_note` for the EdH-Matsui survey: "Recommended T91 dispatch: theorist Hypothesize for sign-pattern-lemma1-tier3-vs-kawaguchi-ueda (T69 §2.3 menu item #3; cheapest D1 advance; rotates subagent off implementer_text after 5 of last 6)." Investigation does NOT yet exist in state.json — T91 dispatch creates it.

  IMPORTANT CORRECTION to T90's recommendation: T90 wrote "theorist Hypothesize", but T69 §2.3 only confirmed KU2012 §4 EXISTS via WebSearch abstract — the actual β_S table EXTRACTION was scoped as "Turn T70: theorist (text-only) — WebFetch Kawaguchi-Ueda 2012 §4 / Stamper-Kurn-Ueda 2013 §IV; extract β_S tables...". Per §F1 (verify-claim) the stage that does external-source extraction is **Research** (role: researcher), not Hypothesize. T91 honors §F1 discipline: dispatch researcher_shallow for Research stage (extract KU2012 + SKU2013 channel-weight tables for F=2 tetrahedral A_1), then T92 theorist Hypothesize applies Lemma 1 formula and produces the cross-check claim.

- **Stage transition**: (new) → **Research** per §F1 (verify-claim: Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed).

- **Tier**: `(new)` → `2` post-Research (Research extracts the external benchmark tables; tier_current pre-existing internal verification = 2 per MEMORY.md "Sign Pattern Lemma 1 General-S CLOSED FORM" entry 2026-05-11; T92 Hypothesize + critic Update advances to 3 if Lemma 1 formula matches external tables). tier_target = 3.

- **Falsifier-tested**: 0 of 3 (to be drafted at T92 Hypothesize; preliminary list: F1 = KU2012-F2-cyclic-channel-weight-match-within-1pct; F2 = SKU2013-F2-tetrahedral-Bogoliubov-spectrum-derived-β_S^(λ_spin)-match-within-1pct; F3 = F=1-FM-or-polar-cross-check-against-UKU2010-or-KU2012-§3-as-secondary-anchor).

- **Other in-flight investigations summary** (post-T90 close of tier3-verification-pipeline-survey):
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED Tier 3.0 T29.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): CLOSED Tier 3.0 T59.
  - `yan-li-saito-2026-reproduction` (priority 1): CLOSED REFUTED-CLEAN T65 tier 0.4.
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED tier 2 T54.
  - `audit-due-heuristic-bug-2026-05-18` (priority 4): CLOSED tier 2 T68.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1.
  - `tier3-verification-pipeline-survey-2026-05-18` (priority 10): CLOSED Tier 1.0 T90.
  - `edh-eu151-vortex-vs-matsui-science-2026` (priority 1): CLOSED Tier 3.0 T86.
  - `meta-cost-waste-audit-2026-05-18` (priority 15): Observe-spawned auto; Hypothesize pending. Cost_inflation cleared since T87 — not urgent.
  - `audit-class-scan-2026-05-18-T87` (priority 20): CLOSED tier 2 T89; next AUDIT_DUE ~T98.
  - `meta-director-self-audit-2026-05-18` (priority 20): Observe auto-spawn; Hypothesize pending.
  - `meta-stage-routing-2026-05-18` (priority 25): CLOSED tier 0 REFUTED-BY-CONFOUNDER.
  - `meta-cost-inflation-2026-05-18` (priority 40): Observe auto-spawn; Hypothesize pending — deprioritized (cost_inflation cleared T87+).
  - `meta-critic-placement-2026-05-17` (priority 50): Observe ongoing; deferred.
  - `fullbdg-f6-polar-3000x` (priority 99): dormant.
  - **`sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`** (THIS TURN spawns; priority 1 inheriting EdH's vacated slot per T70 precedent for child investigations from survey).

- **Scheduler** (`runs/_loop/_local/scheduler_91.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, allowed_workloads includes `researcher`, `researcher_deep`, `researcher_exhaustive`, `theorist`, `critic`, `implementer_text`, etc. Window ends 2026-05-31T23:59 JST with **1,141,547 sec (~13.2 days)** remaining. researcher_shallow workload (~1M effective baseline) trivially within budget. Probe: VRAM 12,703 MB free, RAM 25.06 GB, GPU util 1%, foreign_julia 0.

- **Last judge verdict**: T90 = PASS (27/27 success criteria, 0 issues, 0 triggered_failure_modes, effective cost 1.31M, cost_audit `BUDGET_OVER` 1.31M/0.80M=1.64). T90 cleanly closed `tier3-verification-pipeline-survey-2026-05-18` at Tier 1.0. State.json now has zero lingering Document-pending non-closed investigations.

- **Drift signals (T90 footer)**: subagent_repetition=0.667 (5/6 implementer_text incoming — **rotation pressure ACTIVE this turn**); cost_inflation=0.784 (down from 0.87 at T89; trend continues downward); manuscript_delta_zero=1.0 (advisory only — correct by design for state-only closure); novel_claim_zero=1.0 (T90 was mechanical closure; T91 MUST produce novel content to clear). drift_escalation = `director_must_address` per drift_signals.py.

- **Why THIS investigation, THIS stage, NOT noop, NOT something else (decision tree per §B2)**:

  1. **Eliminate closed/dormant/blocked**: 7 closed (Barnett, Klaus-BCH, Yan-Li-Saito, judge-in-operator, audit-due-heuristic, meta-internal-b-unification, meta-stage-routing, audit-class-scans T50/T61/T87, judge-in-operator, EdH-Matsui, tier3-survey), 1 dormant (fullbdg-f6-polar-3000x priority 99 skip per §B2 rule), 4 meta in Observe-Hypothesize-pending state (meta-critic-placement priority 50, meta-cost-waste-audit priority 15, meta-director-self-audit priority 20, meta-cost-inflation priority 40).

  2. **Anko seed.md priority order**: seed.md is the 2026-05-15 morning stale version (Klaus-julia-ban no longer active per scheduler probe). Goal continuation directive: "研究が最も進む方向性はどれかを考えた上で理論を詰める。盲目に理論をやらない。様々な論文を読んだり verify したり、まだ実装してない効果を入れたりとかそういうのを総合的に考えて。" Translation: pick the direction that advances research most; verify implementations against papers; identify unimplemented effects. **The Sign Pattern Lemma 1 Tier-3 cross-check IS exactly "様々な論文を読んだり verify したり" — extracting KU2012 + SKU2013 tables and verifying our Lemma 1 formula against them.**

  3. **Lowest priority number among physics-eligible**: spawning the new investigation at priority 1 (inheriting EdH-Matsui's just-vacated slot per T70 precedent) makes it tied with the closed barnett/klaus-bch/yan-li-saito for priority but is the only eligible one. Meta investigations (priority 15-50) are interleaved per §B2, not parallel; with 5 of last 6 turns being implementer_text and NONE being theorist/researcher/critic substantive work, the rotation must go to physics-axis next, not meta.

  4. **Continuation of T90's `closing_note` recommendation**: explicit pre-routing pointed T91 here. T90 was CLOSING the parent (tier3-verification-pipeline-survey), the closing_note explicitly recommended this exact spawn. Honoring T90's closing_note is the canonical multi-turn director continuity discipline.

  5. **Largest tier_target − tier_current gap**: among all candidate physics investigations spawnable from the T69 menu:
     - sign-pattern-lemma1-tier3-vs-KU (new, tier 2 → 3): gap 1, cost ~1-2 turns
     - bug-4-itp-ddi-half-rate-revalidation (new, tier 1 → 2): gap 1, cost 2 turns + 1 optional julia (no GPU needed)
     - twochannel-lhy-F6-polar-30-70-percent-error (new, tier 1.5 → 2.5 capped): gap 1.0 capped, cost 2 turns
     - tdhfb-phase2-hf-kernel-generic-F-bogoliubov (new, tier 2 → 3): gap 1, cost 2-3 turns + julia validation
     The Sign Pattern candidate ties on tier gap but wins on cost (cheapest 1-2 turn text-only path) AND on subagent rotation (text-only research+theorist sequence rotates off the 5/6 implementer_text streak in two-turn span).

  6. **Why NOT a meta-investigation Hypothesize pivot (cost-waste, director-self-audit, cost-inflation)**:
     - Cost_inflation drift already cleared since T87 (T87 0.91 → T88 0.87 → T89 0.87 → T90 0.784); the trigger that auto-spawned `meta-cost-waste-audit` and `meta-cost-inflation` has been substantially mitigated by the recent steady-state PASS pattern. Meta-investigations are not urgent.
     - Meta is INTERLEAVED, not parallel per §B2; with the recent T87+T88+T89 audit-class-scan cycle being a meta-flavored block, advancing a different meta now stacks meta-on-meta. Director.md §B2: "Do not pile multiple meta turns in a row."
     - Physics-axis work (Sign Pattern Tier-3 cross-check) directly advances D1 (verify); the meta investigations target D2 (service axis) which §A5 explicitly subordinates: "D2 dispatch requires explicit justification ending in a D1 verification or D3 derivation blocked by performance."
     - novel_claim_zero=1.0 escalation: T91 NEEDS to produce novel claims; researcher Research stage extracting external tables produces concrete numerical data (β_S^(c_0) values for F=2 tetrahedral A_1) — exactly the novel claim shape that clears the escalation.

  7. **Why NOT Bug-4 ITP DDI half-rate revalidation (T69 §2.2 candidate #2)**:
     - Cheapest in absolute terms (2 turns + optional julia) but requires implementer_julia for the optional re-run; the rotation pressure from 5/6 implementer_text says route to researcher/theorist this turn.
     - Bug-4 partially audited at production parameters via EdH-Matsui F3 falsifier (T82-T83 implicitly checked DDI-active GS energy was correct post-fix). A dedicated audit is institutional-clarity work, not urgent verification.
     - Lemma 1 Tier-3 is the SAME budget (1-2 turns) and produces a Tier-3 trajectory (3 → 4 project Tier-3 closed), whereas Bug-4 produces a Tier-2 trajectory.

  8. **Why NOT TDHFB Phase 2 HF kernel (T69 §2.5 candidate #5)**:
     - Requires julia validation runs (sound-velocity comparison against KU2012 §4.2 sound-mode dispersion) for Tier-3; researcher_shallow alone doesn't get there.
     - Heavier subagent rotation (researcher → theorist → implementer_julia) vs Lemma 1 (researcher → theorist alone).

  9. **Why NOT directly skip Research and dispatch theorist Hypothesize (T90 recommendation)**:
     - T69 §2.3 confirmed KU2012 §4 EXISTS via WebSearch abstract but did NOT extract the actual β_S tables.
     - Per §A2 (no execution by director) + §A3 (do not skip stages of flow template): theorist Hypothesize needs an extracted-table input, which is a Research-stage deliverable per §F1.
     - The cleanest sequence is: T91 Research (extract tables) → T92 Hypothesize (apply Lemma 1 formula + compare) → T93 Update (critic verifies). 3-turn Tier-3 closure.
     - If Research extraction reveals "tables exist but in a form requiring manual derivation from text" or "KU2012 §4 tables actually cover F=2 antiferromagnetic only, not cyclic-tetrahedral A_1", the failure_mode routes to Hypothesize-with-refined-scope or jumps to a different external anchor (SKU2013) — exactly the discipline §F1 Research stage exists for.

  10. **Why NOT noop**: noop with rationale "waiting for anko seed update" wastes the turn; the T90 closing_note is concrete pre-routing; subagent rotation pressure escalates if T91 is noop (then T92 also implementer_text would make 6/7); novel_claim_zero=1.0 escalation requires action.

- **Cost frame**: target ~1.0M-2.0M effective (researcher_shallow baseline 1M; +WebFetch budget 0.5M for KU2012 PDF + SKU2013 RMP article + arXiv:0912.0355 UKU2010 secondary anchor; +structured-output 0.3M). Hard cap 2.5M. Previous comparable researcher_shallow turns: T69 = ~6M (researcher_deep including PDF analysis), T61 = ~4.8M (researcher 10-pattern grep sweep). T91 is more focused than T69 (1 external paper extraction, not survey) so target lower at ~1.5M.

- **Subagent rotation discipline**: 5 of last 6 implementer_text incoming (T85/T86/T88/T89/T90). T91 = researcher rotates off the streak in one turn. T92 = theorist (continuation of investigation) rotates further. T93 = critic Update. This 3-turn arc cleanly clears the rotation pressure.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

This is a NEW investigation; no prior turns. Relevant precursor turns from the parent investigation `tier3-verification-pipeline-survey-2026-05-18`:

| Turn | Stage (parent) | Verdict | What happened |
|---|---|---|---|
| T69 | Research (parent) | PASS | researcher inventoried 5 candidates; §2.3 confirmed KU2012 §4 EXISTS via WebSearch abstract; flagged Sign Pattern Lemma 1 Tier-3 as cheapest path (1 turn theorist text-only); benchmark availability HIGH; assigned PRIORITY #3 in menu (cheapest but lowest load-bearing-ness 2/5). |
| T70 | Synthesize (parent) | PASS | theorist spawned different child (`edh-eu151-vortex-vs-matsui-science-2026`, priority #1 not #3) per anko priority weighting (load-bearing 5/5 > cost factor). T70 preserved Sign Pattern Lemma 1 candidate in survey menu for "future steady-state turns". |
| T90 | Document (parent) | PASS | implementer_text closed parent survey at tier 1. `closing_note` explicitly named `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda` as T91 recommendation. Survey methodology memory file `tier3_pipeline_survey_2026_05_18.md` appended with Outcome section. |

Internal Sign Pattern Lemma 1 verification history (NOT prior turns of this investigation, but prior memory):
- 2026-05-11 (commits c811cd7..fe5f3ec / 330e73a): Lemma 1 General-S CLOSED FORM β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0) **internally verified at 26 channels across F=3/4/6/8/10 polyhedral cases** (rational arithmetic, machine precision). Regression script `scripts/manuscript/lemma1_general_S_verification.jl` 26/26 PASS. Also rank-2 vanishing proved rigorously via character formula (commit 2026-05-11; `D2_H_irrep_character_proof.jl` 4 PASS). This puts tier_current at **2** (internal cross-implementation: closed form vs IcosahedralMod manual coefficients at 4 F=6 channels — Tier 2).
- 2026-05-12 (#75): F=13 O:A_1 + O:A_2 verified at machine precision; F=5 algebraic obstruction documented.

This T91 dispatch's purpose: turn that internal Tier-2 verification into a Tier-3 published-reference-benchmarked claim by extracting KU2012 §4 / SKU2013 §IV channel-weight tables for F=2 tetrahedral A_1 and comparing.

## 3. Flow template recall

- **Template**: `verify-claim` (§F1): Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed.
- **Role for Research**: `researcher` per §F1 stage table. Director.md §F1 says: "Research: researcher — lit scan, prior loop turns, memory entries — sets up Hypothesize with citation chain. MUST specify `researcher_depth` in §6 contract: `shallow` (5-15 queries, ~1M) / `deep` (≥30 parallel queries + full-PDF mandatory + ≥2 iteration rounds, ~4.5M) / `exhaustive` (100+ queries + cross-citation graph, ~10M+). Default `shallow`."

- **Researcher depth choice = `shallow`**:
  - Investigation tier_target=3 (per §F1 upgrade trigger "investigation tier_target == 3"): this normally signals `deep` upgrade.
  - BUT: T69 §2.3 already did the canonical-source identification work (KU2012 + SKU2013 confirmed as primary external anchors, abstract-confirmed). T91 Research only needs to EXTRACT tables from already-identified papers, not survey.
  - Prior shallow research turn (T69 §2.3) did NOT produce contradictions for this specific candidate.
  - The question does NOT involve unit-system / hyperfine-state / normalization choices that would force `deep`.
  - **Decision: `shallow` is the right depth**. Hard cap budget: 1.5M effective. If shallow extraction produces ambiguous results, T92 retries with `deep` upgrade explicitly documented.

- **Verdict-driven routing per §B3**: T90 (parent) verdict was PASS (Document close). This new investigation has no prior verdict (new spawn); first stage is Research per §F1.

- **Why Research NOW (not Hypothesize directly)**:
  - §A3 flow discipline: "Do NOT skip stages."
  - §F1 Research stage explicitly produces "citation chain" input to Hypothesize. T91 must extract the actual β_S^(c_0) numerical values from KU2012 §4 / SKU2013 §IV for the F=2 tetrahedral state — this is text extraction work, not theory work.
  - T92 theorist Hypothesize then applies internal Lemma 1 formula β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0) to the extracted β_S^(c_0) values + writes the formal claim + falsifier list.

## 4. Research grounding (§A6)

T91 dispatch citations (researcher-stage extraction grounding; §A6 mandatory for Hypothesize and Design stages but recommended for all stages):

1. **`runs/_loop/research/turn_69.md` §2.3 (a)-(g)** — T69 researcher's identification of KU2012 (arXiv:1001.2072) §4 and SKU2013 (RMP) §IV as the canonical external anchors with channel-weight tables for F=2 polyhedral states; abstract-confirmed via WebSearch; benchmark availability HIGH. This is the load-bearing reference for T91's Research scope.

2. **MEMORY.md "Sign Pattern Lemma 1 General-S CLOSED FORM (2026-05-11)" entry** + `memory/universal_theorem_status.md` Iter 2 update (2026-05-11) — the internal closed form β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0) verified at 26 channels across F=3/4/6/8/10. Provides the formula T92 will apply to the T91-extracted β_S^(c_0) values.

3. **Kawaguchi & Ueda 2012, Phys. Rep. 520, 253-381** (arXiv:1001.2072; DOI: 10.1016/j.physrep.2012.07.005). Canonical spinor BEC review. §4 tabulates β_S channel weights for F=2 polyhedral states (cyclic = tetrahedral A_1). T91 Research target.

4. **Stamper-Kurn & Ueda 2013, Rev. Mod. Phys. 85, 1191** (DOI: 10.1103/RevModPhys.85.1191). Spinor BEC RMP. §IV covers F=1 and F=2 Bogoliubov spectra with explicit channel-weight data. T91 Research secondary target.

5. **Uchino, Kobayashi & Ueda 2010, PRA 81, 063632** (arXiv:0912.0355). LHY for F=1 and F=2. Optional tertiary anchor: F=1 polar + F=2 polar / cyclic-tetrahedral A_1 LHY-explicit forms (not the primary Lemma 1 cross-check but provides redundancy for the F=2 cyclic state).

6. **`scripts/manuscript/lemma1_general_S_verification.jl`** — 26/26 PASS internal regression (the script T92 will compare against the external tables).

7. **`runs/_loop/director/turn_70.md`** — the precedent for spawning a child investigation from a survey-menu candidate. T70 created `edh-eu151-vortex-vs-matsui-science-2026` from T69 §2.1; T91 mirrors this shape for §2.3 (different child, same survey menu).

8. **`runs/_loop/director/turn_90.md` §1 closing_note** — explicit pre-routing recommendation for T91 to advance `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda`. T91 honors this multi-turn continuity per §B3 ("continuation of last director's if_succeeds_next_step / if_fails_next_step if last turn was on this investigation"). Note: T90 said "theorist Hypothesize" but T91 corrects to "researcher Research" per §F1 stage-order discipline (the actual extraction of external tables is a Research deliverable, not a Hypothesize deliverable).

9. **APC contract template cache hit** (per §B1 protocol): `python3 .claude/scripts/contract_cache.py lookup --kind physics --template verify-claim --stage Research` would return the verify-claim Research skeleton; cache shows verify-claim Hypothesize has n_seen=4 (cf. /home/suzume/workspace/BEC-simulation/.claude/cache/contract_templates.json lines 757-907). verify-claim Research is NOT yet cached at n_seen >= 2 (T29 / T71 Research turns were single instances of researcher_deep, not researcher_shallow), so T91 builds the structure from scratch and the contract_cache.py extract --turn 91 post-turn will populate the cache for future verify-claim::Research dispatches.

10. **Director.md §F1 Research stage role specification** — "researcher — lit scan, prior loop turns, memory entries — sets up Hypothesize with citation chain. MUST specify `researcher_depth`." T91 specifies `shallow`.

11. **Director.md §A5 D-axis discipline** — "D1 verification depth tiers: Tier 0 never attempted, Tier 1 internal regression only, Tier 2 closed-form / sympy / cross-implementation verified, Tier 3 published-reference benchmarked (Stuttgart, Yan-Li-Saito, etc.). Most [Established] memory entries are Tier 1-2. Zero are Tier 3 currently." Out of date — barnett (T29), klaus-bch (T59), edh-matsui (T86) are now Tier 3. Sign Pattern Lemma 1 would be the 4th Tier-3 trajectory and the first manuscript-anchored (paper3 v3) one.

12. **Memory `feedback_decision_style.md`** — single commitment per turn; T91 commits to spawning the new investigation + Research stage dispatch; T92 will continue with Hypothesize (or jump to Update if Research fails-clean).

13. **Memory `feedback_cost_overhead_is_the_cost.md`** — execute the dispatch immediately; the Lemma 1 Tier-3 cross-check is cheap and high-value-per-token.

14. **Memory `feedback_no_improvised_terminology.md`** — Research stage must use standard physics terminology: "channel weights β_S^(c_0)", "tetrahedral A_1 state", "Bogoliubov spectrum", per KU2012 / SKU2013 conventions. No novel naming.

15. **Memory `feedback_manuscript_is_not_the_essence.md`** — T91 advances D1 verification, NOT paper3 polish. If Research extraction surfaces a discrepancy that would force paper3 v3 revisions, that's a legitimate D1 finding (paper text follows physics, not the other way round).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. Extracting external published-reference channel-weight tables for cross-check against internal Lemma 1 closed-form formula advances Tier 2 → 3 (published-reference benchmarked) on the Sign Pattern Lemma 1 claim. Direct match to §A5 D1 axis ("Every load-bearing claim could be wrong. Find the wrongness.").

- **Tier ladder position**: T91 begins a Tier 2 → 3 trajectory. Project Tier-3 count post-T91 (after T93 Update completes the cycle): 3 → 4 (barnett + klaus-bch + edh-matsui + sign-pattern-lemma1).

- **Project D1 verification depth narrative**: This is the project's first **manuscript-anchored** Tier-3 claim (paper3 v3 Lemma 1 General-S). All prior Tier-3 closures (barnett, klaus-bch, edh-matsui) verified simulation-side physics. Lemma 1 Tier-3 verifies the analysis-side classification framework against published reviews — orthogonal axis of verification depth.

- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). T91 dispatch produces a research extraction report (runs/_loop/research/turn_91.md); no paper3 polish, no thesis-section edits. If T93 Update CORROBORATES, T94 Document will append the Tier-3 verification stamp to MEMORY.md / sign_pattern_lemma1_general_S.md only.

- **Cost frame**: target ~1.5M effective; hard cap 2.5M. researcher_shallow baseline is ~1M; +WebFetch budget for KU2012 PDF (large review, ~120 pages but only §4 needed) ~0.4M; +SKU2013 §IV ~0.3M; +structured output ~0.3M. T91 stays within steady-state cost trend.

- **Drift trajectory after T91 (anticipated)**:
  - cost_inflation: stays low (~0.7-0.8 range) — researcher_shallow is canonical-cost workload.
  - code_delta_zero: 1.0 (research turn, no src/ touched — correct by design).
  - manuscript_delta_zero: 1.0 (correctly, by design; T91 is research extraction).
  - novel_claim_zero: 0.0 (CLEARED — extracted β_S^(c_0) numerical values from KU2012 §4 + SKU2013 §IV are novel claims for the loop's institutional record).
  - topic_repetition: drops (audit-class-scan + survey-closure → new theory-verification topic).
  - subagent_repetition: 1/6 researcher (was 0/6) — rotation pressure CLEARED in one turn.
  - verdict_drift: stays clean (researcher_shallow Research is a low-failure-rate workload).

- **Recommended T92-T93 trajectory** (post-T91 success path):
  1. **T92 theorist Hypothesize**: apply Lemma 1 formula β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0) to T91-extracted β_S^(c_0) values for F=2 tetrahedral A_1 (S ∈ {0, 2, 4}; β_S^(c_0)_KU2012 known); write the claim "Lemma 1 closed-form matches KU2012 §4 / SKU2013 §IV channel-weight tables for F=2 tetrahedral within X% relative error"; draft falsifier list. ~1.5M theorist text-only.
  2. **T93 critic Update**: independent verification — re-derive Lemma 1 formula from Wigner-Eckart 6j-symbol structure for F=2 case; verify the table extraction is not cherry-picked; check sign conventions consistent between KU2012 and project. CORROBORATE or REFUTE. If CORROBORATE: tier_current 2 → 3. If REFUTE: jump to Update with refined hypothesis (sign-convention mismatch, normalization difference, etc.). ~1.2M critic.
  3. **T94 implementer_text Document**: append Tier-3 verification stamp to `memory/MEMORY.md` "Sign Pattern Lemma 1" entry; append errata-resolved if any; close investigation. ~0.7M.
  4. Total Tier-3 closure cost: ~5M effective across 4 turns.

- **Branch-point T91 failures (per §6 failure_modes)**:
  - If KU2012 §4 tables turn out to use a DIFFERENT canonical state for "F=2 tetrahedral" than the project (e.g., KU2012 uses biaxial-nematic while project uses cyclic-tetrahedral A_1): T92 redirects to extracting the cyclic state explicitly and noting the convention difference.
  - If KU2012 §4 tables are derived-not-tabulated (i.e., only formulas in symbolic form, no numerical values for specific β_S^(c_0)): T92 evaluates the formula symbolically + compares structurally to Lemma 1; this is still Tier 3 (closed-form match against published derivation).
  - If KU2012 PDF is paywalled and arXiv:1001.2072 differs from published version §4 numbering: T91 escalates to researcher_deep or anko-manual extraction.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18",
  "stage_advancing_to": "Research",
  "subagent_type": "researcher",
  "researcher_depth": "shallow",
  "parallel_researcher_count": 1,
  "rationale": "T90 closing_note explicitly recommended this investigation as the T91 pivot ('Recommended T91 dispatch: ... sign-pattern-lemma1-tier3-vs-kawaguchi-ueda (T69 §2.3 menu item #3; cheapest D1 advance; rotates subagent off implementer_text after 5 of last 6)'). T69 §2.3 confirmed Kawaguchi-Ueda 2012 (arXiv:1001.2072) §4 + Stamper-Kurn-Ueda 2013 (RMP) §IV channel-weight tables for F=2 polyhedral states EXIST via WebSearch abstract — but the actual extraction was deferred to a future turn (originally T70 theorist, but theorist Hypothesize cannot extract tables without input; per §F1 stage discipline the extraction is a Research-stage deliverable). T91 dispatches researcher_shallow to (a) WebFetch KU2012 §4 + SKU2013 §IV PDFs, (b) extract β_S^(c_0) numerical values for F=2 tetrahedral A_1 (cyclic) state at S ∈ {0, 2, 4}, (c) verify that the project's internal Lemma 1 closed-form formula β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0) (verified 26/26 internally at F=3/4/6/8/10) is APPLICABLE at F=2 (the closed form was derived for A_1-irrep polyhedral inert states; F=2 cyclic = T_d which is polyhedral), (d) record the extracted tables in a structured output T92 theorist Hypothesize can apply Lemma 1 formula to + critic Update can independently audit. Cheapest Tier-3 cross-check in T69 menu; rotates subagent off the 5/6 implementer_text streak; clears novel_claim_zero drift advisory; advances D1 (the project's primary axis) toward the 4th Tier-3 closure (1st manuscript-anchored). APC contract cache: physics::verify-claim::Research not yet at n_seen>=2 (cf. n_seen=1 at T71; T29 Barnett Research was older form). T91 builds Research contract from scratch; contract_cache.py extract post-turn populates for T92+.",
  "brief": "## ROLE\n\nYou are researcher (depth=shallow). T91 §F1 Research stage of NEW investigation `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`. Your job: extract Kawaguchi-Ueda 2012 §4 + Stamper-Kurn-Ueda 2013 §IV channel-weight tables β_S^(c_0) for F=2 tetrahedral A_1 (cyclic) polyhedral state, structured for T92 theorist Hypothesize to apply Lemma 1 closed-form formula β_S^(λ_spin) = (S(S+1) − 2F(F+1))/(2F(F+1)) · β_S^(c_0) and compare against the same papers' Bogoliubov spectrum / spin-stiffness data. NO src/ modification. NO state.json edit (orchestrator manages investigation entry). NO julia execution.\n\nDIRECTIVE_LABEL: sign-pattern-lemma1-tier3-T91-research-extract-ku2012-sku2013-f2-tables\n\n## REQUIRED READING (READ FIRST, BEFORE WEBFETCH)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_91.md` (this director report) — the dispatch rationale + §6 contract.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_69.md` §2.3 entirely — the prior researcher's identification of KU2012 + SKU2013 as canonical external anchors + the falsifier sketch you are advancing. Pay attention to §2.3 (d) 'EXTERNAL-BENCHMARK AVAILABILITY' and (e) 'PROPOSED FALSIFIER SKETCH'.\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_90.md` §1 closing_note — the multi-turn continuity rationale.\n4. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/universal_theorem_status.md` — internal Lemma 1 General-S closed-form derivation history; Iter 2 update has the canonical formula. Also lists rank-2 vanishing proof.\n5. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/universal_structure_u1u4_2026_05_13.md` — U1-U4 internal verification cascade including IcosahedralMod cross-check.\n6. `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` (if present) — the paper-side Lemma 1 General-S document; gives the canonical formula statement and known-verified cases.\n7. `/home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl` — 26/26 PASS internal regression; structurally what T91 is augmenting with external published reference data.\n8. (OPTIONAL) `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/kawaguchi-ueda-2012.md` (T10 prior reference per T69 §2.3 (d) [depth: ... by_tag/kawaguchi-ueda-2012.md confirms T10 prior reference]).\n\n## EXTRACTION TARGETS (priority order)\n\n### Primary: Kawaguchi-Ueda 2012 §4 (arXiv:1001.2072)\n\nWebFetch the arXiv abstract page first to confirm publication metadata (Phys. Rep. 520, 253-381; DOI: 10.1016/j.physrep.2012.07.005; submitted 2010, published 2012). Then WebFetch the arXiv full PDF or HTML version. §4 of the review tabulates β_S channel weights for F=2 polyhedral inert states. Target the F=2 cyclic (= tetrahedral A_1) state specifically.\n\nExtract:\n- β_S^(c_0) numerical or rational values for S ∈ {0, 2, 4} (the allowed S channels at F=2 are S=0, 2, 4 per even-rank polyhedral selection rule).\n- The defining normalization convention KU2012 uses for β_S^(c_0) (typically `g_S = (4πℏ²/M) a_S` per channel; β_S^(c_0) is the coefficient of g_S in the mean-field energy density per atom, after channel decomposition).\n- The F=2 state's spinor representative in m-basis (cyclic state is ψ_cyclic ∝ (1, 0, i√2, 0, 1) / √(some normalization); confirm against KU2012).\n- Any Bogoliubov spectrum / spin-stiffness data in §4 that relates to β_S^(λ_spin) channels — these are the cross-check data for T92.\n\n### Secondary: Stamper-Kurn & Ueda 2013 §IV (Rev. Mod. Phys. 85, 1191)\n\nWebFetch the RMP article (DOI: 10.1103/RevModPhys.85.1191) or arXiv equivalent if available. §IV covers F=2 spinor BEC including Bogoliubov spectra of tetrahedral / cyclic states.\n\nExtract:\n- Same β_S^(c_0) table for F=2 cyclic-tetrahedral A_1 (independent extraction; should match KU2012 modulo normalization convention).\n- Bogoliubov-spectrum / λ_spin-stiffness-channel data for F=2 cyclic that lets T92 cross-check β_S^(λ_spin) directly (not just via Lemma 1 transform).\n- Any errata or normalization conventions documented in this later review.\n\n### Tertiary (only if Primary or Secondary is paywalled/unreadable): Uchino-Kobayashi-Ueda 2010 (arXiv:0912.0355)\n\nF=1 and F=2 LHY-explicit forms. Provides a third independent extraction for F=2 polar / cyclic LHY (related but not identical channel structure).\n\n## REQUIRED OUTPUT — `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_91.md`\n\nFile MUST include these sections in this order:\n\n```markdown\n---\nturn: 91\nsubagent: researcher\ndepth: shallow\ninvestigation_id: sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18\nstage_advancing_to: Research\ntopic_tags: [...]\nproduces: ...\n---\n\n# Turn 91 — Researcher Report (depth=shallow): KU2012 §4 + SKU2013 §IV F=2 tetrahedral A_1 channel-weight extraction\n\n## 1. Queries received\n[paste director brief succinctly]\n\n## 2. WebFetch / WebSearch log\n[bullet list: URL → status (200/paywalled/redirect/timeout) → tokens spent → extraction result yes/no]\nMust be honest: if KU2012 PDF was paywalled, say so; if arXiv 1001.2072v1 differed from published Phys. Rep. version, note the version used.\n\n## 3. KU2012 §4 extraction\n### 3.1 F=2 cyclic-tetrahedral state spinor representation in m-basis\n[explicit (ψ_+2, ψ_+1, ψ_0, ψ_-1, ψ_-2) normalized representation per KU2012; cite eq number if numbered]\n\n### 3.2 β_S^(c_0) channel-weight values at F=2\n[table: S | β_S^(c_0)_KU2012 | KU2012 normalization | KU2012 eq number]\n| S | β_S^(c_0) | normalization | KU2012 reference |\n|---|---|---|---|\n| 0 | <extracted> | g_S = ... | Eq (X.Y) |\n| 2 | <extracted> | g_S = ... | Eq (X.Y) |\n| 4 | <extracted> | g_S = ... | Eq (X.Y) |\n\n### 3.3 Bogoliubov / λ_spin-channel data (if available in §4)\n[any direct β_S^(λ_spin)-related quantities, e.g. spin-stiffness ρ_s^(S), Bogoliubov dispersions ω_S(k), per-channel sound velocities c_S]\n\n## 4. SKU2013 §IV extraction\n### 4.1 F=2 cyclic-tetrahedral A_1 spinor representation\n[independent extraction, note if differs from KU2012]\n\n### 4.2 β_S^(c_0) channel-weight values at F=2 (cross-check with §3.2)\n[same table format; flag any discrepancy with KU2012]\n\n### 4.3 Bogoliubov / λ_spin-channel data\n[independent extraction]\n\n## 5. UKU2010 extraction (only if needed)\n[brief structured table if relevant]\n\n## 6. Cross-reference table — Lemma 1 closed-form prediction vs extracted external values\n[table: S | β_S^(c_0)_KU2012 | β_S^(c_0)_SKU2013 | (S(S+1) − 2F(F+1))/(2F(F+1)) at F=2 | β_S^(λ_spin)_predicted_via_Lemma_1 | β_S^(λ_spin)_extracted_or_derivable | match? | normalization_caveat]\n| S | β_S^(c_0) KU | β_S^(c_0) SKU | factor | β_S^(λ_spin) pred | β_S^(λ_spin) ext | match |\n|---|---|---|---|---|---|---|\n| 0 | ... | ... | (0 − 12) / 12 = -1 | -1 × β_0^(c_0) | <if extractable> | yes/no |\n| 2 | ... | ... | (6 − 12) / 12 = -1/2 | -1/2 × β_2^(c_0) | <if extractable> | yes/no |\n| 4 | ... | ... | (20 − 12) / 12 = 2/3 | 2/3 × β_4^(c_0) | <if extractable> | yes/no |\n\n(Verify the Lemma 1 prefactor (S(S+1) − 2F(F+1))/(2F(F+1)) at F=2 — F(F+1)=6 so 2F(F+1)=12.)\n\n## 7. Convention reconciliation notes\n[any sign / normalization / factor-of-2 caveats between KU2012, SKU2013, and project — these are CRITICAL for T92 Hypothesize to interpret the match/mismatch correctly]\n\n## 8. Provisional verdict (researcher; binding verdict comes from critic Update at T93)\n[one of: TABLES_EXTRACTED_CLEAN (T92 can directly apply Lemma 1); TABLES_EXTRACTED_WITH_CONVENTION_CAVEATS (T92 must reconcile first); TABLES_NOT_TABULATED_FORMULAIC_ONLY (T92 must do symbolic comparison); TABLES_PAYWALLED_OR_INACCESSIBLE (escalate to researcher_deep or anko-manual)]\n\n## 9. Recommended T92 Hypothesize scope\n[concrete: which channels to compare; expected match precision; failure modes to test]\n\n## 10. Metrics JSON\n[fenced ```json``` block per the schema in §METRICS below]\n```\n\n## METRICS JSON (single fenced ```json``` block in research/turn_91.md §10)\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"investigation_kind\": \"physics\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"agents_md_files_modified\": 0,\n  \"patterns_yaml_modified\": false,\n  \"state_json_modified\": false,\n  \"manuscript_edited\": false,\n  \"src_edited\": false,\n  \"julia_executed\": false,\n  \"investigation_id\": \"sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18\",\n  \"stage_advancing_to\": \"Research\",\n  \"flow_template\": \"verify-claim\",\n  \"researcher_depth\": \"shallow\",\n  \"web_fetches_attempted\": <int>,\n  \"web_fetches_successful\": <int>,\n  \"external_papers_extracted_count\": <int; 1 if only KU2012, 2 if KU2012+SKU2013, 3 if +UKU2010>,\n  \"external_papers_extracted_list\": [\"<arxiv id or DOI strings>\"],\n  \"ku2012_section_4_accessed\": <true|false>,\n  \"sku2013_section_IV_accessed\": <true|false>,\n  \"f2_cyclic_state_spinor_extracted\": <true|false>,\n  \"beta_s_c0_extracted_for_S_0_2_4\": <true|false>,\n  \"beta_s_c0_S0_value\": <numeric or rational string or null>,\n  \"beta_s_c0_S2_value\": <numeric or rational string or null>,\n  \"beta_s_c0_S4_value\": <numeric or rational string or null>,\n  \"normalization_convention_documented\": <true|false>,\n  \"bogoliubov_or_lambda_spin_channel_data_present\": <true|false>,\n  \"cross_reference_table_filled\": <true|false>,\n  \"lemma1_prefactor_evaluated_at_F2_S0\": -1.0,\n  \"lemma1_prefactor_evaluated_at_F2_S2\": -0.5,\n  \"lemma1_prefactor_evaluated_at_F2_S4\": 0.6666666666666666,\n  \"convention_caveats_documented\": <true|false>,\n  \"provisional_verdict\": <\"TABLES_EXTRACTED_CLEAN\"|\"TABLES_EXTRACTED_WITH_CONVENTION_CAVEATS\"|\"TABLES_NOT_TABULATED_FORMULAIC_ONLY\"|\"TABLES_PAYWALLED_OR_INACCESSIBLE\">,\n  \"recommended_t92_hypothesize_scope_described\": <true|false>,\n  \"t69_section_2_3_canonical_anchors_re_verified\": <true|false>,\n  \"references_cited_count\": <int>,\n  \"references_cited_list\": [<list of refs cited>],\n  \"no_invention\": <true|false; true means every numerical value cited has a source>\n}\n```\n\n## CONSTRAINTS\n\n- **Files allowed to modify**: `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_91.md` ONLY (the research turn report).\n- **Files allowed to create**: `/tmp/*` (one-shot helpers, e.g. PDF caching scripts).\n- **Files FORBIDDEN to modify**: `src/`, `runs/eu151_*/`, `runs/matsui_edh_baseline_*/`, `scripts/`, `docs/manuscript/`, `runs/_loop/state.json`, `.claude/agents/*`, `.claude/scripts/*`, `.claude/workload_specs.yaml`, `quota_config.json`, `.claude/settings*.json`, `runs/_loop/patterns.yaml`, any other `runs/_loop/` file (including theorist/, sim/, critic/, judge/, director/).\n- **No julia execution**. No GPU.\n- **No new memory file** (the existing `tier3_pipeline_survey_2026_05_18.md` already references this candidate; Sign-Pattern-Lemma1-Tier-3 memory entry will be created at T94 Document if Tier-3 closure achieved).\n- **English only**. No emojis. No anko-attribution. No improvised terminology — use KU2012/SKU2013 standard physics terms ('channel weight', 'cyclic state', 'tetrahedral A_1', 'Bogoliubov spectrum', 'spin stiffness ρ_s', etc.).\n- **No fabrication** (CRITICAL): every numerical β_S^(c_0) value MUST cite the exact equation number from KU2012 or SKU2013. If unable to extract via WebFetch (paywall, complex PDF tables, etc.), HONESTLY report \"TABLES_PAYWALLED_OR_INACCESSIBLE\" and flag for escalation — do NOT guess values from internal Lemma 1 formula and present as 'extracted'.\n- **Absolute paths in all Read / Write / Bash tool calls**.\n- **Cost budget**: stay within ~1.5M effective tokens; hard cap 2.5M. researcher_shallow baseline ~1M; +WebFetch budget ~0.5M; +structured output ~0.3M.\n- **WebFetch discipline**: try arXiv abstract pages first (cheap, fast), then full PDFs only if needed. KU2012 arXiv:1001.2072 may have multiple versions (v1, v2, v3); use the most recent. SKU2013 may not be on arXiv (RMP-only); try DOI first.\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT modify src/, manuscript, state.json, .claude/agents/scripts, agent prompts, patterns.yaml.\n- Do NOT execute julia.\n- Do NOT invent β_S^(c_0) values — if extraction fails, report TABLES_PAYWALLED_OR_INACCESSIBLE.\n- Do NOT do theorist's job (do NOT apply Lemma 1 formula and write the Tier-3 verification verdict; that is T92 theorist's job; T91 researcher provides the input data only).\n- Do NOT do critic's job (do NOT independently re-derive Lemma 1 from 6j-symbols; that is T93 critic's job).\n- Do NOT extend to F=1 / F=3 / F=6 / F=8 / F=10 extraction (out of scope; T91 is F=2 only; if F=2 lands clean, T92+ may extend).\n- Do NOT generate Bogoliubov spectra ourselves; extract what KU2012 / SKU2013 PROVIDE only.\n- Do NOT exceed 2.5M effective tokens hard cap.\n\n## REPORTING DISCIPLINE\n\n- If WebFetch for KU2012 §4 returns paywall/redirect/timeout > 2 attempts, mark `ku2012_section_4_accessed: false` and `provisional_verdict: TABLES_PAYWALLED_OR_INACCESSIBLE`, escalate.\n- If KU2012 §4 returns text but the F=2 cyclic-tetrahedral A_1 state's β_S^(c_0) values are derivation-only-no-numerical-table (formulaic only), mark `provisional_verdict: TABLES_NOT_TABULATED_FORMULAIC_ONLY` and extract the symbolic formulas instead — this is still useful (Tier 3 via closed-form match).\n- Honest counts only — every WebFetch attempt logged with status; every claimed value cited to a paper equation.\n- If you discover that KU2012 §4 uses a DIFFERENT canonical state for 'F=2 tetrahedral' than the project (e.g., biaxial nematic vs cyclic), document the divergence and flag for T92 reconciliation.\n",
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
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "researcher_depth",
      "web_fetches_attempted",
      "web_fetches_successful",
      "external_papers_extracted_count",
      "external_papers_extracted_list",
      "ku2012_section_4_accessed",
      "sku2013_section_IV_accessed",
      "f2_cyclic_state_spinor_extracted",
      "beta_s_c0_extracted_for_S_0_2_4",
      "beta_s_c0_S0_value",
      "beta_s_c0_S2_value",
      "beta_s_c0_S4_value",
      "normalization_convention_documented",
      "bogoliubov_or_lambda_spin_channel_data_present",
      "cross_reference_table_filled",
      "lemma1_prefactor_evaluated_at_F2_S0",
      "lemma1_prefactor_evaluated_at_F2_S2",
      "lemma1_prefactor_evaluated_at_F2_S4",
      "convention_caveats_documented",
      "provisional_verdict",
      "recommended_t92_hypothesize_scope_described",
      "t69_section_2_3_canonical_anchors_re_verified",
      "references_cited_count",
      "references_cited_list",
      "no_invention"
    ],
    "optional": [],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_91.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_69.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_90.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/state.json && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/universal_theorem_status.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/universal_structure_u1u4_2026_05_13.md && python3 -c \"import json; d = json.load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/state.json')); inv = d['investigations']; tier3_open = [k for k,v in inv.items() if v.get('current_stage')=='closed' and v.get('tier_current')==3.0]; print(f'closed-tier3-investigations: {tier3_open}'); print(f'edh-matsui-closed: {inv[\\\"edh-eu151-vortex-vs-matsui-science-2026\\\"][\\\"current_stage\\\"]==\\\"closed\\\"}'); print(f'survey-closed: {inv[\\\"tier3-verification-pipeline-survey-2026-05-18\\\"][\\\"current_stage\\\"]==\\\"closed\\\"}'); print('OK precondition: parent survey closed at T90; T91 ready to spawn child investigation via Research stage dispatch')\""
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "text_only",
      "tolerance": null,
      "rationale": "Research stage is WebFetch + extraction; no execution."
    },
    {
      "id": "investigation_kind_physics",
      "metric": "investigation_kind",
      "operator": "==",
      "value": "physics",
      "tolerance": null,
      "rationale": "Sign Pattern Lemma 1 is a physics theory verification investigation."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Research stage does not modify src/."
    },
    {
      "id": "no_scripts_committed",
      "metric": "new_analysis_scripts_written",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "/tmp/ helpers do not count; no scripts/."
    },
    {
      "id": "no_agents_md_changes",
      "metric": "agents_md_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Research stage does not modify agent prompts."
    },
    {
      "id": "patterns_yaml_untouched",
      "metric": "patterns_yaml_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Research stage is unrelated to patterns.yaml audit catalog."
    },
    {
      "id": "state_json_untouched_by_researcher",
      "metric": "state_json_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Researcher does not edit state.json; orchestrator handles investigation entry spawn from director contract."
    },
    {
      "id": "no_manuscript_polish",
      "metric": "manuscript_edited",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Per feedback_manuscript_is_not_the_essence."
    },
    {
      "id": "no_src_modification_explicit",
      "metric": "src_edited",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Redundant src/ guard."
    },
    {
      "id": "no_julia_execution",
      "metric": "julia_executed",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "Research stage text-only."
    },
    {
      "id": "investigation_consistent",
      "metric": "investigation_id",
      "operator": "==",
      "value": "sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18",
      "tolerance": null,
      "rationale": "Researcher report must echo investigation_id from director contract."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Research",
      "tolerance": null,
      "rationale": "Researcher report must echo Research from director contract."
    },
    {
      "id": "template_consistent",
      "metric": "flow_template",
      "operator": "==",
      "value": "verify-claim",
      "tolerance": null,
      "rationale": "verify-claim template per §F1."
    },
    {
      "id": "depth_consistent",
      "metric": "researcher_depth",
      "operator": "==",
      "value": "shallow",
      "tolerance": null,
      "rationale": "Director specified shallow per §F1 cost discipline (T69 already did canonical-source identification; T91 only extracts)."
    },
    {
      "id": "min_one_external_paper_extracted",
      "metric": "external_papers_extracted_count",
      "operator": ">=",
      "value": 1,
      "tolerance": null,
      "rationale": "At minimum KU2012 OR SKU2013 OR UKU2010 must yield extractable channel-weight data. If 0, investigation hits TABLES_PAYWALLED_OR_INACCESSIBLE failure_mode."
    },
    {
      "id": "lemma1_prefactor_S0_correct",
      "metric": "lemma1_prefactor_evaluated_at_F2_S0",
      "operator": "==",
      "value": -1.0,
      "tolerance": 1e-12,
      "rationale": "(0(0+1) - 2*2*(2+1)) / (2*2*(2+1)) = (0 - 12)/12 = -1 exact. Direct algebra check that researcher correctly evaluated the Lemma 1 prefactor at F=2, S=0."
    },
    {
      "id": "lemma1_prefactor_S2_correct",
      "metric": "lemma1_prefactor_evaluated_at_F2_S2",
      "operator": "==",
      "value": -0.5,
      "tolerance": 1e-12,
      "rationale": "(2(2+1) - 2*2*(2+1)) / (2*2*(2+1)) = (6 - 12)/12 = -1/2 exact. Direct algebra check at F=2, S=2."
    },
    {
      "id": "lemma1_prefactor_S4_correct",
      "metric": "lemma1_prefactor_evaluated_at_F2_S4",
      "operator": "==",
      "value": 0.6666666666666666,
      "tolerance": 1e-12,
      "rationale": "(4(4+1) - 2*2*(2+1)) / (2*2*(2+1)) = (20 - 12)/12 = 8/12 = 2/3 = 0.6666... exact. Direct algebra check at F=2, S=4."
    },
    {
      "id": "cross_reference_table_populated",
      "metric": "cross_reference_table_filled",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "The §6 cross-reference table is the load-bearing T92 input deliverable."
    },
    {
      "id": "convention_caveats_recorded",
      "metric": "convention_caveats_documented",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Sign / normalization / factor-of-2 caveats between KU2012, SKU2013, and project are CRITICAL for T92 Hypothesize."
    },
    {
      "id": "verdict_classification_set",
      "metric": "provisional_verdict",
      "operator": "in",
      "value": ["TABLES_EXTRACTED_CLEAN", "TABLES_EXTRACTED_WITH_CONVENTION_CAVEATS", "TABLES_NOT_TABULATED_FORMULAIC_ONLY", "TABLES_PAYWALLED_OR_INACCESSIBLE"],
      "tolerance": null,
      "rationale": "Researcher classifies the extraction outcome into one of 4 named verdicts; routes T92 director."
    },
    {
      "id": "t92_scope_recommended",
      "metric": "recommended_t92_hypothesize_scope_described",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "T92 director needs explicit scope handoff from T91 researcher."
    },
    {
      "id": "t69_canonical_anchors_re_verified",
      "metric": "t69_section_2_3_canonical_anchors_re_verified",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Researcher must confirm KU2012/SKU2013 are still the canonical anchors before doing extraction; sanity guard."
    },
    {
      "id": "min_references_cited",
      "metric": "references_cited_count",
      "operator": ">=",
      "value": 3,
      "tolerance": null,
      "rationale": "T69 §2.3 (~5 references), internal memory + paper3 doc + at least one external paper = ≥3."
    },
    {
      "id": "no_invention_enforced",
      "metric": "no_invention",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Every numerical value MUST cite an external source equation number; no fabrication."
    }
  ],
  "failure_modes": [
    {
      "if": "provisional_verdict == 'TABLES_PAYWALLED_OR_INACCESSIBLE'",
      "category": "data_gap",
      "next_action": "T92 director: upgrade researcher_depth to `deep` (re-dispatch researcher_deep with explicit PDF mirror search + cross-citation graph; ~4.5M budget) OR pivot to UKU2010 (arXiv:0912.0355) tertiary anchor if it has F=2 data."
    },
    {
      "if": "provisional_verdict == 'TABLES_NOT_TABULATED_FORMULAIC_ONLY'",
      "category": "scientific_partial",
      "next_action": "T92 director: dispatch theorist Hypothesize with extracted symbolic formulas; theorist evaluates symbolically at F=2 and compares to Lemma 1 closed-form structurally; still a valid Tier-3 path (closed-form match rather than numerical table match)."
    },
    {
      "if": "provisional_verdict == 'TABLES_EXTRACTED_WITH_CONVENTION_CAVEATS'",
      "category": "scientific_partial",
      "next_action": "T92 director: dispatch theorist Hypothesize with explicit convention-reconciliation step (e.g., factor-of-2 between KU2012 g_S and project g_S; sign convention on β_S definition); Tier-3 closure achievable but needs reconciliation note in T93 critic Update."
    },
    {
      "if": "external_papers_extracted_count == 0 (BOTH KU2012 AND SKU2013 AND UKU2010 inaccessible)",
      "category": "data_gap",
      "next_action": "T92 director: escalate to anko-manual extraction or institutional library access; mark investigation blocked_on='external_paper_inaccessible'; pivot to next T69 menu candidate (Bug-4 ITP DDI half-rate revalidation, §2.2)."
    },
    {
      "if": "lemma1_prefactor_evaluated_at_F2_S0 != -1.0 OR lemma1_prefactor_evaluated_at_F2_S2 != -0.5 OR lemma1_prefactor_evaluated_at_F2_S4 != 2/3",
      "category": "operational",
      "next_action": "T92 director: re-dispatch researcher with explicit prefactor derivation requirement; this is a basic algebra sanity check that catches if the researcher mis-applied the Lemma 1 formula at F=2."
    },
    {
      "if": "no_invention == false (researcher cited a β_S value without an equation number reference)",
      "category": "framework_error",
      "next_action": "T92 director: re-dispatch researcher with stricter no-invention guard; the unfounded value is invalidated and treated as missing data."
    },
    {
      "if": "cross_reference_table_filled == false (the §6 table is empty or only partially filled)",
      "category": "operational",
      "next_action": "T92 director: re-dispatch researcher specifically for table completion; T91 deliverable is incomplete."
    },
    {
      "if": "F=2 cyclic-tetrahedral state in KU2012 / SKU2013 turns out to be a DIFFERENT state than the project's tetrahedral A_1 (e.g., biaxial nematic in KU2012 = cyclic in project)",
      "category": "scientific_partial",
      "next_action": "T92 director: theorist Hypothesize includes explicit state-identification reconciliation; the polyhedral inert state landscape at F=2 has multiple A_1 representatives (per Universal Structure U1-U4 classification); pick the matching one or document the gap."
    },
    {
      "if": "cost > 2.5M effective (hard cap exceeded)",
      "category": "operational",
      "next_action": "T92 director: audit researcher's WebFetch budget usage; if PDF caching overhead inflated cost, instruct T92+ researchers to use arXiv abstract pages + targeted equation extraction queries rather than full-PDF dumps."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2500000,
    "wall_time_max_seconds": 600
  },
  "budget": {
    "expected_cost_eff": 1500000,
    "expected_wall_time_sec": 480,
    "split_by_subtask": {
      "context_read_t69_t90_director_memory": 300000,
      "ku2012_webfetch_section_4_extraction": 500000,
      "sku2013_webfetch_section_IV_extraction": 400000,
      "uku2010_optional_tertiary_extraction": 100000,
      "cross_reference_table_construction": 100000,
      "research_turn_91_md_write": 100000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Hypothesize",
    "if_success_tier_becomes": 2,
    "if_partial_success_advance_to_stage": "Hypothesize (T92 with explicit reconciliation scope)",
    "if_partial_success_tier_becomes": 2,
    "if_refuted_advance_to_stage": "n/a (Research stage produces extraction data, not refutation)",
    "if_refuted_tier_becomes": 2,
    "if_inconclusive_advance_to_stage": "Research (T92 researcher_deep retry)",
    "if_inconclusive_tier_becomes": 2,
    "if_data_gap_advance_to_stage": "Research (T92 researcher_deep retry OR pivot to next T69 menu candidate)",
    "if_data_gap_tier_becomes": 2,
    "next_falsifier_to_test_after": "F1=KU2012-F2-cyclic-channel-weight-match-within-1pct (to be tested at T93 critic Update after T92 theorist Hypothesize)"
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json (active_investigation_id, investigations_index lines 1812-1824, edh-eu151-vortex-vs-matsui closed entry lines 2399-2479, tier3-verification-pipeline-survey closed entry lines 2365-2398, meta investigations entries) + scheduler_91.json + seed.md (stale 2026-05-15 morning, klaus-julia-ban no longer active per probe) THIS turn.
- [x] Read judge/turn_90.json (T90 PASS verdict 27/27) + sim/turn_90.md (predecessor closure shape) + director/turn_90.md §1 closing_note (multi-turn continuity recommendation).
- [x] Read research/turn_69.md §2.3 entirely (the candidate identification) + memory/tier3_pipeline_survey_2026_05_18.md (the parent survey methodology including Outcome closure section) + memory/universal_theorem_status.md (internal Lemma 1 General-S history).
- [x] APC contract cache checked (`.claude/cache/contract_templates.json`): physics::verify-claim::Hypothesize n_seen=4 (T30, T44, T56, T72 — useful as T92 prep). physics::verify-claim::Research n_seen<2 (cache not authoritative); T91 builds Research contract from scratch (skeleton: researcher_depth, webfetch precondition, extracted-table observable manifest, no-invention enforcement).
- [x] Considered switching to a different investigation: meta-cost-waste-audit Hypothesize, meta-director-self-audit Hypothesize, Bug-4 ITP DDI half-rate revalidation, TDHFB Phase 2 HF kernel, TwoChannelLHY F=6 30-70% — all explicitly considered and rejected in §1 per priority/cost/rotation analysis.
- [x] investigation_id `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18` is a NEW spawn (consistent with T70 precedent for spawning child investigation from survey-menu candidate); not yet in state.json (orchestrator handles spawn from director contract).
- [x] stage_advancing_to `Research` is the FIRST stage per flow template §F1 (verify-claim: Research → Hypothesize → ... → closed); new investigation must start at Research.
- [x] subagent_type `researcher` matches role_per_stage[Research] for `verify-claim` template per §F1 ("Research: researcher — lit scan, prior loop turns, memory entries — sets up Hypothesize with citation chain").
- [x] researcher_depth `shallow` specified per §F1 mandatory field, with explicit upgrade-trigger analysis (tier_target=3 normally triggers `deep`, but T69 already did canonical-source identification work so extraction-only at `shallow` is appropriate; if shallow fails, T92 retries with `deep` per failure_mode).
- [x] success_criteria are machine-evaluable: 25 criteria, every metric appears in Metrics JSON schema in brief §METRICS JSON; mix of ==/>=/in operators on scalar/bool/list values.
- [x] failure_modes cover 9 likely failures (paywall, formulaic-only tables, convention caveats, all-papers-inaccessible, prefactor algebra error, fabrication, incomplete table, state-identification mismatch, cost overrun).
- [x] observable_manifest precondition_check is concrete (bash one-liner using test + python3 -c with state.json shape assertions; would actually run and verify precondition: parent survey closed at T90, EdH-Matsui closed, ready to spawn child).
- [x] budget fits within scheduler window_seconds_left (1.14M sec >> 600 sec wall_time_max).
- [x] §A6 research-first citation present (15 enumerated references in §4 to prior loop turns, memory files, external papers KU2012/SKU2013/UKU2010, internal scripts, contract cache).
- [x] §A5 D-axis articulated: D1 verification (PRIMARY axis) tier 2 → 3 trajectory begins; first manuscript-anchored Tier-3 claim. Manuscript NOT in scope.
- [x] investigation_update field describes spawn + Research-stage outcomes correctly: if_success advances to Hypothesize at tier 2 (Research extraction is input for T92 Hypothesize; tier doesn't bump until T93 Update CORROBORATES); if_data_gap routes to retry or pivot.
- [x] Single commitment per turn (T91 spawns investigation AND Research stage dispatch — these are one logical commitment for the new investigation's first turn; not collapsing with T92 Hypothesize).
- [x] Subagent rotation pressure (5/6 implementer_text incoming) cleared by routing T91 to researcher.
- [x] novel_claim_zero drift escalation cleared by routing T91 to extract new external β_S^(c_0) numerical values.
- [x] cost_inflation drift trend continues downward (T91 target 1.5M << T90 1.31M is not a downward delta per se, but well within steady-state band).
- [x] No fabrication possible: every value in §6 contract is either a citation to existing artifacts or a basic algebra result (Lemma 1 prefactor at F=2: -1, -1/2, 2/3) trivially verifiable.
