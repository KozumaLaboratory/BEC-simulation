# 1000-turn autonomous research loop — design synthesis

**Status**: research-saturated, design draft
**Prereqs**: read `long_horizon_design_handoff.md` (context),
  `long_horizon_priorart.md` (round-1 lit scan, 25 refs),
  `long_horizon_priorart_round2.md` (round-2 lit scan, 16 refs).
**Author**: assistant, 2026-05-15

This is a concrete file-by-file change plan, not a vague proposal.
Each upgrade cites the literature finding that justifies it, gives
current-vs-proposed code, and ranks by leverage × inverse-cost.

---

## 1. Literature distillation (what 41 refs actually say)

After 2 research rounds (41 sources, 2024-2026), the consensus
applicable to a 1000-turn autonomous research agent is:

**M (memory)**: hierarchical, paged. **Letta** [Packer 2023, Letta
docs 2024] uses core (≤2KB, always-in-context) + archival (vector,
unlimited) + external (cold). **Anthropic's /memory tool benchmark**:
84% token reduction at 100-turn evaluations vs naive prompt
accumulation [Anthropic 2025, via third-party]. **Codex CLI**:
durable spec via `AGENTS.md` files + context compaction yields 25h
uninterrupted runs [OpenAI 2025].

**F (failure modes)**: literature documents 5 distinct failure
modes at long horizon. We currently catch 0:
1. **Context saturation** — >50% fail-rate from noisy context
   [arXiv:2510.18939]
2. **Meltdown** — coherent-incorrect → incoherent looping +
   hallucinated tool outputs. GPT-4o: 61% pass@1 → 25% pass@8
   [arXiv:2603.29231]
3. **Tool hallucination** — stronger reasoning amplifies fabricated
   tool calls [arXiv:2510.22977]
4. **Planning brittleness** — sub-intention omission cascades
   [arXiv:2509.18970]
5. **Looping without recovery** — agents retry same failed action
   [arXiv:2512.07497]

**S (self-correction)**: independent-context critic correctly avoids
the circular-critique failure of single-agent Reflexion [MAR 2025,
arXiv:2512.20845]. Our T6 critic was independent → caught T5's
wrong claim. Validates direction; need to scale critic frequency.

**C (cost)**: agentic tasks consume **1000× more tokens** than chat
[Bai 2026, arXiv:2604.22750]. Identical task runs vary by **up to
30×** in total tokens. Our 3M effective cost cap is appropriately
placed as runaway detector. Per-task economics: AgentRxiv produces
a full ML paper at **$3.11/paper** (40-paper avg, range $2.15–$9.87)
in 1.36h wall [arXiv:2503.18102]. Agent Laboratory: $2.33–$13.10/paper
[arXiv:2501.04227]. **Our 1.2M effective/turn × 1000 ≈ $300–$1000
total** (rough, depends on rate) is "industry-standard heavy",
not "unreasonable".

**A (architecture)**:
- **Anthropic "Effective Harnesses"** [2025]: 2-agent split
  (Initializer writes 200+ feature spec + init.sh + first git commit;
  Coding agent reads progress + git log, works one feature at a
  time). Three state-bridging artifacts: progress file + JSON
  feature list + git history. We have all 3 (`seed.md` + `state.json`
  + git log). Need to make Initializer pattern explicit.
- **Anthropic "Multi-agent Research System"** [2025]: Opus
  orchestrator + Sonnet subagents + Citation Agent. External memory
  saves research plan when approaching 200K limit. Multi-agent
  outperforms single Opus by **90.2%** on breadth-first queries.
  Cost: 4× chat (single-agent), 15× chat (multi-agent). We match
  this exactly with our director + 4 subagents.
- **AI Scientist v2** [Yamada 2025, arXiv:2504.08066]: tree-search
  managed by **Experiment Progress Manager** agent + VLM critic loop
  for figures. First AI-generated paper accepted at ICLR 2025 ICBINB
  workshop. Cost $15-20/run. Tree-search variant of our linear loop.
- **Google AI co-scientist** [Feb 2025, arXiv:2502.18864]: 6
  specialized agents + ELO tournament hypothesis ranking. Scoped
  to hypothesis gen, not experiment exec. We're a closer match to
  the linear pipeline.

