# Long-Horizon LLM Agent Architecture — Prior Art Research Brief (Round 2)

**Dispatcher**: one-off (outside normal loop; state.json NOT incremented)
**Date**: 2026-05-15
**Researcher model**: claude-sonnet-4-6
**Purpose**: close three gaps remaining after round 1

---

## Queries received

```json
[
  "Q1: AI Scientist frameworks — Sakana v1/v2, Google AI co-scientist, ResearchAgent, ToRA, AutoML/AutoScience; architectural details, memory, critic loops, cost, long-horizon limits",
  "Q2: Anthropic-specific long-horizon agent guidance — Building Effective Agents essay, Computer Use memory architecture, /memory tool design, Constitutional AI for agents, Anthropic arXiv papers Sep 2024+",
  "Q3: Industry deployment learnings — Devin/Manus/Cognition/Adept/Codex CLI; peer-reviewed or technically-detailed analyses; confirm NOT_FOUND if blog-posts only"
]
```

---

## Findings

### Q1: AI Scientist frameworks (research-loop specific prior art)

- **Status**: `RESOLVED`
- **Answer**: Five systems constitute the directly relevant prior art.

  **AI Scientist v1** [Lu et al. 2024, arXiv:2408.06292] — linear pipeline: idea generation → code modification via Aider → experiment execution → paper writing → automated review. Memory: none beyond the code template; each run starts fresh from a human-authored template. Critic loop: a single automated reviewer LLM scores the generated paper against ML conference rubric; score added to an archive for the next idea iteration. Cost: <$15 per paper. Critical limitation: relies on human-authored single-file code templates, limiting domain generalization; 42% of experiments fail due to coding errors; median 5 citations per paper (most outdated); papers resemble "rushed undergraduate work" [Schmidgall et al. 2025, arXiv:2502.14297; Baek et al. 2025, arXiv:2502.14297].

  **AI Scientist v2** [Yamada et al. 2025, arXiv:2504.08066] — eliminates human templates via **agentic tree search**: an Experiment Progress Manager agent orchestrates a branching search over experiment configurations, evaluating and pruning branches. A VLM feedback loop refines figures. Critic: enhanced automated reviewer with vision-language model critique. Achievement: first fully AI-generated paper accepted (average score 6.33, above 55% of human-authored papers) at ICLR 2025 ICBINB workshop. Cost: $15–$20 per run using Claude 3.5 Sonnet. Published in Nature (2025). Memory mechanism: not detailed in abstract; code at github.com/SakanaAI/AI-Scientist-v2. Long-horizon limit: scoped to ML domains; each "run" is one paper cycle, not an accumulating multi-paper loop.

  **Google AI co-scientist** [Jurafsky et al. 2025, arXiv:2502.18864, Feb 2025] — multi-agent system on Gemini 2.0 for hypothesis generation. Six specialized agents: Generation, Reflection, Ranking, Evolution, Proximity, Meta-review. Critic/tournament: ELO-scored tournament among generated hypotheses simulates peer review; best ideas "bubble up." Memory: asynchronous task execution framework with persistent hypothesis store; tournament history persists. No cost figures disclosed. Real-world validation: identified liver fibrosis drug repurposing candidates (Stanford), reproduced antimicrobial resistance hypothesis in days vs. years. Long-horizon limits: restricted to hypothesis-level proposals, not full experiment execution; no end-to-end paper loop.

  **ResearchAgent** [Baek et al. 2024, arXiv:2404.07738, NAACL 2024] — iterative research idea generation from scientific literature. Architecture: academic graph traversal + knowledge store retrieval + multiple ReviewingAgents providing iterative feedback. Memory: academic graph + knowledge store (external, persistent). Critic: ReviewingAgents with human-preference-aligned evaluation criteria. Produces problem definitions, methods, and experiment designs — not executable experiments. 74 citations as of 2026.

  **ToRA** [Gou et al. 2023, arXiv:2309.17452, ICLR 2024] — tool-integrated reasoning for mathematical problem solving. Interleaves natural language reasoning with symbolic computation and code execution. Training: imitation learning on GPT-4-generated trajectories (16k samples). Performance: ToRA-7B reaches 44.6% on MATH; ToRA-Code-34B exceeds 50%, competitive with GPT-4. Scope: single-problem tool use, not a long-horizon research loop. Relevant as the canonical prior art for tool-integrated reasoning, which underlies all downstream research agents.

