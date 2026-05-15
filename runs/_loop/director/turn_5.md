# Turn 5 — Director Report

## 1. Project state snapshot

- **T0–T4 active work zone**: T0–T3 = `force_gradient.jl` docstring/test
  inoculation + `compute_sympy` infra. T4 (director-driven) pivoted to
  Paper #3 Lemma 1 — added F=14 O:A_1 row on
  `auto/turn_4_lemma1-f14-extension` (commit `be6a472`, **not yet
  merged to main**). 5 consecutive `modify_code` directives, all
  cosmetic/manuscript-extending — no production code path
  semantics altered, no bug closed, no experiment run.
- **Manuscript pulse**: Paper #1 (F=2 cyclic) "ready for LaTeX
  conversion" (Round 8 2026-05-12). Paper #3 Lemma 1 closed-form
  verified at 26 channels (F=3/4/6/8/10) on main; F=14 awaits merge.
  Paper #2 (F=6 icosahedral), Paper #4 (TWA chaos), Paper #6
  (F-systematic) raw. **Paper #4 specifically blocked**: any F=6
  polar comparison is uncashable while FullBdGLHY 3000× bug stands.
- **Blocker inventory (unchanged across T0–T4)**:
  - F=6 polar FullBdGLHY 3000× spurious offset
    (`full_bdg_F6_polar_broken.md`, currently `@warn` guarded only).
  - TwoChannelLHY F=6 30-70% off (pinned, design boundary).
  - Klaus 2022 magnetostir not reproducible (Option γ design only,
    ~700 LOC pending).
  - **DDI conventions never cross-checked vs Stuttgart/Innsbruck
    published groups** (D2 axis in CLAUDE.md project goals).
  - TDHFB Phase 3+ generic-F HF kernel pending.
  - v4 spinor FG matrix V_SM extension: theory done, code blocked.
- **Loop architecture readiness**: per `loop_architecture_2026_05_14.md`
  Phase 2 status, **researcher subagent has never been dispatched**;
  critic also never dispatched. Seed §"What good looks like"
  explicitly: "At least one researcher dispatch within 5 turns
  (Phase 2 D2 exercise gap)." **Today (T5) is exactly turn 5 →
  forced touchpoint.**
- **seed.md status**: T5 inherits the 2026-05-15 morning seed
  (director-autonomous mode). Not regenerated since T4; same
  guidance: pick highest-leverage move comprehensively from
  verification / physics / code / docs / infra axes, NOT default to
  theorist.

## 2. Recent-turn audit (last 3)

| Turn | Topic | Verdict | Value delivered | Was it right? |
|---|---|---|---|---|
| T2 | Nonlinear-V coefficient invariance docstring | PASS | +20 lines comment on `force_gradient.jl`. Distinguishes coefficient invariance from order-cap. Reduces hypothetical regression blast radius. | Marginal yes (cheap inoculation, but 2nd cosmetic in a row). |
| T3 | `compute_sympy` infra E2E on 3 trivial identities (I1/I2/I3) | PASS | +4 comment lines + `compute_sympy` directive path validated end-to-end (commit `6352726`). Infrastructure value real; physics value zero (all 3 facts were hand-checkable in 5 s). | Yes for infra unlock; theorist's own §8 admitted "out of scope — infrastructure-verification turn". |
| T4 | Lemma 1 General-S F=14 O:A_1 extension (director-driven) | PASS | Commit `be6a472` on `auto/turn_4_lemma1-f14-extension`: Paper #3 §sign_pattern_lemma1_general_S.md +64 lines (F=14 row + 27-row consolidated table + S=20 exact-zero footnote); script extended; 3 sympy steps OK; falsification CONFIRMED. Branch NOT YET merged to main. | Yes — first manuscript-touching turn; exploited compute_sympy at non-trivial weight; found a publishable artifact (S=20 exact node, complementing F=8 S=12). |

**Trajectory flag (§B4)**: 5 consecutive `modify_code` directives;
5 consecutive implementer-only (or implicit theorist-then-implementer)
turns; **zero researcher dispatches**, **zero critic dispatches**,
**zero `run_experiment` directives**. The loop has only exercised one
of four directive shapes. Seed.md's "researcher within 5 turns"
deadline lands today. Continuing the Lemma 1-extension trick into
T5 (F=15, F=16, ...) would be incremental and would burn the last
turn of the researcher-quota window — wrong call.

## 3. Bottleneck analysis

Top candidates by (project value × p(move-this-turn) / cost):

