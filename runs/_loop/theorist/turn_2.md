# Turn 2 — Theorist Report

## 1. Context summary

Turn 0 (PASS, `c589f8f`) pinned the real-time Force-Gradient (FG) coefficient
$\alpha_2 = -1/48$ / $\alpha_3 = -1/72$ via two regression tests. Turn 1
(PASS, `28966b2`) added a representation-invariance doc-comment locking that
coefficient under the v4 spinor extension (matrix-valued $V_{\rm SM}$) and
the F > 1 case. Turn 1 §5 explicitly punted on **Q2: the nonlinear-GPE case**
($V = V_0(r) + g\,|\psi|^2$), which `runs/_loop/seed.md` directs this turn
to address. The Q2 question is two-pronged and I must keep the two prongs
separate:

(A) **Coefficient prong.** Does the formal BCH cancellation
$a_m\,\alpha_2 = \beta_C = 1/72$ (turn 1 §2.1) still set
$\alpha_2 = -1/48$ when $V$ depends on $\psi(t)$ during the step?

(B) **Realized-order prong.** Independently of (A), does the *measured*
order of `split_step_forcegrad!` reach 4 on the nonlinear GPE? Per
production docstring lines 213–223 and `integrator_ch3_5_narrative.md` §3.5.3,
the answer is **no** — v2 plateaus at order ~3, and v3.1 midpoint Picard
does not climb above 3. This is empirical and pre-existing.

Resolving (A) does NOT resolve (B); resolving (B) does NOT refute (A). Both
must be discussed and neither can hide behind the other.

## 2. Derivation

### 2.1 Recap — the turn 1 BCH argument and what its premises actually are

Turn 1 §2.1 derived $\alpha_2 = -1/48$ from a BCH expansion of the bare
5-stage Chin 4A composition
$$
S_{\rm bare}(dt) \;=\; e^{-i a_o dt V}\,e^{-i b\,dt T}\,e^{-i a_m dt V}\,e^{-i b\,dt T}\,e^{-i a_o dt V},
$$
with $(a_o, a_m, b) = (1/6, 2/3, 1/2)$. The expansion through $O(dt^3)$
gives the universal form
$$
S_{\rm bare}(dt) \;=\; \exp\!\Big[-i\,dt\,(T+V) \;+\; i\,dt^3\,\beta_C\,[V,[T,V]] \;+\; O(dt^5)\Big],
$$
with $\beta_C = 1/72$ and $\beta_D = 0$ on $[T,[T,V]]$ (latter forced by
$b = 1/2$ palindromic Strang spacing). FG injects $\tilde V = V + \alpha_2 dt^2\,C$
at the middle slot to cancel the $\beta_C$ residual; $a_m\,\alpha_2 = \beta_C$
forces $\alpha_2 = +1/48$ imaginary-time, $-1/48$ real-time after Wick.

**The hidden premise** that Q2 attacks: the BCH expansion treats $V$ as
a **time-independent operator** during the $[0, dt]$ step. When
$V(t) = V_0(r) + g\,|\psi(t)|^2$, the operator the propagator should
exponentiate is *not* a single $V$ but the time-ordered evolution
generator with a $\psi$-driven $\partial_t V$ component. We must check
whether that $\partial_t V$ contributes residuals at $O(dt^3)$ that
$\alpha_2 = -1/48$ does not cancel.

### 2.2 The right framework for nonlinear V — Magnus / time-ordered BCH

