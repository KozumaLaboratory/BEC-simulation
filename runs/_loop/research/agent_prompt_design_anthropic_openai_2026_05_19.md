# Agent Prompt Design: Anthropic & OpenAI Native Structures

Research date: 2026-05-19. Scope: structural patterns of production agent system prompts (Anthropic, OpenAI, Cursor, Cline, Aider, Codex CLI) as documented or leaked in 2025-2026.

## §1 Key findings

- **Production agent prompts are not monolithic; they are conditionally assembled component graphs.** Claude Code does not ship a single static string — its system prompt is built from "110+ separate instructions, conditionally assembled based on your configuration", with sections like `Intro / System Rules / Doing Tasks / Executing Actions with Care / Using Your Tools / Tone / Output Efficiency` and a `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` cache marker separating stable from session-specific content. [dbreunig](https://www.dbreunig.com/2026/04/04/how-claude-code-builds-a-system-prompt.html), [claudecodecamp](https://www.claudecodecamp.com/p/inside-claude-code-s-system-prompt).
- **The empirical "sweet spot" for an orchestrator core prompt (excluding tool schemas) is ~2.3-3.6K tokens.** Claude Code's base system prompt sits at 2,300-3,600 tokens; conditional sections add 0-1,300 tokens; tool definitions push the assembled total to ~16-25K. The recent Claude Code v2.1.96 regression that ballooned the system prompt by ~70K tokens "made sessions effectively unusable", confirming a hard upper limit. [claudecodecamp](https://www.claudecodecamp.com/p/inside-claude-code-s-system-prompt), [claude-code#45188](https://github.com/anthropics/claude-code/issues/45188).
- **Claude Code, Codex CLI, and Cline all use markdown headers (`##` / `###`), NOT numbered sections** (no `§1.0 §2.3.1` schemes). The Claude Code prompt is "exclusively markdown headers ... scannable, hierarchical nesting without enumeration"; Cline assembles 11 ordered components (`Agent Role → Tool Use → MCP → Editing Files → Act vs Plan → Todo → Capabilities → Rules → System Info → Objective → User Instructions`) without numeric prefixes. [asgeirtj/system_prompts_leaks](https://github.com/asgeirtj/system_prompts_leaks/blob/main/Anthropic/claude-code.md), [cline/cline source](https://github.com/cline/cline/tree/main/src/core/prompts/system-prompt).
- **Hard constraints (MUST / NEVER) are scattered next to the relevant topic, not centralized in a preamble.** In Claude Code, "NEVER skip hooks" lives inside the git-operations subsection; "NEVER guess names" lives inside the Skill tool section. Section-local placement keeps the constraint near its trigger context. [asgeirtj/system_prompts_leaks](https://github.com/asgeirtj/system_prompts_leaks/blob/main/Anthropic/claude-code.md).
- **Long monolithic prompts with overlapping rules empirically degrade reasoning.** The STAR reasoning framework scored 85-100 % standalone but collapsed to 0-30 % when embedded in a 60+ line evolved system prompt; Anthropic explicitly frames this as a finite "attention budget" with n² pairwise interactions. [arxiv 2603.13351](https://arxiv.org/html/2603.13351v1), [Anthropic context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents).
- **Auditing leaked prompts of 3 production agents (Claude Code, Codex CLI, Gemini CLI) found 152 unflagged interference patterns and 21 hand-labeled contradictions** — exactly the failure mode anko's director.md is showing. The Arbiter paper notes these prompts are "software artifacts that govern agent behavior, yet lack the testing infrastructure applied to conventional software". [arxiv 2603.08993](https://arxiv.org/pdf/2603.08993).
- **The dominant fix for instruction drift is active-generation scaffolding, not prompt repetition.** A 300-token "SCAN markers + answer your own markers" pattern beat prompt-repeat (~2 K tokens / cycle) on long-session adherence: "without SCAN, agents reliably lose critical rules by mid-session". [dev.to nikolasi](https://dev.to/nikolasi/solving-agent-system-prompt-drift-in-long-sessions-a-300-token-fix-1akh).
- **Anthropic's official guidance: avoid embedded decision trees; use clear instructions + examples and let the model judge.** "Examples are the 'pictures' worth a thousand words"; brittle hardcoded logic creates fragility and maintenance complexity. [Anthropic context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents).
- **Critical instructions belong at the END of long prompts** (Anthropic empirical finding). For long contexts, recall of instructions placed at the prompt's tail is highest; middle-position content lives in the attention trough. [Anthropic long-context prompting](https://www.anthropic.com/news/prompting-long-context).

## §2 Structural patterns observed

### Pattern A — Claude Code's assembled-component model

Shape (markdown headers only, no enumeration):
```
## Identity & Security             (~100 tk)   always
## Task Execution / Doing Tasks    (~600 tk)   conditional
## Executing Actions with Care     (~540 tk)   always   [hard constraints sit here]
## Tool Usage Policy               (~550 tk)   conditional
## Output & Tone                   (~320 tk)   always
## [Session-specific guidance]     (0-1300 tk) per-mode conditional
## Memory                          (~200 tk)   conditional
## Environment                     (~15 tk)    always
## Tools (Read, Edit, Bash, ...)   (~14-25 K)  schema definitions
```
Key features: (a) constraints live inside the topic-local section that triggers them, (b) the `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` cache split separates immutable assembly from per-session injection, (c) sub-agent prompts (Explore: 575 tk, Plan: 715 tk, Agent-creation: 1,110 tk) are SEPARATE files invoked via the Agent tool, not embedded into the orchestrator prompt. [Piebald-AI/claude-code-system-prompts](https://github.com/Piebald-AI/claude-code-system-prompts), [dbreunig](https://www.dbreunig.com/2026/04/04/how-claude-code-builds-a-system-prompt.html).

### Pattern B — OpenAI Codex CLI's role-stratified injection

Codex CLI does not write one big "you are X" prompt; it stratifies by message role: `system → developer → user → assistant`, in decreasing priority. AGENTS.md files are walked from repo-root down to CWD, each merged in as its OWN user-role message (`# AGENTS.md instructions for <dir>`). Later directories override earlier. Hard cap 32 KiB. [OpenAI Codex docs](https://developers.openai.com/codex/guides/agents-md), [OpenAI agent loop](https://openai.com/index/unrolling-the-codex-agent-loop/).

### Pattern C — Cline's ordered component variants

Cline ships a `PromptVariant` interface with `componentOrder` and per-variant `componentOverrides`. The default order is the 11-section pipeline (Agent Role → ... → User Instructions). The Act vs Plan section sits BEFORE Tools, so plan-mode constraints are read before tool definitions. Different model families (`generic`, `next-gen`, `xs`) can reorder or replace components. [cline/cline source](https://github.com/cline/cline/tree/main/src/core/prompts/system-prompt), [cline blog](https://cline.bot/blog/system-prompt-advanced).

### Pattern D — Anthropic's multi-agent orchestrator delegation

Each sub-task delegated by the lead agent receives 4 fields: **objective + output format + tool/source guidance + clear task boundaries**. Effort is scaled explicitly: "Simple fact-finding: 1 agent with 3-10 tool calls / Direct comparisons: 2-4 subagents with 10-15 calls / Complex research: 10+ subagents". Sub-agents return condensed summaries to a shared memory store, not raw chat history. [Anthropic multi-agent](https://www.anthropic.com/engineering/multi-agent-research-system).

### Pattern E — Claude 4 system prompt (consumer chat)

Mixes prose narrative (identity, personality, safety) for the first ~third with XML-tagged structured blocks for the rest (`<thinking_mode>`, `<mandatory_copyright_requirements>`, `<styles_info>`). Tool descriptions are entirely OUT of the published prompt — they live in a separate ~6,471-token search-instructions module. [simonwillison.net](https://simonwillison.net/2025/May/25/claude-4-system-prompt/).

## §3 Length norms

Numbers extracted across sources, normalized to "orchestrator-class core prompt", i.e. excluding tool schemas and CLAUDE.md / AGENTS.md user content:

| Source                          | Core prompt    | Tools + assembled | Notes |
|---------------------------------|----------------|-------------------|-------|
| Claude Code base                | 2,300-3,600 tk | 16-25 K           | 27 K with global CLAUDE.md added |
| Claude Code subagent (Explore)  | 575 tk         | —                 | leaf agent |
| Claude Code subagent (Plan-enhanced) | 715 tk    | —                 | |
| Claude Code subagent (Agent-creation architect) | 1,110 tk | —      | the most complex sub |
| Claude Code Learning mode       | 1,042 tk       | —                 | conditional |
| AGENTS.md (Codex CLI cap)       | —              | 32 KiB hard cap   | enforced by `project_doc_max_bytes` |
| Claude 4 search-instructions    | 6,471 tk       | —                 | OUT of base prompt |

**Empirical median for an orchestrator core prompt: ~600-1,200 tokens (~80-200 lines markdown).** Above ~3 K tokens of core instructions, Anthropic and field reports show attention dilution; Claude Code's regression at +70 K tokens is the documented upper bound where sessions become unusable. [claudecodecamp](https://www.claudecodecamp.com/p/inside-claude-code-s-system-prompt), [claude-code#45188](https://github.com/anthropics/claude-code/issues/45188).

For anko's director.md context: **590 lines / 15 sections / 29 anchors is already above the field's empirical sweet-spot ceiling**. Sub-agent prompts in production stay under ~1,200 tokens (~150-200 lines) each.

## §4 Anti-patterns documented

1. **Contradictory directives across sections.** "Always use TodoWrite" in one section and "NEVER use TodoWrite" in another. Found across Claude Code, Codex CLI, Gemini CLI (21 hand-labeled contradictions). [arxiv 2603.08993](https://arxiv.org/pdf/2603.08993).
2. **Unordered precedence.** No explicit "if rules conflict, X wins". Models default to earlier instructions (recency-anti-bias when the prompt is the system role), but later context-window tokens win in conversation. Predictable failure when authors don't specify which. [arxiv 2603.08993](https://arxiv.org/pdf/2603.08993), [arxiv 2502.12197](https://arxiv.org/pdf/2502.12197).
3. **Patch-rot / instruction accumulation.** "Real-world system prompts often contain ... an average of 5.1 guardrails per prompt" and incrementally added ones interfere with original ones (STAR went 85%→0-30%). [arxiv 2502.12197](https://arxiv.org/pdf/2502.12197), [arxiv 2603.13351](https://arxiv.org/html/2603.13351v1).
4. **Embedded decision trees that should be workflow code.** "Decision tree can become a maintenance nightmare — nested conditionals everywhere". Production guidance: keep behavioral rules / heuristics IN the prompt; push deterministic routing OUT to a workflow graph. [softcery](https://softcery.com/lab/the-ai-agent-prompt-engineering-trap-diminishing-returns-and-real-solutions), [aiyan](https://www.aiyan.io/blog/engineer-agent-reliability/).
5. **Negative-only framing.** Stacked "don't do X" clauses create ambiguity through accumulated exceptions; positive directives outperform negative ones for adherence. [agentwiki](https://agentwiki.org/how_to_structure_system_prompts), [arxiv 2603.08993](https://arxiv.org/pdf/2603.08993).
6. **Drift from system prompt over long sessions.** "1,000 prompt tokens out of 80,000 total = ~1% attention". Passive re-reading of the prompt does NOT fix this; active generation (SCAN-marker style) does. [dev.to nikolasi](https://dev.to/nikolasi/solving-agent-system-prompt-drift-in-long-sessions-a-300-token-fix-1akh), [arxiv 2510.07777](https://arxiv.org/pdf/2510.07777).
7. **Middle-of-prompt critical rules.** U-shaped attention curve / lost-in-the-middle: rules buried in section 7 of 15 get lost. Anthropic explicitly recommends instructions at prompt END. [Anthropic long-context](https://www.anthropic.com/news/prompting-long-context).
8. **Closures / dynamic logic embedded in prompts.** Cursor v2 "meaningful rewrite, not just incremental tuning ... usually signals a core UX problem they were trying to fix" — symptom of accumulated incremental patches. [augmentcode](https://www.augmentcode.com/learn/leaked-ai-system-prompts-github).

## §5 Recommendations for director.md rewrite

Empirical guidance only, no implementation:

1. **Target ~150-250 lines / ~1,000-1,500 tokens for the orchestrator core.** Anything that grows beyond ~300 lines should be split into a sub-agent file invoked by reference, mirroring Claude Code's Explore/Plan/Agent-creation pattern. The current 590-line director.md is roughly 2× the empirical ceiling.
2. **Drop numbered sections (§B1.0, §B2.1, etc.) in favor of plain markdown headers** (`## Topic`, `### Subtopic`). Every leaked production prompt (Claude Code, Codex, Cline, Aider, Cursor) avoids numeric enumeration. The numbers create false precedence and invite the exact "§B1.0 override gets ignored in favor of older §B2" failure that triggered this research.
3. **Co-locate hard constraints with their trigger context, not in a top-level preamble.** Put "must read scheduler before julia" inside the Scheduler section, not in §B1. This matches Claude Code's NEVER/MUST placement (git-related NEVERs inside git section, tool-related NEVERs inside tool section).
4. **State precedence ONCE, at the end of the prompt.** Per Anthropic's long-context finding, final-position recall is highest. A single closing block "If rules conflict: scheduler > seed.md > legacy patterns; halt and ask if unresolvable" is more reliable than scattered precedence claims.
5. **Replace embedded decision trees with example-driven heuristics.** Anthropic's explicit guidance: "examples are the 'pictures' worth a thousand words". Show 2-3 worked turns ("here's what a JULIA_CPU_HEAVY window run looks like end-to-end") instead of nested "if window=X then ...".
6. **Move stable text into a cache-able prefix; put per-turn injection at the tail.** Mirror the `SYSTEM_PROMPT_DYNAMIC_BOUNDARY` pattern: scheduler.json, state.json snapshot, seed.md all belong AFTER the durable orchestrator rules.
7. **Externalize procedural workflows from the prompt.** The "in-context procedures replace orchestration" finding (arxiv 2604.27891) is the opposite direction — but it applies to deterministic node graphs. For SpinorBEC's research loop, the seed.md / state.json / scheduler.json triad IS the externalized workflow; director.md should reference, not duplicate, that state.
8. **Audit for contradictions the same way Arbiter does.** After rewriting, run the prompt past a second model with the question "list every pair of instructions that could conflict given some input". The Arbiter paper found 21 contradictions in production Claude Code; assume the same density.
9. **Avoid pure-negative framing.** Convert "don't ignore §B1.0" into a positive "before any julia run: read scheduler then proceed only if policy allows". Positive forms have empirically higher adherence.
10. **Mid-session refresh by active generation, not repetition.** If drift past turn 20-30 is the real concern, add a "verdict block" that requires the agent to RESTATE the active scheduler policy in its own tokens, costing ~30-50 tokens vs re-injecting the whole prompt (~1.5 K). [SCAN method](https://dev.to/nikolasi/solving-agent-system-prompt-drift-in-long-sessions-a-300-token-fix-1akh).

---

### Sources cited

- [Anthropic — Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Anthropic — How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Anthropic — Prompt engineering for Claude's long context window](https://www.anthropic.com/news/prompting-long-context)
- [Anthropic — Building Effective AI Agents](https://anthropic.com/research/building-effective-agents)
- [asgeirtj/system_prompts_leaks — Claude Code](https://github.com/asgeirtj/system_prompts_leaks/blob/main/Anthropic/claude-code.md)
- [Piebald-AI/claude-code-system-prompts](https://github.com/Piebald-AI/claude-code-system-prompts)
- [Drew Breunig — How Claude Code Builds a System Prompt](https://www.dbreunig.com/2026/04/04/how-claude-code-builds-a-system-prompt.html)
- [Claude Code Camp — Inside Claude Code's System Prompt](https://www.claudecodecamp.com/p/inside-claude-code-s-system-prompt)
- [claude-code#45188 — system prompt grew 70K tokens](https://github.com/anthropics/claude-code/issues/45188)
- [Simon Willison — Highlights from the Claude 4 system prompt](https://simonwillison.net/2025/May/25/claude-4-system-prompt/)
- [OpenAI — Codex AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md)
- [OpenAI — Unrolling the Codex agent loop](https://openai.com/index/unrolling-the-codex-agent-loop/)
- [OpenAI — Codex Prompting Guide](https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide)
- [cline/cline source — system-prompt directory](https://github.com/cline/cline/tree/main/src/core/prompts/system-prompt)
- [Cline — System Prompt Advanced](https://cline.bot/blog/system-prompt-advanced)
- [Aider — modular coders FAQ](https://aider.chat/docs/faq.html)
- [Cursor system prompt leak analysis — Patrick McGuinness](https://patmcguinness.substack.com/p/cursor-system-prompt-revealed)
- [jujumilk3/leaked-system-prompts — Cursor IDE Sonnet](https://github.com/jujumilk3/leaked-system-prompts/blob/main/cursor-ide-sonnet_20241224.md)
- [Augment Code — Leaked AI system prompts](https://www.augmentcode.com/learn/leaked-ai-system-prompts-github)
- [arxiv 2603.08993 — Arbiter: detecting interference in agent prompts](https://arxiv.org/pdf/2603.08993)
- [arxiv 2502.12197 — Closer look at system prompt robustness](https://arxiv.org/pdf/2502.12197)
- [arxiv 2603.13351 — Prompt complexity dilutes structured reasoning](https://arxiv.org/html/2603.13351v1)
- [arxiv 2510.07777 — Drift no more: context equilibria](https://arxiv.org/pdf/2510.07777)
- [arxiv 2604.27891 — In-context prompting obsoletes orchestration](https://arxiv.org/abs/2604.27891)
- [dev.to nikolasi — 300-token drift fix (SCAN)](https://dev.to/nikolasi/solving-agent-system-prompt-drift-in-long-sessions-a-300-token-fix-1akh)
- [softcery — AI agent prompt engineering diminishing returns](https://softcery.com/lab/the-ai-agent-prompt-engineering-trap-diminishing-returns-and-real-solutions)
- [aiyan — Don't prompt your agent for reliability, engineer it](https://www.aiyan.io/blog/engineer-agent-reliability/)
- [agentwiki — How to structure system prompts](https://agentwiki.org/how_to_structure_system_prompts)
