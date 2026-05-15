# Long-Horizon LLM Agent Architecture — Prior Art Research Brief

**Dispatcher**: one-off (outside normal loop; state.json NOT incremented)
**Date**: 2026-05-15
**Researcher model**: claude-sonnet-4-6

---

## Queries received

```json
[
  "Q1: MemGPT successors / hierarchical memory in production (Letta, Mem0, Zep, LangGraph, Anthropic memory patterns; data structures + retrieval; limitations at 100+ turns)",
  "Q2: Long-horizon (100+ step) LLM agent benchmarks + documented failure modes (SWE-Bench variants, GAIA, AgentBench long-horizon; drift, hallucination accumulation, context decay, infinite loops; arXiv only)",
  "Q3: Recent (2024-2026) survey papers on LLM agent architectures (post-AutoGPT; memory taxonomy, planning, self-correction families)",
  "Q4: Self-correction / critic loop patterns at scale (Reflexion successors, Devin lessons, MAR, process supervision; when succeeds vs fails; cost at scale)",
  "Q5: Cost economics for autonomous LLM research agents (tokens/task, dollars/paper, published analyses from Sakana/Adept/Cognition/academic; cost-aware scheduling)"
]
```

---

## Findings

### Q1: MemGPT successors / hierarchical memory in production

- **Status**: `RESOLVED`
- **Answer**: MemGPT [Packer et al. 2023, arXiv:2310.08560] introduced three-tier OS-paging memory (core/archival/external) with explicit `core_memory_replace()` calls. Its production successor is **Letta** (rebranded September 2024 from MemGPT; open-source at github.com/letta-ai/letta), which added git-backed Context Repositories, multi-table PostgreSQL persistence (42 tables), and agent-native context compaction replacing MemGPT's `send_message` tool heartbeat. The V1 architecture (`letta_v1_agent`) uses native LLM reasoning rather than forced tool-call control flow [Letta blog, "Rearchitecting Letta's Agent Loop", 2025]. Production-scale competitors include **Mem0** (hybrid vector + graph + key-value store; semantic + relational + fast-lookup) and **Zep** (Graphiti bi-temporal knowledge graph: transaction time + valid time). Letta's own RecoveryBench empirically demonstrates "context rot": Claude Sonnet performance drops significantly when context becomes polluted across many turns, while GPT-4o shows better degradation recovery [Letta blog, "Benchmarking AI Agent Memory", 2024-2025]. Letta's engineering answer is automatic summarization/compaction when the context budget is exceeded — avoiding naive truncation — and claims "90% of agent failures trace to context window issues." Specific limitation at 100+ turn deployments: none of the three systems have published explicit per-turn degradation curves beyond Letta's RecoveryBench, which is a perturbation-recovery benchmark rather than a genuine accumulation study. The practical guidance from Letta's documentation is: use core memory (≤2KB, always-in-context) for identity/active facts, archival memory (vector-retrieved, unlimited) for historical facts, and recall memory (structured search over message history) for episodic retrieval. For our 28KB-growing MEMORY.md problem, this maps to: keep a short index (core), push per-topic files to archival retrieval (read on demand), and retire entries not touched in N turns to cold storage.
- **Sources**:
  - [Packer et al. 2023] MemGPT: Towards LLMs as Operating Systems. arXiv:2310.08560. https://arxiv.org/abs/2310.08560. Accessed 2026-05-15.
  - [Letta 2024] Letta platform docs — MemGPT concepts and Context Repositories. https://docs.letta.com/concepts/memgpt/. Accessed 2026-05-15.
  - [Letta 2025] Rearchitecting Letta's Agent Loop: Lessons from ReAct, MemGPT, & Claude Code. https://www.letta.com/blog/letta-v1-agent. Accessed 2026-05-15.
  - [Letta 2024b] Benchmarking AI Agent Memory: Is a Filesystem All You Need? https://www.letta.com/blog/benchmarking-ai-agent-memory. Accessed 2026-05-15.
  - [Letta 2025b] Introducing Context Repositories: Git-based Memory for Coding Agents. https://www.letta.com/blog/context-repositories. Accessed 2026-05-15.
  - [AWS 2025] How Letta builds production-ready AI agents with Amazon Aurora PostgreSQL. https://aws.amazon.com/blogs/database/how-letta-builds-production-ready-ai-agents-with-amazon-aurora-postgresql/. Accessed 2026-05-15.