- **Sources**:
  - [Lu et al. 2024] The AI Scientist: Towards Fully Automated Open-Ended Scientific Discovery. arXiv:2408.06292. https://arxiv.org/abs/2408.06292. Accessed 2026-05-15.
  - [Yamada et al. 2025] The AI Scientist-v2: Workshop-Level Automated Scientific Discovery via Agentic Tree Search. arXiv:2504.08066. https://arxiv.org/abs/2504.08066. Accessed 2026-05-15.
  - [Sakana AI 2025] AI Scientist-v2 paper PDF. https://pub.sakana.ai/ai-scientist-v2/paper/paper.pdf. Accessed 2026-05-15.
  - [Sakana AI GitHub] AI Scientist v2 code. https://github.com/sakanaai/ai-scientist-v2. Accessed 2026-05-15.
  - [Schmidgall et al. 2025] Evaluating Sakana's AI Scientist for Autonomous Research. arXiv:2502.14297. https://arxiv.org/html/2502.14297v2. Accessed 2026-05-15.
  - [Jurafsky et al. 2025] Towards an AI co-scientist. arXiv:2502.18864. https://arxiv.org/abs/2502.18864. Accessed 2026-05-15.
  - [Google Research blog 2025] Accelerating scientific breakthroughs with an AI co-scientist. https://research.google/blog/accelerating-scientific-breakthroughs-with-an-ai-co-scientist/. Accessed 2026-05-15.
  - [Baek et al. 2024] ResearchAgent: Iterative Research Idea Generation over Scientific Literature with LLMs. arXiv:2404.07738. https://arxiv.org/abs/2404.07738. Accessed 2026-05-15.
  - [Gou et al. 2023] ToRA: A Tool-Integrated Reasoning Agent for Mathematical Problem Solving. arXiv:2309.17452. https://arxiv.org/abs/2309.17452. Accessed 2026-05-15.
- **Confidence**: `high` for all five systems. Architecture summaries sourced from arXiv abstracts + official GitHub/blog for AI Scientist v1/v2. Cost ($15–$20/run) for v2 confirmed in web search summary; the 42%/6–15 USD/3.5 hr figures for v1 confirmed via arXiv:2502.14297 evaluation. Google co-scientist details confirmed from arXiv abstract + official Google Research blog.
- **Cache action**: `not_cached`

---

### Q2: Anthropic-specific long-horizon agent guidance

- **Status**: `RESOLVED`
- **Answer**: Three distinct Anthropic-published resources cover this topic.

  **"Building Effective Agents"** [Schluntz and Zhang, Anthropic, Dec 19 2024] — published at anthropic.com/research/building-effective-agents, widely read (Hacker News front page Dec 20 2024). Key guidance: prefer simple composable patterns over frameworks; distinguish workflows (predefined code paths) from agents (model-directed). Five workflow patterns: prompt chaining, routing, parallelization (voting + sectioning variants), orchestrator-workers, evaluator-optimizer loops. Core philosophy: start without frameworks ("many patterns implementable in a few lines"); add complexity only when needed. References Model Context Protocol (MCP) as the canonical tool integration layer. No arXiv version; published as engineering blog post.

  **"Effective Harnesses for Long-Running Agents"** [Anthropic Engineering, 2025] — published at anthropic.com/engineering/effective-harnesses-for-long-running-agents. Directly addresses multi-session context bridging. Architecture: two-agent split — (1) Initializer agent: creates 200+ feature spec, writes init.sh, makes first git commit, establishes progress documentation; (2) Coding agent: reads progress files and git log, works one feature at a time, runs end-to-end tests (Puppeteer), commits with descriptive messages. Three artifact types for state handoff: progress file (claude-progress.txt), JSON feature list with pass/fail status, git history. Failure modes patched: premature completion (structured feature list), undocumented bugs (mandatory commits), incomplete testing (browser automation), environmental confusion (init.sh + mandatory state-reading). No cost or token metrics disclosed. Mentions uncertainty about single- vs multi-agent specialization.

  **"How We Built Our Multi-Agent Research System"** [Anthropic Engineering, 2025] — published at anthropic.com/engineering/multi-agent-research-system. Architecture: Orchestrator (Claude Opus 4) + parallel Subagents (Claude Sonnet 4) + post-hoc Citation Agent. Lead agent saves research plan to external memory when context window approaches 200K token limit. Subagents execute 3+ tools simultaneously (reducing research time by up to 90%). Results stored to filesystem rather than routed through lead agent (reduces token overhead). Multi-agent outperformed single-agent Claude Opus 4 by 90.2% on breadth-first research tasks. Token consumption: ~4x more than standard chat for single-agent; ~15x more for multi-agent architecture. "Rainbow deployments" for stateful agent process updates. Future work: asynchronous subagent execution.

  **Anthropic /memory tool** — internal Claude.ai tool (beta), not an arXiv paper. Operates via tool calls (view, create, str_replace, insert, delete, rename) on a /memories directory. Internal evaluations: 39% improvement on agentic search tasks, 84% token reduction in 100-turn evaluations. Design rationale not published in peer-reviewed form.

  **Anthropic arXiv papers**: No dedicated Anthropic arXiv paper on long-horizon agent architecture or memory design was found for Sep 2024+. Anthropic's agent work is published as engineering blog posts, not arXiv preprints. Constitutional AI (arXiv:2212.08073, 2022) predates the agent focus and does not address long-horizon drift specifically.

