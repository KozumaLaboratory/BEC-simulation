# SpinorBEC.jl Autonomous Research Loop — System Design (2026-05-19)

Snapshot for cross-session review. Goal: identify structural improvements that the current owner is too embedded to see.

---

## 1. Purpose

A self-driving Claude agent loop that conducts physics research on the
SpinorBEC.jl Julia codebase (F=6 ¹⁵¹Eu spinor BEC simulator). One human
operator (anko, the PI). The loop runs unattended for hours to days,
producing real research artifacts (Tier-3 reproductions of published
results, new theoretical results, bug fixes in production code).

Concrete outputs to date (4 closed Tier-3 trajectories):
- `barnett-mechanism-2026-05-16` — Yan-Li-Saito 2026 PRL reproduction
- `klaus-magnetostir-bch-leak-2026-05-13` — Klaus 2022 magnetostir experiment match
- `edh-eu151-vortex-vs-matsui-science-2026` — Matsui Science 2026 EdH paper (NOTE: closure was questionable — see §11)
- `f2-cyclic-tetrahedral-a1-tier3-2026-05-18` — Sign Pattern Lemma 1 extended to F=2 cyclic (manuscript-anchored)

---

## 2. Top-level architecture

```
                ┌─────────────────────────────────────┐
                │  loop.sh  (bash, while true)        │
                │  - reads state.json                 │
                │  - reads scheduler/quota gates      │
                │  - spawns `claude -p /run-loop`     │
                │    (timeout 2400s = 40 min/turn)    │
                │  - post-step: 15+ hooks             │
                └────────────────┬────────────────────┘
                                 │ exec
                                 ▼
                ┌─────────────────────────────────────┐
                │  claude -p /run-loop                │
                │  ───────────────────                │
                │  /run-loop slash command sources    │
                │  the .claude/agents/director.md     │
                │  (orchestrator agent)               │
                │                                     │
                │  Director picks an investigation +  │
                │  drafts a §6 declarative contract,  │
                │  dispatches ONE of:                 │
                │   • theorist  (derivations)         │
                │   • researcher (lit scan, deep tier)│
                │   • implementer (Julia code/run)    │
                │   • critic    (independent audit)   │
                │   • noop                            │
                └────────────────┬────────────────────┘
                                 │ writes
                                 ▼
                ┌─────────────────────────────────────┐
                │  runs/_loop/{director,theorist,     │
                │              sim,research,judge,    │
                │              critic,conclusions,    │
                │              status}/turn_N.{md,json}│
                │  + state.json transaction           │
                └─────────────────────────────────────┘
```

---

## 3. Directory layout

