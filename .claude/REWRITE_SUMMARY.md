# Agent rewrite v2 — Summary for atomic swap decision (2026-05-19)

## What this is

5 agent files staged in `.claude/agents.v2/` ready to replace `.claude/agents/`. The rewrite addresses external reviewer feedback + 3 internal research reports + Arbiter audit findings.

## Line count change

| File | v1 (current) | v2 (staged) | Reduction |
|---|---|---|---|
| director.md | 575 | 241 | 58% |
| theorist.md | 545 | 123 | 77% |
| researcher.md | 362 | 134 | 63% |
| implementer.md | 380 | 155 | 59% |
| critic.md | 257 | 136 | 47% |
| **Total** | **2119** | **789** | **63%** |

## Structural changes

| Aspect | v1 | v2 |
|---|---|---|
| Numbered sections (`§B1.0` etc.) | 29 anchors across files | 0 |
| CAPS markers per 100 lines (director) | 2.26 | 1.2 |
| Cross-section interferences (director, per Arbiter audit) | 23 (10 HIGH) | TBD — re-audit in flight |
| Dangling citations (`Per : ...`, `(D1/D2/D3, )`) | 3 | 0 |
| Decision-tree IF-ELSE prose | many | replaced with decision tables |
| Output format | mixed Markdown + JSON | JSON schemas first; prose minimal |
| Worked examples | director only, 1 | director 1 (full); theorist/researcher/implementer/critic embed inline |
| AI Scientist v1 verbatim references | none | 3 (theorist, implementer, critic) — `.claude/agents.v2/references/aisci_v1_*.py` |
| Halt token (`I am done`) | absent | theorist only (per AI Scientist v1 pattern) |
| FORM B raw-artifact criteria (judge.py shell hook) | absent | director schema + worked example use it |
| central falsifier gate (Tier-3) | unenforced | director schema + critic B8 check |
| D4 axis for meta/audit | absent (P3 contradiction) | declared explicitly |
| Quota precedence over depth | absent (P4 contradiction) | "quota wins" explicit |

## How v2 addresses each Arbiter P1-P5 (HIGH severity)

| Audit finding | v2 resolution |
|---|---|
| P1 — artifact-first vs flow-template stage | v2 decision table: "For active topic, runs/<topic>*/ exists ... → **Artifact-first path (bypasses flow_template stage order)**: set `stage_advancing_to = Update`, `subagent_type = critic`" |
| P2 — director's Write lock vs meta subagent | Identity section explicit: "Your `Write` tool may only write `runs/_loop/director/turn_${N}.md`. The subagents you dispatch have their own `Write` tool grants per their agent files; that is via the §6 contract, not via your direct action." |
| P3 — D1/D2/D3-only vs meta/audit | New "Project axes" section: D1/D2/D3/D4 — D4 = scheduler-mandated loop infrastructure (meta-improvement / audit-class-scan). Required field `project_axis` in §6 contract |
| P4 — quota vs researcher_depth | "Quota precedence (overrides depth defaults)" subsection: downgrade depth on insufficient budget; "Quota wins. Always." |
| P5 — Bash example vs no Bash tool | v2 uses `Glob: runs/<topic>*/` notation; worked example rationale uses Glob terminology |

## Reference patterns adopted

- **director.md**: LangGraph (decision table for state→action) + Claude best-practice contract (XML-style structure, JSON output, precedence-at-end)
- **theorist.md**: AI Scientist v1 `generate_ideas.py` (idea_system_prompt + first_prompt + reflection_prompt + halt token "I am done") + DSPy Signature (typed I/O contract)
- **researcher.md**: Voyager curriculum (pure retrieval, restricted tools) + AI Scientist v1 lit-search (found/not_found/gaps JSON, no write to src)
- **implementer.md**: AI Scientist v1 `perform_experiments.py` `coder_prompt` + ReAct format (strict command convention, exact regex output)
- **critic.md**: AI Scientist v1 `perform_review.py` reviewer_system_prompt_neg + Reflexion (THOUGHT/REVIEW JSON with numerical fields)

Source files cached: `.claude/agents.v2/references/aisci_v1_*.py`

## Atomic swap procedure (when ready)

```bash
cd /home/suzume/workspace/BEC-simulation

# 1. Snapshot v1 for emergency rollback
cp -r .claude/agents .claude/agents.v1.bak

# 2. Stash references separately (they stay in agents.v2/references/, not under agents/)
mv .claude/agents.v2/references .claude/agents.references

# 3. Atomic swap
rm -rf .claude/agents
mv .claude/agents.v2 .claude/agents
mv .claude/agents.references .claude/agents/references

# 4. Verify (no broken paths in scripts that reference agent files)
grep -rE "\.claude/agents/" .claude/scripts/ docs/ | grep -v "agents.v2\|agents.v1" | head

# 5. (Re)start loop
bash .claude/scripts/loop.sh > .claude/logs/loop_postrewrite_$(date +%s).out 2>&1 &
```

## Risk

The rewrite changes director.md most significantly. The new §6 contract schema adds fields (`project_axis`, FORM B `check_cmd`/`expect` criteria, central-falsifier requirement). `judge.py` was updated to read these. `loop.sh` was updated to apply `tier_cap` clamp.

Backward compatibility: the new schema is a SUPERSET of v1. Existing turns' contracts (without `project_axis`) will still parse; only NEW turns will be required to specify it.

If atomic swap goes wrong: `mv .claude/agents .claude/agents.v2 && mv .claude/agents.v1.bak .claude/agents` restores v1 in 1 second.

## Verification before swap (recommend)

- [x] Each v2 file ≤ target line budget (see comparison table)
- [x] Zero numbered §B-style sections
- [x] CAPS density ≤ 5 per 100 lines (director: 1.2)
- [ ] Arbiter re-audit on v2 director.md (re-audit in flight)
- [ ] anko reviews and approves

## What this does NOT include

- POPPER sequential e-value framework (separate 2-day task)
- `active_investigation_id` hard-lock in loop.sh (separate task)
- P4 slice-regression CI on 20 pinned turns (separate task)
- P8 declarative dispatch as Python function (opportunistic future task)
- Per-investigation curation of `is_central` falsifier (auto-picker chose first-falsifier for non-Matsui cases; revise case-by-case in follow-up)
