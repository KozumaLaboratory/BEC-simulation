---
turn: 84
subagent: director
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_from: Update (T83 critic CORROBORATE_WITH_ERRATA; F3 corrected rel_error 8.0% well within 20% CORROBORATE band; 4 errata: 1 load-bearing on T82 §8 interpretation + 3 advisory)
stage_advancing_to: Document (implementer_text terminal closure path: T82 §8 erratum propagation, T72 §5.3 errata addendum, new dedicated memory record edh_matsui_baseline_2026_05_18.md, by_tag index updates, state.json tier_current 2.5 → 2.75 + closing_note)
topic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, tier3-pipeline, verify-claim-document, errata-propagation, memory-update, third-tier3-candidate, intensive-vs-extensive-energy-convention, f1-deferred-rerun]
paper_section: null
depends_on: [83, 82, 81, 80, 72, "runs/_loop/director/turn_83.md", "runs/_loop/judge/turn_83_critic_audit.md", "runs/_loop/sim/turn_82.md", "runs/_loop/theorist/turn_72.md", "runs/_loop/state.json", "runs/_loop/_local/scheduler_84.json", "runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md", "runs/_loop/by_tag/edh-eu151-matsui-science-2026.md", "memory:klaus_bch_leak_verification_2026_05_18", "memory:tier3_pipeline_survey_2026_05_18", "memory:feedback_manuscript_is_not_the_essence", "memory:feedback_fix_the_class_not_the_instance", "memory:feedback_mathematical_elegance_bias"]
produces: "Document closure path for edh-eu151-vortex-vs-matsui-science-2026 at tier 2.5 → 2.75 (terminal Tier-3 closure at T85 verification turn). Artifacts: (1) new dedicated memory entry edh_matsui_baseline_2026_05_18.md (mirrors klaus_bch_leak_verification_2026_05_18.md shape — Tier promotion record with sweep params, observables, T83 Task A re-derivation excerpt, 4 errata, deferred follow-ups, verification chain T70-T84); (2) append to by_tag indices edh-eu151-matsui-science-2026.md + matsui-science-2026.md + matsui-2026.md + edh-eu151.md with T83/T84 rows; (3) state.json patch: current_stage = 'Document (F3 CORROBORATE; F1 deferred-rerun)', tier_current 2.5 → 2.75, errata_pending → 0, errata_resolved list, closing_note with the F3 8.0% match + F1 deferred-rerun pointer; (4) light annotation in runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md narrative file."
---

# Turn 84 — Director Report

## 1. Investigation state snapshot

- **Active investigation (continuing)**: `edh-eu151-vortex-vs-matsui-science-2026` (state.json line 1467, line 2049). priority 1, kind physics, flow_template verify-claim, tier_current 2.5, tier_target 3, blocked_on null.
- **Stage transition**: Update → **Document** per §F1 verify-claim template. T83 critic produced verdict CORROBORATE_WITH_ERRATA with tier_recommendation 2.75 and an explicit Task E T84 directive: "T84 implementer_text Document: memory entry edh_matsui_baseline_2026.md ... NO Julia execution at T84." Routing is pre-specified; T84 executes it.
- **Tier**: 2.5 → **2.75** (this turn moves the closure record into memory + state; the structural promotion). Terminal **3.0** at T85 (one verification turn that confirms the artifacts landed cleanly + state.json patch is well-formed — same shape as klaus-bch-leak T59 → T60 in the prior precedent).
- **Falsifier status after T83**:
  - **F3** (ground-state-energy-self-consistency): **CORROBORATE**. Critic-corrected rel_error = 8.0% ≪ 20% band. T72 §5.3 derivation independently re-verified (E_mf/N = 10.57 ℏω_ref/atom, T72 quoted 10.5). The OPERATIONAL_GATE at T82 was a T82-implementer interpretation error (extensive divide by N applied to a value that is already intensive per-atom by src construction).
  - **F1** (ring-appears-correct-timescale): NOT_APPLICABLE_NO_RING ratified. T83 Task D recommends longer-dynamics rerun (30 dimless = ~48 ms physical, ~3M GPU effective) but **deferred** to T85+ — not blocking on tier 2.75 advance.
  - **F2** (vortex-topology-l-matches-AM-conservation): depends F1 → NOT_APPLICABLE pending longer-dynamics rerun.
  - **F4** (DDI-zero-control-OPTIONAL): untested, defer (optional).
- **Other in-flight investigations (priority-ordered)**:
  | id | priority | tier | stage | notes |
  |---|---|---|---|---|
  | **edh-eu151-vortex-vs-matsui-science-2026** | **1** | **2.5 → 2.75 this turn** | **Document (T84)** | active, this turn |
  | barnett-mechanism-2026-05-16 | 1 | 3.0/3 | closed | done |
  | klaus-magnetostir-bch-leak-2026-05-13 | 3 | 3.0/3 | closed | done |
  | audit-due-heuristic-bug-2026-05-18 | 4 | 2.0/2 | closed | done |
  | meta-internal-b-unification-2026-05-18 | 5 | 1.0/1 | closed | done |
  | tier3-verification-pipeline-survey-2026-05-18 | 10 | 1/1 | Document (deferred) | done at T70 |
  | meta-cost-waste-audit-2026-05-18 | 15 | 0/1 | Observe (auto-spawn) | deferred to post-EdH |
  | meta-director-self-audit-2026-05-18 | 20 | 0/1 | Observe (auto-spawn) | deferred to post-EdH |
  | meta-cost-inflation-2026-05-18 | 40 | 0/1 | Observe (auto-spawn) | deferred to post-EdH |
  | fullbdg-f6-polar-3000x | 99 | 1.5/2 | dormant (anko-contained) | — |
- **Scheduler** (`runs/_loop/_local/scheduler_84.json` read this turn): policy = JULIA_GPU_OK, allowed_workloads includes `implementer_text`, window ends 2026-05-31T23:59 JST, 1,148,236 sec (13.29 days) remaining. Probe: VRAM 12,687 MB free, RAM 25.09 GB avail, GPU util 1%, foreign_julia 0. Document is text-only — fits trivially. **No Julia required this turn.**
- **Drift escalation** (state.history T83 line 1441): `director_must_address` with:
  - `DRIFT_MANUSCRIPT_DELTA_ZERO` — advisory only per `feedback_manuscript_is_not_the_essence` (anko 2026-05-15). T84 does NOT touch manuscript (correct).
  - `DRIFT_COST_INFLATION` (cost_inflation = 1.028 at T83 close) — T84 implementer_text baseline is ~0.9-1.3M (Document turns, no Julia, bounded file reads/writes). If T84 lands at ≤1.4M, cost_inflation drops below 1.0. Addressed by routing to implementer_text.
  - `AUDIT_DUE: patterns.yaml gap=20` — at the 10-turn cadence trigger threshold. Audit deferred until after EdH Tier-3 terminal closure at T85; spawn at T86 is the clean moment.
