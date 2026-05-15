# Turn 4 — Director Report

## 1. Project state snapshot

- **Active code work zone (turns 0-3)**: all four turns touched ONLY
  `src/hamiltonian/integrator/force_gradient.jl` (and an associated
  static-regex test file). T0 added the regression test; T1/T2/T3
  are pure docstring/comment additions. Production semantics
  unchanged for 4 consecutive turns.
- **Manuscript pulse**: Paper #1 (F=2 cyclic, Round 8 cleanup
  2026-05-12) is "ready for LaTeX conversion via pandoc_workflow.sh 1"
  — no mention of FG/integrator content in the paper-1 raw md.
  Paper #3 (Universal Theorem) v3 audit landed 2026-05-11; Sign
  Pattern Lemma 1 general-S closed form verified across 26 channels.
  Paper #4 (TWA chaotic) raw exists. Multi-paper effort is rich;
  FG sign work plugs into none of them as a load-bearing item.
- **Recent capability**: commit `82b82cb`..`6352726` added
  `compute_sympy` directive path (run_sympy.py + sim §4
  `compute_results[]` schema). T3 validated it end-to-end on a
  trivial 3-line rational arithmetic. This is a genuine infra win
  but consumed a turn on it.
- **Blockers visible from memory**: F=6 polar `FullBdGLHY` 3000×
  spurious (`full_bdg_F6_polar_broken.md`); TwoChannelLHY F=6 30-70%
  off; Klaus 2022 magnetostir not reproducible (Option γ rotating
  basis ~700 LOC, design-only); TDHFB Phase 3+ generic-F HF kernel
  pending; v4 spinor FG extension DERIVED but not coded
  (`force_gradient.jl` line 31-43 docstring says so); cross-validation
  of DDI conventions vs Stuttgart/Innsbruck never done.
- **None of those blockers were touched in T0-T3.**
- **seed.md status**: `runs/_loop/seed.md` is anko's directive
  *specifically for turn 3* (filename collision — single seed.md,
  rewritten each turn). It explicitly says "future turns can use
  compute_sympy for non-trivial rational coefficient derivations
  (e.g. F=6 I_h LHY closed form per the user's exemplar Round 2
  deliverable)." That's a clear hand-off cue for turn 4.

## 2. Recent-turn audit (last 3)

| Turn | Topic | Verdict | Value delivered | Was it right? |
|---|---|---|---|---|
| T1 | FG coefficient invariance docstring (spinor/F>1/DDI) | PASS | +13 lines comment on `force_gradient.jl`; no manuscript section closed, no code path enabled, no verification added. Reduces a hypothetical future-regression blast radius. | Marginal yes. Cheap inoculation. |
| T2 | Nonlinear-V coefficient invariance docstring | PASS | +20 lines comment on same file, same target. Distinguishes (A) coefficient invariance from (B) order-cap separately. | Cheap, but same file *third* turn in a row. Diminishing returns. |
| T3 | compute_sympy infra E2E on 3 trivial identities | PASS | +4 lines comment on same file; first successful `compute_steps[]` exercise. Infrastructure validation, not physics. | Infra value real; topic still same file; theorist authored derivation explicitly said "out of scope — infrastructure-verification turn." |

**Trajectory flag (§B4)**: 4 consecutive turns on the same file
(`force_gradient.jl`), 3 of them pure docstring additions, 1 of
them explicitly an infra test. The theorist hash has rotated only
once (`142e3c..` for T1/T2 → `464b7e..` for T3) — meaning T1+T2
share priors, T3 had a fresh theorist who still landed on the same
file. Implementer hash rotated for T3. This is *exactly* the §B4
"do not dispatch theorist for a 4th iteration" pattern. The seed
for T3 also explicitly handed off: "future turns can use
compute_sympy for non-trivial rational coefficient derivations
(e.g. F=6 I_h LHY closed form)." The seed.md is dated for T3 and
not consumed for T4.

## 3. Bottleneck analysis

Top candidates by (project value × p(this turn moves it) / cost):

- **F=6 polar `FullBdGLHY` 3000× spurious offset**
  *Issue*: memory `full_bdg_F6_polar_broken.md` — ψ converges to the
  same min as `:scalar` but the reported LHY energy contribution is
  off by ~3000×, attributed to λ<0 BdG modes contaminating the sum.
  This is the single LHY bug with the largest blast radius:
  Paper #4 and any F=6 polar work currently can't trust FullBdG.
  *Category*: verification gap + physics gap (sign convention on
  negative-λ branch).
  *Leverage*: 4. Theorist could derive the correct projector;
  implementer could add a `Re λ > 0` filter and bench against
  `:polar_contact`/`:polar_dipolar`.
  *What moves it*: theorist (1 turn) for the projector definition
  on bosonic Bogoliubov negative branch, then implementer (next
  turn) to apply the filter and add regression. Or directly:
  researcher reads Lima & Pelster 2012 sign convention to confirm
  Bose-Bogoliubov sum-rule.

