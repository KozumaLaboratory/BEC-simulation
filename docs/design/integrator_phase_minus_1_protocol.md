# Phase -1 protocol — paper fetch + 紙 derivation as hard gate

> **FROZEN 2026-05-23.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Applies to:** Track C (Chin Force-Gradient + DDI).

**Purpose:** Prevent the failure mode that hit Track A1.5 (AVF
state-averaging negative) and earlier MPS-{10,12} over-optimism: a
formula was paraphrased from memory at proposal time, implemented under
that paraphrase, and the implementation took a week + bench cycle to
reveal the gap. Phase -1 hard-gates Phase 0 implementation on a written
manuscript that survives anko's review.

---

## Rule 1 — No memory paraphrase

All formulas in `docs/design/integrator_track_{c,b}_derivation.md` begin with a
**verbatim transcription** of the source paper formula. Format:

```
> **Paper eq. (N)**, Chin-Krotscheck 2005, PRE 72, 036705:
> [LaTeX from paper, copied character-by-character]

[Derivation step / interpretation by us, clearly separated from the
quote above.]
```

If a formula has to be expressed in our notation (e.g., the paper uses
different sign conventions), the paper form is transcribed FIRST and the
notation translation is shown as a separate explicit step. Memory paraphrase
is not allowed: every formula must be traceable back to a cited paper
eq. number or to a previous step in the same document.

When the paper itself derives the formula via intermediate steps, those
intermediate steps are also transcribed. The derivation manuscript shows
the full chain, not just the final identity.

---

## Rule 2 — Running document (failed branches preserved)

The derivation manuscripts are append-only running documents. Each Phase -1
session adds:

- New transcribed paper sections (Rule 1 form)
- New derivation steps (toward the spinor + DDI extension)
- **Failed branches**: algebraic dead-ends, Fréchet divergences, sign
  errors caught, alternative reductions abandoned

Format for failed branches:

```
### Failed branch (YYYY-MM-DD): [short description]

**Attempt:** [what we tried]
**Failure mode:** [where it diverged / what self-check failed]
**Hypothesis at start:** [why we tried this]
**Lesson:** [what to avoid in the next attempt]
**Reusable:** [any sub-result still usable elsewhere]
```

Reasons:

- Future-us reading the manuscript needs to see why current-us discarded
  branch X — otherwise we'll re-try it 6 months later
- Negative results have manuscript-Ch.3 value (cf. AVF state-averaging
  §3.3.2): the failure mode IS the contribution

The manuscript never gets rebased / squashed to remove failed branches.

---

## Rule 3 — 3-condition anko review for Phase 0 entry

A Phase -1 manuscript exits review (= Phase 0 implementation can start)
only when **all three conditions hold**:

### (i) Transcription verified
Every formula in the manuscript referenced as "from paper X eq. (N)"
matches the paper character-by-character. anko reads the paper alongside
the manuscript and confirms.

### (ii) Each derivation step is justified
Every algebraic step in the manuscript (combining transcribed identities
to reach our spinor + DDI extension) has either (a) an explicit cited
rule (e.g., "[ψ, ∇] = 0 since ψ is a c-number wavefunction"), or
(b) a self-contained derivation in the manuscript proving the step. No
"obvious", no "by symmetry" without explicit symmetry argument.

### (iii) Self-check items pass
The following four checks must be performed symbolically on the final
spinor + DDI extension and reported in the manuscript:

- **Limit case: scalar reduction.** Set spinor structure to trivial
  (F = 0 or c₁ = c₂ = c₄ = 0, single component). The extension must
  reduce to the published scalar GPE Force-Gradient (Track C) verbatim.
- **Limit case: DDI off.** Set c_dd = 0. The extension must reduce to
  the spinor-only contact case, which itself reduces (via the previous
  check) to the scalar case.
- **Time-reversal symmetry.** Apply the proposed V step operator to a
  trial state, then apply its formal inverse (τ → −τ). Verify that
  S(τ) · S(−τ) = I to the order of the scheme. This is symbolic — no
  Picard residual yet, since Phase -1 is formula-level only.
- **Conservation properties.** Compute ⟨ψ | norm | ψ⟩ and ⟨ψ | Mz | ψ⟩
  variation under the proposed V step at order O(τ³). They must vanish
  at the expected order.

If any of (i)/(ii)/(iii) fails, the manuscript stays in Phase -1; the
failure is recorded as a failed branch (Rule 2); the next attempt
modifies the derivation accordingly.

---

## Rule 4 — Time hard cap

- **Track C Phase -1: 2 weeks** total elapsed.

If the cap is hit and Rule 3 review hasn't passed:

- Track C cap hit → re-evaluate Track C scope: drop, retry with different
  framing (e.g., explicit V_dd^eff form vs Fourier form), or accept a
  weaker scheme (Y4-midpoint baseline + Force-Gradient deferred to follow-up
  work).

The cap is enforced. "We're 90% done, give it another week" is the sunk
cost trap that motivated this protocol in the first place.

---

## Why this protocol exists

The AVF state-averaging negative result (Track A1.5, commit 63ad7c1)
consumed approximately half a session: implementation, Phase 2a verification,
Picard convergence diagnostic, Phase 5 smoke, Phase 5 re-run with milder
parameters. Net contribution to the thesis: one negative result
documented as §3.3.2. Net cost: a real day of work + the cognitive
overhead of refactoring the framework after the negative result landed.

The trigger for that loss was a **memory paraphrase** of the AVF formula
at the proposal stage. The literal AVF expression
`f̄ = (1/2)[f(ψⁿ) + f(ψⁿ⁺¹)]` was used as if it were the
Quispel-McLaren method, when in fact (a) Quispel-McLaren's true AVF
integrates ∇H along the segment with Gauss-Legendre quadrature, not
trapezoidal endpoint averaging; (b) implementing the literal trapezoidal
in our framework slipped into state-averaging
`f((ψⁿ + ψⁿ⁺¹)/2)`, which differs from the vector-field-averaging
`(f(ψⁿ) + f(ψⁿ⁺¹))/2` by `cos(Hτ/2)` (even-power-in-τ shift). Neither
form is true AVF.

Track C (Chin Force-Gradient — `[V, [T, V]]` with full DDI nonlocal
extension) involves formulas at least an order of magnitude more
elaborate than AVF. Without the protocol above, the AVF-class failure
WILL repeat at greater cost. Hence: paper fetch + verbatim transcription
+ 3-condition review + time cap, before any Phase 0 line of code.

---

## How to use this document

When starting Track C or B Phase -1:

1. Read this document.
2. Open the appropriate `docs/design/integrator_track_{c,b}_derivation.md`
   skeleton.
3. Begin by fetching the listed papers (PDF saved or URL bookmarked).
4. Append-only edits to the derivation manuscript, following Rule 1
   (transcription first) and Rule 2 (preserve failed branches).
5. Track cumulative elapsed time. If approaching the Rule 4 cap with
   review not yet passed, surface to anko for a scope decision.
6. When Rule 3 (i/ii/iii) is satisfied, request anko's review. Phase 0
   implementation begins only after review pass.