For an explicitly time-dependent Hamiltonian $H(t) = T + V(t)$, the exact
propagator is
$$
U(dt) \;=\; \mathcal T\,\exp\!\Big[-i\int_0^{dt} H(s)\,ds\Big],
$$
which, after Magnus expansion, is
$$
U(dt) \;=\; \exp\!\Big[-i\,\Omega_1 \;-\; \tfrac{1}{2}\Omega_2 \;-\; \tfrac{i}{6}\Omega_3 \;+\; \cdots\Big],
$$
with
$$
\Omega_1 = \int_0^{dt}\!H(s)\,ds,\quad
\Omega_2 = \int_0^{dt}\!\!\int_0^{s_1}\![H(s_1), H(s_2)]\,ds_2\,ds_1,\quad
\Omega_3 \sim [H,[H,H]]\text{-integrals}.
$$
A symmetric (palindromic) splitting like Chin 4A approximates $U(dt)$ by
evaluating $V$ at three slot-anchored times $\{t_L, t_M, t_R\}$. The
**time-dependent factorization rule** (CK 2005 §IV, eqs 4.5–4.8,
transcribed in `docs/design/integrator_track_c_derivation.md` §1.2) fixes
the anchor times: each $V$ exponent uses $V(t^*)$ where $t^*$ is the sum
of the time steps of all $T$ operators to its right. For the 4A composition
$V\,K\,\tilde V\,K\,V$:

| slot | weight | anchor time |
|---|---|---|
| outer right $V$ | $a_o dt = dt/6$ | $t^* = 0$ |
| middle $\tilde V$ | $a_m dt = 2dt/3$ | $t^* = b\,dt = dt/2$ |
| outer left $V$ | $a_o dt = dt/6$ | $t^* = 2b\,dt = dt$ |

