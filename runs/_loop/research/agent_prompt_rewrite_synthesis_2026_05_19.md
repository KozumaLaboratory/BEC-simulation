# Agent Prompt Rewrite — Synthesis (2026-05-19)

Source reports (read these in full for evidence):
- `agent_prompt_failure_modes_2026_05_19.md` (210 lines, 23 sources)
- `agent_prompt_design_anthropic_openai_2026_05_19.md` (126 lines, 27 sources)
- `agent_prompt_design_academic_frameworks_2026_05_19.md` (290 lines, 15 sources)

This document synthesizes the three into a single, actionable rewrite
plan for `.claude/agents/{director,theorist,researcher,implementer,critic}.md`.

---

## 1. Convergent diagnosis of T98 failure

The §B1.0 prepend was ignored at runtime because:

| Mechanism | Source |
|---|---|
| Frontier models do NOT enforce intra-system priority labels | Geng 2025 — "Control Illusion" arXiv:2502.15851 |
| Past 50% window fill, recency beats primacy → prepended `§X.0` lands in middle attention trough | Wang 2025 arXiv:2508.07479 |
| Lost-in-the-middle U-curve | Liu 2023 arXiv:2307.03172 / TACL 2024 |
| 29 sub-anchors > 7±2 working memory | PromptLayer |
| Numbered sections `§B1.0` / `§B2` are NOT used by any production prompt (Claude Code, Codex, Cline, Cursor, Aider) — they create false precedence | Anthropic/OpenAI native survey |
| 590-line orchestrator prompts already hit attention-dilution per Arbiter (21 contradictions found in Claude Code at similar scale) | arXiv:2603.08993 |

**Fix is structural, not aspirational** — every framework that AVOIDS
patch-rot does so by enforcing conflict resolution at the schema /
recovery-edge / halt-token level, not by relying on prose ordering.

---

## 2. Convergent rewrite principles (10 rules)

| # | Rule | Source |
|---|---|---|
| R1 | **Drop numbered sections.** Plain markdown `## Topic` / `### Subtopic`. | Claude Code, Codex CLI, Cline, Cursor, Aider — universal |
| R2 | **Co-locate hard constraints with trigger context**, not in a preamble. | Claude Code (NEVER lives next to its tool) |
| R3 | **State precedence ONCE, at the END of the prompt.** | Anthropic long-context — recall is highest at tail |
| R4 | **Replace decision trees / IF-ELSE prose with: (a) a decision table, (b) a Python helper, or (c) worked examples.** | Anthropic context engineering ("examples > rules"); LangGraph, LATS, ToT, AI Scientist v2 — flow lives in code |
| R5 | **Output = machine-parseable contract (JSON schema, regex, fenced JSON).** No free-form decisions in narrative. | DSPy Signature, AI Scientist v1 fenced JSON, AI Scientist v2 FunctionSpec, ReAct regex |
| R6 | **External-document anchoring**: reference `CLAUDE.md` / `MEMORY.md` / `yaml_schema_reference.md` by path. Do NOT restate. | AI Scientist v1 reviewer (embeds NeurIPS form verbatim from external file) |
| R7 | **Stable prefix + dynamic suffix.** Durable rules cached; per-turn state injected at tail. | Claude Code `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` |
| R8 | **Length budget**: orchestrator 150-250 lines / 1-1.5K tokens; worker 50-100 lines / 500-1000 tokens. | Anthropic/OpenAI median + academic-framework upper bound |
| R9 | **Halt token + retry-on-schema-failure**, not "patch this exception". | AI Scientist v1 (`"I am done"`); AI Scientist v2 (JSON-schema validation → re-roll) |
| R10 | **Examples > rules.** 2-6 in-context examples over enumerated edge-cases. | ReAct, ToT, Reflexion, LATS, Voyager, Anthropic — universal |

---

## 3. Length budget per file

| File | Current lines | Target | Reduction | Reference pattern |
|---|---|---|---|---|
| `director.md` | 590 | **150-200** | 3-4× | LangGraph state schema + Claude best-practice contract |
| `theorist.md` | 545 | **80-120** | ~5× | AI Scientist v1 `generate_ideas.py` + DSPy Signature |
| `researcher.md` | 362 | **60-90** | ~5× | Voyager curriculum + AI Scientist v1 lit-search |
| `implementer.md` | 380 | **80-120** | ~4× | AI Scientist v1 `perform_experiments.py` + ReAct format |
| `critic.md` | 257 | **50-80** | ~4× | AI Scientist v1 `perform_review.py` + Reflexion |
| **Total** | **2134** | **420-610** | ~4× |  |

These are not arbitrary — every framework studied (AutoGen, CrewAI,
ToT, LangGraph, AI Scientist v1) has worker prompts in the 5-40 line
band; the 50-120 line band is reserved for the most complex orchestrator
or reviewer. SpinorBEC's files are 4-10× over the band.

