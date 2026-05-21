# Deferred improvements — loop architecture

Items that the third/fourth audit identified but are too big to land
in maintenance windows. Each has enough scope that they deserve their
own design discussion or follow-up session.

## Recently completed (this session, 2026-05-14)

- ✅ **G. tokens_used wiring** — `extract_turn_tokens.py` rewritten
  to parse Anthropic stream-json correctly (input/cache/output
  decomposed; previous version double-counted cumulative deltas).
  `loop.sh` post-step patches BOTH sim §4 metrics AND state.history
  entry, then re-runs judge so cost cap sees real numbers.
- ✅ **H. agent .md hash recording** — `/run-loop.md` Step 0d
  captures MD5 of each agent file into `current_agent_hashes`;
  Step 6a-bis copies into the per-turn history entry.
- ✅ **R. dispatch action enum** — `/run-loop.md` Step 3b validates
  `directive.action` against the 5-item enum (noop, run_experiment,
  modify_code, analyze_existing, compute_sympy) and halts with
  `last_error` if invalid.
- ✅ **S. cost cap (proper threshold)** — `judge.py` has two caps:
  `cost_cap_per_turn_effective: 3_000_000` (Anthropic billing-weighted
  tokens; observed ~1M typical) and `cost_cap_per_turn_raw: 35_000_000`
  (raw any-source tokens; observed ~7M typical). FAIL_PHYSICS on
  exceed.
- ✅ **A1. sympy path** — `compute_sympy` action + `compute_steps`
  field added to theorist directive schema; implementer C3 handler
  invokes `.claude/scripts/run_sympy.py` which uses
  `uv run --with sympy python3` (ephemeral, no persistent venv).
  Smoke verified: `integrate(x**2, x) → x**3/3` runs end-to-end.
- ✅ **B2. convention §0** — theorist output schema §0 prepended:
  forces explicit declaration of sign/normalization/factor
  conventions before §1, with `Grep` verification against
  production code.
- ✅ **B3. publishability §8** — theorist output schema §8 appended:
  optional but encouraged when a turn produces a paper-scale
  finding; maps to `docs/manuscript/papers/...` chapter.
- ✅ **Bug-X. state.json branch/commit recording** —
  `extract_branch_commit.py` parses implementer's sim §2,
  loop.sh post-step patches history entry with branch + commit +
  parent SHA.

## Deferred items

### B1. multi-deliverable directive (Tier-2)

**What**: `§6 action: "multi"` allowing a JSON array of
sub-deliverables `[{id: "D1", action: ..., depends_on: [...]}]`,
implementer iterates in dependency order, judge aggregates per-D
verdicts.

**Why deferred**: requires orchestrator state machine changes
(/run-loop.md Step 4 needs to handle multi as a fan-out, judge.py
needs aggregation logic). The exemplar's Round 2 5-deliverable
bundle motivates it, but no current seed uses this format. Single-
deliverable turns chain naturally via cross-turn context (Tier-2 J).
Implement when anko queues bundled-request seeds.

### C3. iterative refinement / same-turn 2-pass (Tier-2)

**What**: `§6 action: "refine"` triggering a second theorist pass
within the SAME turn after implementer compute results are in. E.g.
turn N theorist emits compute_steps, implementer runs sympy, theorist
re-dispatched with `runs/_loop/sim/turn_N.md` as additional context
and writes a FINAL `runs/_loop/theorist/turn_N.md` overwriting the
first-pass.

**Why deferred**: A1 (compute_sympy) already enables the workflow
via TWO turns (compute in turn N, synthesize in turn N+1). The
same-turn refine is a wall-time optimization, not a capability gain.
Worth implementing once compute_sympy proves valuable in practice.

### M. loop dashboard (Tier-3)

**What**: web UI at `dashboard/loop/` showing turn history, token spend
trend, pass-rate, branch tree. Anko's morning-review accelerator.

**Why deferred**: builds on existing `dashboard/` React + WebGPU stack.
Multi-day implementation (React component, data fetch from
`runs/_loop/state.json` and per-turn markdown). Worthwhile only
once the loop has ≥ 50 turns of data to visualize.

### Q. multi-machine coordination (Tier-4)

**What**: TSUBAME-side loop runs that share state with local-side
loop. Currently state.json is single-machine; running on both
diverges.

**Why deferred**: requires architectural choice — git push/pull
sync (slow, race-prone), S3/MinIO state backend (infra heavy), or
"explicitly serial" (anko runs locally OR on TSUBAME, never both).
Resolution depends on anko's actual TSUBAME workflow. Discuss before
implementing.

### T. critic blind enforcement via permissions (Tier-4)

**What**: Currently critic subagent is told "read only these 2 files"
via prompt, but it CAN read other files (its tools include `Read`).
Real enforcement would need a per-subagent permission profile that
restricts `Read` to specific paths.

**Why deferred**: Claude Code's permission system doesn't support
per-subagent allow/deny scopes — settings are session-wide. Working
around this would require a wrapper that spawns critic in a separate
restricted process. Not feasible without Claude Code feature changes.

**Workaround for now**: trust the prompt-level instruction in
critic.md Section A1. Periodically audit critic outputs for
file-read leaks via `.claude/logs/`.

## Items considered but rejected

- **Move loop history to a separate `loop-history` branch instead of
  main**: rejected because filter via `git log --grep="^auto(loop)"`
  is easier than maintaining a parallel branch.
- **Spawn implementer in a git worktree per turn**: rejected because
  the current "implementer creates auto/turn_N branch" achieves the
  same isolation with simpler tooling.
- **Replace bash hook scripts with Python**: rejected because bash is
  already runtime-available and the hook scripts are too small to
  benefit from Python's structure.

## Cross-references

- The 8 Tier-1 fixes from audit pass 2: see git log `auto(loop):` and
  `chore(loop):` commits on main (2026-05-14).
- The 7 Tier-1/2/3 fixes from audit pass 3: this session's
  improvements (loop.sh timeout + log rotation + trap, judge.py
  try/except, run-loop.md regex narrow / consecutive-fail halt /
  flock / force_critic, theorist.md cross-turn + force_critic,
  state.json schema_version, status.sh, gpu_lock.sh,
  extract_research_queries.py, auto_pr_template.md, this file).
