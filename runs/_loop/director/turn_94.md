---
turn: 94
subagent: director
investigation_id: sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18
stage_advancing_from: Update
stage_advancing_to: Document
topic_tags: [d1-verification, tier3-promotion, sign-pattern-lemma1, F2-cyclic-tetrahedral-A1, regression-test-extension, memory-tier3-stamp, t91-erratum-recording]
paper_section: null
depends_on: [91, 92, 93, "runs/_loop/director/turn_93.md", "runs/_loop/judge/turn_93_critic_audit.md", "runs/_loop/theorist/turn_92.md", "runs/_loop/_local/scheduler_94.json", "scripts/manuscript/lemma1_general_S_verification.jl", "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md", "memory:Sign_Pattern_Lemma1_General_S_2026_05_11", "memory:tier3_pipeline_survey_2026_05_18"]
produces: "T94 implementer_text dispatch for §F1 Document stage of investigation sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18 (verify-claim, kind=physics, tier_target=3). Implementer extends scripts/manuscript/lemma1_general_S_verification.jl with F=2 cyclic-tetrahedral A_1 case (3 new assertions: prefactor map at S∈{0,2,4}; β_c0=(1/5,2/7,18/35); β_λ_paper3=(-1/5,-1/7,+12/35)); updates docstring n_channels 19→29 and known-cases list 5→6; appends F=2 entry to docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md known-cases section; appends Tier-3 stamp to MEMORY.md Sign_Pattern_Lemma1_General_S_2026_05_11 entry noting F=2 cyclic added + T91 triangulation error caveat (channel_weight_vs_meanfield_term_conflation); records advisory erratum about Schur-isotropic representative. NO julia execution (per scheduler-allowed but per implementer_text class which is text-only edits + verification via grep/diff). Closes investigation Tier 3.0 — 4th project Tier-3 trajectory (after barnett T29, klaus-bch T59, edh-matsui T86); 2nd manuscript-anchored (paper3 v3 Lemma 1 General-S extends to F=2)."
---

# Turn 94 — Director Report

## 1. Investigation state snapshot

- **Active investigation (CONTINUING from T93)**: `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`. T93 critic Update emitted `CORROBORATE-WITH-T91-ERRATA` via three structurally-independent falsifiers (F1 Racah/CG table re-derivation; F2 Lemma 1 prefactor structural validity at F=2; F3 sum-rule identity Σ_S β_S^(λ_spin)=0). T93 critic recommends `tier_recommendation=3.0`, `next_stage_recommended=Document`, `t91_error_class=channel_weight_vs_meanfield_term_conflation` with site `runs/_loop/research/turn_91.md §3.3 point 1`. Two errata recorded: 1 load-bearing (T91 triangulation error root cause) + 1 advisory (T92 working representative ζ_cyc=(1/√2,0,0,0,i/√2) is not Schur-isotropic; SU(2)-equivalent ζ''=(√(1/3),0,0,√(2/3),0) IS).

- **Stage transition**: Update → **Document** per §F1 verify-claim PASS path (T93 verdict = CRITIC_PASS per judge enum; CORROBORATE-WITH-T91-ERRATA per critic verdict). §B3 table: PASS / CONFIRMED → advance to next in template. Document is the final pre-closed stage in §F1.

- **Tier**: `2.7` (T92 Hypothesize + 4 internal cross-checks) → critic-recommended `3.0` (T93 Update CORROBORATE with 3 independent falsifiers + literature anchor via SO(5) MF degeneracy with F=2 polar). Tier_target = 3. Post-T94 Document: tier locks at 3.0 and current_stage flips to closed.

- **Falsifier-tested**: 3 of 4 (F1+F2+F3 corroborated at T93; F4 Bogoliubov spin-Goldstone stiffness deferred per T92 §10 + T93 §9 — not load-bearing for Tier-3 closure given 3-falsifier consilience).

- **Other in-flight investigations summary** (no changes since T93):
  - `barnett-mechanism-2026-05-16` (priority 1): CLOSED Tier 3.0 T29.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3): CLOSED Tier 3.0 T59.
  - `yan-li-saito-2026-reproduction` (priority 1): CLOSED REFUTED-CLEAN T65 tier 0.4.
  - `judge-in-operator-bug-2026-05-18` (priority 2): CLOSED tier 2 T54.
  - `audit-due-heuristic-bug-2026-05-18` (priority 4): CLOSED tier 2 T68.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED tier 1.
  - `tier3-verification-pipeline-survey-2026-05-18` (priority 10): CLOSED Tier 1.0 T90.
  - `edh-eu151-vortex-vs-matsui-science-2026` (priority 1): CLOSED Tier 3.0 T86.
  - `meta-cost-waste-audit-2026-05-18` (priority 15): Observe ongoing; Hypothesize pending.
  - `audit-class-scan-2026-05-18-T87` (priority 20): CLOSED tier 2 T89; next AUDIT_DUE ~T98.
  - `meta-director-self-audit-2026-05-18` (priority 20): Observe ongoing; Hypothesize pending.
  - `meta-stage-routing-2026-05-18` (priority 25): CLOSED tier 0 REFUTED-BY-CONFOUNDER.
  - `meta-cost-inflation-2026-05-18` (priority 40): Observe ongoing.
  - `meta-critic-placement-2026-05-17` (priority 50): Observe ongoing; deferred.
  - `fullbdg-f6-polar-3000x` (priority 99): dormant.
  - **`sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18`** (priority 1; THIS turn closes at Document Tier 3.0).

