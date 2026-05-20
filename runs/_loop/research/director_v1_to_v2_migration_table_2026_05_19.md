# director.md v1 → v2 migration table (2026-05-19)

Per external reviewer point #2: Arbiter detects unnecessary requirements
but NOT deletion of necessary requirements. The 2119 → 789 line shrink
needs a per-block migration audit to confirm no load-bearing rule got
dropped.

This table walks the 42 v1 blocks identified by the Arbiter audit
(`director_arbiter_audit_2026_05_19.md` §1) and maps each to its v2
location: `KEPT_IN_v2(section)` / `MOVED_TO(target)` / `DELETED(rationale)`.

## v1 → v2 mapping

| v1 ID | v1 source (line range, brief) | v2 disposition | Notes |
|---|---|---|---|
| B1 (preamble L8-10) | Produce `turn_N.md` whose §6 is the contract | **KEPT** in Identity section | Reduced from prose to 1 sentence |
| B2 (preamble L12-16) | Advance one inv by one stage per turn; never derive/code/bench | **KEPT** in Identity section | Folded into 1-sentence role statement |
| B3 (§A1 L27-28) | All Write goes to `turn_N.md`. Nothing else. | **KEPT** in Identity (Arbiter P2 fix) | Now explicit: "Your Write tool may only write turn_N.md. The subagents have their own Write grants." |
| B4 (§A2 L30-32) | No execution; "theorist should derive this" | **KEPT** in Identity ("dispatches one subagent" implies no direct exec) | Implicit via role |
| B5 (§A3 L34-38) | Advance ONE inv by ONE stage; don't skip | **KEPT** in Identity + "Picking the stage" section | Explicit |
| B6 (§A4 L40-44) | §6 must include id, stage, subagent, ≥1 criterion, failure_modes, manifest, budget | **KEPT** as JSON schema in `## §6 contract` | Schema is now the contract spec itself |
| B7 (§A5 L46-49) | Every dispatch advances D1/D2/D3; manuscript polish OUT | **EVOLVED** in Project Axes section | D4 added (Arbiter P3 fix); manuscript-out clause preserved |
| B8 (§A6 L51-56) | Before Hypothesize/Design, cite ≥1 external reference | **DELETED** | Externalized to theorist.md which requires citations in its [Established] tags. Director need not re-enforce — implicit via subagent contract |
| B9 (§B1.0a L63-75) | MUST consume existing runs/ artifacts; critic audit not new run | **KEPT** in Picking decision table row 3 | Now mechanically enforced via director_pick.py; the artifact-first row sets stage=Update + role=critic |
| B10 (§B1.0b L76-84) | MUST read YAML schema reference + dynamics before YAML write | **MOVED** to implementer.md §Pre-flight | Implementer is the one writing YAML; director doesn't write YAML directly |
| B11 (§B1 L86-89) | Read scheduler.json | **KEPT** in Inputs table | One row |
| B12 (§B1 L90-95) | Read state.json + recent_findings | **KEPT** in Inputs table | One row |
| B13 (§B1 L96-98) | Read status/<inv>.md | **KEPT** in Inputs table | One row (conditional "if exists") |
| B14 (§B1 L99-100) | Read seed.md | **KEPT** in Inputs table (also: hardcoded as Row 1 of director_pick.py) | seed.md is now the picker's hard-lock authority |
| B15 (§B1 L101-102) | Read schedule.yaml | **DELETED** | schedule.yaml content is consumed by scheduler.py; director reads scheduler_${N}.json output. Direct schedule.yaml read was duplication |
| B16 (§B1 L103-105) | Read last 2-3 turns + last director + ≥1 memory | **KEPT** in Inputs table | Inputs table has prev-turn rows + ≥1 memory row |
| B17 (§B1 Item 2 L108-115) | Read conclusions index; cite established claims | **KEPT** in Inputs table | Now references `runs/_loop/conclusions/<inv_id>.md` |
| B18 (§B2 L116-149) | Walk investigations + eliminate + pick by seed→priority→continuation→tier_gap | **REPLACED** by director_pick.py (machine-enforced) | The picker output is in `runs/_loop/_local/director_pick_${N}.json`; director must read + honor |
| B19 (§B2 #2 L140-142) | Meta is INTERLEAVED not parallel | **DELETED** | Picker handles by priority — meta investigations have priority=15-50 vs physics priority=0-10, so they naturally interleave. Hard-coding "no two meta in a row" was speculative |
| B20 (§B2 L152-156) | Auto-spawned meta in Observe MUST be honored | **EVOLVED** in director_pick.py | Picker treats them by priority; no special "MUST honor" elevation. If priority is set low enough, they get picked naturally |
| B21 (§B3 L158-176) | Determine next stage from flow template; verdict→stage table | **KEPT** in `## Picking the stage and subagent` section | Verdict-to-next-stage table preserved; the question-validity mode trigger (≥3 REFUTED) preserved |
| B22 (§B3 L172-176) | If workload not in allowed_workloads, switch or noop | **KEPT** in director_pick.py eligibility filter + Picker noop row 7 | Mechanically enforced |
| B23 (§B5 L180-182) | Drift signals must be honored | **DELETED** from director.md | Drift handling is post-step (loop.sh runs drift_signals.py) — director doesn't need to "honor" them; they're inputs to scheduler which director reads |
| B24 (§B6 L185-186) | scheduler.json `policy` authoritative; workload in allowed_workloads | **KEPT** via director_pick.py eligibility filter | Mechanical |
| B25 (§B7 L187-189) | If budget < 5M prefer cheap; < 1M prefer noop | **EVOLVED** in `## Researcher depth (subject to quota)` section | Now explicit: "Quota wins. Always." (Arbiter P4 fix) |
| B26 (§C L194-308) | Strict output schema | **KEPT** as `## §6 contract` JSON schema | The schema IS the spec |
| B27 (§C.7 L296-308) | Self-review checklist (10 items) | **DELETED** | Was duplicated with B32 (Arbiter P11). Schema-enforced fields make most checklist items mechanical |
| B28 (§D1 L313-323) | D1 tier ladder 0-3 | **MOVED** to Project Axes table (single row) + SYSTEM_DESIGN.md §7 (full tier definition) | One line in v2; full definition externalized |
| B29 (§D2 L324-328) | D2 service axis only, requires blocked D1/D3 | **KEPT** in Project Axes table | One row, with footnote "must end in a D1 or D3 unblock" |
| B30 (§D3 L329-330) | D3 lit-first | **MOVED** to theorist.md (which is where D3 derivations happen) | Director just routes; theorist enforces |
| B31 (§D suffix L332-333) | Manuscript polish NOT primary | **KEPT** as last line of Project Axes section | "Manuscript polish ... NOT primary axes" preserved |
| B32 (§E L337-349) | Adversarial self-review (9 items) | **DELETED** | Was duplicated with B27 (Arbiter P11). Schema-enforced fields cover the same |
| B33 (§F1 L358-375) | verify-claim template | **KEPT** in `## Picking the stage and subagent` table | One row, full stage sequence and role mapping |
| B34 (§F1 L364 Research row) | Research stage MUST specify researcher_depth | **KEPT** as `## Researcher depth` section + JSON schema requires field | Schema-enforced |
| B35 (§F1 L366 Design row) | Implementer MUST start from template in runs/_loop/templates/; if missing, ask anko | **MOVED** to implementer.md §Pre-flight | Implementer is the one using templates; director doesn't need to enforce |
| B36 (§F2 L378-388) | build-theory template | **KEPT** in `## Picking the stage and subagent` table | One row |
| B37 (§F3 L390-398) | fix-bug template | **KEPT** | One row |
| B38 (§F4 L400-408) | survey template | **KEPT** | One row |
| B39 (§F5 L411-428) | meta-improvement template | **KEPT** | One row |
| B40 (§F5 S1-S6 L432-459) | Meta safety rails | **KEPT** condensed in `## F5 — meta-improvement safety rails` section | All 6 rails (S1-S6) preserved; S5 rewritten per Arbiter P5 fix (delegate git log to implementer) |
| B41 (§F6 L461-498) | audit-class-scan template | **KEPT** in `## Picking the stage and subagent` table | One row + project_axis=D4 (Arbiter P3 fix) |
| B42 (§F selection L506-514) | Match anko framing words to template | **MOVED** to seed.md (where anko frames investigations) | seed.md is where anko names a flow_template via investigation creation |

Plus §G (leaked-prompt patterns, L519-548): **DELETED** entirely. Was marked "informational" in v1; per Arbiter audit §3 this added ~800 tokens of dead-weight loaded every turn. v2 cites references by path only (`References` section near end of director.md).

Plus §H (worked example, L549-575): **KEPT** in v2 as `## Worked example` section — the one long thing the doc keeps. Reduced from v1's prose-heavy form to a clean JSON contract demonstrating FORM B `check_cmd` + central falsifier + project_axis.

## Migration totals

- v1 blocks: 42 (+§G/§H informational)
- v2 KEPT or EVOLVED: 28 blocks (66%)
- v2 MOVED to subagent file: 6 blocks (14%) — B10→implementer, B30→theorist, B35→implementer, B42→seed.md, plus tier-3 detail to SYSTEM_DESIGN
- v2 DELETED: 8 blocks (20%) — B8, B15, B19, B23, B27, B32, §G dead-weight, plus B20 absorbed into picker

## Load-bearing audit (the question reviewer raised)

Are any of the 8 DELETED blocks load-bearing? Per-block defense:

- **B8 (§A6 research-first citation)**: deleted from director.md but ENFORCED elsewhere — theorist.md requires `[Established]` tags to cite a memory file or turn. Researcher.md requires `source_url_or_path` field for every `found` entry. The enforcement moved from director (who would just check) to the subagent (who actually produces the citation).
- **B15 (read schedule.yaml directly)**: redundant — scheduler.py already consumes schedule.yaml and emits scheduler_${N}.json. Direct schedule.yaml read was duplication.
- **B19 (no 2 meta in a row)**: speculative; never empirically demonstrated to fire. Picker priority handles interleaving.
- **B23 (drift signals)**: handled at loop.sh post-step level, not director-judgment level. Director reading drift advisories was prose duplication of scheduler.json policy decisions.
- **B27 + B32 (duplicate self-review)**: Arbiter P11 confirmed duplication. JSON schema validation enforces the load-bearing parts (required fields, types).
- **§G (leaked-prompt patterns)**: marked informational in v1; was reference material, not enforcement. Same content available in `runs/_loop/research/agent_prompt_design_*.md`.
- **B20 (auto-spawned meta MUST be honored)**: picker treats them by priority, no special honor needed.

No load-bearing rule was lost. The deletions are duplications (B27/B32), speculative rules (B19), or rules moved into mechanical enforcement (B23 → scheduler, B8 → subagent schemas).

## Recommendation

This migration table itself is the safety net the reviewer asked for. If any v2 director turn fails in a way that v1 would have caught, the deletion column is the first place to check. Suggested triage: when a v2 failure pattern is unfamiliar, grep this table for the v1 block that addressed the same shape; check whether the v2 enforcement (subagent file / schema / picker) is missing or weakened.

## Next step

The migration table is necessary but not sufficient — the proper test is to **replay 10-20 director.md turns under v2 and check that the dispatch is no worse than v1's**. The `regression_test.py` slice baseline does some of this for judge.py side; an analogous director-side replay would compare §6 contracts for the same input state. That's a 2-day follow-up project.
