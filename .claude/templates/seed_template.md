# seed.md template — long-running session spec (Upgrade E, Initializer pattern)

Anthropic's "Effective Harnesses for Long-Running Agents" (2025) shows that
multi-day agent runs converge on a two-agent split: an **Initializer** writes
a 200+ feature spec + init.sh + first commit, and a **Coding agent** then
executes feature-by-feature, reading the spec each session.

For our research loop, the analog is: anko (or a one-shot setup turn) writes
a SESSION SPEC into `seed.md` that the director reads every turn for
duration of the session. The spec is durable; only anko changes it
mid-session. Director can override only with explicit rationale.

This template documents the recommended spec format. Copy + fill in
when launching a long-horizon session (>10 turns).

---

# Session spec — <session_name>

## Session goals

3–7 numbered goals, each with a measurable definition of "done":

1. <goal 1, e.g. "Land Paper #4 Chapter 2 (LHY framework) — Stuttgart Dy
   convention vs SpinorBEC.jl implementation cross-validated, at least 3
   benchmark points within 5% of published values">
2. <goal 2, e.g. "Eu-151 v4 spinor FG extension implemented, F=2 cyclic
   bench passes order-4 collapse at α_3 = -1/72">
3. <goal 3, ...>

## Priority order

Goals listed in priority order. If a turn's leverage analysis suggests
working on goal 3 instead of goal 1, director must explicitly justify in
its §6 rationale ("I am overriding spec priority because ...").

## Hard constraints (immutable this session)

- Memory pressure: <e.g. "Julia phi sweep running 4-parallel; do NOT
  spawn julia from implementer turns; researcher/critic/text-only OK">
- Cost cap: <e.g. "≤ 100M effective tokens this session (~80 turns at
  1.2M/turn budget)">
- Forbidden actions: <e.g. "No `git push`, no auto-merge of auto/
  branches to main, no Edit on CLAUDE.md">
- Time budget: <e.g. "Halt by 2026-05-16 08:00 JST regardless of state">

## Excluded topics (do NOT pursue this session)

- <e.g. "Klaus magnetostir reproduction — deferred to post-sweep">
- <e.g. "Universal Theorem F=12 verification — not on this session's
  critical path">
- <e.g. "F=6 polar FullBdGLHY F-δ fix implementation — needs Julia run,
  defer">

## Reference materials this session

Files / memory entries director should pre-read at session start:

- `runs/_loop/research/long_horizon_design.md` (architecture)
- `MEMORY.md` entries: `<list specific entries relevant to goals>`
- Manuscript sections: `<list manuscript paths in flight>`
- Recent commits: `<git ref / hash>`

## Milestones with check-in turns

After every N turns, director should produce a §5 "Calibrated progress
check" against THIS spec's goals:

- After T_{start+10}: progress check, halt if no goal advanced 20%
- After T_{start+25}: re-prioritize if a goal is blocked
- After T_{start+50}: anko review checkpoint (status = paused, await
  human review)

## Allowed subagent dispatch profile

Limit director's routing this session to a subset:

- ✓ theorist (for derivations supporting goals 1-3)
- ✓ researcher (for literature verification, especially goal 1)
- ✓ implementer (for goal 2 code changes ONLY — read constraint above)
- ✓ critic (for any [Established] claim that's load-bearing for a paper)
- noop allowed when goals all blocked

## anko's notes (free form, optional)

Anything else director / theorist / etc. should know — context, prior
art, "I tried X and it didn't work", etc.

---

## How to use this template

1. Copy the template to `runs/_loop/seed.md` before launching
2. Fill in goals, priorities, constraints, etc.
3. Commit to git (it's tracked under runs/_loop/)
4. Launch `LOOP_MAX_TURNS=N bash .claude/scripts/loop.sh`
5. After N turns or check-in milestones, anko reviews + optionally
   updates seed.md mid-session (director re-reads each turn)

## What's different from the old seed.md format

Old format: free-form prose, often ad-hoc per-turn. Director honored
but had full autonomy to override.

New format: structured spec with measurable goals + immutable constraints
+ explicit allowed/excluded topics. Director still has autonomy, but
must explicitly justify any override of spec priorities.

This shift matters at 100+ turn sessions where director's free-form
interpretation can drift far from anko's actual intent without
anko realizing.
