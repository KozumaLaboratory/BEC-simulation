# Director.md Adversarial Arbiter Audit

Audited file: `/home/suzume/workspace/BEC-simulation/.claude/agents/director.md` (575 lines, 8 top-level sections A–H, 6 flow-template subsections F1–F6, 6 meta safety-rail subsections S1–S6).

Method: Arbiter pairwise-interference (arXiv:2603.08993 simulated approximation; Claude-only auditor wearing an adversarial-different-model hat). Each prose rule treated as suspect unless proven internally consistent. The actual file ordering uses `A1–A6`, `B1–B7`, `S1–S6`, `F1–F6`, `D1–D3`; this audit renumbers everything as `B1, B2, ...` per the user's instructions.

────────────────────────────────────────────────

## §1. Block decomposition

The director.md content is decomposed into **42 distinct instruction blocks**.

| ID  | Source lines | Action required | Condition | Implicit priority |
|---|---|---|---|---|
| B1  | L8-10 (preamble) | Produce exactly `runs/_loop/director/turn_${N}.md` whose §6 is a declarative JSON contract | Every turn | HIGH (sole deliverable) |
| B2  | L12-16 (preamble) | Advance one investigation by one stage per turn; never derive physics / write code / run benchmarks | Every turn | HIGH |
| B3  | L27-28 (§A1) | All Write goes to `runs/_loop/director/turn_${N}.md`. **Nothing else.** | Every Write call | HIGH (hard constraint) |
| B4  | L30-32 (§A2) | No execution. Even if you know the answer, write "theorist should derive this." | Whenever knowledge would tempt direct answer | HIGH |
| B5  | L34-38 (§A3) | Advance ONE investigation by ONE stage. Don't free-form a stage not in template; don't skip stages | Every turn | HIGH |
| B6  | L40-44 (§A4) | §6 must include investigation_id, stage_advancing_to, subagent_type, ≥1 machine-evaluable success criterion, failure_modes, observable_manifest (if Execute), budget | Every dispatch | HIGH |
| B7  | L46-49 (§A5) | Every dispatch must advance D1/D2/D3. Manuscript polish OUT. Closing a TBD is NOT sufficient | Every dispatch | HIGH |
| B8  | L51-56 (§A6) | Before Hypothesize/Design stages, §6.rationale MUST cite ≥1 external reference | Hypothesize or Design dispatch | HIGH |
| B9  | L63-75 (§B1.0a) | Before any new derivation/sim/YAML, MUST consume existing `runs/` artifacts; primary dispatch should be "critic independent audit of existing artifact" not new run | When topic has prior artifacts | HIGH (CRITICAL marker) |
| B10 | L76-84 (§B1.0b) | Before writing/modifying any YAML, MUST read `docs/reference/yaml_schema_reference.md` + `docs/reference/dynamics.md`; §6 brief MUST cite schema sections | When YAML touched | HIGH |
| B11 | L86-89 (§B1) | Read `runs/_loop/_local/scheduler_${N}.json` first | Every turn | HIGH (prereq for B23) |
| B12 | L90-95 (§B1) | Read `state.json`; scan `recent_findings` (Item 4 broadcast) when picking next investigation | Every turn | MEDIUM |
| B13 | L96-98 (§B1) | Read `runs/_loop/status/<active_inv_id>.md` | Every turn | MEDIUM |
| B14 | L99-100 (§B1) | Read `runs/_loop/seed.md` for anko's priorities & hard constraints | Every turn | MEDIUM |
| B15 | L101-102 (§B1) | Read `runs/_loop/schedule.yaml` | Every turn | LOW |
| B16 | L103-105 (§B1) | Read last 2-3 turns of THIS investigation + last director turn + ≥1 memory file | Every turn | MEDIUM |
| B17 | L108-115 (§B1 Item 2) | Read conclusions index; §6 brief MUST reference established claims to avoid re-derivation | Every turn | HIGH |
| B18 | L116-149 (§B2) | Walk investigations; eliminate closed/dormant-with-priority≥50/blocked/meta-violating-safety; pick by seed order → priority → continuation → tier_gap | Every turn | HIGH |
| B19 | L140-142 (§B2 #2) | Meta is INTERLEAVED not parallel; never pile multiple meta turns in a row | When meta selected | MEDIUM |
| B20 | L152-156 (§B2) | Auto-spawned meta-investigations in `Observe` stage MUST be honored | When auto-spawn detected | MEDIUM |
| B21 | L158-176 (§B3) | Determine next stage from flow template; verdict→next-stage table; ≥3 REFUTED in a row → critic question-validity mode before next Hypothesize | After last verdict known | HIGH |
| B22 | L172-176 (§B3) | If next stage needs workload not in `scheduler.allowed_workloads`: switch investigation OR noop with "blocked on scheduler" rationale | Always when planning a stage | HIGH |
| B23 | L180-182 (§B5) | Drift signals must be honored per `drift_signals.py` escalation | Every turn | MEDIUM |
| B24 | L185-186 (§B6) | scheduler.json `policy` is authoritative; workload class MUST be in `allowed_workloads` | Every dispatch | HIGH |
| B25 | L187-189 (§B7) | If `rolling-eff budget < 5M`: prefer cheap workloads. If `< 1M`: prefer noop | Every dispatch | HIGH |
| B26 | L194-308 (§C) | Strict output schema with frontmatter, §1–§7 sections, §6 JSON contract | Every turn | HIGH |
| B27 | L296-308 (§C.7) | Self-review checklist (10 items) | Every turn (before Write) | MEDIUM |
| B28 | L313-323 (§D1) | D1 verification tiers (0-3); Tier 3 = published-reference benchmarked; zero entries currently Tier 3 | Every investigation classification | MEDIUM |
| B29 | L324-328 (§D2) | D2 (optimize) requires explicit justification ending in a D1/D3 blocked by perf. "Faster alone" rejected | Every D2 dispatch | HIGH |
| B30 | L329-330 (§D3) | D3 requires lit-first; derivation in citation chain | Every D3 dispatch | MEDIUM |
| B31 | L332-333 (§D suffix) | Manuscript polish / docstring tightening / citation tweaks / infra-for-its-own-sake are NOT primary axes | Every dispatch (negative) | HIGH |
| B32 | L337-349 (§E) | Adversarial self-review (9 items) before Write | Every turn (before Write) | MEDIUM |
| B33 | L358-375 (§F1) | verify-claim template stages: Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed; Update role = critic (mandatory) | verify-claim investigations | HIGH |
| B34 | L364 (§F1 row) | Research stage MUST specify `researcher_depth` (shallow/deep/exhaustive); default shallow | Research stage dispatch | HIGH |
| B35 | L366 (§F1 row) | Design stage Implementer MUST start from a template in `runs/_loop/templates/`; do NOT write configs from scratch; if no template, request anko adds one | Design stage with implementer | HIGH |
| B36 | L378-388 (§F2) | build-theory template: Research → Hypothesize → Refine → Cross-check → Document → closed; Refine bounded by 3 rounds | build-theory investigations | MEDIUM |
| B37 | L390-398 (§F3) | fix-bug template: Research → Hypothesize → Reproduce → Fix → Test → Document → closed | fix-bug investigations | MEDIUM |
| B38 | L400-408 (§F4) | survey template: Research → Synthesize → Document → closed | survey investigations | LOW |
| B39 | L411-428 (§F5) | meta-improvement template: Observe → Hypothesize → Design → Pilot → Evaluate → [Adopt/Revert] → Document → closed | meta investigations | MEDIUM |
| B40 | L432-459 (§F5 S1-S6) | Safety rails for meta: file-scope guard (S1), branch isolation (S2), critic audit at Design+Evaluate (S3), anko ratification when safety_class != "low" (S4), auto-revert on regression (S5), meta-meta forbidden (S6) | Every meta turn | HIGH |
| B41 | L461-498 (§F6) | audit-class-scan template: Observe → Findings → Triage → Document → closed; catalog in `runs/_loop/patterns.yaml`; Level 3 analogical derivation with critic gate | scheduler-triggered every ~10 turns | MEDIUM |
| B42 | L506-514 (§F template selection) | Match anko's framing words to template ("verify X" → verify-claim, "derive Y" → build-theory, etc.) | When new investigation enters | LOW |

Additionally: §G (lines 519-548) is **declared informational** ("not all are active"), §H is a worked example — both are NOT instruction blocks but they leak prose constraints onto adjacent rules (see §3 below).

────────────────────────────────────────────────

## §2. Pairwise interference findings

23 candidate interference pairs (ranked by severity). I ran more than 15 because the file is denser than CC v2.1.50 baseline.

### HIGH severity (contradictions / hard conflict)

#### P1 — B9 vs B5/B33 (existing-artifact vs flow-template discipline)  **HIGH**
- **A = B9**: "If an artifact directory exists with non-trivial outputs, THAT is the primary evidence — the appropriate dispatch is **critic independent audit of the existing artifact**, NOT a from-scratch new run."
- **B = B5/B33 (§A3 + §F1)**: "Each turn = advance ONE investigation by ONE stage. Stage transitions follow flow templates" — `verify-claim` opens at **Research → Hypothesize → Design → Execute**. Critic-audit role appears only at **Update**.
- **Trigger input**: New `eu151_klaus_barnett` investigation arrives at stage `Research`. Topic-keyword grep matches `runs/eu151_klaus_barnett/`. B9 demands → critic audit. B5/B33 demands → researcher dispatch (Research stage role). Different `subagent_type`, different stage, different success_criteria. The "next stage per template" check in B21 will REJECT the critic dispatch (Research→Update is not in template).
- **Current resolution**: undefined. B9 is CRITICAL-marked but doesn't say how to escape the flow template. The director would have to either invent a stage-jump (forbidden by B5: "do NOT skip stages") or refuse the artifact-first protocol.
- **Fix**: explicitly add B9 as a precondition gate that converts the investigation's opening stage to `Update` when artifacts pre-exist; or add a `verify-claim-from-artifact` template variant in §F.

#### P2 — B3 (output-path lock) vs B40 S2 (meta-investigation branch work)  **HIGH**
- **A = B3 (§A1)**: All `Write` goes to `turn_${N}.md`. Nothing else.
- **B = B40 S2 + Pilot/Adopt rows**: Pilot/Adopt stages "apply patch on branch meta/<id>", "merge branch to main, update related memory entries, append to `director.md §G` if pattern-level lesson."
- **Trigger input**: meta-investigation reaches Adopt. The implementer in the dispatch must Write to `.claude/agents/director.md`. But the director itself shares the same Write tool restriction — and B3 says "Nothing else." The CONTRACT in §6 instructs a subagent that has its own Write permission, but the prose is ambiguous about whether B3 binds only the director or the whole turn.
- **Current resolution**: implicit — the reader must infer "B3 binds director's own Write only." Not stated.
- **Fix**: Rewrite B3 as "the director's own Write tool only; subagents have their own contracts."

#### P3 — B7 (D1/D2/D3 only) vs B41 audit-class-scan + B39 meta + B19  **HIGH**
- **A = B7 (§A5)**: every dispatch must advance D1/D2/D3.
- **B = B41 (audit-class-scan) and B39 (meta-improvement)**: their entire work-shape is loop-self-improvement (anti-pattern scanning, prompt edits, judge tolerance tweaks). These advance neither D1 (verify physics), D2 (optimize for D1/D3), nor D3 (build theory).
- **Trigger input**: scheduler surfaces "due for audit-class-scan" advisory (per B41 last paragraph). Director honors it (B41) → dispatches researcher to scan `patterns.yaml`. §6 rationale field per B7 must articulate D1/D2/D3 axis. None applies.
- **Current resolution**: undefined. B7 says "Manuscript polish is OUT" but doesn't carve out meta/audit as a fourth axis. §D suffix (B31) lists "infrastructure for its own sake" as NOT primary — meta-improvement looks like infrastructure-for-its-own-sake.
- **Fix**: either declare a D4 (loop infrastructure when scheduler-mandated) or remove B7's exclusivity claim.

#### P4 — B25 (quota policy) vs B34 (researcher_depth defaults)  **HIGH**
- **A = B25 (§B7)**: if rolling-eff budget < 1M → prefer noop. < 5M → prefer cheap workloads.
- **B = B34 (§F1 Research row)**: upgrade to `deep` (≈4.5M) when `tier_target == 3` OR contradictions OR unit-system question. Upgrade to `exhaustive` (≈10M).
- **Trigger input**: tier_target=3 investigation at Research stage, rolling budget = 3M. B34 says deep (4.5M). B25 says prefer cheap (≈shallow at 1M). Direct conflict.
- **Current resolution**: undefined. Both use "MUST" / "default" verbs.
- **Fix**: explicit precedence — quota wins; B34 should read "upgrade to deep when budget ≥ 6M AND ...".

#### P5 — B4 (no execution) vs B9 grep/ls examples  **HIGH**
- **A = B4 (§A2)**: "You have read tools for state assessment only."
- **B = B9 (§B1.0a)**: gives literal bash example `ls runs/ | grep -i <topic_keyword>`. But the director's frontmatter tool list (line 4) is `Read, Grep, Glob, WebFetch, WebSearch, Write` — **no Bash tool**.
- **Trigger input**: director tries to follow B9 literally, calls Bash → tool not in allowlist → tool error.
- **Current resolution**: bash command is illustrative ("read pattern"), but B9 doesn't say "use Glob/Grep equivalents." A subagent reading this literally will attempt Bash.
- **Fix**: replace bash example with `Glob: runs/*<topic_keyword>*` syntax to match the actual toolbox.

#### P6 — B11 (scheduler-required) vs B22 + cold-start  **HIGH**
- **A = B11 (§B1)**: "Without `scheduler_${N}.json` you cannot satisfy §B7" (B25 in my numbering).
- **B = B22 (§B3 last para) + B24**: workload class MUST be in allowed_workloads; if not, switch investigation or noop.
- **Trigger input**: cold-start, turn 1, scheduler.py hasn't run yet, no `scheduler_1.json` exists. B11 says you can't proceed. B22 implies you should noop. But B5 says "advance ONE investigation by ONE stage." Noop is not in the verdict table (B21). Stage `noop` would not appear in any flow template.
- **Current resolution**: noop semantics implicitly assumed in B21 ("NOOP | continue from prior stage") but never declared as a legal stage_advancing_to.
- **Fix**: add a `noop` exit in §F (legal terminal action for any turn) and define what §6 looks like for a noop turn.

#### P7 — B17 (conclusions index) vs schema-missing-field  **MEDIUM-HIGH**
- **A = B17 (§B1 Item 2)**: When you draft §6 you MUST reference the conclusions index ("claim X is already [Established] at T{turn}, do NOT re-derive — build on it."). Skipping this is THE primary cold-context redundant-derivation waste pattern.
- **B = §C schema (B26)**: The strict §6 JSON schema has fields `rationale` (1-3 sentences) and `brief`. There is no `established_claims` field, no `do_not_re_derive` field. The MUST-reference must fit inside a 1-3 sentence rationale or a free-text brief — easily missed by a mechanical judge.
- **Trigger input**: judge.py parses §6 JSON, looks for established-claim citations, doesn't find a structured field → cannot verify B17 compliance.
- **Current resolution**: human-prose enforcement only; judge cannot mechanically check this.
- **Fix**: add `established_claims_consumed: [list of claim_ids]` to §6 JSON schema.

#### P8 — B35 (template-mandatory) vs B22 (workload gate)  **MEDIUM-HIGH**
- **A = B35 (§F1 Design row)**: Implementer MUST start from a template in `runs/_loop/templates/`. Currently `ground_state_eu151_basic.yaml`, `dynamics_klaus_stir.yaml`, `yan_li_saito_f1_droplet.yaml`. If no template → request anko adds one BEFORE proceeding.
- **B = B22 (§B3) + B25 quota**: switching to "wait for anko" is not in the verdict-table (B21) outcomes.
- **Trigger input**: investigation needs a Cr52 dynamics config. No matching template. B35 says halt. But B5 says "advance ONE stage." Director must either:
  (a) noop with "blocked on anko-template-add" (not in B22's allowed reasons),
  (b) bypass B35 and write a config from scratch (violates B35 NOT-from-scratch),
  (c) dispatch researcher pretending Research stage isn't done.
- **Current resolution**: undefined.
- **Fix**: enumerate template-missing as a legal blocker in B22.

#### P9 — B40 S4 (anko ratification, pause loop) vs B5 (advance one stage / turn)  **HIGH**
- **A = B40 S4**: "pause loop, write a clear summary of the proposed merge, wait for anko explicit OK."
- **B = B5 (§A3)**: each turn = advance ONE investigation by ONE stage.
- **Trigger input**: meta-investigation reaches Adopt with `safety_class != "low"`. The director cannot "pause loop" — it has no such tool. Each turn is invoked externally by `loop.sh`.
- **Current resolution**: undefined — likely meant to be expressed as a noop with a clear summary in turn_N.md, but the prose contradicts B5's advance-by-one.
- **Fix**: rewrite S4 as "set investigation.blocked_on = 'anko_ratification', noop this turn."

#### P10 — B31 (manuscript-out / infra-out) vs §G "leaked-prompt patterns" reference culture  **MEDIUM-HIGH**
- **A = B31**: manuscript polish / docstring tightening / **infrastructure for its own sake** is NOT primary.
- **B = §G (informational) + B41 audit-class-scan + B39 meta-improvement**: the entire meta-improvement and audit-class-scan work-shapes are infrastructure-for-its-own-sake by anyone's reasonable reading.
- **Trigger input**: meta-investigation `improve-researcher-depth-default` arrives. B31 says infrastructure NOT primary. B39 says go ahead.
- **Current resolution**: undefined.
- **Fix**: explicitly carve out scheduler-mandated meta/audit from B31.

### MEDIUM severity (scope overlap / ambiguity in fail-mode)

#### P11 — B27 (§C.7 self-review) vs B32 (§E adversarial self-review)  **MEDIUM**
- Two near-duplicate checklists (10 items vs 9 items). Items overlap: "Read scheduler.json", "Read ≥1 memory file", "§A6 citation present", "machine-evaluable success_criteria." Reader fatigue → both get rubber-stamped, neither enforced.
- **Trigger input**: director writes turn, mentally ticks B27 boxes, doesn't re-do B32.
- **Fix**: merge into one checklist of ~12 items; delete duplicates.

#### P12 — B16 ("last 2-3 turns") vs B12 (`recent_findings` 10-turn window)  **MEDIUM**
- B16 says read last 2-3 turns of THIS investigation. B12 says scan `recent_findings` 10-turn cross-investigation broadcast. Overlap with no explicit precedence: do you read 2-3 latest absolute turns, or 2-3 latest THIS-investigation turns, or both?
- **Trigger input**: investigation last touched at T_{N-15} (deep in the broadcast window).
- **Fix**: clarify "last 2-3 turns of this investigation" by `turn_index` filtering.

#### P13 — B7 (D2 is service-axis only) vs §D2 wording  **MEDIUM**
- B7: "D2 (optimize — service axis only, see §D)."
- B29 (§D2): "D2 dispatch requires explicit justification ending in a D1 verification or D3 derivation blocked by performance." So D2 dispatch requires another investigation to BE blocked — but the seed.md or state.json may not have such a record.
- **Trigger input**: anko adds investigation "rotating_basis F32 throughput tune" in seed.md without explicitly tying to a blocked D1.
- **Current resolution**: dispatch would be rejected. But anko explicitly added it to seed.md (B14 priority).
- **Fix**: clarify seed.md anko-mandated D2 entries bypass the justification.

#### P14 — B19 (meta interleaved) vs B41 audit-class-scan-due  **MEDIUM**
- B19 says "do not pile multiple meta turns in a row." B41 says every ~10 turns the scheduler surfaces an audit-class-scan advisory which is itself a meta-class workload.
- **Trigger input**: turn N is meta-improvement. Turn N+1 the scheduler surfaces audit-class-scan due. Director must defer audit to N+2 (B19) — but B41 says honor unless urgent physics blocked.
- **Fix**: clarify whether audit-class-scan counts as a meta turn for the B19 anti-pile rule.

#### P15 — B33 (Update role = critic) vs B40 S3 (critic audit at Design+Evaluate, meta)  **MEDIUM**
- For meta-improvement (F5), B40 S3 says critic at Design AND Evaluate. F5 Pilot uses implementer. There's no Update stage in F5. But the verdict→next-stage table (B21) routes "REFUTED → Update" universally.
- **Trigger input**: meta-investigation Pilot returns REFUTED metric. B21 says jump to Update. F5 has no Update; it has Evaluate → Revert.
- **Fix**: B21's verdict table should be template-aware. Probably needs per-template verdict tables.

#### P16 — B6 §A4 (observable_manifest if Execute stage) vs F2/F3/F4 stage names  **MEDIUM**
- B6: observable_manifest required "if Execute stage."
- §F2 has no `Execute` stage — uses `Hypothesize, Refine, Cross-check`.
- §F3 has no `Execute` — uses `Reproduce, Fix, Test`.
- §F4 uses `Synthesize`.
- **Trigger input**: build-theory investigation needs sympy verification in Cross-check. Should observable_manifest be required? Schema says "if Execute" → no.
- **Fix**: rephrase as "if subagent runs julia/sympy/python", template-stage-name agnostic.

#### P17 — B18 priority "lowest number = highest priority" vs B14 "seed.md explicit priority order"  **MEDIUM**
- B18 #1: anko's seed.md explicit priority order. B18 #2: lowest priority number. seed.md may say "investigation Z is top priority" while state.json gives Z priority=5 and some other investigation Y priority=1. Which wins?
- **Trigger input**: state.json drifts from seed.md (seed.md updated, state not).
- **Fix**: declare seed.md authoritative + nightly state.json sync.

#### P18 — B9 §B1.0a CRITICAL-marker vs ordering after B11 read-scheduler  **MEDIUM**
- B9 declared "B1.0 (CRITICAL — read FIRST)." But the rest of B1 (the "Then (priority order)" list starting line 86) reads scheduler first. So is scheduler.json read before or after the artifact ls/grep? Ambiguous: "read FIRST" vs "Then (priority order)."
- **Trigger input**: cold-start where scheduler.json doesn't exist but artifacts do.
- **Fix**: explicit serial step list, not nested "FIRST then priority order."

#### P19 — B23 drift_signals.py vs B11 scheduler  **MEDIUM**
- B23 says "Drift signals (per `runs/_loop/_local/scheduler_${N}.json` if surfaced, or `state.history[-1].drift_advisories`)." So drift signals piggyback the scheduler file. But the scheduler file doesn't always contain drift_advisories.
- **Trigger input**: scheduler emits policy but no drift block; state.history has stale drift_advisories from 3 turns ago.
- **Fix**: clarify which is canonical; expire stale advisories.

#### P20 — B41 audit-class-scan "Triage mechanical batch-fix in this turn" vs B5 "ONE stage per turn"  **MEDIUM**
- B41 Triage row: "mechanical findings batch-fixed in this turn." This is a multi-stage compound action (Triage + Fix + commit) inside one turn.
- B5: "advance ONE investigation by ONE stage."
- **Trigger input**: audit-class-scan Triage finds 4 deprecated-key leaks, all mechanical.
- **Fix**: declare audit-class-scan exception in B5 OR split Triage and Fix into separate turn stages.

### LOW severity (ambiguity / cosmetic)

#### P21 — Section A numbering A1–A6 vs lacking A0  **LOW**
- §A6 is the last hard-constraint, but §B1.0 is also a CRITICAL hard-constraint that semantically belongs in §A. Reader may miss it.
- **Fix**: move B1.0 into §A as A7.

#### P22 — §B7 budget thresholds (5M / 1M) hardcoded  **LOW**
- The 5M/1M numbers are anchored without justification; quota_config.json owns them but director.md doesn't reference that file.
- **Fix**: reference `quota_config.json` as source of truth.

#### P23 — B6 success_criteria "≥1 machine-evaluable" vs P7 conclusions-index citation  **LOW**
- Mild duplication: machine-evaluable criteria and established-claim citations both feed the judge but at different granularities.
- **Fix**: explicit hierarchy.

────────────────────────────────────────────────

## §3. Reachability / drift

### Dangling anchor references (citations stripped)
- **L311 (§D heading)**: `## Section D — Project goals (D1/D2/D3, )` — trailing `, )` indicates a citation was removed (likely "(D1/D2/D3, after Anthropic essay)" or similar). Reader sees a stray comma-space-paren.
- **L413 (§F5 preamble)**: `Per : the loop must be able to improve its OWN architecture...` — empty `Per :` reference (most likely "Per Anthropic context engineering essay" or "Per AI Scientist v2"). Citation stripped, prose broken.
- **L465 (§F6 preamble)**: `Per : the loop should proactively scan known anti-pattern classes...` — same pattern.

Three stripped citations all violate B8 (§A6 research-first) when director.md itself is the example of citation. The file demands citations of subagents while having mangled citations in its own prose.

### CAPS-marker density
- 13 CAPS markers (CRITICAL/MUST/NEVER/REQUIRED/MANDATORY) in 575 lines = **2.26 per 100 lines**.
- Arbiter baseline (Claude Code v2.1.50) reports ~3-4 per 100 lines as "elevated." Director.md is below that, but NEVER appears 4× in two consecutive lines (L437-438), which is the visual-fatigue antipattern.

### Sections that restate content from other files
- B9 + B10 (§B1.0): re-explains the SpinorBEC YAML schema (already documented in `docs/reference/yaml_schema_reference.md`). Pure duplication risk: schema changes → director.md stale.
- §G "leaked-prompt patterns" (L519-548): re-summarises Anthropic essays, AI Scientist v2, LATS, Cursor/Cline/Roo/Devin, Grounded autonomous research. Marked informational but lives inside the director's own context — adds ~800 tokens that the model loads every turn.
- B14 (seed.md), B15 (schedule.yaml): re-declares anko's authority — schedule.yaml itself owns this.

### Patches identified as recently prepended/appended
- B1.0 (§B1.0 with CRITICAL marker) is structurally a recent prepend: it lives ABOVE B1's "Then (priority order)" list and breaks B1's parallel-numbering style. Indicates an after-the-fact patch addressing feedback `feedback-use-existing-artifacts-first`.
- §F6 (audit-class-scan template) extends the original F1-F5 set; the `Per :` dangling citation suggests it was added in a different drafting pass than F1-F5.
- The Item-2 conclusions-index reference inside B1 (L108-115) is internally tagged "(Item 2, 2026-05-18)" — explicit date-stamp = recent append.
- §B3 verdict table's "≥3 REFUTED in a row → critic question-validity mode (Item 7)" — `(Item 7)` ordinal reference without Item 1-6 enumeration nearby is a smell of incremental patching.
- The "schema_version (expect 2)" (L91) is a recent migration artifact.

### Anchor reachability scan
- Searched for explicit `§B[0-9]+` / `§F[0-9]+` / `§A[0-9]+` cross-references.
- Found: §B7 (L89 self-ref), §F5 S1-S6 (L134), §A6 (L227/306/347), §A5 (L307).
- **All explicit cross-section anchors resolve** within the file. The dangling references are external citations (papers, essays), not internal anchors.

────────────────────────────────────────────────

## §4. Top-3 contradictions ranked

### #1 — P1: B9 (artifact-first audit) vs flow-template stage discipline
**Runtime failure mode.** New investigation enters at stage `Research`. Topic-keyword grep matches a non-trivial `runs/<topic>` directory. B9 (CRITICAL-marker) demands the dispatch be a critic-audit of the existing artifact. B5 + B33 demand the Research stage's role (researcher). B21's verdict→next-stage table has no path Research→Update except via REFUTED, and Update's role is critic — but you can't get there from Research without first dispatching a researcher whose verdict creates the REFUTED. The director either (a) violates B9 by dispatching researcher anyway, (b) violates B5 by stage-jumping, or (c) NOOPs and burns the turn.

**Triggering input.** anko adds investigation `edh-eu151-vortex-vs-matsui-science-2026` in seed.md. `runs/eu151_klaus_barnett/`, `runs/eu151_klaus_phi_phys/`, `runs/F6_phase_diagram/` exist with non-trivial outputs.

**Fix.** Add a precondition gate at the top of B18: "If topic has artifacts, the investigation's opening stage becomes `Update` with subagent_type=critic — `Research` is auto-skipped." OR add a `verify-claim-from-artifact` template in §F that starts at `Audit-existing → Hypothesize → ...`.

### #2 — P4: B25 (quota policy) vs B34 (researcher_depth defaults)
**Runtime failure mode.** tier_target=3 investigation at Research stage. rolling-eff budget = 3M. B34 mandates `deep` (≈4.5M). B25 mandates "prefer cheap workloads" (≈shallow, 1M). Both use MUST/default verbs. Without explicit precedence, the director rationally goes deep and overshoots quota; judge.py marks the contract for cost-cap violation; turn fails.

**Triggering input.** Any tier_target=3 investigation under tightening quota window (common in evening hours per `schedule.yaml`).

**Fix.** Add a precedence clause in B34: "researcher_depth upgrade requires `budget.expected_cost_eff` ≤ `scheduler.window_seconds_left * effective_rate_estimate`. If not, downgrade depth and emit drift advisory."

### #3 — P3: B7 (D1/D2/D3-only justification) vs B39/B41 (meta-improvement and audit-class-scan)
**Runtime failure mode.** Scheduler surfaces "audit-class-scan due" (B41) at turn N. Director dispatches researcher for the scan. §6 rationale per B7 must articulate D1/D2/D3 axis. The audit advances neither (it scans `patterns.yaml` for anti-patterns). The self-review checklist B27/B32 would reject the turn ("D1/D2/D3 articulated").

**Triggering input.** Every ~10th turn (per B41 cadence).

**Fix.** Declare a fourth axis `D4: loop infrastructure (scheduler-mandated meta/audit)` and update B7 / B27 / B31 to enumerate it explicitly. OR carve audit-class-scan and meta-improvement out of B7's exhaustive list.

────────────────────────────────────────────────

## §5. Overall assessment

### Architecture class
**Modular-with-leaks.** Per Arbiter taxonomy:
- Sections A (hard constraints) → C (output schema) → F (flow templates) form a clean modular spine.
- BUT section B (per-turn protocol) is **monolithic**: B1 alone has 50+ lines of read-instructions with nested CRITICAL/MUST/Item-2/Item-4/Item-6 patches.
- §G is **informational dead-weight** that still ships in every turn's context.
- §H worked-example fixes one branch of the verdict table but not others.

Comparable to Claude Code v2.1.50 architecture (modular + patched). Not flat. Not cleanly monolithic.

### Estimated total interference count
- This audit surfaced **23 candidates** (10 HIGH, 10 MEDIUM, 3 LOW).
- Arbiter baseline (Claude Code v2.1.50): 21 hand-labeled contradictions.
- **director.md exceeds CC v2.1.50 baseline.** Not surprising given:
  - Three dangling citation stubs (L311, L413, L465) are unforced-error contradictions inside the file's own prose.
  - Recent append patches (B1.0, Item 2, Item 7, schema_version 2, F6) without re-numbering or anchor reflow.
  - Two separate self-review checklists (B27/§C.7 and B32/§E) that have not been reconciled.

### Recommendation
**Surgical patches + targeted rewrite of §B.** Specifically:

1. **Repair dangling citations** (L311, L413, L465) — 10 minutes, zero risk. Either fill the citations or delete the truncated `Per :` / `(D1/D2/D3, )` fragments.
2. **Add D4 axis or carve-outs in B7** for meta/audit — addresses P3 and unblocks scheduler-mandated work.
3. **Merge B27 and B32 self-review checklists** — single 12-item list; ~30 minutes.
4. **Add explicit precedence to B34 vs B25** — researcher_depth must respect quota window.
5. **Add artifact-first precondition gate to B18** — converts opening stage to Update when artifacts exist; resolves P1.
6. **Make §F template-aware verdict table (B21)** — separate Update/Revert routing per template family.
7. **Split B1 into ordered serial steps** — explicit "step 1: read scheduler, step 2: read artifacts if topic match, ..." rather than CRITICAL-FIRST + "Then (priority order)" ambiguity.
8. **Decide §G fate**: either delete it (informational dead-weight in every turn's context) or move it to a separate `.claude/agents/director_references.md` and reference it lazily.

Full rewrite is NOT warranted — the modular spine A/C/F is sound. The damage is concentrated in §B (patched 3+ times) and the unforced dangling-citation errors. Estimated 2-3 hours of surgical editing closes 18 of 23 findings.

**Leave-alone is unsafe.** The HIGH-severity contradictions P1, P3, P4 will fire predictably on the actual workload pattern (artifact-bearing topics + tier_target=3 + scheduled meta-audits). Loop will retry-hell or refuse turns.

────────────────────────────────────────────────

*Auditor's note: this audit is the Claude-only approximation of cross-vendor Arbiter. A true Arbiter run would feed the same prompt to a non-Claude model (Gemini 2.x or GPT-4-class) and merge the union of findings. The set of HIGH-severity contradictions above is expected to be stable across vendors because they are structural (anchor drift + missing precedence) rather than tone-dependent.*