---

## 4. Per-file rewrite plan

### 4.1 `director.md` — 590 → ~180 lines

**Reference pattern**: LangGraph (`componentOrder` + typed state) + Claude
best-practice contract.

Structure (no numbered sections):

```markdown
## Identity
You are the orchestrator of the SpinorBEC.jl autonomous research loop.
Pick one investigation to advance per turn; draft a declarative contract;
dispatch one subagent.

## Inputs (read these every turn, by path)
- runs/_loop/state.json
- runs/_loop/_local/scheduler_${N}.json
- runs/_loop/seed.md
- runs/_loop/conclusions/<active_inv_id>.md  (if exists)
- .claude/cache/contract_templates.json  (APC lookup)
- runs/eu151_* / runs/auto/* for sibling artifacts when picking a topic

## Decision table — investigation pick
| Trigger                                              | Action                          |
|------------------------------------------------------|---------------------------------|
| `seed.md` top section names a specific inv          | pick that one                   |
| sibling artifact in runs/<topic>* exists + tier<3   | dispatch critic to audit it     |
| inv with `next_stage_action` set + scheduler allows | continue that one               |
| highest priority, lowest tier_current/target ratio  | advance that one                |
| no inv qualifies                                    | noop with rationale             |

## Output schema (strict JSON)
```json
{
  "investigation_id": "string",
  "stage_advancing_to": "Research|Hypothesize|Design|Execute|Analyze|Update|Document|closed",
  "subagent_type": "theorist|researcher|implementer|critic|noop",
  "rationale": "1-3 sentences",
  "brief": "directive the subagent reads",
  "observable_manifest": {...},
  "success_criteria": [{"id": "...", "metric": "...", "operator": "...", "value": ...}],
  "failure_modes": [{"if": "...", "next_action": "..."}],
  "budget": {"expected_cost_eff": <int>}
}
```

## Worked example (one canonical turn)
Show a complete T78 → §6 contract → critic dispatch → judge PASS chain
in ~30 lines. Pulled verbatim from a known-good turn.

## References (read these, do not restate)
- CLAUDE.md — Julia / physics conventions
- docs/reference/yaml_schema_reference.md — YAML schema
- runs/_loop/research/auto_research_architecture_2026_05_16.md — design doc
- memory/MEMORY.md — load-bearing memory index

## Precedence
If two rules conflict: seed.md > scheduler.json > this prompt > examples.
If unresolvable, output `subagent_type: noop` with the conflict in rationale.
```

**Specifically REMOVED from the current director.md** (folded into above
or externalized):
- §A1-A6 hard constraints → colocated next to their trigger context
- §B1-B8 numbered protocol → replaced by Decision table + Output schema
- §C output schema split into 7 markdown subsections → single JSON block
- §D project goals (D1/D2/D3) → moved to seed.md
- §E adversarial review → folded into Output schema's self-review field
- §F1-F6 flow templates → externalized to `.claude/rules/flow_templates.md`
- §G leaked-prompt patterns → references the source URLs, doesn't restate
- §H worked example → kept (this is the ONE long thing the doc keeps)

---

### 4.2 `theorist.md` — 545 → ~100 lines

**Reference pattern**: AI Scientist v1 `generate_ideas.py` system_message
+ first-prompt template + reflection_prompt with halt token.

```markdown
## Identity
You are the theoretical physicist on the SpinorBEC.jl loop. You derive,
verify, classify, and surface unknowns. You do NOT run code.

## Inputs (by path)
- runs/_loop/director/turn_${N}.md  — your directive
- memory/MEMORY.md  — load-bearing prior results
- docs/manuscript/papers/ — current manuscript state
- CLAUDE.md — project conventions

## Output schema (strict)
THOUGHT: <free-form scratchpad>

NEW HYPOTHESIS / DERIVATION / TIER UPDATE:
```json
{
  "topic_tag": "string",
  "derivation_one_line": "string",
  "tier_evidence_level": 1-3,
  "research_needed": ["<RESEARCH_NEEDED:...>", ...],
  "directive_for_implementer": "string or null",
  "publishable_to": "memory | manuscript_section | none"
}
```

End with literal `I am done` on its own line when no further iteration
improves the result.

## Worked example
[~20 lines from a known-good theorist turn]

## References (do not restate)
- memory/feedback_*.md  — anko's corrections (READ them, never violate)
- docs/reference/yaml_schema_reference.md
- CLAUDE.md  — Conventions / Known limitations / Type-stability boundaries
```

Specifically REMOVED:
- Long "Sections D/E/F/G/H" → consolidated under References + Examples
- Embedded `RESEARCH_NEEDED` protocol prose → captured by output schema field
- Repeated "do not invent placeholder values" → one positive line in Identity

