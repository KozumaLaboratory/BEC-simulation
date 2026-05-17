---
turn: 50
subagent: director
investigation_id: audit-class-scan-2026-05-18-T50
stage_advancing_from: (new turn — no prior stage; §F6 Observe is entry point)
stage_advancing_to: Observe
topic_tags: [audit-class-scan, patterns-yaml, AUDIT_DUE-gap-49, code-debt-sweep, sibling-grep, fix-the-class, deprecated-name-leak, api-rename-stragglers, doc-staleness, large-file-bloat, dead-export, test-mock-of-real]
paper_section: null
depends_on: [49, 48, 47, "runs/_loop/director/turn_49.md", "runs/_loop/judge/turn_49.json", "runs/_loop/patterns.yaml", "runs/_loop/_local/scheduler_50.json", "runs/_loop/state.json", "runs/_loop/seed.md", "memory:feedback_fix_the_class_not_the_instance", "memory:feedback_mechanical_vs_investigation_threshold", "memory:feedback_decision_style", "memory:feedback_cost_overhead_is_the_cost"]
produces: "researcher Observe stage artifact at runs/_loop/research/turn_50_audit_class_scan.md: scan of all 8 dormant patterns (last_scanned == null) + recall scan of the 1 already-scanned class (deprecated-name-leak) for drift; concrete file:line findings tables per class; triage classification (mechanical-fix-now / spawn-fix-bug-child / spawn-investigation / no-action-rationalized); related_classes proposal queue (L3 analogical derivation candidates) with grep anchors for critic audit; updates to patterns.yaml audit_history rows + last_scanned timestamps; no src/ changes this turn (Triage stage at T51 if mechanical-fix-now batch found)."
---

# Turn 50 — Director Report

## 1. Investigation state snapshot

- **Active investigation (new this turn)**: `audit-class-scan-2026-05-18-T50` — flow_template `audit-class-scan` (§F6), kind=meta, priority=20 (services AUDIT_DUE gap=49 accumulated since T0; one prior reactive audit at T48 added the `paper-unit-system-wrong-param-in-spot-check` class but did not sweep the other 8 catalog entries).
- **Stage transition**: **(none) → Observe** per §F6 entry stage. Observe = run each pattern's grep/detect against current `src/`; emit findings table; classify per 3-second mechanical-vs-investigation test.
- **Tier ladder**: this is a meta-investigation; tier_current 0 → tier_target 1 (Observe + Findings + Triage = 1 audit cycle complete). Not a physics Tier-3 advance — this is loop-architecture self-improvement (D3 secondary axis per `feedback_fix_the_class_not_the_instance`).
- **Falsifiers** (pattern-level): each pattern is its own micro-falsifier — "grep returns 0 hits OR all hits are explicitly excluded" = pattern dormant-clean for this audit cycle.
- **Why yan-li-saito + klaus-bch-leak NOT this turn**:
  - **yan-li-saito-2026-reproduction**: at Document terminal, `next_stage = null`, partial-REFUTE landed at tier 0.4 per T49 PASS (judge confirmed all 11 success criteria). Per T49 §6 `failure_modes` success-path success-branch + `investigation_update.if_success_advance_to_stage`, the explicit T50 director option-space was {(a) R4 child-investigation [requires anko prioritization, not surfaced], (b) klaus-bch-leak [valid but cascade-context cold], (c) audit-class-scan [default recommendation]}. T50 director picks (c) per the prior turn's documented routing.
  - **klaus-magnetostir-bch-leak-2026-05-13**: priority 3, state.json `current_stage: "documented"`, all 6 stages_done, blocked on "julia P3 validation". Scheduler now permits `implementer_julia_cpu_light`, but inspecting the existing data: `runs/eu151_klaus_phi_phys/phi_*/result.jld2` is `kind: rotating_basis` (Option γ, NOT lab-frame; verified `runs/eu151_klaus_phi_phys/config.yaml:19`). Theorist T10 P3 prediction ("halving p halves lab-frame scrambling per-step error") REQUIRES a fresh lab-frame run to compare against — not a quick analysis of existing rotating-basis jld2. That means a klaus T50 advance is at least: theorist Hypothesize (re-design P3 from existing-data vs fresh-run) → Design (lab-frame config + matched-Option-γ reference) → Execute. Significant context + ~5-10M budget, NOT a single-turn move. Cleaner to first close AUDIT_DUE gap and possibly surface code-level findings in `src/rotating_basis/` that feed into the klaus re-design.
  - **barnett-mechanism-2026-05-16**: CLOSED at Tier 3.0 (T29).
  - **fullbdg-f6-polar-3000x**: priority 99, dormant (anko-contained).
  - **meta-critic-placement-2026-05-17** (priority 50, Observe): defer; sub-investigation work, not gated by current state.
  - **meta-stage-routing-2026-05-18** (priority 25, Observe, auto-spawned T44): the 3+ fail-streak that triggered this has since landed PASS at T49; the genuine meta-target framing has shifted (per T48 director §6 "judge.py contract-flattening"); defer to a future dedicated meta turn with cleaner framing.
- **Drift signals from T49** (judge T49 PASS): no drift signals serialized in the latest history entry (PASS path). Predecessor T48 had advisories `DRIFT_MANUSCRIPT_DELTA_ZERO`, `AUDIT_DUE gap=48`. **`AUDIT_DUE` is the one I am explicitly servicing this turn.**