```
.claude/                          (machine-local, gitignored)
├── agents/
│   ├── director.md              590 lines, 15 sections, 29 anchors  ← BLOATED
│   ├── theorist.md              545 lines
│   ├── researcher.md            362 lines (has depth tier: shallow/deep/exhaustive)
│   ├── implementer.md           380 lines
│   └── critic.md                257 lines
├── scripts/
│   ├── loop.sh                  parent shell loop, ~400 lines
│   ├── judge.py                 verdict evaluator (declarative contract)
│   ├── scheduler.py             window/quota gate
│   ├── quota_check.py           5-hr rolling budget cap
│   ├── resource_probe.py        OOM avoidance
│   ├── drift_signals.py         cost/retry/fail-streak detection + meta-spawn
│   ├── otel_emit.py             NDJSON trace emission
│   ├── otel_query.py            agent-friendly OTEL aggregation
│   ├── otel_cost_audit.py       cost-waste pattern detection + auto-spawn
│   ├── contract_cache.py        APC-style §6 template cache  (2026-05-18)
│   ├── conclusions_index.py     [Established]/[Plausible] ledger  (2026-05-18)
│   ├── memory_twice_rule.py     repeated feedback detection      (2026-05-18)
│   ├── forgetting.py            OTEL rotate + log prune + memory cool (2026-05-18)
│   ├── memory_hygiene.py        MEMORY.md size + entry shape audit
│   ├── memory_consolidate.py    periodic merge (every 30 turns)
│   ├── status.sh                anko-readable status snapshot
│   ├── update_investigation_status.py    per-inv narrative file maintenance
│   ├── state_schema_check.py    enum / field validation
│   ├── turn_index_regen.py      forensic index (by_subagent, by_tag, by_paper)
│   ├── notify.sh                halt / error / SIGINT alerts (NO per-turn notify)
│   └── ... (tests/, extract_*, cleanup_branches)
├── workload_specs.yaml          per-workload-class cost/wallclock expectations
├── cache/contract_templates.json  APC cache (19 templates)
└── logs/
    ├── loop.log                 main log
    ├── otel_traces.ndjson       structured trace
    ├── turn_N.jsonl             per-turn full transcript
    └── {memory_hygiene,judge_patch,contract_cache,...}_N.log

runs/_loop/                       (in-tree, version-controlled)
├── state.json                   schema v2.1, 23 investigations, 49 history entries
├── seed.md                      anko-edited priority directives
├── schedule.yaml                anko-edited time windows
├── INDEX.md                     forensic index (auto)
├── _local/scheduler_N.json      per-turn scheduler decision
├── director/turn_N.md           per-turn director output
├── theorist/turn_N.md
├── researcher/turn_N.md
├── sim/turn_N.md                implementer output
├── critic/turn_N.md
├── judge/turn_N.json            structured verdict
├── conclusions/<inv_id>.md      durable per-inv claim ledger
├── status/<inv_id>.md           narrative per-inv history
└── research/                    deeper / synthesis output

memory/  (anko's Claude Code auto-memory, persistent across sessions)
├── MEMORY.md                    index (~150 lines)
├── feedback_*.md                12+ anko corrections (load-bearing)
├── gotcha_*.md                  10+ landmines (e.g. "use 'Gauss' not 'G'")
├── universal_theorem_status.md  current research thread state
└── ... (50+ topic files)
```

---

## 4. State schema (`runs/_loop/state.json` v2.1)

```jsonc
{
  "schema_version": 2.1,
  "turn": 105,                          // current turn pointer
  "status": "running",                  // running | halt | error | scheduler_halt | ...
  "last_judge": "CRITIC_PASS",
  "active_investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "retries": 0,
  "history": [/* per-turn audit records */],
  "investigations": {
    "edh-eu151-vortex-vs-matsui-science-2026": {
      "id": "...",
      "kind": "physics",                // physics | meta
      "title": "...",
      "hypothesis": "...",
      "flow_template": "verify-claim",  // see §6
      "current_stage": "Update (re-opened ...)",
      "stages_done": ["Research", "Hypothesize", "Design", ...],
      "tier_current": 2.5,
      "tier_target": 3,
      "priority": 0,                    // lower = higher
      "blocked_on": null,
      "next_stage_action": "...",       // hint for next director turn
      "falsifiers": [
        {"id": "F1", "description": "ring formation at t_ring", "tested_at_turn": null, "result": null},
        {"id": "F2", ...},
        {"id": "F3", ...}
      ]
    },
    ...22 more investigations (closed + dormant + observe + ...)
  },
  "recent_findings": [/* 10-turn cross-investigation broadcast queue */]
}
```

---

## 5. Per-turn protocol

