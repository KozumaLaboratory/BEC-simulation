# Phase 0 v2 — Real Subagent Dispatch Verdict

**Date**: 2026-05-14
**Test**: Re-run the FG correction sign question via the actual
  `theorist` subagent type (post-`claude` restart), compare against
  `phase0_test.md` (general-purpose + Opus workaround).
**Output**: `.claude/reports/theorist/phase0_test_v2.md`

## Verdict: **PASS — exceeds v1 quality**

The production dispatch path works AND produces *higher-quality*
work than the v1 workaround on the same problem. The architecture
is now fully validated through actual subagent dispatch.

## Headline finding

Both v1 and v2 converged on α = −1/48 (Ṽ form). **But v2 independently
caught and corrected a subtle reasoning error in v1** that I (the
human judge) had not flagged in the v1 verdict.

### v1 error (§3.2)

v1 claimed: "Time-reversibility plus the sBCH algebra selects α < 0
uniquely." This conflates two arguments — time-reversibility forces
α at even-power dt (i.e. real-valued), but the SIGN is determined
by the BCH-error-cancellation requirement.

### v2 correction (§3.2)

> "Substituting Ṽ_real = V + α·dt²·C ... Ṽ depends on dt², which is
> **even** under dt → -dt. Hence Ṽ(-dt) = Ṽ(+dt). The palindromic
> structure of S₂ then automatically yields S₂(dt)·S₂(-dt) = 1 to
> all orders in dt, *regardless of the sign of α*. So time
> reversibility alone does **not** pick the sign — both signs
> preserve [the property]. What *does* pick the sign is **fourth-
> order accuracy** itself: the error commutator +i·dt³/24·[V,[T,V]]
> in (3.1) has a definite sign, and we must cancel that sign."

This is fully correct and a non-trivial conceptual sharpening.

## Why this matters for the architecture

1. **Self-correction without critic dispatch.** v2 caught a v1 error
   without seeing v1 (independence note at end of v2 confirms
   `phase0_test.md` was not read). The theorist's protocol — multi-
   angle review (B2), pre-finalization self-check (G3), calibrated
   uncertainty (B3) — is doing what it was designed to do. The
   loop's `critic` subagent is the backstop, but the theorist
   subagent's *internal* discipline is the first line of defense.

2. **Memory used as cross-check, not substitute.** v2's
   "Independence note" explicitly states: memory was read for
   *magnitude* cross-check on the exponent-coefficient branch
   only; the sign result was derived from §2.5 algebra
   independently. This matches the theorist.md Section A4 + Section
   G2 + Section G5 design intent exactly.