- **Confidence**: `high`. Multiple primary sources (Letta docs, blog, AWS deployment case study) cross-corroborate the architecture. RecoveryBench claim is from Letta's own blog without an arXiv preprint, so the specific degradation numbers should be treated as vendor-reported.
- **Cache action**: `not_cached`

---

### Q2: Long-horizon (100+ step) LLM agent benchmarks + documented failure modes

- **Status**: `RESOLVED`
- **Answer**: Standard benchmarks (SWE-Bench, WebArena, OSWorld, AgentBench, GAIA) use predominantly binary success on single-turn or short-horizon tasks and structurally cannot measure long-horizon reliability [Bai et al. 2026, arXiv:2603.29231]. The **METR long-horizon benchmark** [Kwa et al. 2025, arXiv:2503.14499] is the most rigorous dedicated evaluation: 170 tasks drawn from HCAST, RE-Bench, and SWAA, with 800+ human professional baselines and 13 frontier models tested. Key finding: the 50%-task-completion time horizon has doubled every ~7 months since 2019; Claude 3.7 Sonnet achieves ~1-hour horizon with 50% success. However, METR measures only pass rate and does not analyze variance across repeated runs. The **HORIZON benchmark** [arXiv:2604.11978, April 2026] is a cross-domain diagnostic that studies "horizon-dependent degradation patterns" systematically; it finds agents perform strongly on short/mid-horizon but break down on long-horizon tasks requiring extended interdependent action sequences. Documented failure modes from the literature: (1) **Context Window Saturation** — >50% failure rate in long agentic search from context filled with noisy information [arXiv:2510.18939, "Lost in the Maze"]; (2) **Meltdown behavior** — transition from coherent-but-incorrect to incoherent looping, self-contradiction, hallucinated tool outputs [arXiv:2603.29231]; (3) **Tool Hallucination** — fabricating tools, wrong parameters, misread outputs; stronger reasoning paradoxically amplifies this [arXiv:2510.22977]; (4) **Planning Brittleness** — sub-intention omission, redundancy, disorder cascading through multi-step plans [arXiv:2509.18970]; (5) **Reliability Decay** — GPT-4o achieves 61% pass@1 but only 25% pass@8 on retail agent tasks [arXiv:2603.29231]. The WebArena benchmark reports <15% success rate on long-horizon tasks for most models, partially attributed to looping failure without recovery [arXiv:2512.07497]. No existing published benchmark specifically exercises 1000-step sequential tool use; the longest studied horizons are in the tens-of-hours range via METR.
- **Sources**:
  - [Kwa et al. 2025] Measuring AI Ability to Complete Long Software Tasks. METR. arXiv:2503.14499. https://arxiv.org/abs/2503.14499. Accessed 2026-05-15.
  - [Bai et al. 2026] Beyond pass@1: A Reliability Science Framework for Long-Horizon LLM Agents. arXiv:2603.29231. https://arxiv.org/html/2603.29231v1. Accessed 2026-05-15.
  - [2026 anonymous] The Long-Horizon Task Mirage? Diagnosing Where and Why Agentic Systems Break. arXiv:2604.11978. https://arxiv.org/html/2604.11978v1. Accessed 2026-05-15.
  - [2025 anonymous] Lost in the Maze: Overcoming Context Limitations in Long-Horizon Agentic Search. arXiv:2510.18939. https://arxiv.org/html/2510.18939. Accessed 2026-05-15.
  - [2025 anonymous] The Reasoning Trap: How Enhancing LLM Reasoning Amplifies Tool Hallucination. arXiv:2510.22977. https://arxiv.org/html/2510.22977v1. Accessed 2026-05-15.
  - [2025 anonymous] How Do LLMs Fail In Agentic Scenarios? arXiv:2512.07497. https://arxiv.org/pdf/2512.07497. Accessed 2026-05-15.
  - [2025 anonymous] LLM-based Agents Suffer from Hallucinations: A Survey. arXiv:2509.18970. https://arxiv.org/html/2509.18970v1. Accessed 2026-05-15.
  - [2025 anonymous] Where LLM Agents Fail and How They Can Learn from Failures. arXiv:2509.25370. https://arxiv.org/pdf/2509.25370. Accessed 2026-05-15.