```
loop.sh while-loop iteration:

1. scheduler.py + quota_check.py        gate check
2. spawn claude -p /run-loop (40min timeout)
   ├─ director.md picks investigation, drafts §6 contract
   ├─ subagent dispatched (theorist / researcher / implementer / critic / noop)
   ├─ judge.py runs (preliminary, before tokens known)
   ├─ output written under runs/_loop/<role>/turn_N.{md,json}
3. post-step (in loop.sh):
   a. extract tokens from claude -p stdout
   b. patch sim/turn_N.md §4 Metrics with tokens
   c. RE-RUN judge.py (now with tokens → cost_audit fires)
   d. copy investigation_id + stage + cost_audit → history[-1]
   e. drift_signals.py: detect cost-inflation / retry-loop / fail-streak
   f. drift_signals.py --check-meta-spawn: auto-spawn meta-investigation if triggered
   g. turn_index_regen.py: forensic index
   h. memory_hygiene.py check + memory_twice_rule.py scan
   i. memory_consolidate.py (every 30 turns)
   j. forgetting.py all (every 50 turns: OTEL rotate, log prune, memory cool)
   k. otel_emit.py turn-summary
   l. otel_cost_audit.py --maybe-spawn (auto-spawn meta if cost waste detected)
   m. contract_cache.py extract (APC template extraction)
   n. conclusions_index.py extract (durable claim ledger)
   o. update_investigation_status.py (narrative md per investigation)
   p. state_schema_check.py (enum validation, advisory)
   q. flock-protected jq update of investigation state per judge verdict
4. sleep INTER_TURN_SLEEP (default 5s)
```

---

## 6. Flow templates (`director.md §F`)

Investigations are typed by `flow_template`:

| Template | Stages | Use case |
|---|---|---|
| `verify-claim` | Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed | D1 verification (default for most physics work) |
| `build-theory` | Research → Hypothesize → Derive → Specialize → Test → Generalize → Update → Document → closed | D3 new-theory work |
| `fix-bug` | Reproduce → Hypothesize → Patch → Test → Land → Document → closed | bug fixes |
| `survey` | Inventory → Triage → Report → closed | low-commitment exploration |
| `meta-improvement` | Observe → Hypothesize → Design → Pilot → Evaluate → Adopt/Revert → Document → closed | loop self-improvement (the loop modifies its own prompts/scripts) |
| `audit-class-scan` | Observe → Triage → Sample → Audit → Patch → Verify → Report → closed | periodic anti-pattern scanning (codebase grep + critic) |

Each stage maps to a role (theorist / researcher / implementer / critic).
Director's §6 contract specifies success_criteria + failure_modes + observable_manifest + budget per stage.

---

## 7. Tier ladder

| Tier | Meaning |
|---|---|
| 0 | not attempted |
| 1 | internal regression test only |
| 2 | closed-form / sympy / cross-implementation verified |
| 3 | published-reference benchmarked (Stuttgart, Yan-Li-Saito, Matsui, etc.) |

Most existing `[Established]` claims in memory are Tier 1-2. Reaching
Tier 3 is the loop's main D1-axis goal ("grounded autonomous research"
metric: 75% of [Established] claims within 5% of published).

---

## 8. Subagent roles + responsibilities

| Agent | Reads | Writes | Tools |
|---|---|---|---|
| **director** | state.json, scheduler.json, seed.md, memory/MEMORY.md, prev director, conclusions index | runs/_loop/director/turn_N.md | (orchestrates only, no exec) |
| **theorist** | director's §6 contract, prior theorist/sim, memory | runs/_loop/theorist/turn_N.md | Read, Grep, Glob, WebFetch, Write |
| **researcher** | §6 contract, `<RESEARCH_NEEDED>` tokens from theorist, memory | runs/_loop/research/<topic>.md | Read, Grep, Glob, WebSearch, WebFetch, Write |
| **implementer** | §6 contract, theorist directive, src/, runs/auto/, sibling configs | runs/_loop/sim/turn_N.md + runs/auto/turn_N_<label>/ + code edits | Read, Edit, Write, Bash, Glob, Grep |
| **critic** | sim metrics, theorist directive, conclusions index | runs/_loop/critic/turn_N.md OR returns to orchestrator | Read only |
| **judge** | sim §4 Metrics + director §6 contract | runs/_loop/judge/turn_N.json | (python script, not LLM) |

