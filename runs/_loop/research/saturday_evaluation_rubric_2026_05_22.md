# Saturday (2026-05-22 onwards) resume evaluation rubric

**Pre-specified BEFORE data collection** to avoid anchoring bias when interpreting restrict-mode 6-turn results. Read this BEFORE looking at any turn output. Apply mechanically.

Written 2026-05-20 evening, after quota hit 95% Tuesday. Loop has been halted since Wed 05:03 (permission gate incident, 74 retries).

---

## What we're evaluating

The first 6 turns after quota reset (Saturday). The loop runs with:
- Sonnet downshift (all subagents except theorist via Bash; theorist also Sonnet for Phase 1 ablation)
- critic_lite Haiku tier
- central-falsifier gate + FORM B raw-artifact check
- director_pick.py deterministic investigation selection
- seed.md hard-lock on F-ladder portfolio
- daily_cap=6, inter_turn_sleep=1800s
- run_loop_helpers.py replacing 17 compound bash blocks
- --model sonnet --exclude-dynamic-system-prompt-sections --max-budget-usd 0.50
- investigation_budget_cap.py per-turn check

Combined hypothesis: above changes drop median cost/turn from 1.5M → ~0.8M, reduce retry_ratio from 67% F=6 baseline, and produce 1-2 clean F-ladder Tier-3 closures in 6 turns.

---

## Pass / Fail metrics (pre-committed)

### A. Infrastructure metrics (binary GREEN required)

| Metric | Target | Yellow band | RED |
|---|---|---|---|
| `exit=1` retry events | 0 | 1-3 | ≥ 4 |
| Permission-gate "Contains shell syntax" errors | 0 | 1 | ≥ 2 |
| Turn TIMEOUT (>40 min) | 0 | 1 | ≥ 2 |
| `loop.sh` death mid-window | 0 | — | 1 |
| `--max-budget-usd 0.50` firing | 0 | 1 | ≥ 2 |

Any RED → halt immediately, diagnose, do not auto-continue.
Yellow → continue, log, evaluate at end of 6 turns.

### B. Cost metrics (median over 6 turns)

| Metric | Pre-reform baseline | GREEN | Yellow | RED |
|---|---|---|---|---|
| Per-turn effective tokens | ~1.5M (Opus mix) | ≤ 0.8M | 0.8-1.2M | ≥ 1.5M |
| cache_hit_rate | 92.4% (T123) | ≥ 92% | 80-92% | < 80% |
| critic_lite escalation rate | n/a (new) | 5-60% | 0-5% or 60-80% | < 0% or > 80% |
| Day total token spend | ~30M (pre-reform daily) | ≤ 6M | 6-15M | ≥ 15M |

`critic_lite escalation < 5%` = Haiku silently passing physics judgment (DANGER).
`critic_lite escalation > 60%` = no point splitting (revert to single critic).

### C. Quality metrics (per-turn)

| Metric | GREEN | Yellow | RED |
|---|---|---|---|
| Sonnet theorist retry_ratio | < 50% | 50-67% | ≥ 67% (matches Opus F=6 baseline) |
| Clean Tier-3 closures (n_turns ≤ 7, tier ≥ 3) | ≥ 1 in 6 turns | 0 in 6 turns | — |
| central-falsifier gate firing (any false closure blocked) | as-needed | — | gate failed to fire on a known false case |
| investigation_budget_cap soft advisories | 0 (new portfolio) | 1 | ≥ 2 (means stuck pattern returning) |

### D. Portfolio progression

| Metric | Before (now) | Expected after 6 turns | Yellow | RED |
|---|---|---|---|---|
| n_firm_tier3 (clean) | 4 | 4-5 | 4 (no progress) | 3 or less (regression) |
| sunk_cost_ratio | 0.445 | ≤ 0.40 | 0.40-0.50 | > 0.50 |
| cost_per_firm_tier3 | 11.9M | ≤ 11M | 11-15M | > 15M |
| F-ladder Tier-3 advance (F=11 Te_1 or new F) | 0 progress | 1 progress (Hypothesize→Design) | same stage | tier_clamped |
| Matsui paperwork closure | tier 2.5 stuck | tier 3.0 emitted | still 2.5 | regression to 2.0 |