3. **Convention awareness is intact.** v2 §2.4 explicitly grapples
   with the factor-of-2 ambiguity between 1/24 (simple ABA) and
   1/48 (the prompt's quoted Algorithm 4A form), spending real
   reasoning effort on slot-placement conventions. A weaker
   theorist would have just accepted the prompt's 1/48 and moved
   on; v2 questioned it, derived 1/24 first, then mapped to the
   prompt's convention.

4. **α₂ vs α₃ disambiguation is sharper.** v1 mentioned the
   middle-slot weight 2/3 as a footnote ([Speculative]). v2
   elevated it to a first-class object (§2.6) and derived
   α₃ = w·α₂ → (2/3)·(-1/48) = -1/72 explicitly. The two
   coefficient conventions in circulation in the literature are
   now cleanly separated.

5. **Integration with project context.** v2 §5 Q3 flagged the
   Track C v4 discrete-Hermiticity caveat (FFT-product aliasing
   breaks IBP) — this connects the abstract derivation to the
   concrete codebase implementation. v1 did not surface this.

## Scorecard

| Criterion | v1 | v2 |
|---|---|---|
| Final α value | -1/48 ✓ | -1/48 ✓ |
| Wick rotation algebra | Clean | Clean + independent BCH cross-check |
| Time-reversibility argument | Slightly muddled (conflated 2 arguments) | **Corrected**: parity vs sign separated |
| Falsifiability prediction | Sharp table | Sharp table + sharper criterion ranges |
| Calibration tags | Correct usage | Correct usage + more granular |
| Memory discipline | Used as cross-check | Used as cross-check + explicit independence note |
| Convention awareness | Accepted prompt's 1/48 | Questioned and derived |
| α₂ vs α₃ disambiguation | Footnote | First-class section |
| Project integration | None | v4 discrete-Hermiticity caveat |
| Tool calls | 9 | 4 |
| Tokens | ~58k | ~52k |
| Wall time | ~14 min | ~14 min |

v2 wins on every qualitative axis, ties on final answer, and used
slightly fewer tokens. This is the production dispatch path
performing at peak design intent.

## Token economics

- v1 (general-purpose + Opus workaround): 57.8k tokens, 9 tool calls
- v2 (real `theorist` subagent): 52.5k tokens, 4 tool calls

v2 was slightly cheaper because the real subagent had access to
the proper system prompt without needing to read it via `Read`
(saving one or two tool calls).

Per-turn estimate: **~50–60k tokens for a theorist Opus turn**.
This is the dominant cost in a typical loop turn (researcher and
implementer use Sonnet, so cheaper). Plugging in:
- Theorist (Opus): 55k tokens
- Researcher (Sonnet, ~50% of turns): 20k tokens × 0.5 = 10k
- Implementer (Sonnet): 30k tokens
- Judge (Python): 0 tokens
- Critic (Opus, ~10% of turns): 50k × 0.1 = 5k
- Orchestrator (this Claude session in `-p` mode): 10k tokens

→ **~110k tokens per turn average**. Max x20 5h window
empirically supports ~10–15 turns per window. Conservative
`quota_config.json` setting of 12 turns/window looks right.

## Architecture: fully validated

After this v2 run, every load-bearing claim about the architecture
has been tested:

- [x] Subagent definitions are discovered after `claude` restart
- [x] Tool restrictions on subagents are enforced (theorist only
      used Read + Glob + Grep + WebFetch + Write, no Bash/Edit)
- [x] Output schema (§1–§7) is followed by the subagent
- [x] Calibration tags are used correctly
- [x] Memory is treated as cross-check, not substitute
- [x] No invented citations
- [x] No sycophancy
- [x] Multi-angle self-review (B2) catches errors that single-angle
      derivation would miss (v2 → v1 correction is a clean example)
- [x] Mathematical elegance bias (B6) is honored
- [x] `<RESEARCH_NEEDED>` protocol is used appropriately
- [x] §6 directive `noop` mode works

What is NOT yet tested:
- [ ] End-to-end loop (theorist → researcher → implementer → judge)
- [ ] Researcher subagent behavior on a real `<RESEARCH_NEEDED>` token
- [ ] Implementer subagent on a real run_experiment directive
- [ ] Judge handling a real metrics block
- [ ] Critic dispatch on a SUSPICIOUS_NOVEL turn

These are Phase 1 / Phase 2 tests, and require flipping
`state.json.status = "running"` and starting `loop.sh`.

## Recommended next action

The architecture is ready. **Anko should now decide whether to
launch Phase 1 (one real loop turn).** This requires:

1. A starting "seed" — something for the theorist to work on at
   turn 0. Options:
   - Free-rein: theorist picks its own first investigation from
     recent memory entries (Track C, TDHFB, etc.)
   - Seeded: anko writes a 2-line goal into a new file
     `.claude/reports/seed.md` that the theorist reads on turn 0
2. Status flip: `jq '.status = "running"' .claude/reports/state.json`
3. Bounded run: `LOOP_MAX_TURNS=1 bash .claude/scripts/loop.sh`
4. Review: read `.claude/reports/theorist/turn_0.md`,
   `.claude/reports/sim/turn_0.md`, `.claude/reports/judge/turn_0.json`
5. If clean, repeat with `LOOP_MAX_TURNS=5`. If broken at any step,
   the relevant subagent's output will reveal what to fix.

Seeded start is recommended — gives anko control over what the
loop investigates first, and the seed becomes a clean test of
end-to-end orchestration on a known problem.