- **Sign Pattern Lemma 1 — extension to a NEW F via compute_sympy**
  *Issue*: memory entries say β_S^{(λ_spin)} closed form verified
  at F=3-12 (Lemma 1 verified at 11+ instances), F=13 added 2026-05-12.
  F=14 and beyond are open; F=5 has an algebraic obstruction
  (no polyhedral invariant). Verifying one more F using the
  freshly-validated `compute_sympy` path is high-signal: it both
  exercises the infra at non-trivial weight and extends Paper #3
  Lemma 1 reach.
  *Category*: physics completeness (theorem extension) +
  infrastructure exploitation (compute_sympy second-real-use).
  *Leverage*: 4. Result is *publishable* (Paper #3 gets an extra
  data row); compute is bounded (≤30 s sympy); seed.md explicitly
  flags this kind of work as the right next direction.
  *What moves it*: implementer with compute_steps[] running
  `scripts/manuscript/lemma1_general_S_verification.jl` at F=14 or
  F=16, OR theorist deriving the explicit decomposition needed.

- **F=6 I_h LHY closed-form rational coefficient**
  *Issue*: seed.md T3 explicitly names this as the exemplar
  "Round 2 deliverable" for compute_sympy.
  *Category*: physics gap (closed form not yet codified).
  *Leverage*: 5 (high — directly publishable in Paper #2 or #3) but
  cost is high: needs the icosahedral CG sum + Schur projection.
  Multi-turn work; not single-turn.
  *What moves it*: theorist Round 1 to set up the symbolic
  problem (which CG coefficients, which Schur projector), then
  implementer Round 2 to run compute_sympy. Single turn: only
  Round 1 fits.

- **v4 spinor FG extension code (matrix V_SM)**
  *Issue*: theorist work in T1 §2 established representation
  invariance ($\alpha_2 = -1/48$ holds for matrix V_SM); the code
  at `force_gradient.jl` lines 54-55 still hard-errors when
  $c_1 \neq 0$. This is the EXACT verification chain T1's
  derivation enables.
  *Category*: code gap (theory done, code blocked).
  *Leverage*: 3. Would convert T1-T3 docstring inoculation into
  actual capability. But cost: ≥1 turn implementer + smoke test.
  Memory `integrator_modernization_status.md` notes a "structural
  order-2 ceiling on the Strang-predictor FG form" was identified,
  so v4 may not get high order even if implemented — paying off
  may be limited.

- **DDI cross-validation vs published Stuttgart group**
  *Issue*: D2 axis (CLAUDE.md project goals): DDI conventions
  believed but never benchmarked against published Eu/Dy/Er groups.
  *Category*: verification gap.
  *Leverage*: 3. High value for credibility, but probably
  multi-turn (researcher to identify a reproducible Stuttgart
  benchmark + implementer to set up). Not single-turn-shaped.

## 4. Strategic options for THIS turn

1. **Lemma 1 at a new F via compute_sympy (researcher + implementer combo, but most naturally an implementer-direct turn)** — exploits validated infra, extends Paper #3 by 1 data row, cost bounded, falsifiable. **Leverage 4.**
2. **Theorist Round 1 of F=6 I_h LHY closed-form (multi-turn)** — high ceiling but single turn delivers only a problem setup, not a result. Leverage 5 over project, 2 for *this* turn.
3. **F=6 polar FullBdGLHY projector derivation (theorist)** — closes a known bug at root. Leverage 4 but T3 just ran theorist; per §B4 we should not default to theorist again unless it's the highest leverage by margin.
4. **v4 spinor FG code (implementer)** — converts T1 docstring into capability. Leverage 3, single-turn-sized, but structural order-2 ceiling caveat caps payoff.
5. **noop** — only justified if quota is tight or no bottleneck is cheap. Neither holds.

**Pick: Option 1 (Lemma 1 at a new F via compute_sympy).**

Why:
- Anko's seed.md (still on disk, T3-targeted but explicitly hands off
  to "F=6 I_h LHY closed form per Round 2 deliverable") signals
  compute_sympy is the path. F=6 I_h is too big for one turn; the
  natural intermediate is a single Lemma 1 extension at a new F.
