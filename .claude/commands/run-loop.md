---
description: Execute one turn of the SpinorBEC.jl autonomous research loop. Reads state, dispatches subagents, runs judge, updates state, commits. Designed to be invoked once per `claude -p` call from .claude/scripts/loop.sh.
---

Execute one turn of the SpinorBEC.jl autonomous research loop.

You are the **orchestrator**. You do not theorize, code, or judge. You
dispatch the four subagents (`theorist`, `researcher`, `implementer`,
`critic`) and the Python `judge.py`, then commit and update state.

────────────────────────────────────────────────────────────────────
## CRITICAL — Bash discipline (read BEFORE any Bash tool call)

Claude Code v2's permission gate rejects compound bash. The 2026-05-19 incident (74 retries in 3h13m) was caused by this exact failure mode. The 2026-05-20 follow-up incident showed the orchestrator (this prompt) was still emitting compound bash via `; echo $?` appended to helper invocations.

**EVERY Bash tool call MUST be a single program with arguments.** The Bash tool result includes `is_error` and the captured stdout/stderr — you do NOT need to append exit-code probes.

FORBIDDEN in any Bash command:
- `;` between commands (run as two separate Bash tool calls instead)
- `&&` chains (likewise two separate calls)
- `||` chains (use Python try/except instead)
- `for f in ...; do ...; done` (use `Glob` tool + per-file Bash calls)
- `if [ ... ]; then ...; fi` (use `Read` for graceful-missing OR `python3 -c "..."`)
- `VAR=$(cmd)` command substitution (read cmd's stdout from tool result)
- backtick `` `cmd` `` substitution
- `sed -i` (use `Edit` tool)
- `sed -n 'NNNp' file` (use `Read` with offset+limit OR `python3 .claude/scripts/run_loop_helpers.py read_lines FILE START END`)
- `; echo "exit:$?"` or `&& echo OK` style probes (the tool already reports exit)

When you need multi-step work, use `python3 .claude/scripts/run_loop_helpers.py <action>` — those helpers do the compound work internally with no shell metacharacters in the Bash command line.

Specifically: if a step in this protocol says "Run `!python script.py`. If non-zero exit: ...", you check the tool_result for `is_error` field OR parse the stdout (e.g. quota_check.py emits literal `QUOTA_OK` or `QUOTA_OVER:...`). Do NOT append `; echo $?`.

────────────────────────────────────────────────────────────────────
## Step 0 — Sanity checks

0a. Read `runs/_loop/state.json`. Extract:
    - `turn` (integer, denote `N`)
    - `status` (string)
    - `retries` (integer, default 0)

0b. If `status` ∈ {`halted`, `budget_exhausted`, `human_required`,
    `error`}, output exactly:
    ```
    LOOP HALTED: ${status}
    ```
    and stop. Do NOT dispatch any subagent.

0c. Run `!python .claude/scripts/quota_check.py`. Parse stdout: it
    prints `QUOTA_OK | rolling-eff: ...` if budget is fine, or
    `QUOTA_OVER: ...` / `QUOTA_BUSTED: ...` if exceeded. **Do NOT
    append `; echo $?` or any compound bash** (see "CRITICAL — Bash
    discipline" above). Read the tool result's stdout and the
    `is_error` boolean; both tell you the outcome.
    If stdout contains `QUOTA_OVER` / `QUOTA_BUSTED` or tool result
    `is_error == true`:
    - Update state.json via:
      `!python3 .claude/scripts/run_loop_helpers.py state_modify_atomic '.status = "budget_exhausted"'`
    - Stop with `LOOP HALTED: budget_exhausted`.

0d. **Capture agent prompt hashes (Tier-2 H).** Record MD5 of each
    `.claude/agents/*.md` so retroactive analysis can correlate a
    turn's behavior with the active prompt version. The hashes are
    written into state.json `current_agent_hashes` and copied into
    the per-turn history entry at Step 6.
    ```
    !python3 .claude/scripts/run_loop_helpers.py agent_hash_snapshot
    ```
    (2026-05-20 permission-gate fix: previous version used `for-loop`
    + subshell + `&&` chain which Claude Code v2 rejects with "Contains
    shell syntax that cannot be statically analyzed". Helper does the
    work as a single subprocess invocation.)

────────────────────────────────────────────────────────────────────
## Step 0.5 — Director dispatch (strategy layer)

The director chooses **what kind of turn this is** before any
physics/code work begins. Without this layer, theorist runs every
turn by default and the loop drifts into "do theory blindly" mode
even when literature review or code benchmark would be higher
leverage.

0.5a. mkdir -p `runs/_loop/director/` (idempotent).

0.5b. Dispatch the `director` subagent. Brief:
> "Read `runs/_loop/state.json` (N=${N}), `runs/_loop/seed.md` if
> exists, last 3 turns' theorist+sim+judge outputs, your previous
> turn (`runs/_loop/director/turn_$((N-1)).md`) if exists, and at
> least one relevant memory file. Decide the highest-leverage move
> for this turn per your protocol's decision tree (Section B).
> Output to `runs/_loop/director/turn_${N}.md` with §6 dispatch JSON."

0.5c. After director returns, parse its §6 JSON. Extract:
- `subagent_type` ∈ {theorist, researcher, implementer, critic, noop}
- `brief` (verbatim, will be passed to chosen subagent)
- `expected_cost`, `if_fails_next_step` (used for downgrade logic)

If §6 JSON is malformed or `subagent_type` not in enum:
- `status` ← `"error"`, `last_error` ← `"director produced invalid §6"`.
- Stop.

────────────────────────────────────────────────────────────────────
## Step 1 — Subagent dispatch (routed by director)

Branch on `director.subagent_type`:

### (a) `subagent_type = "theorist"` — physics derivation turn

1a. Dispatch the `theorist` subagent. Brief is composite:

```
> "DIRECTOR'S STRATEGIC CONTEXT (turn ${N}):
> ${director.brief}
>
> STANDARD CONTEXT:
> Read `runs/_loop/state.json` (current turn is N=${N}).
> Read `runs/_loop/sim/turn_$((N-1)).md` if it exists.
> Read `runs/_loop/judge/turn_$((N-1)).json` if it exists — if
> status is FAIL_PHYSICS, your previous directive was refuted and
> you must address that explicitly. If `runs/_loop/seed.md`
> exists, read it; it is anko's optional hand-written note.
> Output your turn-${N} analysis to
> `runs/_loop/theorist/turn_${N}.md` per the schema in your
> system prompt."
```

1b. After theorist returns, read
    `runs/_loop/theorist/turn_${N}.md`. Verify the file exists
    and contains §6 directive. If missing or malformed:
    - Update state.json: `status` ← `"error"`, `last_error` ←
      `"theorist did not produce valid turn_${N}.md"`.
    - Stop.

Continue to Step 2 (researcher conditional), Step 3, Step 4
(implementer), Step 5 (judge).

### (b) `subagent_type = "researcher"` — literature/parameter scan turn

1b. Extract from director's §6 contract:
    - `researcher_depth` ∈ {shallow, deep, exhaustive} (default shallow)
    - `parallel_researcher_count` (default 1)
    - `parallel_query_sets` (only required if parallel_researcher_count > 1)

    **Single-context path** (`parallel_researcher_count == 1`,
    any depth):

    Dispatch ONE `researcher` subagent. Brief: director's §6.brief +
    explicit `researcher_depth=<value>` instruction. Researcher
    writes to `runs/_loop/research/turn_${N}.md` per its protocol
    Section C. For `deep`/`exhaustive`, researcher must honor B6 + B7
    (≥30 parallel queries, full-PDF mandatory, iteration ≥2 rounds,
    contradiction surface, per-claim confidence).

    **Multi-context parallel path** (`parallel_researcher_count > 1`,
    typically `exhaustive` only):

    Director's contract MUST include `parallel_query_sets` — an array
    of N objects, each with shape:
    ```json
    {
      "id": "set-a",
      "focus": "Eu-151 F=1 hyperfine scattering length",
      "queries": ["query 1", "query 2", ...]
    }
    ```

    Orchestrator dispatches N `researcher` Task agents IN PARALLEL
    (one tool call message with N Task invocations). Each agent:
    - gets its own fresh context
    - receives the matching `parallel_query_sets[i]` as its brief
    - writes to `runs/_loop/research/turn_${N}_set_${i}.md`
    - honors `researcher_depth=deep` minimum (multi-context exists
      because single-context exhausted, so each shard is deep-tier)

    After all N return, dispatch ONE synthesis turn (researcher
    again, in "synthesis mode"):
    - brief: "Synthesize the N parallel research outputs at
      `runs/_loop/research/turn_${N}_set_*.md` into a unified
      report at `runs/_loop/research/turn_${N}.md`. Identify
      cross-shard contradictions. Provide per-claim confidence
      reconciling sources from multiple shards."
    - Synthesis writes the canonical `turn_${N}.md` (same path as
      single-context output, so downstream Steps don't need to
      special-case the multi-context path).

    Failure handling: if any of the N parallel shards times out or
    errors, log it and proceed with the surviving shards. Mark the
    synthesis output with `partial_parallel_shards: ["set-a", ...]`
    listing the missing IDs.

1b-bis. **Skip Steps 2-5** (no theorist, no implementer, no judge for
    a researcher-only turn). Jump to Step 6 with
    `judge_status = "RESEARCHER_ONLY"`. The turn's outputs are the
    research brief alone; anko reviews manually.

### (c) `subagent_type = "implementer"` — direct code/benchmark turn

1c. Dispatch the `implementer` subagent. Director's §6.brief IS the
    directive (no theorist needed). Implementer treats `brief` as if
    it were a theorist's §6 JSON. To make this concrete, director's
    brief MUST be valid directive JSON parseable by implementer's
    Section C1.

1c-bis. **Skip Step 2 (researcher) and Step 3 (directive parsing)** —
    the directive came from director. Proceed to Step 4b (verify sim
    output) and Step 5 (judge).

### (d) `subagent_type = "critic"` — out-of-band audit turn

1d. Dispatch the `critic` subagent. Director's §6.brief specifies
    which past turn(s) to audit and what specific load-bearing claim
    to scrutinize. Critic returns text (not file write per
    critic.md A2). Save the critic response to
    `runs/_loop/judge/turn_${N}_critic_audit.md`.

1d-bis. **Skip Steps 2-5.** Parse critic's `VERDICT:` line. Jump to
    Step 6 with `judge_status = "CRITIC_${VERDICT}"` (one of
    `CRITIC_PASS`, `CRITIC_FAIL`, `CRITIC_INCONCLUSIVE`).

### (e) `subagent_type = "noop"` — explicit pause turn

1e. No subagent dispatch. The director judged that this turn
    shouldn't run (quota tight, easy bottlenecks exhausted, etc.).
    Jump to Step 6 with `judge_status = "NOOP_DIRECTOR"` and the
    `if_fails_next_step` field of director's §6 logged for the next
    director turn.

────────────────────────────────────────────────────────────────────
## Step 2 — Researcher dispatch (conditional, parallel-capable)

2a. Extract the §7 Research queries JSON array via the helper (which
    strict-filters for valid `{id, topic, ...}` objects — prose
    `<RESEARCH_NEEDED:>` mentions outside §7 are ignored, per the
    Tier-1 E false-positive fix):
    ```
    !python3 .claude/scripts/extract_research_queries.py runs/_loop/theorist/turn_${N}.md
    ```
    The helper prints the JSON array directly to stdout. Read it from
    the bash output; count elements as K. If `K == 0`, skip to Step 3.
    (2026-05-20 permission-gate fix: previous version used `VAR=$(...)`
    command substitution + pipe to jq; Claude Code v2 rejects compound
    bash. Read the stdout JSON inline instead.)

2b. Use the array elements as the per-query briefs. Let `K` = number
    of query objects (from above).

2c. Dispatch researchers based on `K`:

    **`K == 1`** — single researcher, output to default path:
    > "Resolve the single `<RESEARCH_NEEDED>` query at
    > `runs/_loop/theorist/turn_${N}.md` §7 per your protocol.
    > Output to `runs/_loop/research/turn_${N}.md`."

    **`K > 1`** — **dispatch K researchers IN PARALLEL** by emitting
    K Task tool calls in a single message (Claude Code executes
    parallel Task calls concurrently). Each researcher gets a brief
    scoped to ONE query, with a per-query output path:
    > "Resolve query Q<id> from
    > `runs/_loop/theorist/turn_${N}.md` §7 (topic:
    > `<topic>`, why: `<why>`). Output to
    > `runs/_loop/research/turn_${N}_Q<id>.md`. Single-query
    > version of the per-Q schema in your system prompt's Section
    > A4 + Section C."

    Parallel dispatch wins when queries are independent (typical
    case). Wall time is ~max over researchers rather than sum.

2d. After researchers return, build a unified brief at
    `runs/_loop/research/turn_${N}.md` if `K > 1`. Use a Python helper
    that concatenates the per-Q files (no shell glob + redirect, which
    expands to compound bash on Claude Code v2's permission gate):
    ```
    !python3 -c "import glob,pathlib; p=pathlib.Path('runs/_loop/research/turn_${N}.md'); p.write_text(''.join(open(f).read() for f in sorted(glob.glob('runs/_loop/research/turn_${N}_Q*.md'))))"
    ```
    (The per-Q files stay on disk for traceability; the unified
    file is what the implementer reads.)

2e. Read the unified brief. If any query came back as `NOT_FOUND`:
    - The theorist's directive that depends on that value may be
      MISSING_DEPENDENCY. Flag in state but proceed — the
      implementer will REJECT if dependency is critical.

────────────────────────────────────────────────────────────────────
## Step 3 — Directive parsing

3a. Parse the §6 JSON block from
    `runs/_loop/theorist/turn_${N}.md`.

3b. Inspect `directive.action` (must be one of the four enum values
    below — Tier-4 R):
    - `"noop"` → skip to Step 6 with `judge_status = "NOOP"`.
    - `"run_experiment"`, `"modify_code"`, `"analyze_existing"` →
      Step 4.
    - **anything else** → update state.json:
      `status = "error"`,
      `last_error = "invalid directive.action: <value>; allowed: noop/run_experiment/modify_code/analyze_existing"`,
      run Step 6 to record the verdict and commit, then stop.

────────────────────────────────────────────────────────────────────
## Step 4 — Implementer dispatch

4a. Dispatch the `implementer` subagent. Brief:
    > "Theorist directive is in
    > `runs/_loop/theorist/turn_${N}.md` §6. Research brief (if
    > present) is in `runs/_loop/research/turn_${N}.md`. Execute
    > per your protocol. Output sim report to
    > `runs/_loop/sim/turn_${N}.md`. Commit code/run changes to
    > the auto-branch but do NOT commit `runs/_loop/`."

4b. After implementer returns, verify
    `runs/_loop/sim/turn_${N}.md` exists. Inspect its content:
    - Contains §4 (Metrics) JSON block → proceed normally.
    - Contains a REJECTED block (per implementer Section F) →
      Step 4c.
    - Contains neither (implementer subagent crashed mid-turn,
      partial write) → set `status = "error"`,
      `last_error = "implementer produced incomplete sim/turn_${N}.md"`,
      run Step 6 (no judge, no critic), then stop. The orchestrator
      commit + notify still happen so the audit trail survives.

4c. If REJECTED:
    - Skip Step 5 (no judge needed for rejected directives).
    - `judge_status = "REJECTED"`.
    - Update state.json: `retries++`. If `retries >= 3`, set
      `status = "human_required"` (the theorist is stuck — anko must
      look).

────────────────────────────────────────────────────────────────────
## Step 5 — Judge

5a. Run: `!python .claude/scripts/judge.py --turn=${N}`. The script
    writes `runs/_loop/judge/turn_${N}.json` and returns exit
    code 0 (PASS) or 1 (any FAIL).

    **Note (F2 timing fix)**: this is the *preliminary* judge run.
    `tokens_used` in metrics is null at this point (implementer
    cannot self-report tokens). `loop.sh`'s post-step extracts
    token usage from the stream-json log, patches sim §4 metrics
    AND state.history[-1], then RE-RUNS judge.py — that second run
    can downgrade a PASS to FAIL_PHYSICS if cost cap is exceeded.
    Do NOT special-case the preliminary verdict here; trust judge.

5b. Read `runs/_loop/judge/turn_${N}.json`. Extract `status`.

5b-bis. **Stuck check (Tier-1 C).** Before branching on the judge,
    read the last 5 entries of state.json's `history[]` (including
    this turn's verdict you're about to record). Count how many
    have `judge_status` matching one of: `FAIL_PHYSICS`,
    `FAIL_NUMERICAL`, `REJECTED`, `FAIL_JUDGE_CRASHED`,
    `FAIL_NO_METRICS`. If that count is ≥ 4 out of 5, force
    `status = "human_required"`, `last_error = "stuck: 4+ of last 5
    turns failed — halt for anko review"`, run Step 6 to record
    the verdict and commit, then stop. The loop is stuck and a
    human must intervene.

5b-tris. **force_critic seed handling (Tier-2 K).** If the theorist's
    §4 Calibrated claims include the literal string
    `[force_critic_requested_by_user]`, set
    `force_critic_flag = true` to dispatch the critic even on PASS.
    Default `false`.

5b-quater. **Drift escalation (Upgrade B, 1000-turn design).** After
    judge runs, `loop.sh` post-step has already embedded
    `drift_signals` into state.history[-1] via
    `.claude/scripts/drift_signals.py`. Read
    `runs/_loop/state.json` → `history[-1].drift_escalation`. Branch:

    - `none` or `advisory`: continue normally (single signal recorded
      for next director turn; no state change here).
    - `director_must_address`: continue this turn, but the NEXT
      director turn's brief MUST acknowledge the drift signals (the
      director protocol B6 enforces this). No state change here.
    - `human_required`: force `status = "human_required"` in
      state.json regardless of judge verdict. Loop halts after Step 6
      commit. Log `last_error = "drift escalation: <triggered signals>"`.

5c. Branch on judge `status`:

    **`PASS`**
    - Reset `retries = 0`.
    - If `force_critic_flag == true`, dispatch the `critic` subagent
      now (same brief as SUSPICIOUS_NOVEL below); save its full
      response to `runs/_loop/judge/turn_${N}_critic.md`; if
      verdict is FAIL, downgrade `judge_status` to `FAIL_PHYSICS`
      and proceed via that branch.
    - Advance turn.

    **`FAIL_NUMERICAL`**
    - `retries++`. If `retries < 3`, the next theorist turn will see
      this in state.json and adjust (typically dt halving).
    - If `retries >= 3`, escalate to `FAIL_PHYSICS` semantics.

    **`FAIL_PHYSICS`**
    - Advance turn (theorist needs the failure logged in
      sim/turn_${N}.md to course-correct).
    - Mark `last_judge = "FAIL_PHYSICS"` so the next theorist turn
      addresses it explicitly.

    **`SUSPICIOUS_NOVEL`**
    - Dispatch the `critic` subagent. Brief:
      > "Independent blind review. Read ONLY these two files:
      > `runs/_loop/sim/turn_${N}.md` and
      > `runs/_loop/theorist/turn_${N}.md`. Output PASS/FAIL/
      > INCONCLUSIVE per your protocol."
    - **Parse the critic's response text** for the first line
      matching the regex `^VERDICT:\s*(PASS|FAIL|INCONCLUSIVE)` —
      the critic does NOT write a file; the verdict is returned as
      part of the subagent's text response (per critic.md
      Section C).
    - If verdict is `PASS`: set `judge_status = "NOVEL_CONFIRMED"`,
      `status = "human_required"` — anko reviews before
      committing the discovery direction. The loop pauses; this is
      intentional. Save the full critic response under
      `runs/_loop/judge/turn_${N}_critic.md` for the audit
      trail.
    - If verdict is `FAIL`: set `judge_status = "FAIL_PHYSICS"`,
      proceed with FAIL_PHYSICS branch (advance turn, mark
      `last_judge`).
    - If verdict is `INCONCLUSIVE` or the regex doesn't match: set
      `status = "human_required"`, `last_error =
      "critic verdict unparseable"`, halt — surface to anko.