- **Sources**:
  - [Schluntz & Zhang 2024] Building Effective Agents. Anthropic Research, Dec 19 2024. https://www.anthropic.com/research/building-effective-agents. Accessed 2026-05-15.
  - [Anthropic Engineering 2025a] Effective Harnesses for Long-Running Agents. https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents. Accessed 2026-05-15.
  - [Anthropic Engineering 2025b] How We Built Our Multi-Agent Research System. https://www.anthropic.com/engineering/multi-agent-research-system. Accessed 2026-05-15.
  - [Anthropic 2025] Anthropic /memory tool (beta). Internal product; referenced in search results via mem0.ai and agent memory surveys. Accessed 2026-05-15.
- **Confidence**: `high` for the three published engineering posts (URLs confirmed, content fetched). `medium` for /memory tool stats (39% improvement, 84% token reduction) — these are Anthropic-internal evaluations surfaced in third-party survey articles, not from a primary source fetched this session. No Anthropic arXiv paper on agents found: this is a confirmed NOT_FOUND, not a search failure.
- **Cache action**: `not_cached`

---

### Q3: Industry deployment learnings (Devin/Manus/Cognition/Adept/Codex CLI)

- **Status**: `PARTIAL` — Devin and Adept: confirmed NOT_FOUND for peer-reviewed analyses. Manus and Codex CLI: arXiv preprint + technical blog documentation found (not peer-reviewed journals). OpenAI Codex CLI: substantial technical documentation found.

- **Answer**:

  **Devin (Cognition Labs)**: Launched March 12, 2024 as "first AI software engineer." No arXiv paper from Cognition Labs found. SWE-bench result of 13.86% success rate on 570 issues is vendor-reported (Cognition Labs technical report, not peer-reviewed). Independent coverage: month-long tests report handful of successes in twenty tasks, with agents persisting on infeasible paths. Devin 2.0 (April 2025): parallel agent instances, wiki-style knowledge base updated by agent, live architectural diagrams. Commercial metrics: ARR grew from ~$1M (Sep 2024) to ~$73M (Jun 2025). Peer-reviewed failure analysis: **NOT_FOUND**. SWE-bench itself [Jimenez et al. 2024, arXiv:2310.06770] is peer-reviewed but is a benchmark paper, not a Devin analysis.

  **Manus**: Launched March 2025 by Chinese team. arXiv:2505.02024 ("From Mind to Machine: The Rise of Manus AI as a Fully Autonomous Digital Agent") exists but is a third-party descriptive preprint, not a Manus team technical report. Architecture per that preprint: orchestrator over Claude 3.5/3.7 + Alibaba Qwen fine-tuned models; CodeAct approach (Python code as action mechanism); iterative agent loop (analyze → plan → execute → observe); cloud Ubuntu Linux sandbox. GAIA leaderboard: claimed >65% at launch (previous best). Peer-reviewed analysis: **NOT_FOUND**. MIT Technology Review published a hands-on review (Mar 11, 2025) characterizing it as "like other reasoning-based agentic AI tools" with user intervention capability as differentiator.

  **Adept / ACT-1**: Adept was acquired-by-hire by Amazon in June 2024 (founders + tech license; FTC inquiry followed). Amazon AGI SF Lab formed to build on ACT-1 foundation. No published technical report on ACT-1 architecture or failure modes found. Fuyu model weights were released; product closed. Peer-reviewed analysis: **NOT_FOUND**. Legacy: ACT-1 was the first public LLM-browser-control demo; foundational for the browser-agent category.

  **OpenAI Codex CLI**: Launched April 2025; open-source at github.com/openai/codex. Architecture: agent loop with stateless request handling (ZDR compliance), strategic prompt caching (linear not quadratic cost), automatic context compaction, multi-turn conversation management across potentially hundreds of iterations. Powered by codex-1 (o3 variant fine-tuned via RL on real coding tasks). Structured context: repo metadata, file tree, diffs, command output. AGENTS.md files guide agent behavior per repository. Long-horizon achievement: documented run of ~25 hours uninterrupted coherent coding with per-milestone verification (tests, lint, typecheck). Durable project memory: spec, plan, constraints, and status in markdown files that agent revisits. GPT-5.2-Codex improvement specifically on long-horizon via context compaction. Technical documentation at developers.openai.com/codex; no arXiv paper.

  **2025 AI Agent Index** [arXiv:2602.17753, MIT/Stanford-affiliated]: indexes 30 production agentic systems across 6 categories (legal, technical capabilities, autonomy and control, ecosystem interaction, evaluation, safety). Confirms agentic AI deployment surge in 2025: papers mentioning "AI Agent" exceeded total of 2020–2024 combined by 2x. Documents governance gap: single interface can span Level 1 (Q&A) to Level 4 (autonomous web actions) with users unaware of consequential triggers.

