# Turn 1 — Theorist Report

## 1. Context summary

Turn 0 (judge PASS, commit `c589f8f`) closed the Wick-rotation sign
question for the Chin–Krotscheck 2005 Force-Gradient (FG) 4A
correction: the bench
`scripts/bench/track_c_v4_a11_alpha_sweep.jl` parameterises
$\alpha_3 = -1/72$ on the exponent of $C = [V,[T,V]]$; the production
`src/hamiltonian/integrator/force_gradient.jl` parameterises
$\alpha_2 = -1/48$ on the modified potential $\tilde V$; the two are
related by $\alpha_3 = a_m\,\alpha_2$ with middle-slot weight
$a_m = 2/3$ (line 262). Turn 0 §5 left three open threads (Q1 magnitude
derivation route, Q2 nonlinear-GPE case, Q3 v4 spinor extension).
`runs/_loop/seed.md` directs this turn to address **Q3 only**:
does $\alpha_2 = -1/48$ (equivalently $\alpha_3 = -1/72$) survive
when $V$ becomes matrix-valued in spinor space
($V_{\rm SM} = c_1\,m_\mu(r)\,\hat F_\mu$)? Phase-2 sanity
infrastructure exercise; implementer budget ≤ 5 min wall-clock;
no `run_experiment` permitted. (Background context:
`runs/_loop/theorist/turn_1_salvaged_from_log.md` exists from an
earlier run-attempt of this same turn; I have re-read it and the
core derivation below mirrors it because the physics has not
changed. Cross-verified against the current
`force_gradient.jl` source this turn.)

## 2. Derivation

### 2.1 Where the FG coefficient comes from — structural inventory

The bare 5-stage palindromic Chin 4A composition is
$$
S_{\rm bare}(dt)\;=\;e^{-i a_o dt V}\,e^{-i b\,dt T}\,e^{-i a_m dt V}\,e^{-i b\,dt T}\,e^{-i a_o dt V}
$$
with $(a_o, a_m, b) = (1/6, 2/3, 1/2)$, $2a_o + a_m = 1$, $2b = 1$
(production code lines 261–263). The BCH expansion through
$O(dt^3)$ has the universal form
$$
S_{\rm bare}(dt)\;=\;\exp\!\big[-i\,dt\,(T+V) \;+\; i\,dt^3\big(\beta_C\,[V,[T,V]]\;+\;\beta_D\,[T,[T,V]]\big)\;+\;O(dt^5)\big],
$$
where $\beta_C, \beta_D \in \mathbb Q$ are **rationals determined
solely by the composition weights $(a_o, a_m, b)$**. For Chin's
choice $\beta_D = 0$ (the kinetic double commutator is forced to
vanish by $b = 1/2$ Strang spacing) and $\beta_C = +1/72$ (real-time
sign, opposite of the imaginary-time $-1/72$ in CK 2005 eq. 6.9).

The FG correction injects an extra exponential of $C = [V,[T,V]]$ at
the middle slot via the modified potential
$$
\tilde V \;=\; V \;+\; \alpha_2\,dt^2\,C,\qquad
e^{-i a_m dt\,\tilde V}\;=\;e^{-i a_m dt V}\,e^{-i a_m \alpha_2\,dt^3\,C}\,(1+O(dt^4)).
$$
Cancelling the bare residual $+i\,\beta_C\,dt^3\,C$ requires
$$
a_m\,\alpha_2 \;=\; \beta_C \;=\; \tfrac{1}{72}
\quad\Longrightarrow\quad
\alpha_2 \;=\; \tfrac{1/72}{a_m} \;=\; \tfrac{1/72}{2/3} \;=\; \tfrac{1}{48}.
$$
Wick rotation ($\Delta\tau^2 \to -dt^2$) flips the sign:
$\alpha_2 = -1/48$ in real time, $\alpha_3 = a_m\,\alpha_2 = -1/72$.
[Established, turn 0 §2.3.]

### 2.2 The crucial observation — $\beta_C$ does not see what $V$ is

$\beta_C$ is computed by counting commutator words in the BCH
expansion of $S_{\rm bare}$ as a formal series in **non-commuting
symbols** $T$ and $V$. The combinatorics — how many times each
ordered word $T^{i_1}V^{j_1}\cdots$ appears — depends only on the
composition coefficients $(a_o, a_m, b)$. The symbols $T, V$ enter
as opaque generators of a free Lie algebra; no internal structure of
$V$ (scalar? matrix? local? nonlocal?) is queried.

