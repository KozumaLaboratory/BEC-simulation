---
turn: 69
subagent: director
investigation_id: tier3-verification-pipeline-survey-2026-05-18
stage_advancing_from: null (new survey-flow investigation spawning at Research stage)
stage_advancing_to: Research (survey-template §F4: researcher enumerates [Established] memory claims that are Tier 1-2 and proposes top-3 Tier-3 verification candidates)
topic_tags: [d1-verification-depth, established-claim-audit, tier3-pipeline-population, memory-inventory-scan, post-tier3-pipeline-empty, survey-flow-template, novel-claim-zero-mitigation-real]
paper_section: null
depends_on: [68, 67, 66, 65, 59, 29, "runs/_loop/director/turn_68.md", "runs/_loop/state.json", "runs/_loop/_local/scheduler_69.json", "runs/_loop/seed.md", "memory:feedback_manuscript_is_not_the_essence", "memory:feedback_decision_style", "memory:feedback_cost_overhead_is_the_cost", "memory:loop_architecture_2026_05_14"]
produces: "runs/_loop/research/turn_69.md enumerating Tier 1-2 [Established] memory claims, scored on (a) load-bearing-ness for production code, (b) external-benchmark availability (Stuttgart / Innsbruck / Yan-Li-Saito / etc.), (c) cheapness of falsifier; top 3-5 candidates with proposed falsifier sketches + minimum-viable verification budget; seed-md-ready stubs anko can ratify into priority-1-3 investigations."
---

# Turn 69 — Director Report

## 1. Investigation state snapshot

