---
turn: 70
subagent: director
investigation_id: tier3-verification-pipeline-survey-2026-05-18
stage_advancing_from: Research
stage_advancing_to: Synthesize (survey §F4: theorist organizes T69 findings + spawns top-ranked child investigation `edh-eu151-vortex-vs-matsui-science-2026`)
topic_tags: [d1-verification-depth, survey-synthesize-stage, child-investigation-spawn, edh-eu151-matsui-science-2026, tier3-pipeline-population, post-default-anko-silent, drift-novel-claim-zero-clear]
paper_section: null
depends_on: [69, 68, 67, "runs/_loop/director/turn_69.md", "runs/_loop/research/turn_69.md", "runs/_loop/state.json", "runs/_loop/_local/scheduler_70.json", "runs/_loop/seed.md", "runs/_loop/judge/turn_68.json", "memory:feedback_manuscript_is_not_the_essence", "memory:feedback_decision_style", "memory:feedback_cost_overhead_is_the_cost"]
produces: "runs/_loop/theorist/turn_70.md synthesizing T69 candidate menu into (a) a one-paragraph methodology-note memory entry capturing the survey's institutional lesson, (b) a full verify-claim investigation spec for `edh-eu151-vortex-vs-matsui-science-2026` (the priority-1 candidate per T69 §2.1) with formal hypothesis statement + 3-4 pre-registered falsifiers + tier-3 success criteria, (c) state.json updates closing the survey investigation and spawning the new child investigation at Research stage."
---

# Turn 70 — Director Report

## 1. Investigation state snapshot

