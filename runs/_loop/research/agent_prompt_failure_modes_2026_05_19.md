# Agent prompt failure modes at scale (2026-05-19)

Scope: literature + industry evidence for why long, patched agent prompts
(e.g. our `director.md`, 590 lines, 29 sub-sections) silently drop the
newest rule in favour of an older sibling. 15 sources, ≥5 academic and
≥5 industry. Focus on **evidence**, not opinion.

---

## §1 Documented failure modes

1. **Lost-in-the-Middle (LiM) U-shape.** Liu et al. (TACL 2024) — accuracy
   on multi-document QA drops from ~75% (info at position 1) to ~50% when
   the same fact is placed in the middle of a 20-doc context, recovering
   at the tail. Both base and RLHF-tuned models exhibit the curve.
   ([arXiv:2307.03172](https://arxiv.org/abs/2307.03172))

2. **Context Rot at every length, not just the limit.** Chroma (Hong,
   Troynikov, Huber, Jul 2025) measured 18 frontier models incl. Claude
   4 and GPT-4.1 on 8 input lengths; performance degrades monotonically
   from 1K → 50K even when the window is 1M, including on simple copy
   tasks. Failure type is *non-uniform* — distractor type and structure
   matter more than raw length. ([Chroma](https://research.trychroma.com/context-rot))

3. **Instruction-adherence collapse beyond 4–8K output / input.**
   LongGenBench (ICLR 2025) — frontier models obey early instructions
   but adherence "gradually degraded as text generation extends beyond
   the 4,000-token threshold". LongProc reports GPT-4o EM 94.8% @ 0.5K
   → 38.1% @ 8K. Ada-LEval shows accuracy collapse to random ≥32–64K
   on most frontier models. ([LongGenBench](https://arxiv.org/html/2409.02076v7), [Ye et al.](https://arxiv.org/pdf/2511.05850))

4. **Instruction-hierarchy is not actually enforced.** Wallace et al.
   2024 (OpenAI) trained models to prefer the system prompt over user
   input, but Geng et al. ("Control Illusion", arXiv:2502.15851, 2025)
   show frontier models routinely violate intra-system priority once
   conflicts are subtle; *social cues* (authority, expertise, consensus)
   override structural priority. ([Wallace 2024](https://arxiv.org/pdf/2404.13208), [Geng 2025](https://arxiv.org/html/2502.15851v1))

5. **Recency dominates as the prompt approaches the window.** Wang et al.
   (arXiv:2508.07479, Aug 2025) — primacy bias weakens past 50% window
   fill, while recency remains stable. Effect direction reverses: long
   prompts effectively make the *last* rule win. ([arXiv:2508.07479](https://arxiv.org/abs/2508.07479v1))

6. **Attention-dilution in long structured prompts.** SWE-PRBench (Dec
   2025) — 8 models degrade monotonically as the context expands from
   2K-token diff-summary to 2.5K-token full-context with execution and
   test signatures; "the dominant mechanism is a collapse of contextual
   issue detection, consistent with attention dilution". ([SWE-PRBench](https://arxiv.org/html/2603.26130v1))

7. **Prompt-architecture is a measurable bug class.** Arbiter
   (arXiv:2603.08993) audited Claude Code, Codex CLI, Gemini CLI, etc.
   System prompts span 245–1490 lines. Architecture *type* correlates
   with failure *class* (not severity): monolithic → growth-level bugs
   at subsystem boundaries; flat → consistency loss; modular → seam
   bugs. ([Arbiter](https://arxiv.org/pdf/2603.08993))

8. **More tokens ≠ better.** LLMLingua/LongLLMLingua benchmarks
   (ACL 2024) show 4–6× compression *improves* NaturalQuestions accuracy
   by up to 21.4% over the uncompressed prompt — empirical evidence that
   parts of a long prompt are net-negative for the rest. ([Jiang 2023](https://arxiv.org/abs/2310.06839),
   [Microsoft Research](https://www.microsoft.com/en-us/research/blog/llmlingua-innovating-llm-efficiency-with-prompt-compression/))

---

## §2 Empirical length thresholds (where things break)

| Threshold | Symptom | Source |
|---|---|---|
| ~50% of window fill | Primacy bias starts disappearing; recency stays | [Wang 2025](https://arxiv.org/abs/2508.07479v1) |
| 4K output tokens | Stable Top-of-prompt instruction adherence breaks | [LongGenBench](https://arxiv.org/html/2409.02076v7) |
| 8K input tokens | LongProc EM falls from 94.8% to 38.1% | [Ye 2025](https://arxiv.org/pdf/2511.05850) |
| 32–64K input | Most frontier models hit random-baseline on Ada-LEval | [Wang et al. 2024](https://www.emergentmind.com/topics/context-degradation-in-large-language-models) |
| 100K (in 1–2M window) | Agentic safety + capability >50% drop | [arXiv:2512.02445](https://arxiv.org/pdf/2512.02445) |
| CLAUDE.md > ~500 lines | Anecdotal-but-consistent bloat reports | [PromptShelf](https://thepromptshelf.dev/blog/cursorrules-vs-claude-md/), [zenn.dev tmasuyama1114](https://zenn.dev/tmasuyama1114/articles/claude_code_dynamic_rules?locale=en) |
| Production-agent prompts 245–1490 lines | Architecture class predicts failure type | [Arbiter](https://arxiv.org/pdf/2603.08993) |

For us: `director.md` at 590 lines is past the community-cited 500-line
warning, but tiny compared to academic stress tests. The acute risk is
**not raw length** — it is that we sit on the rising part of the curve
where instruction-conflict and recency bias dominate over structural
priority. Our 1.0 (CRITICAL) prefix is competing on a flat field, not
on a hierarchy the model enforces.

---

## §3 Anti-patterns catalog

1. **Patch-on-top.** New "§B1.0 OVERRIDES §B2" prepended; §B2 still
   wins (Geng 2025 — no intra-system priority enforcement). T98 bug.
2. **CAPSLOCK escalation.** Stacked `CRITICAL`/`MANDATORY`/`MUST` —
   adherence erodes when every third paragraph shouts. ([MindStudio](https://www.mindstudio.ai/blog/how-to-prompt-claude-opus-4-7))
3. **Live-data embedding.** Quota / commit-hash / schedule baked in;
   stale within a turn, bloats cache prefix. ([Desai](https://medium.com/@the_manoj_desai/system-prompt-vs-agent-skills-the-architecture-decision-that-makes-or-breaks-your-ai-agent-b58357df1f10))
4. **Duplicated cross-section rules.** §B1 vs §B8 say the same or
   contradict; both decrease signal. ([Databricks](https://docs.databricks.com/aws/en/generative-ai/guide/agent-system-design-patterns))
5. **Phase-collapse.** "Do triage, scoring, execution" given
   simultaneously → agent skips phases. ([Paxrel](https://paxrel.com/blog-ai-agent-prompts))
6. **Edge-case stuffing.** Enumerating "if X then Y; if X' then Y'…"
   instead of canonical examples. ([Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents))
7. **Anchor drift.** Section content rewritten, hooks still cite the
   stable `§B2` name. ([Arbiter](https://arxiv.org/pdf/2603.08993))
8. **"From now on" closures.** Each patch fires unconditionally;
   patches compete in parallel.
9. **Unscoped negatives.** "Never X" without "in scope Y" widens the
   prohibition across unrelated turns.
10. **Author-stamp rules.** "Per anko YYYY-MM-DD" adds tokens, no
    enforcement weight; authority-cue compliance is unpredictable.
11. **Section count > working memory.** 29 sub-anchors exceeds the
    ~7±2 rules LLMs track reliably. ([PromptLayer](https://blog.promptlayer.com/prompt-routers-and-modular-prompt-architecture-8691d7a57aee/))
12. **Mid-context overrides.** Prepending §X.0 to §X puts the override
    in the worst attention zone (LiM). ([Liu 2023](https://arxiv.org/abs/2307.03172))

---

## §4 Detection heuristics

A. **Snapshot regression** — pin 10–50 prior turns; diff verdicts on
   every prompt edit. Slice-level metric ([Ma 2023](https://arxiv.org/pdf/2311.11123),
   [Traceloop](https://www.traceloop.com/blog/automated-prompt-regression-testing-with-llm-as-a-judge-and-ci-cd)).
B. **Conflict-grep** — `rg -i 'override|supersedes|priority|takes precedence'`;
   high count = patch-stack smell.
C. **Anchor-drift audit** — every `§B[0-9]+` cited in scripts/hooks
   must resolve, pre-commit lint.
D. **Echo test** — ask the agent at turn start to list the top-3 rules
   in §B in order; unstable ordering across runs = primacy/recency
   trouble. ([IntuitionLabs](https://intuitionlabs.ai/articles/llm-position-bias-primacy-recency-effects))
E. **CAPS-density** — `CRITICAL|MUST|MANDATORY|NEVER` per 100 lines;
   >5 → adherence inversion likely.
F. **Section-count cap** — ≤7 top-level sections per file; exceed → split.
G. **Compression delta** — run LLMLingua at 4×; if compressed beats
   baseline on the regression set, original carries dead tokens.
   ([LongLLMLingua](https://arxiv.org/abs/2310.06839))
H. **Latest-rule isolation probe** — per rule, construct a turn that
   only that rule resolves; verify the agent picks it. Catches the
   §B1.0 vs §B2 failure directly.
I. **Cacheable-prefix budget** — track stable-prefix vs dynamic-suffix
   ratio per commit. ([Desai](https://medium.com/@the_manoj_desai/system-prompt-vs-agent-skills-the-architecture-decision-that-makes-or-breaks-your-ai-agent-b58357df1f10))

---

## §5 Prevention strategies + recommendations for SpinorBEC.jl loop

P1. **Rewrite-trigger, not patch.** Anthropic's prompt-improver does a
    full rewrite when structure is ambiguous. ([Anthropic](https://www.anthropic.com/news/prompt-improver))
    Trigger rewrite when (a) §X.0 OVERRIDES §X appears, (b) two
    sections contradict, or (c) >500 lines. `director.md` hits (a)+(c).
P2. **Kernel + skills split.** Replace `director.md` with a ≤150-line
    kernel (identity, hard policy, dispatch contract) that *references*
    `.claude/rules/<topic>.md` loaded path-based.
    ([zenn](https://zenn.dev/tmasuyama1114/articles/claude_code_dynamic_rules?locale=en),
    [keboca](https://www.keboca.com/articles/cursorrules-ai-how-i-unified-my-cursor-and-claude-config-one-place))
P3. **One-rule-per-file** in `.claude/rules/` + `rules.yaml` manifest
    mapping turn-phase → rule files. (Router + dynamic-suffix pattern.)
P4. **Snapshot + slice-regression CI.** Pin 20 prior turns under
    `runs/_loop/regression/`; run judge.py on them after every prompt
    edit; fail commit on slice drop. ([Ma 2023](https://arxiv.org/pdf/2311.11123))
P5. **Anchor lint.** Pre-commit: (i) CAPS-marker count, (ii) flag
    `OVERRIDES|SUPERSEDES`, (iii) every `§B[0-9]+` cited in
    `.claude/scripts/*` resolves.
P6. **Last-not-first for the volatile rule.** While the single-file
    prompt remains, put the authoritative rule at the **end** of its
    section, not prepended — recency dominates past 50% window fill.
    ([Wang 2025](https://arxiv.org/abs/2508.07479v1)) Replace §B1
    in-place; don't prepend §B1.0.
P7. **Move dynamic state out of the prompt** — scheduler window, turn
    counter, quota live in files, not text constants.
P8. **Declarative dispatch.** Director's "if scheduler=X route to Y"
    is a classifier, not prose; port to a Python/Julia function.
    ([Khattab 2023](https://arxiv.org/pdf/2310.03714))
P9. **Compression smoke test.** Periodic 4× LLMLingua run; if the
    compressed prompt wins on the regression set, take the diff as a
    prioritised cut-list.
P10. **No author-stamp trailers.** Already in MEMORY; add as lint.

Order:
- P5 + P6 same-day; unblocks T98 with no arch change.
- P4 in one evening; highest leverage thereafter.
- P1 + P2 + P3 as a dedicated rewrite turn.
- P8 opportunistic, next time dispatch is touched.

---

## Sources (15)

Academic:
- [Liu et al., "Lost in the Middle", arXiv:2307.03172 / TACL 2024](https://arxiv.org/abs/2307.03172)
- [Wang et al., "Positional Biases Shift as Inputs Approach Context Window Limits", arXiv:2508.07479](https://arxiv.org/abs/2508.07479v1)
- [Wallace et al., "The Instruction Hierarchy", arXiv:2404.13208 (OpenAI 2024)](https://arxiv.org/pdf/2404.13208)
- [Geng et al., "Control Illusion: The Failure of Instruction Hierarchies", arXiv:2502.15851](https://arxiv.org/html/2502.15851v1)
- [Khattab et al., "DSPy", arXiv:2310.03714 (ICLR 2024)](https://arxiv.org/pdf/2310.03714)
- [Jiang et al., "LongLLMLingua", arXiv:2310.06839 (ACL 2024)](https://arxiv.org/abs/2310.06839)
- [Ma et al., "(Why) Is My Prompt Getting Worse?", arXiv:2311.11123](https://arxiv.org/pdf/2311.11123)
- ["Arbiter: Detecting Interference in LLM Agent System Prompts", arXiv:2603.08993](https://arxiv.org/pdf/2603.08993)
- [Liu et al., LongGenBench, arXiv:2409.02076 / ICLR 2025](https://arxiv.org/html/2409.02076v7)
- ["When Refusals Fail: Unstable Safety in Long-Context Agents", arXiv:2512.02445](https://arxiv.org/pdf/2512.02445)
- [SWE-PRBench, arXiv:2603.26130](https://arxiv.org/html/2603.26130v1)

Industry / engineering:
- [Chroma Research, "Context Rot" (Hong/Troynikov/Huber, Jul 2025)](https://research.trychroma.com/context-rot)
- [Anthropic, "Effective context engineering for AI agents"](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Anthropic Claude 4 prompting best practices](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices)
- [Anthropic prompt improver (rewrite tool)](https://www.anthropic.com/news/prompt-improver)
- [Microsoft Research, LLMLingua blog](https://www.microsoft.com/en-us/research/blog/llmlingua-innovating-llm-efficiency-with-prompt-compression/)
- [Traceloop, "Automated Prompt Regression Testing with LLM-as-a-Judge and CI/CD"](https://www.traceloop.com/blog/automated-prompt-regression-testing-with-llm-as-a-judge-and-ci-cd)
- [PromptLayer, "Prompt routers and modular prompt architecture"](https://blog.promptlayer.com/prompt-routers-and-modular-prompt-architecture-8691d7a57aee/)
- [Manoj Desai, "System Prompt vs Agent Skills"](https://medium.com/@the_manoj_desai/system-prompt-vs-agent-skills-the-architecture-decision-that-makes-or-breaks-your-ai-agent-b58357df1f10)
- [zenn.dev, "Prevent CLAUDE.md bloat with .claude/rules/"](https://zenn.dev/tmasuyama1114/articles/claude_code_dynamic_rules?locale=en)
- [Paxrel, "AI Agent Prompt Engineering: 10 Patterns That Actually Work (2026)"](https://paxrel.com/blog-ai-agent-prompts)
- [IntuitionLabs, "LLM Position Bias: Primacy and Recency Effects"](https://intuitionlabs.ai/articles/llm-position-bias-primacy-recency-effects)
- [DeployHQ, "CLAUDE.md, AGENTS.md & Copilot Instructions Guide"](https://www.deployhq.com/blog/ai-coding-config-files-guide)