---

## Decision tree

After 6 turns complete (or daily_cap halts loop):

```
if any RED in section A:
    halt-and-diagnose (do not auto-resume)
    create memory entry "incident_<date>_<symptom>.md"
    continue ONLY after root cause + fix
elif any RED in sections B/C/D:
    pause restrict-mode (do not raise daily_cap)
    investigate single failed metric
    targeted fix, then 1 more measurement turn
elif ALL GREEN:
    continue restrict-mode through 2026-05-26
    start backlog #1/3/5/6 design discussion (post-data)
elif yellow-mix:
    case-by-case judgment:
        - cost yellow + quality green → continue, may need tuning
        - quality yellow + cost green → re-evaluate Opus revert for theorist
        - both yellow → halt-and-think before next 6 turns
```

---

## Specific data points to record (manual checklist)

Before declaring evaluation complete, capture these to `runs/_loop/research/saturday_actual_2026_05_22.md`:

- [ ] Total turn count completed (0-6)
- [ ] Per-turn list: `turn N: judge=<status>, inv=<id>, eff=<tokens>M, cache_hit=<rate>, model=<sonnet|haiku>`
- [ ] critic_lite invocation count + verdict distribution
- [ ] Any director_pick.py decisions overridden by director (should be 0)
- [ ] Any FORM B check_cmd successes/failures (track for shell-hook reliability)
- [ ] OTEL `portfolio` snapshot before + after
- [ ] OTEL `retry-cost` snapshot before + after (per-investigation diff)
- [ ] anko's reading: emotion state when reviewing data (Sat ~? hours sleep)
- [ ] Whether ANTHROPIC_API_KEY remained unset throughout (manual env check)

---

## Anti-bias guards

Common biases to actively defend against:

1. **Recency-anchored optimism**: "0.8M/turn vs 1.5M baseline is HUGE improvement" — only if it's also reliable. Cost reduction at the price of even 1 retry incident is net loss.

2. **Sunk cost reasoning**: "I built 7 things tonight, they should work" — they should work, but if they don't, the metrics expose it. Don't argue with metrics.

3. **Quota-saving FOMO**: "Quota was 95%, every saved turn feels victorious" — but a saved turn from a halted loop is not a win. Productivity per token matters.

4. **Pattern over-fitting**: "F=11 Te_1 success means F-ladder generalizes" — n=1 is anecdote. Wait for F=10 / F=12 also working before claiming generalization.

5. **Reform-narrative confirmation**: "tonight's reforms must work because they were designed thoughtfully" — designed thoughtfully ≠ correct. The 2026-05-19 permission gate incident is a recent reminder.

6. **Authority bias**: External reviewer says "good" — but cross-check with metrics. Same applies to my own (anko's) intuition: cross-check with metrics.

---

## What this rubric is NOT for

- Not for evaluating individual physics results. Tier ladder gate handles that.
- Not for judging anko's discipline or my (Claude's) capability. Just measures the system.
- Not for projecting beyond Saturday. Restrict-mode reset on 2026-05-26 is a separate decision.

---

## Reference

- [[established-tier3-trajectories]] — pre-Saturday Tier-3 baseline
- [[tier3-cost-economics-6-day-retrospective]] — cost economics from 6-day data
- [[hypothesis-opus-f6-spinor-retry-burn]] — ablation hypothesis being tested
- [[design-backlog-post-reform-2026-05-19]] — 6 items deferred to post-data
- `runs/_loop/seed.md` — restrict-mode portfolio
- `runs/_loop/debug/permission_gate_incident_2026_05_19_to_20.log` — incident reference

Application timing: read THIS file before opening any T124+ data on Saturday morning. Apply rubric mechanically. Record actual observations to companion file `saturday_actual_2026_05_22.md`. Do NOT mix interpretation with measurement.