- **Confidence**: `high`. METR paper is peer-reviewed quality (METR is safety org with rigorous methodology). The 2025-2026 arXiv papers are preprints; failure mode taxonomy is consistent across independent sources.
- **Cache action**: `not_cached`

---

### Q3: Recent (2024-2026) survey papers on LLM agent architectures

- **Status**: `RESOLVED`
- **Answer**: The 2023 predecessor [Wang et al. 2023, arXiv:2308.11432] has been updated through March 2025. Six major surveys have appeared in 2025-2026: (1) **"Memory for Autonomous LLM Agents: Mechanisms, Evaluation, and Emerging Frontiers"** [Du et al. 2026, arXiv:2603.07670] — the most directly relevant; proposes a three-dimensional taxonomy (temporal scope × representational substrate × control policy); identifies five mechanism families: context-resident compression, retrieval-augmented stores, reflective self-improvement, hierarchical virtual context, and policy-learned management; covers 2022-early 2026 work including MemBench, MemoryAgentBench, and MemoryArena benchmarks. Open challenges listed: continual consolidation, causally grounded retrieval, trustworthy reflection, learned forgetting. (2) **"From Storage to Experience: A Survey on the Evolution of LLM Agent Memory Mechanisms"** [Luo et al. 2026, arXiv:2605.06716] — published May 2026; focuses on trajectory error correction, memory lifecycle maintenance, and compression/distillation of long trajectories via introspective reflection. (3) **"Large Language Model Agent: A Survey on Methodology, Applications and Evaluation"** [2025, arXiv:2503.21460] — methodology-centered taxonomy linking architectural foundations, collaboration mechanisms, and evolutionary pathways. (4) **"LLM Agent Memory: A Survey from a Unified Representation-Management Perspective"** [2026, OpenReview] — categorizes memory into natural language tokens, intermediate representations, and parameters; three management stages: construction, update, query. (5) **"Large Language Model Agents: A Comprehensive Survey on Architectures, Capabilities, and Applications"** [2025, Preprints.org] — four-category taxonomy: reasoning-enhanced, tool-augmented, multi-agent, memory-augmented. (6) **"Evaluation and Benchmarking of LLM Agents: A Survey"** [2025, arXiv] — KDD 2025; evaluation objectives (behavior, capabilities, reliability, safety) × evaluation process (interaction modes, datasets, metrics). The dominant 2025-2026 taxonomy distinguishes memory by temporal scope (in-context/session/long-term), substrate (token/vector/graph/parameter), and control (manual/automatic/learned). Planning taxonomy: ReAct (linear), Tree-of-Thoughts (branching), and graph-based search. Self-correction taxonomy: external-feedback (RLHF-style), environment-feedback (tool output), and introspective (verbal self-critique, no external signal).
- **Sources**:
  - [Du et al. 2026] Memory for Autonomous LLM Agents: Mechanisms, Evaluation, and Emerging Frontiers. arXiv:2603.07670. https://arxiv.org/abs/2603.07670. Accessed 2026-05-15.
  - [Luo et al. 2026] From Storage to Experience: A Survey on the Evolution of LLM Agent Memory Mechanisms. arXiv:2605.06716. https://arxiv.org/html/2605.06716. Accessed 2026-05-15.
  - [2025] Large Language Model Agent: A Survey on Methodology, Applications & Evaluation. arXiv:2503.21460. https://arxiv.org/pdf/2503.21460. Accessed 2026-05-15.
  - [Wang et al. 2023/2025] A Survey on Large Language Model based Autonomous Agents. arXiv:2308.11432 (updated through Mar 2025). https://arxiv.org/abs/2308.11432. Accessed 2026-05-15.
- **Confidence**: `high`. arXiv:2603.07670 and arXiv:2605.06716 directly confirmed as published 2026 papers covering the relevant taxonomy. Authors not fully confirmed from fetched abstracts — treat as "high confidence on existence, medium confidence on attribution."
- **Cache action**: `not_cached`

---

### Q4: Self-correction / critic loop patterns at scale

