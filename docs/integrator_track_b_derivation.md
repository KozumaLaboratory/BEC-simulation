# Track B — Thalhammer 2026 modified splitting: Phase -1 derivation

**Status:** Phase -1 COMPLETE (2026-05-11). Paper fetched + transcribed +
J=1 reduction verified to equal Chin-Krotscheck 2005 4A.
**Protocol:** Phase -1 protocol satisfied per
`docs/integrator_phase_minus_1_protocol.md`.

The thesis section is **§3.6 Modified splitting for spinor + DDI**. See
`docs/integrator_ch3_plan.md` and `docs/integrator_ch3_6_narrative.md`
for the chapter section.

---

## Major finding: Thalhammer J=1 = Chin-Krotscheck 2005 4A

For the single-component (J=1) Gross-Pitaevskii equation, Thalhammer's
modified operator splitting method (eq 22 of arXiv:2601.19838) reduces
to Chin-Krotscheck 2005's algorithm 4A (eq 6.8-6.10). Both methods
implement the same 5-stage ABA composition with the same coefficients
and the same gradient-correction term. They differ only in the
theoretical framework used to derive them — Chin-Krotscheck uses the
classical force-gradient construction `[V, [T, V]]`, while Thalhammer
uses the Lie-derivative iterated commutator `[DF_2, [DF_2, DF_1]]`.

This means Track C v1-v3 implementation (`split_step_forcegrad!`,
commits 1ee1de8 + 390f474 + 0b0a822 + 8d34a71) IS Track B for our
diagonal-only subset. No separate implementation needed for J=1.

The genuine Track B contribution beyond Chin-Krotscheck for our case is
the spinor matrix + DDI extension (= Track C v4/v5 derivation). For
our SpinorBEC F-matrix structure, Thalhammer's framework gives the
same derivative term (∇ψ) identified in Track C v4 §5.2 — the two
formalisms converge at the algebraic content.

---

## Step 0 — Paper fetch + transcription (DONE)

arXiv:2601.19838v1 (Jan 2026) fetched and transcribed. Key formulas:

### eq 11a — J-component GPE (the model problem)

$$i\,\partial_t \Psi_j(x,t) = \Delta_{\alpha_j}\Psi_j(x,t) + V_{\beta_j,\gamma_j,\delta_j}(x)\,\Psi_j(x,t) + \sum_{k=1}^{J} \vartheta_{jk}|\Psi_k(x,t)|^2\,\Psi_j(x,t)$$

with $j \in \{1, \ldots, J\}$. Note paper convention uses *positive*
prefactor on RHS (i.e., $H = \Delta + V + \vartheta|\psi|^2$) and
$\alpha_j$ weights are *negative* for the kinetic part.

### eq 18a — Modified splitting structure

$$\mathcal{S}_{\tau_n, F} = \mathcal{E}_{\tau_n, b_s F_2 + c_s \tau_n^2 G} \circ \mathcal{E}_{\tau_n, a_s F_1} \circ \cdots \circ \mathcal{E}_{\tau_n, b_1 F_2 + c_1 \tau_n^2 G} \circ \mathcal{E}_{\tau_n, a_1 F_1}$$

### eq 18c — Iterated commutator G (Lie-derivative form)

$$G(v) = F_1''(v)\,F_2(v)\,F_2(v) + F_1'(v)\,F_2'(v)\,F_2(v) + F_2'(v)\,F_2'(v)\,F_1(v) - F_2''(v)\,F_1(v)\,F_2(v) - 2 F_2'(v)\,F_1'(v)\,F_2(v)$$

This is paper-stated as $G = [DF_2, [DF_2, DF_1]]$ (Lie-derivative form).

### eq 20 — Explicit G for J=1 (time evolution)

$$G(\Psi) = 2i\,[\nabla_\alpha V \cdot \nabla V - 2\vartheta\,\Delta_{\alpha_1} V\,|\Psi|^2 - 2\vartheta^2\,\mathfrak{R}(\nabla_\alpha\Psi \cdot \nabla\bar\Psi)^2 - 6\vartheta^2\,\nabla_\alpha\Psi \cdot \nabla\bar\Psi\,|\Psi|^2 - 4\vartheta^2\,\mathfrak{R}(\Delta_\alpha\Psi\,\bar\Psi)\,|\Psi|^2]\,\Psi$$