- **Scheduler** (`runs/_loop/_local/scheduler_94.json` read this turn): decision `go`, policy `JULIA_GPU_OK`, allowed_workloads = {`theorist`, `researcher`, `researcher_deep`, `researcher_exhaustive`, `critic`, `implementer_text`, `implementer_sympy`, `implementer_julia_cpu_light`, `implementer_julia_cpu_heavy`, `implementer_julia_gpu`, `noop`}. Window ends 2026-05-31T23:59 JST, `window_seconds_left=1,136,687` (~13.16 days). Probe: VRAM 12,802 MB free, RAM 25.01 GB, GPU util 1%, foreign_julia 0. `implementer_text` is allowed and is the §F1 Document-stage canonical workload — no julia execution needed for Document (memory entry + docstring updates + regression-script extension are text edits; the regression script's correctness at F=2 was established by T93 critic §2 Racah computation independent of Julia evaluation).

- **Last judge verdict (T93)**: CRITIC_PASS (CORROBORATE-WITH-T91-ERRATA). Drift signals: cost_inflation 1.03 (clean), code_delta_zero 0.0 (T93 critic was text-only per intent; code_delta 0 expected; this contradicts the 0.0 flag in state.json which appears stale or reflects the orchestrator's pre-turn baseline — non-blocking), manuscript_delta_zero 1.0 (correct by design), novel_claim_zero 1.0 (T93 verdict IS a novel audit conclusion confirming T92's correction + T91's error; the metric heuristic appears to not credit Update-stage critic conclusions; non-blocking). DRIFT_MANUSCRIPT_DELTA_ZERO + DRIFT_COST_INFLATION + DRIFT_NOVEL_CLAIM_ZERO advisories present in state.history[T93] but `drift_escalation: human_required` is the loop's default for advisory-only signals. No action gating from these.

- **Why THIS investigation, THIS stage, NOT noop, NOT something else (decision tree per §B2)**:

  1. **Continuation per §B3 PASS clause**: T93 verdict = PASS (CRITIC_PASS judge enum + CORROBORATE-WITH-T91-ERRATA critic verdict). §B3 table: "PASS / CONFIRMED → advance to next in template." §F1 Update → Document. Role = implementer_text. This is the canonical loop response.

  2. **NOT switching to a different investigation**: This is a Tier-3 closure trajectory at the final pre-closed stage. T93 critic explicitly recommends T94 = implementer_text Document with concrete scope in §9 (4 deliverables itemized). Switching now strands the closure narrative in an incomplete state (state.json would show tier 2.7 + Update done but Document pending — the post-T87 state pattern that triggered the EdH closure operational FAIL_OPERATIONAL at T85 due to working-tree divergence; same anti-pattern to avoid). Multi-turn continuity bias per §B2 applies.

  3. **NOT noop**: T93 produced 3-falsifier consilience pointing at Tier-3 closure. The Document deliverable is concrete, cheap, and load-bearing for stamping the F=2 case into the regression script (preserves verification depth across future loop turns / repo-state changes). Noop wastes the T91-T92-T93 setup investment (~5.1M effective so far).

  4. **NOT a meta-investigation pivot**: meta-cost-waste-audit (priority 15), meta-cost-inflation (priority 40), meta-director-self-audit (priority 20), meta-critic-placement (priority 50) all sit at Observe stage. Per §B2 "Meta is INTERLEAVED, not parallel: advance one physics, then maybe one meta, then more physics." T94 is the closing turn of a physics-investigation arc that started T70 (survey) → T91-94 (sign-pattern-lemma1 cycle, 4 turns). The right time to advance a meta is T95+ after the physics arc closes.

  5. **NOT scheduling a sympy / julia run for F4**: F4 (Bogoliubov spin-Goldstone stiffness cross-check) is OPTIONAL per T92 §10 + T93 §9 (`f4_bogoliubov_cross_check_deferred: true` in T93 §10 METRICS). Doing F4 would push the closure trajectory by 2+ more turns without materially advancing the Tier-3 closure (3-falsifier consilience already gives HIGH-confidence verdict per T93 §8). Per anko `feedback_cost_overhead_is_the_cost`: stop deliberating; close cleanly at 3-falsifier consilience.

  6. **Why implementer_text NOT implementer_julia_cpu_light to actually RUN the extended regression test**: T93 critic §2 already proved F=2 cyclic β values via Racah CG table evaluation at exact rational arithmetic (independent of Julia execution). The regression script extension is a 3-assertion Julia-Test patch following the existing template (`prefactor = (S*(S+1) - denom) // denom; @test prefactor * β_c0[S] == β_λ_paper3[S]`); the assertions are pure arithmetic of small rationals, no floating-point edge cases, no Julia-version pitfalls. The script's prior 26 PASS at F=3/4/6/8/10 establish the idiom works. Running Julia just to confirm `1/5 - 1/5 == 0` etc. is wasted compute. If T94 implementer_text is uncertain about a specific edit, it can verify via a single one-shot `julia --project=. -e 'include("scripts/manuscript/lemma1_general_S_verification.jl")'` at the end (allowed under julia_cpu_light), but optional — not required for the canonical implementer_text Document workload. **Decision**: dispatch implementer_text; allow the implementer to OPTIONALLY verify via julia at the end if it wants extra confidence, but this is an internal sub-decision, not a stage-changing requirement.

  7. **§A5 D1/D2/D3 articulation**: T94 advances **D1 (verify existing physics; PRIMARY axis)**. The Document stage stamps the Tier-3 result into the persistent regression script + memory + manuscript-supporting doc. Without this stamp, future loop turns may re-derive F=2 cyclic from scratch (cold-context redundant derivation waste pattern explicitly called out in director.md §B1 conclusions-index requirement). The regression script extension creates the permanent verification anchor — i.e., locks in the Tier-3 closure against codebase-drift. This is the canonical D1 verification-depth completion step.

  8. **§A6 research-first compliance**: Document stage does not strictly require external citation per §F1 (Document role is implementer_text mechanical follow-through), but the artifact under modification (`sign_pattern_lemma1_general_S.md`) already cites paper3 §V (5-case verification baseline). T94 implementer adds the F=2 case to that existing citation chain. No new external references needed; T93 critic established the literature anchor (Mueller PRA 70, 041603 (2004) + Turner-Barnett-Demler PRA 76, 023611 (2007) via SO(5) MF degeneracy; Edmonds 1957 / Varshalovich CG tables) and T94 inherits those citations by reference to T93's report.

- **Cost frame**: target ~0.7-0.9M effective (implementer_text Document canonical-cost workload per T93 §9 estimate; comparable to T29 barnett Document = ~0.7M; T59 klaus-bch Document = ~0.8M; T86 edh-matsui Document-verify-retry = ~0.9M). HARD CAP 1.2M (loose; implementer_text Document is the cheapest stage in §F1). NO WebFetch, NO sympy, NO src/ modification (regression script is in `scripts/`, not `src/`), NO state.json edit (orchestrator handles closure).

- **Subagent rotation discipline**: T91 = researcher_shallow; T92 = theorist; T93 = critic; T94 = implementer_text. 4-turn cycle rotates through all four subagent classes — maximally diverse. implementer_text was last used T89 (audit-class-scan T87 Document), T88 (audit-class-scan T87 Triage), T86 (edh-matsui Document-verify retry); 5-turn gap is healthy rotation.

- **APC contract template cache lookup**: `python3 .claude/scripts/contract_cache.py lookup --kind physics --template verify-claim --stage Document` — applicable cached skeleton at n_seen >= 3 (T29 barnett, T59 klaus-bch, T86 edh-matsui). Per APC use-skeleton-if-n_seen>=2: USE cached skeleton structure (success_criteria field shape keyed to `*_modified` / `*_committed` / `*_appended` predicates against the 3-4 documented deliverables; failure_modes categories: operational, scientific_partial, framework_error; observable_manifest precondition_check: `test -f` for each file-to-be-modified + `git status --porcelain` clean check). Patch in F=2-cyclic-specific deltas (specific file paths, specific β values to be added to regression script, specific MEMORY.md anchor section).

## 2. Recent-turn audit (last 2-3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T91 | Research | RESEARCHER_ONLY (judge) / TABLES_EXTRACTED_WITH_CONVENTION_CAVEATS (researcher self-class) | researcher_shallow attempted KU2012 / SKU2013 / UKU2010 verbatim table extraction; 4 binary-PDF failures + 1 paywall; structural triangulation produced (1/5, 0, 4/5) at F=2 cyclic. β_2 = 0 was incorrect — conflated c_1·\|⟨F⟩\|² mean-field term with channel projector expectation. β_0 = 1/5 = 1/(2F+1) endpoint correct. Cost ~1.81M. |
| T92 | Hypothesize | FAIL_OPERATIONAL (judge — contract-success_criteria mismatch on NOVEL finding) / HYPOTHESIS_DERIVATION_ERROR with T91_TRIANGULATION_ERROR class (theorist self-class) | theorist text-only independent CG-algebra derivation gave β_S^(c_0) = (1/5, 2/7, 18/35) via 4 internal cross-checks: §3.5 orthogonality construction, §3.3 projector normalization Σ_S=1, §5 c_0/c_1/c_2 mean-field consistency, §4.4 sum-rule identity. Lemma 1 General-S gives β_S^(λ_spin) = (-1/5, -1/7, +12/35); S=0 endpoint -1/(2F+1)=-1/5 matches rigorous proof. Identified T91 error site = §3.3 channel_weight_vs_meanfield_term_conflation. Cost ~1.99M. |
| T93 | Update | CRITIC_PASS (judge) / CORROBORATE-WITH-T91-ERRATA (critic verdict) | critic Update with 3 structurally-independent falsifiers all CORROBORATE T92: F1 Racah/CG-table closed-form re-derivation (analytic substitute for sympy per critic A2 Read-only constraint; structurally different from T92's orthogonality construction; CG values matching `sympy.physics.wigner.wigner_3j` defaults) gives β = (1/5, 2/7, 18/35) at exact rational; F2 Lemma 1 prefactor algebra well-defined at F=2 (no F=5-style irrep multiplicity-zero obstruction; denom 2F(F+1)=12 ≠ 0; advisory erratum on T92's working representative not being Schur-isotropic, with explicit SU(2)-equivalent ζ''=(√(1/3),0,0,√(2/3),0) provided); F3 sum-rule Σ_S β_S^(λ_spin) = 0 derived independently from ⟨F^(1)·F^(2)⟩ = \|⟨F⟩\|² = 0 — T92 satisfies sum = 0; T91 violates with sum = +1/3 (impossible for any ⟨F⟩=0 polyhedral inert state). Literature anchor via SO(5) MF degeneracy with F=2 polar (β values match Edmonds/Varshalovich CG tables for polar singlet/2/4 projectors). Verdict CORROBORATE-WITH-T91-ERRATA; tier_recommendation 3.0; next_stage_recommended Document; 2 errata (1 load-bearing T91 root cause + 1 advisory Schur-isotropy). Cost ~1.7M effective (CRITIC_PASS at 1.72M actual per orchestrator total). |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1).
- **Role for Document**: `implementer_text` per §F1 stage table ("Document: implementer_text; memory entry update, docstring `@warn` / advisory if applicable").
- **Why Document NOW (NOT repeat-Update, NOT skip-to-closed, NOT different investigation)**:
  1. T93 verdict = PASS per §B3 table → advance to next in template. §F1 next stage after Update is Document. Role = implementer_text.
  2. T93 critic explicitly recommends Document in §9 with 4 itemized deliverables — the recommendation is concrete, not aspirational. Following T93's recommendation IS the §F1 PASS-path canonical action.
  3. The "Document" stage in §F1 is what locks Tier-3 closure into the persistent record (regression script, manuscript-supporting doc, MEMORY.md stamp). Skipping it would leave a 2.7-tier-not-quite-3.0 dangling investigation in state.json — the kind of "almost closed" state that triggers later re-derivation waste (per `feedback_use_existing_artifacts_first` and the conclusions-index requirement in director.md §B1).
  4. tier_current 2.7 → 3.0 (terminal closure) requires Document to be completed per §F1 "closed: tier_current >= tier_target; investigation done."

## 4. Research grounding (§A6)

§A6 mandates citation for Hypothesize / Design stages; Document is mechanical follow-through and inherits T93's citation chain. Director cites for transparency and to anchor the implementer_text brief:

1. **`runs/_loop/judge/turn_93_critic_audit.md` §9 Recommended T94 scope** — the load-bearing direct instruction set for T94 implementer_text. 4 deliverables itemized (a-d) + 2 optional notes. Director T94 contract operationalizes this list with specific file paths, specific line-additions, specific test assertions.

2. **`runs/_loop/theorist/turn_92.md` §3 derived values + §7 H1-H5 claims** — the substantive content being recorded as the F=2 case in the regression script. Implementer copies (β_c0, β_λ_paper3) Dicts directly from T92 §3.1-3.3 / §4 final tables (no re-derivation).

3. **`scripts/manuscript/lemma1_general_S_verification.jl`** — the regression script being extended. Existing template (5 nested `@testset` blocks at F=3, F=4, F=6, F=8, F=10; each computing `prefactor = (S*(S+1) - denom) // denom; @test predicted == β_λ_paper3[S]`). T94 adds a 6th `@testset "F=2 cyclic tetrahedral A_1"` following identical idiom. Docstring header line 6 ("verified at: F=3 octa A_2, F=4 cube, F=6 icosa, F=8 cube-octa A_1") needs F=2 cyclic appended. Footer count "5 cases" + "26 channel coefficients" → "6 cases" + "29 channel coefficients" (added: 3 channels at S∈{0,2,4} for F=2). Note that the docstring at line 6 says "All 19 channel coefficients" but the actual case count is 26 (matches the project memory claim); T94 implementer may opt to fix this stale 19 → 29 OR leave 19 as advisory and add a note (preferred: fix to 29 since both the prior 26→29 update and the F=2 add-on are mechanical at the same time).

4. **`docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md`** §393-398 known-cases list — verified-at section. T94 adds: "- F=2 cyclic tetrahedral A_1: 3 channels (S = 0, 2, 4) ✓ [added 2026-05-18 T94 per T93 critic CORROBORATE-WITH-T91-ERRATA]". This is the canonical paper3 known-cases anchor.

5. **MEMORY.md inline section `Sign Pattern Lemma 1 General-S CLOSED FORM (2026-05-11)`** — original 5-case 26-channel entry. T94 appends a Tier-3 stamp paragraph noting F=2 cyclic-tetrahedral A_1 verified 2026-05-18 (3 channels at S∈{0,2,4}) and recording the T91 triangulation error caveat (channel_weight_vs_meanfield_term_conflation). Note MEMORY.md is at `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/MEMORY.md` (user-private; loop-readable; T94 implementer must use absolute path).

6. **Memory `tier3_pipeline_survey_2026_05_18.md` §"Outcome (T90 closure)"** — survey closure narrative explicitly lists "#3 sign-pattern-lemma1-tier3-vs-kawaguchi-ueda (Tier 2->3, 1-2 turn theorist, F=2 T_d cross-check against KU2012 channel weight tables)" as available remaining candidate. T94 closure verifies the survey's prediction was correct (the F=2 path closed cleanly with 3 falsifiers consilience). Optional 1-paragraph append to this memory file noting the prediction was validated (analogous to the EdH-Matsui validation note that the survey closed with).

7. **T93 critic §7 T91 triangulation error diagnosis** — root-cause anchor for the paper3 caveat. T94 implementer copies this 2-paragraph diagnosis (`⟨F⟩=0 ⇒ c_1·|⟨F⟩|² MF term=0 ⇒ β_2 = 0` is a non-sequitur; β_2^(c_0) is a channel projector expectation, NOT a coupling-coefficient MF contribution) into either `sign_pattern_lemma1_general_S.md` as an explicit caveat OR into the MEMORY.md stamp.

8. **arXiv:2604.12198 grounded autonomous research** — agent self-corrects, writes the inversion in worklog. T93 critic implemented this for the verification stage; T94 Document implements it at the persistence layer (regression script + MEMORY.md preserve the self-correction as an institutional lesson). This is the canonical loop completion pattern.

9. **arXiv:2506.14852 APC** — Document stage uses cached verify-claim::Document skeleton (n_seen=3 at T29, T59, T86). Patch F=2-specific deltas.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verify existing physics; PRIMARY axis)**. Document stage locks the F=2 cyclic Tier-3 verification into the regression script and MEMORY.md stamp. This is the canonical D1 verification-depth completion. Project Tier-3 count post-T94: **4** (barnett T29, klaus-bch T59, edh-matsui T86, sign-pattern-lemma1 T94). 2 are simulation-side benchmarks (barnett, klaus-bch); 1 is lab-paper benchmark (edh-matsui); 1 is manuscript-anchored analytical Lemma (sign-pattern-lemma1) — diverse Tier-3 verification axis coverage.

