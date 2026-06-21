# Loop Engineering runbook — a runnable verifier-centric loop

The minimal, runnable form of the architecture in
`docs/design/loop_engineering_architecture.md`, native to this repo (the old
autonomous `.claude/` loop is retired; this is its research-validated, supervised
successor). It drives an agent to certify a physics result, with the three-valued
physics gate as the reward signal — not "tests pass," not an LLM judge.

## Pieces

| Piece | Role |
|---|---|
| `scripts/loop/verify.jl <candidate.toml>` | the ISOLATED 3-valued gate: builds the cell, solves to a tight stationary point (LBFGS → Newton-CG), runs norm-conservation AND `StabilitySpec`, emits one token `VERIFY: ACCEPT\|REJECT\|ABSTAIN <content_id> <verify_sha>` + exit code 0/2/3 |
| `scripts/loop/loop_gate.sh` | Stop/SubagentStop hook — the INTEGRITY FLOOR: on a stop attempt it FRESH-RERUNS `verify.jl` and decides from its own subprocess run, never the transcript; budgeted; seals a `.loop/<name>.done` sentinel |
| `runs/directions/<name>.toml` | a pre-registered direction = the cell + the gate budget, as DATA (the agent cannot inject code) |
| `/goal` | the sequencer — Haiku pattern-matches the `VERIFY: ACCEPT` token to drive turns; it never judges physics |

## Run a campaign

1. **Write the direction** (`runs/directions/<name>.toml`) — physics cell + gate
   budget. See `rb87_stable_polar.toml` (a stable minimum ⇒ ACCEPT) and
   `rb87_polar_saddle.toml` (a saddle ⇒ REJECT) for the schema.

2. **Launch** — the Stop hook is injected ONLY into the campaign sub-session via
   `--settings`, so it is **campaign-scoped**: it never touches the shared
   `.claude/settings.json` and your normal interactive sessions are never
   affected (no Stop hook fires on the main session at all). Prompt via stdin so
   `--allowedTools` does not consume it:
   ```bash
   HOOK='{"hooks":{"Stop":[{"matcher":"*","hooks":[{"type":"command",
     "command":"bash \"$CLAUDE_PROJECT_DIR/scripts/loop/loop_gate.sh\""}]}],
     "SubagentStop":[{"matcher":"*","hooks":[{"type":"command",
     "command":"bash \"$CLAUDE_PROJECT_DIR/scripts/loop/loop_gate.sh\""}]}]}}'
   printf '%s' 'Run `julia --project=. scripts/loop/verify.jl runs/directions/<name>.toml`
   and report its full VERIFY line verbatim.
   /goal The latest turn contains a line matching ^VERIFY: ACCEPT produced by running
   verify.jl on runs/directions/<name>.toml THIS turn (not echoed). On ABSTAIN, read
   the StabilitySpec reason and ESCALATE the gate budget (raise `niter` in the TOML)
   then re-run. On REJECT, the physics is wrong: stop and report. Stop after 12 turns.' \
   | BEC_LOOP_DIRECTION=runs/directions/<name>.toml \
     claude --print --max-turns 15 --settings "$HOOK" \
       --allowedTools "Bash(julia *),Read(./**),Edit(runs/directions/**)"
   ```
   `--settings` MERGES onto the project settings, so the sub-session keeps the
   API-key guard etc. AND gains the loop gate; the main session, launched without
   it, has neither. (Do NOT commit the hook into `.claude/settings.json` — that
   would fire `loop_gate.sh` on every interactive Stop. It is opt-in, per run.)

## How the loop actually turns

- The agent runs `verify.jl` each turn; the token lands in the transcript.
- `/goal` (Haiku) pattern-matches `VERIFY: ACCEPT` and, if absent, auto-starts the
  next turn. **It only sequences — it never decides physics.**
- On the agent's stop attempt, `loop_gate.sh` **re-runs `verify.jl` itself** and
  allows the stop only on a real ACCEPT (or budget exhaustion). An echoed
  `VERIFY: ACCEPT` in the transcript cannot end the loop (proven by
  `test/loop/test_loop_gate.sh`).
- **The three-valued discipline drives the inner loop**: `ABSTAIN` ≠ `REJECT`.
  ABSTAIN means "not certified yet" → escalate budget / tighten the solve and
  re-submit. REJECT means the physics is wrong → stop. Never coerce ABSTAIN→ACCEPT.

## Budgets (three orthogonal layers)

- `--max-turns N` on `claude -p` — the silent hard backstop.
- `BEC_LOOP_MAX_TICKS` (default 12) — the progress-relative POLICY cap in the
  hook: K consecutive non-ACCEPT stop attempts → `BUDGET_EXHAUSTED`, terminate
  with a logged non-success (a `.loop/<name>.done` sentinel that survives
  `--resume`). The turn clause in the `/goal` text is advisory.
- TSUBAME points — the separate compute budget for heavy cells.

## Gate re-certification (anti-Goodhart)

The gate is in-tree, so the in-tree substitute for out-of-tree isolation is
continuous re-certification: set `BEC_LOOP_RECERT=1` and the hook runs the frozen
adversarial suite (`test_stability_sneaky_prover.jl` + `test_stability_indeterminate.jl`)
before trusting a verdict — a silently-weakened gate turns the suite red and the
hook refuses to certify. Heavy (Julia); run it periodically, not every tick.

## Honest bounds

- This is the **supervised** loop. The research shows an agent that can *read or
  edit* the verifier games it 49–76 % of the time; here the Stop hook re-runs the
  gate fresh (the agent's claims are ignored) and the frozen suite catches gate
  weakening — but the gate code is still in the working tree. For **unattended**
  operation, move the gate out of the agent's reach (the outer-harness / separate
  repo structure), which is exactly what the now-retired `autoresearch` did.
- `verify.jl` is heavy (a Newton-CG-polished solve + the gate per call). Use
  `BEC_LOOP_MOCK ∈ {accept,reject,abstain}` ONLY for harness mechanism tests.
- The outer-stop predicate here is per-cell ("this cell is a certified stable
  minimum"). A multi-cell campaign needs an outer `check_direction` over several
  ACCEPTed cells + a proposer difficulty ladder (see the design note).