## 2. Recent-turn audit (last 3 turns CONTEXT — no prior turns of THIS investigation)

This is a fresh investigation; the recent-turn audit context is the cascade leading to T50, which determines that AUDIT_DUE is appropriate now:

| Turn | Stage | Verdict | Relevance to T50 |
|---|---|---|---|
| T47 critic Update | Update | CRITIC PASS | §D 152× D₀ flag → T48 audit → resolved as T47-critic input error; added `paper-unit-system-wrong-param-in-spot-check` pattern (1st time a Triage spawned a class entry). |
| T48 researcher Research | Research | RESEARCHER_ONLY | Normalization audit; §6 proposed pattern; T48 was Level-1 reactive audit (instance → class), not a sweep. |
| T49 implementer_text Document | Document | PASS (all 11 criteria) | Closed yan-li-saito at tier 0.4; added pattern + audit_history row #2 (T48 reactive). T49 success-path failure_modes explicitly listed `(c) audit-class-scan` as default T50 recommendation. |

**Key observation**: of 9 catalog entries in `patterns.yaml`, only 2 have `last_scanned` set (deprecated-name-leak: 2026-05-18T01:50; paper-unit-system-wrong-param-in-spot-check: 2026-05-18T05:00 from reactive add). **6 entries are at `last_scanned: null`**: api-rename-stragglers, doc-staleness, hardcoded-magic-number, dead-export, large-file-bloat, test-mock-of-real, cargo-cult-comment. **None of these have been swept across `src/` yet.** Per `feedback_fix_the_class_not_the_instance`, this is exactly the operating mode anko called broken on 2026-05-18 — recognizing class-level discoveries but not running the grep-batch. T50 corrects that for the entire catalog in one Observe pass.

## 3. Flow template recall

- **Template**: `audit-class-scan` (§F6 — added per anko 2026-05-18 "テストによる発見という前提なくても?").
- **Stages**: **Observe → Findings → Triage → Document → closed**.
- **Role for Observe stage**: **researcher** per §F6 ("run each pattern's grep/detect against current src/. Record `last_scanned` timestamp and `last_count` per entry. Emit a `findings` block listing instances").
- **Why Observe (and not jumping to Triage)**: Triage requires findings to triage. Observe is the entry stage and the gating data-collection. Findings classification (3-second test per class) happens at the end of this same researcher turn OR as a follow-up; Triage stage (T51 if mechanical-fix-now batch found) is a separate dispatch with `implementer` or `theorist+critic` depending on class types found.
- **Why this stage NOW vs other moves**:

  **Why not klaus-bch-leak Hypothesize**: cleaner to first surface any code-level concerns in `src/rotating_basis/` via the audit (especially via `large-file-bloat`, `dead-export`, `cargo-cult-comment` patterns) before re-Hypothesizing klaus P3 — the audit may inform what level of rigor klaus Design needs.

  **Why not yan-li-saito R4 child-investigation (build-theory)**: anko has not surfaced R4 priority signal. R4 (analytical DDI energy sign derivation) is a low-probability revival path; spawning a build-theory investigation without anko's explicit prioritization is over-eager.

  **Why not noop**: AUDIT_DUE gap=49 is a real signal that has been advisory-only for 8 consecutive turns. Per `feedback_cost_overhead_is_the_cost`, deliberating about audit-deferral is more expensive than running the audit (researcher ~1-1.5M, ~15-25 min).

  **Why not implementer-direct sed-class fix on a single pattern**: per `feedback_mechanical_vs_investigation_threshold`, mechanical fixes get direct execution. But we don't YET know which patterns produce mechanical-fix-class findings vs investigation-class findings — Observe IS the gating step that produces this triage data. T51 is then the mechanical-fix turn (if applicable) per the §F6 Triage stage.

  **Why researcher (not theorist or implementer)**: §F6 explicitly assigns researcher to Observe. Theorist's role is hypothesizing; implementer's role is code change. researcher does scan + classify + report — exactly Observe.

## 4. Research grounding (§A6)

External / prior references applicable to this audit-class-scan Observe dispatch (≥1 per §A6; multiple provided for rigor):

1. **`runs/_loop/patterns.yaml`** (the catalog itself): 9 active patterns, 6 with `last_scanned: null`, 2 with stale or one-off `last_scanned`. The schema defines runnable grep_patterns / detect blocks; this is the empirical anchor (per `patterns.yaml` line 5-13 comment: "Each entry's grep / detector is the EXTERNAL ANCHOR — the empirical verification that prevents fabricated findings").

2. **Memory `feedback_fix_the_class_not_the_instance.md`** (anko 2026-05-18): "なにか新しくわかったときに既存で他にあるか探すの普通じゃない？" — the audit is exactly this. The triage rule "3-second recognition time" applies per-finding inside Findings stage.

3. **Memory `feedback_mechanical_vs_investigation_threshold.md`** (anko 2026-05-18): the 3-second triage rule for each finding — mechanical→direct execute (T51); schema-design→meta-improvement; algorithm→verify-claim; new theory→build-theory.

4. **Memory `feedback_cost_overhead_is_the_cost.md`** (anko 2026-05-15): deliberation about whether to audit is more expensive than the audit itself. Per anko's hard cap policy (100M rolling), researcher ~1.5M is sub-2% of the rolling cap.