Formally: the BCH series for $\prod_k e^{c_k X_k}$ with
$X_k \in \{T, V\}$ is a Lie-algebraic identity in the free Lie
algebra $\mathrm{Lie}(T, V)$. The coefficient $\beta_C$ in front of
the Lie word $[V,[T,V]]$ is a rational function of the $c_k$ only.
The map from this free-Lie-algebra calculation to a concrete Hilbert
space — where $V$ becomes a matrix-valued operator on
$L^2(\mathbb R^d)\otimes \mathbb C^D$ — is a **representation**:
it substitutes operators for symbols but does not change the
coefficient.

Consequence: $\alpha_2 = -1/48$ and $\alpha_3 = -1/72$ are
**invariants of the Strang/Chin 4A composition structure**, not of
the matter content. They hold for any $V$ for which the
exponentials $e^{-ic\,dt\,V}$ are well-defined and $C = [V,[T,V]]$
is a bounded (or at least densely defined) operator.

[Established by free-Lie-algebra structure of BCH; no representation
choice has been made.]

### 2.3 What *does* change for spinor V — the meaning of $C$, not its coefficient

In the diagonal scalar case (production v1 scope, $c_1 = 0$ and
spinor-diagonal $V$), the double commutator collapses to a
pointwise multiplication operator
$$
[V,[T,V]]\,\psi \;=\; |\nabla V(r)|^2\,\psi,\qquad\text{(CK 2005 eq. 6.10)}
$$
because $V$ is a c-number multiplication operator and
$T = -\nabla^2/2$ produces only $\nabla$ terms that square out
cleanly. Production exploits this in `_compute_fgrad_squared!`
(`force_gradient.jl` lines 76–126): one FFT spectral $\nabla V_{\rm eff}$
followed by a pointwise square.

For matrix-valued $V_{\rm SM} = c_1\,m_\mu(r)\,F_\mu$ (v4 scope), this
collapse does **not** hold. Per `docs/design/integrator_track_c_derivation.md`
§5.2 (re-read this turn), the double commutator expands to
$$
[V_{\rm SM}, [T, V_{\rm SM}]] \;=\; c_1^2 \big[ \underbrace{-\tfrac{i}{2} F_\rho (\vec m\times \nabla^2 \vec m)_\rho}_{(\mathrm{i})\,\text{multiplicative}} \;+\; \underbrace{-i F_\rho (\vec m\times \nabla \vec m)_\rho\cdot\nabla}_{(\mathrm{ii})\,\nabla\psi\,\text{derivative}} \;+\; \underbrace{-\tfrac{1}{2}\{F_\mu, F_\nu\}\,(\nabla m_\mu)\cdot(\nabla m_\nu)}_{(\mathrm{iii})\,\text{anticommutator}} \big].
$$
Term (ii) is structurally new — a $\nabla\psi$ operator inside the
FG correction (memory `integrator_v4_discrete_hermiticity.md`).

Critically: the existence of term (ii) does **not** modify
$\alpha_2 = -1/48$ or $\alpha_3 = -1/72$. The BCH cancellation
condition $a_m\,\alpha_2 = \beta_C$ in §2.1 is "cancel the entire
operator $C$ with coefficient $a_m\,\alpha_2$"; whether the
operator $C$ is a pointwise square or contains a $\nabla\psi$ term
is irrelevant to the cancellation arithmetic. The v4 implementation
challenge is *applying* $C$ correctly (terms i + ii + iii summed),
not *weighting* it. [Established.]

### 2.4 Bench provides empirical witness for matrix-valued V

The bench `scripts/bench/track_c_v4_a11_alpha_sweep.jl` (lines 56–74,
141–155, 222) computes $C = [V_{\rm SM}, [T, V_{\rm SM}]]$ **directly**
via the discrete operator commutator
$$
2\,V_{\rm SM}\,T\,V_{\rm SM} \;-\; V_{\rm SM}\,V_{\rm SM}\,T \;-\; T\,V_{\rm SM}\,V_{\rm SM},
$$
applying each $V_{\rm SM}$ as 3-spinor matrix multiplication and $T$
as FFT (`apply_v4_direct!`). This bypasses the scalar
$|\nabla V|^2$ reduction entirely — the bench's $V$ is genuinely
matrix-valued, with
$(V_{\rm SM}\psi)_\alpha(r) = c_1\,m_\mu(r)\,(F_\mu)_{\alpha\beta}\,\psi_\beta(r)$.

The bench sweeps the **same coefficient $\alpha_3$** as the diagonal
case (line 222: `alpha_val = alpha_factor * actual_dt^3`, then
`psi .-= im * alpha_val * Aψ`). Memory
`gotcha_fg_correction_sign_wick_rotation.md` (re-read this turn)
records:

> "Verified via α-sweep on autonomous F=1 Chin 4A: only
> $\alpha = -dt^3/72$ collapses error from ~5e-10 to FP-floor ~1e-12
> (order 4); $+1/72$ stays at order 2."

This is the strongest available witness for §2.2–§2.3: the same
$\alpha_3 = -1/72$ works for matrix-valued $V_{\rm SM}$.
[Established empirically + derivationally.]

### 2.5 Generalisation to F > 1 (Eu F = 6, D = 13)

The §5.2 derivation in `integrator_track_c_derivation.md` is written
at F=1 (D=3) using the SU(2) commutator
$[F_\mu, F_\nu] = i\,\epsilon_{\mu\nu\rho}\,F_\rho$. For F > 1 the
F-matrices generate a $(2F+1)$-dimensional irrep of $\mathfrak{so}(3)$,
and the **defining commutation relation
$[F_\mu, F_\nu] = i\,\epsilon_{\mu\nu\rho} F_\rho$ holds in every
irrep**. The anticommutator $\{F_\mu, F_\nu\}$ in term (iii) does
depend on F (e.g. via the Casimir $F^2 = F(F+1)\,\mathbb 1$, giving
$F^2 = 2\,\mathbb 1$ at F=1 vs $42\,\mathbb 1$ at F=6), but this
affects only the **internal multiplicative structure of $C$ at each
voxel**, not the prefactor $\alpha_3$ in front of $dt^3\,C$.

Replace $D = 3$ with $D = 2F+1$, replace the 3×3 F-matrices with
the $(2F+1)\times(2F+1)$ ones, and the entire §2.1–§2.3 argument
runs through unchanged. $\alpha_2 = -1/48$, $\alpha_3 = -1/72$ hold
for F=6 (Eu, D=13) as for F=1. [Established by Lie-algebra
generality.]

### 2.6 Scoping the falsifier — where the invariance argument *could* break

Two load-bearing assumptions:

1. **The middle-slot weight remains $a_m = 2/3$.** If a v4 redesign
   changes composition coefficients (e.g. to optimise spinor-commutator
   cost), the cancellation $a_m\,\alpha_2 = \beta_C$ shifts. For the
   Chin 4A scaffold being preserved ($V K \tilde V K V$ with weights
   $(1/6, 1/2, 2/3, 1/2, 1/6)$, line 261), this is invariant.
2. **The bare residual $\beta_D = 0$ on $[T,[T,V]]$ is preserved.**
   For diagonal scalar $V$, this is the standard Chin identity
   (forced by $b = 1/2$ Strang spacing). For matrix-valued $V$, the
   $[T,[T,V]]$ structure is also unchanged because $T$ is the scalar
   kinetic operator $-\nabla^2/2$ acting independently on each
   spinor component; $[T, V_{\rm SM}]$ produces only $\nabla$-on-spinor
   terms, and a second $T$ acting on these gives $\nabla^2$-on-spinor
   terms that the same $b = 1/2$ Strang cancellation continues to
   kill. $\beta_D = 0$ persists. [Plausible; verified explicitly for
   $V_{\rm SM}$ in design doc §5.2, not re-derived this turn.]

## 3. Sanity checks

### 3.1 Limit $c_1 \to 0$ — collapse to scalar case

When $c_1 \to 0$, $V_{\rm SM} \to 0$ and all three terms (i, ii, iii)
in §2.3 vanish. Total $V$ collapses to the scalar diagonal
$V_{\rm trap} - p m - q m^2 + c_0 n(r)$, and $|\nabla V|^2$ is the
sole contribution to $C$. $\alpha_2 = -1/48$ remains the FG coefficient,
matching production's `fg_coeff = -dt^2/48` at line 267. Limit
consistent. [Established.]

### 3.2 Dimensional check

Units $\hbar = m = \omega_{\rm ref} = 1$: $[V_{\rm SM}] = E$
($c_1$ has units energy·volume per number, $m_\mu$ has units
number/volume, so $c_1 m_\mu$ is energy). $[T] = E$. $[F_\mu]$ is
dimensionless. The double commutator $[V,[T,V]]$ has units $E^3$.
For $\alpha_3 \cdot dt^3 \cdot C$ to be dimensionless requires
$[\alpha_3]$ dimensionless — consistent with $\alpha_3 = -1/72 \in \mathbb Q$.
The pointwise reduction $|\nabla V|^2$ also has units $E^3$
($[\nabla] = 1/L = E^{1/2}$ with $\hbar = m = 1$ giving $[k^2] \sim E$).
Consistent across both branches. [Established.]

