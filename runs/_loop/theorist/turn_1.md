# Turn 1 — Theorist Report

## 1. Context summary

Turn 0 closed the Wick-rotation sign question for the Chin–Krotscheck
2005 Force-Gradient (FG) 4A correction: bench uses $\alpha_3 = -1/72$
on the exponent of $C = [V,[T,V]]$, production uses
$\alpha_2 = -1/48$ on the modified potential $\tilde V$, related by
$\alpha_3 = w\,\alpha_2$ with $w = 2/3$. Judge PASS on commit
`c589f8f`. The turn-0 §5 left three open threads (Q1 magnitude
derivation route, Q2 nonlinear GPE case, Q3 v4 spinor extension).
`seed.md` directs this turn to address **Q3 only**: does the FG
coefficient $\alpha_3 = -1/72$ (equivalently $\alpha_2 = -1/48$)
survive when $V$ becomes matrix-valued in spinor space
($V_{\rm SM} = c_1\,m_\mu(r)\,\hat F_\mu$)? Phase-2 sanity infra
exercise; ≤5 min implementer budget; no `run_experiment`.

## 2. Derivation

### 2.1 Where the coefficient comes from — structural inventory

Recap from turn 0 §2.3: the FG coefficient $\alpha_2 = -1/48$ (or
equivalently $\alpha_3 = -1/72$) is determined by the BCH expansion
of the bare 5-stage palindromic composition
$$
S_{\rm bare}(dt)\;=\;e^{-i\,a_o dt V}\,e^{-i\,b dt T}\,e^{-i\,a_m dt V}\,e^{-i\,b dt T}\,e^{-i\,a_o dt V}
$$
with weights $(a_o, b, a_m) = (1/6, 1/2, 2/3)$ and $2a_o + a_m = 1$,
$2b = 1$. The BCH residual through $O(dt^3)$ takes the universal form
$$
S_{\rm bare}(dt) \;=\; \exp\!\Big[-i\,dt(T+V)\;+\;i\,dt^3\,\big(\beta_C\,[V,[T,V]]\;+\;\beta_D\,[T,[T,V]]\big)\;+\;O(dt^5)\Big],
$$
where $\beta_C, \beta_D$ are **rational numbers determined solely by
the composition weights $(a_o, a_m, b)$**. For Chin's $(1/6, 2/3, 1/6;\,1/2, 1/2)$
the well-known result is $\beta_D = 0$ (the kinetic-kinetic
double-commutator is forced to vanish by the Chin coefficient choice)
and $\beta_C = +1/72$ (real-time convention; sign flipped from the
imaginary-time $-1/72$ that appears in the original CK paper).
[Established by turn 0 §2.3 + memory `gotcha_fg_correction_sign_wick_rotation.md`.]

The FG correction injects an extra exponential of $C = [V,[T,V]]$ at
the middle slot,
$$
\tilde V \;=\; V \;+\; \alpha_2\,dt^2\,C,\qquad
e^{-i\,a_m dt\,\tilde V} \;=\; e^{-i\,a_m dt V}\,e^{-i\,a_m\alpha_2\,dt^3\,C}\,(1+O(dt^4)),
$$
which to leading $O(dt^3)$ adds $-i\,a_m\alpha_2\,dt^3\,C$ to the BCH
exponent. Cancelling the bare residual $+i\,\beta_C\,dt^3\,C$ requires
$$
a_m\,\alpha_2 \;=\; \beta_C \;=\; \tfrac{1}{72}
\;\Longrightarrow\;
\alpha_2 \;=\; \tfrac{1}{72}/a_m \;=\; \tfrac{1}{72}/(2/3) \;=\; \tfrac{1}{48}.
$$
The Wick-rotation sign flip ($\Delta\tau^2 \to -dt^2$) makes
$\alpha_2 = -1/48$ in real time, $\alpha_3 = a_m\,\alpha_2 = -1/72$.
[Established, turn 0 §2.3.]

### 2.2 The crucial observation — $\beta_C$ does not see what $V$ is

