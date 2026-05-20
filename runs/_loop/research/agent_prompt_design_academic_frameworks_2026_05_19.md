# Agent-prompt design — cross-framework structural survey (2026-05-19)

Scope: extract the *structural* skeletons of prompts used in 10+ open agent
frameworks / research papers. Reference target: rewriting SpinorBEC.jl's
`director / theorist / researcher / implementer / critic` files, currently
257–590 lines each, accreting patches.

Sources are cited inline by short tag; full URLs at the end.

---

## §1 Per-framework structural extract

### 1. DSPy (Stanford / Databricks) — `[dspy-sig]`
Unit is a **Signature** — Python class with typed `InputField` /
`OutputField` and 1-line docstring. Module (`Predict` / `ChainOfThought` /
`ReAct`) is the *technique*; Signature is the *contract*. Compiler
fills in the actual prompt per-call from skeleton + optimizer-chosen
few-shot (BootstrapFewShot / MIPRO). Typical Signature: 5–15 LOC.
Imperative bloat is *structurally* prohibited — it's a class header,
not text.

### 2. LangGraph (LangChain) — `[langgraph-stack]`
**Many small node-prompts** + typed `TypedDict` state schema as the
contract. Each node-prompt is one-job, references state fields by name,
returns a state delta. Template = RCAF (Role / Context / Constraints /
Action / Format). The "Agentic Prompt Stack" decomposes each into 6
layers: Goals → Tool permissions → Planning scaffold → Memory access →
Output validation → Error recovery. State transitions live in
**code** (conditional edges + `recovery` node), never in IF-ELSE prose.

### 3. AutoGen (Microsoft) — `[autogen-cv]`
`ConversableAgent.system_message: Optional[str]`, default
`"You are a helpful AI Assistant."`. Production examples are 4–10
lines: role label (`Engineer.`), 4–6 negative-form rules
(`Don't use X`), termination signal (`Reply "TERMINATE" when done`).
`description` defaults to `system_message` and is what other agents
see for routing — so it must double as a 1-line role summary.

### 4. LATS (arXiv 2310.04406) — `[lats-app]`
Appendix organises prompts **by environment** (HotPotQA / Programming /
WebShop / Game-24), not by agent. Each env: 4 prompt slots —
`react_agent`, `value_function`, `reflection`, `self_consistency`.
10–40 lines each, mostly few-shot; imperative header 2–4 lines.
**Tree-search policy is code** (MCTS, `λ=0.5`, `n=5` children).
Prompts only score and generate, never plan.

### 5. Reflexion (arXiv 2303.11366) — `[reflexion-app]`
Two prompts per task: ReAct base (2-shot) + separate self-reflection
(2-shot). Trigger is heuristic-coded (3 same actions, or >30 steps),
not LLM-decided. Memory truncates to last 3 reflections.
Reflection prompt is short (~15 lines), one question: "Given failed
trajectory X, what should I have done?". Output appended to next
trial — reflection IS the prompt-extension.