5. **director.md §F6 template specification**: explicit role_per_stage map (Observe = researcher), explicit deliverable shape (findings block + last_scanned timestamps + related_classes proposal queue + audit_history append).

6. **`runs/_loop/research/auto_research_architecture_2026_05_16.md`** (the loop's design doc): patterns.yaml as the L2/L3 anti-pattern catalog; audit-class-scan as the periodic sweep.

7. **`runs/_loop/judge/turn_49.json` `investigation_update.if_success_advance_to_stage` field** (line 129): explicitly lists "(c) run audit-class-scan §F6 to clear AUDIT_DUE gap=49" as one of the three T50 options.

8. **`runs/_loop/director/turn_49.md` §6 failure_modes "scientific_success" branch**: explicitly says "Default recommendation: (c) audit-class-scan to clear AUDIT_DUE accumulated since T0, then (b) klaus-bch-leak at T51".

9. **`runs/_loop/director/turn_48.md` §3** ("Why not audit-class-scan AUDIT_DUE gap=47"): T48 director explicitly deferred audit-class-scan to a future turn citing T48's binary cheap-bottleneck. That binary has resolved at T49 PASS, and the deferral is now overdue.

10. **Anthropic context-engineering "Compress" pattern**: the audit produces a compact findings block that compresses 49 turns of accumulated code-level debt into one decision-table — exactly the Compress strategy.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 SECONDARY** (verification depth at the codebase level — `src/` is the production code that supports every physics investigation; finding deprecated-name leaks or stale doc claims is bug-finding in production) + **D3 SECONDARY** (research-grounded loop architecture improvement — the audit-class-scan flow itself is anko's 2026-05-18 design grounded in the "fix the class not the instance" principle). **Not D2** (not optimizing existing implementation).
- **Tier ladder position**: meta-investigation tier 0 → 1 (one audit cycle complete = Observe + Findings + Triage classification report).
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "audit-class-scan-2026-05-18-T50",
  "stage_advancing_to": "Observe",
  "subagent_type": "researcher",
  "rationale": "AUDIT_DUE gap=49 with 6 patterns at last_scanned=null. T49 PASS resolved yan-li-saito Document; T49 §6 failure_modes success-path explicitly listed audit-class-scan as default T50 recommendation. Per §F6, Observe is the entry stage with researcher role. Scope: run grep_patterns / detect blocks for all 9 patterns in patterns.yaml against current src/, emit findings table per class, classify per 3-second triage (mechanical-fix-now / spawn-fix-bug-child / spawn-investigation / no-action-rationalized), propose related_classes for L3 analogical derivation with critic-auditable grep anchors. No src/ modifications this turn — T51 dispatches the mechanical-fix batch (if any) per Triage stage.",
  "brief": "## ROLE\n\nYou are the researcher subagent. Observe stage of `audit-class-scan-2026-05-18-T50` per director.md §F6 audit-class-scan template. Service AUDIT_DUE gap=49 by sweeping the entire patterns.yaml catalog (9 entries) against current `src/`. Produce findings + triage classification + L3 related_classes proposals. No code modification this turn.\n\n## CONTEXT\n\nLast reactive audit (T48) added 1 class (paper-unit-system-wrong-param-in-spot-check) from an instance trigger. 6 of 9 catalog entries have `last_scanned: null` — never swept. Per anko 2026-05-18 (\"なにか新しくわかったときに既存で他にあるか探すの普通じゃない？\" + \"テストによる発見という前提なくても?\"), the loop must proactively scan the catalog, not only react when an instance surfaces. T49 PASS closed yan-li-saito at tier 0.4; T50 services this audit debt before re-Hypothesizing klaus-bch-leak at T51+.\n\n## REQUIRED READING\n\n1. `/home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml` END-TO-END — the catalog you will sweep. Note each entry has either `grep_patterns:` (list of regex) or `detect:` (manual review prescription).\n2. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_50.md` (this director turn) — your dispatch contract.\n3. `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_49.md` §6 `failure_modes` success-path — explicit T50 routing recommendation (c).\n4. `/home/suzume/workspace/BEC-simulation/CLAUDE.md` `## Known limitations (design boundaries — don't \"fix\")` section — DO NOT flag any of these as findings; they are by-design.\n5. `/home/suzume/workspace/BEC-simulation/CLAUDE.md` `## Conventions (do NOT \"fix\")` section — same.\n6. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/feedback_fix_the_class_not_the_instance.md` — the operating principle.\n7. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/feedback_mechanical_vs_investigation_threshold.md` — the 3-second triage rule applied per-finding.\n8. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/state_zoo_yaml_integration_wip.md` — note: 22 init_psi_* exports are documented WIP-not-dead; `dead-export` scan must explicitly exclude state_zoo per existing memory.\n\n## DELIVERABLE 1: Per-pattern findings table (markdown report)\n\nCreate `runs/_loop/research/turn_50_audit_class_scan.md` with the following structure:\n\n```markdown\n---\nturn: 50\nsubagent: researcher\ntopic_tags: [audit-class-scan, patterns-yaml, sibling-grep, AUDIT_DUE-resolution]\ndepends_on: [49, 'runs/_loop/patterns.yaml', 'runs/_loop/director/turn_50.md']\nproduces: 'Per-class findings table + triage classification + L3 related_classes proposals; patterns.yaml last_scanned/last_count updates queued for Triage'\n---\n\n# Turn 50 — Audit-class-scan Observe stage\n\n## 1. Scope\n- Patterns swept: 9 (all of patterns.yaml `patterns:` list)\n- Sweep scope: `src/`, `test/` (where pattern's `exclude_paths` permits)\n- Time window: this single turn (Observe + Findings + Triage proposals)\n\n## 2. Per-pattern findings\n\n### 2.1 deprecated-name-leak (RECALL scan; last swept T48)\n... <runnable command + raw count + filtered count + first 5 hits with file:line + classification> ...\n\n### 2.2 api-rename-stragglers (FIRST scan)\n... ...\n\n### 2.3 doc-staleness (FIRST scan — note: includes both grep_patterns AND manual review per detect_extra)\n... ...\n\n### 2.4 hardcoded-magic-number (FIRST scan — note: high false-positive risk per pattern description)\n... ...\n\n### 2.5 dead-export (FIRST scan — note: explicitly exclude state_zoo per state_zoo_yaml_integration_wip.md)\n... ...\n\n### 2.6 large-file-bloat (FIRST scan — detect script `find src/ -name '*.jl' -exec wc -l {} \\; | awk '$1 > 800'`)\n... ...\n\n### 2.7 test-mock-of-real (FIRST scan)\n... ...\n\n### 2.8 cargo-cult-comment (FIRST scan — manual review only, pick 5 worst instances)\n... ...\n\n### 2.9 paper-unit-system-wrong-param-in-spot-check (RECALL scan; last swept T48 reactive)\n... ...\n\n## 3. Triage classification\n\nClassify each finding per the 3-second test:\n\n| Pattern | Hits (filtered) | Triage class | Estimated wall-time to clear |\n|---|---|---|---|\n| deprecated-name-leak | <N> | mechanical-fix-now / spawn-fix-bug-child / spawn-investigation / no-action-rationalized | <minutes/hours> |\n... <one row per pattern> ...\n\nLegend:\n- **mechanical-fix-now**: regex / sed-class change; success criterion = grep returns 0 hits OR compiles cleanly. T51 dispatch implementer_text or implementer_julia_cpu_light with direct Edit.\n- **spawn-fix-bug-child**: bug-class issue with non-trivial physics implication; spawn child investigation `fix-bug` template.\n- **spawn-investigation**: pattern reveals a question requiring `verify-claim` or `build-theory`; spawn child accordingly.\n- **no-action-rationalized**: hits exist but are by-design per CLAUDE.md `do NOT fix` section, or in `runs/_loop/` (not actual code), or in `test/` (where applicable). Document the exclusion reason.\n\n## 4. L3 related_classes proposals\n\nFor each NEW pattern proposal, include:\n- `id` (kebab-case)\n- `description` (1-3 sentences, sharp)\n- `grep_patterns` OR `detect` (RUNNABLE — must produce 1-10000 hits per §F6 audit rule)\n- `related_to` (which existing catalog entry it analogizes from)\n- `external_anchor` (= the grep command, with hit count)\n\nProposals go into the queue `proposed_classes:` for T50+1 critic audit; NOT auto-added to active catalog.\n\nExamples of analogical derivation seeds (do NOT add unless YOUR audit produced the supporting evidence):\n- From `deprecated-name-leak`: \"deprecated-config-key-leak\" (YAML configs still referencing removed keys)\n- From `api-rename-stragglers`: \"function-rename-callsite-stragglers\" (specifically focused on `runs/*` script callers, not src/ refactors)\n- From `hardcoded-magic-number`: \"hardcoded-tolerance-in-physics-code\" (specifically tolerances like 1e-8 etc. inside hot loops or convergence checks where they should be configurable)\n\n## 5. patterns.yaml update proposals\n\nFor each pattern, the Triage stage should:\n- Update `last_scanned` to '2026-05-18T<NOW>+09:00'\n- Update `last_count` to the filtered hit count from §2\n- Append a row to `audit_history:`:\n  - run_at, triggered_by ('T50 audit-class-scan §F6 Observe sweep'), patterns_scanned (full list), findings_count (sum), notes (summary).\n\nList these proposed YAML changes literally so T51 implementer can apply them mechanically.\n\n## 6. Next-turn recommendation\n\nGiven the §3 triage table, recommend T51 dispatch:\n- If 1+ `mechanical-fix-now`: T51 = implementer (text or julia_cpu_light) with explicit file:line list + regex + commit message. Single turn, batch-fix all mechanical findings.\n- If 0 mechanical + 1+ `spawn-fix-bug-child` or `spawn-investigation`: T51 = director spawn child investigation (state.json update; researcher Hypothesize next).\n- If only `no-action-rationalized`: T51 = director switch to klaus-bch-leak Hypothesize (priority 3 unblocked).\n- If `proposed_classes` non-empty: schedule a critic-audit side-dispatch at T51 or T52 to gate proposals before adding to active catalog.\n\nSingle commitment per `feedback_decision_style`.\n```\n\n## DELIVERABLE 2: Actual grep + scan execution\n\nFor EACH of the 9 patterns, execute the grep / detect / shell command and record:\n- Raw hit count\n- After applying `exclude_paths` (filtered count)\n- First 5 hits with full file:line context (more if surprising; less if 0)\n- For `detect`-based patterns (doc-staleness `detect_extra`, dead-export, large-file-bloat, cargo-cult-comment, paper-unit-system manual rule): perform the scripted/manual check and record outcomes.\n\nUse `rg` (ripgrep) or `grep -rn` per the Grep tool. Always use absolute paths. Record the exact command run so T51 implementer can reproduce.\n\n### Per-pattern guidance:\n\n**deprecated-name-leak** (RECALL, T48 first scan showed 0 hits post-batch-fix): re-run grep_patterns ['legacy.*(zeeman|B_hat|c_lhy|spinor_lhy|spin_rotating_frame_omega)', 'removed 20\\d{2}', 'deprecated']. Apply exclude_paths ['test/', '.claude/logs/', 'runs/_loop/']. Expected: ~0 substantive hits in src/. Drift signal if >5.\n\n**api-rename-stragglers**: grep_patterns ['@deprecate', 'Base\\\\.depwarn', '_old_', '_v1_']. Apply exclude_paths ['test/']. Note: `@deprecate` in `src/` is legitimate when introducing a rename; tag those as no-action-rationalized.\n\n**doc-staleness**: grep_patterns ['TODO:.*document', 'work in progress', 'WIP', 'FIXME']. ALSO perform spot-check: pick 3 random sections of `CLAUDE.md`, verify against current `src/`. Output: TODO/WIP/FIXME hit count + 3 spot-check verdicts.\n\n**hardcoded-magic-number** (high noise; expect 1000+ hits): grep_patterns ['\\\\b1e-?\\\\d+\\\\b', '\\\\b1\\\\.0e-?\\\\d+\\\\b']. Apply exclude_paths ['test/', 'docs/']. Triage: filter to instances where the same magic number appears in 3+ files (= true class-level issue); single-file constants are OK. Show top 10 multi-file constants ranked by frequency.\n\n**dead-export**: for each `export ...` line in `src/SpinorBEC.jl` (and module-level exports in subsystem umbrellas), grep for callers outside `<defining_file>` and `test/`. **EXPLICITLY EXCLUDE state_zoo init_psi_* per memory `state_zoo_yaml_integration_wip.md`** — those 22 are documented WIP, not dead. Report any other names with 0 external callers.\n\n**large-file-bloat**: run `find /home/suzume/workspace/BEC-simulation/src -name '*.jl' -exec wc -l {} \\;` then filter `>800`. Anko's CLAUDE.md preference: 200-400 typical, 800 max. Report files with line count + suggested split axis (if obvious from file structure).\n\n**test-mock-of-real**: grep_patterns ['mock_\\\\w+\\\\s*=', 'stub_\\\\w+\\\\s*=', 'Mock\\\\w+\\\\(']. Apply exclude_paths ['docs/']. Note: SpinorBEC.jl has a Julia-style test suite that generally doesn't mock production; expect ~0. Real findings would be unusual.\n\n**cargo-cult-comment**: detect-only (manual review). Pick 5 random functions across `src/`, read 3-5 lines of comments each, judge each comment for WHAT vs WHY. Identify the WORST 5 instances (those that comment WHAT the next line obviously does). Report file:line + comment text.\n\n**paper-unit-system-wrong-param-in-spot-check** (RECALL, T48 found 1 instance = T47 critic): re-grep ['a_s\\\\s*=\\\\s*110\\\\s*a[_]?0', 'a_s_si\\\\s*=\\\\s*110\\\\s*\\\\*\\\\s*a_0', 'a_s_bohr\\\\s*=\\\\s*110']. Apply exclude_paths ['test/', 'runs/_loop/judge/turn_47_critic_audit.md']. Expected: 0 in scope.\n\n## DELIVERABLE 3: L3 analogical derivation queue\n\nPropose 2-4 new pattern classes derived analogically from your sweep findings. Each proposal MUST:\n- Have a runnable `grep_patterns` OR `detect` block\n- Produce 1-10000 hits when run (verify before submitting)\n- Differ sharply from existing 9 entries\n- Link to one existing class as `related_to`\n\nIf no new analogical class is justified by your findings (the audit shows the existing 9 are sufficient), state that explicitly — DO NOT manufacture proposals. Per critic L3 rule (§F6): \"Critic-rejected proposals are logged in patterns.yaml proposed_classes with the rejection reason; NOT added to active catalog. This is the safety rail against ungrounded self-reflection.\"\n\n## CONSTRAINTS\n\n- **DO NOT modify any file** other than creating `runs/_loop/research/turn_50_audit_class_scan.md`. patterns.yaml updates are PROPOSED in §5 for T51 implementer to apply, not applied here.\n- **DO NOT modify `src/`**. This is Observe + Findings only.\n- **DO NOT spawn child investigations** in state.json — that's T51 director's call after reading your triage.\n- **DO NOT flag CLAUDE.md `do NOT \"fix\"` items**. They are documented design boundaries.\n- **English only**. Anko prefers Japanese conversation but code/docs/findings English.\n- **No emojis**.\n- **Use absolute paths in all greps + reports** per user CLAUDE.md.\n- **Stay within ~1.5M effective tokens, ~25 min wall**.\n\n## SUCCESS CRITERIA (judge.py evaluates §8 metrics block in your sim file)\n\nThe sim turn (`runs/_loop/sim/turn_50.md`) must contain a §8 metrics block with the following JSON keys evaluated:\n\n```json\n{\n  \"experiment_kind\": \"text_only\",\n  \"deliverable_1_findings_report_present\": true,\n  \"patterns_swept_count\": 9,\n  \"patterns_with_findings_table\": 9,\n  \"patterns_with_triage_classification\": 9,\n  \"l3_proposals_count\": <0-4 integer; can be 0 with explicit rationale>,\n  \"patterns_yaml_update_proposals_present\": true,\n  \"next_turn_recommendation_present\": true,\n  \"src_files_modified\": 0,\n  \"patterns_yaml_modified\": false,\n  \"state_json_modified\": false,\n  \"new_findings_count_total\": <integer; filtered hit count summed across patterns>,\n  \"new_findings_count_actionable\": <integer; subset of total that are mechanical-fix-now / spawn-fix-bug-child / spawn-investigation>,\n  \"investigation_id\": \"audit-class-scan-2026-05-18-T50\",\n  \"stage_advancing_to\": \"Observe\",\n  \"flow_template\": \"audit-class-scan\"\n}\n```\n\nReport ALL findings honestly, even if zero. A 0-findings-total sweep is a VALID result — it means the patterns are dormant-clean OR the patterns are too narrow (in which case L3 should propose tighter or replacement classes).\n\n## DELIVERABLE SUMMARY\n\n1. Single markdown report at `runs/_loop/research/turn_50_audit_class_scan.md` with §1-§6 per template above.\n2. All 9 patterns swept with concrete file:line findings + triage classification.\n3. L3 proposals queue (0-4 entries, each with runnable grep anchor).\n4. patterns.yaml update proposals (last_scanned + last_count + audit_history row) listed verbatim for T51 implementer to apply mechanically.\n5. T51 next-turn recommendation (single commitment).\n6. sim/turn_50.md with §8 metrics block per judge contract.",
  "observable_manifest": {
    "required": [
      "deliverable_1_findings_report_present",
      "patterns_swept_count",
      "patterns_with_findings_table",
      "patterns_with_triage_classification",
      "patterns_yaml_update_proposals_present",
      "next_turn_recommendation_present",
      "src_files_modified",
      "patterns_yaml_modified",
      "state_json_modified",
      "new_findings_count_total",
      "investigation_id",
      "stage_advancing_to",
      "flow_template"
    ],
    "optional": [
      "l3_proposals_count",
      "new_findings_count_actionable"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml && test -d /home/suzume/workspace/BEC-simulation/src && test -f /home/suzume/workspace/BEC-simulation/CLAUDE.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/state_zoo_yaml_integration_wip.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_50.md && python3 -c \"import yaml; cat = yaml.safe_load(open('/home/suzume/workspace/BEC-simulation/runs/_loop/patterns.yaml')); assert len(cat['patterns']) == 9, f'expected 9 patterns, got {len(cat[\\\"patterns\\\"])}'\" && echo 'precondition OK: 9 patterns + src/ + CLAUDE.md + state_zoo memory + director T50 brief all present'"
  },
  "success_criteria": [
    {
      "id": "report_landed",
      "metric": "deliverable_1_findings_report_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "The single deliverable file `runs/_loop/research/turn_50_audit_class_scan.md` must exist with the §1-§6 template structure."
    },
    {
      "id": "all_patterns_swept",
      "metric": "patterns_swept_count",
      "operator": "==",
      "value": 9,
      "tolerance": null,
      "rationale": "All 9 patterns in patterns.yaml must be swept this turn; partial sweep is a scope violation."
    },
    {
      "id": "all_patterns_with_findings",
      "metric": "patterns_with_findings_table",
      "operator": "==",
      "value": 9,
      "tolerance": null,
      "rationale": "Every pattern needs an explicit findings entry (even if hit count = 0, the entry says '0 hits' with the command run)."
    },
    {
      "id": "all_patterns_triaged",
      "metric": "patterns_with_triage_classification",
      "operator": "==",
      "value": 9,
      "tolerance": null,
      "rationale": "Every pattern gets a triage class (mechanical-fix-now / spawn-fix-bug-child / spawn-investigation / no-action-rationalized)."
    },
    {
      "id": "yaml_proposals_present",
      "metric": "patterns_yaml_update_proposals_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Per §F6, last_scanned / last_count / audit_history updates must be PROPOSED (not applied) so T51 implementer can apply mechanically."
    },
    {
      "id": "next_turn_rec_present",
      "metric": "next_turn_recommendation_present",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "T51 dispatch recommendation per `feedback_decision_style` single-commitment."
    },
    {
      "id": "no_src_touched",
      "metric": "src_files_modified",
      "operator": "==",
      "value": 0,
      "tolerance": null,
      "rationale": "Observe stage is read-only. Any src/ modification is a scope violation."
    },
    {
      "id": "no_yaml_touched",
      "metric": "patterns_yaml_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "patterns.yaml updates are queued for T51 Triage, not applied at Observe."
    },
    {
      "id": "no_state_touched",
      "metric": "state_json_modified",
      "operator": "==",
      "value": false,
      "tolerance": null,
      "rationale": "state.json investigation entries are added by director (T50 director may add `audit-class-scan-2026-05-18-T50` to state.json post-Observe — but researcher does not touch state.json)."
    },
    {
      "id": "investigation_id_correct",
      "metric": "investigation_id",
      "operator": "==",
      "value": "audit-class-scan-2026-05-18-T50",
      "tolerance": null,
      "rationale": "Investigation ID consistency."
    },
    {
      "id": "stage_correct",
      "metric": "stage_advancing_to",
      "operator": "==",
      "value": "Observe",
      "tolerance": null,
      "rationale": "Observe is the entry stage per §F6 audit-class-scan."
    },
    {
      "id": "template_correct",
      "metric": "flow_template",
      "operator": "==",
      "value": "audit-class-scan",
      "tolerance": null,
      "rationale": "Template consistency with §F6."
    }
  ],
  "failure_modes": [
    {
      "if": "patterns_swept_count < 9",
      "category": "operational",
      "next_action": "T51 director = re-dispatch researcher with explicit per-pattern enforcement (one section per pattern, no skipping). Identify which patterns were skipped + why; if skipped due to undefined grep_patterns/detect, log as patterns.yaml schema deficiency requiring meta-fix."
    },
    {
      "if": "deliverable_1_findings_report_present == false",
      "category": "operational",
      "next_action": "T51 director = re-dispatch researcher with file-path enforcement (Write tool to `runs/_loop/research/turn_50_audit_class_scan.md`). Verify with `ls`."
    },
    {
      "if": "src_files_modified > 0 OR patterns_yaml_modified == true OR state_json_modified == true",
      "category": "scope_violation",
      "next_action": "T51 director = revert any modifications (git reset / restore); re-dispatch researcher with read-only-mode reinforcement. Observe stage is NEVER a write turn for these files."
    },
    {
      "if": "new_findings_count_total == 0 AND l3_proposals_count == 0",
      "category": "low_signal",
      "next_action": "T51 director = either (a) refine catalog (patterns are too narrow — propose meta-improvement to broaden detect blocks); (b) accept dormant-clean and switch to klaus-bch-leak Hypothesize. Default: (b) if all 9 patterns triaged as no-action-rationalized with rationale; (a) only if researcher flagged catalog narrowness explicitly."
    },
    {
      "if": "new_findings_count_total >= 5 AND any pattern triaged mechanical-fix-now",
      "category": "scientific_success",
      "next_action": "T51 = dispatch implementer (implementer_text or implementer_julia_cpu_light per finding type) with batch-fix brief: explicit file:line + regex + commit message. Single conventional commit per pattern OR one big commit if related-classes are coupled. After T51 = patterns.yaml Triage update (last_scanned + last_count + audit_history)."
    },
    {
      "if": "new_findings_count_actionable >= 1 AND any pattern triaged spawn-fix-bug-child OR spawn-investigation",
      "category": "scientific_success_with_followup",
      "next_action": "T51 director = add child investigation(s) to state.json with appropriate flow_template (fix-bug for code-level; verify-claim for physics-implication; build-theory if theory question surfaces). Researcher Hypothesize next. If multiple, pick highest-priority per anko's seed.md priority hierarchy."
    },
    {
      "if": "l3_proposals_count >= 1",
      "category": "scientific_success_followup",
      "next_action": "T51 OR T52 = critic side-dispatch to audit each L3 proposal against §F6 critic rules (runnable grep, 1-10000 hits, sharp differentiation, related-class link real not vibes). Critic-pass proposals get added to patterns.yaml proposed_classes WITH rejection-or-approval reason; only approved proposals join active catalog."
    },
    {
      "if": "all 9 patterns triaged AND triage = no-action-rationalized",
      "category": "audit_clean",
      "next_action": "T51 director = patterns.yaml Triage update (last_scanned timestamps + last_count = filtered hit counts + audit_history row 'T50 audit-class-scan: 9 patterns swept, 0 actionable findings'), then switch to klaus-bch-leak-2026-05-13 Hypothesize (priority 3, scheduler permits implementer_julia_cpu_light) — re-Hypothesize the P3 falsifier (existing rotating-basis data validates P2 not P3; need fresh lab-frame design for P3)."
    },
    {
      "if": "researcher exceeds budget OR researcher writes to wrong file path",
      "category": "operational",
      "next_action": "T51 director = noop or re-dispatch with stricter budget enforcement; verify file path is `runs/_loop/research/turn_50_audit_class_scan.md` (not `runs/_loop/research/turn_50.md` or other variants)."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 2000000,
    "wall_time_hard_cap_sec": 1800
  },
  "budget": {
    "expected_cost_eff": 1300000,
    "expected_wall_time_sec": 1500,
    "split_by_subtask": {
      "read_patterns_yaml_and_claude_md": 150000,
      "execute_9_pattern_greps_with_filtering": 400000,
      "triage_classification_per_pattern": 250000,
      "l3_proposal_derivation_with_grep_verification": 200000,
      "write_findings_report": 250000,
      "patterns_yaml_proposal_drafts": 50000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Findings (collapsed into same turn) → Triage at T51 (implementer batch-fix if mechanical; director spawn child if investigation-class; switch to klaus-bch-leak Hypothesize if dormant-clean). Single-commit T51 routing per researcher §6 recommendation.",
    "if_success_tier_becomes": 1,
    "if_refuted_advance_to_stage": "N/A — Observe is sweep-and-classify; there is no scientific REFUTED branch for an audit. Operational failures route to T51 re-dispatch.",
    "if_refuted_tier_becomes": "N/A",
    "next_falsifier_to_test_after": "N/A — meta-investigation; next move is Triage outcome at T51."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_50.json` (policy=JULIA_GPU_OK; `researcher` in allowed_workloads; window 1,190,520s left; PROBE_DRIVEN; vram free 12974 MB; foreign julia=0).
- [x] Read `runs/_loop/state.json` end-to-end (yan-li-saito at Document terminal tier 0.4; klaus-bch-leak documented dormant; barnett CLOSED Tier 3.0; 2 dormant meta-investigations; 1 closed meta).
- [x] Read `runs/_loop/seed.md` (priority order: barnett=1 [closed], yan-li-saito=2 [Document landed], klaus-bch-leak=3 [dormant pending julia P3 design]; anko hard constraints; manuscript OUT; AUDIT_DUE explicitly authorized per §F6).
- [x] Read `runs/_loop/director/turn_49.md` (T49 directive; success-path failure_modes explicitly listed (c) audit-class-scan as default T50 recommendation).
- [x] Read `runs/_loop/judge/turn_49.json` (T49 PASS all 11 criteria; investigation_update.if_success_advance_to_stage confirms (c) audit-class-scan path).
- [x] Read `runs/_loop/patterns.yaml` end-to-end (9 patterns; 6 with last_scanned=null; 2 with stale last_scanned; audit_history with 2 prior rows).
- [x] Read `runs/_loop/director/turn_48.md` first 80 lines (T48 explicit deferral of audit-class-scan; that deferral is now overdue at T50).
- [x] Read `runs/_loop/theorist/turn_10.md` and `option_gamma_rotating_basis.md` memory (klaus context: P3 prediction requires fresh lab-frame run, NOT existing rotating-basis jld2 sweep; confirms klaus is NOT a 1-turn move and audit-class-scan is the cleaner T50 pick).
- [x] Read memory `feedback_fix_the_class_not_the_instance.md` + `feedback_mechanical_vs_investigation_threshold.md` + `feedback_decision_style.md` + `feedback_cost_overhead_is_the_cost.md` — anko's behavioral feedback for triage-class work.
- [x] investigation_id `audit-class-scan-2026-05-18-T50` is a NEW investigation; T50 director will add it to state.json via the dispatch (state.json update is implicit via auto-update by loop runner after PASS; researcher does NOT touch state.json per success_criteria `no_state_touched`).
- [x] stage_advancing_to `Observe` is the entry stage per §F6 audit-class-scan template.
- [x] subagent_type `researcher` matches role_per_stage[Observe] in §F6 + scheduler.allowed_workloads.
- [x] success_criteria 12 criteria, machine-evaluable (file presence + counts + booleans + literal strings).
- [x] failure_modes cover 9 likely outcomes including operational sub-types + scope violations + low-signal + scientific-success branches + L3-proposals branch + all-clean branch + budget-overrun branch.
- [x] observable_manifest precondition_check is concrete bash (5 file/dir checks + YAML parse + pattern-count assertion).
- [x] budget 1.3M effective + tolerance 2M effective fit within per-turn cap (6M) and scheduler window. Wall time 25 min well inside 1800s hard cap.
- [x] §A6 research-first citation present (10 references in §4 anchored on patterns.yaml schema + anko's 2026-05-18 §F6 design intent + prior turns' explicit deferral + behavioral feedback memos + Anthropic context-engineering Compress strategy).
- [x] §A5 D1 SECONDARY articulated (codebase-level verification depth — finding deprecated/stale/dead-code in production src/); D3 SECONDARY (loop architecture self-improvement via audit catalog). Not D2 (no optimization). Manuscript NOT primary.
- [x] Considered switching investigations: yan-li-saito R4 (deferred — anko has not surfaced R4 priority); klaus-bch-leak (deferred — needs theorist Hypothesize re-design first, not 1-turn-able); meta-stage-routing / meta-critic-placement (defer post-cascade — sub-threshold drift, framing benefits from post-audit data); audit-class-scan (PICKED — overdue, low cost, high information).
- [x] Drift signals from T49: PASS path; no advisories logged in latest history entry. Predecessor T48 had AUDIT_DUE; this turn explicitly services it.
- [x] Resisted the temptation to spawn yan-li-saito R4 here per `feedback_decision_style` single-commit; resisted dispatching klaus_julia_cpu_light without theorist re-Hypothesize per design-FIRST seed.md §92 ("design FIRST, patches AFTER").
- [x] All file paths in brief are absolute (per user CLAUDE.md instruction).
- [x] Brief delegates the actual classification and L3 derivation to researcher (with empirical anchors required); director does not pre-judge findings.
- [x] Per `feedback_mechanical_vs_investigation_threshold`: T50 is the diagnosis turn; T51 is the execution turn IF findings warrant. The diagnosis-execution separation is a feature of §F6, not over-engineering — anko explicitly added §F6 as the periodic-audit flow on 2026-05-18.
- [x] Per `feedback_fix_the_class_not_the_instance`: this turn IS the class-sweep operating mode anko called for. Sibling instances of paper-unit-system class were already grep'd by T48 researcher; T50 expands to all 8 other dormant catalog classes.
