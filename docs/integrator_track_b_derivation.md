# Track B — Thalhammer 2026 modified splitting (F=13 + DDI): Phase -1 derivation

**Status:** skeleton only, Phase -1 not yet started.
**Protocol:** all edits follow `docs/integrator_phase_minus_1_protocol.md`.
**Goal:** independent extension of Thalhammer & Thalhammer-Thurner (2026)
modified splitting from paper's J = 2 contact-only case to F = 6 / D = 13
spinor + DDI.
**Time cap:** 4 weeks elapsed.

The thesis section is **§3.6 Modified splitting for spinor + DDI**. See
`docs/integrator_ch3_plan.md` for the chapter outline.

**Conditional execution.** Track B begins only if Track C either fails to
reach Phase 3 Pareto win OR fails to give ≥10× energy drift improvement
vs Y4-midpoint in Phase 5. See `docs/integrator_ch3_plan.md` for the
Track B skip decision protocol.

---

## Step 0 — Paper fetch list (REQUIRED before any derivation)

1. **Thalhammer & Thalhammer-Thurner (2026)** ★ KEY PAPER.
   arXiv:2601.19838. 34 pages, January 2026. Modified splitting for
   J-component coupled GPE with contact-only interactions. §2 contains
   the Lie-derivative formalism; eq.(11) the J-component GPE form;
   eqs.(18a-c) the modified splitting structure with the
   `+ c_i τ² G` correction term; eq.(19a-e) the explicit form of
   G = [DF₂, [DF₂, DF₁]] for the J = 2 case; eq.(22) the 4th-order
   coefficient choice (s=3, a=(0,1/2,1/2), b=(1/6,2/3,1/6),
   c=(0,−1/72,0)). anko has read parts; full re-read with verbatim
   transcription is the first deliverable.

2. **Hairer, Lubich & Wanner**, *Geometric Numerical Integration*
   (Springer, 2nd ed. 2006), Ch.III. Background on Lie-derivative
   formalism used in Thalhammer 2026. Needed especially for §III.5
   (composition methods) and §III.4 (symmetric and symplectic order
   conditions). Reference book — section transcription rather than
   full paper transcription.

After fetching, transcribe paper / chapter sections into "§ Transcribed
formulas" below.

---

## Step 1 — Transcribed formulas

*(empty; to be filled in Phase -1 sessions 1-2.)*

Expected content blocks:

- **1.1** Thalhammer 2026 eq.(11): J-component GPE form
  `i ∂_t ψ_j = Δ_{α_j} ψ_j + V_j ψ_j + Σ_k ϑ_{jk} |ψ_k|² ψ_j`. Note
  this is contact-only, no DDI, no F-matrix spinor coupling (ϑ is a
  real-symmetric J×J matrix, not F-matrix structure).
- **1.2** Thalhammer 2026 eqs.(18a-c): modified splitting structure
  ABA-form with a `c_i τ² G` correction term where G is the iterated
  commutator of Lie derivatives.
- **1.3** Thalhammer 2026 eq.(19a-e): explicit G for J = 2 case.
  Approximately 30 terms involving `∇_{α_j} ψ̃_k · ∇ ψ̃_l ψ̃_m` triple
  products, `Δ_{α_j} V_k` Laplacians of potentials, and
  `(Δ_{α_1} − Δ_{α_2}) ψ̃` cross-component Laplacian differences. This
  is the explicit form we extend.
- **1.4** Thalhammer 2026 eq.(22): 4th-order coefficient choice
  `s = 3, a = (0, 1/2, 1/2), b = (1/6, 2/3, 1/6), c = (0, −1/72, 0)`.
  Principal coefficients (a, b) non-negative ⇒ imaginary-time stable;
  the τ²-scaled c handles the negative-coefficient issue.
- **1.5** HLW Ch.III selected: Lie-derivative definition, action of `D`
  on smooth functionals, the Jacobi identity, the BCH-style commutator
  expansion for composed flows.

---

## Step 2 — Notation translation (paper → SpinorBEC)

*(empty; to be filled after Step 1.)*

Paper uses index `j ∈ {1, ..., J}` for components; we use `c ∈ {1, ..., D}`
where `D = 2F + 1 = 13` for Eu151 F = 6. Paper's `ϑ_{jk}` real-symmetric
contact matrix has NO spinor-matrix-F̂ structure — for our spinor
problem this is the first non-trivial extension. Per-symbol mapping
table:

| Paper symbol | Paper meaning | SpinorBEC analog | Notes |
|---|---|---|---|
| `J` | component count | `D = 2F + 1 = 13` | F = 6 fixed |
| `ϑ_{jk}` | real contact matrix | c₀ δ + c₁ ⟨F̂⟩·F̂_{jk} + ... | not real-symmetric in general — F̂ is hermitian but matrix-valued |
| `V_j` | scalar potential per j | V_trap + zeeman[j] | diagonal in component index |
| `Δ_{α_j}` | per-component Laplacian | same Δ for all D | (no mass differences in our problem) |
| `F_1` | kinetic + scalar potential | T + V_diag | linear in ψ, diagonal in component |
| `F_2` | contact nonlinear | c₀|ψ|² + c₁⟨F̂⟩·F̂ + DDI | non-diagonal in component due to F̂, nonlocal due to DDI |
| ... | ... | ... | ... |

Note the paper's `ϑ_{jk}` is a c-number matrix in component space, while
our analog includes F-matrix operators (spin rotation generators) and a
non-local DDI convolution. These are TWO orthogonal extensions:

- **Extension X1 (spinor matrix)**: from ϑ_{jk} ∈ ℝ to spin-coupling
  matrix in component space. The Fréchet derivative DF₂ then carries
  F̂ matrix-valued action, not just per-component scalar.
- **Extension X2 (DDI nonlocal)**: from local |ψ_k|² to nonlocal
  convolution with U_dd. The Fréchet derivative DF₂ then has a
  nonlocal kernel.

Both extensions must be made consistent with the paper's Lie-derivative
algebra simultaneously.

---

## Step 3 — Lie-derivative formalism (re-derived from HLW + Thalhammer)

*(empty; to be filled in Phase -1 session 2.)*

Re-derive the action of `D_F₁` and `D_F₂` (Lie derivatives associated
with vector fields F₁, F₂) on smooth functionals of ψ. Verify the Jacobi
identity in this context. This is a warm-up showing the formalism works
in our notation before extension steps.

Expected output: explicit formulas
`(D_F g)(ψ) = g'(ψ) · F(ψ)`
adapted to ψ ∈ L²(ℝ³; ℂ^D), and the commutator
`[D_F, D_G] = D_{[F,G]}` where `[F, G] = G'·F − F'·G` is the
Jacobi-Lie bracket of vector fields.

---

## Step 4 — DF₂ spinor F=6 explicit form (X1 extension, no DDI yet)

*(empty; to be filled in Phase -1 session 2-3.)*

For F₂ = (c₀|ψ|² + c₁⟨F̂⟩·F̂ + c₂A₀₀ + tensor) ψ (contact spinor, no DDI):

Compute DF₂ explicitly as an operator acting on ψ ∈ ℂ^13. The result is
a 13 × 13 matrix-valued differential operator (no derivative in space
for contact term, but matrix action in component space).

Key sub-derivations:

- **4.1** Variational derivative δ(c₀|ψ|²)/δψ* = c₀|ψ|²ψ (diagonal in
  component index)
- **4.2** Variational derivative δ(c₁⟨F̂⟩·F̂)/δψ* (matrix-valued; F̂
  generators act on ψ)
- **4.3** Combined DF₂ matrix structure for F = 6
- **4.4** Self-consistency: at c₁ = c₂ = c₄ = 0, DF₂ must reduce to
  scalar diagonal (Thalhammer 2026 J = 1 limit, equivalent to paper
  J = 2 with ϑ_{11} = c₀, ϑ_{22} = c₀, ϑ_{12} = 0)

---

## Step 5 — DDI nonlocal Fréchet derivative (X2 extension)

*(empty; to be filled in Phase -1 session 3.)*

For the DDI term `F_DDI[ψ] = c_dd ∫ U_dd(r - r') (F̂_α ψ)(r')(F̂_β ψ*)(r') · k̂_αk̂_β / k̂² dr'`,
or equivalently in Fourier `Φ_DDI(k) = U_dd(k) · S(k)` where S(k) is the
spin density spectrum:

Compute DF_DDI as a nonlocal operator. The variational derivative has
contributions from the convolution kernel U_dd which the paper's
contact-only framework doesn't address.

Key sub-derivations:

- **5.1** Express Φ_DDI[ψ] · ψ in functional form
- **5.2** Variational derivative δΦ_DDI/δψ* with care for the nonlocal
  kernel