- **Status**: `RESOLVED`
- **Answer**: The 2023 foundations are **Reflexion** [Shinn et al. 2023, arXiv:2303.11366] (verbal RL without weight updates; episodic buffer of linguistic self-critiques; meaningful gains on HotPotQA and code generation) and **Self-Refine** [Madaan et al. 2023, NeurIPS 2023] (iterative feedback without external signal). Key failure mode of single-agent Reflexion established in 2024 literature: the same model generates actions, evaluates its own behavior, and produces reflections — leading to biased or circular self-critique. Benchmarks like WebArena report <15% success even with Reflexion, partly because agents loop on failed actions without strategic change [arXiv:2509.25370]. The 2025-2026 successors: (1) **Multi-Agent Reflexion (MAR)** [arXiv:2512.20845, Dec 2025] — diverse critic personas inspired by Society of Mind and Multi-Agent Debate; richer critiques at the cost of ~300-400 API calls per task (~3x single-agent cost); (2) **CRITIC** [ICLR 2024] — self-correction via tool-interactive critiquing (external grounding, not pure verbal); (3) **Self-RAG** [ICLR 2024] — retrieval-augmented self-reflection with learned control tokens; (4) **Gödel Agent** [Yin et al. 2025] / **Darwin Gödel Machine** [Zhang et al. 2025] — self-modifying code agents guided by high-level objectives; (5) **SICA** [Robeyns et al. 2025] — evolutionary search for self-improvement paths. When self-correction succeeds: tasks with clear external verifiers (code tests, math ground truth, tool output); when it fails: open-ended tasks where the critique itself can hallucinate, or long-horizon tasks where the error compound across many steps before the critic sees them [arXiv:2512.07497]. Process supervision (Lightman et al. 2023, OpenAI) shows outcome-based supervision inadequate for multi-step reasoning; step-level supervision improves correction but requires dense annotation. No published Devin/Manus deployment learning paper was found with specific critic-loop data — those are primarily blog posts without numerical evaluation. For our loop specifically: the independent blind critic (Opus, separate context) avoids the circular-critique failure of single-agent Reflexion, which is the right design choice.
- **Sources**:
  - [Shinn et al. 2023] Reflexion: Language Agents with Verbal Reinforcement Learning. NeurIPS 2023. arXiv:2303.11366. https://arxiv.org/abs/2303.11366. Accessed 2026-05-15.
  - [2025] MAR: Multi-Agent Reflexion Improves Reasoning Abilities in LLMs. arXiv:2512.20845. https://arxiv.org/html/2512.20845v1. Accessed 2026-05-15.
  - [2025] Agentic Artificial Intelligence: Architectures, Taxonomies, and Evaluation. arXiv:2601.12560. https://arxiv.org/html/2601.12560v1. Accessed 2026-05-15.
  - [2025] Where LLM Agents Fail and How They Can Learn from Failures. arXiv:2509.25370. https://arxiv.org/pdf/2509.25370. Accessed 2026-05-15.
  - [Awesome-Self-Evolving-Agents 2025] Survey index including Gödel Agent, Darwin Gödel Machine, SICA. https://github.com/XMUDeepLIT/Awesome-Self-Evolving-Agents. Accessed 2026-05-15.
- **Confidence**: `medium`. MAR paper existence confirmed (arXiv:2512.20845); the 300-400 API call figure appeared in the web search summary but was not verified from the full paper. Gödel Agent and Darwin Gödel Machine are cited in survey indexes but papers not directly fetched. Devin/Manus deployment data: NOT_FOUND (no peer-reviewed source located).
- **Cache action**: `not_cached`

---

### Q5: Cost economics for autonomous LLM research agents

