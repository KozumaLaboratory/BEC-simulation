# Track C — Force-Gradient 4 + DDI: Phase -1 derivation

**Status:** skeleton only, Phase -1 not yet started.
**Protocol:** all edits follow `docs/integrator_phase_minus_1_protocol.md`.
**Goal:** independent extension of Chin's force-gradient 4th-order scheme
from scalar GPE to spinor (F = 6, D = 13) + DDI lab-path V step.
**Time cap:** 2 weeks elapsed.

The thesis section is **§3.5 Force-gradient extension to spinor + DDI**.
See `docs/integrator_ch3_plan.md` for the chapter outline.

---

## Step 0 — Paper fetch list (REQUIRED before any derivation)

The first deliverable of Phase -1 is fetching these three papers and
saving them where anko can confirm. No formula manipulation begins until
all three are in hand.

1. **Chin (1997)** — original force-gradient construction.
   Phys. Lett. A 226, 344. The fourth-order symplectic integrator with
   `[V, [T, V]]` correction term replacing the negative-coefficient
   middle stage of triple-jump composition. Scalar / classical mechanics.

2. **Chin & Krotscheck (2005)** — rotating BEC GPE extension. ★ KEY
   PAPER for Track C. PRE 72, 036705. Applies the force-gradient
   construction to a scalar nonlinear Gross-Pitaevskii equation. This
   gives us the "scalar GPE + force-gradient" recipe as the starting
   point; spinor + DDI extensions are then orthogonal additions on top.

3. **Aichinger, Chin & Krotscheck (2005)** — non-local potential
   generalisation. Provides the framework for handling nonlocal V
   in the force-gradient evaluation, which we need for DDI.

After fetching, transcribe paper key sections into the
"§ Transcribed paper formulas" section below.

---

## Step 1 — Transcribed paper formulas

*(empty; to be filled in Phase -1 session 1, following Rule 1 of the
protocol: verbatim LaTeX from each paper, character-by-character.)*

Expected content blocks:

- **1.1** Chin 1997 eqs. defining the force-gradient operator
  `[V, [T, V]]` and the 4th-order ABA composition coefficients
  including the c·τ² gradient term.
- **1.2** Chin-Krotscheck 2005 scalar GPE form: how `V` becomes
  `V_trap + c₀|ψ|²` and how `[V, [T, V]]` evaluates to a concrete
  gradient quantity for the scalar nonlinear potential.
- **1.3** Aichinger-Chin-Krotscheck 2005 nonlocal extension: how
  `V = ∫ V_nl(r-r') ρ(r') dr'` factors through the
  force-gradient construction.

Reference notation conventions (sign, normalisation, time direction)
exactly as they appear in the paper. Translation to our SpinorBEC
conventions happens in Step 2 with explicit per-symbol mapping.

---

## Step 2 — Notation translation (paper → SpinorBEC)

*(empty; to be filled after Step 1.)*

Per-symbol mapping table:

| Paper symbol | Paper meaning | SpinorBEC symbol | Notes |
|---|---|---|---|
| (e.g.) `ψ` | scalar wavefunction | `psi[I, 1]` for D=1 | sign / phase conv. |
| (e.g.) `V_eff` | mean-field potential | `c0 * density_buf` | `c0` includes `4π·a/m` factor |
| ... | ... | ... | ... |

Sign convention checks: i ∂_t ψ = H ψ in both paper and ours? Hbar = 1?
m = 1? These are typically the same but must be confirmed verbatim.

---

## Step 3 — Scalar GPE force-gradient (derivation from paper eqs.)

*(empty; to be filled in Phase -1 session 1-2.)*

Re-derive Chin-Krotscheck 2005's scalar GPE force-gradient V step
explicitly, using the transcribed Chin 1997 + scalar GPE forms. This is
not new content per se — the point is to (a) verify the protocol works
on a known-correct case before we attempt the spinor + DDI extension,
(b) build the scaffolding (notation, derivation style) that the spinor
extension will reuse.

Expected output: an SpinorBEC-flavored explicit V step formula equivalent
to Chin-Krotscheck 2005 for the c₁ = 0, c_dd = 0, F = 0 case. The
formula should reduce to plain Strang in the limit τ² gradient term → 0.

---

## Step 4 — Spinor matrix extension (independent derivation)

*(empty; to be filled in Phase -1 session 2.)*

Generalise from scalar to spinor: D-component wavefunction `ψ[I, c]`,
mean-field operator H_mf = `c₀|ψ|² + c₁⟨F⟩·F̂ + c₂A₀₀·...` (spinor
matrix algebra; F̂ are the spin-F generators).