- **B-1: F=6 polar `FullBdGLHY` 3000× spurious offset — sign /
  negative-eigenvalue handling**
  *Issue*: `full_bdg_F6_polar_broken.md` (2 days stale, code claims
  must be re-verified): ψ converges to the same minimum as `:scalar`
  but reported LHY energy is ~3000× too negative, attributed to
  unstable BdG modes (λ < 0) contaminating the Petrov zero-point
  sum. Paper #4 + any F=6 polar comparison currently blocked.
  *Category*: physics gap (wrong negative-eigenvalue treatment) +
  verification gap (no benchmark vs Lima-Pelster Q5 / Petrov 2015
  for the F=6 polar exception case).
  *Leverage*: **5**. Single bug fix unblocks ≥ 2 papers; researcher
  has a clean, single-turn-sized question: "How does Lima-Pelster
  (2012) / Petrov (2015) / Schmitt-Wenzel-Böttcher (2014–2016)
  handle negative-eigenvalue Bogoliubov modes in the LHY zero-point
  integral for F=6 polar (or any spin-mixed polar) systems? What
  is the canonical reference projector?"
  *What moves it*: **researcher** (1 turn) — Phase 2 D2 axis exercise
  + literature sufficient to set up a theorist or implementer fix
  next turn.

- **B-2: DDI convention cross-validation vs published Stuttgart /
  Innsbruck Dy / Er groups**
  *Issue*: CLAUDE.md project D2 goals list this as the single
  biggest verification gap (D2). Conventions `c_dd=μ₀μ²` (no 4π),
  `Q_αβ=k̂_αk̂_β−δ_αβ/3` (no 1/(4π)) are "believed, never benchmarked
  against published groups". For Eu (F=6) credibility this is paper-
  scale.
  *Category*: verification gap.
  *Leverage*: **4**. High value for credibility, but the question is
  diffuse — many papers, many conventions, may need multiple turns.
  Less crisp than B-1.
  *What moves it*: researcher to identify a single Stuttgart Dy
  benchmark with extractable numbers; or critic to challenge our
  DDI sign chain.

- **B-3: Klaus 2022 magnetostir — Option γ scalar eGPE adiabatic
  validation**
  *Issue*: `active_handoff.md` (17 days stale; CHECK current code
  state). Klaus still not reproducible; Option γ rotating basis is
  designed but only adiabatic limit landed (per memory: phase II
  static-tilt match scalar eGPE 0.999959; phase III high-resolution
  lab-frame match in scope but ~700 LOC remain).
  *Category*: physics gap + code gap.
  *Leverage*: **4**. But scope is multi-turn / multi-session and the
  17-day-stale memory means current state must be re-confirmed
  before any work — this turn would burn on rediscovery, not
  resolution.

- **B-4: Merge T4 `auto/turn_4_lemma1-f14-extension` to main**
  *Issue*: F=14 extension on branch but not landed.
  *Category*: infra / housekeeping.
  *Leverage*: **1**. Mechanical; not director-shaped (orchestrator
  / anko handles this).

- **B-5: Lemma 1 next-F (F=15 / F=16) extension via compute_sympy**
  *Issue*: continue T4's trick; F=15 O:A or T:A could be a 4th-or-5th
  data row.
  *Category*: docs gap (manuscript +1 row).
  *Leverage*: **2**. Diminishing returns vs T4; F=14 already
  demonstrated the pattern; another F is a thin marginal win.
  Burns the researcher-quota window.

## 4. Strategic options for THIS turn

| # | Move | Subagent | Now-or-later | Cost |
|---|---|---|---|---|
| 1 | Researcher literature scan: how do Lima-Pelster 2012 / Petrov 2015 / Stuttgart group handle λ < 0 BdG modes in LHY integral for spin-mixed polar GS? | **researcher** | NOW — seed deadline + B-1 leverage | ≤1.5M effective tokens, ≤15 min |
| 2 | Lemma 1 next-F extension (F=15 / F=16) | implementer | later (decreasing leverage) | ≤1.5M, ≤12 min |
| 3 | Critic audit: re-examine T1's "α_2 = -1/48 representation-blind under V → V_SM" claim before letting it cascade into the v4 spinor FG code patch | critic | could wait — claim is plausible, but turn budget OK | ≤2M, ≤15 min |
| 4 | Theorist: derive correct λ < 0 projector for FullBdGLHY | theorist | later — researcher must precede (literature first; §B4 anti-default-theorist) | ≤2M, ≤15 min |
| 5 | noop | n/a | only if quota tight; current cap is 3M/turn and recent turns used ≤1.74M | 0 |

**Pick: Option 1 (researcher → B-1).**