- **5.3** Combine with Step 4 X1 extension: total DF₂ = DF₂_contact +
  DF_DDI
- **5.4** Self-consistency: at c_dd → 0, DF₂ reduces to Step 4 contact
  form

---

## Step 6 — Iterated commutator G = [DF₂, [DF₂, DF₁]]

*(empty; to be filled in Phase -1 session 4-6. This is the hardest step.)*

Paper eq.(19a-e) gives the explicit G for J = 2 contact only — already
~30 terms. Our F = 6 + DDI version is expected to have at least 100+
terms, with substantial new structure coming from:

- F-matrix non-commutativity `[F̂_α, F̂_β] = iε_{αβγ} F̂_γ` in the
  spinor coupling part
- Nonlocal DDI kernel commutating with kinetic Δ but not with contact
  V_diag in general — produces cross-terms `[T, V_DDI]` with non-trivial
  spatial gradient structure
- Triple products `(∇_{α_j} ψ̃_k) · (∇ ψ̃_l) · ψ̃_m` extended to all
  combinations of m, m' ∈ −F..F

Key sub-derivations:

- **6.1** [DF₁, DF₂_contact]: kinetic Laplacian + spinor matrix
- **6.2** [DF₁, DF_DDI]: kinetic + nonlocal convolution. Both Δ and DDI
  diagonal in Fourier ⇒ commute in Fourier; check carefully.
- **6.3** [DF₂_contact, [DF₁, DF₂_contact]]: spinor analog of paper
  eq.(19a-e)
- **6.4** [DF₂_contact, [DF₁, DF_DDI]]: contact × DDI cross-term
- **6.5** [DF_DDI, [DF₁, DF₂_contact]]: DDI × contact cross-term
- **6.6** [DF_DDI, [DF₁, DF_DDI]]: DDI × DDI term (likely small but
  must compute)
- **6.7** Total G = sum of 6.3-6.6. Expected ~100-200 explicit terms.

This step is the time sink for Track B. The 4-week Phase -1 cap is set
based on this expectation.

---

## Step 7 — 4th-order coefficient solve (paper eq.(22) structure)

*(empty; to be filled in Phase -1 session 7-8.)*

Paper eq.(22) gives `(s=3, a=(0,1/2,1/2), b=(1/6,2/3,1/6), c=(0,−1/72,0))`
for the J = 2 case. Verify these coefficients still satisfy 4th-order
order conditions in the extended setting (spinor + DDI). Order conditions
involve `G` evaluated at appropriate stages.

If the paper's coefficients ARE consistent: confirm via order-condition
verification (symbolic algebra; small terms must vanish at appropriate
powers of τ). Then the implementation can use the same coefficients.

If the paper's coefficients are NOT consistent (e.g., because the extra
G terms from extension X1/X2 introduce a new constraint), solve for new
coefficients. This is a small linear system in (a, b, c) — feasible by
hand or symbolic algebra.

---

## Step 8 — Time-reversal + conservation self-checks

*(empty; protocol Rule 3, self-check (iii.c)-(iii.d).)*

Same as Track C Step 6-7:

- Symbolic verify `S_TM(τ) · S_TM(−τ) = I` to O(τ⁵)
- Norm conservation exact, Mz conservation at c₂ = 0
- Energy drift at O(τ⁴)

---

## Failed branches

*(none yet — to be appended when derivation hits dead ends.)*

Format per protocol Rule 2.

---

## Phase -1 exit criteria

- [ ] Step 0: papers fetched, accessible to anko
- [ ] Steps 1-2: transcription + notation translation complete
- [ ] Step 3: Lie-derivative formalism verified in our notation
- [ ] Step 4: DF₂ spinor F=6 explicit, reduces to scalar at c₁ = c₂ = c₄ = 0
- [ ] Step 5: DDI nonlocal Fréchet complete, reduces to Step 4 at c_dd = 0
- [ ] Step 6: G = [DF₂, [DF₂, DF₁]] explicit (~100+ terms documented)
- [ ] Step 7: 4th-order coefficient consistency / solve
- [ ] Step 8: time-reversal verified, conservation properties documented
- [ ] anko review pass per protocol Rule 3

If 4 weeks elapse without all items checked, scope decision per
protocol Rule 4 (likely outcome: Track B dropped, §3.6 pivots to
expanded Track C case study).