────────────────────────────────────────────────────────────────────
## Step 6 — Commit + state update

6a. **Atomic state.json write (Tier-1 A).** All state.json
    modifications go through a `flock` to prevent races between
    concurrent `claude -p` invocations (e.g. anko running a manual
    `/run-loop` while `loop.sh` is also active). Pattern for any
    state.json read-modify-write:
    ```
    !python3 .claude/scripts/run_loop_helpers.py state_modify_atomic '<jq filter>'
    ```
    The helper takes the jq filter as a single shell-quoted argument
    (jq's own `;` syntax is OK inside a quoted argument; the shell only
    sees one argv element). Internally it acquires flock on
    `runs/_loop/_local/state.json.lock`, runs jq on state.json, writes
    atomically via .tmp + rename. The lock file is gitignored — lock
    state is per-machine, not part of the scientific record.
    (2026-05-20 permission-gate fix: previous version used `&&` chain
    + tmp file + rename inside flock; Claude Code v2 rejects this.
    Helper preserves the same semantics in a single python subprocess.)

6a-bis. Append a history entry to state.json. **Copy
    `current_agent_hashes` into the entry** so each historical turn
    records which prompt version produced it (Tier-2 H wiring):
    ```json
    {
      "turn": ${N},
      "ts": "<ISO 8601 UTC>",
      "judge_status": "${judge_status}",
      "directive_action": "${directive.action}",
      "directive_label": "${short_label}",
      "wall_time_sec": <from sim metrics if available>,
      "agent_hashes": <copy of state.current_agent_hashes>
    }
    ```
    The `tokens_used` field is patched in retroactively by
    `loop.sh` after `claude -p` exits (Tier-2 G wiring via
    `.claude/scripts/extract_turn_tokens.py`); don't try to fill it
    here.