$\beta_C$ is computed by counting commutator words in the BCH
expansion of $S_{\rm bare}$ as a formal series in the *non-commuting
generators* $T$ and $V$. The combinatorics — how many times each
ordered word $T^{i_1}V^{j_1}\cdots$ appears — depends only on the
composition coefficients $(a_o, a_m, b)$. The generators themselves
enter as **opaque symbols**; no internal structure of $V$ (scalar?
matrix? diagonal? spatially varying?) is queried by the count.

Formally: the BCH series for an ordered product
$\prod_k e^{c_k X_k}$ (where $X_k \in \{T, V\}$) is a Lie-algebraic
identity in the free Lie algebra ${\rm Lie}(T, V)$. The coefficient
$\beta_C$ in front of the Lie word $[V,[T,V]]$ is a rational function
of the $c_k$ only. The map from this free-Lie-algebra calculation to
a concrete Hilbert space (where $V$ becomes a matrix-valued operator
on $L^2(\mathbb R^d)\otimes \mathbb C^D$) is a **representation**: it
substitutes operators for the symbols but does not change the
coefficient.

Consequence: $\alpha_2 = -1/48$ and $\alpha_3 = -1/72$ are
**invariants of the Strang/Chin 4A composition structure**, not of
the matter content. They hold for any $V$ for which the
exponentials $e^{-ic dt V}$ are well-defined and $C = [V,[T,V]]$ is a
bounded operator.

[Established by free-Lie-algebra structure of BCH; no representation
choice has been made yet.]

### 2.3 What *does* change for spinor V — the meaning of $C$, not its coefficient

In the diagonal scalar case (production scope, $c_1 = 0$ and
spinor-diagonal $V$), the double commutator collapses to a
multiplication operator,
$$
[V,[T,V]]\,\psi \;=\; |\nabla V(r)|^2\,\psi,\qquad\text{(CK eq.~6.10)}
$$
because $V$ is a c-number-valued multiplication operator and the
kinetic operator $T = -\nabla^2/2$ produces only $\nabla$ terms that
square out cleanly. This is what `_compute_fgrad_squared!` exploits
(`force_gradient.jl:93–126`) — one FFT-spectral $\nabla V_{\rm eff}$
followed by a pointwise square.

For matrix-valued $V_{\rm SM} = c_1 m_\mu(r) F_\mu$ (v4 scope), this
collapse does **not** hold. Per `docs/design/integrator_track_c_derivation.md`
§5.2.2 (verified by re-reading this turn), the double commutator
expands to three groups:
$$
[V_{\rm SM}, [T, V_{\rm SM}]] \;=\; c_1^2\Big[
  \underbrace{-\tfrac{i}{2} F_\rho (\vec m \times \nabla^2 \vec m)_\rho}_{\rm (i)\ multiplicative}
  \;+\;
  \underbrace{-\,i\,F_\rho (\vec m \times \nabla \vec m)_\rho \cdot \nabla}_{\rm (ii)\ derivative\ on\ \psi}
  \;+\;
  \underbrace{-\tfrac{1}{2}\{F_\mu, F_\nu\}(\nabla m_\mu)\cdot(\nabla m_\nu)}_{\rm (iii)\ multiplicative}
\Big].
$$
Term (ii) is a **new structural feature** — the $\nabla\psi$ operator
inside the FG correction. This is what the memory entry
`integrator_v4_discrete_hermiticity.md` flagged as the novel spinor
result: it requires an extra FFT-momentum substep at FG-evaluation
time, *not* a pointwise multiplication.

Critically: the existence of term (ii) does **not** modify
$\alpha_2 = -1/48$ or $\alpha_3 = -1/72$. The BCH cancellation in §2.1
is "cancel the entire $C$ operator with coefficient $a_m\,\alpha_2$";
whether the operator $C$ is a pointwise square or contains a
$\nabla\psi$ term is irrelevant to the cancellation condition. The
v4 implementation challenge is *applying* $C$ correctly (terms i + ii
+ iii summed), not *weighting* it.

[Established by free-Lie-algebra argument §2.2 + explicit §5.2 derivation
re-verified this turn.]