Why:
- **Seed-deadline forced**: "At least one researcher dispatch within
  5 turns (Phase 2 D2 exercise gap)." T5 is the deadline. No prior
  researcher dispatch. Skipping → seed-clause violation.
- **§B4 anti-default-theorist** applies cleanly: T2 + T3 + T4 last
  three turns were implementer-shaped; T1 had theorist; no
  researcher. Rotate routes.
- **§B3 routing rule for researcher** is exactly met: "Dispatch when
  the bottleneck is 'what does paper X actually say' or 'what's the
  latest measurement' — external knowledge gap, not a derivation
  gap." B-1 (negative-eigenvalue handling) IS a literature-canon
  question first, then a derivation question. The opposite path
  (theorist guesses the projector, code is patched, then we discover
  Lima-Pelster used a different convention) wastes turns.
- **§A5 value test**: hits (b) verification gap + (c) physics-effect
  missing (correct λ<0 treatment) + path to (d) bug blast-radius
  reduction (Paper #4 + F=6 polar unblock). Three of four §A5
  categories.
- **Cost-bounded**: literature lookup, no derivation, no code, no
  experiment. Researcher protocol expects 1.5M effective tokens; T4
  burned 1.74M with much heavier work.
- **Setup-quality**: researcher output directly feeds T6 dispatch
  (theorist with concrete projector definition, or implementer with
  one-line filter on Re λ). Compounds.

Why NOT critic (Option 3) today:
- T1's α_2 = -1/48 claim has not been cashed into production code
  yet (force_gradient.jl line 54-55 still hard-errors for c_1 ≠ 0).
  Until that claim is load-bearing in a `run_experiment` or
  production path, critic-audit is premature. Re-evaluate after the
  v4 spinor extension lands.

Why NOT noop:
- Both quota (well under 3M/turn cap) and bottleneck-cheapness
  (B-1 is a single-turn literature lookup) cleanly fail the noop
  test in §F2.

## 5. Calibrated progress check

| Axis | Status | Evidence |
|---|---|---|
| Physics completeness | **at risk** | F=6 polar FullBdGLHY 3000× spurious (memory `full_bdg_F6_polar_broken.md`); TwoChannelLHY F=6 30-70% off (CLAUDE.md "Known limitations"); Klaus magnetostir not reproducible (Option γ design only). 5 turns added zero physics effects. |
| Verification depth | **at risk** | DDI vs Stuttgart never benchmarked (D2 axis open since project inception). Lemma 1 reach: F=3-14 verified (T4 branch). FG sign: 18/18 regression tests pass (T0). No turn yet attacked the FullBdGLHY F=6 polar verification gap. |
| Manuscript | **on track for Paper #1, #3; off track for #2, #4, #6** | Paper #1 LaTeX-ready (Round 8). Paper #3 +1 row via T4 (pending merge). Paper #2 (F=6 icosahedral) raw — needs LHY closed form. Paper #4 (TWA chaos) raw and blocked by F=6 polar FullBdGLHY bug. Paper #6 raw. |
| Reproducibility | **on track** | YAML schema documented, lab-units opt-in, resumable runs. No regression in T0-T4. |
| Loop infrastructure | **partial** | `compute_sympy` validated (T3) + exploited at non-trivial weight (T4). **Researcher path: never exercised** (T5 deadline). **Critic path: never exercised.** **`run_experiment` directive: never exercised.** |

**Mark**: Physics + Verification both at risk; researcher path
unexercised at the seed-imposed deadline. T5 dispatch must turn the
wheel toward verification depth via literature.

## 6. Dispatch decision

```json
{
  "subagent_type": "researcher",
  "rationale": "Seed.md sets a hard deadline 'at least one researcher dispatch within 5 turns'; T5 is exactly turn 5 and no prior researcher dispatch has fired (state.json history T0-T4 all modify_code). §B4 rotation rule fires after 3 same-subagent turns (T2/T3/T4 all implementer-shaped) — researcher is the route to rotate to, not theorist (§B3: external-knowledge gap, not derivation gap). The B-1 bottleneck (`full_bdg_F6_polar_broken.md`: F=6 polar FullBdGLHY 3000× spurious, blocks Paper #4 and any F=6 polar comparison) is exactly literature-shaped: 'what does Lima-Pelster 2012 / Petrov 2015 / Stuttgart group actually do with negative-eigenvalue Bogoliubov modes in the LHY zero-point integral?' Answering this seeds either a theorist (sign-convention derivation) or implementer (Re λ > 0 filter) next turn. This single dispatch hits §A5 (b) verification-gap + (c) missing-physics-correctness + sets up (d) bug blast-radius reduction.",
  "brief": "Goal: characterize how the published LHY-for-spinor-BEC literature handles **Bogoliubov modes with negative eigenvalues** (mean-field-unstable modes) inside the zero-point energy integral, with specific application to the F=6 polar phase where SpinorBEC.jl's `FullBdGLHY` mode produces a ~3000× spurious energy offset.\n\n## Context to read first (in order)\n\n1. `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/full_bdg_F6_polar_broken.md` — the bug summary (2 days stale; treat as starting hypothesis, not fact).\n2. `src/hamiltonian/lhy.jl` or equivalent: locate the current `FullBdGLHY` / `compute_spinor_lhy_table` implementation. The LHY refactor (memory `lhy_refactor_2026_05_12.md`) reorganized this; grep for `FullBdGLHY` and find where the BdG eigenvalues are summed. **Report the exact line where negative eigenvalues are currently handled (or silently included).**\n3. `src/hamiltonian/lhy/`-tree for the parallel `PolarContactLHY` / `PolarDipolarLHY` / `IcosahedralLHY` closed-form modes — these work; FullBdG is the one that breaks. The contrast tells us what the F=6 polar literature must encode that we lost in the numerical sum.\n\n## Literature questions (priority-ordered)\n\nQ1 (load-bearing). **Lima & Pelster 2012** (PRA 86, 063609 — 'Quantum fluctuations in dipolar Bose gases'): What is the canonical zero-point-energy formula $\\varepsilon_{\\rm LHY} \\propto \\int d^3k \\sum_\\lambda \\omega_\\lambda(k)$ when one or more BdG branches goes complex (mean-field unstable)? Standard Bogoliubov says drop the imaginary part; what about λ purely real but negative? Cite the eq / page.\n\nQ2. **Petrov 2015** (PRL 115, 155302 — 'Quantum mechanical stabilization'): the canonical Re|λ| prescription for droplet stabilization vs the alternative |Re λ| / |λ| / projector-onto-positive-norm-modes — which is used? Is the Bose-Bogoliubov sum-rule's negative-norm-eigenvalue branch DROPPED or its REAL PART TAKEN?\n\nQ3. **Schmitt-Wenzel-Böttcher 2014-2016** (Dy lab Stuttgart) + **Chomaz-Petter et al. 2016** (Er lab Innsbruck): dipolar droplet LHY in numerical practice — same question. Most explicit numerical reference appreciated.\n\nQ4 (bridge). For **spinor** (multi-component) F ≥ 2 polar with λ < 0 modes that are physically signaling mean-field instability of the polar GS toward FM (mentioned in `full_bdg_F6_polar_broken.md`: 'F=6 polar mean-field is generically unstable'), is the LHY-on-an-unstable-GS even well-defined in the literature? Or is the canonical convention that LHY assumes a locally-stable GS and any negative-λ mode invalidates the LHY prediction (NaN / report-failure rather than apply Re or |·|)?\n\nQ5 (cross-check). The existing **closed-form** modes (`:polar_contact`, `:polar_dipolar`, `:fm_contact`, `:fm_dipolar`, `:icosahedral`) in SpinorBEC.jl come from which paper(s)? Confirm Paper #1 (Eu F=2 cyclic — likely Kawaguchi-Ueda?), Paper #3 family (Eu F=6 — Yi-You? Specific closed forms?). The contrast between 'closed form works for F=6 polar' and 'numerical BdG breaks for F=6 polar' suggests the closed form has assumed-positive-λ ranges that the brute-force numerical sum doesn't enforce.\n\n## Deliverables\n\n1. **§ Citations** with 4-6 concrete refs (DOI / arXiv ID / page-eq). Each ref MUST have a 1-sentence summary of what it actually says about negative-λ handling (not 'discusses LHY').\n2. **§ Convention table** comparing how each ref treats: (a) real-positive λ (trivial), (b) real-negative λ, (c) complex λ (with non-zero imaginary part).\n3. **§ Recommendation** for SpinorBEC.jl's FullBdGLHY: which of {drop real-negative, take Re(λ) which is negative and gives negative contribution, take |Re(λ)|, error out, or other} is most defensible per cited literature.\n4. **§ Sanity check** against the F=6 polar empirical observation in `full_bdg_F6_polar_broken.md` (3000× spurious negative). Does the recommended convention reproduce that magnitude if applied? If 'drop unstable modes' is the canonical answer and current code is taking signed Re(λ), the 3000× spurious negative IS explainable.\n5. **§ Next-turn directive** suggesting either (i) implementer adds 1-line λ-positivity filter with a published reference + adds a regression test that pins the F=6 polar energy to the `:polar_contact` closed-form value; or (ii) theorist needs to derive the correct projector if literature is ambiguous.\n\n## Falsification / out-of-scope\n\n- If no clear literature convention exists (Q4 answer is 'undefined for unstable GS'), say so plainly and escalate to theorist — do NOT invent a convention.\n- If `FullBdGLHY` turns out NOT to be in production code anymore (LHY refactor 2026-05-12 may have already gated it), say so plainly — the bug may already be partially mitigated and the value-add shifts to documenting the post-refactor state.\n- Out-of-scope: deriving a new projector, writing code, running experiments. Researcher's job is literature + canonical-convention crystallization.\n\n## Cost\n\n- Token budget: ≤ 1.5M effective tokens. Researcher should WebSearch / WebFetch for canonical refs; cache them under `.claude/knowledge/<topic>.md` if not already there.\n- Wall-clock: ≤ 15 min.\n- No code edits this turn. Output is `runs/_loop/research/turn_5.md` per the loop schema.",
  "expected_outcome": "(1) `runs/_loop/research/turn_5.md` containing §Citations (4-6 refs minimum, DOI / arXiv / paper-eq), §Convention table (3-row: real-positive / real-negative / complex λ), §Recommendation (one defensible λ < 0 treatment with citation), §Sanity check explaining or refuting the 3000× factor, §Next-turn directive (theorist or implementer with concrete brief). (2) `.claude/knowledge/lhy_negative_eigenvalue_handling.md` (or similar) caching the canonical refs for future turns. (3) Judge PASS (researcher output is read-only — no code regression risk). (4) Researcher agent_hash recorded in `state.json` history (first non-null researcher hash usage).",
  "expected_cost": "≤ 15 min wall-clock, ≤ 1.5M effective tokens. WebSearch + WebFetch are the dominant call shapes; no Julia JIT cost. Reference burn: T4 was 1.74M effective for a heavier directive; this should land lighter since no code edits.",
  "if_fails_next_step": "If researcher returns 'no clear literature convention' (canonical undefined), T6 dispatches theorist to derive the projector from first principles (Bose-Bogoliubov diagonalization + Petrov real-part prescription). If researcher returns 'FullBdGLHY is post-refactor handled correctly, the memory is stale', T6 verifies by running `:full_bdg` on F=6 polar via a small `run_experiment` (the first such directive in loop history; tests the path). If researcher returns 'F=6 polar mean-field unstable → LHY undefined', T6 dispatches implementer to upgrade the current `@warn maxlog=1` guard to an `error` with the canonical citation.",
  "consumed_seed_md": true
}
```

`consumed_seed_md`: **true**. The 2026-05-15 morning seed explicitly
flagged "at least one researcher dispatch within 5 turns" as a quality
gate. T5 satisfies that gate while attacking the highest-leverage
non-implementer bottleneck (B-1 FullBdGLHY F=6 polar). Anko should
overwrite seed.md before T6 if a different direction is desired.

## E. Self-review checklist

- [x] Read `runs/_loop/state.json` (turn=5, last_judge=PASS, 5
      consecutive `modify_code` actions, no researcher hash yet).
- [x] Read T2 theorist (turn_2.md §1 — Magnus framework setup), T3
      theorist (turn_3.md §0-§8 — compute_sympy infra validation),
      T3 sim, T4 director, T4 sim.
- [x] Read `runs/_loop/seed.md` (2026-05-15 morning,
      director-autonomous, researcher-quota explicit).
- [x] Read `runs/_loop/director/turn_4.md` (continuity: T4 picked
      Lemma 1 F=14; next-step note flagged Klaus / FullBdGLHY
      bottlenecks).
- [x] Read ≥1 memory: `full_bdg_F6_polar_broken.md` (2 days stale
      but the only memory addressing B-1 directly),
      `universal_theorem_status.md` (3 days, Paper #3 reach),
      `active_handoff.md` (17 days, Klaus status), plus
      `loop_architecture_2026_05_14.md` (researcher / critic
      untested status).
- [x] Considered NOT dispatching theorist — rejected theorist
      (Option 4) because researcher must precede; the B-1 bottleneck
      is literature-shaped.
- [x] §6 brief is specific: file paths, paper refs to look up,
      5 priority-ordered Q's, deliverable schema, falsification
      criteria, cost cap, fallback paths. Subagent does not need
      clarifying questions.
- [x] Justified why THIS turn (T5 = seed-deadline) and not next
      turn — deadline binds.
- [x] `consumed_seed_md: true` — yes, the researcher-quota clause is
      the seed-binding clause being satisfied; documented above.