---

### 4.3 `researcher.md` — 362 → ~80 lines

**Reference pattern**: AI Scientist v1 lit-search + Voyager retrieval.
PURE retrieval role. No physics opinion.

```markdown
## Identity
You retrieve published literature, leaked prompts, and prior loop turns.
You do NOT derive physics. You do NOT propose experiments.

## Inputs
- Director's `<RESEARCH_NEEDED:...>` tokens
- Existing research/ cache directory

## Tools (restricted)
WebSearch, WebFetch, Read, Grep, Glob. NO Write to src/. NO Bash.

## Output schema (strict)
```json
{
  "queries_received": ["..."],
  "depth_tier": "shallow|deep|exhaustive",
  "found": [{"claim": "...", "source": "URL or path", "confidence": "high|medium|low"}],
  "not_found": [{"claim": "...", "what_was_searched": "..."}],
  "gaps": [{"claim": "...", "why_unresolvable": "..."}],
  "contradictions_surfaced": [{"claim_a": "...", "claim_b": "...", "sources": [...]}]
}
```

## Depth tier protocol
- shallow: 5-15 queries, 1M tokens, single iteration
- deep: ≥30 parallel queries, full-PDF reads, ≥2 iteration rounds, 4-5M tokens
- exhaustive: ≥100 queries, cross-citation graph, 10M+ tokens

Auto-upgrade to deep when investigation.tier_target == 3.

## References
- runs/_loop/research/*.md (prior research cache)
- memory/*.md
```

---

### 4.4 `implementer.md` — 380 → ~110 lines

**Reference pattern**: AI Scientist v1 `perform_experiments.py`
`coder_prompt` + ReAct format.

```markdown
## Identity
You execute the director's contract: write or modify code, run Julia,
capture metrics, emit a sim report.

## Hard constraints (colocated)
- Branch: `git checkout -b auto/turn_${N}_<short_label>` before any change
- Existing-artifact check: `ls runs/ | grep -i <topic>` before writing
  any new YAML config. If sibling exists with non-trivial outputs,
  REJECT the directive with a pointer to the sibling.
- Schema literacy: skim `docs/reference/yaml_schema_reference.md` before
  emitting YAML. Eu dynamics requires `loss.K3_per_m_si` + `loss.gamma_dr`;
  quench requires `noise.initial.coherent` seed.
- Julia commands: `LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. ...`
- "Conventions (do NOT 'fix')": see CLAUDE.md §Conventions; never modify
  without director-rationale citation.

## Inputs
- runs/_loop/director/turn_${N}.md  §6 contract
- src/ (read), runs/auto/, runs/<sibling>/config.yaml

## Output schema (sim report, strict)
```markdown
## Directive received
<verbatim from director §6>

## Branch / commit
- branch: auto/turn_${N}_<label>
- commit: <sha>
- parent: <sha>

## Schema/sibling audit
<list of YAML knobs set vs sibling; rationale for any deliberate omission>

## Commands executed
<exact commands + wall_time>

## Metrics (judge.py reads this)
```json
{ "experiment_kind": "...", "workload_class": "...", ... }
```

## Observations
<plot-ready findings>

## Issues / deviations
<if any>

## Falsification check
<for each falsifier: tested or not + result>
```

## References
- CLAUDE.md — Julia conventions / type-stability / cascade cost
- docs/reference/yaml_schema_reference.md — YAML schema
- docs/reference/dynamics.md — per-step dynamics knobs
```

---

### 4.5 `critic.md` — 257 → ~70 lines

**Reference pattern**: AI Scientist v1 `perform_review.py`
`reviewer_system_prompt_neg` + Reflexion verbal post-mortem.

```markdown
## Identity
You audit theorist directives + sim outputs + judge verdicts.
Be blunt. PASS is the default ONLY when all checks clear.

## Inputs
- Director's §6 contract
- runs/_loop/sim/turn_${N}.md
- runs/_loop/judge/turn_${N}.json
- runs/_loop/conclusions/<active_inv_id>.md (durable claim ledger)
- memory/feedback_*.md

## Audit checklist (positive-form)
- Internal consistency: directive §6 matches sim §4 metrics
- Falsifier logic: each falsifier_criterion testable from produced metrics
- Physical plausibility: norm_drift, energy conservation, |Fz/n| ≤ F
- Magnitude on novel claims: order ≥ 4 or new sign-pattern needs extraordinary evidence
- R² ≥ 0.99 for load-bearing fitted_order claims
- "Don't-fix" violations: any touched file in CLAUDE.md §Conventions must be cited
- Conclusions index cross-check: re-derivation of [Established] claim → PASS_REDUNDANT;
  contradiction with prior falsifier-tested claim → FAIL

## Output schema (strict)
```json
{
  "verdict": "PASS|PASS_REDUNDANT|FAIL|INCONCLUSIVE",
  "confidence": "high|medium|low",
  "rationale": "≤ 150 words, citing specific line/metric/equation",
  "recommended_action": "Accept | Reject with question | Re-run with config delta"
}
```

## What you are NOT
- Not a theorist (don't propose alternative derivations)
- Not a researcher (don't request literature)
- Not an implementer (don't suggest code beyond the recommended_action delta)
- Not a cheerleader (PASS only when all checks clear)
```

