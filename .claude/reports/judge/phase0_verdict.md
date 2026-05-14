# Phase 0 Quality Calibration — Verdict

**Date**: 2026-05-14
**Architecture under test**: theorist subagent (`.claude/agents/theorist.md`)
**Dispatch mechanism**: general-purpose agent with `model: opus`, Phase 0
  workaround — the real `theorist` subagent type isn't yet exposed in
  this session because subagents are discovered at session start.
  Restart `claude` in this dir to validate actual subagent dispatch.
**Output under review**: `.claude/reports/theorist/phase0_test.md`

## Verdict: **PASS (high confidence)**

The output is publishable-quality reasoning. The architecture is GO
for the next phase pending the session-restart subagent dispatch
verification.

## Scorecard

| Criterion | Result | Notes |
|---|---|---|
| Final α value correct | **PASS** | α = −1/48 in the Ṽ form. Matches the Wick rotation Δτ²/48 → −dt²/48 exactly. |
| Distinguishes Ṽ-form (−1/48) vs exponent-form (−1/72) | **PASS** | §3.3 footnote correctly identifies the 2/3 middle-slot weight: (2dt/3)·(dt²/48) = dt³/72. Memory `gotcha_fg_correction_sign_wick_rotation.md` was used as cross-check, not as substitute. |
| Wick rotation algebra explicit | **PASS** | §2.3 + §3.1 track i² = −1 explicitly, verify sign convention invariance. |
| Time-reversibility argued, not asserted | **PASS** | §3.2 separates the parity argument (forces even-power dt) from the sBCH cancellation argument (forces the sign). The two are correctly distinguished. |
| Falsifiability concrete | **PASS** | §3.3 prediction table is sharp: only α = −1/48 gives p=4; α = +1/48 gives p=2 with *larger* prefactor than bare Strang (smoking-gun observable). |
| Calibrated language used | **PASS** | [Established] for derived claims, [Plausible] for CK 2005 magnitude (not refetched), [Speculative] for the 2/3 weight identification. |
| `<RESEARCH_NEEDED>` discipline | **PASS** | §7 Q1 requests CK 2005 magnitude refetch with explicit `why` — would upgrade the [Plausible] tag to [Established]. |
| No invented citations | **PASS** | Cited refs (Yoshida 1990, McLachlan 1995, Hairer–Lubich–Wanner Ch.III.5, CK 2005 PRE 72 036705) are real and load-bearing only where derivation can stand alone. |
| No sycophancy | **PASS** | Direct tone. No "great question", "absolutely", "you're right". |
| Schema compliance (§1–§7) | **PASS** | All sections present in order. §6 directive correctly emits `noop` with concrete next-step recommendation per B6. |
| Mathematical elegance bias (B6) | **PASS** | §6 recommends one localized regression test, not a sweeping refactor — explicit reference to "B6 mathematical-elegance bias". |
| Stayed within tool restrictions | **PASS** | Only Read + WebFetch + Write observed in the 9 tool calls. No Bash/Edit attempted. |

## What went unusually well

- Distinguishing the two coefficient conventions (Ṽ vs exponent
  form) with the algebraic identification of the 2/3 weight. This
  is the kind of sophistication that separates a competent theorist
  from a quote-the-memory bot. The model could have just said
  "memory says −1/72" and stopped; instead it derived the
  parameterization map.
- The smoking-gun framing in §3.3: "wrong sign gives p=2 with
  *larger* prefactor than no correction" is the right pedagogical
  way to write a falsifiability criterion. An experimenter can
  distinguish three branches from one α-sweep.

## What to watch

- §2.2 hand-waves the Algorithm 4A "middle-slot" derivation as
  "schematically". This is acceptable for Phase 0 (scope is
  calibration, not a full reproof of CK 2005), but in a production
  turn aimed at modifying integrator code, that derivation would
  need to be tight or the implementer should REJECT for
  insufficient rationale.
- The 2/3 middle-slot weight is taken on faith in §3.3 (tagged
  [Speculative] in §4). If a future turn depends on this weight,
  the theorist should derive it or emit `<RESEARCH_NEEDED>`.

## What this validates

1. **The theorist.md prompt produces sound physics on a real
   project question.** This was the primary anxiety from prior
   sessions ("Claude Code は理論カス"). The tool restriction +
   Section G fragments + the §1-§7 schema together yield work
   comparable to manual claude.ai dialogue.
2. **Calibration tags are used correctly.** The Established /
   Plausible / Speculative gradient is not decorative — the
   theorist used it to flag exactly the sub-claims that could
   fail under deeper scrutiny.
3. **Memory is treated as a soft cross-check, not a substitute
   for derivation.** Section A4 ("no silent assumptions") + §G2
   ("investigate before claiming") held even when an answer was
   one Grep away.

## What this does NOT validate

1. **The actual subagent dispatch path.** This test ran via
   `general-purpose` + `model: opus`. Tool restrictions, model
   binding, and system-prompt loading may differ when invoked
   via the real `theorist` subagent type. **Anko must restart
   `claude` in this dir and retry to confirm.**
2. **The orchestrator loop end-to-end.** Phase 0 only exercises
   theorist. The handoff theorist → researcher → implementer →
   judge → critic is still untested.
3. **Quota behavior under sustained load.** This one turn used
   ~58k tokens. Phase 1 should measure tokens-per-turn over 3–5
   turns to calibrate `quota_config.json`.

## Recommended next steps

1. **Anko restart**: exit and reopen `claude` in this directory,
   then prompt with `Read .claude/agents/theorist.md`. If the
   subagent appears in the Task tool's available types, dispatch
   actual works.
2. **Re-run Phase 0 with real subagent** (cheap, ~60k tokens):
   dispatch `theorist` with the same FG question, output to
   `phase0_test_v2.md`, diff against this run. If structurally
   equivalent, the dispatch path is validated.
3. **Phase 1 — minimum-viable loop turn**: set
   `state.json.status = "running"`, run
   `LOOP_MAX_TURNS=1 bash .claude/scripts/loop.sh`. Watch logs.
   The expected outcome: theorist proposes one small directive,
   implementer runs ≤ 5 min on a trivial config, judge emits
   PASS, state advances to turn 1, loop self-exits.
4. **Phase 2 — sustained 5-turn run**: bump `LOOP_MAX_TURNS=5`,
   measure quota burn rate, update `quota_config.json` accordingly.
5. **Phase 3 — cron + tmux** only after Phase 2 is stable.

## Token budget consumed

- Phase 0 single theorist call: ~58k tokens (general-purpose,
  Opus). Real subagent dispatch likely similar (same model, same
  output volume).
- Architecture build-out (this conversation through Phase 0): one
  evening, ~12 turns. Most of the budget went to file authoring,
  not theorist work.

## Verdict bottom line

The "Claude Code is理論カス" verdict from the prior session was
on the right side at the time. With the theorist.md protocol
(tool restriction + Section G fragments + structured output
schema), the same model on the same kind of problem produces work
that would have passed peer review at a workshop. The architecture
is GO. Restart, re-run, and proceed to Phase 1.