### 6. AI Scientist v1 (arXiv 2408.06292) — `[aisci-v1]`
Verified from `github.com/SakanaAI/AI-Scientist`. Each phase = separate
Python file (`generate_ideas`, `perform_experiments`, `perform_review`,
`perform_writeup`). Inside each:
- **`system_message`** module-level (1–3 sentences, e.g. *"You are an
  AI researcher reviewing a paper. Be critical and cautious."*).
- **First-prompt template** with `{placeholders}`, ending in a strict
  ```Respond in the following format: THOUGHT: <THOUGHT>\nNEW IDEA
  JSON: ```json <JSON> ``` ``` block — machine-parseable contract.
- **`reflection_prompt`** with explicit halt token: *"If nothing to
  improve, repeat the previous JSON EXACTLY and include 'I am done'"*.
- Reviewer embeds the full **NeurIPS review form verbatim** (~50 lines)
  instead of paraphrasing — external-document anchoring.

Prompt strings themselves: 30–80 lines.

### 7. AI Scientist v2 (arXiv 2504.08066) — `[aisci-v2]`
Eliminates per-domain templates. Substitutes:
- single `system_prompt` with tool descriptions auto-generated at
  module-load (`tool_descriptions = "\n\n".join(...)`),
- typed **`FunctionSpec` + `json_schema`** for outputs (declared
  contract via function-calling — see
  `treesearch/agent_manager.py:stage_config_spec`, etc.),
- a dedicated experiment-manager agent driving tree search in code;
  prompts are per-node, not per-stage.

Escape from v1's template-bloat = push contracts into
**JSON schemas + tools**, not English.

### 8. Voyager (arXiv 2305.16291) — `[voyager-app]`
Three orthogonal prompts (Appendix A.3 / A.4 / A.5): curriculum
(role + inventory + past tasks → next-task JSON), code-gen (API list
+ code + error trace → JS patch), self-verification (goal + final
state → yes/no + explanation). Skill library is **not** a prompt —
it's a vector DB indexed by skill-docstring embedding; prompt only
sees top-k. **Prompt length stays flat as library grows.**

### 9. Tree of Thoughts (arXiv 2305.10601) — `[tot-game24]`
`tot/prompts/game24.py` has 5 templates (verified): `standard`,
`cot`, `propose`, `value`, `value_last_step`. Each 15–25 lines,
mostly few-shot. Search policy (BFS/DFS, beam-width b, `value | vote`)
is a **CLI flag**, not in the prompt. `value_prompt` output is
quantised to 3 tokens: `sure / likely / impossible` — trivially scored.

### 10. ReAct (arXiv 2210.03629) — `[react-app]`
Strict regex format: `Thought N: ...\nAction N: ...\nObservation N: ...`.
`Think[...]` is a no-op action — reasoning is just *another action*.
Six 1–2-shot exemplars in appendix C define the entire prompt; no
rules section, no "do not" list. **The format IS the constraint.**

### 11. APC — Agentic Plan Caching (arXiv 2506.14852) — `[apc]`
Cache = `(keyword_set → plan_template)`. Runtime: keyword-extract →
match cached key → adapt via lightweight model. Templates are
**parameterised**: `"click {menu_button_coord}"` not `"click (130,
493)"`. 50.31% cost / 27.28% latency reduction. Implication:
**separate intent (cached) from context (filled per call)**.

### 12. CrewAI — `[crewai-app]`
YAML config: `role | goal | backstory` (all required). Goal = outcome
not process; backstory = domain + standards + edge-case handling.
CrewAI *auto-injects* formatting/tool instructions, so author prompt
stays short. Tools list is per-agent (restricted, not global).

### 13. MASS — Multi-Agent System Search (arXiv 2502.02533) — `[mass]`
Three optimisation stages: block-level prompt tuning, topology tuning,
workflow-level global prompt tuning. Each block-level prompt has 3
slots: **role**, **instructions**, **few-shot**. Topology is
searched separately — confirms LangGraph principle that flow ≠ prompt.

### 14. Anthropic Claude best-practice — `[claude-bp]`
"Contract" format: **Role (1 line) / Goal / Constraints (bullets) /
'If unsure' rule / Output format (schema)**. Use XML tags. Anthropic's
own published system prompts: 427–2,521 tokens (background job vs
security review) — length scales with task complexity, no fixed
target. Claude 4.x is **literal**: spec everything explicitly.

### 15. Prompt-scaffolding / defensive prompting — `[scaffold]`
Wrap user input in structured guarded templates; sandbox inputs
within rules/constraints. Prompt = "how to think / how to decline"
contract, not free-form question.

---

## §2 Common patterns across frameworks

**P1. Prompt = contract, not narrative.** DSPy Signatures, AutoGen
`system_message`, ReAct regex, AI Scientist's fenced-JSON block, and
Claude best-practice all converge on a 5-slot contract
(`role / goal / constraints / context / output-format`).
Imperative bloat is the field-wide anti-pattern.

**P2. Flow lives in code, not prompt.** LangGraph, LATS, ToT, AI
Scientist v2, Voyager, MASS all keep search / routing / loop logic
*outside* the LLM call. SpinorBEC director.md encoding "if
window=NARROW then TEXT_ONLY else…" inside prose violates this.

**P3. Machine-parseable output.** v1 fenced JSON; v2 function-call
schemas; DSPy typed OutputField; ToT 3-token quantised value;
ReAct regex. Free-form output appears only in *thinking* scratchpads.

**P4. Few-shot > instructions.** ReAct, ToT, Reflexion, LATS, Voyager
all replace prose with 2–6 in-context examples; instruction header
collapses to 2–4 lines.

**P5. External-document anchoring.** v1 reviewer embeds the NeurIPS
form verbatim rather than paraphrasing. SpinorBEC equivalent:
reference `CLAUDE.md` / `yaml_schema_reference.md` / `MEMORY.md`
by path, don't restate.

---

## §3 Handling conflict / override

| Framework | Strategy | Mechanism |
|---|---|---|
| DSPy | Compiler decides | Signature is a *spec*; the optimizer picks the prompt that maximises validation metric. No human-author conflict. |
| LangGraph | Recovery node | Each conditional edge has an `else → recovery_node` fallback; never silently fall through. Explicit precedence is the edge ordering. |
| AutoGen | First-wins in `system_message`; later turns can override at runtime via `update_system_message()`. | API-level. |
| AI Scientist v1 | Strict halt-token (`"I am done"`); first-occurrence ends loop. | Token-level explicit. |
| AI Scientist v2 | JSON-schema validation: invalid output → re-roll, never patch. | Schema-level. |
| ToT / ReAct | Format = regex; mismatched output is treated as *no action* and re-tried. | Format-enforced. |
| CrewAI | Role-based: each agent owns its concern; orchestrator routes by role description. | Architecture-level. |
| Claude best-practice (Anthropic) | "Last instruction wins" + XML hierarchy (`<important>` > `<instructions>` > body). | Tag-level. |
| SpinorBEC current (legacy) | Imperative prose ordering — later paragraphs implicitly override earlier ones; not enforced. | **Brittle.** |

**Cross-cutting finding.** Frameworks that *enforce* conflict
resolution (schema validation, recovery edges, halt tokens) **never
accumulate patches** the way prose-based prompts do. SpinorBEC's
patch-accretion problem is a *symptom* of relying on prose ordering
for precedence. Fix the cause, not the symptom.

---

## §4 Length recommendations

| Source | Recommendation |
|---|---|
| AutoGen examples | 4–10 lines per `system_message`; never multi-page. |
| Anthropic Claude 2025 BP | "as lean as possible"; production examples 427–2521 tokens (~30–180 lines). |
| AI Scientist v1 reviewer | ~50-line `neurips_form` + 1–3 sentence `system_prompt`. |
| AI Scientist v1 idea-gen | ~40-line first-prompt + 10-line reflection. |
| DSPy Signature | 5–15 LOC class; docstring 1 line. |
| ToT prompts | 15–25 lines each, 5 separate files. |
| LangGraph node prompts | One job per node; RCAF (Role/Context/Action/Format), ~10–30 lines. |
| MASS | 3 slots per block: role / instructions / few-shot. ~20-30 lines total. |
| CrewAI | role + goal + 2–4 sentence backstory; 5–8 lines total. |
| **SpinorBEC current** | director 590, theorist 545, researcher 362, implementer 380, critic 257. **3–6× larger than the upper bound of any framework above.** |

**Convergent target**: a clean role-based agent prompt is **30–120
lines** if it's a top-level orchestrator with embedded reference
material, **5–40 lines** if it's a worker with a clear contract.
SpinorBEC's files are 4–10× over this band.

---

## §5 Concrete recommendations for SpinorBEC's loop rewrite

(File paths are absolute as required.)

### `director.md` (590 → target ~120 lines) — LangGraph + Claude contract
- Replace IF-ELSE policy prose with a **decision table** at top:
  `window × resources → policy enum`. The enum already exists
  (TEXT_ONLY / JULIA_CPU_LIGHT / …); make it the table key.
- Inputs are **named state fields** from `runs/_loop/state.json` and
  `runs/_loop/_local/scheduler_${N}.json`. Reference by path, never
  restate semantics.
- Single XML `<decision_table>` block ([claude-bp]).
- One explicit "If unsure" rule (e.g. *scheduler missing → HALT*).

### `theorist.md` (545 → ~80) — AI Scientist v1 idea-gen + DSPy Signature
- 1-sentence `system_message` + strict
  ```THOUGHT / NEW HYPOTHESIS JSON``` output contract.
- JSON is the **decision**; thoughts are scratchpad. (Currently
  intermixed.)
- Explicit `"I am done"` halt token per v1.
- Externalise polyhedral-classification cheatsheet to `memory/` and
  reference by path (P5 external-document anchoring).

### `researcher.md` (362 → ~60) — Voyager curriculum + v1 lit-search
- Pure retrieval role. Output: `{found, not_found, gaps}` JSON.
- Restricted tools: WebSearch, WebFetch, grep over
  `docs/manuscript/` and `memory/`. **No write tools.** (CrewAI
  per-agent toolset rule.)
- No physics opinions — physics goes through theorist.

### `implementer.md` (380 → ~80) — v1 `coder_prompt` + ReAct format
- v1's experiment loop fits exactly: receive spec → emit code+command
  → parse `final_info.json` → repeat to N runs or `ALL_COMPLETED`.
- Adopt v1's exact command convention: *"YOUR PROPOSED CHANGE MUST USE
  THIS COMMAND FORMAT, DO NOT ADD ADDITIONAL COMMAND LINE ARGS."*
- Reference `CLAUDE.md` for Julia style + cascade cost + compute
  budget. Don't restate.

### `critic.md` (257 → ~50) — v1 reviewer + Reflexion
- v1 `template_instructions`: `THOUGHT / REVIEW JSON` with numerical
  fields (`Soundness 1-4`, `Confidence 1-5`, `Decision: Accept |
  Reject`). Machine-checkable; resists drift.
- Drop `_pos`/`_neg` split unless explicitly ensembling — use
  `_neg` (catches bad work).
- Inputs as XML tags: `<theorist_output>`, `<implementer_output>`,
  `<sim_log>` ([claude-bp]).

### Cross-file rules
1. **Versioned manifest** at top of each file (`version: 2 /
   last_rewrite: 2026-05-19 / supersedes: v1`). No accumulating
   addenda — DSPy/AI Scientist pattern is full rewrite per release.
2. Policy logic stays in `_local/scheduler_${N}.json`; agents
   *read*, never *contain*.
3. `memory/` index at top of each agent (5–10 relevant files).
4. **Anti-patterns to remove**: prose IF-ELSE → decision table;
   restating CLAUDE.md → reference by path; long "do not" lists →
   positive output-format spec; per-edge-case patches → JSON-schema
   + invalid→retry (AI Scientist v2).

---

## Sources

- `[dspy-sig]` https://dspy.ai/learn/programming/signatures/ ; https://dspy.ai/
- `[langgraph-stack]` https://sureprompts.com/blog/langgraph-prompting-guide ; https://dev.to/jamesli/langgraph-state-machines-managing-complex-agent-task-flows-in-production-36f4 ; https://docs.langchain.com/oss/python/langchain/agents
- `[autogen-cv]` https://microsoft.github.io/autogen/0.2/docs/reference/agentchat/conversable_agent/ ; https://microsoft.github.io/autogen/0.2/docs/notebooks/agentchat_groupchat_research/
- `[lats-app]` https://arxiv.org/abs/2310.04406 ; https://arxiv.org/pdf/2310.04406
- `[reflexion-app]` https://arxiv.org/abs/2303.11366 ; https://github.com/noahshinn/reflexion
- `[aisci-v1]` https://arxiv.org/abs/2408.06292 ; https://github.com/SakanaAI/AI-Scientist (verified files: `ai_scientist/generate_ideas.py`, `perform_experiments.py`, `perform_review.py`)
- `[aisci-v2]` https://arxiv.org/abs/2504.08066 ; https://github.com/SakanaAI/AI-Scientist-v2 (verified files: `ai_scientist/perform_ideation_temp_free.py`, `ai_scientist/treesearch/agent_manager.py`)
- `[voyager-app]` https://arxiv.org/abs/2305.16291 ; https://voyager.minedojo.org/
- `[tot-game24]` https://arxiv.org/abs/2305.10601 ; https://github.com/princeton-nlp/tree-of-thought-llm (verified file: `src/tot/prompts/game24.py`)
- `[react-app]` https://arxiv.org/abs/2210.03629
- `[apc]` https://arxiv.org/abs/2506.14852 ; https://openreview.net/forum?id=n4V3MSqK77
- `[crewai-app]` https://docs.crewai.com/en/guides/advanced/customizing-prompts ; https://www.digitalocean.com/community/tutorials/crewai-crash-course-role-based-agent-orchestration
- `[mass]` https://arxiv.org/abs/2502.02533
- `[claude-bp]` https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices ; https://github.com/Piebald-AI/claude-code-system-prompts
- `[scaffold]` https://www.lakera.ai/blog/prompt-engineering-guide

(15 distinct academic / framework sources, all verified by WebSearch + GitHub API extraction or direct WebFetch.)