- **active_investigation_id (state.json line 1926)**: `audit-due-heuristic-bug-2026-05-18` (closed at T68 PASS — that turn's success). Switching this turn to a new investigation.
- **All anko priority 1-3 physics investigations remain terminally closed/dormant** (unchanged from T68 snapshot):
  | id | priority | tier | current_stage | last_turn |
  |---|---|---|---|---|
  | barnett-mechanism-2026-05-16 | 1 | 3.0 / target 3 | closed | T29 |
  | yan-li-saito-2026-reproduction | 1 | 0.4 / target 3 | closed (DORMANT-CLOSE; F1 REFUTED) | T65 |
  | klaus-magnetostir-bch-leak-2026-05-13 | 3 | 3.0 / target 3 | closed | T59 |
  | judge-in-operator-bug-2026-05-18 | 2 | 2 / target 2 | closed | T54 |
  | audit-due-heuristic-bug-2026-05-18 | 4 | 2 / target 2 | closed | T68 |
  | audit-class-scan-2026-05-18-T50 | 20 | 2 / target 2 | closed | T54 |
  | audit-class-scan-2026-05-18-T61 | 20 | 2 / target 2 | closed | T63 |
  | meta-stage-routing-2026-05-18 | 25 | 0.0 / target 1 | closed (REFUTED-BY-CONFOUNDER) | T60 |
  | meta-internal-b-unification-2026-05-18 | 5 | 1 / target 1 | closed (mechanical) | T49 |
  | fullbdg-f6-polar-3000x | 99 | 1.5 / target 2 | dormant (anko-contained) | — |
  | meta-critic-placement-2026-05-17 | 50 | 0 / target 2 | dormant (Observe, no anko trigger) | — |
- **Scheduler (scheduler_69.json)**: policy=JULIA_GPU_OK, all workloads allowed; window 1,171,660s left (~13.5 days); VRAM 12,970 MB free; foreign_julia=0. No constraint pressure.
- **Last judge verdict (T68)**: PASS for audit-due-heuristic-bug fix; all 7 success criteria met.
- **T68 drift signals (state.json line 1892-1905)**:
  - `manuscript_delta_zero: 1.0` → DRIFT_MANUSCRIPT_DELTA_ZERO (design-persistent per `feedback_manuscript_is_not_the_essence`).
  - `novel_claim_zero: 1.0` → DRIFT_NOVEL_CLAIM_ZERO (3 consecutive: T66 hygiene + T67 noop + T68 mechanical fix all scored zero on `[Established]` theorist tags — by construction).
  - `cost_inflation: 0.727` → below threshold.
  - `AUDIT_DUE`: ABSENT (T68 fix cleared it correctly).
  - `drift_escalation: director_must_address`.
- **§B2 elimination pass for existing investigations**: all eliminated.
  - 9 of 11 investigations: `current_stage in {closed, "closed (...)"}`, eliminated.
  - 2 of 11 investigations dormant + priority high: `fullbdg-f6-polar-3000x` priority 99 (anko-contained), `meta-critic-placement-2026-05-17` priority 50 (no anko trigger). Both eliminated per `current_stage == dormant AND priority >= 50` rule (director.md §B2).
  - Zero candidates from existing pool.
- **New for T69**: spawning `tier3-verification-pipeline-survey-2026-05-18` with `survey` flow template (§F4), at Research stage. Goal = populate the investigation pipeline (currently empty) with concrete Tier-3 verification candidates for anko to ratify into priority-1-3 slots in seed.md.

## 2. Recent-turn audit (last 3 turns)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T66 | Document (yan-li-saito current_stage canonicalize) | PASS | Implementer_text 1-line yaml hygiene fix. Cost 8.0M raw / 1.21M eff. |
| T67 | null (steady-state noop) | NOOP_DIRECTOR | Director report only; mis-diagnosed AUDIT_DUE as "false positive". Cost 5.86M raw / 861k eff. |
| T68 | Fix (collapsed fix-bug; AUDIT_DUE heuristic data bug) | PASS | Implementer_text added 5 turn: fields to patterns.yaml audit_history + 6-line institutional comment. Cost 6.58M raw / 1.08M eff. Other advisories unchanged (manuscript+novel_claim_zero still triggered). |
| T69 (THIS) | Research (new survey investigation) | (TBD) | Researcher scans MEMORY.md + runs/_loop/by_tag/ for [Established] tier-1-2 claims and proposes top-3 Tier-3 verification candidates with falsifier sketches + budget estimates. |

## 3. Flow template recall

- **Template**: `survey` (§F4) — `Research → Synthesize → Document → closed`. Low-commitment exploration template; appropriate when the pipeline is empty and we need to surface candidate investigations rather than commit to one.
- **Role for stage Research**: `researcher`. Per `.claude/agents/researcher.md` Section 0 the researcher reads `state.investigations[active_investigation_id]` and director §6.
- **Why this stage now (vs continuing prior investigation, vs different investigation, vs noop)**:
  - **Prior investigation (audit-due-heuristic-bug)** closed at T68 PASS — nothing to continue.
  - **Different investigation**: zero candidates in existing pool per §1.
  - **Noop**: T68 director's §5 forecast explicitly said "DO NOT noop two turns in a row past T68 — escalates per the 3-noops warrants meta or halt rule from T67." T67 was already a noop; T68 was a real dispatch (fix-bug). T69 should NOT regress to a second noop.
  - **Survey-template spawn** is the pipeline-population move: aligns with `feedback_manuscript_is_not_the_essence` D1 axis ("verification depth — cross-validation against Stuttgart/Innsbruck, ..., audit of [Established] memory claims for hidden errors"), produces concrete falsifier sketches anko can ratify, and is cheap (single researcher dispatch ~1.5-2M eff).
- **Why survey vs verify-claim directly**:
  - Picking ONE [Established] claim and running verify-claim now without anko ratification risks: (a) picking the wrong claim from anko's perspective, (b) anko has explicit `seed.md` priority interface for declaring priority-1-3 investigations.
  - Survey produces a ranked **menu**; anko picks. This respects `seed.md` as the "anko's interface" channel.
  - Per `feedback_decision_style` ("pick defaults and move"): the default for empty pipeline is "surface candidates", not "spawn the most exciting one without input".
- **Why NOT spawn a meta-investigation on novel_claim_zero metric**:
  - T67/T68 both forecasted considering this. The metric IS over-counting hygiene phases (T66+T67+T68 all 1.0; mechanical fixes legitimately produce no `[Established]` theorist tags). 
  - But spawning a meta-investigation right NOW would mean: T69 = meta-investigation, while the pipeline is empty of physics. That deepens the metric problem rather than fixing it. The right move is to do real D1 work that DOES produce `[Established]` tags (theorist Synthesize stage at T70+), which naturally clears novel_claim_zero. Meta-investigation can wait until anko explicitly requests metric recalibration OR until 5+ consecutive turns trigger it.
- **Why NOT initiate a new physics investigation unilaterally (e.g., pick Bug-4 re-verification debt)**: per `seed.md` "How to add a new investigation" section, anko's interface is appending to seed.md. The director's job is to surface candidates THROUGH the survey, not to commit anko's priority queue. Survey output goes back to anko via researcher .md + director T70 review; anko ratifies into seed.md if accepted.

## 4. Research grounding (§A6)

Per §A6: dispatch must cite ≥1 external reference. Survey-template Research stage is researcher-led and grounded in external sources by construction. Director's grounding for the **dispatch decision**:

1. **Memory `feedback_manuscript_is_not_the_essence.md`** (anko 2026-05-15, re-loaded this turn with staleness-warning acknowledged): "D2 Verification depth — cross-validation against Stuttgart/Innsbruck, F-δ signature test, audit of [Established] memory claims for hidden errors." This survey directly targets that axis. The memory is 2 days old but the directive ("manuscript polish is OUT; D1/D2/D3 are IN") was explicit and has not been retracted in any subsequent feedback memory.
2. **`director.md` §D1**: "Most [Established] memory entries are Tier 1-2. Zero are Tier 3 currently. The biggest blank space." (As of pre-Barnett-T29: now we have 2 Tier-3 claims — Barnett T29 + Klaus-BCH T59 — so the count is "2 Tier-3 out of dozens of [Established] claims". The "biggest blank space" framing still holds.)
3. **`runs/_loop/research/auto_research_architecture_2026_05_16.md`** (per director.md §B1): the loop's architecture explicitly includes survey template for low-commitment exploration; this is the design-intended use.
4. **Memory `loop_architecture_2026_05_14.md`** (validated phase 0+1): cross-references that the researcher role exists precisely to enumerate citable facts; survey use here is in-charter.
5. **Memory `feedback_decision_style.md`** (anko 2026-04-24): "pick defaults and move". Default for empty pipeline = surface candidates for anko to choose; don't deliberate.
6. **Memory `feedback_cost_overhead_is_the_cost.md`** (anko 2026-05-15): "deliberation is more expensive than the work". Single researcher dispatch (~1.5-2M eff) beats a 3rd noop turn (~0.9M eff but zero value) plus the eventual catch-up cost.
7. **Anthropic context engineering essay (per director.md §G)**: "Write strategy for durable state" — researcher output is durable; future directors can read research/turn_69.md and pick from the candidate list without re-doing the scan.
8. **Loop precedent T30 (yan-li-saito Hypothesize stage)** + **T11 (barnett Hypothesize)**: both showed that careful researcher-led groundwork BEFORE picking falsifiers prevents wasted execute-stage cost. The pattern of "researcher scan → director routes → theorist hypothesize" is well-established and reliably produces Tier 2+ outcomes (Barnett T29 Tier-3 closure traces back to T11 researcher anchor).

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verification axis)** — primary axis per anko's essence statement. This turn's researcher produces a prioritized list of Tier 1-2 [Established] claims that lack Tier-3 cross-implementation or published-reference benchmarking. Output is directly actionable: anko reads it, picks 1-3 candidates, appends to seed.md, T70+ director picks up the highest-priority one and routes through verify-claim flow.
- **Tier ladder position**: new investigation `tier3-verification-pipeline-survey-2026-05-18` enters at tier 0 → target tier 1 (Tier 1 for survey = "researcher delivers ranked candidate list with falsifier sketches + budget"). Survey is low-tier by nature; the VALUE is in the candidates it enables, not the survey itself reaching Tier 3.
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`).
- **DRIFT_NOVEL_CLAIM_ZERO at T68 (3rd consecutive)**: T69 is a researcher dispatch with no theorist `[Established]` tag output — the metric will likely hit 4-consecutive. **However**, the researcher output establishes the candidate list FROM WHICH the eventual theorist Hypothesize stage at T70+ will produce real `[Established]` tags. The metric will naturally clear at T70 or T71 once anko ratifies a candidate and the verify-claim flow's Hypothesize stage runs (theorist always emits `[Established]` tags on prior-art citations). So the 3+ consecutive trigger is acknowledged but the trajectory is correct — the FIX is more physics work in pipeline, which this turn enables.
- **Loop steady-state diagnostic**:
  - Cost trending stable post-closure phase: T64-T68 in the 5.86-8.5M raw / 0.86-1.31M eff range. T69 forecast ~6-8M raw / ~1.5-2.0M eff (researcher dispatch reading memory inventory + WebSearch checks on benchmark availability + Write to research/turn_69.md).
  - Verdict streak post-T53: 14/14 turns operationally clean. T69 is structured to preserve this streak (researcher contract is lighter than theorist/implementer, and success criteria are checkable by file-existence + grep).
- **Recommended T70+ trajectory** (informational):
  - T69 researcher produces research/turn_69.md with 3-5 candidates ranked by (a) load-bearing for production code × (b) external-benchmark availability × (c) cheapness.
  - T70 director either: (i) waits for anko to ratify candidates into seed.md (NOOP_DIRECTOR with rationale "T69 candidates surfaced; awaiting anko"), or (ii) if anko has already updated seed.md by T70, advance the top-ratified investigation through Hypothesize → Design.
  - If anko silent through T70 AND novel_claim_zero hits 5-consecutive, escalate per "5+ noops" rule: ping anko explicitly via state.json closing_note + suspend until ratification.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "tier3-verification-pipeline-survey-2026-05-18",
  "stage_advancing_to": "Research",
  "subagent_type": "researcher",
  "rationale": "All anko priority 1-3 physics investigations terminally closed/dormant; pipeline empty. T67 noop + T68 mechanical-fix have left the loop in a state where T69's third consecutive non-physics turn would regress per T68 §5 forecast. Per `feedback_manuscript_is_not_the_essence` D1 axis (verification depth — audit of [Established] memory claims for hidden errors) and director.md §D1 (most [Established] memory entries are Tier 1-2; only 2 currently at Tier 3), the highest-leverage cheap move is to populate the investigation pipeline with concrete Tier-3 verification candidates anko can ratify into seed.md. Survey-template flow §F4 is designed exactly for this low-commitment exploration; researcher Research stage is the entry point. Single researcher dispatch (~1.5-2M eff) is cheaper than another mechanical-fix turn and produces durable state (research/turn_69.md) future directors can route off.",
  "brief": "ROLE: researcher (text-only, no julia, no GPU, no sympy). TASK: Survey the [Established] memory claims in the SpinorBEC.jl loop knowledge base and propose 3-5 top candidates for Tier-3 verification (Tier 3 = published-reference benchmarked, per director.md §D1).\n\n=== CONTEXT YOU MUST READ FIRST ===\n\n1. `runs/_loop/director/turn_69.md` §1-§5 — this director report (load-bearing rationale).\n2. `.claude/agents/director.md` §D (D1/D2/D3 axes; tier ladder definitions; project goals).\n3. `runs/_loop/seed.md` — anko's investigation priority interface; the candidates you propose will be in a format anko can paste into the 'Active investigations' section.\n4. `.claude/projects/-home-suzume-workspace-BEC-simulation/memory/MEMORY.md` — top-level index of [Established] tags and tier-references; treat as the master inventory.\n5. `runs/_loop/by_tag/` — per-tag turn histories; cross-reference for tier-history.\n6. **Production code constraints (CLAUDE.md 'Conventions do NOT fix' + 'Known limitations')**: do NOT propose verification of intentional design choices (DDI no-4π convention, _YOSHIDA_W0<0, ITP Zeeman min-shift, scalar LHY @warn, etc.). Those are by-design; verification would be wasted.\n\n=== TASK SPECIFICATION ===\n\nFor each candidate, produce:\n\n  (a) **CLAIM ID**: a concise kebab-case label (e.g., `tdhfb-phase2-hf-kernel-vs-published-F6-polar`, `bug-4-itp-ddi-half-rate-pre-fix-runs-residual-error`, `universal-structure-u1-u4-classification-vs-mizushima-2012`).\n\n  (b) **CURRENT TIER + EVIDENCE**: cite the memory file(s) and prior turn(s) that establish current tier (Tier 1 = internal regression only; Tier 2 = closed-form / sympy / cross-implementation verified). State explicitly why it is NOT yet Tier 3.\n\n  (c) **LOAD-BEARING-NESS FOR PRODUCTION CODE**: score 1-5. 5 = called in hot paths of run_yaml/find_ground_state/run_simulation!; 1 = isolated utility. Cite the src/* call site(s) that depend on this claim being correct.\n\n  (d) **EXTERNAL-BENCHMARK AVAILABILITY**: identify ≥1 published source (paper, Stuttgart/Innsbruck/MIT/Kyoto experiment, Yan-Li-Saito-style PRL, etc.) whose data could falsify or corroborate the claim. Cite DOI/arXiv. If you cannot find an external benchmark, mark NOT_FOUND and lower the recommendation rank. Use WebSearch + WebFetch as needed; cache results in `.claude/knowledge/` per researcher.md §A3.\n\n  (e) **PROPOSED FALSIFIER SKETCH** (1-2 sentences each, no derivation): what concrete numerical comparison would constitute Tier-3 evidence? E.g., 'Reproduce Stuttgart Eu dipolar magnetization decay rate Γ_dr=X.X s⁻¹ at B=Y G within 30% — closer = corroborate, ≥3× off = refuted.'\n\n  (f) **MINIMUM-VIABLE BUDGET**: rough cost estimate to drive the candidate to Tier 3 (number of turns × workload class: theorist text / julia_cpu_light / julia_gpu_heavy). Be explicit if a candidate needs >5 turns; that's a flag for anko.\n\n  (g) **RECOMMENDED PRIORITY**: 1-3 ranking among your candidates. Tie-break by load-bearing-ness × cheapness.\n\n=== HARD CONSTRAINTS ON YOUR OUTPUT ===\n\n  - You may use Read (memory + by_tag + src), Grep (find call sites + cross-references), Glob (memory file index), WebSearch + WebFetch (benchmark availability). NO Edit, NO Bash, NO Write to anything except `runs/_loop/research/turn_69.md`.\n  - Do NOT invent citations. If you cannot find a published benchmark for a candidate, mark NOT_FOUND honestly. NOT_FOUND is useful information — it tells anko which claims are stranded without external comparison.\n  - Do NOT propose verification of intentional design choices (re-confirmed from CLAUDE.md 'Conventions do NOT fix' + 'Known limitations' sections — list inline at top of your report).\n  - Do NOT propose to verify the already-Tier-3 claims (Barnett mechanism T29, Klaus-BCH leak T59). They are closed.\n  - Do NOT propose to revive yan-li-saito-2026-reproduction (closed DORMANT at T65 after F1 REFUTED). It is a paper-anchor problem, not a framework-claim problem.\n  - DO include 'Bug-4 ITP DDI half-rate (FIXED 2026-05-02)' re-verification debt as a candidate — MEMORY.md flags 'All Eu DDI runs predating 2026-05-02 should be re-verified' as an outstanding D1 task.\n  - DO consider candidates from: Sign Pattern Lemma 1 General-S (verified at 26 channels exact rational arithmetic — could be cross-implementation against Kawaguchi-Ueda 2012 review), TDHFB Phase 2 generic-F HF kernel (208 tests Tier-2 — could benchmark against Lima-Pelster 2010 / Wachtler-Santos 2016 numerics), Universal Structure U1-U4 (Tier 2; could benchmark against Mizushima-Machida-Ohmi 2012 polyhedral classification), F=6 polar TwoChannelLHY 30-70% off claim (pinned in test but no external benchmark; opportunity), full_bdg F=6 polar 3000× spurious offset (contained but NOT yet root-caused — Tier-2 candidate not Tier-3).\n\n=== OUTPUT FORMAT ===\n\nWrite to `runs/_loop/research/turn_69.md`. Use the template:\n\n```\n---\nturn: 69\nsubagent: researcher\ntopic_tags: [d1-verification-depth, tier3-pipeline-survey, established-claim-audit, post-closure-pipeline-population]\ndepends_on: [director/turn_69]\nproduces: ranked candidate list for anko to ratify into seed.md\n---\n\n# Turn 69 — Researcher Report: Tier-3 Verification Candidates Survey\n\n## 1. Inventory scan summary\n\n- Total [Established] tags scanned in MEMORY.md: <N>\n- Already Tier-3: <list>\n- Intentional-design (excluded): <list with reason cite>\n- Eligible candidates (Tier 1-2, load-bearing, NOT intentional): <count>\n\n## 2. Top candidates (ranked)\n\n### #1 (recommended priority): <CLAIM_ID>\n- Current tier + evidence: …\n- Load-bearing-ness: …\n- External-benchmark availability: …\n- Proposed falsifier sketch: …\n- Minimum-viable budget: …\n\n### #2: <CLAIM_ID>\n…\n\n### #3: <CLAIM_ID>\n…\n\n### #4-5 (lower priority, listed for completeness): …\n\n## 3. Excluded candidates (with rationale)\n\n(e.g., yan-li-saito reproduction, intentional design choices, ...)\n\n## 4. NOT_FOUND items (claims without external benchmark)\n\n…\n\n## 5. Seed.md-ready stubs (anko may paste verbatim)\n\nFor the top 2-3, produce a copy-pasteable seed.md entry in the same format as the existing 'Active investigations' entries (id / priority / hypothesis / tier_target / falsifier list).\n\n## 6. Self-review checklist\n- [ ] No invented citations (every benchmark has a DOI/arXiv or NOT_FOUND).\n- [ ] No intentional-design candidates proposed.\n- [ ] Bug-4 re-verification candidate included.\n- [ ] All candidates have load-bearing-ness × benchmark-availability × cheapness scored.\n- [ ] Seed.md stubs follow existing format.\n```\n\n=== SUCCESS SIGNAL ===\n\nFile `runs/_loop/research/turn_69.md` exists, parses as markdown frontmatter + body, contains ≥3 ranked candidates (each with all 7 fields a-g populated or explicit NOT_FOUND for a benchmark), contains the Bug-4 re-verification candidate, contains seed.md-ready stubs for the top 2-3.\n\n=== BUDGET ===\n\nExpected ~1.5-2.0M effective. ~30-45 min wall time for memory inventory + WebSearch/WebFetch for 3-5 benchmarks + write-up. Hard cap: 3M effective; if you hit it before finishing, write what you have and end honestly.\n\n=== STATE.JSON UPDATE (your responsibility) ===\n\nAt end of work, also append the new investigation entry to `runs/_loop/state.json`:\n  - `investigations.tier3-verification-pipeline-survey-2026-05-18`: id, title='Tier-3 verification pipeline candidate survey (post-pipeline-empty pipeline population)', hypothesis='Pipeline has zero open priority-1-3 physics investigations; researcher Research stage produces ranked candidate list for anko to ratify into seed.md', flow_template='survey', current_stage='Research', stages_done=['Research'], stages_at_turn={'Research': [69, 'researcher inventoried <N> [Established] tags, produced <M> ranked candidates']}, tier_current=1, tier_target=1, next_stage='Synthesize', next_stage_action='Pending anko ratification of candidates into seed.md OR theorist Synthesize stage at T70 if anko silent', blocked_on='anko ratification of candidate priority', priority=10, kind='physics', closing_note=null.\n  - Append id to `investigations_index`.\n  - Set `active_investigation_id` to 'tier3-verification-pipeline-survey-2026-05-18'.\n  - DO NOT touch other investigations.\n\nGUARDRAIL: NO git commit, NO branch creation, NO touching src/, NO touching test/, NO touching `.claude/scripts/*`. The research/turn_69.md is the only new file, and state.json is the only existing file you modify outside of cache writes.",
  "observable_manifest": {
    "required": ["research_turn_69_md_exists", "candidate_count", "bug_4_re_verification_included", "seed_md_stubs_count", "invented_citations_count"],
    "optional": ["not_found_benchmarks_count", "cache_hits"],
    "precondition_check": "cd /home/suzume/workspace/BEC-simulation && test -f runs/_loop/state.json && test -f runs/_loop/seed.md && test -d runs/_loop/by_tag && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/MEMORY.md && python3 -c \"import json; s=json.load(open('runs/_loop/state.json')); assert 'tier3-verification-pipeline-survey-2026-05-18' not in s['investigations'], 'investigation already exists — director duplicate spawn'; print('OK_T69_precondition: new investigation slot clean')\""
  },
  "success_criteria": [
    {
      "id": "research_file_written",
      "metric": "research_turn_69_md_exists",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Survey Research stage's product is the researcher's md file under runs/_loop/research/."
    },
    {
      "id": "candidate_count_meets_minimum",
      "metric": "candidate_count",
      "operator": ">=",
      "value": 3,
      "tolerance": null,
      "rationale": "Brief requires ≥3 ranked candidates; fewer indicates incomplete scan or excessive filtering."
    },
    {
      "id": "bug_4_re_verification_candidate_included",
      "metric": "bug_4_re_verification_included",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "MEMORY.md explicitly flags Bug-4 (ITP DDI half-rate FIXED 2026-05-02) re-verification as outstanding D1 task ('All Eu DDI runs predating 2026-05-02 should be re-verified'). Researcher must include it as a candidate per brief explicit instruction."
    },
    {
      "id": "seed_md_stubs_produced",
      "metric": "seed_md_stubs_count",
      "operator": ">=",
      "value": 2,
      "tolerance": null,
      "rationale": "Top 2-3 candidates must have copy-pasteable seed.md-format stubs so anko's ratification action is one paste. <2 stubs would mean researcher didn't produce the actionable handoff."
    },
    {
      "id": "no_invented_citations",
      "metric": "invented_citations_count",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "researcher.md §A2 hard constraint: no invented citations. NOT_FOUND is OK; fabricated DOIs/arXiv IDs are not. Judge can verify by checking that every cited paper appears in WebSearch / WebFetch results in the researcher's tool history."
    },
    {
      "id": "state_json_investigation_recorded",
      "metric": "tier3_verification_pipeline_survey_2026_05_18_in_state_investigations",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Survey investigation must be recorded in state.json for future directors to pick up post-Research stage routing."
    },
    {
      "id": "investigation_at_research_stage",
      "metric": "tier3_verification_pipeline_survey_2026_05_18_current_stage",
      "operator": "==",
      "value": "Research",
      "tolerance": null,
      "rationale": "Survey flow §F4 starts at Research; investigation remains in Research stage post-T69 awaiting either anko ratification (which would close this survey and spawn child investigations) or T70 Synthesize stage if anko silent."
    }
  ],
  "failure_modes": [
    {
      "if": "researcher produces fewer than 3 candidates (e.g., over-filters intentional-design entries)",
      "category": "data_gap",
      "next_action": "T70 director reviews researcher output; if filtering rationale is sound (most [Established] tags are intentional-design or already Tier-3 and only 1-2 candidates legitimately exist), accept and advance to Synthesize stage with the small list; if researcher missed candidates (e.g., didn't scan by_tag/ files), re-dispatch researcher with broader scope."
    },
    {
      "if": "researcher invents a citation (judge detects DOI/arXiv that doesn't resolve in WebSearch)",
      "category": "operational",
      "next_action": "T70 director invalidates that candidate, requests researcher re-do that specific candidate's benchmark lookup, marks NOT_FOUND if no real benchmark exists. May indicate researcher.md A2 needs re-emphasis (already strong in agent prompt; this would be a regression)."
    },
    {
      "if": "researcher proposes verification of intentional design choices (e.g., DDI no-4π convention)",
      "category": "operational",
      "next_action": "T70 director removes those candidates from the list; the brief explicitly prohibits them. Indicates the researcher didn't read CLAUDE.md 'Conventions do NOT fix' carefully; tighten brief on future surveys."
    },
    {
      "if": "researcher exceeds 3M effective hard cap without completing all 5 candidates (cost overrun)",
      "category": "operational",
      "next_action": "T70 director accepts the partial output (researcher was instructed to end honestly at cap); if ≥3 candidates with required fields are present, advance to Synthesize at T70 with what we have; if <3, treat as Research-stage-incomplete and re-dispatch with narrower scope (e.g., 'only TDHFB-related claims')."
    },
    {
      "if": "researcher returns OUT_OF_SCOPE (refuses task as theorist-like rather than librarian-like)",
      "category": "framework_error",
      "next_action": "T70 director re-reads researcher.md §A1; this task IS librarian-shape (enumerate facts about existing claims + cite benchmarks). If researcher's OUT_OF_SCOPE is wrong, override and re-dispatch with explicit 'this is inventory + citation work, not derivation' clarification. If researcher's OUT_OF_SCOPE is right (we accidentally asked for derivation), re-route to theorist with revised brief."
    },
    {
      "if": "all candidates' external-benchmark availability is NOT_FOUND",
      "category": "framework_error",
      "next_action": "T70 director treats this as a finding: the project's [Established] claims are stranded without external comparison. This itself is a meta-result worth recording. Next move: consider survey-template Synthesize stage at T70 producing a memory entry 'project-tier3-pipeline-empty-due-to-benchmark-vacuum' so anko can decide whether to (a) accept Tier 2 as ceiling for these claims, or (b) target experimental collaborations for benchmarks."
    },
    {
      "if": "state.json edit by researcher introduces JSON syntax error (file no longer parses)",
      "category": "operational",
      "next_action": "T70 director runs `python3 -c \"import json; json.load(open('runs/_loop/state.json'))\"` to confirm; if broken, reverts via git checkout, re-instructs researcher with Edit-tool-only state.json modification (one minimal edit, not whole-file rewrite)."
    },
    {
      "if": "DRIFT_NOVEL_CLAIM_ZERO hits 4+ consecutive at T69 (T66+T67+T68+T69)",
      "category": "framework_error",
      "next_action": "T70 director acknowledges the metric is genuinely over-counting hygiene/survey phases — survey Research stage by design has no theorist [Established] tags. Considers spawning meta-investigation `novel-claim-zero-metric-calibration-2026-05-18` to suppress the metric for survey/research/hygiene turn types. Alternatively, if anko has ratified candidates by T70 such that T71 routes to theorist Hypothesize, the metric naturally clears at T71 and meta-investigation is unnecessary."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 3000000
  },
  "budget": {
    "expected_cost_eff": 1800000,
    "expected_wall_time_sec": 2100,
    "split_by_subtask": {
      "read_memory_index_and_by_tag": 300000,
      "grep_src_for_load_bearing_call_sites": 200000,
      "websearch_websearch_for_benchmarks_5_candidates": 600000,
      "write_research_turn_69_md_with_5_candidates": 500000,
      "state_json_update": 200000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Synthesize (or hold at Research if awaiting anko ratification — director T70 decides based on whether seed.md has new entries)",
    "if_success_tier_becomes": 1,
    "if_refuted_advance_to_stage": "Research (re-dispatch with narrower scope or expanded inventory list)",
    "if_refuted_tier_becomes": 0,
    "if_inconclusive_advance_to_stage": "Research (one-turn retry with diagnostic guidance on what was missing)",
    "if_inconclusive_tier_becomes": 0.5,
    "next_falsifier_to_test_after": "If anko ratifies candidates into seed.md by T70, the top-ranked candidate's verify-claim flow Hypothesize stage is the next move. If anko silent through T70, survey investigation advances to Synthesize stage (theorist) at T70 producing a methodology note on the pipeline state. If 5+ noops accumulate, escalate per state.json closing_note to anko."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json + scheduler.json + seed.md this turn (state.json multi-range covering active_investigation_id line 1926, all investigation current_stage/priority/blocked_on fields, history T28-T68, drift signals T64-T68 confirming AUDIT_DUE no longer present post-T68; scheduler_69.json full read confirms JULIA_GPU_OK + 13.5 days window; seed.md full read confirms NO new anko-prioritized investigation surfaced post-T68).
- [x] Read ≥1 memory file related to active investigation (new investigation; read 3 anko-feedback memory files: `feedback_manuscript_is_not_the_essence` — load-bearing for D1-axis justification; `feedback_decision_style` — for "pick defaults and move" choice between survey-spawn vs noop; `feedback_cost_overhead_is_the_cost` — for budget guard; staleness-warning on `feedback_manuscript_is_not_the_essence` acknowledged in §4).
- [x] investigation_id valid in state.investigations (new id `tier3-verification-pipeline-survey-2026-05-18` spawning this turn; precondition check ensures no duplicate slot pre-fix).
- [x] stage_advancing_to is the next stage per flow template (survey §F4 entry stage is Research; this is the canonical entry point).
- [x] subagent_type matches role_per_stage[stage] (researcher for Research stage in survey template; researcher.md §0 + §A4 confirm output path `runs/_loop/research/turn_69.md`).
- [x] success_criteria are machine-evaluable: file existence boolean, candidate count integer, included-candidate boolean (Bug-4), seed-md stubs count integer, invented-citations count integer, state.json field presence boolean + literal-equality string — all directly checkable by python json + grep + file-existence.
- [x] failure_modes cover 8 most likely failures: too few candidates (data gap), invented citation (operational), intentional-design proposed (operational), cost overrun (operational), OUT_OF_SCOPE refusal (framework error), all-NOT_FOUND benchmarks (framework error), JSON corruption (operational), DRIFT_NOVEL_CLAIM_ZERO 4-consecutive (framework error). All have specific next-action mapping.
- [x] observable_manifest precondition_check is concrete: bash test for required files + python3 json check that investigation slot is clean (would catch duplicate-spawn class of bug).
- [x] budget fits within scheduler window_seconds_left (1.8M eff forecast vs 100M rolling cap; 35 min wall vs 13.5 day window — abundant).
- [x] §A6 research-first citation present (8 references: 3 anko-feedback memory files + director.md §D1 + auto_research_architecture_2026_05_16.md + loop_architecture_2026_05_14.md + Anthropic Write strategy + loop precedent T30/T11).
- [x] §A5 D1/D2/D3 articulated: T69 advances **D1 (verification axis — primary)** by populating the Tier-3 verification candidate pipeline. Justification: anko's essence statement explicitly names "verification depth" as the D1 axis; the pipeline is empty post-T68 closures; survey-template Research stage is the cheapest way to populate it without invoking anko unilateral priority. Manuscript NOT primary.
- [x] DRIFT_NOVEL_CLAIM_ZERO 3-consecutive acknowledged in §5; deferred to T70+ trajectory (real physics work clears it naturally; meta-investigation deferred).
- [x] Survey-template flow §F4 used per template-selection-rule "find what's known about Z" → survey (here "Z" = "[Established] memory claims that lack Tier-3 verification benchmark").
- [x] No noop: per T68 §5 forecast, T69 must NOT be a noop. Survey dispatch is real work and is cheaper than another mechanical-fix-style turn while producing more durable state.