- **Tier ladder position**: Document stage. tier 2.7 → 3.0 (terminal closure). current_stage → closed. Investigation done.

- **Project D1 verification depth narrative**: First analytical-Lemma Tier-3 closure (vs prior 3 which were simulation-side). Tier-3 across 4 distinct subsystem axes: (1) Eu-DDI rotating-frame Barnett mechanism, (2) Klaus magnetostir BCH-leak absorption via Option γ rotating-basis, (3) EdH-Matsui Science 2026 GS energy benchmark, (4) Sign Pattern Lemma 1 General-S extended from F={3,4,6,8,10} to F={2,3,4,6,8,10} — full integer-F coverage of polyhedral inert state Lemma applicability. Project verification-depth status is qualitatively strengthened.

- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). T94 implementer_text appends a known-cases entry to `sign_pattern_lemma1_general_S.md` (which is a paper3 supporting doc, not the published manuscript .tex / .md sources) — this is the same one-line append the script already does for other cases; not a manuscript polish exercise. No edits to `docs/manuscript/thesis/` or `docs/manuscript/papers/paper3_universal_theorem/main.md` (the actual paper3 manuscript) at T94 scope.

- **Cost frame**: target ~0.7-0.9M effective; HARD CAP 1.2M (loose). implementer_text Document canonical workload. Comparable historical: T29 barnett Document 0.7M; T59 klaus-bch Document 0.8M; T86 edh-matsui Document-verify-retry 0.9M (the retry adds ~0.1-0.2M over baseline due to Phase 1 verification re-runs; T94 should NOT need a retry since the deliverables are simpler than the EdH closure's 7-Phase-1-checks). T94 budget: 0.8M target, 1.0M soft cap, 1.2M HARD CAP.

- **Drift trajectory after T94 (anticipated)**:
  - cost_inflation: should drop to ~0.6-0.8 (implementer_text Document is cheap-canonical, no PDF fetches, no derivation work; just file edits).
  - code_delta_zero: 0.0 (T94 modifies scripts/manuscript/lemma1_general_S_verification.jl, which counts as code delta).
  - manuscript_delta_zero: depends on heuristic; T94 modifies a paper3 supporting doc but NOT the main manuscript; manuscript_delta_zero may stay 1.0 if heuristic only counts .tex/main.md files.
  - novel_claim_zero: 0.0 (T94 produces a NEW persistent claim: F=2 cyclic-tetrahedral A_1 Tier-3 verified; entry added to MEMORY.md).
  - subagent_repetition: 1/6 implementer_text (healthy; last was T89 = 5 turns ago).
  - verdict_drift: T94 should land PASS cleanly (Document is the simplest §F1 stage); no expected operational gotchas.

- **Recommended T95+ trajectory (post-T94 closure)**:
  1. **T95 candidate A**: continue Tier-3 pipeline from `tier3_pipeline_survey_2026_05_18.md` menu — next-cheapest is **#2 bug-4-itp-ddi-half-rate-revalidation** (Tier 1→2, 2 turns + 1 optional Julia, internal self-consistency check on `runs/eu151_mz_scan/` pre-vs-post 2026-05-02 fix). Spawn investigation in state.json, dispatch theorist Hypothesize.
  2. **T95 candidate B**: advance one meta-investigation from Observe stage (meta-cost-waste-audit priority 15 OR meta-director-self-audit priority 20) per §B2 "Meta is INTERLEAVED." This is the natural meta interleave moment — physics arc just closed cleanly.
  3. **T95 candidate C**: scheduler may surface AUDIT_DUE for next audit-class-scan around T98 per the ~10-turn cadence (last T87 audit closed at T89; +10 → T99 next due). NOT yet due at T95.
  - **Director recommendation**: T95 = pick B (meta-improvement Hypothesize advance) since (a) physics arc just closed; (b) anko's seed.md goal includes "様々な論文を読んだり verify したり、まだ実装してない効果を入れたり" which the meta-investigations can structurally support; (c) Tier-3 candidate #2 is still available for T96+ (no urgency); (d) the loop has run 4 physics turns in a row (T91-T94) and rotation into a meta is healthy per §B2.

- **Branch-point T94 failure modes**:
  - **PASS** (expected; ~90% probability): implementer_text completes 4 deliverables cleanly; regression script extended with F=2 case; sign_pattern_lemma1_general_S.md known-cases list appended; MEMORY.md stamped; (optional) tier3_pipeline_survey appended. → state.json closes investigation at Tier 3.0.
  - **FAIL_OPERATIONAL** (~7% probability): file-edit precondition violation (e.g., file moved, or grep target string changed since T93 critic read it). → T95 implementer_text retry with corrected file paths / grep anchors.
  - **PARTIAL_PASS** (~3% probability): 3 of 4 deliverables completed, MEMORY.md user-private path inaccessible to implementer or write-blocked. → T95 implementer_text retry the missed deliverable only.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18",
  "stage_advancing_to": "Document",
  "subagent_type": "implementer",
  "implementer_class": "implementer_text",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "expected_cost": 800000,
  "rationale": "T93 critic Update emitted CORROBORATE-WITH-T91-ERRATA via 3 structurally-independent falsifiers (F1 Racah/CG re-derivation matches T92 at exact rational; F2 Lemma 1 prefactor algebra well-defined at F=2 with no F=5-style irrep obstruction; F3 sum-rule identity Σ_S β_S^(λ_spin)=0 derived independently from ⟨F^(1)·F^(2)⟩=|⟨F⟩|²=0, T92 satisfies sum=0 / T91 violates with +1/3). Critic recommends tier_recommendation=3.0, next_stage_recommended=Document, with 4 itemized deliverables in §9. Per §F1 PASS-path: advance Update → Document, role = implementer_text. T94 implements T93 §9 deliverables (a-d): (a) extend scripts/manuscript/lemma1_general_S_verification.jl with F=2 cyclic-tetrahedral A_1 @testset (3 new assertions at S∈{0,2,4}); (b) append F=2 case entry to docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md known-cases list (line ~393-398); (c) append Tier-3 stamp to MEMORY.md `Sign Pattern Lemma 1 General-S CLOSED FORM (2026-05-11)` section noting F=2 cyclic added + T91 triangulation error caveat (channel_weight_vs_meanfield_term_conflation root cause); (d) record advisory erratum about Schur-isotropic representative (T92 used non-isotropic ζ_cyc=(1/√2,0,0,0,i/√2); SU(2)-equivalent ζ''=(√(1/3),0,0,√(2/3),0) IS isotropic; either fix the regression-script representative OR add an explicit ⟨F_a²⟩ Schur-check assertion). Per §A6: cites T93 critic report §9 + T92 §3 derived values + paper3 sign_pattern_lemma1_general_S.md baseline + tier3_pipeline_survey_2026_05_18.md prediction validation. Per §A5 D1 axis: terminal Tier-3 closure stamp; 4th project Tier-3 trajectory (after barnett T29, klaus-bch T59, edh-matsui T86); 2nd manuscript-anchored. APC cache verify-claim::Document n_seen=3 → use cached skeleton, patch F=2-specific deltas.",
  "brief": "## ROLE\n\nYou are implementer_text. T94 §F1 Document stage of investigation `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18` — terminal Tier-3 closure per T93 critic CORROBORATE-WITH-T91-ERRATA verdict. Your job: execute 4 file-edit deliverables (a-d below) that lock the F=2 cyclic-tetrahedral A_1 Tier-3 result into the persistent record.\n\nNO julia execution required (optional one-shot verification at the end is allowed under julia_cpu_light if you want extra confidence, but not gating). NO WebFetch. NO src/ modification. NO state.json edit (orchestrator handles closure). NO .claude/agents/* or .claude/scripts/* modification (no meta-improvement here).\n\nDIRECTIVE_LABEL: sign-pattern-lemma1-tier3-T94-document-f2-cyclic-tier3-stamp\n\n## REQUIRED READING (in this order)\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_93_critic_audit.md` ENTIRE — your primary source. Note: this file IS the critic's report (the judge bundled it under judge/ rather than critic/ this turn; the content is the critic Update report and §9 lists your 4 deliverables verbatim).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_92.md` §3.1-3.3 (β_c0 values), §4 (β_λ_paper3 = Lemma 1 application values), §0 (conventions reference).\n3. `/home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl` ENTIRE — existing template; you append a 6th @testset following identical idiom (5 prior @testset blocks at F=3, F=4, F=6, F=8, F=10).\n4. `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` lines ~380-420 (the 'verified at:' known-cases list around line 393-398). You append F=2 cyclic entry to this list.\n5. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/MEMORY.md` `Sign Pattern Lemma 1 General-S CLOSED FORM (2026-05-11)` section. You append a 2026-05-18 T94 Tier-3 stamp paragraph noting F=2 addition + T91 erratum.\n6. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md` §'Outcome (T90 closure)' — optional 1-paragraph append noting candidate #3 validated.\n\n## DELIVERABLES (per T93 critic §9; execute IN THIS ORDER)\n\n### Deliverable A: extend `scripts/manuscript/lemma1_general_S_verification.jl` with F=2 cyclic-tetrahedral A_1 case\n\nAppend a 6th `@testset` after the F=10 dodec I_h block (currently lines ~77-103) and before the closing `end` of the outer `@testset` (line 104). Idiom (verbatim template — match existing style):\n\n```julia\n    # --- F=2 cyclic tetrahedral A_1 (per T92 derivation + T93 critic CORROBORATE-WITH-T91-ERRATA at exact rational arithmetic) ---\n    @testset \"F=2 cyclic tetrahedral A_1\" begin\n        F = 2\n        denom = 2 * F * (F + 1)  # = 12\n        β_c0 = Dict(0 => 1//5, 2 => 2//7, 4 => 18//35)\n        β_λ_paper3 = Dict(0 => -1//5, 2 => -1//7, 4 => 12//35)\n        for S in [0, 2, 4]\n            prefactor = (S*(S+1) - denom) // denom\n            predicted = prefactor * β_c0[S]\n            @test predicted == β_λ_paper3[S]\n        end\n    end\n```\n\nAlso update the docstring header (line 6 — currently 'verified ... at F=3 octa A_2, F=4 cube, F=6 icosa, F=8 cube-octa A_1'): append ', F=10 dodec I_h, F=2 cyclic tetrahedral A_1' (since F=10 is also missing from this stale line — the actual script tests F=3/4/6/8/10 and after T94 will test +F=2). Also update line 7 ('All 19 channel coefficients matched at exact rational arithmetic.') → 'All 29 channel coefficients matched at exact rational arithmetic.' (previous incorrect 19; actual is 26 pre-T94 and 29 post-T94).\n\nAlso update the footer count message (line 115 currently 'Lemma 1 General-S: 26 channel coefficients verified across 5 cases') → 'Lemma 1 General-S: 29 channel coefficients verified across 6 cases'.\n\n### Deliverable B: append F=2 cyclic entry to `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` known-cases list\n\nFind the verified-at section near lines 393-398. Append after the F=10 line:\n\n```\n- F=2 cyclic tetrahedral A_1: 3 channels (S = 0, 2, 4) ✓ [added 2026-05-18 T94; T93 critic CORROBORATE-WITH-T91-ERRATA via 3 structurally-independent falsifiers]\n```\n\nDo NOT touch other parts of this file (other sections are paper3 derivation content beyond Document scope).\n\n### Deliverable C: append Tier-3 stamp to MEMORY.md `Sign Pattern Lemma 1 General-S CLOSED FORM (2026-05-11)` section\n\nThe MEMORY.md section is at `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/MEMORY.md`. Find the line starting with `## Sign Pattern Lemma 1 General-S CLOSED FORM (2026-05-11)` (or similar — exact wording per the file). Append (NOT replace) a paragraph:\n\n```\n\n## F=2 cyclic-tetrahedral A_1 Tier-3 closure (2026-05-18, loop T94)\n\nLemma 1 General-S extended to F=2 cyclic-tetrahedral A_1 representative. β_S^(c_0) = (1/5, 2/7, 18/35) at S∈{0,2,4}; β_S^(λ_spin) = (-1/5, -1/7, +12/35) via the closed-form prefactor (S(S+1) - 2F(F+1))/(2F(F+1)). Verified by T93 critic via 3 structurally-independent falsifiers: F1 (Racah CG-table closed-form re-derivation at exact rational arithmetic; structurally different from T92's orthogonality construction), F2 (Lemma 1 prefactor algebra well-defined at F=2 — denom 2F(F+1)=12 ≠ 0, no F=5-style irrep multiplicity-zero obstruction), F3 (sum-rule identity Σ_S β_S^(λ_spin) = 0 derived independently from ⟨F^(1)·F^(2)⟩ = |⟨F⟩|² = 0 for any ⟨F⟩=0 polyhedral inert state). Literature anchor via SO(5) MF degeneracy with F=2 polar (β values match Edmonds/Varshalovich CG tables for polar S=0/2/4 projectors). Regression script `scripts/manuscript/lemma1_general_S_verification.jl` now covers 29 channel coefficients across 6 cases (F=2/3/4/6/8/10).\n\n**T91 triangulation error caveat (paper3-side, recorded T94)**: T91 §3.3 claimed β_2^(c_0) = 0 for F=2 cyclic by reasoning '⟨F⟩=0 ⇒ c_1·|⟨F⟩|² mean-field term = 0 ⇒ β_2 = 0'. The first implication is correct; the second is a non-sequitur. β_S^(c_0) is a channel projector expectation ⟨ζ⊗ζ|P_S|ζ⊗ζ⟩, NOT a coupling-coefficient mean-field contribution; they are connected only through the sum rule Σ_S[S(S+1)-2F(F+1)]β_S = 2|⟨F⟩|² (which constrains the weighted combination, not individual β_S). At F=2 cyclic: (1/5)(-12) + (2/7)(-6) + (18/35)(+8) = -84/35 - 60/35 + 144/35 = 0, cancellation T91 mis-attributed to β_2 = 0 alone.\n\n**Schur-isotropic representative advisory erratum (T93 critic §3)**: T92's working representative ζ_cyc = (1/√2, 0, 0, 0, i/√2) is NOT Schur-isotropic (⟨F_z²⟩ = 4 ≠ F(F+1)/3 = 2). β_S^(c_0) is SU(2)-invariant so the result is correct, but for clarity the SU(2)-equivalent canonical Schur-isotropic representative is ζ'' = (√(1/3), 0, 0, √(2/3), 0) (⟨F_z²⟩ = 4·(1/3) + 1·(2/3) = 2 ✓). Future regression tests may prefer ζ'' OR include an explicit ⟨F_a²⟩ Schur-check assertion.\n```\n\n### Deliverable D (OPTIONAL but RECOMMENDED): append 1-paragraph closure note to `tier3_pipeline_survey_2026_05_18.md`\n\nAt `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md`, find the §'Outcome (T90 closure)' section. Append:\n\n```\n\n**Additional validation 2026-05-18 T94**: Survey candidate #3 `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda` closed Tier 3.0 at T94 (4th project Tier-3 trajectory; 2nd manuscript-anchored — paper3 v3 Lemma 1 General-S extended from F={3,4,6,8,10} to F={2,3,4,6,8,10}, full integer-F coverage of polyhedral inert state Lemma applicability at the verified cases tested). Total turns T91 (research) + T92 (hypothesize) + T93 (update) + T94 (document) = 4 turns, ~5.3M effective. The survey's prediction that candidate #3 was the cheapest Tier-3 closure was validated.\n```\n\n## ANTI-PATTERN GUARDS\n\n- Do NOT modify any src/ file (the regression script is in scripts/, not src/).\n- Do NOT touch state.json (orchestrator manages closure post-judge).\n- Do NOT touch .claude/agents/* or .claude/scripts/* or .claude/workload_specs.yaml (no meta-improvement here).\n- Do NOT touch quota_config.json or .claude/settings*.json.\n- Do NOT touch runs/_loop/patterns.yaml (no audit-class-scan here).\n- Do NOT re-derive the F=2 cyclic β values from scratch (T92 derived; T93 corroborated; use those values verbatim).\n- Do NOT WebFetch (cost discipline).\n- Do NOT add new Julia tests beyond the F=2 @testset (3 assertions exactly, matching idiom).\n- Do NOT rewrite the existing 5 @testset blocks at F=3/4/6/8/10 (they pass; do not touch).\n- Do NOT edit `docs/manuscript/thesis/` or `docs/manuscript/papers/paper3_universal_theorem/main.md` (those are the actual paper3 manuscript; T94 scope is paper3 supporting doc `sign_pattern_lemma1_general_S.md` only).\n- Do NOT spawn new investigations in state.json (orchestrator does that; T95 director will pick next).\n- Do NOT exceed 1.2M effective tokens HARD CAP. Target 0.8M.\n- Sympy invocation NOT REQUIRED (T93 critic already did the analytic Racah path). Do NOT spawn sympy.\n- Julia execution NOT REQUIRED. If you choose to verify with one-shot `julia --project=. -e 'include(\"scripts/manuscript/lemma1_general_S_verification.jl\")'` at the end, that is ALLOWED (under julia_cpu_light scheduler policy + the test is light — 29 rational comparisons, sub-second), but optional and gated by your judgment. If you skip Julia verification, that is FINE — the Racah CG values were proven correct at exact rational arithmetic by T93 critic §2 independently of Julia execution.\n- English only. No emojis. No anko-attribution. No improvised terminology — use established physics terms only.\n\n## REQUIRED OUTPUT — `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_94.md` (per implementer_text convention)\n\nFile MUST include these sections in this order:\n\n```markdown\n---\nturn: 94\nsubagent: implementer_text\ninvestigation_id: sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18\nstage_advancing_to: Document\ndirective_label: sign-pattern-lemma1-tier3-T94-document-f2-cyclic-tier3-stamp\ntopic_tags: [d1-verification, tier3-closure, sign-pattern-lemma1, F2-cyclic-tetrahedral-A1, regression-test-extension, memory-tier3-stamp, t91-erratum-recording]\nproduces: F=2 cyclic-tetrahedral A_1 Tier-3 closure stamp across 4 files\n---\n\n# Turn 94 — Implementer_text Document: F=2 cyclic-tetrahedral A_1 Lemma 1 General-S Tier-3 closure stamp\n\n## 1. Scope\n[Brief: per T93 critic §9, execute 4 file-edit deliverables stamping F=2 cyclic Tier-3 closure into persistent record.]\n\n## 2. Pre-flight reads + diffs prepared\n[Confirm read of T93 critic file + T92 theorist file; locate target lines in 4 destination files; show 3-line context snippets for each insertion site.]\n\n## 3. Deliverable A — regression script extension\n[Show the diff/patch applied to `scripts/manuscript/lemma1_general_S_verification.jl`: 1 new @testset (3 assertions) + 3 docstring/footer line updates. Include the actual @testset block text inserted.]\n\n## 4. Deliverable B — paper3 supporting doc known-cases list extension\n[Show the diff applied to `sign_pattern_lemma1_general_S.md`: 1 line appended to the verified-at section. Include exact text.]\n\n## 5. Deliverable C — MEMORY.md Tier-3 stamp\n[Show the diff applied to `MEMORY.md`: section heading + 3-paragraph stamp body. Include exact text.]\n\n## 6. Deliverable D — tier3_pipeline_survey validation paragraph (OPTIONAL)\n[Either: show the diff applied to tier3_pipeline_survey_2026_05_18.md; OR: report 'D skipped due to budget / file access; non-load-bearing per T94 contract optional flag.']\n\n## 7. Verification (OPTIONAL)\n[Either: report `julia --project=. -e 'include(\"scripts/manuscript/lemma1_general_S_verification.jl\")'` output showing 29/29 PASS; OR: report 'Julia verification skipped per T94 brief optional flag; Racah CG values proven correct at exact rational by T93 critic §2 independently of Julia execution; 3 new assertions are pure rational arithmetic.']\n\n## 8. Investigation closure summary\n[State: T94 closes investigation sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18 at Tier 3.0. 4th project Tier-3 trajectory. 2nd manuscript-anchored. Files touched (list 3-4 paths).]\n\n## 9. Metrics JSON\n[fenced ```json``` block per §METRICS schema below]\n```\n\n## METRICS JSON (single fenced ```json``` block in sim/turn_94.md §9)\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"investigation_kind\": \"physics\",\n  \"src_files_modified\": 0,\n  \"scripts_modified\": <int; expect 1 if Deliverable A done>,\n  \"docs_supporting_modified\": <int; expect 1 if Deliverable B done>,\n  \"memory_md_modified\": <true|false; expect true if Deliverable C done>,\n  \"tier3_pipeline_survey_appended\": <true|false; D is optional>,\n  \"agents_md_files_modified\": 0,\n  \"patterns_yaml_modified\": false,\n  \"state_json_modified\": false,\n  \"manuscript_main_edited\": false,\n  \"src_edited\": false,\n  \"julia_executed\": <true|false; OPTIONAL>,\n  \"julia_test_pass_count_if_run\": <int or null; expect 29 if julia run>,\n  \"webfetch_used\": false,\n  \"sympy_invoked\": false,\n  \"investigation_id\": \"sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18\",\n  \"stage_advancing_to\": \"Document\",\n  \"flow_template\": \"verify-claim\",\n  \"deliverable_A_regression_script_F2_testset_appended\": <true|false>,\n  \"deliverable_A_docstring_count_updated_19_to_29\": <true|false>,\n  \"deliverable_A_footer_count_updated_26_to_29_cases_5_to_6\": <true|false>,\n  \"deliverable_B_paper3_supporting_doc_known_cases_appended\": <true|false>,\n  \"deliverable_C_memory_md_tier3_stamp_appended\": <true|false>,\n  \"deliverable_C_t91_erratum_documented_in_memory\": <true|false>,\n  \"deliverable_C_schur_isotropy_advisory_in_memory\": <true|false>,\n  \"deliverable_D_optional_completed\": <true|false>,\n  \"tier_reached\": 3.0,\n  \"investigation_closed_at_tier3\": <true|false; expect true>,\n  \"verdict\": \"DOCUMENT_PASS\",\n  \"n_files_modified_total\": <int; expect 3 or 4>,\n  \"next_stage_recommended\": \"closed\"\n}\n```\n\n## SUCCESS CRITERIA (judge will mechanically check these)\n\nSee director T94 §6 success_criteria. The most important are:\n- deliverable_A_regression_script_F2_testset_appended == true\n- deliverable_B_paper3_supporting_doc_known_cases_appended == true\n- deliverable_C_memory_md_tier3_stamp_appended == true\n- deliverable_C_t91_erratum_documented_in_memory == true\n- investigation_closed_at_tier3 == true\n- src_files_modified == 0\n- state_json_modified == false\n",
  "observable_manifest": {
    "required": [
      "experiment_kind",
      "investigation_kind",
      "src_files_modified",
      "scripts_modified",
      "docs_supporting_modified",
      "memory_md_modified",
      "agents_md_files_modified",
      "patterns_yaml_modified",
      "state_json_modified",
      "manuscript_main_edited",
      "src_edited",
      "julia_executed",
      "webfetch_used",
      "sympy_invoked",
      "investigation_id",
      "stage_advancing_to",
      "flow_template",
      "deliverable_A_regression_script_F2_testset_appended",
      "deliverable_A_docstring_count_updated_19_to_29",
      "deliverable_A_footer_count_updated_26_to_29_cases_5_to_6",
      "deliverable_B_paper3_supporting_doc_known_cases_appended",
      "deliverable_C_memory_md_tier3_stamp_appended",
      "deliverable_C_t91_erratum_documented_in_memory",
      "tier_reached",
      "investigation_closed_at_tier3",
      "verdict",
      "n_files_modified_total",
      "next_stage_recommended"
    ],
    "optional": [
      "tier3_pipeline_survey_appended",
      "deliverable_C_schur_isotropy_advisory_in_memory",
      "deliverable_D_optional_completed",
      "julia_test_pass_count_if_run"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_93_critic_audit.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_92.md && test -f /home/suzume/workspace/BEC-simulation/scripts/manuscript/lemma1_general_S_verification.jl && test -f /home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/MEMORY.md && echo PRECONDITIONS_OK"
  },
  "success_criteria": [
    {
      "id": "experiment_kind_correct",
      "metric": "experiment_kind",
      "operator": "==",
      "value": "text_only",
      "rationale": "implementer_text Document stage; no julia, no sympy required."
    },
    {
      "id": "investigation_kind_physics",
      "metric": "investigation_kind",
      "operator": "==",
      "value": "physics",
      "rationale": "verify-claim physics investigation."
    },
    {
      "id": "src_unchanged",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "rationale": "Document stage modifies scripts/, docs/, and memory/; NOT src/."
    },
    {
      "id": "scripts_one_modified",
      "metric": "scripts_modified",
      "operator": "==",
      "value": 1,
      "rationale": "Deliverable A modifies scripts/manuscript/lemma1_general_S_verification.jl exactly once."
    },
    {
      "id": "docs_supporting_one_modified",
      "metric": "docs_supporting_modified",
      "operator": "==",
      "value": 1,
      "rationale": "Deliverable B modifies docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md exactly once."
    },
    {
      "id": "memory_modified",
      "metric": "memory_md_modified",
      "operator": "==",
      "value": true,
      "rationale": "Deliverable C appends Tier-3 stamp to MEMORY.md."
    },
    {
      "id": "no_agents_md_changes",
      "metric": "agents_md_files_modified",
      "operator": "==",
      "value": 0,
      "rationale": "No meta-improvement; agent prompts untouched."
    },
    {
      "id": "patterns_untouched",
      "metric": "patterns_yaml_modified",
      "operator": "==",
      "value": false,
      "rationale": "No audit-class-scan here."
    },
    {
      "id": "state_json_untouched_by_implementer",
      "metric": "state_json_modified",
      "operator": "==",
      "value": false,
      "rationale": "Orchestrator manages state.json closure post-judge."
    },
    {
      "id": "no_manuscript_main_polish",
      "metric": "manuscript_main_edited",
      "operator": "==",
      "value": false,
      "rationale": "Manuscript polish OUT (§A5). T94 touches paper3 SUPPORTING doc only, not main paper3.md / .tex."
    },
    {
      "id": "no_src_modification_explicit",
      "metric": "src_edited",
      "operator": "==",
      "value": false,
      "rationale": "src/ untouched."
    },
    {
      "id": "no_webfetch",
      "metric": "webfetch_used",
      "operator": "==",
      "value": false,
      "rationale": "Cost discipline."
    },
    {
      "id": "no_sympy",
      "metric": "sympy_invoked",
      "operator": "==",
      "value": false,
      "rationale": "T93 critic already did Racah path; T94 is mechanical file edits."
    },
    {
      "id": "investigation_consistent",
      "metric": "investigation_id",
      "operator": "==",
      "value": "sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18",
      "rationale": "Same investigation across T91-T94 arc."
    },
    {
      "id": "stage_consistent",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Document",
      "rationale": "§F1 next stage post-Update PASS is Document."
    },
    {
      "id": "template_consistent",
      "metric": "flow_template",
      "operator": "==",
      "value": "verify-claim",
      "rationale": "Same template throughout investigation."
    },
    {
      "id": "deliverable_A_done",
      "metric": "deliverable_A_regression_script_F2_testset_appended",
      "operator": "==",
      "value": true,
      "rationale": "Load-bearing: regression-script extension is the durable verification anchor."
    },
    {
      "id": "deliverable_A_docstring_updated",
      "metric": "deliverable_A_docstring_count_updated_19_to_29",
      "operator": "==",
      "value": true,
      "rationale": "Fix stale 19 → 29 channel count in docstring (was wrong pre-T94 even before F=2 add)."
    },
    {
      "id": "deliverable_A_footer_updated",
      "metric": "deliverable_A_footer_count_updated_26_to_29_cases_5_to_6",
      "operator": "==",
      "value": true,
      "rationale": "Footer count message must reflect new totals (29 channels / 6 cases)."
    },
    {
      "id": "deliverable_B_done",
      "metric": "deliverable_B_paper3_supporting_doc_known_cases_appended",
      "operator": "==",
      "value": true,
      "rationale": "Load-bearing: paper3 supporting doc lists verified cases; missing F=2 leaves dangling claim."
    },
    {
      "id": "deliverable_C_done",
      "metric": "deliverable_C_memory_md_tier3_stamp_appended",
      "operator": "==",
      "value": true,
      "rationale": "Load-bearing: MEMORY.md stamp prevents future cold-context re-derivation per conclusions-index requirement."
    },
    {
      "id": "deliverable_C_t91_erratum_recorded",
      "metric": "deliverable_C_t91_erratum_documented_in_memory",
      "operator": "==",
      "value": true,
      "rationale": "T91 triangulation error root cause (channel_weight_vs_meanfield_term_conflation) must be recorded for future-loop awareness; not recording it loses the institutional lesson."
    },
    {
      "id": "tier_3_reached",
      "metric": "tier_reached",
      "operator": "==",
      "value": 3.0,
      "rationale": "Per T93 critic tier_recommendation = 3.0."
    },
    {
      "id": "investigation_closes",
      "metric": "investigation_closed_at_tier3",
      "operator": "==",
      "value": true,
      "rationale": "Document is the terminal stage of §F1 verify-claim; tier_current >= tier_target → closed."
    },
    {
      "id": "verdict_document_pass",
      "metric": "verdict",
      "operator": "==",
      "value": "DOCUMENT_PASS",
      "rationale": "Implementer self-classification on successful Document execution."
    },
    {
      "id": "min_files_modified",
      "metric": "n_files_modified_total",
      "operator": ">=",
      "value": 3,
      "rationale": "Deliverables A+B+C are mandatory (3 files); D optional (+1)."
    },
    {
      "id": "next_stage_closed",
      "metric": "next_stage_recommended",
      "operator": "==",
      "value": "closed",
      "rationale": "Terminal stage of §F1 verify-claim."
    }
  ],
  "failure_modes": [
    {
      "if": "deliverable_A_regression_script_F2_testset_appended == false",
      "category": "operational",
      "next_action": "T95 director re-dispatches implementer_text with explicit verbatim @testset block in brief AND specific 3-line context snippet showing insertion site (the line just before the outer @testset's closing 'end'). If still fails, downgrade to noop and split scope into separate Deliverable A retry."
    },
    {
      "if": "deliverable_B_paper3_supporting_doc_known_cases_appended == false",
      "category": "operational",
      "next_action": "T95 director re-dispatches implementer_text with explicit grep-anchor for the verified-at section header (e.g., 'verified at:' or '- F=8 cube-octa A_1' as anchor line). Cheap retry."
    },
    {
      "if": "deliverable_C_memory_md_tier3_stamp_appended == false",
      "category": "operational",
      "next_action": "T95 director investigates MEMORY.md write-access: is the path correct? (Note: MEMORY.md is at /home/suzume/.claude/projects/.../memory/MEMORY.md user-private; implementer_text should have Write access per loop convention since prior loop turns have appended to it; if not, file an issue with anko about MEMORY.md write-policy.) Cheap retry with corrected path or with anko-confirmation of write-policy."
    },
    {
      "if": "deliverable_C_t91_erratum_documented_in_memory == false",
      "category": "scientific_partial",
      "next_action": "Deliverable C completed but missed the T91 erratum paragraph. T95 director re-dispatches implementer_text with explicit 2-paragraph erratum text in brief. Partial-PASS counts as Tier-3 closure but loses the institutional lesson; retry is cheap."
    },
    {
      "if": "tier_reached < 3.0",
      "category": "framework_error",
      "next_action": "Implementer self-classifies Tier < 3.0 despite T93 critic CORROBORATE-WITH-T91-ERRATA + tier_recommendation=3.0. T95 director audits implementer report for what caused the downgrade (likely a discovered file-edit conflict or an unrecorded falsifier objection). Possibly back to Update stage with critic re-audit. RARE; expected ~3%."
    },
    {
      "if": "src_files_modified > 0 OR src_edited == true OR state_json_modified == true OR agents_md_files_modified > 0 OR patterns_yaml_modified == true",
      "category": "framework_error",
      "next_action": "Implementer violated scope (modified out-of-scope file). T95 director reviews diff, reverts the out-of-scope changes, and re-dispatches with tighter file-scope guards in brief. CRITICAL bug class; flag for meta-investigation if recurrent."
    },
    {
      "if": "n_files_modified_total < 3",
      "category": "operational",
      "next_action": "Fewer than 3 deliverables completed. T95 director dispatches implementer_text retry for the missing deliverables only (avoid re-doing the completed ones). Partial-PASS path."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 1200000
  },
  "budget": {
    "expected_cost_eff": 800000,
    "expected_wall_time_sec": 600,
    "split_by_subtask": {
      "read_state_and_reports": 200000,
      "deliverable_A_regression_script": 200000,
      "deliverable_B_paper3_supporting": 100000,
      "deliverable_C_memory_md": 200000,
      "deliverable_D_optional_survey": 50000,
      "report_drafting": 100000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "closed",
    "if_success_tier_becomes": 3.0,
    "if_success_closing_note": "Tier 3.0 terminal closure 2026-05-18 T94. CORROBORATE-WITH-T91-ERRATA per T93 critic via 3 structurally-independent falsifiers (F1 Racah CG re-derivation; F2 Lemma 1 prefactor algebra; F3 sum-rule identity). 4th project Tier-3 trajectory (after barnett T29, klaus-bch T59, edh-matsui T86); 2nd manuscript-anchored Tier-3 closure (paper3 v3 Lemma 1 General-S extended from F={3,4,6,8,10} to F={2,3,4,6,8,10}, full integer-F coverage at the tested cases). 2 errata recorded: 1 load-bearing (T91 channel_weight_vs_meanfield_term_conflation root cause) + 1 advisory (T92 working representative ζ_cyc not Schur-isotropic; SU(2)-equivalent ζ'' IS). Survey candidate #3 from tier3_pipeline_survey_2026_05_18.md validated. Total cost T91-T94 = ~5.3M effective across 4 turns (researcher 1.81M + theorist 1.99M + critic 1.72M + implementer_text 0.8M target).",
    "if_refuted_advance_to_stage": "Update",
    "if_refuted_tier_becomes": 2.5,
    "next_falsifier_to_test_after": "F4-bogoliubov-spin-goldstone-stiffness (optional; deferred per T92 §10 + T93 §9; not load-bearing for current Tier-3 closure)"
  },
  "if_fails_next_step": "T95 director triages by failure_modes category: operational (re-dispatch implementer_text with tighter scope/anchor); scientific_partial (re-dispatch only missing deliverable); framework_error (revert + meta-investigation flag). For all failure modes, the most likely T95 action is a cheap (~0.5M) implementer_text retry of the specific missed deliverable. If all 4 deliverables fail (very unlikely; <1%), T95 director may downgrade to noop + critic-side audit asking 'why did Document fail despite Update CORROBORATE?'",
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json (T93 entry + investigation index + investigations dict) this turn
- [x] Read scheduler_94.json this turn — `JULIA_GPU_OK` policy, implementer_text allowed
- [x] Read seed.md this turn — seed is 2026-05-15 with hard memory constraint that has SINCE LAPSED (per scheduler probe foreign_julia=0); T94 implementer_text is text-only edits, fully compatible with both pre- and post-lapse states
- [x] Read ≥1 memory file related to active investigation — `tier3_pipeline_survey_2026_05_18.md` (origin + outcome) + MEMORY.md inline §Sign Pattern Lemma 1 General-S CLOSED FORM
- [x] Read T93 critic full audit (judge bundled at `runs/_loop/judge/turn_93_critic_audit.md`) — verdict CORROBORATE-WITH-T91-ERRATA + §9 T94 recommended scope
- [x] Read T93 director (this director's previous turn) — for continuity
- [x] investigation_id `sign-pattern-lemma1-tier3-vs-kawaguchi-ueda-2026-05-18` valid in state.active_investigation_id (though not yet in state.investigations dict — orchestrator manages spawn at closure)
- [x] stage_advancing_to == Document is the next stage per §F1 verify-claim template
- [x] subagent_type == implementer (class implementer_text) matches role_per_stage[Document] in §F1
- [x] success_criteria are machine-evaluable (all metrics map to METRICS JSON fields the implementer writes to sim/turn_94.md §9; judge.py operators all valid: ==, >=)
- [x] failure_modes cover the 5+ most likely failures (file-edit precondition violation per deliverable, MEMORY.md access, partial-PASS, scope-violation, sub-tier downgrade)
- [x] observable_manifest precondition_check is concrete bash chain that tests all 5 input files exist before T94 starts editing
- [x] budget 0.8M target / 1.2M HARD CAP fits comfortably within scheduler window_seconds_left (13.16 days) and prior implementer_text Document turn precedents (T29 0.7M, T59 0.8M, T86 0.9M)
- [x] §A6 research-first citation present (T93 critic §9, T92 theorist §3, paper3 sign_pattern_lemma1_general_S.md baseline, MEMORY.md Sign Pattern entry, tier3_pipeline_survey memory) — Document stage is advisory not mandatory per §F1; citations included for transparency
- [x] §A5 D1/D2/D3 articulated; manuscript NOT primary (T94 touches paper3 supporting doc only, NOT main paper3.md/.tex)
- [x] investigation_update field updates current_stage → closed AND tier_current → 3.0 on success path; AND advances to Update + 2.5 on refute path (rare)
- [x] §B7 quota budget: 0.8M target is comfortably below 5M cheap-workload threshold; no quota concerns
- [x] APC contract template cache referenced (verify-claim::Document n_seen=3) — skeleton inherited from T29/T59/T86 prior Document turns; F=2-specific deltas patched