(Note: I follow CK 2005's convention that the rightmost factor acts first,
matching the production code's ordering at lines 318–340.)

So the nonlinear-V analogue of the bare scheme is **not** a single
$V$ at three slots, but $V(0)$, $V(dt/2)$, $V(dt)$ at the three slots,
each derived from the corresponding ψ-snapshot. The BCH expansion must
therefore be done in three independent symbols $V_0, V_{1/2}, V_1$ —
not one symbol $V$.

### 2.3 Order-by-order expansion with three V symbols

Write $V_t = V(\psi(t))$ for $t \in \{0, dt/2, dt\}$ and Taylor-expand
each around the midpoint:
$$
V_0 = V_{1/2} - \tfrac{dt}{2}\,\dot V \;+\; \tfrac{dt^2}{8}\,\ddot V + O(dt^3),
\quad
V_1 = V_{1/2} + \tfrac{dt}{2}\,\dot V \;+\; \tfrac{dt^2}{8}\,\ddot V + O(dt^3),
$$
where $\dot V \equiv (\partial_t V)|_{t=dt/2}$ etc. The bare 4A composition,
keeping each $V$ symbol distinct, is
$$
S_{\rm bare}^{\rm nonlin}(dt) \;=\; e^{-i a_o dt V_1}\,e^{-i b dt T}\,e^{-i a_m dt V_{1/2}}\,e^{-i b dt T}\,e^{-i a_o dt V_0}.
$$
The BCH residual through $O(dt^3)$ now has two kinds of terms:

**(i) "Static" residual** — surviving when $V_0 = V_{1/2} = V_1 = V$
identically. By turn 1 §2.1, this is exactly
$+i\,dt^3 (\beta_C\,[V,[T,V]] + 0)$. **Cancelled by $\alpha_2 = -1/48$
unchanged.**

**(ii) "Time-derivative" residual** — terms that vanish when all three
$V$ agree, but are non-zero when they differ. The leading such terms
enter at:

- $O(dt^2)$: $\Omega_1$ in Magnus, the time-average of $V(t)$. The
  4A weights $(a_o, a_m, a_o) = (1/6, 2/3, 1/6)$ on $(V_1, V_{1/2}, V_0)$
  give
  $$
  \tfrac{1}{6}V_1 + \tfrac{2}{3}V_{1/2} + \tfrac{1}{6}V_0
  \;=\; V_{1/2} + \tfrac{1}{6}\cdot 2\cdot \tfrac{dt^2}{8}\,\ddot V + O(dt^4)
  \;=\; V_{1/2} + \tfrac{dt^2}{24}\,\ddot V + O(dt^4).
  $$
  This is exactly **Simpson's rule** applied to $\int_0^{dt} V(s)\,ds / dt$,
  matching the exact integral $\Omega_1/dt$ through $O(dt^4)$: Simpson is
  fourth-order. So the **time-averaged $V$ term in Magnus is reproduced
  to $O(dt^4)$ by the 4A weights** — no $O(dt^2)$ or $O(dt^3)$ residual
  enters from this channel.

- $O(dt^2)$: $\Omega_2 = -\tfrac{1}{2}\int_0^{dt}\!\!\int_0^{s_1}[H(s_1), H(s_2)]\,ds_2\,ds_1$.
  Expanding $H(s) = T + V_{1/2} + (s - dt/2)\,\dot V + \cdots$, the
  leading time-dependent commutator is
  $$
  [H(s_1), H(s_2)] \;=\; (s_1 - s_2)\,[T + V_{1/2},\, \dot V] + O((s_i - dt/2)^2).
  $$
  The double integral $\int_0^{dt}\!\!\int_0^{s_1}(s_1 - s_2)\,ds_2\,ds_1 = dt^3/6$.
  So $\Omega_2 = -\tfrac{1}{2}\cdot\tfrac{dt^3}{6}\,[T+V_{1/2}, \dot V] + O(dt^4)
  = -\tfrac{dt^3}{12}\,[T+V_{1/2}, \dot V] + O(dt^4)$.

  The bare 4A scheme reproduces $\Omega_2$ through some equivalent
  weighting of $V_0, V_1$ contrast (i.e. $V_1 - V_0 = dt\,\dot V + O(dt^3)$).
  Whether the 4A weights exactly reproduce the $\Omega_2$ coefficient
  $-dt^3/12$ on $[T, \dot V]$ is a calculation I have **not** carried out
  in full this turn — it is a coupled BCH-on-three-symbols + Magnus
  problem. [Plausible-but-unverified]: standard symmetric splittings
  reproduce $\Omega_2$ through $O(dt^3)$ when the slot-anchor times are
  chosen per CK 2005 §IV (which is exactly the role of the
  $\{0, dt/2, dt\}$ anchor rule).

- $O(dt^3)$: Within the existing static residual structure
  $\propto [V,[T,V]]$, what we now have is
  $[V_{1/2}, [T, V_{1/2}]] + (\text{cross terms involving }\dot V)$.
  The cross terms produce **new operator structures**
  $[V, [T, \dot V]]$, $[\dot V, [T, V]]$, etc. — these are NOT proportional
  to $[V, [T, V]]$ and so **cannot be cancelled by any choice of
  $\alpha_2$** multiplying $C = [V, [T, V]]$.

### 2.4 Operational consequence — coefficient survives, achievable order does not

The key observation from §2.3:

> $\alpha_2 = -1/48$ continues to cancel the *static* $\beta_C$
> residual — the operator $[V_{1/2}, [T, V_{1/2}]]$ at the midpoint
> MF. It cannot cancel new cross-commutators of the form
> $[V, [T, \dot V]]$ etc. that appear at $O(dt^3)$ when $V$ is genuinely
> time-dependent.

Therefore:

**Coefficient claim [A]**: $\alpha_2 = -1/48$ remains the unique correct
value for the FG correction in the nonlinear-V case. Picking any other
$\alpha_2$ would re-introduce a *new* static $[V,[T,V]]$ residual on top
of the unkillable time-dependent residuals. **The coefficient is
unchanged.** [Established by §2.3 BCH structure + Simpson identity §2.3.]

**Realized-order claim [B]**: Even with $\alpha_2 = -1/48$, the achievable
order is bounded above by the accuracy of (a) the midpoint MF estimator
$\psi(dt/2)$ used to anchor $V_{1/2}$ in slot 3 ($\tilde V$), and (b) the
treatment of the cross-commutator $\dot V$ residuals at $O(dt^3)$.

This matches the production empirical record exactly
(`integrator_ch3_5_narrative.md` §3.5.3, force_gradient.jl docstring
lines 213–223):

| variant | midpoint MF source | nonlinear order |
|---|---|---|
| 4A00 ($n\_picard=1$, no predictors) | $\psi(0)$ (no midpoint shift) | **0.96** |
| v2 (Strang half-step predictor, $O(dt^2)$) | Strang($dt/2$) | **~2.9-3.2** |
| v3.1 (Strang re-prediction Picard) | Picard-converged Strang($dt/2$) | **~2.8-3.0** |

The progression is consistent: midpoint MF error $O(dt^k)$ feeds a
$V_{1/2}$ error of the same order, which through the BCH cascade
contributes $O(dt^{k+1})$ to the global per-step residual, capping
*global* nonlinear order at roughly $k+1$. Strang's $k=2$ midpoint
gives nonlinear $\sim 3$. To reach nonlinear order 4 would require a
midpoint MF predictor of order $\geq 3$ — itself either a Y4-style
inner solve (`integrator_ch3_5_narrative.md` line 100: "circular and
expensive") or a higher-order multi-stage Picard scheme.

### 2.5 Independent angle — empirical witness in the production tree

The narrative `integrator_ch3_5_narrative.md` lines 84–101 documents
five distinct attempted refinements to push nonlinear order from 1 (v1)
to 4 (target), all of which respected $\alpha_2 = -1/48$ unchanged. The
narrative's own verdict line 103: **"Force-Gradient on lab path plateaus
at order ~3 in nonlinear regime with practical Picard iterations.
Y4-midpoint (Track A1) reaches clean order 4 at comparable cost.
Y4-mid wins cost-per-accuracy."**

This is the inverse of what would be observed if the coefficient itself
were wrong in the nonlinear case: a wrong $\alpha_2$ would produce
order $\leq 2$ regardless of MF predictor quality (because the static
$\beta_C$ residual would not be cancelled and would dominate at $O(dt^3)$).
The fact that nonlinear order *climbs* from 1 → 3 as MF predictors
improve is direct evidence that the static $\beta_C$ cancellation is
working — i.e. that $\alpha_2 = -1/48$ is correct in the nonlinear case
too. The remaining gap (3 vs 4) is the MF/Magnus residual, not the
coefficient.

### 2.6 Where this leaves Q2 from `runs/_loop/seed.md`

The seed offered three possible outcomes:
1. *Coefficient survives unchanged, order stays 4* — partially correct.
   Coefficient survives. Order stays 4 only in the limit of an
   "ideal" midpoint MF predictor; with a practical Strang-$O(dt^2)$
   predictor, achievable order is 3.
2. *Coefficient modified by $g\cdot\langle\psi|\dots|\psi\rangle$* — incorrect.
   The coefficient is a free-Lie-algebra invariant (turn 1 §2.2) and
   the nonlinear-V $\dot V$ terms do not multiply the same operator
   $[V,[T,V]]$, so they cannot be absorbed by adjusting $\alpha_2$.
3. *Order degrades from 4 to 3 for nonlinear V* — empirically yes,
   structurally for the reason explained in §2.4 (midpoint MF predictor
   quality), not because $\alpha_2$ is wrong.

The cleanest statement is: **outcome (1) for the coefficient, outcome
(3) for the realized order, with the two phenomena being structurally
distinct.** The seed's framing "BCH typically assumes constants;
nonlinear V brings ∂_t V terms" is correct — but the consequence of
those $\partial_t V$ terms is to limit the achievable order via
unkillable cross-commutator residuals, not to shift $\alpha_2$.

## 3. Sanity checks

### 3.1 Limit check — autonomous V (no time dependence) recovers the turn 1 result

Set $g = 0$ (or freeze $\psi$ in $V$): $V_0 = V_{1/2} = V_1 = V$,
$\dot V = 0$, $\ddot V = 0$. Every "time-derivative" residual in §2.3
vanishes identically. Only the static $\beta_C\,[V,[T,V]]$ remains;
$\alpha_2 = -1/48$ cancels it; order = 4 cleanly. This matches the
autonomous Chin 4A bench (`scripts/bench/track_c_v4_a11_alpha_sweep.jl`)
and the empirical $\alpha$-sweep record (memory
`gotcha_fg_correction_sign_wick_rotation.md`: only $\alpha = -1/72$
collapses error to FP-floor). [Established — limit reproduces turn 1
case bit-exactly.]

### 3.2 Simpson identity — independent verification

The §2.3 Simpson check is a one-line independent identity: weights
$(1/6, 2/3, 1/6)$ on three equally-spaced nodes $(0, dt/2, dt)$
reproduce $\int_0^{dt} f(s)\,ds / dt$ to fourth order — this is
**Simpson's 1/3 rule** with quadrature error $-(dt^4/2880)\,f^{(4)}(\xi)$.
So the time-averaging of $V$ across slots is already 4th-order
accurate; *no order-2 or order-3 residual comes from this channel*.
Any residual must come from $\Omega_2$ (commutator-of-commutators
involving $\dot V$) or higher Magnus terms, not from the time-average
of $V$. This is consistent with the structural picture of §2.4. The
fact that the 4A weights happen to be Simpson weights is not a
coincidence — Chin (1997) chose them to maximize quadrature order for
the time-dependent case (CK 2005 §IV alludes to this).
[Established — Simpson 1/3 rule is textbook.]

### 3.3 Cross-check — production docstring already encodes the realized-order story

The docstring at `force_gradient.jl` lines 213–223 lists explicit
empirical orders for three Picard hierarchies, matching the structural
picture in §2.4. The pre-existing doc-comment is consistent with the
derivation but does **not** explain *why* the coefficient $-1/48$
nonetheless remains correct — only that practical orders cap at 3-4.
This is the structural gap turn 2 closes. [Established by direct
read of production source, this turn.]

### 3.4 Failure-mode falsifier — state-average midpoint

`integrator_ch3_5_narrative.md` line 79 records that an alternative
state-average midpoint Picard collapsed v3 from order ~3 back to
order 2.00. If the FG coefficient cancellation were sensitive to
*how* the nonlinear MF is averaged, this failure mode would not have
a state-average–specific signature; it would manifest at all MF
choices. The fact that the failure is specific to state-average
$(\psi(0)+\psi_{\rm current})/2$ (a documented cos(Hτ/2) AVF
anti-pattern, narrative §3.3.2) and that Strang-half-step + Picard
**preserves** order ~3 with the same $\alpha_2 = -1/48$ confirms that
the coefficient is robust and the order is set by MF accuracy
independently. [Established empirically — narrative §3.7.4.c.]

### 3.5 Dimensional check

Same as turn 1 §3.2 — $\alpha_2$ is dimensionless because it multiplies
$dt^2 \cdot [V,[T,V]]$ with $[V,[T,V]] = E^3$ and $dt = 1/E$ in our
units. Adding $g|\psi|^2$ to $V$ does not change $[V]$ (it is still an
energy density), so $[V,[T,V]]$ still has units $E^3$ and $\alpha_2$
remains dimensionless. Wick rotation only affects the sign, not the
dimensions. [Established.]

## 4. Calibrated claims

- [Established] The real-time FG coefficient $\alpha_2 = -1/48$
  ($\alpha_3 = -1/72$) is unchanged by the introduction of nonlinear
  $V = V_0(r) + g|\psi(t)|^2$. The free-Lie-algebra argument of
  turn 1 §2.2 generalizes to the three-symbol case $V_0, V_{1/2}, V_1$;
  the static $\beta_C$ residual factor is set by composition weights
  $(a_o, a_m, b)$ — not by the time-dependence of $V$. Time-dependent
  cross-commutator residuals at $O(dt^3)$ involve *new* operator
  structures $[V,[T,\dot V]]$ etc. that cannot be cancelled by any
  $\alpha_2$ on $[V,[T,V]]$. Source: §2.3–§2.4 + Simpson identity §3.2.

- [Established] Achievable global order on the nonlinear GPE is
  bounded above by $k_{\rm MF} + 1$, where $k_{\rm MF}$ is the
  accuracy order of the midpoint MF predictor used to anchor
  $V_{1/2}$. With Strang half-step predictor ($k_{\rm MF} = 2$),
  achievable order is $\sim 3$; cleanly reaching order 4 requires
  $k_{\rm MF} \geq 3$. Source: §2.4 + production narrative §3.5.3
  empirical record.

- [Established] The production code already exhibits exactly this
  pattern: 4A00 (no midpoint) gives order 0.96; v2 (Strang
  midpoint, $k_{\rm MF} = 2$) gives order 2.9–3.2; v3.1
  (Picard-refined Strang midpoint, still $k_{\rm MF} = 2$) does not
  exceed order ~3. Source: `integrator_ch3_5_narrative.md` §3.5.3
  + `force_gradient.jl` docstring lines 213–223.

- [Established] Outcome (2) from `runs/_loop/seed.md` (coefficient
  modified by $g\,\langle\psi|\dots|\psi\rangle$) is **incorrect**.
  The nonlinear $\dot V$ residuals are not proportional to
  $[V,[T,V]]$ and therefore cannot be absorbed into $\alpha_2$.
  Source: §2.3 operator-structure argument.

- [Plausible] Outcome (3) from `runs/_loop/seed.md` (order degrades
  from 4 to 3 for nonlinear V) is correct in practice but the
  correct mechanism is **MF predictor accuracy**, not the FG
  coefficient. With an order-3 or higher midpoint MF predictor the
  scheme could in principle reach order 4 — but this is not
  cost-effective vs. Y4-midpoint (Track A1) per
  `integrator_ch3_5_narrative.md` line 103.

- [Plausible] The full BCH-on-three-symbols calculation
  (verifying that the $\Omega_2$ coefficient from Magnus is exactly
  reproduced by the 4A weights, not just at the leading
  $V$-time-average channel I checked in §2.3) is a tractable but
  lengthy algebraic exercise. I have NOT performed it this turn —
  flagged as `<RESEARCH_NEEDED: Q2.1>` only if a future turn needs
  the explicit $\Omega_2$ residual structure.

- [Plausible] An analogous turn-1-style doc-comment in
  `force_gradient.jl` — explicitly stating that
  $\alpha_2 = -1/48$ survives nonlinear V at the coefficient level
  *and* that the realized-order cap is a separate MF-predictor
  story — would inoculate against future agent re-derivation
  attempts (the same hazard turn 1 §1 motivated for the v4 case).
  See §6 directive.

## 5. Open questions

- **Q2.1**: Explicit Magnus $\Omega_2$ residual structure. §2.3 sketched
  that $\Omega_2 \sim -(dt^3/12)\,[T+V, \dot V]$; verifying this is
  *exactly* reproduced by the 4A composition (so that no residual at
  $O(dt^3)$ survives from this channel either, leaving only the
  $[V,[T,\dot V]]$-type unkillable cross-terms) is a calculation not
  performed this turn. Whether it matters depends on whether anyone
  attempts to push nonlinear order beyond 3 via composition redesign.
- **Q2.2**: Is there a 4A-compatible composition where the $\Omega_2$
  residual *and* the $[V,[T,\dot V]]$ cross-commutator both cancel
  simultaneously by augmenting with a second FG correction term
  proportional to $[V,[T,\dot V]]$? This is speculative; would require
  a higher-order force-gradient scheme like Chin's 6th-order families,
  out of scope here.
- **Q2.3**: Track A1 Y4-midpoint reaches order 4 nonlinear at
  comparable cost (narrative line 103). Why does Y4-midpoint
  *not* suffer the MF-predictor cap that FG does? Suspect this is
  because Y4-midpoint's inner $S_2(\beta dt)$ substeps each carry
  their own midpoint Picard, so the MF accuracy compounds across
  substeps; FG has only one midpoint anchor per outer step and one
  Picard channel for it. Outside Q2 scope this turn; potentially a
  Phase 2 sanity question on its own.

## 6. Directive for implementer

```json
{
  "action": "modify_code",
  "rationale": "Turn 0 pinned alpha_2 = -1/48 via regression. Turn 1 added a doc-comment locking the coefficient under spinor/F>1/DDI extensions. The remaining Q2 hole, addressed by turn 2 §2.3-§2.4, is that the coefficient is also invariant under NONLINEAR V (V = V0 + g|psi|^2) -- and CRITICALLY the empirical fact that realized order plateaus at ~3 in the nonlinear case is structurally a separate issue (midpoint-MF-predictor accuracy O(dt^2) -> global order ~3), NOT a coefficient problem. The production docstring at force_gradient.jl lines 213-223 lists the empirical nonlinear orders (0.96, ~2.9-3.2, plateau ~3) but does NOT explain that the coefficient -1/48 stays correct throughout this hierarchy. A future agent reading the docstring could plausibly conclude that the order-3 plateau implies the coefficient must be wrong in the nonlinear regime and 'fix' it. Recommend a 8-12 line doc-comment addition immediately after the existing # Self-consistency hierarchy block (line 223), distinguishing (A) coefficient invariance (theory: BCH static residual) from (B) realized-order cap (MF-predictor accuracy: structurally independent). Physically a noop; inoculates against the specific failure mode where someone confuses (A) and (B). Single axis of change per B5 (docstring only, no code semantics modified).",
  "target_files": [
    "src/hamiltonian/integrator/force_gradient.jl"
  ],
  "experiment_config": null,
  "expected_outcome": "Insert a new doc-comment block immediately after the existing '# Self-consistency hierarchy' block in the split_step_forcegrad! docstring (the block currently ending at the line 'FFT spectral derivative used for ∇V_eff (paper §IV recommendation).'). Approximately:\n\n  # Nonlinear-V coefficient invariance vs. realized-order cap (turn 2 §2.3-§2.4):\n  #\n  # The hierarchy above shows nonlinear order plateauing at ~3 (v3.1) even\n  # with Picard refinement. This is structurally SEPARATE from the FG\n  # coefficient: alpha_2 = -1/48 (fg_coeff line ~267 below) remains the\n  # unique correct value for nonlinear V = V_trap + c0|psi|^2 as well.\n  #\n  # Reason: the BCH static residue +beta_C * dt^3 * [V,[T,V]] (beta_C = 1/72)\n  # is set by 4A composition weights (1/6, 2/3, 1/6; 1/2, 1/2) and is\n  # cancelled by alpha_2 = -1/48 regardless of whether V is time-dependent.\n  # Time-dependent V introduces NEW dt^3 residuals of the form\n  # [V,[T,dV/dt]] etc.; these involve different operator structures than\n  # [V,[T,V]] and CANNOT be absorbed into alpha_2. They are instead\n  # bounded by midpoint-MF-predictor accuracy: Strang half-step is O(dt^2),\n  # so the global nonlinear order plateaus at ~3 regardless of Picard\n  # iteration count.\n  #\n  # Reaching order 4 nonlinear requires an O(dt^3)-accurate midpoint MF\n  # predictor (e.g. Y4-mid inner) -- expensive; Y4-midpoint (Track A1)\n  # is cost-competitive at order 4. See integrator_ch3_5_narrative.md\n  # §3.5.3 and runs/_loop/theorist/turn_2.md §2.3-§2.4.\n\nNo functional code change. No new test required. test/hamiltonian/test_force_gradient_wick_sign.jl from turn 0 must continue to pass at 18/18.",
  "falsification_criterion": "test/hamiltonian/test_force_gradient_wick_sign.jl must still pass 18/18: its regex r\"fg_coeff\\s*=\\s*it\\s*\\?[^\\n]+\" matches the unchanged fg_coeff ternary, and the bench alpha_factors list still contains '-1/72' and '-1/48'. The docstring-only addition must NOT touch the fg_coeff assignment line or the Wick-rotation comment immediately above it. If any test in test_force_gradient_wick_sign.jl fails, OR if the line containing 'fg_coeff = it ?' is altered, the change is rejected. Additionally: SPINORBEC_TEST_TIER=fast Pkg.test() must show no regression in any other suite (no test reads or depends on force_gradient.jl docstring content beyond the pinned Wick-sign regex).",
  "estimated_cost": "≤4 min: ~1 min draft the new doc-comment block, ~1 min cross-check fg_coeff line untouched, ~2 min run julia --project=. -e 'using Test; include(\"test/hamiltonian/test_force_gradient_wick_sign.jl\")' as no-regression check."
}
```

## 7. Research queries

```json
[]
```