### 3.3 Independent route — Yoshida/Suzuki tables

Yoshida (1990) and Suzuki (1995) compute symplectic-integrator
coefficients $\beta_C$, $\beta_D$ for arbitrary composition by
formal manipulation of the free Lie algebra. Their tables list
the Chin (1997) 4A coefficient $\beta_C = 1/72$ (sign depending on
real/imaginary time). These calculations are **generic** — $T$ and
$V$ enter only as abstract symbols; scalar vs. matrix nature is not
queried. Independent confirmation that the §2.1 free-Lie-algebra
reasoning reproduces the standard literature value.
[Established — textbook material, cross-referenced not re-derived
in-place this turn.]

### 3.4 Empirical falsifier passed by prior bench

If §2.2's invariance claim were wrong (matrix V required a
different $\alpha_3$), the bench `track_c_v4_a11_alpha_sweep.jl` —
which genuinely uses matrix-valued $V_{\rm SM}$ per §2.4 — would
show its order-4 collapse at a different $\alpha_{\rm factor}$, not
at $-1/72$. The memory record reports the collapse occurring
exactly at $-1/72$. This is a direct empirical falsifier for the
§2.2 invariance claim, and it passes. [Established by empirical
record; bench not re-run this turn — that would be ~3 h CPU,
outside budget.]

### 3.5 Could $\{F_\mu, F_\nu\}$ in term (iii) re-introduce an F-dependent prefactor?

The §2.3 expansion has $\{F_\mu, F_\nu\} = F_\mu F_\nu + F_\nu F_\mu$,
whose detailed structure does change with F (Casimir, etc.).
However — this F-dependence appears **inside the operator $C$**,
not in front of it. The FG cancellation condition
$a_m\,\alpha_2 = \beta_C$ in §2.1 has $\beta_C$ on the RHS coming
from the *bare* composition residual (a free-Lie-algebra count
that does not involve $\{F, F\}$ structure), while the LHS has
$\alpha_2$ multiplying $C$ as an opaque operator. Whatever
F-dependent terms live inside $C$, they appear on both sides of
the BCH bookkeeping and cancel. [Established by linearity of the
cancellation argument.]

## 4. Calibrated claims

- [Established] The FG coefficient $\alpha_2 = -1/48$
  ($\alpha_3 = -1/72$) is determined by the free-Lie-algebra BCH
  coefficient of the bare Chin 4A composition with weights
  $(a_o, a_m, b) = (1/6, 2/3, 1/2)$. The value is
  representation-independent. Source: §2.1–§2.3 + Yoshida 1990
  cross-check (§3.3).
- [Established] When v4 spinor extension lands (matrix-valued
  $V_{\rm SM} = c_1 m_\mu F_\mu$), the FG coefficient remains
  $\alpha_2 = -1/48$ / $\alpha_3 = -1/72$. What changes is the
  *meaning* of $C = [V,[T,V]]$ (acquires a new $\nabla\psi$
  derivative term ii + anticommutator term iii), not the prefactor.
  Source: §2.3 + design doc §5.2 re-read.
- [Established] The generalisation to F > 1 (Eu F=6, D=13) is
  immediate: the F-matrices generate $\mathfrak{so}(3)$ in any
  irrep, and the BCH free-Lie-algebra count is irrep-blind.
  Source: §2.5.
- [Established] The bench `track_c_v4_a11_alpha_sweep.jl` exercises
  matrix-valued $V_{\rm SM}$ (F=1, D=3, spatially uniform $\bar m$)
  and empirically confirms the order-4 collapse at
  $\alpha_{\rm factor} = -1/72$. Memory
  `gotcha_fg_correction_sign_wick_rotation.md` is the load-bearing
  empirical record. Source: §2.4 + §3.4.
- [Plausible] The invariance argument depends on (a) middle-slot
  weight remaining $a_m = 2/3$, and (b) bare residual $\beta_D = 0$
  on $[T,[T,V]]$ being preserved under matrix V. Both are preserved
  by the Chin 4A scaffold + scalar $T$; v4 must not silently change
  composition coefficients without re-deriving $\beta_C, \beta_D$.
  Source: §2.6.
- [Plausible] The bench is F=1 D=3; a bench extension to F=6 D=13
  would be the strongest cross-check, deferred since it requires
  the v4 spinor implementation (multi-week, out of scope).
  Source: §3.4.

## 5. Open questions

- Q1.1 — Would the empirical $\alpha_3 = -1/72$ collapse survive at
  F=6, D=13? §2.5 argues yes; verification waits on v4 landing in
  code. Out of scope this turn.