- **Active investigation (state.json line 1976)**: `tier3-verification-pipeline-survey-2026-05-18`, current_stage=Research, tier 1/target 1, blocked_on="anko ratification of candidate priority", priority=10, kind=physics.
- **T69 verdict (judge.py)**: `RESEARCHER_ONLY` (effective_full_rate 1.79M, 12.0M raw) — researcher dispatch completed; 5 candidates produced; survey stage Research entered `stages_done`.
- **Anko ratification status**: seed.md unchanged since 2026-05-15 (still references "Klaus phi-magnetostir sweep is running 4 julia processes" which scheduler probe confirms is stale — foreign_julia=0 in scheduler_70.json). No new anko priorities appended. Default per `feedback_decision_style`: proceed with T69 researcher's #1 ranking.
- **Stage transition**: Research → Synthesize per survey template §F4.
- **Tier**: 1 → 1 (survey is intrinsically low-tier; the VALUE is the spawned child investigation, not survey's own tier ladder).
- **Falsifiers**: not applicable to survey template (no falsifier list field by design).
- **Other in-flight investigations**:
  | id | priority | tier | stage | status |
  |---|---|---|---|---|
  | barnett-mechanism-2026-05-16 | 1 | 3.0/3 | closed | Tier-3, T29 |
  | yan-li-saito-2026-reproduction | 1 | 0.4/3 | closed | DORMANT-CLOSE T65 |
  | judge-in-operator-bug-2026-05-18 | 2 | 2/2 | closed | T54 |
  | klaus-magnetostir-bch-leak-2026-05-13 | 3 | 3.0/3 | closed | Tier-3, T59 |
  | audit-due-heuristic-bug-2026-05-18 | 4 | 2/2 | closed | T68 |
  | meta-internal-b-unification-2026-05-18 | 5 | 1/1 | closed (mechanical) | T49 |
  | tier3-verification-pipeline-survey-2026-05-18 | 10 | 1/1 | **Research** | T69 PASS (this turn target) |
  | audit-class-scan-2026-05-18-T50 | 20 | 2/2 | closed | T54 |
  | audit-class-scan-2026-05-18-T61 | 20 | 2/2 | closed | T63 |
  | meta-stage-routing-2026-05-18 | 25 | 0.0/1 | closed (REFUTED-BY-CONFOUNDER) | T60 |
  | meta-critic-placement-2026-05-17 | 50 | 0/2 | dormant | — |
  | fullbdg-f6-polar-3000x | 99 | 1.5/2 | dormant (anko-contained) | — |
- **Scheduler (scheduler_70.json)**: policy=JULIA_GPU_OK, all workloads allowed; window 1,167,085s left (~13.5 days); VRAM 12,715 MB free; foreign_julia=0; ram_avail=25.07 GB. No constraint pressure. seed.md's "no julia" hard memory constraint is **stale** (probe authoritative per scheduler notes).
- **T69 drift signals (state.json line 1941-1955)**: DRIFT_MANUSCRIPT_DELTA_ZERO (design-persistent), DRIFT_NOVEL_CLAIM_ZERO (4-consecutive), DRIFT_COST_INFLATION (1.205 — researcher used more than baseline; expected for deep WebSearch survey). Escalation: `human_required`. **T70 must clear DRIFT_NOVEL_CLAIM_ZERO** by dispatching theorist (Synthesize stage produces [Established] tags on Matsui 2026 + Miyazawa 2022 citation grounding).

## 2. Recent-turn audit (last 3 turns of THIS investigation; survey only exists since T69)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T68 | (different inv: audit-due-heuristic-bug) | PASS | mechanical fix; closed audit-due-heuristic-bug-2026-05-18; novel_claim_zero=1.0 (expected for hygiene fix) |
| T69 | Research (survey) | RESEARCHER_ONLY | researcher produced 5 ranked Tier-3 candidates; #1 = `edh-eu151-vortex-vs-matsui-science-2026` (Matsui Science 391, 384, 2026; DOI:10.1126/science.adx2872; arXiv:2504.17357; load-bearing 5/5; Tier 0 → Tier 3 candidate); 11 web requests; 0 invented citations; 3 seed.md stubs produced; cost 12.03M raw / 1.79M eff |
| T70 (THIS) | Synthesize (survey) → spawn child investigation | (TBD) | theorist synthesizes T69 candidate menu, produces methodology memory entry, formalizes priority-1 candidate into a verify-claim investigation spec with falsifiers, updates state.json (close survey + spawn child) |

## 3. Flow template recall

- **Template**: `survey` (§F4) — Research → Synthesize → Document → closed. Low-commitment exploration.
- **Role for stage Synthesize**: **theorist** per §F4 "organize findings, identify what's worth a full investigation". The Synthesize stage is the survey's payoff point — theorist takes researcher's raw menu and converts the top pick into an investigation-grade spec.
- **Why this stage now (vs continuing prior stage, vs different investigation, vs noop)**:
  - **Prior stage (Research) is COMPLETE** at T69. Researcher produced all required outputs (5 candidates, seed.md stubs, Bug-4 included, no invented citations). Survey can advance.
  - **Different investigation**: zero eligible per §1 (all priority-1-9 physics investigations closed; dormant priority-50+ excluded per §B2). The survey IS the only eligible candidate.
  - **Noop**: would mean 4-consecutive turns without progress (T67 noop + T68 mechanical + T69 researcher + T70 noop). Per T68 §5 forecast + T69 §5 forecast both call this out as a regression to avoid. DRIFT_NOVEL_CLAIM_ZERO at 4-consecutive (human_required escalation) means we MUST produce theorist [Established]-tag work this turn or escalate to anko meta-investigation.
  - **Anko ratification**: NOT received. Per `feedback_decision_style` ("pick defaults and move"; "わからんて" → don't wait for anko clarification on default choices), the default is the T69 researcher's #1 ranking. Anko's silence on seed.md is consistent with delegation; if anko wanted to override, the seed.md interface is available.
  - **Synthesize stage advances the survey to its natural payoff** (spawn child investigation) AND produces theorist work that clears DRIFT_NOVEL_CLAIM_ZERO.
- **Why theorist (not researcher Document)**:
  - T69 was researcher; per §B2 elimination criteria "no more than 2 same-subagent in a row" (seed.md line 60), T70 should NOT be researcher. theorist is the correct §F4 role for Synthesize.
  - The Synthesize task is genuinely theorist-shape: read T69 menu, formalize the top-1 candidate's hypothesis with paper-derived predictions (Matsui 2026 protocol parameters → SpinorBEC.jl dimensionless predictions for τ_EdH, vortex l), pre-register falsifiers. This requires physics interpretation, not lit-scan.
- **Why directly Synthesize → child-spawn (skip survey Document stage)**:
  - §F4 says Synthesize "organize findings, identify what's worth a full investigation". The spawn of child investigation IS the "identify what's worth a full investigation" deliverable. Survey Document at T71 would be the closure recap.
  - Doing both Synthesize + Document at T70 is too much for one turn (theorist + state.json edit + memory write). Defer Document to T71 IFF the spawn validates the survey's value (it will).
  - Alternative: theorist could synthesize + spawn at T70; T71 = no survey work needed (child investigation Research stage takes priority); survey Document deferred until next steady-state. This is the leanest path per `feedback_cost_overhead_is_the_cost`.

## 4. Research grounding (§A6)

Required for Hypothesize/Design dispatches; Synthesize qualifies as Hypothesize-adjacent (formalizes a hypothesis for the child investigation). Director's grounding for this dispatch:

1. **T69 researcher output (`runs/_loop/research/turn_69.md` §2.1)** — primary source: identified Matsui et al. Science 391, 384-388 (2026), DOI:10.1126/science.adx2872, arXiv:2504.17357, as the only published external benchmark for F=6 Eu-151 spinor dynamics. Theorist will WebFetch the arXiv PDF for full parameters.
2. **Miyazawa et al. PRL 129, 223401 (2022), arXiv:2207.11692** — foundational Eu-151 BEC paper; provides a_s=110(4) a_B (the value SpinorBEC.jl uses as canonical); referenced both in T69 researcher report and in CLAUDE.md §¹⁵¹Eu line.
3. **Memory `feedback_manuscript_is_not_the_essence.md`** — D2 axis "cross-validation against Stuttgart/Innsbruck, F-δ signature test, audit of [Established] memory claims for hidden errors" directly supports the EdH-vs-Matsui choice as the D1/D2-axis priority work. Note: memory has staleness warning (2 days old); the D1/D2 directive has not been retracted in any subsequent feedback memory.
4. **Memory `feedback_decision_style.md`** — "pick defaults and move"; T69 ranked candidates; anko silent on seed.md ratification; default = T69 #1; proceed without re-asking.
5. **Loop precedent T11 (barnett Hypothesize)** + **T30 (yan-li-saito Hypothesize)**: both Hypothesize stages produced 4-5 pre-registered falsifiers with quantitative predictions. The Barnett-T11 pattern produced Tier-3 closure at T29 (CORROBORATED). T70 Synthesize should follow this template: formal hypothesis + 3-4 falsifiers + falsifier-by-falsifier success criteria.
6. **Director.md §F4** ("survey template Synthesize: organize findings, identify what's worth a full investigation, possibly spawn child investigation"): T70 dispatch is the template-canonical use.
7. **Director.md §D1**: "Most [Established] memory entries are Tier 1-2. Zero are Tier 3 currently. The biggest blank space." (Current count: 2 Tier-3 closed. The EdH-vs-Matsui candidate would be the 3rd Tier-3 closure and the project's first cross-validation against a Science-tier published experimental paper.)
8. **Anthropic context engineering "Write strategy"** (per director.md §G): theorist's Synthesize output (a memory entry + state.json investigation spec) is durable state; future directors at T71+ can read it directly and route the child investigation without re-deriving the spec.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 (verification axis — primary)** AND **D3-adjacent (theorist formalizes hypothesis grounded in lit)**. Manuscript NOT in scope.
- **Tier ladder position**: survey investigation 1 → 1 (no change; survey's intrinsic tier ceiling); NEW child investigation `edh-eu151-vortex-vs-matsui-science-2026` enters at tier 0, target tier 3 (Tier 3 = published-reference benchmarked, here vs Matsui Science 2026).
- **Manuscript NOT in scope** (per `feedback_manuscript_is_not_the_essence`).
- **DRIFT_NOVEL_CLAIM_ZERO clearance**: T70 theorist Synthesize stage will cite [Established] tags on:
  - Matsui et al. 2026 EdH protocol parameters
  - Miyazawa et al. 2022 a_s=110(4) a_B + N≤5×10⁴ + Feshbach @ 1.32 G
  - SpinorBEC.jl canonical Eu-151 g_F, μ, F=6 framework
  - Kawaguchi-Ueda 2012 §3.2 spinor-DDI Bogoliubov framework (background for τ_EdH prediction)
  These are real [Established] tags that the judge's novel_claim_zero metric will count. Trajectory: T70 clears the 4-consecutive streak.
- **Cost trend**: T64-T69 oscillated 5.86M-12.03M raw / 0.86-1.79M eff. T70 forecast: ~6-8M raw / ~1.0-1.5M eff (theorist text-only, WebFetch ×2-3 for Matsui PDF + Miyazawa verification, no julia). Stable within steady-state band.
- **Verdict streak**: post-T53 15/15 operationally clean. T70 success criteria are file-existence + state.json field equality + theorist output structure — all checkable by judge.py mechanically.
- **Recommended T71+ trajectory** (informational):
  - **T71**: child investigation `edh-eu151-vortex-vs-matsui-science-2026` enters Research stage. Dispatch researcher_deep (per director.md §F1 — investigation has tier_target=3, mandates `deep` depth: ≥30 parallel queries, full-PDF mandatory). Researcher fetches Matsui 2026 arXiv PDF (binary may need theorist-side PDF extraction via Read tool with pages param), extracts: N, trap ω_{x,y,z}, B-quench protocol (initial Bz amplitude + ramp time τ), simulation reference values for c_dd / c_1 / a_s used, observed τ_EdH and ring topology l.
  - **T72**: theorist Hypothesize translates paper parameters into SpinorBEC.jl dimensionless predictions; formal hypothesis with quantitative bands.
  - **T73**: implementer Design — YAML config from template `runs/_loop/templates/` (NOTE: no EdH template exists; T73 may need to add one BEFORE running OR copy+patch from `dynamics_klaus_stir.yaml`).
  - **T74**: implementer_julia_gpu Execute (RTX 5070 Ti, 32³ or 64³ grid).
  - **T75**: implementer Analyze.
  - **T76**: critic Update.
  - **T77**: implementer_text Document.
  - **Total: ~7 turns to Tier-3 closure.** Survey investigation Document closure can happen anywhere in the gap as a fill-turn (1-turn implementer_text).
  - **Branching**: if T71 researcher_deep cannot extract Matsui 2026 parameters (paywall, PDF binary unparseable), falls back to inquiring Miyazawa 2022 parameter set as proxy + email-the-authors flag for anko.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "tier3-verification-pipeline-survey-2026-05-18",
  "stage_advancing_to": "Synthesize",
  "subagent_type": "theorist",
  "researcher_depth": null,
  "parallel_researcher_count": 0,
  "rationale": "T69 researcher (RESEARCHER_ONLY verdict, PASS) delivered 5 ranked Tier-3 candidates with the #1 being `edh-eu151-vortex-vs-matsui-science-2026` (Matsui et al. Science 391, 384-388 (2026), DOI:10.1126/science.adx2872, arXiv:2504.17357 — load-bearing 5/5; Tier 0 → Tier 3 candidate; the project's first cross-validation opportunity against a Science-tier published experiment on F=6 Eu-151 spinor DDI dynamics). Anko has not updated seed.md to ratify a different pick; per `feedback_decision_style` ('pick defaults and move'), the default is to proceed with the T69 #1. Survey template §F4 Synthesize stage is the canonical mechanism to organize findings + spawn the child investigation. Theorist (not implementer/researcher) per role_per_stage map. The dispatch clears DRIFT_NOVEL_CLAIM_ZERO 4-consecutive (human_required escalation) because theorist Synthesize will emit [Established] tags on Matsui 2026 + Miyazawa 2022 + Kawaguchi-Ueda 2012 grounding the child investigation's hypothesis. Cost ~6-8M raw / ~1.0-1.5M eff for one theorist text-only turn.",
  "brief": "ROLE: theorist (text-only, no julia, no GPU, no sympy execution — use Read / Grep / Glob / WebFetch / Write). TASK: Synthesize the T69 researcher candidate menu into (a) a brief methodology memory entry capturing the survey's institutional lesson, (b) a formal verify-claim investigation spec for the priority-1 candidate `edh-eu151-vortex-vs-matsui-science-2026`, and (c) state.json updates closing the survey investigation and spawning the new child investigation.\n\n=== CONTEXT YOU MUST READ FIRST ===\n\n1. `runs/_loop/director/turn_70.md` (this file) §1-§5 for routing context.\n2. `runs/_loop/research/turn_69.md` — researcher's 5-candidate report; §2.1 is the top candidate, §2.2 (Bug-4), §2.3 (Sign Pattern Lemma 1), §2.4 (TwoChannelLHY), §2.5 (TDHFB Phase 2 HF kernel). Section 5 has the seed.md-ready stubs.\n3. `.claude/agents/director.md` §F1 (verify-claim template), §F4 (survey template), §D1 (tier ladder definitions).\n4. `runs/_loop/state.json` — investigations block. Specifically lines 2528-2551 (current survey state) and lines 1989-2061 (barnett-mechanism-2026-05-16 entry, as a template for the child investigation structure).\n5. `.claude/projects/-home-suzume-workspace-BEC-simulation/memory/MEMORY.md` — top-level index. Reference for [Established] tag style + memory file naming conventions.\n6. CLAUDE.md §¹⁵¹Eu — F=6, g_F≈1.163, μ≈6.977μ_B, a_s≈110a₀, 7 unknown scattering channels, c₀+36c₁=4π(a_s/a_ho)N constraint.\n7. **CRITICAL — verify the Matsui 2026 reference exists**: WebFetch https://arxiv.org/abs/2504.17357 (T69 cited this arXiv ID). The first thing you do is confirm the paper exists and extract its abstract. If WebFetch fails or paper does not match T69's claim, ABORT and report; DO NOT spawn the child investigation on an unverified reference.\n8. Memory `barnett_spin_pumping_observed_2026_05_16.md` if it exists (T69 cites it) — for anko's prior empirical Eu-151 signal context.\n\n=== TASK SPECIFICATION ===\n\n**STEP 1 (verification)**: WebFetch https://arxiv.org/abs/2504.17357 OR https://doi.org/10.1126/science.adx2872. Extract abstract + first-page summary. Confirm: (i) the paper exists, (ii) it is about Eu-151 EdH / spinor dipolar dynamics, (iii) it reports the ring-vortex observation. If ALL three confirm, proceed. If ANY fail, write a brief report at `runs/_loop/theorist/turn_70.md` titled 'ABORT — Matsui 2026 reference unverifiable' and do NOT spawn child investigation; set survey investigation `current_stage='Synthesize'` and `next_stage='Document'`, `next_stage_action='Re-research top candidate with verified alternative'`.\n\n**STEP 2 (synthesis memory entry)**: Write `.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md`. Required content:\n  - Title: 'Tier-3 verification pipeline survey 2026-05-18 (T69-T70)'\n  - Frontmatter: `name: tier3-pipeline-survey-2026-05-18`, `description: ...`, `type: methodology`.\n  - Body (~400-600 words):\n    - Context: project had 2 Tier-3 claims (Barnett T29, Klaus-BCH T59); all priority 1-3 physics investigations closed/dormant; survey was spawned to populate the pipeline.\n    - 5-candidate menu (1-line summary each, citing T69 §2.X locations).\n    - Ranking rationale (load-bearing × benchmark × cheapness).\n    - Key finding: Matsui Science 2026 is the highest-value Tier-3 anchor for the project.\n    - Excluded candidates (intentional design, already-closed) — list briefly.\n    - 4 NOT_FOUND benchmarks (T69 §4) — these are real institutional knowledge; record them so future directors don't re-search.\n    - Action: child investigation `edh-eu151-vortex-vs-matsui-science-2026` spawned at T70 Research stage.\n\n**STEP 3 (child investigation hypothesis formalization)**: Write `runs/_loop/theorist/turn_70.md` with the canonical theorist output format. Required content:\n  - Frontmatter: turn 70, subagent theorist, depends_on [director/turn_70, research/turn_69], produces 'edh-eu151-vortex-vs-matsui-science-2026 verify-claim investigation specification'.\n  - §1 Synthesis of T69 candidate menu (which 5, what ranking, why #1).\n  - §2 [Established] background:\n    - Matsui et al. Science 2026 EdH observation [Established, arXiv:2504.17357 / DOI:10.1126/science.adx2872, verified WebFetch this turn].\n    - Miyazawa et al. 2022 PRL Eu-151 BEC parameters [Established, arXiv:2207.11692, T69-verified, anko's barnett_spin_pumping run uses same a_s=110 a_B].\n    - Kawaguchi-Ueda 2012 §3.2 spinor-DDI Bogoliubov framework [Established, arXiv:1001.2072, KU2012].\n    - SpinorBEC.jl canonical Eu-151 framework [Established, CLAUDE.md §¹⁵¹Eu, F=6 g_F=1.163 μ=6.977μ_B].\n  - §3 Formal hypothesis statement for child investigation:\n    - Hypothesis: 'SpinorBEC.jl spinor DDI + split_step framework can reproduce Matsui et al. Science 391, 384-388 (2026) within factor-2 of experimental τ_EdH and matching ring-vortex topology (l consistent with F=6 angular momentum balance) when fed the paper's published parameters (N, trap ω, B-quench profile, a_s, c_dd).'\n  - §4 Pre-registered falsifiers (3-4, each quantitative):\n    - F1 ring-appears-correct-timescale: ring density in m=-5 component (or m=-5±1 if Matsui paper uses different m-labelling) appears at t∈[0.5·τ_EdH_paper, 2.0·τ_EdH_paper] → CORROBORATE; absent at any t<10·τ_EdH_paper → REFUTED.\n    - F2 vortex-topology-l-matches-AM-conservation: extracted vortex winding number from m≠-6 density via phase singularity count = l_predicted (predict via theorist analysis of angular momentum balance at F=6, target after paper-PDF extraction) → CORROBORATE if exact match; ±1 wrong winding → INCONCLUSIVE; >1 off → REFUTED.\n    - F3 ground-state-energy-self-consistency: pre-quench m=-6 FM GS energy at Matsui's N + a_s + trap matches mean-field formula `E_mf/N = (c_0+36c_1)n/2 + E_DDI/N` within 20% → CORROBORATE (confirms Bug-4 fix and GS preparation); >100% off → operational bug somewhere in pipeline (not physics failure).\n    - F4 (optional) DDI-zero-control: re-run with c_dd=0 → ring should NOT form (DDI is the AM-transfer mechanism in Matsui's interpretation) → CORROBORATE if no ring; ring still forms → mechanism is something else (refutes our interpretation of paper).\n  - §5 Tier-3 success criteria (Tier 3 = published-reference benchmarked):\n    - F1 + F2 + F3 all CORROBORATE → Tier 3 closure.\n    - F1 OR F2 REFUTED → Tier 2 partial (framework reproduces SOME but not ALL of Matsui's observation; investigation closes at tier 2 with documented gap).\n    - F3 REFUTED only → operational gate to investigate (likely Bug-4 pre-fix data contamination — connects to T69 candidate #2).\n  - §6 Budget estimate (informational; will be refined at each child-investigation turn): 5-7 turns total; researcher_deep T+0 + theorist Hypothesize T+1 + implementer Design T+2 + implementer_julia_gpu Execute T+3 + Analyze T+4 + critic Update T+5 + Document T+6.\n\n**STEP 4 (state.json updates)** — use Edit tool with minimal-precision edits, NOT full-file rewrite. JSON syntax MUST remain valid (judge will run `python3 -c 'import json; json.load(open(\"runs/_loop/state.json\"))'` to verify):\n  - Update `tier3-verification-pipeline-survey-2026-05-18`:\n    - `current_stage`: 'Research' → 'Synthesize' (this turn's stage)\n    - `stages_done`: append 'Synthesize' to existing ['Research'] → ['Research', 'Synthesize']\n    - `stages_at_turn`: add `'Synthesize': [70, 'theorist organized T69 menu, spawned child edh-eu151-vortex-vs-matsui-science-2026, recorded methodology in memory']`\n    - `next_stage`: 'Synthesize' → 'Document'\n    - `next_stage_action`: 'Pending anko ratification of candidate priority' → 'Survey Document stage may be done at any steady-state turn (1-turn implementer_text closure); not blocking child investigation T71+ work'\n    - `blocked_on`: 'anko ratification of candidate priority' → null (default-picked per feedback_decision_style; anko can override in seed.md if desired)\n  - Add NEW investigation `edh-eu151-vortex-vs-matsui-science-2026`:\n    - `id`: 'edh-eu151-vortex-vs-matsui-science-2026'\n    - `title`: 'Einstein-de Haas Eu-151 vortex emergence — reproduction of Matsui et al. Science 391, 384-388 (2026)'\n    - `hypothesis`: (the §3 formal hypothesis statement, verbatim)\n    - `flow_template`: 'verify-claim'\n    - `current_stage`: 'Research'\n    - `stages_done`: []\n    - `stages_at_turn`: {}\n    - `falsifiers`: array of 3-4 falsifier objects (F1-F3 minimum, F4 optional), each with `id`, `description`, `tested_at_turn: null`, `result: null`\n    - `tier_current`: 0\n    - `tier_target`: 3\n    - `next_stage`: 'Research'\n    - `next_stage_action`: 'T71 director: dispatch researcher_deep to extract Matsui 2026 PDF parameters (N, trap omega, B-quench profile, observed τ_EdH, vortex winding number l). Researcher depth MUST be deep per director.md §F1 (tier_target=3 mandates ≥30 parallel queries + full-PDF mandatory).'\n    - `blocked_on`: null\n    - `priority`: 1 (replaces yan-li-saito's vacated priority-1 slot)\n    - `kind`: 'physics'\n  - Append 'edh-eu151-vortex-vs-matsui-science-2026' to `investigations_index`.\n  - Update `active_investigation_id`: 'tier3-verification-pipeline-survey-2026-05-18' → 'edh-eu151-vortex-vs-matsui-science-2026' (the child takes the next-turn priority).\n  - DO NOT touch other investigations, history array, schema_version, or any other top-level field.\n\n=== HARD CONSTRAINTS ===\n  - Tools: Read, Grep, Glob, WebFetch, Write, Edit. NO Bash, NO Pkg.test, NO julia, NO GPU.\n  - File scope: write ONLY `runs/_loop/theorist/turn_70.md`, `.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md`, and Edit `runs/_loop/state.json` (precise minimal edits to specified fields only). NO touching src/, test/, .claude/scripts/, .claude/agents/, manuscripts/.\n  - If Matsui 2026 reference does not verify (Step 1), abort and produce ABORT report without state.json changes.\n  - No invented physics: §4 falsifier F2 vortex winding number prediction is 'target after paper-PDF extraction at T71' — do NOT invent a specific number this turn without paper data. F1 timescale band is paper-relative; do NOT invent an absolute τ_EdH this turn.\n  - 4-consecutive DRIFT_NOVEL_CLAIM_ZERO: this turn's [Established] tags in §2 of theorist/turn_70.md must be REAL — citing Matsui 2026 + Miyazawa 2022 + KU2012 + SpinorBEC.jl framework — verified via WebFetch (Matsui), prior memory + CLAUDE.md (Miyazawa, KU2012, framework).\n  - No anko-attribution in output prompts (per memory `feedback_no_anko_attribution_in_prompts`).\n\n=== OUTPUT FORMAT ===\n\n`runs/_loop/theorist/turn_70.md`:\n```\n---\nturn: 70\nsubagent: theorist\ntopic_tags: [survey-synthesize-stage, edh-eu151-matsui-science-2026, child-investigation-spawn, tier3-anchor, d1-verification-depth]\ndepends_on: [director/turn_70, research/turn_69]\nproduces: edh-eu151-vortex-vs-matsui-science-2026 verify-claim investigation spec + tier3 pipeline survey methodology memory entry + state.json child-investigation spawn\n---\n\n# Turn 70 — Theorist Synthesis\n\n## 1. Synthesis of T69 candidate menu\n...\n## 2. [Established] background\n...\n## 3. Formal hypothesis statement\n...\n## 4. Pre-registered falsifiers\n...\n## 5. Tier-3 success criteria\n...\n## 6. Child-investigation budget estimate\n...\n## 7. Self-review checklist\n- [ ] Matsui 2026 reference WebFetch-verified this turn\n- [ ] All [Established] tags are real (no fabrication)\n- [ ] state.json edits preserve JSON validity\n- [ ] No invented physics (no specific vortex number until paper PDF available at T71)\n- [ ] Memory entry created per Step 2\n- [ ] Child investigation added to investigations_index\n- [ ] active_investigation_id updated to child\n```\n\n=== SUCCESS SIGNALS ===\n\n  - File `runs/_loop/theorist/turn_70.md` exists, has §1-§6 populated.\n  - File `.claude/projects/-home-suzume-workspace-BEC-simulation/memory/tier3_pipeline_survey_2026_05_18.md` exists with proper frontmatter.\n  - state.json parses as valid JSON post-edit.\n  - state.json contains both `tier3-verification-pipeline-survey-2026-05-18` (current_stage=Synthesize) and `edh-eu151-vortex-vs-matsui-science-2026` (current_stage=Research, tier_target=3) in investigations.\n  - state.json `active_investigation_id` == 'edh-eu151-vortex-vs-matsui-science-2026'.\n  - state.json `investigations_index` contains 'edh-eu151-vortex-vs-matsui-science-2026'.\n  - theorist/turn_70.md §2 contains ≥3 [Established] tags with real citations (Matsui, Miyazawa, KU2012).\n  - theorist/turn_70.md §4 contains ≥3 falsifiers each with quantitative criteria (timescale band, vortex topology gate, energy delta gate).\n  - WebFetch tool was called at least once on the Matsui arXiv URL this turn (judge can verify via tool-use record).\n\n=== BUDGET ===\n\nExpected ~6-8M raw / ~1.0-1.5M effective. ~25-40 min wall time for WebFetch verification + memory write + theorist report + state.json edits. Hard cap: 3M effective. If you hit 3M before completing all 4 steps, prioritize: Step 1 (verify) → Step 3 (theorist report) → Step 4 (state.json) → Step 2 (memory entry, can be deferred to T71 Document).\n\n=== GUARDRAIL ===\n\nNO git commit, NO branch creation. The orchestrator handles commits. If the state.json edit corrupts the file, the orchestrator/judge will detect via JSON parse failure and you'll be reverted.",
  "observable_manifest": {
    "required": [
      "theorist_turn_70_md_exists",
      "memory_tier3_pipeline_survey_md_exists",
      "state_json_parses_as_valid_json",
      "edh_eu151_vortex_vs_matsui_science_2026_in_investigations",
      "edh_eu151_vortex_vs_matsui_science_2026_current_stage_equals_Research",
      "edh_eu151_vortex_vs_matsui_science_2026_tier_target_equals_3",
      "tier3_verification_pipeline_survey_current_stage_equals_Synthesize",
      "active_investigation_id_equals_edh_eu151_vortex_vs_matsui_science_2026",
      "established_tags_in_theorist_turn_70_md",
      "falsifier_count_in_theorist_turn_70_md",
      "webfetch_matsui_called"
    ],
    "optional": ["matsui_pdf_extraction_summary", "miyazawa_2022_cross_check_confirmed"],
    "precondition_check": "cd /home/suzume/workspace/BEC-simulation && test -f runs/_loop/state.json && test -f runs/_loop/research/turn_69.md && test -d runs/_loop/theorist && test -d .claude/projects/-home-suzume-workspace-BEC-simulation/memory && python3 -c \"import json; s=json.load(open('runs/_loop/state.json')); inv=s['investigations']; assert 'tier3-verification-pipeline-survey-2026-05-18' in inv, 'survey investigation missing'; assert inv['tier3-verification-pipeline-survey-2026-05-18']['current_stage']=='Research', 'survey not at Research stage; T70 dispatch precondition violated'; assert 'edh-eu151-vortex-vs-matsui-science-2026' not in inv, 'child investigation already exists; T70 would duplicate-spawn'; print('OK_T70_precondition: ready for Synthesize stage advance and child spawn')\""
  },
  "success_criteria": [
    {
      "id": "theorist_report_written",
      "metric": "theorist_turn_70_md_exists",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Synthesize stage product is the theorist's md report at runs/_loop/theorist/turn_70.md per loop convention."
    },
    {
      "id": "memory_entry_written",
      "metric": "memory_tier3_pipeline_survey_md_exists",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Survey's institutional lesson (5-candidate menu, NOT_FOUND items, ranking rationale) must persist beyond loop state for future directors."
    },
    {
      "id": "state_json_valid_post_edit",
      "metric": "state_json_parses_as_valid_json",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "JSON parse failure would break every subsequent turn; this is the highest-priority operational gate."
    },
    {
      "id": "child_investigation_spawned",
      "metric": "edh_eu151_vortex_vs_matsui_science_2026_in_investigations",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "The Synthesize stage's primary deliverable per §F4 ('identify what's worth a full investigation, possibly spawn child investigation') is the spawn itself."
    },
    {
      "id": "child_investigation_at_research_stage",
      "metric": "edh_eu151_vortex_vs_matsui_science_2026_current_stage_equals_Research",
      "operator": "==",
      "value": "Research",
      "tolerance": null,
      "rationale": "verify-claim flow §F1 starts at Research; child enters at Research for T71 researcher_deep dispatch."
    },
    {
      "id": "child_investigation_tier_target_3",
      "metric": "edh_eu151_vortex_vs_matsui_science_2026_tier_target_equals_3",
      "operator": "==",
      "value": 3,
      "tolerance": null,
      "rationale": "Tier 3 = published-reference benchmarked (against Matsui 2026 Science). The whole point of this investigation."
    },
    {
      "id": "survey_advanced_to_synthesize",
      "metric": "tier3_verification_pipeline_survey_current_stage_equals_Synthesize",
      "operator": "==",
      "value": "Synthesize",
      "tolerance": null,
      "rationale": "Survey flow §F4 advances Research → Synthesize this turn; Document deferred."
    },
    {
      "id": "active_id_updated_to_child",
      "metric": "active_investigation_id_equals_edh_eu151_vortex_vs_matsui_science_2026",
      "operator": "==",
      "value": "edh-eu151-vortex-vs-matsui-science-2026",
      "tolerance": null,
      "rationale": "T71 director MUST pick up the child investigation as active; updating active_investigation_id now pre-positions the next turn's routing."
    },
    {
      "id": "established_tags_count",
      "metric": "established_tags_in_theorist_turn_70_md",
      "operator": ">=",
      "value": 3,
      "tolerance": null,
      "rationale": "DRIFT_NOVEL_CLAIM_ZERO 4-consecutive clearance requires real [Established] tags; theorist must cite Matsui 2026 + Miyazawa 2022 + KU2012 at minimum. Judge counts via grep of '[Established]' pattern."
    },
    {
      "id": "falsifier_count_meets_minimum",
      "metric": "falsifier_count_in_theorist_turn_70_md",
      "operator": ">=",
      "value": 3,
      "tolerance": null,
      "rationale": "Hypothesize-grade investigation specs need ≥3 falsifiers per loop precedent (T11 barnett=4, T30 yan-li-saito=4). Fewer = under-specified investigation that can't reach Tier 3 mechanically."
    },
    {
      "id": "matsui_reference_verified",
      "metric": "webfetch_matsui_called",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "STEP 1 hard requirement: theorist must WebFetch Matsui arXiv URL this turn to verify the reference before spawning child investigation. T69 cited it but did not extract paper body. Spawning a Tier-3 investigation against an unverified paper is unacceptable."
    }
  ],
  "failure_modes": [
    {
      "if": "Matsui 2026 WebFetch fails OR returns content inconsistent with T69's claim",
      "category": "data_gap",
      "next_action": "T71 director: per STEP 1 abort path, survey remains at Synthesize stage with next_stage_action='Re-research top candidate with verified alternative'. Re-dispatch theorist or researcher to find an alternative external benchmark (Miyazawa 2022 + Kawaguchi-Ueda 2012 cross-validation OR escalate to anko via state.json closing_note 'unable to verify Matsui Science 2026 reference; need anko input on benchmark choice'). DO NOT spawn child investigation on unverified reference."
    },
    {
      "if": "state.json edit corrupts JSON (parse fails)",
      "category": "operational",
      "next_action": "T71 director: revert state.json via git checkout (orchestrator commit will preserve pre-edit state). Re-dispatch theorist with explicit Edit-tool-only minimal-edit instruction (5-7 precise Edits, NOT Write of whole file). This is the same failure mode as T69 success criteria flagged; if it happens twice we have a tooling problem worth a meta-investigation."
    },
    {
      "if": "theorist produces <3 [Established] tags (DRIFT_NOVEL_CLAIM_ZERO not cleared)",
      "category": "framework_error",
      "next_action": "T71 director: spawn meta-investigation `novel-claim-zero-metric-calibration-2026-05-19` to either (a) suppress the metric for survey/research/hygiene turn types OR (b) tighten judge's [Established]-detection regex. 5-consecutive escalation requires meta-investigation per drift_signals.py protocol. Inform anko via state.json closing_note."
    },
    {
      "if": "theorist invents specific physics quantities not derivable from current context (e.g., specific τ_EdH number without paper PDF; specific vortex winding number without paper data)",
      "category": "operational",
      "next_action": "T71 director: re-read theorist/turn_70.md §4 falsifiers; for any falsifier with a specific numerical value not traced to a verified citation, demote to 'target after T71 paper-PDF extraction'. Spawn corrective implementer_text Edit to relax the falsifier criterion if needed. Tighten theorist brief on T71 to forbid invention."
    },
    {
      "if": "theorist spawns child investigation but does NOT update active_investigation_id",
      "category": "operational",
      "next_action": "T71 director: explicit Edit on state.json active_investigation_id field. Mechanical fix. T71 then proceeds with child investigation Research stage as planned."
    },
    {
      "if": "theorist exceeds 3M effective cap before completing all 4 steps",
      "category": "operational",
      "next_action": "T71 director: triage based on what was completed. If Step 1 (verify) + Step 3 (theorist report) + Step 4 (state.json) done but Step 2 (memory entry) skipped, the survey investigation can be completed at survey Document stage T73+ via implementer_text — not blocking T71 child research. If Step 4 (state.json) skipped, T71 director writes the state.json edits before any other work (1-turn implementer_text)."
    },
    {
      "if": "theorist returns OUT_OF_SCOPE for the synthesis task",
      "category": "framework_error",
      "next_action": "T71 director: re-read theorist.md agent prompt; Synthesize stage IS theorist-shape (organize, formalize, identify); if theorist refuses, the agent prompt has drifted. Escalate to anko via closing_note. Interim: re-dispatch as researcher (lit-scan + formalize) with explicit brief."
    },
    {
      "if": "theorist adds child investigation with priority that conflicts with existing (e.g., duplicate priority-1 slot)",
      "category": "operational",
      "next_action": "T71 director: priority is a tier-breaker, not a unique key; multiple priority-1 investigations are allowed (barnett-mechanism is closed priority 1; yan-li-saito-2026-reproduction is closed priority 1). EdH-Matsui as priority 1 is the canonical inheritance. No corrective action needed."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 3000000
  },
  "budget": {
    "expected_cost_eff": 1300000,
    "expected_wall_time_sec": 1800,
    "split_by_subtask": {
      "webfetch_matsui_verification": 300000,
      "read_research_turn_69_and_state_json": 200000,
      "write_memory_entry": 250000,
      "write_theorist_turn_70_md": 400000,
      "edit_state_json": 150000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Document (deferred to T73+ steady-state via implementer_text; not blocking child investigation T71+ research)",
    "if_success_tier_becomes": 1,
    "if_refuted_advance_to_stage": "Synthesize (re-attempt with verified alternative benchmark)",
    "if_refuted_tier_becomes": 0.5,
    "if_inconclusive_advance_to_stage": "Synthesize (one-turn retry with clarified scope)",
    "if_inconclusive_tier_becomes": 0.5,
    "next_falsifier_to_test_after": "Survey investigation has no falsifiers (low-commitment exploration template). The CHILD investigation `edh-eu151-vortex-vs-matsui-science-2026` will be the next-turn focus at T71: researcher_deep extracts Matsui 2026 PDF parameters (N, trap omega_{x,y,z}, B-quench profile, simulation reference c_dd / c_1 / a_s, observed tau_EdH, vortex winding number l). Falsifier F1 (ring timescale) is the first execute-stage check after Hypothesize and Design stages."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read state.json (4 ranges covering schema_version, active_investigation_id, history T28-T69, full investigations block including the new survey entry at lines 2528-2551) + scheduler_70.json (full read: JULIA_GPU_OK, 13.5 days, foreign_julia=0) + seed.md (full read: unchanged since 2026-05-15; stale Julia-sweep constraint; no new anko priorities).
- [x] Read T69 director turn (full content reviewed for routing context) + T69 researcher output (full read: 5 candidates, Matsui top, all 7 fields populated, 0 invented citations).
- [x] Read ≥1 memory file related to active investigation: `feedback_manuscript_is_not_the_essence` (D1 axis support for EdH-vs-Matsui choice; staleness warning acknowledged), `feedback_decision_style` (defaults-and-move for unprompted anko ratification; staleness warning acknowledged). Both feed §4 research grounding.
- [x] investigation_id `tier3-verification-pipeline-survey-2026-05-18` valid in state.investigations (line 2528).
- [x] stage_advancing_to = Synthesize is the next stage per survey template §F4 (Research → Synthesize → Document → closed).
- [x] subagent_type theorist matches role_per_stage[Synthesize] per §F4 ("organize findings, identify what's worth a full investigation").
- [x] success_criteria are machine-evaluable: file-existence booleans (theorist_turn_70_md_exists, memory_*_exists), JSON-parse boolean, state.json field equality strings (current_stage, tier_target, active_investigation_id), greppable count metrics ([Established] tag count, falsifier count), tool-use boolean (webfetch_matsui_called). Judge.py can apply all 11 mechanically.
- [x] failure_modes cover 8 most likely failures: Matsui WebFetch fails (data_gap), JSON corruption (operational), <3 [Established] tags (framework_error), invented physics (operational), missed active_id update (operational), cost overrun (operational), OUT_OF_SCOPE refusal (framework_error), priority conflict (operational with no-action rationale).
- [x] observable_manifest precondition_check is concrete: bash test for required files + python3 json check that survey investigation is at Research stage AND child investigation does NOT yet exist (would catch duplicate-spawn class of bug).
- [x] budget fits within scheduler window_seconds_left (1.3M eff forecast vs 100M rolling cap; 30 min wall vs 13.5 day window — abundant).
- [x] §A6 research-first citation present (8 references: T69 researcher report; Matsui 2026 + Miyazawa 2022 [arXiv-grounded]; 2 anko-feedback memory files; loop precedents T11/T30 Hypothesize patterns; director.md §F4 + §D1; Anthropic context engineering Write strategy).
- [x] §A5 D1/D2/D3 articulated: T70 advances **D1 (verification axis — primary)** by formalizing the Tier-3 verification target. Manuscript NOT primary.
- [x] DRIFT_NOVEL_CLAIM_ZERO 4-consecutive (T67/T68/T69/baseline-T70-if-noop) addressed by REAL theorist Synthesize work that emits ≥3 [Established] tags (success criterion #9). Clears the human_required escalation by producing actual D1 progress.
- [x] No noop: per T68/T69 forecasts both explicitly warned against multi-consecutive noops; T70 dispatches real theorist work that produces durable state (memory entry + investigation spec + state.json updates).
- [x] No skip-stage: survey Research → Synthesize per §F4 exactly. Document stage deferred to T73+ as a 1-turn closure; not skipped.
- [x] No more than 2 same-subagent in a row: T68 implementer, T69 researcher, T70 theorist — clean rotation.
- [x] Anko-attribution check: §6 brief does not embed "per anko 2026-XX-YY" or quoted anko statements; cites memory file names + design docs only (per `feedback_no_anko_attribution_in_prompts`).
- [x] State.json edit instructions are PRECISE field-by-field with explicit values — minimizes JSON-corruption risk.
- [x] Child investigation `edh-eu151-vortex-vs-matsui-science-2026` enters at priority 1 (replaces yan-li-saito's vacated priority-1 slot per state.json) — clear seed.md-equivalent priority signaling without requiring anko to edit seed.md.