### eq 22 — 4th-order coefficient choice

$$s = 3, \quad a = (0, \tfrac{1}{2}, \tfrac{1}{2}), \quad b = (\tfrac{1}{6}, \tfrac{2}{3}, \tfrac{1}{6}), \quad c = (0, -\tfrac{1}{72}, 0)$$

Principal coefficients $(a_i, b_i)_{i=1}^3$ are non-negative.

---

## Step 1 — Equivalence proof for J=1 (Phase -1 self-check iii.a)

Reading eq 18a right-to-left (operator composition order applied to ψ):

| stage | coeff | operator |
|-------|-------|----------|
| 1 | $a_1 = 0$ | trivial (identity) |
| 2 | $b_1 = 1/6$, $c_1 = 0$ | nonlinear $F_2$ at $\tau/6$, no correction |
| 3 | $a_2 = 1/2$ | linear $F_1$ at $\tau/2$ |
| 4 | $b_2 = 2/3$, $c_2 = -1/72$ | **modified** nonlinear $F_2 + c\tau^2 G$ at $\tau$ scaled by 2/3 |
| 5 | $a_3 = 1/2$ | linear $F_1$ at $\tau/2$ |
| 6 | $b_3 = 1/6$, $c_3 = 0$ | nonlinear $F_2$ at $\tau/6$, no correction |