`judge.py` is the only NON-LLM agent: it deterministically evaluates
the declarative §6 contract against sim metrics and emits PASS / FAIL /
INCONCLUSIVE / FAIL_OPERATIONAL / NOOP_DIRECTOR / REFUTED / NOVEL.

Researcher has depth tiers (shallow / deep / exhaustive) — deep tier
mandates ≥30 parallel queries, full-PDF reads, ≥2 iteration rounds,
contradiction surfacing, per-claim confidence.

---

## 9. Auto-spawned meta-investigations

The loop spawns meta-investigations on itself when patterns are detected:

| Trigger | Spawns |
|---|---|
| `otel_cost_audit.py` detects PERSISTENT_BUDGET_OVER (≥4/10 turns over budget) | `meta-cost-waste-audit-YYYY-MM-DD` |
| `drift_signals.py` detects cost_inflation_run (3+ turns over 2× expected) | `meta-cost-inflation-YYYY-MM-DD` |
| Same-stage fail streak (3+ FAIL_OPERATIONAL on same stage) | `meta-stage-routing-YYYY-MM-DD` |
| Director self-audit due (every N turns) | `meta-director-self-audit-YYYY-MM-DD` |
| Audit-class-scan due heuristic | `audit-class-scan-YYYY-MM-DD-T<N>` |

Meta-investigations can modify the loop's own prompts (`director.md`,
`workload_specs.yaml`, `theorist.md`, etc.) under safety rails (§F5 S1-S6:
single change at a time, baseline metric, evaluate window, revert path,
no anko-edited files, idempotency).

**External reviewer hazard (2026-05-19):** Gloaguen et al. 2026
documented that **LLM-generated agent instructions reduce agent
performance while increasing cost** — a direct empirical reversal of
the expected meta-improvement gain. The §F5 safety rails are
necessary but not sufficient; the deeper issue is **Arbiter's
principle (arXiv:2603.08993): "the agent that resolves conflicts
cannot be the same as the agent that detects them"** — auto-prompt-
rewrite by the same orchestrator family is the named failure mode.

Recommended hardening (still pending):
- meta-investigation patches to `director.md` etc. should go through
  an Arbiter-style adversarial audit BEFORE landing — a separate
  prompt that tries to break the patched prompt by finding internal
  contradictions or unresolved priorities. (True Arbiter is cross-
  vendor; Claude-only approximation = use a deliberately-different
  system prompt for the audit pass.)
- DGM-style archive: revert decisions kept as a separate archive for
  future reference (arXiv:2505 Darwinian Gödel Machine pattern).

---

## 10. Hooks added 2026-05-18 (latest layer)

1. **APC contract cache** — extracts §6 contract structural skeleton
   (values stripped to placeholders), keyed by (kind, flow_template,
   stage). 19 templates backfilled. Director reads cache before drafting
   §6 (claimed 30-50% cost reduction per arXiv:2506.14852).

   **External reviewer caution (2026-05-19):** arXiv:2602.18922 (Mar
   2026) reports APC achieves **0-12% accuracy** on personal AI agent
   benchmarks (MASSIVE/BANKING77/CLINC150). Root cause: "cache
   effectiveness requires key consistency and precision, not
   classification accuracy".

   **Audit completed 2026-05-19 — verdict: PULLED.** Two independent
   failures confirmed:
   1. Director has no Bash tool — the §B1 directive
      `python3 .claude/scripts/contract_cache.py lookup ...` cannot
      execute. 6 director turns confabulated the lookup (wrote "would
      return ... USE the cached skeleton" without actually calling
      anything). The 30-50% cost reduction was never realized in this
      deployment.
   2. The cached skeleton is byte-equivalent to the most-recently-
      extracted contract with values stripped, NOT a class-generic
      template. T100's tdhfb-phase2-specific 18-criteria schema sat
      under the same key (`physics::verify-claim::Execute`) as T27
      barnett's 4-criteria schema. Key (kind, flow_template, stage)
      is too coarse.
   Removed: §B1 directive in director.md, `contract_cache.py extract`
   hook in loop.sh post-step. Script preserved for archival.
   Full audit: `runs/_loop/research/apc_audit_2026_05_19.md`.