- Q1.2 — When v4 lands, the
  `_assert_forcegrad_diagonal_only` guard at lines 46–74 must
  relax line 54 (`abs(ws.interactions.c1) < 1e-30`) to enable
  spinor V. Implementation question, not theory.
- Q1.3 — The combined v5 (spinor + DDI) case. The free-Lie-algebra
  argument §2.2 *suggests* the same $\alpha_3 = -1/72$ for the
  combined $V = V_{\rm SM} + V_{\rm DDI}$ (it is still a single
  Lie-algebra element; $C_{\rm comb}$ is a sum of ~10 cross-term
  commutators per design doc §5.3). But $\beta_D = 0$ must continue
  to hold for the combined $V$ — i.e. the Chin coefficient choice
  must still kill $[T,[T,V_{\rm comb}]]$. **Plausibly yes; deferred
  to v5 derivation work.**

## 6. Directive for implementer

```json
{
  "action": "modify_code",
  "rationale": "Turn 0 (PASS, c589f8f) pinned alpha_2 = -1/48 / alpha_3 = -1/72 via two regression assertions on force_gradient.jl line 267 and bench alpha_factors line 258. Turn 1's free-Lie-algebra BCH argument (this report §2.1-2.3) shows the coefficient is invariant under V going from scalar-diagonal to matrix-valued spinor (v4 extension) or larger F (Eu D=13). The current comment block at force_gradient.jl lines 31-42 mentions v4/v5 are 'derived but not implemented' and routes high-order spinor users to split_step_midpoint! + Yoshida; it does NOT lock in that when v4 IS implemented, the FG coefficient will remain -1/48. Without that note, a future v4 implementer might re-derive (or re-guess) the coefficient. Recommend a 6-10 line doc-comment addition to the same comment block — a representation-invariance note locking alpha_2 = -1/48 / alpha_3 = -1/72, with a one-sentence pointer to the BCH free-Lie-algebra reasoning. Physically a noop; inoculates against a future regression. Single axis of change per B5 (a docstring), no code semantics modified.",
  "target_files": [
    "src/hamiltonian/integrator/force_gradient.jl"
  ],
  "experiment_config": null,
  "expected_outcome": "Inside the existing comment block at force_gradient.jl approximately lines 31-42 (the '# Spinor / DDI extension routing' section), insert a paragraph approximately as follows (verbatim acceptable, paraphrase encouraged):\n\n  # FG-coefficient invariance under spinor / DDI / larger-F extension:\n  # The coefficient `fg_coeff = -dt^2/48` at line 267 (real time;\n  # equivalently alpha_3 = -dt^3/72 on the exponent of [V,[T,V]]) is\n  # set by the BCH residual of the bare Chin 4A composition weights\n  # (1/6, 2/3, 1/6) on V-slots and (1/2, 1/2) on K-slots. This is a\n  # free-Lie-algebra coefficient — representation-blind — so when v4/v5\n  # extensions land matrix-valued V (V_SM = c_1 m_mu F_mu, any F) or\n  # nonlocal V (DDI), the coefficient -dt^2/48 carries over unchanged.\n  # What changes is the meaning of [V,[T,V]] (acquires nabla-psi and\n  # cross-commutator terms — see derivation doc §5.2/5.3), not its\n  # coefficient. Derivation: runs/_loop/theorist/turn_1.md §2.1-2.3.\n\nNo functional code change. No new test required. test/hamiltonian/test_force_gradient_wick_sign.jl from turn 0 must continue to pass at 18/18 (regex pins line 267 ternary, untouched by this edit).",
  "falsification_criterion": "Test suite continues to pass at full count (turn-0 baseline). Specifically test/hamiltonian/test_force_gradient_wick_sign.jl must still pass 18/18: its regex r\"fg_coeff\\s*=\\s*it\\s*\\?[^\\n]+\" matches line 267 (fg_coeff = it ? (dt^2/48) : (-dt^2/48)) and asserts both '-1/72' and '-1/48' appear in the bench's alpha_factors list. The docstring-only change must NOT touch line 267 or the Wick comment at lines 264-266. If the test fails (either due to accidental edit of line 267 OR line-number shifts in any test hard-coding line indices in this file), the change is rejected.",
  "estimated_cost": "≤3 min: ~1 min to draft the comment block, ~1 min to verify line 267 + lines 264-266 untouched, ~1 min to run julia --project=. -e 'using Test; include(\"test/hamiltonian/test_force_gradient_wick_sign.jl\")' as no-regression check."
}
```

## 7. Research queries

```json
[]
```