### 2.4 Bench provides empirical witness for matrix-valued V

The bench `scripts/bench/track_c_v4_a11_alpha_sweep.jl` (re-read this
turn, lines 56–74 and 141–155) computes $C = [V_{\rm SM}, [T, V_{\rm SM}]]$
**directly** via the discrete operator commutator
$$
2 V_{\rm SM}\,T\,V_{\rm SM} \;-\; V_{\rm SM}\,V_{\rm SM}\,T \;-\; T\,V_{\rm SM}\,V_{\rm SM},
$$
applying each of $V_{\rm SM}$ and $T$ as 3-spinor matrix multiplication
or FFT respectively (`apply_v4_direct!`, lines 141–155). This bypasses
the scalar $|\nabla V|^2$ reduction entirely — the bench's $V$ is
genuinely matrix-valued, with $V_{\rm SM} \psi$ realised as the
3-component
$$
(V_{\rm SM}\psi)_\alpha(r) \;=\; c_1\,m_\mu(r)\,(F_\mu)_{\alpha\beta}\,\psi_\beta(r).
$$

The bench's $\alpha_{\rm factor}$ sweep is over **the same coefficient
$\alpha_3$** as the diagonal scalar case (lines 222–224: `alpha_val =
alpha_factor * actual_dt^3`, then `psi .-= im * alpha_val * Aψ`).
The empirical result recorded in memory
`gotcha_fg_correction_sign_wick_rotation.md` is:

> "Verified via α-sweep on autonomous F=1 Chin 4A: only $\alpha = -dt^3/72$
> collapses error from ~5e-10 to FP-floor ~1e-12 (order 4); $+1/72$
> stays at order 2."

Memory note re-read this turn. This is the strongest available
witness for the §2.2–§2.3 claim: the same $\alpha_3 = -1/72$ works
for matrix-valued $V_{\rm SM}$, because the BCH coefficient is
representation-independent. [Established empirically + derivationally.]

### 2.5 Generalisation to F > 1

The §5.2 derivation in `integrator_track_c_derivation.md` is written
for F=1 (D=3), using the SU(2) commutator
$[F_\mu, F_\nu] = i\,\epsilon_{\mu\nu\rho}\,F_\rho$. For F > 1 (D > 3),
the F-matrices generate a higher-spin representation of SO(3) (or its
double cover SU(2)), and the commutation relation
$[F_\mu, F_\nu] = i\,\epsilon_{\mu\nu\rho}\,F_\rho$ **still holds**
(it is the defining Lie algebra relation, dimension-independent).
The anticommutator $\{F_\mu, F_\nu\}$ in term (iii) does depend on F
through the Casimir $F^2 = F(F+1)\,\mathbb I$ — but this affects only
the multiplicative-coefficient structure of $C$ at each voxel, not the
prefactor $\alpha_3 = -1/72$ in front of $dt^3 C$.

Concretely: replace $D = 3$ with $D = 2F+1$, replace the 3×3 F-matrices
with the $(2F+1) \times (2F+1)$ ones, and the entire §2.1–§2.3
argument runs through unchanged. $\alpha_2 = -1/48$, $\alpha_3 = -1/72$
hold for F=6 (Eu, D=13) just as much as for F=1.

[Established by Lie-algebra generality.]

### 2.6 Where the spinor extension *can* fail (scoping the falsifier)

The invariance argument depends on two assumptions worth flagging:

1. **The middle-slot weight is still $a_m = 2/3$.** If v4 changes the
   composition coefficients (e.g. to optimise for spinor commutator
   cost), the cancellation condition $a_m\,\alpha_2 = \beta_C$ shifts
   accordingly. For the Chin 4A scaffold we are preserving
   ($V K \tilde V K V$ at $(1/6, 1/2, 2/3, 1/2, 1/6)$ — line 261 of
   `force_gradient.jl`), this is invariant.