**B (benchmarks)**: **No published benchmark exercises 1000 sequential
turns**. Frontier studied horizon: **~25 hours / ~100 turns** (Codex
CLI). METR's 10-hour horizon is upper bound on academic measurement
[Kwa 2025, arXiv:2503.14499]. **We are designing for an unmeasured
regime**. This must inform our risk register.

---

## 2. Priority-ordered upgrade list

Ranked by leverage × inverse-effort. Each upgrade lists:
- Current state (concrete file/code reference)
- Proposed change (concrete code)
- Literature justification (citation)
- Effort estimate
- Risk if NOT done at 1000 turns

### Upgrade A — Memory hierarchy (highest leverage)

**Current** (concrete):
- `MEMORY.md` 28KB auto-loaded every subagent dispatch via
  Anthropic `/memory` tool
- ~50 topic files in `/home/suzume/.claude/projects/.../memory/`
- Each subagent reads memory + state + reports = 80-130KB context
  per turn (5-20% of 200K window)

**Projection at 1000 turns**: MEMORY.md → 500KB–1MB (each turn adds
~1KB of curated findings, only some get promoted). Auto-loading 1MB
consumes 50% of Opus context window before any work.

**Proposed**:
1. **Split MEMORY.md into MEMORY_INDEX.md (≤2KB, one line per topic)
   + per-topic files (already exist but not formally indexed)**.
   Subagents auto-load INDEX only.
2. **Add `mcp__memory__search` style on-demand retrieval**: subagents
   `Grep` or `Glob` memory dir for relevant topics, then `Read`
   specific files. Already supported by current tool restrictions.
3. **Add cold-storage policy**: entries not Read in last 100 turns
   move to `memory/cold/`. Audit: track last-read-turn per entry.
4. **Per-subagent memory profiles**: theorist loads physics-topic
   files; researcher loads literature-cache files; implementer loads
   code-convention files. Currently all subagents load same MEMORY.md.

**Literature**: Letta's three-tier (core/archival/cold) [Packer
2023]; Anthropic /memory 84% token reduction at 100 turns [Anthropic
2025]; Codex CLI's AGENTS.md compaction [OpenAI 2025].

**Effort**: 4-6 hours.
- Restructure MEMORY.md to INDEX form (~1h)
- Update 5 agent .md files to use Grep+Read pattern instead of full
  auto-load (~2h)
- Implement last-read tracking + cold-storage script (~1h)
- Migration: cold-storage existing 50 topic files initially (~1h)

**Risk if skipped**: context saturation at turn ~300-500 (when
MEMORY.md exceeds 100KB). Subagent context becomes 60%+ filled
with stale memory, performance degrades per RecoveryBench finding
[Letta 2024].

---

### Upgrade B — Drift detection (highest safety)

**Current**:
- `judge.py` outputs: PASS / FAIL_NUMERICAL / FAIL_PHYSICS / SUSPICIOUS_NOVEL / FAIL_JUDGE_CRASHED / FAIL_NO_METRICS
- `run-loop.md` Step 5b-bis "stuck check": last 5 turns, ≥4 FAIL → halt to human
- No detection of: meltdown, tool hallucination, planning brittleness,
  looping, context saturation, **thematic drift** (loop pursuing
  dead end for 50 turns)

**Projection at 1000 turns**: minor drift accumulates. 50 turns
pursuing a wrong theory direction = ~60M effective tokens wasted.

**Proposed**: per-turn drift metrics + escalation rules.

Add to `runs/_loop/state.json.history[N]`:
```json
{
  ...,
  "drift_signals": {
    "topic_repetition": <int, count of last 10 turns with same directive_label prefix>,
    "subagent_repetition": <int, count of consecutive same-type>,
    "manuscript_delta": <bool, did this turn modify docs/manuscript/*?>,
    "code_delta": <bool, did this turn modify src/*?>,
    "verdict_drift": <int, count of last 10 turns NOT PASS>,
    "cost_inflation": <float, this turn effective_tokens / 10-turn-median>,
    "novel_claim_count": <int, [Established] tags in theorist §4>
  }
}
```