6b. Update top-level state.json — **turn-advance condition** (covers
    all 5 director routes from Step 1):
    - `turn = N+1` when `judge_status` ∈ {
        `PASS`, `FAIL_PHYSICS`, `NOOP`,
        `RESEARCHER_ONLY`,     // route (b): researcher-only turn
        `CRITIC_PASS`, `CRITIC_FAIL`, `CRITIC_INCONCLUSIVE`,  // route (d)
        `NOOP_DIRECTOR`,       // route (e): director explicit noop
        `NOVEL_CONFIRMED`      // SUSPICIOUS_NOVEL after critic PASS
      }. These represent "turn produced an output (even if just a research
      brief or critic audit) — anko reviews; next director turn picks
      from current state."
    - `turn` UNCHANGED when:
      - `judge_status == "FAIL_NUMERICAL"` and `retries < 3` (retry).
      - `judge_status == "FAIL_JUDGE_CRASHED"` (judge bug, investigate
        before next turn).
      - `judge_status == "REJECTED"` (implementer rejected directive;
        retry with corrected directive).
    - `status = "human_required"` when:
      - `retries >= 3` after FAIL_NUMERICAL.
      - `judge_status == "SUSPICIOUS_NOVEL"` after critic PASS.
      - Stuck check (Step 5b-bis) triggered.