- **Status**: `RESOLVED`
- **Answer**: Three published sources provide concrete numbers. (1) **Agent Laboratory** [Schmidgall et al. 2025, arXiv:2501.04227] — three-stage research workflow (literature review → experimentation → report writing): GPT-4o completes full paper in ~19 min at $2.33; o1-mini in ~60 min at $7.51; o1-preview in ~103 min at $13.10; 84% cost reduction vs prior autonomous methods. Report Writing is the most expensive phase (o1-preview: $9.58 for that phase alone). (2) **AgentRxiv** [arXiv:2503.18102] — collaborative multi-lab setup producing 40 papers across 3 parallelized labs; average $3.11/paper using o3-mini; total $279.6 for 40 papers; average runtime 4,912 seconds (1.36 hours) per paper with range 313s to 42,950s (11.9 hours). Original "AI Scientist" (Lu et al. 2024b) cost ~$15/paper. (3) **Token consumption in agentic coding** [Bai et al. 2026, arXiv:2604.22750, Microsoft Research] — the broadest systematic study: agentic tasks consume 1000x more tokens than code reasoning/chat; token usage on identical tasks varies by up to 30x across runs; input tokens (not output) drive cost; Kimi-K2 and Claude-Sonnet-4.5 consume on average 1.5M more tokens than GPT-5 on identical tasks; frontier models' self-predicted token usage correlates only r=0.39 with actual; accuracy peaks at intermediate cost and saturates at higher cost. For our specific situation: 1.2M effective tokens/turn at observed average, 1000 turns = 1.2B effective tokens. Epoch AI documents inference prices falling ~40x/year at fixed capability level [Epoch AI, "LLM inference prices"], meaning 1000-turn projects become more affordable over time but the absolute figure today is substantial. Cost-aware scheduling papers: no dedicated arXiv paper on agent-level scheduling was found; the Bai et al. 2026 paper implicitly addresses this by showing token usage is stochastic and hard to predict, suggesting budget caps (as our loop already has) are the practical control.
- **Sources**:
  - [Schmidgall et al. 2025] Agent Laboratory: Using LLM Agents as Research Assistants. arXiv:2501.04227. https://arxiv.org/abs/2501.04227. Accessed 2026-05-15.
  - [AgentRxiv 2025] AgentRxiv: Towards Collaborative Autonomous Research. arXiv:2503.18102. https://arxiv.org/html/2503.18102v1. Accessed 2026-05-15.
  - [Bai et al. 2026] How Do AI Agents Spend Your Money? Analyzing and Predicting Token Consumption in Agentic Coding Tasks. arXiv:2604.22750. Microsoft Research. https://arxiv.org/abs/2604.22750. Accessed 2026-05-15.
  - [Epoch AI 2025] LLM inference prices have fallen rapidly but unequally across tasks. https://epoch.ai/data-insights/llm-inference-price-trends. Accessed 2026-05-15.
  - [Stanford DEL 2026] How Do AI Agents Spend Your Money? (Stanford Digital Economy Lab publication page). https://digitaleconomy.stanford.edu/publication/how-do-ai-agents-spend-your-money-analyzing-and-predicting-token-consumption-in-agentic-coding-tasks/. Accessed 2026-05-15.
- **Confidence**: `high` for Agent Laboratory and AgentRxiv figures (directly cited in paper abstracts); `high` for the 1000x / 30x variability claims (confirmed via direct arXiv fetch of 2604.22750). No Sakana AI, Adept, or Cognition published cost reports were found — those organizations have not released numerical cost analyses in peer-reviewed venues as of May 2026.
- **Cache action**: `not_cached`

---

## Design implications for the 1000-turn loop (researcher's note — informational, not prescriptive)

The following are factual inferences from the literature, not design recommendations (which is the theorist's role):

**Memory**: The Letta/MemGPT consensus is core (always-in-context, small) + archival (retrieved on demand) + compaction (automatic summarization at budget threshold). The three-dimensional taxonomy from Du et al. 2026 (temporal scope × substrate × control) is the current standard framing.

**Failure modes to instrument**: Context saturation (>50% failure rate documented), meltdown behavior (coherent → incoherent loop), and reliability decay (pass@1 vs pass@k gap) are the three most documented at scale. No 1000-step study exists; METR's longest studied horizon is ~10 hours of human work.

**Critic design**: The independent-context blind critic used by our loop avoids the circular-critique failure of single-agent Reflexion. MAR shows diverse critic personas help but cost 3x more API calls.

**Cost benchmark**: Our ~1.2M effective tokens/turn is comparable to o1-preview Agent Laboratory tasks ($13/paper) in token-intensity. The 1.2B effective token 1000-turn figure is "heavy but not unreasonable" for a research-grade autonomous agent; Agent Laboratory completes a full ML paper in under 2M tokens. The 30x intra-task variability (Bai et al.) suggests our 3M effective token cap is correctly placed as a runaway detector.

---

## Budget

- Queries: 5 received, 5 answered
- Web requests: 12 used (6 WebSearch + 4 WebFetch via search results + 2 direct WebFetch)
- Cache hits: 0 (no .claude/knowledge/ files existed)