New `judge.py` checks on top of existing:
- `topic_repetition > 7` (out of 10) → emit `DRIFT_TOPIC` advisory
- `subagent_repetition > 3` → emit `DRIFT_ROUTING` (director B4 violation)
- `manuscript_delta + code_delta == 0` for last 10 turns → emit
  `DRIFT_IDLE` (loop producing no real artifacts)
- `cost_inflation > 2.0` → emit `DRIFT_COST` advisory
- `novel_claim_count == 0` across last 10 turns → emit `DRIFT_STALE`
  (no new findings)

Escalation: ≥ 2 simultaneous drift signals → director MUST address
in next turn (B-something rule). ≥ 3 → force `human_required` status.

**Literature**: 5 failure modes from arXiv [2510.18939, 2603.29231,
2510.22977, 2509.18970, 2512.07497]. Stuck-check 4/5 catches
consecutive failure; drift signals catch thematic decay.

**Effort**: 3-4 hours.
- Extend `judge.py` (~1h)
- Add drift escalation rules to `run-loop.md` Step 5 (~1h)
- Director protocol B-section to honor drift advisories (~1h)
- Smoke test on synthetic 10-turn drift case (~1h)

**Risk if skipped**: at turn 200, loop is wasting tokens on a wrong
direction with no automatic detection. We catch this MANUALLY (anko
notices nothing's been merged in 50 turns), but by then 50 × 1.2M
= 60M effective tokens lost (~$200-500 wasted).

---

### Upgrade C — Cost pacing + quota awareness (essential at 1000-turn scale)

**Current**:
- `quota_check.py` approximation: rolling 5h turn count + weekly
  turn count (NOT token-aware)
- `cost_cap_per_turn_effective = 3M`, `cost_cap_per_turn_raw = 35M`
- Cost cap CHECKED post-turn by `loop.sh` (judge re-run with real
  tokens), so a turn that exceeds cap completes and then fails
- No off-peak / quota-window scheduling
- No "save quota for harder turns later" budgeting

**Projection at 1000 turns**: at 1.2M effective × 1000 = 1.2B
total effective. At observed window cap ~12 turns / 5h, that's 84
windows × 5h = 17.5 days continuous wall.

**Proposed**:
1. **Token-based quota_check**: track rolling 5h effective tokens
   (not turn count). Replace `max_turns_per_window=12` with
   `max_effective_tokens_per_window=15M` (~12 typical turns).
2. **Pre-turn token reservation**: director estimates expected cost
   (already in §6.expected_cost field). If `current_window_used + expected >
   window_cap`, defer to next window (sleep `loop.sh` until window
   resets, OR emit `subagent_type: "noop"` with budget reason).
3. **Off-peak scheduling**: if wall-clock is in PT 5am-11am
   (~21:00-3:00 JST, anko's sleep hours), allow 1.5× the normal
   cap (Anthropic reportedly throttles less off-peak; was previously
   anecdotal, can verify empirically).
4. **Per-subagent cost profiles**: state.json tracks per-subagent
   effective-token medians over last 100 turns. Director uses this
   for `expected_cost` field calibration.

**Literature**: Bai 2026 30× token variability finding [arXiv:2604.22750]
validates conservative cost caps. AgentRxiv $3.11/paper × 40 papers
= our 1000-turn upper budget ~$300-1000 [arXiv:2503.18102].

**Effort**: 5-7 hours.
- Rewrite `quota_check.py` for token-based (~2h)
- `loop.sh` quota-window sleep logic (~2h)
- Director protocol update for budget-aware dispatch (~1h)
- Per-subagent cost-history tracking in state.json (~1h)
- Smoke test (~1h)

**Risk if skipped**: at turn 300, hit weekly cap mid-turn, loop
crashes asymmetrically (partial commit). Or worse: spent 80% of
weekly cap on low-value researcher turns and have nothing left for
the high-value implementer turn that would have closed the bottleneck.

---

### Upgrade D — Forensic / traceability index (essential for 1000-turn output)

**Current**:
- `runs/_loop/{director,theorist,research,sim,judge}/turn_N.md` for
  every turn — files exist, no index
- `MEMORY.md` is a topic index, not a turn-output index
- Manual: `git log --grep="^auto(loop)"` reveals turn commits
- No way to answer "all turns relevant to Paper #4 Chapter 3"
  without grep across 1000 files

**Projection at 1000 turns**: 5000 files in `runs/_loop/`, ~50MB
of markdown. Manual search degrades fast.

**Proposed**:
1. **Per-turn metadata frontmatter** in every theorist/sim/research/
   director output:
   ```yaml
   ---
   turn: N
   subagent: theorist | researcher | ...
   topic_tags: [paper3, sign-pattern-lemma1, F=14, sympy]
   paper_section: paper3/sign_pattern_lemma1_general_S.md
   depends_on: [turn_4, turn_2]
   produces: docs/manuscript/papers/paper3/.../lemma1_F14_row
   ---
   ```
2. **Auto-generated index** at `runs/_loop/INDEX.md` regenerated by
   `loop.sh` post-step:
   ```markdown
   | turn | subagent | topic_tags | paper_section | verdict |
   |---|---|---|---|---|
   | T4 | implementer | [paper3, lemma1] | paper3/lemma1_general_S | PASS |
   | T5 | researcher | [paper4, lhy, F=6-polar] | paper4/lhy_framework | RESEARCHER |
   | T6 | critic | [paper4, lhy] | paper4/lhy_framework | FAIL |
   | T7 | theorist | [paper4, lhy, Nambu] | paper4/lhy_framework | PASS |
   ```
3. **Reverse index** at `runs/_loop/by_paper/<paper>.md` regenerated:
   ```markdown
   # Paper #4 LHY framework — turn contributions
   - T5: 8-paper lit audit (research/turn_5.md)
   - T6: FAILed T5 Nambu claim (judge/turn_6_critic_audit.md)
   - T7: corrected derivation (theorist/turn_7.md, 667 lines)
   - T7 implementer: dispatch.jl +18 line comment (auto/turn_7_*, commit 6f92776)
   ```

**Literature**: Codex CLI's AGENTS.md durable spec approach
[OpenAI 2025] applied at finer turn-level granularity.

**Effort**: 3-4 hours.
- Frontmatter generation in subagent prompts (~1h)
- Index regen script (~1h)
- Reverse-by-paper script (~1h)
- Backfill existing 8 turns with frontmatter (~30min)
- Smoke (~30min)

**Risk if skipped**: at turn 500, anko (or future reader) loses
ability to trace lineage. Manuscript review becomes "search through
500 files to find what supports this claim".

---

### Upgrade E — Initializer pattern (Anthropic Effective Harnesses)

**Current**:
- `seed.md` written by anko before launching a session, optional
- No explicit "feature spec" or "init.sh" — seed is free-form
  prose
- Director honors seed.md but has full autonomy to override

**Proposed**: formalize seed.md as a 200+ line spec per Anthropic's
"Effective Harnesses" pattern. When anko launches a long session:
1. Anko (or a one-shot Initializer turn) writes the FULL session
   spec: goals, priorities, exclusions, constraints, milestones.
2. Director reads the spec each turn as primary context.
3. Director's §6 must explicitly justify ANY deviation from spec.
4. Spec doesn't change mid-session unless anko writes new spec.

**Literature**: Anthropic "Effective Harnesses for Long-Running
Agents" [2025] — Initializer agent writes 200+ feature spec; Coder
follows. Codex CLI's `AGENTS.md` files similarly serve as durable
context.

**Effort**: 2-3 hours.
- Document spec format in `seed.md` template (~1h)
- Director protocol update to read+honor spec (~1h)
- Backfill current seed.md into spec form (~30min)

**Risk if skipped**: director's autonomy over 1000 turns means
direction may drift far from anko's actual intent without anko
realizing.

---

### Upgrade F — Tree-search variant (optional, advanced)

**Current**: linear loop, one path through possibilities.

**Proposed**: at director's discretion, fork the loop at decision
points. Spawn multiple `auto/turn_N_branch_X/` branches in
parallel, run for 3-5 turns each, then merge / select.

**Literature**: AI Scientist v2's tree-search via Experiment
Progress Manager [Yamada 2025, arXiv:2504.08066]. Tree of Thoughts
[Yao 2023].

**Effort**: 8-12 hours (significant orchestrator rewrite).

**Risk if skipped**: low at current scale. Worth re-evaluating
after upgrades A-E land and we observe 50-100 turn behavior.

**Recommendation**: defer. Not needed for 1000 turns; only needed
if we want **better quality per turn**, which is separate from
"survive 1000 turns".

---

## 3. Migration order

A-E in priority order. F deferred.

Days 1-2 (~10h):
- **A. Memory hierarchy** (4-6h) — biggest leverage, simplest infra
- **D. Forensic index** (3-4h) — accumulates value; do before turn count grows

Days 3-4 (~10h):
- **B. Drift detection** (3-4h) — critical safety
- **C. Cost pacing** (5-7h) — economic safety

Day 5 (~3h):
- **E. Initializer pattern** (2-3h) — strategic discipline

After all 5 upgrades land: smoke-test on a fresh 10-turn run,
observe drift signals + cost tracking + memory paging. Then commit
to a 50-turn run as a stress test (vs the 8 we've done so far).

If 50-turn run shows expected behavior: proceed with 100-turn runs
in waves, increasing to 200, 500, 1000 as confidence builds.

---

## 4. Cost estimate (validated against literature)

Per AgentRxiv [arXiv:2503.18102]: $3.11/paper × ~1000 "papers" of
research-turn work ≈ **$3000 upper bound** if every turn produced a
paper. Realistically, our 1000 turns produce ~10-30 paper-scale
findings (a finding takes 5-50 turns), so $300-1000 per "paper"
× 20 papers = $6000-20000 total.

That's UPPER BOUND on tokens-to-dollars. Anko's Max x20 plan caps
the rate, not the total — actual outlay is the Max subscription
fee × duration (~$200/month × 1 month ≈ $200 covers it).

The constraint is **rate**, not total. Max x20 ~8M tokens / 5h
window (rough estimate); at 1.2M effective/turn that's ~6 turns /
window. **Less optimistic than my earlier ~12 turns/window
estimate.** Need to validate empirically.

At 6 turns / window × 5h window × 24h/day × 7d/week = 7 windows /
day × 7 days = ~250 turns/week. 1000 turns = ~4 weeks elapsed.

---

## 5. Risk register (top 5)

1. **Memory consolidation incorrectness**: cold-storage moves an
   entry that turns out to be critical 200 turns later. Mitigation:
   `last_read_turn` tracking persists; cold-storage doesn't delete,
   just defers loading; explicit-Read still recovers.

2. **Drift detection false positive**: legitimate deep dive on one
   topic for 10 turns flags DRIFT_TOPIC, halts loop. Mitigation:
   advisory not auto-halt; only ≥3 simultaneous signals force
   human_required.

3. **Cost pacing under-budgets a critical turn**: a high-value
   implementer turn (e.g., F=6 spinor extension code add + test
   run) needs 3M effective, gets denied as over-budget. Mitigation:
   per-subagent cost profiles inform `expected_cost`; director can
   `request_high_budget: true` flag for justified cases.

4. **Forensic index regeneration drift**: index becomes stale, loses
   reliability over many turns. Mitigation: regen on every turn's
   commit, validate index against git-log on startup.

5. **Unmeasured regime**: 1000 turns is past any published
   benchmark. Mitigation: pause at 50/100/200/500 for human review
   before committing to next interval.

---

## 6. What we still don't know (epistemic honesty)

- Anthropic Max plan exact rate limits (private; observable empirically).
- Drift signal thresholds in practice (need 50-turn run to calibrate).
- Whether `dont theorize blindly` rule scales — director's 3-turn
  window may need extension at 100+ turns.
- Whether tree-search (F) is needed for quality at high turn count
  or only adds cost without quality gain.

These can ONLY be answered empirically. The first 50-100 turns under
the upgraded architecture should answer them.

---

## End of design

Next concrete steps if anko approves:
1. Build A (memory) + D (index) — 2 days
2. Build B (drift) + C (cost) — 2 days
3. Build E (initializer) — 0.5 day
4. 10-turn smoke
5. 50-turn stress
6. 100/200/500/1000 with checkpoints

Or alternative: anko hands this synthesis + the 2 priorart files +
the handoff doc to claude.ai for second-opinion design review before
implementation.