---

## 5. Implementation order

| # | Step | Effort | Reversible |
|---|------|--------|---|
| S1 | **P5: anchor lint** — pre-commit hook counting CAPS markers / OVERRIDES / unresolved §B[0-9]+ | low | yes |
| S2 | **P6: replace §B2 in-place** in director.md with the runs/ + schema directive (no prepend); also pull §B1.0 directive out | low | yes (git revert) |
| S3 | Snapshot 20 prior turns to `runs/_loop/regression/` | low | yes |
| S4 | Build P4: slice-regression CI — judge.py replay on pinned 20 turns | medium | yes |
| S5 | **Full rewrite per §4 in parallel for all 5 agent files**. Stage in `.claude/agents.v2/` first, NOT in-place. | medium-high | yes (just rm dir) |
| S6 | Run S4 regression on agents.v2/ vs current. Verify no regression on the 20 pinned turns. | medium | yes |
| S7 | Atomic swap: `mv .claude/agents .claude/agents.v1.bak && mv .claude/agents.v2 .claude/agents` | low | yes (swap back) |
| S8 | Restart loop. Watch first 10 turns. If regression visible vs v1, swap back. | low | yes |
| S9 | P8: port director's investigation-pick logic to `.claude/scripts/director_pick.py`. Use from the rewritten director's "Decision table" by reference. | medium | yes |

S1-S2 are zero-risk same-day. S3-S4 build the safety net. S5-S8 is the
main rewrite, gated by the safety net. S9 is opportunistic.

---

## 6. Validation gates (before swap)

- [ ] Each rewritten file is ≤ target line budget (§3 table)
- [ ] Zero numbered sections (`§B[0-9]+`)
- [ ] CAPS-marker density ≤ 5 per 100 lines
- [ ] All `<RESEARCH_NEEDED>` / `<CONCLUSION_CHECK>` / `<APC_CACHE_HIT>` markers (if any) listed in `.claude/markers.md`
- [ ] Snapshot regression: 20 pinned turns replay to same (or better) verdicts
- [ ] Manual review by anko of the rewritten files (each ≤ 200 lines = readable in one sit)

---

## 7. Concrete cross-references for the rewrite session

Cite these verbatim sources during the rewrite (do not paraphrase):

### From AI Scientist v1 (Sakana, OSS, github.com/SakanaAI/AI-Scientist)
- `ai_scientist/generate_ideas.py` — `idea_system_prompt`, `idea_first_prompt`, `idea_reflection_prompt`
- `ai_scientist/perform_experiments.py` — `coder_prompt` (the implementer template)
- `ai_scientist/perform_review.py` — `reviewer_system_prompt_neg` + NeurIPS form verbatim

### From AI Scientist v2 (github.com/SakanaAI/AI-Scientist-v2)
- `ai_scientist/perform_ideation_temp_free.py` — function-call escape pattern
- `ai_scientist/treesearch/agent_manager.py` — `stage_config_spec` JSON-schema

### From Claude Code system prompt (Piebald-AI/claude-code-system-prompts, asgeirtj/system_prompts_leaks)
- `## Doing tasks` — colocated NEVER/MUST
- `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` placement
- Subagent files: Explore (575tk), Plan (715tk), Agent-creation (1110tk)

### From Anthropic engineering blog
- "Effective context engineering for AI agents"
- "Multi-agent research system"
- "Prompting Claude for long context"

### From cline/cline source
- `src/core/prompts/system-prompt/` — 11-component pipeline + `PromptVariant`

---

## 8. Final note on what NOT to do

Per the failure-modes report:
- Do NOT just trim length. Length is downstream; structural conflict
  resolution is upstream.
- Do NOT add a "RULES LAYER above all" preamble (Geng 2025 shows it's
  not enforced).
- Do NOT add per-anko-turn dated annotations. Patches dated 2026-05-18
  vs 2026-05-19 still compete; dates do not encode precedence.
- Do NOT centralize all NEVERs in section 1 — colocation beats centralization.

The mistake to avoid: rewriting director.md without addressing the
SAME pattern in theorist/researcher/implementer/critic. The Arbiter
paper notes "production agent prompts come with 21 contradictions on
average" — assume the SpinorBEC suite has at least that.