2. **Conclusions index** — durable `[Established]` / `[Plausible]` /
   falsifier-tested claim ledger per investigation. Director's reading
   list now includes it (§B1).

3. **Twice rule** — detects when two feedback memories converge on the
   same topic (jaccard ≥ 0.18). Currently 0 pairs trigger.

4. **Critic post-mortem (§B7)** — critic now references conclusions
   index; PASS_REDUNDANT verdict if claim was already Established.

5. **Selective forgetting** — OTEL rotation (gzip after 1500 lines),
   per-turn log prune (>30 days), memory cool (untouched project
   memories → `_cold/` after 80 turns; feedback/user memories NEVER
   cooled).

---

## 11. Known structural problems (the reason for this snapshot)

### A. Prompt bloat / incremental-patch failure

`director.md` is **590 lines, 15 top sections, 29 subsection anchors**.
Patches accumulated: §B1.0 (CRITICAL — read first) was prepended on
top of existing §B1-B8. Empirical failure: at T98, after I set
priority=0 + new §B1.0 + active_investigation_id on the Matsui
investigation, the director **ignored all of it** and picked a different
investigation by §B2 priority walk. The patch was buried under older
rules. Classic "rewrite, don't patch" anti-pattern.

**Root cause (2026-05-19 research):**
- arXiv:2502.15851 (Geng 2025, "Control Illusion") — frontier models do
  not enforce intra-system priority labels; social/positional cues
  override structural priority. "CRITICAL — read FIRST" prefix has no
  enforcement weight.
- arXiv:2508.07479 (Wang 2025) — past 50% window fill, recency beats
  primacy; **prepending §B1.0 lands the rule in the worst attention
  zone**. Correct moves: replace §B2 in-place, OR append at the end.
- 29 sub-anchors >> 7±2 working memory (PromptLayer); 590 lines past
  community-cited 500-line bloat warning (Anthropic guidance, zenn.dev).
- LLMLingua 4× compression empirically **improves** NQ accuracy by
  21.4% — direct evidence that long prompts contain net-negative tokens.

Research artifact: `runs/_loop/research/agent_prompt_failure_modes_2026_05_19.md`
(23 cited sources). Companion reports for Anthropic/OpenAI native +
academic frameworks pending.

Recommended fix path (P1-P10 from research):
- P5 + P6 same-day: pre-commit anchor lint + replace §B2 in-place
- P4 one evening: slice-regression CI on 20 pinned turns
- P1+P2+P3 dedicated rewrite: ≤150-line kernel + `.claude/rules/<topic>.md` split
- P8 opportunistic: port director dispatch (priority walk + tier_gap) to a Python function

This was the trigger for the current rewrite effort.

### B. Tier-3 inflation via partial-falsifier closure

The Matsui EdH investigation closed at T86 as "Tier 3.0" on F3 (energy
convention) alone. F1 (the ring formation — Matsui's actual published
result) was NOT_APPLICABLE because the loop wrote a regressed
simulation config that omitted K3 loss + gamma_dr + noise seed +
anharmonic trap. Meanwhile `runs/eu151_edh_K3_long/trajectory.png`
(May 13, 14.5 ms, all schema features present) shows the cascade
cleanly — but the loop never looked at it because director.md §B1 has
no rule to grep `runs/` for sibling artifacts before drafting new
experiments.

This is rule (B1.0) that I tried to patch in — see (A).

**Root cause (external reviewer, 2026-05-19):**
- This is the named **"Overexcitement / Eureka Instinct"** failure
  mode in Lossfunk arXiv:2601.03315 (Jan 2026), one of their 6
  documented LLM-scientist pathologies.