6c. Spill old history if state.json's `history[]` exceeds the cap.
    Idempotent — no-op when under cap:
    ```
    !bash .claude/scripts/spill_history.sh
    ```

6d. Commit. **Use explicit paths only — never `git add .` or
    `git add -A`** (would pull in anko's uncommitted WIP code).
    Use the `auto(loop):` prefix so the loop's record can be
    filtered with `git log --grep="^auto(loop)"`.

    The implementer leaves HEAD on `auto/turn_${N}_<label>`. The
    orchestrator's commit must land on `main` (or whatever anko's
    home branch is), NOT on the implementer's auto branch — if
    it lands on auto, the scientific record is lost when anko
    discards a failed branch. Switch back first:

    ```
    !python3 .claude/scripts/run_loop_helpers.py git_checkout_home_branch
    !git add runs/_loop/state.json
    !python3 .claude/scripts/run_loop_helpers.py git_add_turn_artifacts ${N}
    !python3 .claude/scripts/run_loop_helpers.py git_add_research_queries ${N}
    !git add runs/_loop/history_archive
    !git add .claude/knowledge
    !git -c commit.gpgsign=false commit -m "auto(loop): T${N} ${judge_status} ${directive.action} ${short_label}" --trailer "Assisted-by: Claude Sonnet 4.6 (loop)"
    # gpgsign bypass per anko explicit permission (2026-05-15) —
    # auto(loop) commits are machine-generated, continuous operation
    # hits 1Password GPG session timeout repeatedly. anko's manual
    # commits remain signed via the global commit.gpgSign=true.
    ```
    Do NOT push. (`auto/turn_${N}_<label>` branches commit
    separately via implementer.)

6e. Notify:
    ```
    !bash .claude/scripts/notify.sh "T${N} ${judge_status}"
    ```

────────────────────────────────────────────────────────────────────
## Step 7 — End turn

7a. Output a 1-line summary to stdout:
    ```
    T${N} ${judge_status} (next: T${N+1 or N}, status=${state.status})
    ```

7b. Stop. The bash wrapper in `.claude/scripts/loop.sh` will re-
    invoke `/run-loop` for the next turn after a short sleep.

────────────────────────────────────────────────────────────────────
## Notes on dispatch syntax

You invoke subagents via the **Task tool**, not a slash command.
When this instruction says "Dispatch the X subagent", you should
emit a single Task tool call with `subagent_type: "x"` and the
provided brief as the `prompt`.

When this instruction says `!python ...` or `!bash ...`, you should
emit a Bash tool call (the `!` is a Markdown convention here, not
literal shell syntax).

Never edit subagent definitions, command files, or scripts during a
loop turn. Those are anko's manual changes.