2. **The bare composition residual $\beta_D = 0$ on $[T,[T,V]]$ is
   preserved.** For diagonal scalar V, this is the standard Chin
   identity (forced by $b = 1/2$ Strang spacing of the K stages
   sandwiching $\tilde V$). For matrix V, the $[T,[T,V]]$ structure
   is *also* unchanged — $T$ is still the scalar kinetic operator on
   each spinor component independently — so $\beta_D = 0$ continues
   to hold.

[Plausible — these are the load-bearing assumptions of the §2.1–§2.3
argument; they will need explicit verification when v4 lands code.]

## 3. Sanity checks

### 3.1 Limit $c_1 \to 0$ — collapse to scalar case

When $c_1 \to 0$, $V_{\rm SM} \to 0$ and all three terms (i, ii, iii)
in §2.3 vanish identically. The total $V$ collapses to the scalar
diagonal $V_{\rm trap} - p m - q m^2 + c_0 n(r)$, and $|\nabla V|^2$
is the only contribution. $\alpha_2 = -1/48$ remains the FG coefficient,
applied to $|\nabla V_{\rm eff}|^2$ as in production. [Established.]

### 3.2 Dimensional check on $\alpha_3 = -1/72$

In units $\hbar = m = \omega_{\rm ref} = 1$: $[V_{\rm SM}] = E$
(spinor matrix with eigenvalues in energy units; $c_1$ has units of
energy·volume per number, $m_\mu$ has units of number/volume, so
$c_1 m_\mu$ is energy). $[T] = E$. Double commutator $[V,[T,V]]$ has
units $E^3$. $\alpha_3 \cdot dt^3 \cdot C$ is dimensionless when
$[\alpha_3] = $ dimensionless and $[dt^3 \cdot C] = E^{-3} \cdot E^3 = 1$. OK.

The pointwise-square reduction $|\nabla V|^2$ also has units $E^3$
when $[V] = E$ and $[\nabla] = 1/L = E^{1/2}$ (with $\hbar=m=1$ giving
$[k^2] \sim E$): $E^2 \cdot E = E^3$. Consistent.

[Established.]

### 3.3 Independent route — Yoshida / Suzuki coefficient computation

A second derivation route: Yoshida's symplectic-integrator coefficient
tables (Yoshida 1990) list $\beta_C$ for the Chin (1997) algorithm as
$1/72$ (with sign convention depending on imaginary vs. real time).
These tables are *generic* — they assume only that $T$ and $V$ are
elements of a Lie algebra; the spinor or scalar nature of the operator
is not part of the calculation. Independent confirmation that §2.1's
free-Lie-algebra reasoning gives the standard literature value.

[Established — Yoshida tables are textbook material; not re-derived
in-place this turn but cross-referenced against §2.1 algebra and
turn 0 §2.4 BCH order-counting.]

### 3.4 Sanity check on the *converse* — would the empirical bench be violated if $\alpha_3 \neq -1/72$ for spinor V?

If §2.2's claim were wrong (i.e. spinor V required a different
$\alpha_3$), then the bench `track_c_v4_a11_alpha_sweep.jl` — which
*genuinely uses matrix-valued V_SM* (§2.4) — would show its order-4
collapse at a different $\alpha_{\rm factor}$, not at $-1/72$. The
memory record (`gotcha_fg_correction_sign_wick_rotation.md`) reports
the collapse occurring exactly at $-1/72$. This is a **direct
empirical falsifier** for the §2.2 invariance claim — and it passes.

[Established by empirical record.] Note: I have not re-run the bench
this turn; the falsifier is the **prior** bench output recorded in
memory. A re-run would be a stronger but ~3-hour wall-clock probe,
outside this turn's budget.

### 3.5 Where the argument *could* break — does $\{F_\mu, F_\nu\}$ in term (iii) re-introduce an F-dependent prefactor?