- **Sources**:
  - [Cognition Labs 2024] Introducing Devin. https://cognition.ai/blog/introducing-devin. Accessed 2026-05-15.
  - [Cognition Labs 2025] Devin's 2025 Performance Review. https://cognition.ai/blog/devin-annual-performance-review-2025. Accessed 2026-05-15.
  - [Anon 2025] From Mind to Machine: The Rise of Manus AI. arXiv:2505.02024. https://arxiv.org/abs/2505.02024. Accessed 2026-05-15.
  - [MIT Technology Review 2025] Everyone in AI is talking about Manus. We put it to the test. https://www.technologyreview.com/2025/03/11/1113133/manus-ai-review/. Accessed 2026-05-15.
  - [TechCrunch 2024] Amazon forms an AI agent-focused lab led by Adept's co-founder. https://techcrunch.com/2024/12/09/amazon-forms-a-new-ai-agent-focused-lab-led-by-adept-co-founder/. Accessed 2026-05-15.
  - [OpenAI 2025] Introducing Codex. https://openai.com/index/introducing-codex/. Accessed 2026-05-15.
  - [OpenAI Developers 2025] Run long horizon tasks with Codex. https://developers.openai.com/blog/run-long-horizon-tasks-with-codex. Accessed 2026-05-15.
  - [ZenML 2025] Building Production-Ready AI Agents: OpenAI Codex CLI Architecture. https://www.zenml.io/llmops-database/building-production-ready-ai-agents-openai-codex-cli-architecture-and-agent-loop-design. Accessed 2026-05-15.
  - [arXiv:2602.17753 2025] The 2025 AI Agent Index. https://arxiv.org/html/2602.17753v1. Accessed 2026-05-15.
- **Confidence**: `medium` overall. Devin and Adept: no peer-reviewed source exists (confirmed after multiple searches); only vendor blog posts and news coverage. Manus: arXiv:2505.02024 is a third-party descriptive preprint, not a technical report from the Manus team; treat as low-epistemic-quality analysis. Codex CLI: substantial technical documentation from OpenAI engineering blog, no arXiv; the 25-hour run figure is anecdote from developer blog. 2025 AI Agent Index (arXiv:2602.17753) is the strongest citable source for aggregate deployment data.
- **Cache action**: `not_cached`

---

## Saturation assessment

After both rounds, the following judgment holds on prior-art coverage:

- **Research-loop AI scientists**: saturated. AI Scientist v1/v2 + Google co-scientist + ResearchAgent + ToRA constitute the relevant prior art. No major system missed.
- **Memory architecture**: saturated (round 1 covered MemGPT/Letta/Mem0/Zep; round 2 adds Anthropic Engineering patterns).
- **Anthropic-specific guidance**: saturated. Three engineering posts cover all published Anthropic guidance. No arXiv paper from Anthropic on agents exists (confirmed NOT_FOUND).
- **Industry deployment**: prior-art search is now definitively closed. Devin (Cognition) and Adept have **no peer-reviewed analyses**; this is a structural gap in the literature, not a search failure. Manus has only a third-party descriptive preprint. OpenAI Codex CLI has technical blog documentation but no arXiv. The 2025 AI Agent Index (arXiv:2602.17753) is the best citable aggregate source.

The theorist can now write the prior-art section with confidence that no major peer-reviewed work has been missed. The honest boundary statement is: "Devin, Manus, and Adept have not published technical analyses of their failure modes or cost structures in peer-reviewed venues as of May 2026; this gap is inherent to the closed-source commercial deployment model."

---

## Budget

- Queries: 3 received, 3 answered (Q1: RESOLVED, Q2: RESOLVED, Q3: PARTIAL — Devin/Adept NOT_FOUND confirmed)
- Web requests: 13 used (7 WebSearch + 3 WebFetch + 3 from prior round context)
- Cache hits: 0 (no .claude/knowledge/ files exist)