- Lossfunk's #2 design principle: **"Verify Everything — ground in
  raw data, not LLM interpretations."** sim §4 Metrics is an LLM-
  written summary; judge.py reading it carries the LLM's optimism.
  trajectory.csv / result.jld2 are deterministic ground truth.
- Combinatorial math the reviewer surfaced: at 23 active
  investigations × P(false PASS | 1-of-3 falsifiers, p=0.1) ≈ 27%
  per investigation, the loop's "1-of-N falsifier PASS = closure"
  rule admits **expected 6.2 false Tier-3 closures**. Matsui case
  was not bad luck — it was system-permitted by design.

**Fix in place (2026-05-19, this session):**
- `falsifier_central_migration.py` added `is_central: bool` to every
  falsifier in `state.json`. For Matsui: F1 (ring formation) marked
  central; F3 (energy convention) demoted to corroborative.
- `judge.py:_check_central_falsifier_for_tier3` clamps tier promotion
  to ≤ 2.75 when the central falsifier is untested / not CORROBORATE.
  Verified by replaying T86 (Matsui closure): now blocked with
  `tier_cap=2.75` instead of silent 3.0 promotion.
- `judge.py:_evaluate_shell_criterion` adds FORM B criterion type
  with `check_cmd` + `expect:{exit_code, stdout_contains,
  stdout_json_field}`. Allow-list of read-only programs
  (julia/python3/jq/grep/etc.); no shell metachars allowed.
  Routes criterion eval through deterministic subprocess against
  raw artifacts (e.g. `runs/eu151_edh_K3_long/trajectory.csv`)
  bypassing sim §4 LLM-summary entirely.

**Still pending (P-class items):**
- POPPER sequential e-value framework (arXiv:2502.09858, ICML 2025)
  with Bonferroni correction α/N_active across in-flight investigations.
  Currently the gate is binary (central PASS or block); the full
  sequential framework would aggregate evidence across falsifiers.
- Per-investigation curation of which falsifier is central (auto-
  picker chose first-falsifier for non-Matsui cases; some are mis-
  curated and should be revised case-by-case).

### C. JUDGE_PATCH silently not firing

The post-step hook copies `investigation_id` + `stage` + `cost_audit`
from judge JSON into `history[-1]`. Manual jq works; the in-loop bash
doesn't apply. T76-T82 history entries are blank for these fields.
Cause not yet identified; debug logging added.

### D. Per-turn notifications not implemented

`notify.sh` only fires on halt / SIGINT / error. There's no per-turn
notify to the human operator, which makes async monitoring tedious.

### E. State enum drift

`current_stage` is supposed to be an enum (Research / Hypothesize /
... / closed). Director writes narrative blobs ("Update (re-opened
2026-05-18; T76-T86 closure was tier-inflation...)") into the enum
slot. `state_schema_check.py` warns but doesn't block. The narrative
content is informative; the enum violation breaks downstream queries.

### F. Researcher depth defaulted to shallow

The researcher has shallow / deep / exhaustive tiers. Default is
shallow. Most director dispatches don't upgrade to deep, even for
Tier-3 target investigations. Anchor on default = wasted cycles.

### G. Active investigation ID does not lock investigation selection

I set `active_investigation_id` thinking it locks director's choice;
director.md §B2 walks priority + tier_gap + continuation. Active is
treated as "what's currently visible" not "what next turn MUST pick".

**Reviewer fix (still pending):** move `active_investigation_id`
hard-lock to `loop.sh` (outside the LLM judgment); director.md
should be invoked with the active inv pre-injected, not picked
inside the prompt. Code-level branching beats prompt-level
hierarchy (Geng 2025 evidence).

---

## 11.H. External reviewer (2026-05-19) — critique recap

A second-opinion review was performed via a parallel Claude session
on this `SYSTEM_DESIGN.md`. Key cross-references the reviewer added:

| Finding | Paper | Section impacted |
|---|---|---|
| Tier-3 inflation = "Eureka Instinct" failure | Lossfunk arXiv:2601.03315 (Jan 2026) | §11.B |
| Self-audit by same agent impossible | Arbiter arXiv:2603.08993 (Mar 2026, found 21 contradictions in Claude Code v2.1.50) | §10, §11.A |
| Sequential e-value falsifier framework | POPPER arXiv:2502.09858 (ICML 2025, snap-stanford/POPPER OSS) | §11.B, §13.6 |
| APC 0-12% accuracy critique | arXiv:2602.18922 (Mar 2026) | §10.1 |
| LLM-generated instructions hurt performance | Gloaguen et al. 2026 | §9 (meta-investigation safety) |
| Session = append-only event log, not transactional state | Anthropic Managed Agents (Apr 2026) | §4 (long-term refactor) |
| DGM archive of reverted variants | Sakana arXiv:2505 | §9 |

**Counter-positions held against the reviewer:**

- *"Arbiter audit costs $0.27 — fork the GitHub impl"* — Arbiter
  requires **cross-vendor** (multi-model) by design. anko has only
  Claude Max OAuth (no Anthropic API key, no Gemini/GPT-4 key). A
  Claude-only approximation reduces to **adversarial critic with
  deliberately-different system prompt** — partial protection only.
- *"POPPER α=0.10 fixed"* — needs **Bonferroni correction
  α/N_active ≈ 0.004** per investigation across ~23 active threads.
  Reviewer didn't mention multiplicity correction.
- *"judge.py reads raw artifact paths"* — done via FORM B shell
  hook (`check_cmd` + `expect`), NOT LLM-eval against raw artifacts.
  Subprocess-based deterministic check on allow-listed read-only
  programs. Reviewer's wording could imply LLM-eval; my impl is
  strictly programmatic.

---

## 12. What's WORKING well

- The investigation thread state model (kind/flow_template/stages_done/
  falsifiers/tier_current/tier_target) is decent.
- The declarative §6 contract (success_criteria + failure_modes +
  observable_manifest + budget) is clean and judge.py evaluates it well.
- The Tier ladder is unambiguous when honored.
- The meta-investigation auto-spawn pattern catches real loop pathologies.
- Memory system (MEMORY.md index + per-topic files + touch log) keeps
  context lean across sessions.
- Cost auditing (predicted vs actual) surfaces budget calibration errors.
- The scheduler / quota gate prevents OOM and 5-hr-quota burnout.
- Token usage is consistent ~1-2M effective per turn.

---

## 13. Open questions for the second-opinion session

1. **Is the right structure**: monolithic agent.md per role, or
   thin-shell agent.md that delegates to a single policies/ spec?

2. **How to encode "rewrite, don't patch"**: at lint level? at agent
   protocol level? Force director.md ≤ 200 lines via auto-spawn meta if
   exceeded?

3. **How to make active_investigation_id LOAD-BEARING** so a human
   override actually locks the next-turn director choice?

4. **Should subagents read agent.md once, or just per-turn?** Currently
   per-turn; bash re-loads on each `claude -p`. Caching wouldn't save
   much (Claude Code already does prompt caching).

5. **Decision-tree vs section-list**: would a DSPy-style declarative
   `Signature(input_fields, output_fields) -> action` model with a
   strict YAML schema beat the current Markdown-with-numbered-sections?
   Or does the freeform Markdown still win for orchestrator-level work?

6. **Falsifier discipline**: currently each investigation has 3-4
   falsifiers but only one needs to PASS for tier closure (Matsui case).
   Should the contract require ALL falsifiers tested + at least N PASS?

7. **Tier closure gate**: should Tier-3 require the published group's
   CENTRAL result, not just a side metric? How to encode "central
   result" in a machine-checkable way?

8. **Researcher depth default**: should it auto-upgrade to deep when
   tier_target == 3? Currently director must explicitly request it.