Key sub-derivations:

- **4.1** Spinor commutators `[F̂_α, F̂_β] = iε_{αβγ} F̂_γ`. How these
  propagate through `[V, [T, V]]` when V contains `c₁⟨F⟩·F̂`.
- **4.2** Component-wise reduction of `[V, [T, V]]` to a sum over m, m'
  spinor pair channels. Use Clebsch-Gordan basis where the action of F̂
  is sparse.
- **4.3** Self-consistency: at c₁ = c₂ = c₄ = 0 (no spin coupling), the
  derivation must reduce to D-independent component-wise scalar GPE.
  Self-check item (iii.a) "scalar reduction".

---

## Step 5 — DDI nonlocal extension (independent derivation)

*(empty; to be filled in Phase -1 session 3.)*

Generalise from contact (c₀|ψ|², c₁⟨F⟩) to nonlocal DDI:

`Φ_DDI(r) = c_dd ∫ U_dd(r - r') · (spin density)(r') dr'`

where `U_dd` is the dipole-dipole kernel and the convolution is most
efficiently done in Fourier space.

Key sub-derivations:

- **5.1** Apply Aichinger-Chin-Krotscheck 2005 nonlocal recipe to
  Φ_DDI. The `∇V_dd^eff = U_dd ∗ ∇ρ` identity should make the gradient
  term manageable in Fourier space.
- **5.2** Combine with the spinor matrix algebra of Step 4: how does
  `[V, [T, V]]` look when V has BOTH contact spinor and nonlocal DDI
  terms? Cross-term `[V_contact, [T, V_DDI]]` arising from non-commutativity.
- **5.3** Self-check (iii.b) "DDI off": setting c_dd → 0 must reduce to
  Step 4's spinor-only result.

---

## Step 6 — Time-reversal symmetry verification

*(empty; protocol Rule 3, self-check (iii.c).)*

Apply the proposed Force-Gradient V step S_FG(τ) to a trial state ψ_0,
then apply S_FG(-τ) to the result. Verify
`S_FG(-τ) · S_FG(τ) · ψ_0 = ψ_0`
to the order of the scheme (= O(τ⁵) residual, since FG is order 4).

This is a symbolic check at formula level. No Picard fixed-point yet
(Phase 0 will handle that). The check should pass exactly at every
power of τ up to τ⁴.

---

## Step 7 — Conservation property verification

*(empty; protocol Rule 3, self-check (iii.d).)*

Compute the variation of the following invariants under the proposed
S_FG(τ) at leading O(τ) and O(τ³):

- `⟨ψ | ψ⟩` (norm): should be exactly preserved at every order
- `⟨ψ | F̂_z | ψ⟩` (magnetization M_z): preserved if the c₂A₀₀ term is
  the only off-diagonal-in-m spinor coupling and we set c₂ = 0; check
  the c₂ ≠ 0 case separately for completeness
- `⟨ψ | H | ψ⟩` (energy): should drift at O(τ⁴) for order-4 scheme.
  This is NOT exact energy preservation — Force-Gradient achieves order 4,
  not exact conservation. Confirm the leading drift constant in our
  spinor + DDI setting.

---

## Failed branches

*(none yet — to be appended when derivation hits dead ends.)*

Failed-branch format (per protocol Rule 2):

```
### Failed branch (YYYY-MM-DD): [short description]

**Attempt:** [what we tried]
**Failure mode:** [where it diverged / what self-check failed]
**Hypothesis at start:** [why we tried this]
**Lesson:** [what to avoid in the next attempt]
**Reusable:** [any sub-result still usable elsewhere]
```

---

## Phase -1 exit criteria (protocol Rule 3 review)

The following must all be true before Phase 0 implementation begins:

- [ ] Step 0: all three papers fetched and accessible to anko
- [ ] Steps 1-2: paper formulas transcribed verbatim, notation translation
      table complete
- [ ] Step 3: scalar GPE force-gradient re-derived as a warm-up
- [ ] Step 4: spinor matrix extension complete, reduces to Step 3 at
      c₁ = c₂ = c₄ = 0
- [ ] Step 5: DDI nonlocal extension complete, reduces to Step 4 at
      c_dd = 0
- [ ] Step 6: time-reversal symmetry verified to O(τ⁴)
- [ ] Step 7: norm conservation exact, Mz conservation at c₂ = 0,
      energy drift constant computed
- [ ] anko review pass on transcription accuracy + step justification +
      self-check completion

If 2 weeks elapse without all items checked, scope decision per
protocol Rule 4.