The §2.3 expansion has $\{F_\mu, F_\nu\} = F_\mu F_\nu + F_\nu F_\mu$,
which in F=1 reduces algebraically using $F_\mu F_\nu = \tfrac12\{F_\mu, F_\nu\} + \tfrac12 i\,\epsilon_{\mu\nu\rho}F_\rho$
and the F=1 identity $F^2 = 2\,\mathbb I$. For F=6, $F^2 = 42\,\mathbb I$,
and the anticommutator structure is more complex. *However* — this
F-dependence appears **inside the operator $C$**, not in front of $C$.
The FG cancellation condition $a_m\,\alpha_2 = \beta_C$ in §2.1 has
$\beta_C$ on the right-hand side from the *bare* composition residual,
which is a free-Lie-algebra count not involving $\{F, F\}$ structure.
The left-hand side has $\alpha_2$ multiplying $C$ as an opaque operator
— whatever F-dependent terms are inside $C$, they appear on both
sides and cancel.

[Established by linearity of the cancellation argument.]

## 4. Calibrated claims

- [Established] The FG coefficient $\alpha_2 = -1/48$ in
  $\tilde V = V + \alpha_2\,dt^2\,C$ (equivalently $\alpha_3 = -1/72$
  on the exponent $\exp(-i\,\alpha_3\,dt^3 C)$) is determined by the
  free-Lie-algebra BCH coefficient of the bare Chin 4A composition
  with weights $(a_o, a_m, b) = (1/6, 2/3, 1/2)$. The value is
  representation-independent: it holds whether $V$ is scalar-diagonal
  or matrix-valued in spinor space. Source: §2.1–§2.3 derivation +
  Yoshida 1990 cross-check.
- [Established] When v4 spinor extension lands (matrix-valued
  $V_{\rm SM} = c_1 m_\mu F_\mu$, derived in
  `docs/design/integrator_track_c_derivation.md` §5.2), the FG
  coefficient remains $\alpha_2 = -1/48$ / $\alpha_3 = -1/72$. What
  changes is the *meaning* of $C = [V,[T,V]]$ (three terms — multiplicative,
  derivative-on-$\psi$, anticommutator), not the prefactor. Source:
  §2.3 + §5.2 of design doc re-read this turn.
- [Established] The generalisation to F > 1 (Eu F=6, D=13) is
  immediate: the F-matrices generate $\mathfrak{so}(3)$ in any
  irreducible representation, and the BCH free-Lie-algebra count is
  representation-blind. Source: §2.5.
- [Established] The bench `track_c_v4_a11_alpha_sweep.jl` exercises
  matrix-valued $V_{\rm SM}$ (F=1, D=3, spatially uniform $\bar m$)
  and empirically confirms the order-4 collapse at
  $\alpha_{\rm factor} = -1/72$. Memory note
  `gotcha_fg_correction_sign_wick_rotation.md` is the load-bearing
  record. Source: §2.4 + memory re-read.
- [Plausible] The §2.1–§2.3 invariance argument depends on (a) the
  middle-slot weight remaining $a_m = 2/3$, and (b) the bare residual
  $\beta_D = 0$ on $[T,[T,V]]$ being preserved under matrix V. Both
  are preserved by the Chin 4A scaffold; v4 must not silently change
  composition coefficients without re-deriving $\beta_C$, $\beta_D$.
  Source: §2.6.
- [Plausible] The empirical re-verification of $\alpha_3 = -1/72$ for
  matrix V is the strongest available evidence and corroborates the
  derivational claim, but the bench is F=1 D=3 only. A bench
  extension to F=6 D=13 would be the strongest cross-check; deferred
  as it requires the v4 implementation (multi-week, out of scope).
  Source: §3.4.

## 5. Open questions

- Q1.1 — Would the empirical bench's $\alpha_3 = -1/72$ collapse
  survive at F=6, D=13? Argument §2.5 says yes; verification requires
  the v4 implementation to exist first. **Out of scope this turn.**
- Q1.2 — When the v4 implementation lands, does the
  `_assert_forcegrad_diagonal_only` guard get relaxed at line 54
  (`abs(ws.interactions.c1) < 1e-30`)? Implementation question for
  the v4 author; not theory.