- It moves Paper #3 manuscript content forward (§A5 (a) — closes a
  manuscript TODO by adding a new verified F to the Lemma 1 table).
- It exercises compute_sympy at non-trivial weight (real rational
  arithmetic on CG coefficients vs T3's trivial 3-line sympy),
  proving the path scales beyond the T3 demonstration.
- §B4 anti-default-theorist applies cleanly: implementer direct, no
  theorist needed since memory says the closed-form derivation is
  already done and the verification script `scripts/manuscript/
  lemma1_general_S_verification.jl` exists. Implementer extends the
  script.
- Cost bounded (sympy CG sums for one F at high rational arithmetic
  ≤60 s per compute_step; total ≤10 min wall).

## 5. Calibrated progress check

- **Physics completeness**: at risk. F=6 polar FullBdGLHY 3000× still
  open. TwoChannelLHY F=6 30-70% off still open. Klaus magnetostir
  still not reproducible. Last 4 turns added zero new effects.
- **Verification depth**: on track for the FG slice (T0 added the
  18/18 regex regression, T1-T3 documented invariance for future
  edits). DDI vs Stuttgart cross-check still untouched. Lemma 1
  reach: F=3-13 verified; F=14+ open.
- **Manuscript**: Paper #1 ready for LaTeX (Round 8 done 2026-05-12).
  Paper #3 Lemma 1 table at 11+ instances, can grow by 1-2 this
  turn. Paper #2 (F=6 I_h) raw; Paper #4 raw. Last 4 loop turns
  touched no manuscript file.
- **Reproducibility**: on track. YAML schema documented, lab-units
  opt-in, resumable runs supported.

Mark: **Physics completeness at risk** — loop has been spinning on
the same file 4 turns. Today's dispatch must turn the wheel toward
either a new physics result, a new verification, or a manuscript
edit. Choosing Option 1 hits "manuscript +1 data row" and
"verification depth +1 F instance" simultaneously.

## 6. Dispatch decision

```json
{
  "subagent_type": "implementer",
  "rationale": "Last 4 turns (T0-T3) all worked the same file (force_gradient.jl) — 3 of them docstring-only, 1 infra validation. §B4 says do not dispatch theorist for a 4th iteration on the same topic; T3 PASS validated the compute_sympy path explicitly so it can be exploited at non-trivial weight. Memory entries (`Sign Pattern Lemma 1 General-S`, `universal_theorem_status.md`) record that the closed form β_S^{(λ_spin)} = [S(S+1) - 2F(F+1)] / [2F(F+1)] · β_S^{(c_0)} is verified across 26 channels at F=3-13 via `scripts/manuscript/lemma1_general_S_verification.jl`, with F=14+ open. Seed.md flags F=6 I_h LHY (Round 2 deliverable) as the long-term compute_sympy target — F=14 Lemma 1 verification is the right single-turn step toward that: real CG-coefficient rational arithmetic, manuscript-extending, infra-exploiting. No new theorist derivation needed: closed form is settled.",
  "brief": "Goal: extend Sign Pattern Lemma 1 verification (Paper #3, §sign_pattern_lemma1_general_S) by one F-value using the newly-validated `compute_sympy` infrastructure (T3 commit `6352726`).\n\nContext / inputs to read first:\n- `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` (closed form: β_S^{(λ_spin)} = [S(S+1) − 2F(F+1)] / [2F(F+1)] · β_S^{(c_0)}).\n- `scripts/manuscript/lemma1_general_S_verification.jl` (existing verifier, verified 26 channels at F=3/4/6/8/10/12/13 per MEMORY.md).\n- `docs/manuscript/papers/paper3_universal_theorem/f_systematic_lemma1_predictions.jl` (per memory, has prediction list).\n- `runs/_loop/sim/turn_3.md` §4 `compute_results[]` for the schema of a successful `compute_steps[]` block.\n\nTask: produce a `modify_code` directive that adds **one new F instance** (target: F=14 if it admits a polyhedral A_1 inert state; otherwise F=11 or F=15 — pick the next-smallest F not yet in the verified list and that has a confirmed polyhedral invariant per memory `Universal Structure U1-U4`). You must:\n\n(1) Identify the target F. Read `scripts/manuscript/f_systematic_lemma1_predictions.jl` (location may need a Glob; if absent, fall back to reading the memory file `universal_theorem_status.md` and choosing F=14 if listed as 'admits polyhedral inert', else F=15 / F=16 / F=11 in that order). Document the choice in §1 of your report (which group/representation: O:A_1, I:A, etc., and a channel S that the verifier will test, e.g. S=2 or S=4).\n\n(2) Run THREE `compute_steps[]` entries via the now-validated `compute_sympy` path:\n  - S1: compute the LHS β_S^{(λ_spin)}(F=target, S=chosen channel) as a `Rational` via the closed-form expression `Rational(S*(S+1) - 2*F*(F+1), 2*F*(F+1))` times a reference β_S^{(c_0)} value (use 1 if needed for purity; otherwise the channel-specific β_S^{(c_0)} from the verifier file).\n  - S2: independently compute the RHS via the Schur-isotropic CG sum at the chosen (F, S) using sympy's Wigner-6j or Wigner-3j (`from sympy.physics.wigner import wigner_3j`). Pick the simplest channel where the sum closes in <10 sympy terms; S=2 is typical.\n  - S3: assert equality `S1 == S2` as a single sympy `print(Eq(lhs, rhs))` or `print(simplify(lhs - rhs))` — expected output `True` or `0`.\n\n(3) Add the F=target row to the Lemma 1 verification table in `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` (find the table; insert one row with F, group, channel S, β_S^{(λ_spin)} value, status='verified-sympy', date 2026-05-15).\n\n(4) Extend `scripts/manuscript/lemma1_general_S_verification.jl` to include the new F (if the script enumerates cases). If the script enumerates by an array, append; if it computes generically, add a corresponding `@test` assertion. The Julia regression must continue to pass (existing 26 channels untouched).\n\n(5) `tests_passed: true` in §4 metrics, all 3 `compute_results` `status: 'OK'`, S3 result must be exactly `'True'` or `'0'`.\n\nFalsification criteria:\n(a) Any compute_step returns FAILED or TIMEOUT — halt, diagnose run_sympy.py call for wigner_3j availability under `uv run --with sympy`.\n(b) S3 result is anything other than `True` / `0` — the closed form fails at this F (would be a Paper #3 finding of its own — escalate to anko, do NOT silently fix).\n(c) Existing `scripts/manuscript/lemma1_general_S_verification.jl` Julia regression breaks (memory: 26 channels exact rational) — revert the script change, keep the manuscript table row + compute_steps.\n(d) Manuscript table row added at wrong location (must be inside the existing Lemma 1 verification table; if no table exists, create one consistent with §sign_pattern_lemma1_general_S.md's existing format).\n\nEstimated cost: ≤12 min wall, ≤1.5M effective tokens. sympy CG sum at single (F, S): ~10-30 s per compute_step (cold cache for wigner module first invoc).\n\nIf F=14 turns out to have no polyhedral invariant of multiplicity 1 (memory flags F=5 as such an obstruction; F=14 may similarly fail), document the obstruction in §1 and pick the next F up — the obstruction itself is a publishable Paper #3 footnote.",
  "expected_outcome": "(1) `runs/_loop/sim/turn_4.md` §4 `compute_results[]` has 3 entries, all status OK, S3 result = 'True' (or '0'). (2) `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` gains one new row in the Lemma 1 verification table at F=target. (3) `scripts/manuscript/lemma1_general_S_verification.jl` extended consistently (or new test asserted), Julia regression still passes. (4) Branch `auto/turn_4_lemma1-F<target>-sympy-extension` with single commit. (5) Lemma 1 verified instance count goes 11+ → 12+, manuscript table goes 26 channels → 27+.",
  "expected_cost": "≤12 min wall-clock, ≤1.5M effective tokens (T3 was 7.6M total / 1.16M effective; this turn is ~same shape — 3 sympy steps + 1 manuscript edit + 1 Julia script edit).",
  "if_fails_next_step": "If the closed form fails at the chosen F (S3 result ≠ True), that's a Paper #3 finding that the general-S formula has an F-range limit — next director turn dispatches theorist to characterize the obstruction (likely a Schur multiplicity > 1 issue per the F=13 T:A note in memory). If compute_sympy infrastructure fails (wigner module unavailable under uv), next turn fixes `run_sympy.py` to pre-load `sympy.physics.wigner` or document the limitation.",
  "consumed_seed_md": false
}
```

`consumed_seed_md`: false. The seed.md on disk is anko's T3 directive
explicitly; it has already been consumed by T3. T4 reads its
hand-off cue ("F=6 I_h LHY closed form … Round 2 deliverable") and
picks the smaller intermediate step (extend Lemma 1 by one F),
which is closer to single-turn-sized. Anko should overwrite
seed.md before T5 if a different direction is desired.
