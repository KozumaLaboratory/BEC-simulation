# 1000-turn autonomous research loop — context handoff for design review

**Audience**: Claude (claude.ai or another agent session) tasked with designing
a long-horizon autonomous research loop that survives 1000 continuous turns.

**Goal**: Take the current Phase 2 architecture (8 turns observed) and produce
a design that scales to 1000 turns without context decay, memory bloat, drift,
or runaway cost. Cite prior art on long-horizon LLM agents.

**Author**: assistant (Claude Opus 4.7 running as the loop's host session)
**Date**: 2026-05-15
**Project repo**: `~/workspace/BEC-simulation` (SpinorBEC.jl — F=6 Eu-151 spinor
BEC simulator, ~8600 tests, ~150k LOC Julia + Python + bash glue).

---

## 1. What the loop does today

The loop runs **autonomous research turns** on a physics simulation codebase.
Each turn:

1. **Director** (Opus, strategic layer) reads state + memory + recent turns,
   decides which subagent to dispatch.
2. **One of: theorist / researcher / implementer / critic / noop** runs.
3. **Judge.py** (LLM-free Python) checks numerical metrics + cost cap.
4. **Orchestrator** commits results + advances state.json.

The loop's "value" is producing manuscript-grade physics findings + code
changes that advance the project toward "credibly validated simulator".
Observed examples (Phase 2 T0-T7):

- T4: Sign Pattern Lemma 1 extended to F=14 (Paper #3 row added) via sympy
- T5: 8-paper literature audit on F=6 polar LHY 3000× bug
- T6: critic FAILED T5's mechanism claim, cited Castin-Dum 1998 et al.
- T7: theorist 667-line derivation correcting T5, implementer added 18-line
  doc note to `src/hamiltonian/interactions/lhy/dispatch.jl` with the
  refuted-claim trail explicit

This is the kind of output the loop produces. Quality is comparable to
manual claude.ai sessions in many cases (see §6 for evidence).

---

## 2. Current architecture (concrete)

### 2.1 Subagent layers

```
Director (Opus, 1 layer above)         ← strategic routing decisions
   │
   ├─→ Theorist (Opus)                  ← physics derivations
   ├─→ Researcher (Sonnet)              ← literature + parameter scans
   ├─→ Implementer (Sonnet)             ← code edits + bench runs
   └─→ Critic (Opus, blind)             ← out-of-band audit
```

Each subagent has its own `.claude/agents/<name>.md` system prompt with
strict tool restrictions:
- Theorist: Read, Grep, Glob, WebSearch, WebFetch, Write (no Bash, no Edit
  — physical isolation from code execution)
- Researcher: Read, Grep, Glob, WebSearch, WebFetch, Write
- Implementer: Read, Edit, Write, Bash, Glob, Grep (full execution)
- Critic: Read only (blind, structurally independent)
- Director: Read, Grep, Glob, WebFetch, WebSearch, Write (strategic only)

### 2.2 Orchestrator (run-loop.md)

A single `.claude/commands/run-loop.md` slash command. Each turn:

```
Step 0:   Sanity checks (state, quota, agent hashes)
Step 0.5: Director dispatch + parse §6 decision
Step 1:   Subagent dispatch (routed by director)
            (a) theorist + downstream
            (b) researcher-only
            (c) implementer-direct
            (d) critic-audit
            (e) noop
Step 2:   Researcher dispatch (conditional, parallel-capable for K>1 queries)
Step 3:   Directive parsing
Step 4:   Implementer dispatch (if directive.action != noop)
Step 5:   Judge.py (numerical metrics + cost cap)
Step 6:   Commit + state update (turn advance, history append)
Step 7:   End turn (notify, sleep, repeat)
```

### 2.3 Loop driver (loop.sh)

```bash
while status != halted; do
    quota_check.py || halt
    timeout 1200 claude -p "/run-loop" > turn_log.jsonl
    extract_turn_tokens.py → patch sim/state with real token counts
    extract_branch_commit.py → patch state with implementer's branch
    judge.py re-run (cost cap with real numbers)
    sleep 5
done
```

### 2.4 File layout

```
runs/_loop/                     # tracked in git
  state.json                    # source of truth, schema_version=1
  seed.md                       # anko's optional brief
  director/turn_N.md            # strategic decisions
  theorist/turn_N.md            # physics derivations
  research/turn_N.md            # literature briefs
  sim/turn_N.md                 # implementer reports + metrics
  judge/turn_N.json             # PASS/FAIL verdicts
  judge/turn_N_critic_audit.md  # critic blind reviews
  knowledge/<slug>.md           # researcher's persistent cache
  history_archive/turns_X_to_Y.json  # spilled history (when > 50 entries)
  _local/                       # gitignored (state.json.lock, etc.)

.claude/                        # ALL gitignored (machine-local)
  agents/{director,theorist,researcher,implementer,critic}.md
  commands/run-loop.md
  scripts/{loop,judge,quota_check,...}.{sh,py}
  settings.json / settings.local.json
  logs/turn_N_<ts>.jsonl        # stream-json per turn
```

### 2.5 Per-turn observed costs

| Metric | Range | Notes |
|---|---|---|
| Wall time | 8–14 min | Director (~1 min) + chosen subagent (~5–10 min) + judge (<1s) |
| Raw tokens | 7M–11M | input_fresh ~10k + cache_creation ~300–500k + cache_read ~7–10M + output ~10–20k |
| Effective billing tokens | 0.96M–1.74M | input + 1.25×cache_write + 0.1×cache_read + 5×output |
| Cost cap (raw) | 35M | runaway detection threshold |
| Cost cap (effective) | 3M | FAIL_PHYSICS above |

**Implication for 1000 turns**: at observed ~1.2M effective/turn average,
1000 turns = 1.2B effective tokens. At Max plan ~12 turns/5h-window,
1000 turns = 84 windows × 5h = 17.5 days continuous wall.

---

## 3. Current memory mechanisms

### 3.1 Hierarchy

```
Anthropic /memory tool       ← auto-loaded per session, anko's accumulated notes
  └── MEMORY.md (~28KB, 50+ topic entries)
  └── per-topic .md files in same dir (varies)

state.json history[]         ← bounded by spill_history.sh
  └── ≤50 most recent entries auto-loaded
  └── older spilled to history_archive/ (NOT auto-loaded)

runs/_loop/* files           ← persisted, not auto-loaded
  └── readable via explicit Read/Glob
  └── director reads "last 3 turns" by convention

knowledge/<slug>.md          ← researcher's persistent cache
  └── grep'd before web searches
```

### 3.2 What each subagent reads per turn (concrete)

- **Director**: state.json + last 3 turns (theorist + sim + judge) + previous
  director turn + ≥1 relevant memory file + seed.md ≈ **130KB ≈ 35K tokens**
- **Theorist**: state + last sim + last judge + seed + MEMORY + agent.md
  ≈ **80KB ≈ 20K tokens**
- **Researcher**: queries + memory + knowledge cache ≈ **30KB ≈ 8K tokens**
- **Implementer**: directive + agent.md + relevant code via Read ≈ **30–80KB**
- **Critic**: only the 2 files specified in dispatch brief ≈ **40KB**

Per-turn context: well within 200K Opus window. Currently 5–20% utilized.

### 3.3 What works

- Each subagent reads relevant subset; nothing dumps full project state.
- MEMORY.md serves as long-term findings index (anko + assistant curated).
- Turn outputs persist in git; explicit Read recovers any past turn.

### 3.4 What's known fragile

- **Director "last 3 turns" is hard-coded**. Turn 100 won't see Turn 10.
- **MEMORY.md is manually updated**. No auto-promotion of findings.
- **No turn-to-paper traceability index**. Manual grep through 1000 files = slow.
- **No drift detection**. Loop could pursue dead end for many turns.

---

## 4. Phase 2 evidence (8 turns observed)

Director (newly added at T4) demonstrated meaningful routing diversity:

| Turn | Director picked | Verdict | Topic | Subagent reuse rule |
|---|---|---|---|---|
| T0–T3 | (pre-director) theorist+impl | PASS | FG sign / Wick / spinor invariance / sympy infra | (no rotation enforced) |
| T4 | implementer (Paper #3) | PASS | Lemma 1 F=14 extension | rotation OK |
| T5 | researcher | RESEARCHER_ONLY | F=6 polar LHY 8-paper audit | rotation OK |
| T6 | critic | CRITIC_FAIL | T5 mechanism audit | rotation OK |
| T7 | theorist + impl | PASS | T6 follow-up Nambu derivation | rotation OK |

**Cross-turn dependency observed**:
- T6 critic FAILed T5 → T7 director read T6 → T7 theorist re-derived
- T7 implementer's dispatch.jl comment explicitly cites "(T5 claim refuted)"
- Memory entry `full_bdg_F6_polar_broken.md` was Read in T5 and T7

So **cross-turn carry-over works for adjacent turns** (T_{N-3} … T_N) via
director's window + explicit Read by lower layers. Working memory layer
is functional at small scale.

**Cost convergence**:
- T0-T3 effective tokens: 1.16M, 1.74M (~1.5M average for theorist-led)
- T5 (researcher): 0.5M (literature-only, lower)
- T6 (critic): 1.26M (Opus, deep but bounded)
- T7 (theorist + impl): 0.96M (theorist heavy, impl light)
- Average: **~1.2M effective per turn**, stable across subagent types.

---

## 5. 1000-turn scaling questions (the actual ask)

The current architecture handles 8 turns well. What needs to change for 1000?

### 5.1 Context decay (highest-priority)

After turn 50, director's "last 3 turns" misses turn 1–47. Without
mechanism to recall turn 12's insight, the loop may **reinvent the same
question 30 turns later**. Observed once already: T2 redid Q3 territory
T1 had partially covered.

**Design questions**:
- Episodic-vs-semantic memory split (cf. Generative Agents, Park et al. 2023)?
- Reflexion-style verbal feedback accumulation per topic?
- Periodic memory consolidation turn (every M=10) that compresses last 10
  turns into a single MEMORY entry?
- Vector-DB retrieval over past turn outputs (semantic search)?

### 5.2 Memory file growth

MEMORY.md at 8 turns: ~28KB. After 1000 turns of curated entries:
~500KB-1MB. Auto-loading 1MB into every subagent's context is **half the
Opus window** consumed before doing any work.

**Design questions**:
- Hierarchical memory (load only top-level index, defer to specific
  files by Read when needed)?
- Topic clustering + relevance filtering (only load topics matching
  the current turn's subagent-type)?
- Compression / summarization passes on cold memory?
- Pruning policy (delete entries that haven't been Read in 100 turns)?

### 5.3 State.json history scaling

Currently 50-entry cap, 30-spill batches. 1000 turns = 33 archives.
Director sees only last 50; older patterns invisible.

**Design questions**:
- Index of archive files searchable by tag (subagent_type, topic, verdict)?
- Sparse summaries persisted per archive (1 line per turn)?
- Bloom filter / similarity hash so director can ask "have we tried X
  in last 200 turns?"

### 5.4 Drift / dead-end detection

What if turns 100–150 are all FAIL_PHYSICS or NOOP because the loop
gets stuck on a question that's not answerable from text?
Current `stuck check` (4/5 fail → halt) catches *consecutive* fails,
not *thematic* drift.

**Design questions**:
- Diversity metric across last N turns (subagent rotation, topic
  rotation)?
- "Manuscript advance" metric — did the last 10 turns produce content
  that landed in a paper chapter?
- Auto-escalation to human when leverage estimate drops?

### 5.5 Cost pacing

1.2M × 1000 = 1.2B effective tokens. At Max x20 plan ~8M tokens / 5h-window
(rough estimate, Anthropic doesn't publish exact). 1000 turns = 150 windows
≈ 31 days continuous. With weekly cap, more like 60 days clock time.

**Design questions**:
- Per-turn cost budget enforcement (cost cap already exists, ~3M effective).
- Topic-cost prioritization (cheap researcher turns interleaved with
  expensive theorist turns)?
- Quota-aware director (refuse expensive moves when window full)?
- Resumability across quota windows?

### 5.6 Branch / git management

1000 auto/turn_*/ branches. Even with cleanup_branches.sh archiving
failed ones, 100s of "PASS but anko hasn't reviewed" branches accumulate.
Git becomes unwieldy.

**Design questions**:
- Auto-merge to main on PASS + some quality gate? Or always require
  anko review?
- Branch retention policy (delete after N turns if not merged)?
- Squash-merge to keep main linear?

### 5.7 Forensic / manuscript traceability

If turn 500 produces a paper-scale finding, how to trace its lineage
back through cited prior turns? Currently: manual grep through
runs/_loop/*. At 1000 turns this is impractical.

**Design questions**:
- Per-turn metadata tagging (topic, paper, chapter, dependency_on:[turn_X, ...])?
- Auto-generated index page (markdown table of contents)?
- Manuscript-section → list-of-turns reverse index?

### 5.8 Failure mode taxonomy

Currently: PASS, FAIL_NUMERICAL (retry), FAIL_PHYSICS (advance with
note), SUSPICIOUS_NOVEL, REJECTED, NOOP, RESEARCHER_ONLY, CRITIC_PASS/FAIL/INCONCLUSIVE.

At 1000 turns: some failure modes may need finer granularity:
- "Director couldn't find leverage move" (different from noop)
- "Subagent context exceeded"
- "Subagent went off-topic" (drift within turn)
- "Cumulative quality drop" (multi-turn pattern)

---

## 6. Reference data (what claude.ai needs)

### 6.1 Concrete file paths to inspect

```
~/workspace/BEC-simulation/
  .claude/agents/director.md           # 250 lines, strategic protocol
  .claude/agents/theorist.md           # 460 lines, physics protocol
  .claude/agents/researcher.md         # 165 lines, literature protocol
  .claude/agents/implementer.md        # 230 lines, code protocol
  .claude/agents/critic.md             # 125 lines, blind audit protocol
  .claude/commands/run-loop.md         # 380 lines, orchestrator state machine
  .claude/scripts/loop.sh              # 180 lines, bash driver
  .claude/scripts/judge.py             # 285 lines, LLM-free verdict
  .claude/scripts/extract_turn_tokens.py  # 220 lines, Anthropic stream-json parser
  .claude/scripts/quota_check.py       # 95 lines, rolling 5h + weekly cap
  .claude/scripts/spill_history.sh     # 50 lines, state.json archival
  .claude/scripts/cleanup_branches.sh  # 110 lines, auto/* lifecycle
  .claude/scripts/extract_research_queries.py
  .claude/scripts/extract_branch_commit.py
  .claude/scripts/run_sympy.py         # 100 lines, ephemeral sympy via uv

  runs/_loop/state.json                # current state machine
  runs/_loop/seed.md                   # anko's optional brief
  runs/_loop/{director,theorist,research,sim,judge}/turn_*.md   # 8 turns of outputs

  /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/
    MEMORY.md                          # 28KB index
    *.md                               # ~50 topic files
```

### 6.2 Memory files of particular relevance to this design ask

```
loop_architecture_2026_05_14.md        # Phase 0+1 history + architecture decisions
universal_theorem_status.md            # Paper #3 progress
lhy_refactor_2026_05_12.md             # Paper #4 LHY framework status
full_bdg_F6_polar_broken.md            # The bug T5-T7 worked on
```

### 6.3 Token-cost reference data

T0–T7 measured effective tokens per turn (from runs/_loop/state.json history):
```
T0: 0 (pre-tokens-tracking)
T1: 0 (pre-tokens-tracking)
T2: 0 (pre-tokens-tracking)
T3: 1,155,181
T4: 1,740,164
T5: ~500,000 (researcher, lighter)
T6: 1,261,444
T7: 962,627
```

Mean post-tracking: **1,123,883 effective tokens / turn**.

### 6.4 Performance characteristics

- Theorist turn (Opus, deep): ~5–10 min wall, ~1.0–1.5M effective
- Researcher turn (Sonnet, light): ~3–5 min, ~0.3–0.7M effective
- Implementer turn (Sonnet, code): ~2–5 min, ~0.5–1.0M effective
- Critic turn (Opus, deep): ~5–8 min, ~1.0–1.3M effective
- Director (Opus, planning): ~1–2 min, ~0.2–0.4M effective (included in all)

---

## 7. Existing prior-art references (incomplete, please extend)

What I know of, but haven't deeply read:

- **Voyager** (Wang et al. 2023): Minecraft LLM agent with skill library;
  uses iterative prompting + automatic curriculum. Skill library = our
  knowledge cache. Curriculum = our director.
- **Generative Agents** (Park et al. 2023): episodic memory stream +
  reflection synthesis. Reflection = our memory consolidation question.
- **Reflexion** (Shinn et al. 2023): verbal feedback + retry. Our critic
  is similar but stricter (independent context).
- **AutoGPT** lessons: drift / cost / hallucination at long horizon. We've
  partially addressed via cost cap + critic + director, but not fully.
- **Self-Refine** (Madaan et al. 2023): iterative improvement of single
  output. Our T6→T7 (critic FAIL → theorist re-derive) is conceptually
  similar.
- **Tree of Thoughts** (Yao et al. 2023): branching exploration. We currently
  do linear; could branch at director.
- **MemGPT** (Packer et al. 2023): OS-style memory hierarchy with paging.
  Highly relevant to our 1000-turn problem.

What I HAVEN'T checked:
- Specific cost / drift characterization papers
- Memory consolidation in production LLM agents (Anthropic, OpenAI, Google papers?)
- Industrial long-horizon agent deployments (Devin, Manus, etc.)
- Recent (2025-2026) survey papers on long-horizon LLM agents

---

## 8. Specific design questions for claude.ai

If anko hands this off to a fresh claude.ai session, the questions to ask:

1. **Memory architecture for 1000 turns**: MemGPT-style paging? Vector-DB
   semantic retrieval? Or hierarchical summarization (Reflexion-style)?
   Which fits a research-loop better than a dialogue-loop?

2. **Drift detection**: what metrics work for "the loop has stopped
   producing value" beyond pass-rate? Should I track per-paper / per-chapter
   contribution rate? Manuscript-diff-size per turn?

3. **Cost amortization**: at 1.2M effective × 1000 = 1.2B effective tokens,
   is there a smarter scheduling (off-peak windows, batch literature reviews,
   etc.) that drops average per-turn cost? Or is 1.2M intrinsic to this kind
   of work?

4. **Director's strategic horizon**: 3-turn window is short. What's the
   right horizon for a research-direction agent? 10? 50? Hierarchical
   (director-of-directors)?

5. **Knowledge cache + retrieval**: researcher writes `knowledge/<slug>.md`
   files. Should there be auto-clustering? Embeddings? When subagent N+1
   asks a question, how does it find prior knowledge?

6. **Auto-correction vs human-review threshold**: critic dispatched
   manually now. At 1000 turns, can't trust autonomous PASS/FAIL forever.
   What's the right escalation pattern?

7. **Reproducibility**: 1000 turn outputs in git. How do future readers
   navigate? Auto-generated dashboard? Per-paper index?

8. **Failure handling**: stuck check (4/5 fail) is coarse. What's the
   right multi-turn quality monitor?

---

## 9. Out of scope for this handoff

- Implementation details of subagent prompts (already in `.claude/agents/`)
- SpinorBEC.jl physics specifics (covered by the project's CLAUDE.md + memory)
- Anthropic API rate-limit specifics (anko has Max x20, exact limits private)
- 1Password / gpg signing details (anko already disabled signing for auto loops)

---

## 10. Concrete asks for the design output

A successful design document from claude.ai (or assistant's own research)
should produce:

1. **Memory architecture** with concrete data structure (file layout +
   schema, NOT just "use a vector DB").
2. **Drift detection metric** with code skeleton.
3. **Pacing strategy** for 1000-turn run (off-peak handling, quota awareness).
4. **Forensic index** structure (how to find "all turns relevant to Paper #4
   Chapter 3").
5. **Migration plan** from current 8-turn-architecture to long-horizon — i.e.,
   what changes to make first, second, third.
6. **Cost estimate**: realistic upper bound on 1000-turn total cost in
   effective tokens + wall-clock days.
7. **Risk register**: top 5 ways this can fail at 1000 turns + mitigations.

---

## End of handoff

The current Phase 2 architecture is documented in repo + memory. The
8-turn evidence base shows the loop can produce manuscript-grade output
when correctly routed. The scaling question is whether the same
architecture survives 100× longer runs, or if it needs structural
upgrade. Please advise.

References (from the loop itself):
- 11 git commits of loop work on `main` branch: `git log --grep="^auto(loop)"` or `--grep="^chore(loop)"`
- T7's dispatch.jl comment with refutation trail: `git show 6f92776`
- T6 critic full audit: `runs/_loop/judge/turn_6_critic_audit.md`
- T7 theorist 667-line derivation: `runs/_loop/theorist/turn_7.md`