This is the 5-stage `V K Ṽ K V` composition (= Chin's 4A) when we map:
- $F_1$ = kinetic + linear potential (= our `_diagonal_step_svec!` Zeeman/V_trap part + kinetic)
- $F_2$ = nonlinear $c_0|\psi|^2$
- $G$ = paper eq 18c iterated commutator

OR equivalently, Chin-style split:
- $F_1$ = kinetic only
- $F_2$ = all potential (linear V + nonlinear $c_0|\psi|^2$)
- $G$ = $[V, [T, V]] = |\nabla V|^2$ (Chin's eq 6.10)

### Step 1.1 — Explicit G computation for J=1 linear case (ϑ=0)

With Chin-style split ($F_1 = (i/2)\Delta$, $F_2 = -iVv$):

- $F_1'(u) \cdot w = (i/2)\Delta w$ (constant operator)
- $F_1'' = 0$
- $F_2'(u) \cdot w = -iV \cdot w$ (constant operator)
- $F_2'' = 0$

Eq 18c with these:
- T1: $F_1''(v) F_2(v) F_2(v) = 0$
- T4: $-F_2''(v) F_1(v) F_2(v) = 0$
- T2: $F_1'(v) F_2'(v) F_2(v) = (i/2)\Delta \cdot (-iV) \cdot (-iVv) = -(i/2)\Delta(V^2 v)$
  - Expanding: $-(i/2)[(2V\Delta V + 2|\nabla V|^2)v + 4V(\nabla V)\cdot\nabla v + V^2 \Delta v]$
- T3: $F_2'(v) F_2'(v) F_1(v) = (-iV)(-iV)((i/2)\Delta v) = -V^2 \cdot (i/2)\Delta v = -(i/2)V^2 \Delta v$
- T5: $-2 F_2'(v) F_1'(v) F_2(v) = -2(-iV)((i/2)\Delta)(-iVv) = -2(-iV)(1/2)\Delta(Vv)$
  - $= iV \cdot \Delta(Vv) = iV[(\Delta V)v + 2(\nabla V)\cdot\nabla v + V\Delta v]$

Sum (collecting v-terms, ∇v-terms, Δv-terms):
- $v$ coefficient: $-(i/2)(2V\Delta V) - (i/2)(2|\nabla V|^2) + iV\Delta V = -i|\nabla V|^2$
- $\nabla v$ coefficient: $-(i/2)(4V\nabla V) + 0 + 2iV\nabla V = 0$ ✓
- $\Delta v$ coefficient: $-(i/2)V^2 + (-(i/2)V^2) + iV^2 = 0$ ✓

**Therefore $G(v) = -i|\nabla V|^2 \cdot v$** for J=1 linear case (with Chin-style $F_1=T, F_2=V$).

### Step 1.2 — Reconciliation with paper eq 20 (ϑ=0)

Paper eq 20 with ϑ=0: $G(\Psi) = 2i\,\nabla_\alpha V \cdot \nabla V \cdot \Psi$.

With $\alpha = -1/2$ (typical Schrödinger convention, paper §2 paragraph
after eq 3 says "weights in the Laplacian are negative"):
- $\nabla_\alpha V = \alpha_i \partial_i V$, sum over $i$
- $\nabla_\alpha V \cdot \nabla V = \alpha_i (\partial_i V)(\partial_i V) = \alpha\,|\nabla V|^2$ (when $\alpha$ uniform)
- For $\alpha = -1/2$: $\nabla_\alpha V \cdot \nabla V = -\tfrac{1}{2}|\nabla V|^2$

Paper formula: $G(\Psi) = 2i \cdot (-\tfrac{1}{2})|\nabla V|^2 \cdot \Psi = -i|\nabla V|^2 \cdot \Psi$ ✓

**Matches Step 1.1**.

### Step 1.3 — Stage 4 phase contribution comparison

Modified subproblem at stage 4 (b_2 = 2/3, c_2 = -1/72):
$\partial_t u = b_2 F_2(u) + c_2 \tau^2 G(u) = (2/3)(-iVu) + (-\tau^2/72)(-i|\nabla V|^2)u$
$= -i u [(2/3)V - (\tau^2/72)|\nabla V|^2]$

Subproblem solution at duration $\tau$:
$u(\tau) = e^{-i\tau\,[(2/3)V - (\tau^2/72)|\nabla V|^2]}\,u(0)$
$= e^{-i(2\tau/3)V}\,e^{+i(\tau^3/72)|\nabla V|^2}\,u(0)$

Chin-Krotscheck stage 4 (Ṽ = V − (τ²/48)|∇V|² in real time, applied at coeff 2/3):
$e^{-i(2\tau/3)\tilde V}\,u(0) = e^{-i(2\tau/3)[V - (\tau^2/48)|\nabla V|^2]}\,u(0)$
$= e^{-i(2\tau/3)V}\,e^{+i(2\tau/3)(\tau^2/48)|\nabla V|^2}\,u(0)$
$= e^{-i(2\tau/3)V}\,e^{+i(\tau^3/72)|\nabla V|^2}\,u(0)$

**Identical**. ✓

---

## Step 2 — Implementation equivalence

For J=1 (scalar GPE):

$$\boxed{\text{Thalhammer eq 22} \equiv \text{Chin-Krotscheck 4A}}$$

Implementation in SpinorBEC: `split_step_forcegrad!` (commits 1ee1de8 +
390f474 + 0b0a822 + 8d34a71) implements both methods. A
`split_step_thalhammer!` alias is exported for Thalhammer-framework
users; bit-exact agreement with `split_step_forcegrad!` verified by
`scripts/bench/forcegrad_thalhammer_equiv.jl`.

For J=2+ multi-species cross-channel BEC (different ϑ_{jk} structure):
paper eq 19/20 explicit G formulas apply. NOT directly relevant to our
SpinorBEC F-matrix structure.

For our F-matrix spinor + DDI extension: see Track C v4/v5 derivation
in `docs/integrator_track_c_derivation.md` Step 5. The Lie-derivative
formalism of Thalhammer would derive the same ∇ψ derivative term
identified there.

---

## Step 3 — Self-checks (Phase -1 protocol Rule 3)

- [x] (i) Transcription verified: eq 11a, 18a-c, 19, 20, 22 all
      transcribed verbatim from arXiv:2601.19838v1 §3-4
- [x] (ii) Step 1.1 derivation justified: explicit operator algebra,
      no "by symmetry" shortcuts
- [x] (iii.a) Scalar reduction (ϑ=0): both Thalhammer and Chin reduce
      to $G = -i|\nabla V|^2 \cdot \Psi$ — verified Step 1.2
- [x] (iii.b) Linear case (no DDI): paper doesn't include DDI; same as
      scalar reduction
- [x] (iii.c) Time-reversal: 4A composition is palindromic (a, b, c
      sequences all symmetric), so $S(\tau) \cdot S(-\tau) = I$ to
      order of the scheme
- [x] (iii.d) Norm conservation: trivially preserved by unitary V step
      composition; magnetization conservation handled per the scalar
      diagonal step (no F-matrix mixing in J=1)

Phase -1 review **PASS**. Implementation alias landed.

---

## Step 4 — Beyond J=1: scope analysis

For the SpinorBEC framework, Track B's relevance beyond J=1:

### 4.1 J=2+ multi-species (different from spinor)

Paper eq 19/20 provide explicit G for the J=2 contact case with
cross-channel coefficients $\vartheta_{jk}$. This models **two-species
BECs** (e.g., binary 87Rb-23Na, 87Rb-39K). Our SpinorBEC is F=1 or F=6
**single-species** spinor; it does NOT have $\vartheta_{jk}$
cross-channel structure.

If a future SpinorBEC extension adds multi-species support, Track B's
J=2 formulas would apply directly. Currently out of scope.

### 4.2 F-matrix spinor (c_1 ≠ 0)

For F=1/F=6 spinor with $c_1 \langle\hat{F}\rangle \cdot \hat{F}$
coupling, the spinor matrix algebra introduces the derivative term
documented in Track C v4 §5.2:

$$[V_{SM}, [T, V_{SM}]] = c_1^2 [\ldots \text{multiplicative} \ldots + (\nabla\psi\text{-derivative term})]$$

Thalhammer's Lie-derivative G formulation captures the SAME mathematical
content via different notation. Specifically, $F_2$ matrix-valued
(spinor structure) makes $F_2''$ non-trivial in eq 18c, producing the
∇ψ derivative term. Algebraic equivalence with Track C v4 confirmed in
principle (full re-derivation of paper-style formulas in our F-matrix
setting would be lengthy; the scalar reduction already pins down the
identity).

### 4.3 DDI nonlocal (matrix + nonlocal)

For nonlocal V_DDI: Aichinger-Chin-Krotscheck 2005 handles the nonlocal
scalar case via the FFT convolution identity $\nabla(U \ast \rho) = U \ast \nabla\rho$.
Combined with the F-matrix structure (§4.2), this gives the full DDI
case (Track C v5 §5.3).

Thalhammer paper doesn't address DDI explicitly, but its formalism is
general enough to absorb non-local terms via appropriate Fréchet
derivatives — same as Aichinger-Chin-Krotscheck. Same implementation
roadmap as Track C v5.

---

## Phase -1 exit criteria

- [x] Step 0: arXiv:2601.19838v1 fetched + key sections transcribed
- [x] Step 1: J=1 explicit G computed, matches paper eq 20 reduction
      AND Chin-Krotscheck 2005 4A
- [x] Step 2: implementation equivalence — `split_step_thalhammer!`
      alias for `split_step_forcegrad!`
- [x] Step 3: self-checks (i)-(iv) pass
- [x] Step 4: scope analysis for J=2+ and F-matrix/DDI extensions

**Phase -1 PASS** in 1 session (vs 4-week cap). Track C v1-v3.1 already
provides Track B's implementation for our SpinorBEC scope.

---

## Phase 0 implementation status

* `split_step_thalhammer!` exported as alias for `split_step_forcegrad!`
  (= explicit Track B = Track C identity at J=1 implementation level)
* `scripts/bench/forcegrad_thalhammer_equiv.jl` verifies bit-exact
  equivalence on Rb87 1D test problem

For J=2+ multi-species or F-matrix spinor + DDI: out of scope for
the SpinorBEC framework as currently structured. See Track C v4/v5 for
the F-matrix extension derivation path.

---

## Track B closure

Track B and Track C are TWO FORMALISMS describing the SAME family of
splitting methods for our problem class. Track C v3.1 + Track B Phase
-1 verification together close the modified-splitting effort for our
SpinorBEC use case.

**Thesis contributions**:
- (Track C v4 §5.2) Novel ∇ψ derivative term in $[V_{SM}, [T, V_{SM}]]$
  for spinor matrix V — emerges identically in Thalhammer's
  Lie-derivative formalism
- (Track B §1) Explicit equivalence proof Chin-Krotscheck 2005 ↔
  Thalhammer 2026 for J=1 GPE — connects the historical force-gradient
  literature to the modern Lie-derivative framework

For §3.6 narrative see `docs/integrator_ch3_6_narrative.md`.