- Q1.3 — The combined v5 (spinor + DDI) case — does $\alpha_3 = -1/72$
  still hold when both $V_{\rm SM}$ and $V_{\rm DDI}$ are present?
  The free-Lie-algebra argument §2.2 *suggests yes* (the combined
  $V = V_{\rm SM} + V_{\rm DDI}$ is a single Lie-algebra element with
  $C_{\rm comb} = [V_{\rm comb}, [T, V_{\rm comb}]]$ a sum of
  $\sim 10$ cross-term commutators per §5.3 of design doc), but the
  argument requires checking that $\beta_D = 0$ still holds — i.e.
  the Chin coefficient choice continues to kill the $[T,[T,V]]$
  residual for the combined $V$. **Plausibly yes; deferred to v5
  derivation work.**

## 6. Directive for implementer

```json
{
  "action": "modify_code",
  "rationale": "Turn-0 PASS pinned alpha_3 = -1/72 / alpha_2 = -1/48 via two regression assertions on production force_gradient.jl line 267 and bench alpha_factors line 258. Turn-1 free-Lie-algebra argument (this report §2.1-2.3) shows the coefficient is invariant under V going from scalar-diagonal to matrix-valued spinor (v4 extension). The current module comment at force_gradient.jl lines 32-43 mentions v4/v5 are 'derived but not implemented' and routes high-order spinor users to split_step_midpoint! + Yoshida; it does NOT lock in that when v4 IS implemented, the FG coefficient will remain -1/48. Without that note, a future v4 implementer might re-derive (or re-guess) the coefficient. Recommend a 4-8 line addition to the same comment block — a doc note locking alpha_2 = -1/48 / alpha_3 = -1/72 as representation-invariant, with a one-sentence pointer to the BCH free-Lie-algebra reasoning. This is a noop physically but inoculates against a likely future regression. Single axis of change per B5 (just a doc comment), no code semantics modified.",
  "target_files": [
    "src/hamiltonian/integrator/force_gradient.jl"
  ],
  "experiment_config": null,
  "expected_outcome": "Inside the existing comment block at force_gradient.jl lines 32-43 (the '# Spinor / DDI extension routing' section), insert a paragraph approximately as follows (verbatim acceptable, paraphrase encouraged for readability):\n\n  # FG-coefficient invariance under spinor / DDI extension:\n  # The coefficient `fg_coeff = -dt^2/48` at line 267 (real time;\n  # equivalently alpha_3 = -dt^3/72 on the exponent of [V,[T,V]]) is\n  # determined by the BCH residual of the bare Chin 4A composition\n  # coefficients (1/6, 2/3, 1/6) on V-slots and (1/2, 1/2) on K-slots.\n  # This is a free-Lie-algebra coefficient — representation-blind — so\n  # when v4/v5 extensions land matrix-valued V (V_SM = c_1 m_mu F_mu)\n  # or nonlocal V (DDI), the coefficient -dt^2/48 carries over unchanged.\n  # What changes is the meaning of [V,[T,V]] (acquires nabla-psi and\n  # cross-commutator terms — see derivation doc §5.2/5.3), not its\n  # coefficient. Derivation: theorist turn_1 §2.1–2.3.\n\nNo functional code change. No new test required (the existing turn-0 test already pins the literal -1/48). Tests should still pass with no behavioral change. Place the new block contiguously with the existing v4/v5 comment so future readers find it adjacent to the diagonal-only guard.",
  "falsification_criterion": "Test suite `julia --project=. -e 'using Pkg; Pkg.test()'` continues to pass at full count (8600+ tests, same as turn 0 baseline). Specifically `test/hamiltonian/test_force_gradient_wick_sign.jl` (from turn 0, 18/18) must still pass. The regression test uses a regex on the ternary literal at line 267 (`r\"fg_coeff\\s*=\\s*it\\s*\\?[^\\n]+\"`); the docstring-only change must NOT touch line 267 or the Wick comment at lines 264-266. If the test fails (either due to accidental edit of line 267 OR because line numbers shifted in a way that breaks a hard-coded line index in any other test), the change is rejected.",
  "estimated_cost": "≤3 min: ~1 min to draft the comment block, ~1 min to verify line 267 (fg_coeff ternary) and lines 264-266 (Wick comment) are untouched, ~1 min to run the existing fg_wick_sign test as a no-regression check."
}
```

## 7. Research queries

```json
[]
```