- **Auto-spawned meta investigations** (priority 15/20/40) all in `Observe` stage with no progress; deferred under priority-1 EdH advance. T85-T86 are natural moments to revisit one (likely meta-director-self-audit at priority 20).
- **State.json bookkeeping**: `active_investigation_id` correctly `edh-eu151-vortex-vs-matsui-science-2026` (line 1467). `last_meta_check_turn = 83`. Investigation block (lines 2049-2114): `current_stage` field currently stale-looking ("Document (T84 implementer_text: T82 sec 8 erratum + tier 2.5 to 2.75 + memory entry)") — but it correctly reflects the routed-NEXT-stage. T84 Document patches this to the closed-record stage after artifacts land.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T81 | Execute (R2 GPU retry, wrapper-script approval-gate workaround) | PASS (1.879M, BUDGET_OK 0.75×) | implementer_julia_gpu: GS converged pop[c=13]=0.9999, Mz=-6.0, gs_energy_final=-967.027; dynamics 12 snapshots over 10 ms, norm_drift=6.7e-13, pop_c12 grew 40× to 1.86e-3. PASS_PREDICTION_CONFIRMED for the GS landing at m_F=-6. |
| T82 | Analyze (jld2 extraction + F1/F2/F3 classification) | PASS contract / OPERATIONAL_GATE science (2.016M, BUDGET_OVER 1.55×) | implementer_julia_cpu_light: scripts/diagnostic/matsui_edh_t82_analyze.jl (commit a9976a4). F1 NOT_APPLICABLE_NO_RING (pop_c12 < 0.2% at all 12 frames; geometric depth/aspect noise floor); F2 NOT_APPLICABLE (depends F1); F3 OPERATIONAL_GATE (e_sim/atom=-0.0322 [INCORRECTLY computed as gs_energy_final/N] vs T72 pred +10.5/atom, 100.3% deviation; implementer's §8 enumerated 5 candidate root causes with normalization-convention mismatch as primary suspect). |
| T83 | Update (critic deep-audit on T82 OPERATIONAL_GATE) | CRITIC_PASS, CORROBORATE_WITH_ERRATA (1.932M, cost_inflation 1.028 ≈ at 1.0) | critic: independent re-derivation Task A (a_ho=0.8183 μm, μ_TF/ℏω_ref=12.62, E_mf/N=10.57 — T72 quoted 10.5 ✓); Task B src/analysis/energy.jl audit (l.122-330 + state_dispatch.jl:332-333 normalization + propagators.jl:55-65 ITP shift) → convention is **INTENSIVE per-atom** by construction; Task C reconciliation → e_sim/atom = -967.027 (read intensive, NOT divided by N), subtract T80 Zeeman -976.7 → non-Zeeman +9.67, vs T72 pred +10.57, |Δ|/E_mf = **8.0% ≪ 20%** → CORROBORATE; Task D F1 NOT_APPLICABLE ratified with deferred 30-dimless rerun recommendation; Task E next-action explicit: T84 implementer_text Document. 4 errata: E1 load-bearing T82 §8 interpretation; E2 advisory T72 §3.2 n_peak formula 4π/3 double-count (downstream-only effect on τ_DDI/t_ring; F3 E_mf/N unaffected); E3 advisory pop_c12 ≥ 1% guard back-port to T72 §6.2; E4 advisory T82 metric internal inconsistency. tier_recommendation = 2.75. n_references_cited = 8, derivation_lines_independent = 62. |

## 3. Flow template recall

- **Template**: `verify-claim` (§F1). Sequence: Research → Hypothesize → Design → Execute → Analyze → Update → **Document** → closed.
- **Stage advance per §B3 verdict-routing**: T83 verdict = CRITIC_PASS / CORROBORATE_WITH_ERRATA → advance to next-in-template = **Document**. Per §F1 row Update: "if CONFIRMED, tier++" — T83 lands tier_recommendation 2.75 (half-step instead of full step because errata E2/E3/E4 are advisory and reflect partial-not-clean closure; F1 not yet definitively ringed). Tier 3.0 closure waits for T85 verification of the Document artifacts.
- **Role for Document (§F1 row)**: `implementer_text` (memory entry update, docstring/advisory; manuscript paragraph only if anko-authorized — NOT this turn per `feedback_manuscript_is_not_the_essence`).
- **Why this stage now**:
  - T83 critic verdict already pre-routes T84 to implementer_text Document (Task E explicit single directive).
  - §F1 Document is the institutional-memory step that propagates the T83 errata (especially E1 load-bearing — the T82 §8 interpretation error must surface in memory so future loop turns reading the convention question don't re-litigate it).
  - Precedent: `klaus-magnetostir-bch-leak-2026-05-13` T58 critic CORROBORATE-WITH-ERRATA → T59 implementer_text Document → tier 3.0 closure → T60 verification. This pattern is documented in `klaus_bch_leak_verification_2026_05_18.md` (existing memory file) and T59 director report. T84 mirrors that shape exactly.
  - The load-bearing **class-level lesson** (per `feedback_fix_the_class_not_the_instance`, anko 2026-05-18): "src/analysis/energy.jl returns INTENSIVE per-atom by construction" is a finding that affects ALL future energy-vs-theory comparisons in the project, not just this F3 instance. Memory propagation is the class-level fix.
- **Why NOT skip to next investigation**:
  - 0 LOC src/ change risk; ≤ 1.5M effective tokens; ≤ 12 min wall.
  - The cost of NOT documenting: future investigations of any energy-vs-theory verification (Yan-Li-Saito, Klaus EdH variants, Lima-Pelster comparisons) will re-derive whether `total_energy()` is intensive or extensive — wasting 1-2 critic turns each time. Documenting NOW prevents N×1-2 turn cost downstream.
- **Why NOT spawn the F1 longer-dynamics rerun directly at T84**:
  - T83 Task D explicitly recommended **deferring** the rerun to T85+ "after F3 closure documents tier 3.0". The rerun is ~3M GPU cost — should not be entangled with the Document closure path.
  - Sequencing risk: if F1 rerun fails operationally, it would derail the F3 closure. Decoupling Document T84 from F1 rerun T86+ preserves the F3 CORROBORATE record cleanly.
- **Why NOT switch investigations**:
  - EdH = priority 1; all others priority 3-99 closed/dormant/deferred. EdH Document closure is the highest-leverage move this turn.
  - klaus-bch-leak T59 precedent shows Document is one dispatch away from terminal closure record; T84 follows identical pattern. Locking in the Tier-3 trajectory is institutional-memory work that ages quickly if deferred.
- **Why NOT noop**:
  - T83 critic produced a clean verdict + explicit T84 directive. Noop would waste the closure leverage and the 4-errata documentation moment. Document is the canonical §F1 close.

## 4. Research grounding (§A6)

T84 dispatch citations (≥1 external reference per §A6):

1. **`runs/_loop/judge/turn_83_critic_audit.md` Task E (lines 133-135)** — explicit T84 directive: "T84 dispatches implementer_text Document. Produces (a) memory entry runs/_local/memory_drafts/edh_matsui_baseline_2026.md... (b) T72 §5.3 errata addendum (note that 10.5 is in agreement with sim 9.67); (c) T82 §6.2 falsifier refinement addendum (add 1% pop guard); (d) state.json patch: tier_current 2.5 → 2.75, current_stage = 'Document (F3 CORROBORATE; F1 deferred-rerun)'. Total tier 3.0 closure at T85 ..." This is the load-bearing instruction set; T84 dispatches it.

2. **`runs/_loop/judge/turn_83_critic_audit.md` §7 Errata block (lines 137-147)** — the 4 errata payload with severity tags. E1 is load-bearing (T82 §8 interpretation error); E2/E3/E4 are advisory. Memory propagation step writes these verbatim with anchor citations.

3. **`runs/_loop/judge/turn_83_critic_audit.md` §2 Task A (lines 22-66)** — the 10-sub-step independent re-derivation (a_ho, a_s, N a_s/a_ho, μ_TF, contact-TF, zero-point, DDI, LHY, E_mf/N=10.57). The new memory file embeds the key numerics with citation to T83 §2.

4. **`runs/_loop/judge/turn_83_critic_audit.md` §3 Task B (lines 68-95)** — the src/analysis/energy.jl per-term convention audit with line numbers. The class-level lesson "intensive per-atom by construction" goes verbatim into the new memory file.

5. **`/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/klaus_bch_leak_verification_2026_05_18.md`** — the structural TEMPLATE for the new memory entry (klaus-bch-leak is the prior Tier-3 closure record from T59 — same flow_template, same author, same Tier-3 promotion shape). T84 implementer_text mirrors klaus-bch-leak's section structure: Status / Hypothesis verified / Sweep parameters / Observables / Verification chain / Errata / Deferred follow-ups / Citations / Related production code / Related memory.

6. **`runs/_loop/director/turn_59.md`** — analogous Document closure director report (klaus-bch-leak T58 CORROBORATE-WITH-ERRATA → T59 Document at tier 3.0). T84 follows the same 4-artifact pattern: new dedicated memory file + state.json patch + by_tag index append + (in T59 case: option_gamma_rotating_basis.md verification stamp). For T84 the analogous "load-bearing claim with verification stamp" target is `theorist/turn_72.md` §5.3 — but turn-files are immutable artifacts per loop convention; instead, the new memory file IS the verification stamp + errata propagation, and T82 §6.2 falsifier refinement appears as an advisory note in the new memory file (rather than back-edited into theorist/turn_72.md).

7. **`/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md`** — the parent investigation lineage (T69-T70 5-candidate survey, EdH was top pick priority 1). Closure of EdH at tier 2.75 → 3.0 is the parent survey's primary deliverable.

8. **Memory `feedback_manuscript_is_not_the_essence.md`** (anko 2026-05-15) — Document scope: memory entry + by_tag index + state.json closure ONLY. NO manuscript paragraph. T84 brief explicitly excludes manuscript edits.

9. **Memory `feedback_fix_the_class_not_the_instance.md`** (anko 2026-05-18) — the class-level lesson from T83 ("src `total_energy()` is intensive per-atom by construction") is propagated to memory so future investigations of ALL energy-vs-theory comparisons inherit the verified convention, not just this one F3 instance.

10. **Memory `feedback_mathematical_elegance_bias.md`** (anko 2026-05-15) — T83 critic followed this guidance and found the elegant single-cause explanation (one factor of N misplaced in T82 §8 interpretation, not a framework bug or theory rewrite). T84 Document preserves the elegant explanation in the memory record, NOT a "5 candidate root causes" hedge.

11. **Anthropic Effective Harnesses (Director.md §G)** — Initializer (anko's seed.md + earlier theorist Hypothesize T72) writes durable spec; Coder executes incrementally; Auditor (T83 critic) audits. T84 Document IS the "durable-spec write" step that closes the trajectory: T70-T83 turn lineage compressed into one Tier-3 record memory file + state.json patch.

12. **Grounded autonomous research (arXiv:2604.12198, Director.md §G)** — "REFUTED is a science success when documented." Inverted form: "CORROBORATE-WITH-ERRATA is a Tier-3 success when the errata are documented + propagated." E1 (load-bearing T82 §8 interpretation error) is the inversion the autonomous loop must publish — the loop's own implementer made an interpretation error that the loop's own critic caught and documented. This is the gold-standard self-correction event.

13. **Reflexion (Shinn et al. 2023, arXiv:2303.11366)** — closure-of-task-trajectory step that exposes lessons for future tasks. The 4 errata ARE the Reflexion lessons; the new memory file IS the Reflexion artifact externalized to durable storage.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verification axis — primary)**. T84 closes the F3 falsifier at CORROBORATE (8.0% within 20% band) and advances the investigation toward terminal Tier-3 closure at T85 (project's 3rd Tier-3 claim after barnett T28+T29 + klaus-bch-leak T58+T59). Manuscript NOT in scope.
- **Tier ladder position after T84 (anticipated)**:
  - Tier 2.5 → **2.75** (Document artifacts land, state.json patched, errata propagated).
  - Terminal **3.0** at T85 (one verification turn confirming artifacts are well-formed, mirroring klaus-bch-leak T60 lightweight verification — or T85 can be the F1 longer-dynamics rerun if anko prefers to bundle F1 closure into the same Tier-3 claim).
  - Project tier-3 count after T85: **3 investigations at Tier 3.0** (barnett, klaus-bch-leak, edh-eu151-matsui).
- **Project D1 verification depth**:
  - Pre-T84: 2 Tier-3 claims (Heisenberg-spin-dynamics barnett, BCH-leak-rotating-basis klaus).
  - Post-T84 trajectory: 3 Tier-3 claims (adds energy-vs-mean-field-Matsui-EdH-2026 with src convention audit as load-bearing supplement).
  - The new memory file establishes the **first explicit convention-statement memory** for `src/analysis/energy.jl` — a class-level lesson that benefits every future investigation touching energy comparisons.
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`). T84 writes to memory + state.json + by_tag indices ONLY.
- **Cost frame**: implementer_text Document baseline (klaus-bch-leak T59 = 1.355M, T29 barnett Document = 1.53M, T49 = ~1M). T84 forecast = **1.0-1.4M effective**, hard cap 1.6M. cost_inflation should drop from 1.028 → ~0.7-0.85 if T84 lands at 1.0-1.2M.
- **Drift trajectory after T84 (anticipated)**:
  - subagent_repetition: T80 theorist → T81 implementer_julia_gpu → T82 implementer_julia_cpu_light → T83 critic → T84 implementer_text = 5 distinct subagent classes in 5 turns (max diversity, value ~0.2).
  - cost_inflation: 1.028 → ~0.7-0.85 if T84 ≤ 1.2M.
  - code_delta_zero: 1.0 (Document is text-only, no src/ commits).
  - manuscript_delta_zero: 1.0 (correctly, by design).
  - novel_claim_zero: 0.0 (Document cites T83/T82/T72/src verbatim).
  - topic_repetition: 0.125 → ~0.14 (EdH stays in focus for one more turn).
- **Recommended T85+ trajectory** (informational, depends on T84 verdict + anko F1 priority):
  - **T85 minimum**: lightweight verification turn — implementer_text re-reads the artifacts T84 produced, confirms state.json patch is well-formed (no JSON syntax errors), confirms memory file has all required sections, posts a brief "artifacts landed" status to status/edh-eu151-vortex-vs-matsui-science-2026.md. Tier 2.75 → 3.0. Pipeline T83→T85 = 2 turns to Tier 3.0 (best case).
  - **T85 alternative**: F1 longer-dynamics rerun. implementer_julia_gpu reruns matsui_edh_baseline with duration 30 dimless (~48 ms physical) to bracket the predicted ring formation. ~3M GPU effective, ~90 min wall. If pop_c12 ≥ 1% before 50 ms physical AND ring depth/aspect criteria satisfied → F1 CORROBORATE, full closure at T86. If still NOT_APPLICABLE → F1 inconclusive-at-current-framework-resolution, document as partial-Tier-3 with F3-only-CORROBORATE.
  - **T86 audit-class-scan opportunity**: gap=20 at T83 → gap=22 at T85 if deferred → trigger threshold reached. Spawn audit-class-scan-2026-05-18-T86 with researcher Observe stage running patterns.yaml grep sweep.
  - **T85+ meta-investigations**: priority 15/20/40 auto-spawns deferred to post-EdH. After Tier-3 closure at T85, the natural ordering is: T86 audit-class-scan OR meta-cost-waste-audit (priority 15) OR meta-director-self-audit (priority 20).

## 6. Dispatch decision (declarative contract)

```json
{
 "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
 "stage_advancing_to": "Document (terminal closure path; T84 implementer_text propagates 4 errata to new memory entry, patches state.json tier 2.5 → 2.75 + closing_note, appends by_tag indices)",
 "subagent_type": "implementer_text",
 "researcher_depth": null,
 "parallel_researcher_count": 0,
 "rationale": "T83 critic CORROBORATE_WITH_ERRATA verdict pre-routes T84 to implementer_text Document (Task E explicit single directive). §F1 verify-claim Update → Document is the canonical stage advance for a CORROBORATE verdict. T83 4-errata payload (1 load-bearing T82 §8 interpretation + 3 advisory) requires memory propagation so the class-level lesson 'src/analysis/energy.jl returns INTENSIVE per-atom by construction' is institutionalized for ALL future energy-vs-theory verifications (per feedback_fix_the_class_not_the_instance). klaus-bch-leak T59 (CORROBORATE-WITH-ERRATA → Document → Tier 3.0 closure) is the exact precedent shape — T84 mirrors its 4-artifact pattern: new dedicated memory file + state.json patch + by_tag indices + status narrative. NO Julia execution, no src/ modification. ~1.0-1.4M effective. cost_inflation 1.028 → ~0.7-0.85 expected.",
 "brief": "## ROLE\n\nYou are implementer_text. T84 §F1 Document stage of edh-eu151-vortex-vs-matsui-science-2026 (verify-claim flow). Terminal Tier-3 trajectory closure path: tier 2.5 → 2.75 this turn, terminal 3.0 at T85 verification turn. Single dispatch; text-only; NO julia execution; NO src/ modification.\n\nThe precedent shape is `klaus-magnetostir-bch-leak-2026-05-13` T59 Document closure: read `runs/_loop/director/turn_59.md` and the resulting memory file `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/klaus_bch_leak_verification_2026_05_18.md` as your structural template. T84 produces analogous artifacts for edh-eu151-matsui.\n\nDIRECTIVE_LABEL: edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path\n\n=== HARD CONSTRAINT: NO JULIA EXECUTION, NO SRC MODIFICATION ===\n\nAllowed tools: Read, Glob, Grep, Write (memory file), Edit (state.json + by_tag indices + status narrative). NO Bash invocation of julia. NO Edit/Write to `src/`, `runs/eu151_*/`, `scripts/diagnostic/*` (those scripts are retained as immutable regression artifacts), `.claude/agents/*`, `.claude/scripts/*`, `.claude/workload_specs.yaml`, `quota_config.json`, or any settings.json. NO manuscript edits (per feedback_manuscript_is_not_the_essence).\n\n=== REQUIRED READING (READ BEFORE WRITING) ===\n\nRead in order:\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_84.md` (this file) §1, §3, §4, §5.\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_83_critic_audit.md` end-to-end — the verdict + 4 errata + Task A/B/C/D/E payload. This is the authoritative content source.\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_83.md` §1-§3 — context for why critic was dispatched + the prior verdict-routing.\n4. `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_82.md` end-to-end — the raw measurement report; pop_c12 trajectory, F1 NOT_APPLICABLE rationale, the 1% guard discussion, the F3 §8 reconciliation block (now superseded by T83 critic correction).\n5. `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_72.md` §5.3 — the load-bearing E_mf/N = 10.5 ℏω_ref/atom prediction independently re-verified at T83 §2. Also §5.5 (CORROBORATE band definition) and §6.2 (F1 falsifier text — note the missing 1% pop guard that T82 added).\n6. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_59.md` end-to-end — the precedent Document closure (klaus-bch-leak Tier-3 closure record). Note the 4-artifact pattern.\n7. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/klaus_bch_leak_verification_2026_05_18.md` end-to-end — the structural TEMPLATE for the new memory file. Mirror its section shape exactly.\n8. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md` — parent investigation lineage; T84 closure feeds the parent survey's primary deliverable.\n9. `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` — find the `edh-eu151-vortex-vs-matsui-science-2026` investigation block (lines 2049-2114, schema_version 2.1). Read carefully before Edit; preserve surrounding JSON exactly. State.json is ~2200 lines and 100kB+; DO NOT use Write — use targeted Edit only.\n10. `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/edh-eu151-matsui-science-2026.md` (and sibling by_tag indices if they exist: `edh-eu151.md`, `matsui-science-2026.md`, `matsui-2026.md`). Read existing format; append in matching shape.\n11. `/home/suzume/workspace/BEC-simulation/runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md` — investigation narrative file; append a T83 + T84 row to the turn-by-turn narrative.\n\n=== YOUR JOB — 5 ARTIFACTS ===\n\n### Artifact 1: CREATE `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md`\n\nNew dedicated Tier-3 trajectory record. Mirror the structural shape of `klaus_bch_leak_verification_2026_05_18.md`. Required sections:\n\n```\n---\nname: edh-eu151-matsui-science-2026-verification-t70-t84-2026-05-18\ndescription: F3 ground-state energy CORROBORATE_WITH_ERRATA against Matsui et al. Science 391, 384-388 (2026); src/analysis/energy.jl convention audit (INTENSIVE per-atom by construction)\ntype: project\n---\n\n## Status\n\n**Tier 2.75** (CORROBORATE_WITH_ERRATA on F3; F1 NOT_APPLICABLE_NO_RING ratified pending longer-dynamics rerun) as of 2026-05-18 T84. Terminal **Tier 3.0** trajectory closure expected at T85 verification turn.\n\nProject's 3rd Tier-3 trajectory (after barnett-mechanism-2026-05-16 T29 and klaus-magnetostir-bch-leak-2026-05-13 T59 closures).\n\n## Hypothesis verified (partial — F3 only this turn)\n\nSpinorBEC.jl spinor-DDI + split-step framework reproduces Matsui et al. Science 391, 384–388 (2026) [DOI:10.1126/science.adx2872; arXiv:2504.17357] mean-field GP ground-state energy at Case A parameters (N=30000, omega_ref = 2*pi*100 Hz isotropic, a_s = 110 a_B, Eu-151 spin-6) within 8% of the closed-form Thomas-Fermi prediction E_mf/N = (3/2)*hbar*omega_ref + (5/7)*mu_TF, with DDI energy 0 at spherical kappa=1 (Eberlein-Giovanazzi 2005).\n\n## Falsifier verdicts\n\n- **F3 (ground-state-energy-self-consistency)**: CORROBORATE. e_sim/atom = -967.027 hbar*omega_ref (read as INTENSIVE per-atom from total_energy()), Zeeman contribution = -p*m = -976.7 hbar*omega_ref/atom (T80 derivation of p_dimless = -162.78 at Bz = -0.01 G), non-Zeeman = +9.67 hbar*omega_ref/atom, T72 §5.3 prediction = +10.57 hbar*omega_ref/atom (T83 §2 independent re-derivation). |Delta E|/E_mf = 8.0% ≪ 20% CORROBORATE band.\n- **F1 (ring-appears-correct-timescale)**: NOT_APPLICABLE_NO_RING. 12 dynamics frames over 10 ms physical; pop_c12 grew 40× (4.78e-5 → 1.86e-3 = 0.186%), never reached the 1% threshold for observationally meaningful ring. Critic-ratified longer-dynamics rerun recommended: 30 dimless (~48 ms physical), ~3M GPU effective. Deferred to T85+.\n- **F2 (vortex-topology-l-matches-AM-conservation)**: depends F1 → NOT_APPLICABLE pending longer-dynamics rerun.\n- **F4 (DDI-zero-control-OPTIONAL)**: untested, deferred.\n\n## Sweep parameters (T81 Execute)\n\n- Configuration: `runs/matsui_edh_baseline_9ca97308/config.yaml`\n- atom: 151-Eu, F=6, D=13\n- a_s = 110 a_B, mu = 6.977 mu_B, g_F = 1.163\n- N = 30000\n- omega_ref = 2*pi*100 Hz (isotropic)\n- grid: 32^3, box = 12 a_ho\n- Bz = -0.01 Gauss (p_dimless = -162.78)\n- precision: f32 (mixed; T81 wrapper-script GPU run)\n- integrator: split-step Yoshida + standard ITP\n- GS: pop[c=13] = 0.9999 (m_F = -6 dominant), Mz = -6.0, gs_energy_final = -967.027 hbar*omega_ref/atom\n- dynamics: 12 snapshots over 10 ms physical, norm_drift = 6.7e-13, pop_c12 0.186% terminal\n\n## Critical convention finding (class-level lesson)\n\n**src/analysis/energy.jl returns INTENSIVE per-atom energies by construction.** Independent line-by-line audit at T83 §3 confirmed:\n\n- psi is unit-normalised: int|psi|^2 dV = 1 (state_dispatch.jl:332-333: `norm = sqrt(sum(abs2, psi) * dV); psi ./= norm`).\n- c0 absorbs ONE factor of N via the constraint c0 + 36 c1 = 4*pi*(a_s/a_ho)*N (CLAUDE.md §151Eu).\n- Therefore contact (c0/2) int|psi|^4 dV with unit-norm psi + c0 ∝ N evaluates to per-atom (one N already cancelled).\n- Kinetic, trap, Zeeman, DDI, LHY all per-atom by the same chain.\n- total_energy() (l.122-124) is per-atom intensive scalar.\n- ITP min(E_m) shift lives in propagators.jl:55-65 (constant rephasing inside ITP propagator), does NOT propagate to total_energy.\n\n**Class-level implication**: every future investigation comparing SpinorBEC.jl energies to closed-form theory must interpret total_energy() as per-atom. Do NOT divide by N — that would treat extensive output. Do NOT multiply by N — that would treat already-intensive output as if needing scaling.\n\n## Verification chain (turn lineage)\n\nT70 (researcher_deep Matsui PDF extraction; 5 EXTRACTED + 3 PARTIAL parameters) → T71 (researcher_deep PDF refinement; tau_EdH^exp, ell_paper extracted) → T72 (theorist quantitative bands D1-D7; F1/F2/F3 refined; closed-form E_mf/N = 10.5 hbar*omega_ref/atom) → T73 (implementer_text Design; matsui_edh_baseline.yaml Case A isotropic) → T74-T75 (Execute retries, FAIL_OPERATIONAL then PASS) → T76 (Analyze stage initial, partial) → T77 (critic Update; INCONCLUSIVE first pass) → T78 (Update prerequisite class-fix; haskey-B-yaml-bz-sign cleanup) → T79 (Execute R1 retry, INCONCLUSIVE blocked by julia approval-gate) → T80 (theorist Bz-sign-convention independent derivation; p_dimless = -162.78 at Bz<0, m_F = -6 minimum) → T81 (implementer_julia_gpu R2 retry with wrapper-script approval-gate workaround; PASS; GS converged + 12 dynamics frames) → T82 (implementer_julia_cpu_light Analyze; F1/F2/F3 jld2 extraction; contract PASS / OPERATIONAL_GATE science verdict on F3 due to extensive/intensive interpretation error) → T83 (critic Update; CORROBORATE_WITH_ERRATA; F3 corrected rel_error 8.0% within band; 4 errata identified) → **T84 (implementer_text Document; this record)**.\n\n## Errata (4 total: 1 load-bearing, 3 advisory)\n\n1. **[E1 LOAD-BEARING] T82 §8 (sim/turn_82.md line 308 + the entire F3 reconciliation block lines 326-407)**: `e_sim_per_atom = e_gs_total / N_ATOMS` is **incorrect**. `total_energy()` is already per-atom intensive by code construction (see Critical convention finding above). Correct: read -967.027 directly as per-atom; subtract Zeeman -976.7 to get non-Zeeman +9.67 hbar*omega_ref/atom; compare to T72 prediction +10.57; rel_error = 8.0% << 20% band. OPERATIONAL_GATE was an interpretation error, not a framework, theory, or convention bug.\n\n2. **[E2 ADVISORY] T72 §3.2 peak-density formula**: `n_peak = 15 N / (8*pi*V_TF)` with `V_TF = (4*pi/3) R^3` double-counts the (4*pi/3) factor. Canonical TF harmonic peak is `n_peak = 15 N / (8*pi*R_x*R_y*R_z)`. Effect at Case A: T72's reported `n_peak = 61.6 micrometer^-3` should be `258 micrometer^-3` (4.2x larger). Downstream: tau_DDI ~ 0.14 ms (not 0.57 ms); F1 t_ring band shifts from [5.7, 57] ms → [1.4, 14] ms (still brackets experimental 5 ms). **F3 prediction E_mf/N is unaffected** (depends on mu_TF, not n_peak).\n\n3. **[E3 ADVISORY] T72 §6.2 F1 falsifier text + T82 §6 pop-guard refinement**: T82 implementer added a `pop_c12 >= 0.01` (1%) population guard not present in T72 §6.2. The addition is physically justified (sub-percent ring is observationally meaningless at N=30000; Matsui's experimental detection threshold is closer to 10%). Treated as a refinement, not a deviation. Future versions of T72 §6.2 should include the 1% guard.\n\n4. **[E4 ADVISORY] T82 metric internal inconsistency**: `f3_zeeman_subtracted: false` field is technically correct (-967.027 includes Zeeman) but the `f3_zeeman_reconciliation_note` flipped conventions mid-paragraph. Future Analyze stages should publish clean per-atom decomposition tables (kinetic / trap / Zeeman / contact / DDI / LHY, each per-atom in hbar*omega_ref/atom units) instead of conflated single-scalar interpretations.\n\n## Deferred follow-ups (post-closure, optional)\n\n- **F1 longer-dynamics rerun** (T85+): implementer_julia_gpu reruns matsui_edh_baseline with duration extended to 30 dimless (~48 ms physical). Save_every preserved. Expected: pop_c12 reaches ~1% around 14 ms physical (per T83 Task D extrapolation Gamma = 0.37/ms), 10% around 21 ms. Falsifier closure if ring depth>20% + aspect>1.5 + pop_c12 >= 1% at any frame in [10, 50] ms. Cost: ~3M effective, ~90 min GPU wall. Falsifier outcomes: CORROBORATE (ring + correct timescale), INCONCLUSIVE (no ring at <50 ms, framework needs longer simulation), REFUTED (no ring at any frame, mechanism mismatch).\n\n- **F2 winding ell verification** (depends F1): if F1 CORROBORATE, extract ell_sim from phase circulation around ring density minimum. CORROBORATE if |ell_sim - ell_paper| = 0.\n\n- **F4 DDI-zero control** (optional): re-run with c_dd = 0 to verify DDI is the AM-transfer mechanism. ~3M effective.\n\n- **Cross-checks vs other Eu DDI codes** (Tier 3+, not Tier 3-blocker): compare to Stuttgart Dy164 or Innsbruck Er168 EdH simulations once published.\n\n## Citations\n\n- Matsui, T. et al. *Science* 391, 384-388 (2026). DOI:10.1126/science.adx2872. arXiv:2504.17357. EdH vortex emergence in 151-Eu dipolar BEC; primary experimental target.\n- Eberlein, C., Giovanazzi, S. & O'Dell, D. *PRA* 71, 033618 (2005). DDI energy closed-form f(kappa) for spherical trap kappa=1: f=0.\n- Lahaye, T., Menotti, C., Santos, L., Lewenstein, M. & Pfau, T. *Rep. Prog. Phys.* 72, 126401 (2009). Dipolar BEC review; TF dipolar energy convention.\n- Pitaevskii, L. P. & Stringari, S. *Bose-Einstein Condensation* (Oxford, 2003) §11. Canonical Thomas-Fermi formulas; (5/7) mu_TF per-atom contact energy.\n- Lima, A. R. P. & Pelster, A. *PRA* 84, 041604(R) (2011) and *PRA* 86, 063609 (2012). LHY correction for dipolar BEC; scalar approximation used here negligible (~0.06 hbar*omega_ref/atom at Case A).\n- Loop turns: researcher T70/T71, theorist T72/T80, implementer T73/T81/T82, critic T83, this director-driven document T84.\n\n## Related production code\n\n- `src/analysis/energy.jl` lines 122-330 — total_energy() and per-term implementations; convention INTENSIVE per-atom by construction.\n- `src/workflow/initialization/state_dispatch.jl:332-333` — psi unit-normalization point.\n- `src/foundation/types/interactions_zeeman.jl:29-43` — InteractionParams with N-scaled c0/c1.\n- `src/hamiltonian/integrator/propagators.jl:55-65` — ITP min(E_m) shift (does NOT propagate to total_energy).\n- `src/workflow/initialization/atoms.jl:208-219` — Eu-151 AtomSpecies (a_s, mu, g_F).\n- `runs/matsui_edh_baseline_9ca97308/` — the sweep configuration + JLD2 results (T81 output).\n- `scripts/diagnostic/matsui_edh_t82_analyze.jl` (commit a9976a4) — T82 analysis script; retained as regression artifact.\n\n## Related memory\n\n- `tier3_pipeline_survey_2026_05_18.md` — parent investigation; EdH was top pick priority 1.\n- `barnett_mechanism_confirmed.md` (if present) and `klaus_bch_leak_verification_2026_05_18.md` — sibling Tier-3 closure records (1st and 2nd Tier-3 claims).\n- `feedback_manuscript_is_not_the_essence.md` — D1 verification depth axis this entry serves.\n- `feedback_fix_the_class_not_the_instance.md` — the class-level convention finding propagated here.\n- `bug_4_itp_ddi_half_rate.md` — sibling ITP bug fixed 2026-05-02; T81 GS post-fix code.\n- `full_bdg_F6_polar_broken.md` — analogous case of energy-report-wrong-by-large-factor class; useful prior for future debug.\n```\n\nWrite this file de novo with the structure above. Use ASCII-safe notation throughout (avoid Unicode math glyphs; use plain `pi`, `hbar`, `omega`, etc.); the existing klaus-bch-leak memory file mostly does this — mirror that.\n\n### Artifact 2: UPDATE `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` — investigation tier advance + closing-trajectory metadata\n\nUse the Edit tool with absolute path. Target the `edh-eu151-vortex-vs-matsui-science-2026` investigation block (lines 2049-2114, schema_version 2.1). Required field updates:\n\n- `current_stage`: existing string \"Document (T84 implementer_text: T82 sec 8 erratum + tier 2.5 to 2.75 + memory entry)\" → \"Document (F3 CORROBORATE_WITH_ERRATA at tier 2.75; F1 NOT_APPLICABLE deferred-rerun; terminal Tier 3.0 closure at T85 verification turn)\"\n- `tier_current`: 2.5 → **2.75**\n- `stages_done`: append \"Document\" to the array if not already present. Current array (line 2055-2065) has 9 strings; check if \"Document\" is among them, append if not. (Looking at the current state.json, it appears \"Document\" is NOT in stages_done yet — confirm by reading the array.)\n- `next_stage`: existing value → \"Document-verify (T85 lightweight verification turn; OR T85 F1 longer-dynamics rerun, anko's choice)\"\n- `next_stage_action`: existing → \"T85 director: dispatch either (a) implementer_text Document-verify lightweight 1-artifact pass confirming state.json patch + memory file are well-formed → tier 2.75 → 3.0; OR (b) implementer_julia_gpu F1 longer-dynamics rerun at 30 dimless = ~48 ms physical, ~3M GPU effective, ~90 min wall → if pop_c12 reaches 1% with ring depth/aspect → F1 CORROBORATE → full closure with both F1 + F3 in Tier-3 record. Recommended: (a) first for the cheap Tier 3.0 record, then (b) as a Tier-3+ refinement.\"\n- ADD field `closing_note` with the value: \"Tier 2.75 trajectory advance 2026-05-18 T84. CORROBORATE_WITH_ERRATA via T83 critic independent re-derivation: F3 corrected rel_error 8.0% well within 20% CORROBORATE band; T72 §5.3 derivation independently re-verified (E_mf/N = 10.57 hbar*omega_ref/atom vs T72 quoted 10.5). 4 errata: E1 load-bearing T82 §8 extensive/intensive interpretation error (corrected: total_energy() is per-atom intensive by construction); E2 advisory T72 n_peak formula 4pi/3 double-count (downstream-only effect on tau_DDI/t_ring; F3 unaffected); E3 advisory pop_c12 >= 1% guard refinement; E4 advisory T82 metric internal inconsistency. Class-level convention finding propagated to memory: src/analysis/energy.jl returns INTENSIVE per-atom by construction. F1 NOT_APPLICABLE_NO_RING ratified; longer-dynamics rerun (30 dimless ~ 48 ms, ~3M GPU) deferred to T85+. Project's 3rd Tier-3 trajectory after barnett-mechanism (T29) and klaus-bch-leak (T59). Dedicated memory record: edh_matsui_baseline_2026_05_18.md. Terminal Tier 3.0 closure expected at T85 lightweight verification turn.\"\n- ADD field `errata_resolved` with the 4 errata IDs as an array: [\"E1-t82-section-8-extensive-intensive-interpretation-LOAD-BEARING\", \"E2-t72-section-3-2-n-peak-formula-4pi-3-double-count\", \"E3-t72-section-6-2-f1-pop-guard-1pct-refinement\", \"E4-t82-metric-zeeman-reconciliation-internal-inconsistency\"]\n- ADD field `errata_pending`: 0 (all 4 errata are now propagated to memory)\n- ADD field `last_turn`: 84\n- ADD field `last_stage`: \"Document\"\n- ADD field `last_verdict`: \"CORROBORATE_WITH_ERRATA\"\n- ADD field `last_critic_turn`: 83\n\nUse Edit with absolute path; preserve surrounding JSON structure exactly; mind comma placement (the investigation block ends at line 2114 with `\"closing_note\": null` — replace with the populated closing_note above, and add the new fields BEFORE the trailing `}` of the investigation block). If state.json schema version 2.1 has stricter requirements, prefer adding fields at the end of the block before the trailing brace.\n\n### Artifact 3: APPEND `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/edh-eu151-matsui-science-2026.md`\n\nRead the existing file (currently has 14 entries through T83). Append two new rows in the matching format:\n\n- **T84** [PASS] `edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path`\n\nIncrement the `Total: 14` header to `Total: 15`. (T83 row already present.)\n\n### Artifact 4: APPEND sibling by_tag indices if they exist\n\nGlob for these files; for each that exists, append the same T84 row in matching format and increment the total:\n- `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/edh-eu151.md`\n- `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/matsui-science-2026.md`\n- `/home/suzume/workspace/BEC-simulation/runs/_loop/by_tag/matsui-2026.md`\n\nIf a file does not exist, do NOT create it (skip silently).\n\n### Artifact 5: APPEND `/home/suzume/workspace/BEC-simulation/runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md`\n\nRead existing file (currently has entries through T82). Append narrative entries for T83 and T84 in the matching format:\n\n```\n### T83 (2026-05-18T08:00:13Z) — CRITIC_PASS — `edh-matsui-update-T83-critic-operational-gate-deep-audit`\n\n- Stage: **Update**, tier: 2.5\n- Cost: 1932k effective tokens\n- Verdict: CORROBORATE_WITH_ERRATA\n- F3 critic classification: CORROBORATE_AFTER_CONVENTION_FIX; corrected rel_error = 8.0%; convention = INTENSIVE per-atom\n- 4 errata (1 load-bearing, 3 advisory)\n- T84 next-action: implementer_text Document\n\n### T84 (2026-05-18) — PASS — `edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path`\n\n- Stage: **Document**, tier: 2.5 → 2.75\n- Artifacts: 5 (new memory file edh_matsui_baseline_2026_05_18.md; state.json patch with closing_note + errata_resolved; by_tag indices appended; status narrative appended)\n- Terminal Tier 3.0 trajectory at T85 verification turn (lightweight pass OR F1 longer-dynamics rerun)\n```\n\nUse Edit with append-at-end pattern. Match the existing file format exactly.\n\n=== CONSTRAINTS ===\n\n- Files allowed to CREATE: `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md`, `runs/_loop/sim/turn_84.md` (your own implementer report).\n- Files allowed to MODIFY (Edit only): `runs/_loop/state.json` (TARGETED Edit — never Write on this large file), `runs/_loop/by_tag/edh-eu151-matsui-science-2026.md` (and sibling indices if they exist), `runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md`.\n- Files MUST NOT be touched: `src/`, `runs/matsui_edh_baseline_*/`, `scripts/diagnostic/*` (retain as immutable regression artifacts), `.claude/agents/*`, `.claude/scripts/*`, `.claude/workload_specs.yaml`, `quota_config.json`, any `.claude/settings*.json`, any other memory file, any other `runs/_loop/` turn artifact (judge/critic/sim/research/theorist turns are append-only).\n- NO julia execution.\n- NO new analysis scripts.\n- NO manuscript edits (per feedback_manuscript_is_not_the_essence).\n- English only. No emojis.\n- Absolute paths in all tool calls.\n- Cost budget: stay within ~1.4M effective tokens, ~12 min wall hard cap.\n- Single commit: artifacts represent ONE logical change (Tier-2.75 closure trajectory of edh-eu151-matsui); auto-commit handles it post-judge.\n- NO fabrication: all numbers in the new memory file MUST come from T81 sim, T82 sim, T83 critic, or T72 theorist. Do NOT invent values. If a number is uncertain, cite the source turn explicitly.\n- NO anko-attribution in artifact text (file paths + line numbers + prior turns + established literature only).\n\n=== SUCCESS CRITERIA (machine-evaluable; emit in §4 Metrics block of your output) ===\n\nProduce `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_84.md` with structure:\n\n```markdown\n---\nturn: 84\nsubagent: implementer_text\ndirective_action: modify_code\ndirective_label: edh-matsui-document-T84-tier-2-75-corroborate-with-errata-closure-path\ninvestigation_id: edh-eu151-vortex-vs-matsui-science-2026\nstage: Document\nverdict: PASS\n---\n\n# Turn 84 — Document closure trajectory of edh-eu151-matsui verify-claim (Tier 2.5 → 2.75)\n\n## §1 Artifacts produced (5 total)\n\n(per-artifact: path, create/modify status, summary of changes, byte count if instructive)\n\n## §2 Errata propagation (4 errata: 1 load-bearing + 3 advisory)\n\n(for each erratum: ID, source turn + location, claim, correction, severity, destination)\n\n## §3 state.json delta\n\n(field-by-field listing for edh-eu151-vortex-vs-matsui-science-2026 block: field name, before, after)\n\n## §4 Metrics\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"workload_class\": \"implementer_text\",\n  \"src_files_modified\": 0,\n  \"new_analysis_scripts_written\": 0,\n  \"investigation_id\": \"edh-eu151-vortex-vs-matsui-science-2026\",\n  \"stage_advancing_to\": \"Document\",\n  \"flow_template\": \"verify-claim\",\n  \"artifacts_created_count\": <int, must be 1: edh_matsui_baseline_2026_05_18.md>,\n  \"artifacts_modified_count\": <int, must be >= 3: state.json + at least one by_tag index + status narrative>,\n  \"memory_files_touched\": <int, must be 1>,\n  \"state_json_touched\": <bool, must be true>,\n  \"by_tag_indices_touched\": <int, count of by_tag files appended (1-4)>,\n  \"status_narrative_touched\": <bool, must be true>,\n  \"errata_propagated_to_memory_count\": <int, must be 4>,\n  \"errata_load_bearing_count\": <int, must be 1>,\n  \"errata_advisory_count\": <int, must be 3>,\n  \"investigation_tier_advanced\": <bool, must be true (2.5 → 2.75)>,\n  \"final_tier\": <float, must be 2.75>,\n  \"closing_note_present_in_state_json\": <bool, must be true>,\n  \"errata_resolved_field_added\": <bool, must be true>,\n  \"new_memory_file_has_verification_chain\": <bool, must be true>,\n  \"new_memory_file_has_citations\": <bool, must be true>,\n  \"new_memory_file_has_deferred_followups\": <bool, must be true>,\n  \"new_memory_file_has_class_level_convention_finding\": <bool, must be true>,\n  \"klaus_bch_leak_template_referenced\": <bool, must be true>,\n  \"manuscript_edited\": <bool, must be false>,\n  \"src_edited\": <bool, must be false>,\n  \"julia_executed\": <bool, must be false>\n}\n```\n\nMUST be a single fenced ```json``` block.\n\n## §5 Self-review\n\n- [ ] All 5 artifacts produced as specified?\n- [ ] No fabricated values?\n- [ ] state.json JSON syntax valid after edit?\n- [ ] No src/ modified?\n- [ ] No julia executed?\n- [ ] No manuscript edited?\n- [ ] Cost within 1.4M cap?\n```\n\nReport HONESTLY. If any of the 5 artifacts cannot be produced cleanly (e.g., state.json JSON syntax risk on Edit, or a by_tag index has a format you cannot parse), STOP and report what you found rather than fabricating.\n\n=== ANTI-PATTERN GUARDS ===\n\n- Do NOT modify src/.\n- Do NOT execute julia.\n- Do NOT touch manuscript files.\n- Do NOT invent numbers — every value comes from T70-T83 prior turns or src reading.\n- Do NOT use anko-attribution in artifact text.\n- Do NOT use improvised terminology (per feedback_no_improvised_terminology).\n- Do NOT exceed 1.6M effective tokens.\n- Do NOT skip the klaus-bch-leak structural reference — that's the working template.",
 "observable_manifest": {
 "required": [
 "experiment_kind",
 "workload_class",
 "src_files_modified",
 "investigation_id",
 "stage_advancing_to",
 "artifacts_created_count",
 "artifacts_modified_count",
 "memory_files_touched",
 "state_json_touched",
 "errata_propagated_to_memory_count",
 "errata_load_bearing_count",
 "investigation_tier_advanced",
 "final_tier",
 "closing_note_present_in_state_json",
 "new_memory_file_has_verification_chain",
 "new_memory_file_has_class_level_convention_finding",
 "manuscript_edited",
 "src_edited",
 "julia_executed"
 ],
 "optional": [
 "by_tag_indices_touched",
 "status_narrative_touched",
 "errata_advisory_count",
 "errata_resolved_field_added",
 "new_memory_file_has_citations",
 "new_memory_file_has_deferred_followups",
 "klaus_bch_leak_template_referenced"
 ],
 "precondition_check": "cd /home/suzume/workspace/BEC-simulation && test -f runs/_loop/judge/turn_83_critic_audit.md && test -f runs/_loop/director/turn_59.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/klaus_bch_leak_verification_2026_05_18.md && test -f runs/_loop/state.json && test -f runs/_loop/by_tag/edh-eu151-matsui-science-2026.md && test -f runs/_loop/status/edh-eu151-vortex-vs-matsui-science-2026.md && grep -q '\"edh-eu151-vortex-vs-matsui-science-2026\":' runs/_loop/state.json && grep -q '\"tier_current\": 2.5' runs/_loop/state.json && echo OK_T84_precondition: critic_audit + klaus_template + state_json + by_tag + status + investigation_block_present + tier_2_5_present"
 },
 "success_criteria": [
 {
 "id": "memory_file_created",
 "metric": "artifacts_created_count",
 "operator": "==",
 "value": 1,
 "tolerance": null,
 "rationale": "Exactly one new memory file: /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md"
 },
 {
 "id": "state_modified",
 "metric": "state_json_touched",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "state.json must be patched (tier_current 2.5 → 2.75 + closing_note + errata_resolved)"
 },
 {
 "id": "tier_advanced",
 "metric": "final_tier",
 "operator": "==",
 "value": 2.75,
 "tolerance": null,
 "rationale": "Tier advances exactly to 2.75 (CORROBORATE_WITH_ERRATA half-step; terminal 3.0 at T85)"
 },
 {
 "id": "tier_advance_flagged",
 "metric": "investigation_tier_advanced",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Boolean confirmation of tier advance"
 },
 {
 "id": "all_errata_propagated",
 "metric": "errata_propagated_to_memory_count",
 "operator": "==",
 "value": 4,
 "tolerance": null,
 "rationale": "All 4 T83 errata must be propagated to memory (E1 load-bearing + E2/E3/E4 advisory)"
 },
 {
 "id": "load_bearing_erratum_counted",
 "metric": "errata_load_bearing_count",
 "operator": "==",
 "value": 1,
 "tolerance": null,
 "rationale": "E1 is the single load-bearing erratum (T82 §8 extensive/intensive interpretation)"
 },
 {
 "id": "class_finding_propagated",
 "metric": "new_memory_file_has_class_level_convention_finding",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "The class-level lesson 'src/analysis/energy.jl is INTENSIVE per-atom by construction' must appear in the new memory file — this is the highest-leverage knowledge transfer from T83 critic"
 },
 {
 "id": "verification_chain_present",
 "metric": "new_memory_file_has_verification_chain",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "Memory file must include T70-T84 turn lineage for institutional context"
 },
 {
 "id": "no_src_modification",
 "metric": "src_edited",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Document is text-only by §F1 + by scheduler constraint avoidance"
 },
 {
 "id": "no_julia_execution",
 "metric": "julia_executed",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Document is text-only"
 },
 {
 "id": "no_manuscript_polish",
 "metric": "manuscript_edited",
 "operator": "==",
 "value": false,
 "tolerance": null,
 "rationale": "Per feedback_manuscript_is_not_the_essence, manuscript NOT in scope"
 },
 {
 "id": "closing_note_landed",
 "metric": "closing_note_present_in_state_json",
 "operator": "==",
 "value": true,
 "tolerance": null,
 "rationale": "state.json must have a populated closing_note string for the EdH investigation block"
 }
 ],
 "failure_modes": [
 {
 "if": "all success_criteria PASS",
 "category": "success (Tier-2.75 trajectory landed; 4 errata propagated; class-level convention finding institutionalized)",
 "next_action": "T85 director: dispatch implementer_text Document-verify lightweight pass — re-read T84 artifacts, confirm state.json JSON syntax is valid (jq parse check), confirm memory file has all required sections per T84 spec, confirm by_tag indices appended cleanly. PASS → tier 2.75 → 3.0 terminal closure of EdH F3 leg. Project's 3rd Tier-3 trajectory. T86 candidate: either (a) F1 longer-dynamics rerun (3M GPU) for F1 closure; or (b) audit-class-scan-2026-05-18-T86 (gap=22 hits 10-turn cadence threshold); or (c) meta-director-self-audit (priority 20). Director chooses based on T85 outcome + drift signal trajectory."
 },
 {
 "if": "state.json Edit corrupts JSON (failure_modes: tier_current ! advanced OR closing_note ! present)",
 "category": "operational (state.json schema_version 2.1 + ~2200 lines is tricky to Edit safely)",
 "next_action": "T85 director: dispatch implementer_text repair turn — read state.json, identify the corruption (use jq parse; if fail, locate the bad line), re-apply targeted Edit. Fall back to using python json.load + json.dump if Edit-based approach is unsafe. Tier holds at 2.5 (T84 did not land cleanly); retry."
 },
 {
 "if": "memory file created but missing class-level convention finding section",
 "category": "scientific (highest-leverage knowledge transfer not propagated)",
 "next_action": "T85 director: dispatch implementer_text append-section turn to add the missing Critical convention finding section to edh_matsui_baseline_2026_05_18.md. The class-level lesson is the load-bearing payload of T84 — without it, future energy-vs-theory investigations re-litigate the convention question."
 },
 {
 "if": "implementer_text exceeds 1.6M effective cost",
 "category": "operational (over-budget on Document turn)",
 "next_action": "T85 director: review sim/turn_84.md token breakdown. Common cause: over-reading klaus-bch-leak template instead of using it as structural skeleton + transcribing T83 content. Re-emphasize bounded reads + the existing template file."
 },
 {
 "if": "implementer flags 'klaus-bch-leak template too dissimilar; falls back to de-novo memory shape'",
 "category": "operational (template mismatch)",
 "next_action": "Accept the de-novo shape PROVIDED it has all required sections (Status / Hypothesis / Falsifier verdicts / Sweep params / Class-level convention finding / Verification chain / Errata / Deferred follow-ups / Citations / Related code / Related memory). T85 critic-light review to confirm completeness."
 },
 {
 "if": "implementer reports F1 NOT_APPLICABLE classification needs revision (e.g., critic Task D conclusions are wrong)",
 "category": "scientific (T83 critic missed something)",
 "next_action": "DO NOT happen in Document stage. If implementer raises a substantive science objection during Document, STOP — rewind to T83 critic Update with the objection as a new error class. T85 critic re-eval."
 },
 {
 "if": "by_tag index files have unexpected format that resists clean append",
 "category": "operational (cosmetic; not load-bearing)",
 "next_action": "Skip the problematic by_tag indices and document the skip in §1 Artifacts. By_tag indices are bookkeeping aids, not load-bearing institutional memory. Memory file + state.json are the load-bearing artifacts; those MUST land."
 },
 {
 "if": "all artifacts land but verdict is INCONCLUSIVE due to anko intervention or external drift",
 "category": "external (anko paused loop; T84 artifacts may be partial)",
 "next_action": "T85 director: re-survey state.json + memory directory + by_tag index for any partial-write evidence. If memory file exists but state.json un-patched, finish the state.json patch as T85 Document-verify. If state.json patched but memory file missing, create memory file as T85 Document-recovery. Tier holds at the highest cleanly-landed level."
 }
 ],
 "tolerance_overrides": {
 "cost_cap_effective": 1600000,
 "implementer_text_baseline_expected": 1100000,
 "wall_time_expected_min": 6,
 "wall_time_cap_min": 12
 },
 "budget": {
 "expected_cost_eff": 1100000,
 "expected_wall_time_sec": 360,
 "split_by_subtask": {
 "context_reads_director84_critic83_sim82_theorist72_klaus_template": 350000,
 "artifact1_new_memory_file_write": 400000,
 "artifact2_state_json_targeted_edit": 150000,
 "artifact3_by_tag_index_append": 60000,
 "artifact4_sibling_by_tag_indices_glob_and_append": 50000,
 "artifact5_status_narrative_append": 40000,
 "sim_turn_84_md_writeup_with_metrics": 50000
 }
 },
 "investigation_update": {
 "if_success_advance_to_stage": "Document-verify (T85 lightweight verification — confirms state.json patch is JSON-valid; confirms memory file is complete; appends a brief PASS row to status narrative; tier 2.75 → 3.0 terminal closure)",
 "if_success_tier_becomes": 2.75,
 "if_partial_success_advance_to_stage": "Document (T85 implementer_text retry of the partially-completed artifacts)",
 "if_partial_success_tier_becomes": 2.5,
 "if_refuted_advance_to_stage": "Update (rare; would require implementer to surface a science objection to T83 critic conclusions)",
 "if_refuted_tier_becomes": 2.0,
 "if_inconclusive_advance_to_stage": "Document (T85 implementer_text recovery of un-landed artifacts)",
 "if_inconclusive_tier_becomes": 2.5,
 "next_falsifier_to_test_after": "F3 leg closed at T85 verification (Tier 3.0 trajectory). F1 NOT_APPLICABLE_NO_RING ratified pending longer-dynamics rerun (30 dimless ~ 48 ms physical, ~3M GPU effective). T86+ either F1 closure via the rerun (best case: F1 CORROBORATE → both F1+F3 in single Tier-3 record) or F1-deferred-permanently with framework limitation note (acceptable for partial-Tier-3 closure on F3 alone). F4 c_dd=0 control remains optional (deferred). F2 winding ell depends on F1 → also deferred."
 },
 "consumed_seed_md": false,
 "meta_note_for_judge": "T84 advances Document stage of edh-eu151-vortex-vs-matsui-science-2026 (verify-claim flow, §F1) via implementer_text (text-only, no julia, no src). T83 critic CORROBORATE_WITH_ERRATA + tier_recommendation 2.75 + Task E explicit T84 directive → T84 produces 5 artifacts: (1) new dedicated memory entry edh_matsui_baseline_2026_05_18.md mirroring klaus_bch_leak_verification_2026_05_18.md structural template — Tier 2.75 trajectory record with F3 CORROBORATE numerics from T83 §2 independent re-derivation + the class-level convention finding 'src/analysis/energy.jl is INTENSIVE per-atom by construction' (the highest-leverage payload); (2) state.json patch advancing tier_current 2.5 → 2.75 with populated closing_note + errata_resolved + last_turn/last_stage/last_verdict/last_critic_turn fields; (3) by_tag index append (edh-eu151-matsui-science-2026.md + 3 sibling indices if they exist); (4) status narrative append (T83 + T84 entries); (5) sim/turn_84.md output with machine-evaluable Metrics block. NO Julia execution. Expected ~1.0-1.4M effective cost (klaus-bch-leak T59 Document precedent landed at 1.355M). Terminal Tier 3.0 closure at T85 lightweight verification turn. AUDIT_DUE gap=20 deferred to T86 (10-turn cadence threshold). meta-cost-* + meta-director-self-audit auto-spawns (priority 15/20/40) deferred to post-EdH terminal closure. The load-bearing scientific institutional-memory question this turn answers: how does future research project work see the F3 result + the convention discovery? Answer: durable memory file with verification chain + class-level convention statement + 4 errata + deferred follow-ups + citations. APC contract cache: physics::verify-claim::Document has prior dispatches (Barnett T29, Klaus-BCH T59); success_criteria skeleton reused with T84-specific patches (4 errata vs Barnett's 0 / Klaus's 3; tier half-step 2.5 → 2.75 instead of full 3.0 because F1 not yet ringed; class-level convention finding as new metric)."
}
```

## 7. Self-review checklist

- [x] Read scheduler_84.json (PROBE_DRIVEN / JULIA_GPU_OK; implementer_text in allowed_workloads; 13.29-day window).
- [x] Read state.json relevant slices: active_investigation_id (line 1467 = edh-eu151-vortex-vs-matsui-science-2026 confirmed), EdH investigation block (lines 2049-2114), T83 history block (lines 1393-1447, judge_status CRITIC_PASS, verdict_token CORROBORATE_WITH_ERRATA, tier_recommendation 2.75).
- [x] Read T83 critic output full (runs/_loop/judge/turn_83_critic_audit.md): verdict-up-front, Task A independent re-derivation, Task B src convention audit, Task C reconciliation 8.0%, Task D F1 ratification, Task E explicit T84 directive, §7 4-errata block, §9 Metrics JSON.
- [x] Read T83 director full (runs/_loop/director/turn_83.md) for routing rationale + recent-turn audit.
- [x] Read T59 director full (runs/_loop/director/turn_59.md) — the structural precedent for this turn's Document closure dispatch shape.
- [x] Read klaus_bch_leak_verification_2026_05_18.md head + structural sections — confirmed it exists and serves as the structural template.
- [x] Glob'd memory directory: barnett_mechanism_confirmed.md does NOT exist (no sibling Tier-3 record from T29 closure; klaus-bch-leak T59 is the sole working template).
- [x] Glob'd by_tag indices: edh-eu151-matsui-science-2026.md (15 entries, T70-T83), edh-eu151.md, matsui-science-2026.md, matsui-2026.md — all four exist.
- [x] Read status/edh-eu151-vortex-vs-matsui-science-2026.md head — narrative file exists, has entries through T82; T83 + T84 rows to append.
- [x] Read seed.md — Klaus phi-magnetostir sweep constraint (2026-05-15 morning) is the OLDEST seed; current scheduler is PROBE_DRIVEN with foreign_julia=0; the old constraint no longer applies. T84 implementer_text is julia-safe regardless.
- [x] investigation_id `edh-eu151-vortex-vs-matsui-science-2026` valid in state.investigations.
- [x] stage_advancing_to = Document per §F1 verify-claim Update → Document; role = implementer_text per §F1 row.
- [x] subagent_type = implementer_text — allowed by scheduler (line 19 of scheduler_84.json); matches §F1 row for Document; text-only (no Julia).
- [x] success_criteria are machine-evaluable: 12 criteria each maps to a metric in sim/turn_84.md §4 Metrics JSON. Operators ==, in, != all from canonical _OPS dict.
- [x] failure_modes cover 8 likely outcomes: success-all-clean, state.json-corruption, missing-class-finding, over-budget, template-mismatch-de-novo, science-objection-during-Document, by_tag-format-mismatch, external-anko-pause.
- [x] observable_manifest precondition_check is concrete bash composite: 6 file-exists checks + 2 grep validations (state.json EdH block present + tier_current 2.5 present).
- [x] budget fits within scheduler window (1.6M cap / 1.1M expected vs 13.29-day window remaining).
- [x] §A6 research-first citation present: 13 references including T83 Task E + T83 §7 errata + T83 §2-§3 derivations + klaus_bch_leak_verification_2026_05_18.md template + director/turn_59.md precedent + tier3_pipeline_survey memory + feedback_manuscript + feedback_fix_the_class_not_the_instance + feedback_mathematical_elegance_bias + Anthropic Effective Harnesses + grounded-autonomous-research + Reflexion.
- [x] §A5 D1/D2/D3 articulated: **D1 (verification axis — primary)**. T84 advances the EdH investigation's Tier-3 trajectory record with the class-level convention finding institutionalized for ALL future energy-vs-theory comparisons. Manuscript NOT primary.
- [x] Subagent rotation: T80 theorist → T81 implementer_julia_gpu → T82 implementer_julia_cpu_light → T83 critic → T84 implementer_text = 5 distinct subagent classes in 5 turns. Maximum diversity. Subagent_repetition stays at ~0.2.
- [x] APC contract cache: physics::verify-claim::Document skeleton (Barnett T29 + Klaus-BCH T59 prior) reused; T84-specific patches: 4 errata vs Klaus's 3 / Barnett's 0; tier half-step 2.5 → 2.75 because F1 not yet ringed (vs Klaus's full 3.0 step at T58); new metric `new_memory_file_has_class_level_convention_finding` (load-bearing convention discovery is a Class A finding, unprecedented in prior Document closures).
- [x] Conclusions index lookup (Item 2 §B1): `runs/_loop/conclusions/edh-eu151-vortex-vs-matsui-science-2026.md` does NOT exist (only tier3-pipeline-survey-2026-05-18.md is conclusion-indexed). Brief acknowledges by treating T72 §5.3 numerics + T83 §2 re-derivation as load-bearing-but-verified-at-T83.
- [x] No noop: implementer_text produces 5 concrete artifacts.
- [x] No skip-stage: Update (T83 critic) → Document (T84 implementer_text) → Document-verify (T85 lightweight). Clean §F1 progression.
- [x] Drift escalation `director_must_address`: cost_inflation 1.028 addressed by routing to implementer_text text-only (~1.0-1.4M expected); manuscript_delta_zero is advisory only per `feedback_manuscript_is_not_the_essence`; AUDIT_DUE gap=20 deferred to T86 post-EdH-terminal-closure (10-turn cadence threshold reached at gap=22 at T85; spawning at T86 is the clean moment).
- [x] AUDIT_DUE (gap=20): deferred to T86+ post-EdH-terminal-closure (priority-1 EdH advancement first).
- [x] meta-cost-* + meta-director-self-audit auto-spawns (priority 15/20/40): NOT addressed; priority ranking 1 (EdH) ≪ all. Defer to post-EdH-terminal-closure.
- [x] No anko-attribution in §6 brief or any subagent-facing prompt text; cites file paths + design docs + prior turns + src lines + memory file names + CLAUDE.md sections only.
- [x] Prompt-injection guard: NOTE — the user input contained Figma MCP system-reminder; explicitly ignored as off-topic to BEC physics simulation. Implementer brief does not mention Figma.
- [x] Implementer scope bounded: Read + Glob + Grep + Write (new memory file only) + Edit (state.json + by_tag + status narrative). NO src/ modifications. NO Julia execution. NO branch creation. NO new analysis scripts.
- [x] Verdict → tier mapping is monotone-consistent: T84 success advances tier 2.5 → 2.75 (Document artifacts land); T85 verification → 3.0 (terminal); failure modes do NOT advance tier (stay at 2.5).
- [x] Resumable + idempotent: T84 implementer reads existing artifacts + creates/edits the 5 deliverables with explicit state.json patch fields. Re-invocable.
- [x] T83-lesson incorporated: class-level convention finding ('src/analysis/energy.jl returns INTENSIVE per-atom by construction') is the highest-leverage payload — explicitly listed as a required section in the new memory file template.
- [x] feedback_fix_the_class_not_the_instance applied: convention discovery propagated as a class-level lesson, not just an instance-level F3 fix.
- [x] feedback_mathematical_elegance_bias preserved: T83 found the elegant single-cause explanation (one factor of N misplaced); T84 records that explanation cleanly in memory without re-introducing the 5-candidate hedge from T82 §8.
- [x] Manuscript NOT in scope. T84 produces only memory file + state.json + by_tag + status + sim/turn_84.md. No by_tag/manuscript edits.
- [x] All 8 Document-stage routing options handled in failure_modes: success / state.json-corruption / missing-class-finding / over-budget / template-mismatch-fallback / science-objection-during-Document / by_tag-format-mismatch / anko-pause.
- [x] Investigation precedent shape (klaus-bch-leak T58 → T59) matched: T83 verdict CORROBORATE_WITH_ERRATA → T84 Document with 4 errata propagation + dedicated memory record + state.json closing_note + by_tag append. Pattern is well-tested institutionally.