9. **Cross-investigation broadcast**: `recent_findings` queue posts
   for 10 turns. Is this length right? Is the broadcast actually
   read?

10. **What's the right abstraction for "consume existing artifacts
    before building new"?** A `runs/` index agent that the director
    must read? A pre-flight checklist in the contract schema? A new
    role like `archivist`?

---

## 14. Reference

- Memory: `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/MEMORY.md` (index)
- Agent files: `/home/suzume/workspace/BEC-simulation/.claude/agents/*.md`
- Scripts: `/home/suzume/workspace/BEC-simulation/.claude/scripts/*.{py,sh}`
- State: `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json`
- Research artifacts (completed 2026-05-19):
  - `runs/_loop/research/agent_prompt_failure_modes_2026_05_19.md` (23 sources)
  - `runs/_loop/research/agent_prompt_design_anthropic_openai_2026_05_19.md` (27 sources)
  - `runs/_loop/research/agent_prompt_design_academic_frameworks_2026_05_19.md` (15 sources)
  - `runs/_loop/research/agent_prompt_rewrite_synthesis_2026_05_19.md` (8 sections)
- Project root: `/home/suzume/workspace/BEC-simulation/`
- Codebase context: `/home/suzume/workspace/BEC-simulation/CLAUDE.md`

## 15. Implementation log (2026-05-19 session)

| Time | Item | Status |
|------|------|--------|
| 22:56 | loop.sh restart with new hooks (contract_cache, conclusions, twice, judge_patch, forgetting) | done |
| evening | 3 parallel research dispatches (failure-modes / Anthropic/OpenAI / academic frameworks) | done |
| evening | Synthesis doc `agent_prompt_rewrite_synthesis_2026_05_19.md` written | done |
| evening | External reviewer critique received via parallel Claude session | done |
| evening | **Reviewer #2** (central falsifier gate): `falsifier_central_migration.py` + `judge.py:_check_central_falsifier_for_tier3` + `loop.sh` tier_cap clamp. Verified on T86 replay (Matsui closure now blocked, tier_cap=2.75) | done |
| evening | **Reviewer #1** (FORM B raw-artifact criteria): `judge.py:_evaluate_shell_criterion` with allow-listed programs (julia/python3/jq/grep/etc.). Verified on 3 smoke tests | done |
| done | **Reviewer #6** APC 5-template adapt audit → **APC pulled** (director has no Bash; skeleton was last-seen copy not class-generic). Report: `runs/_loop/research/apc_audit_2026_05_19.md` |
| done | **Reviewer #3** Arbiter-style adversarial audit. v1 director.md: 23 interference pairs (>CC v2.1.50's 21). Report: `runs/_loop/research/director_arbiter_audit_2026_05_19.md` |
| done | 5-file rewrite (DSPy/Markdown two-tier design). Total 2119 → 789 lines (63% reduction). Per-file lines: director 575→241, theorist 545→123, researcher 362→134, implementer 380→155, critic 257→136. References cached in `.claude/agents.references/` (AI Scientist v1 verbatim) |
| done | v2 director re-audit: 8 interferences (vs v1's 23). P1-P4 RESOLVED. 3 surgical patches applied. Report: `runs/_loop/research/director_arbiter_audit_v2_2026_05_19.md` |
| done | **Atomic swap** at 02:26 — `.claude/agents/` is now v2, v1 in `.claude/agents.v1.bak/`. Loop restarted PID 1269003. |
| done | **P4 slice-regression CI** — 20-turn baseline pinned to `runs/_loop/regression/turn_*.expected.json`. Test: `python3 .claude/scripts/regression_test.py run` (Ma 2023 arXiv:2311.11123 slice-level pattern). Green baseline established. |
| pending | POPPER sequential e-value framework | (future) |
| pending | active_investigation_id hard-lock in loop.sh | (future) |
| pending | P8 declarative dispatch as Python function | task #41 |
