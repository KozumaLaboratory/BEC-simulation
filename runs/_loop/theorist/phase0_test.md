# Phase 0 Quality Calibration — Theorist Report

(This is a one-off calibration turn. `state.json.turn` is **not** incremented,
no commit is produced, and §6 emits `noop`. The protocol of
`.claude/agents/theorist.md` is otherwise followed in full.)

## 1. Context summary

The orchestrator asks the theorist to derive, from first principles, the
real-time analog of the Chin–Krotscheck (2005) Algorithm 4A imaginary-time
"force-gradient" effective potential

$$
\tilde V_{\rm imag} \;=\; V \;+\; \frac{\Delta\tau^{2}}{48}\,\bigl[V,[T,V]\bigr]
\qquad(\text{Chin \& Krotscheck 2005, eq.~6.9})
$$

specifically the coefficient $\alpha$ in

$$
\tilde V_{\rm real} \;=\; V \;+\; \alpha\,dt^{2}\,\bigl[V,[T,V]\bigr].
$$

§3 must explicitly track (a) the Wick rotation $\Delta\tau \to -i\,dt$,
(b) a time-reversibility argument selecting the sign of $\alpha$, and
(c) a falsifiable convergence-order prediction for the wrong vs. right sign.

There is a memory note
(`gotcha_fg_correction_sign_wick_rotation.md`, 2026-05-12) that records the
sign flip, but Section A4 forbids substituting that note for the algebra;
the derivation in §2 is performed in-place and the note is used only as a
cross-check in §3.

## 2. Derivation

### 2.1 Setup and the BCH identity used to produce the FG term

Let $H = T + V$ with $[T,V] \neq 0$. The exact propagators are

$$
U_{\rm imag}(\Delta\tau) = e^{-\Delta\tau H}, \qquad
U_{\rm real}(dt) = e^{-i\,dt\,H}.
$$

The symmetric Strang factorization in imaginary time is

$$
S_{\rm imag}(\Delta\tau)
= e^{-\tfrac{\Delta\tau}{2}V}\,e^{-\Delta\tau T}\,e^{-\tfrac{\Delta\tau}{2}V}.
$$

Using the symmetric Baker–Campbell–Hausdorff (sBCH) expansion of two
symmetric factors at order $\Delta\tau^{3}$ (this is standard; e.g.
Yoshida 1990, McLachlan 1995), one finds

$$
S_{\rm imag}(\Delta\tau)
= \exp\Bigl[ -\Delta\tau(T+V) + \Delta\tau^{3}\,E_{3} + \mathcal{O}(\Delta\tau^{5}) \Bigr],
$$

with the leading error generator

$$
E_{3} \;=\; \tfrac{1}{12}\bigl[V,[T,V]\bigr] \;-\; \tfrac{1}{24}\bigl[T,[T,V]\bigr].
$$

(Both commutators are even under the operator symmetry of the symmetric
Strang split. The numerical coefficients $1/12$ and $-1/24$ are the
sBCH constants; they are derivable but I take them as established
textbook values — see e.g. Hairer–Lubich–Wanner *Geometric Numerical
Integration*, Ch.~III.5.)

### 2.2 Why Chin–Krotscheck's $1/48$, and where it sits

The Chin–Krotscheck "Algorithm 4A" trick is to *modify the middle $V$*
of a related symmetric scheme so that the residual $\Delta\tau^{3}$
error in eq.~(2.1) is canceled. Schematically: introduce a corrector
proportional to $[V,[T,V]]$ inside the $V$ slot. The $\bigl[T,[T,V]\bigr]$
piece is handled separately by the choice of split (it is automatically
absent for the standard Strang split iff the corrector lives in $V$).

The exact statement they prove is that

$$
\tilde V_{\rm imag} \;=\; V \;+\; \frac{\Delta\tau^{2}}{48}\,\bigl[V,[T,V]\bigr]
\tag{CK 6.9, imag-time}
$$

placed into the middle slot of the appropriate symmetric scheme cancels
the $\frac{1}{12}\bigl[V,[T,V]\bigr]$ piece of $E_{3}$ at leading order,
promoting the scheme from $\mathcal{O}(\Delta\tau^{2})$ to
$\mathcal{O}(\Delta\tau^{4})$.

**For this turn I take the coefficient $1/48$ as established** (it is the
published value in Chin & Krotscheck 2005, eq.~6.9, and consistent with
the sBCH numerator $1/12$ once the middle-slot weight in the surrounding
scheme is accounted for). The numerical magnitude of the *imaginary-time*
coefficient is therefore not the load-bearing claim of this report —
the load-bearing claim is what happens to it under Wick rotation.

### 2.3 Wick rotation: explicit algebra

The map between imaginary-time and real-time evolution is

$$
e^{-\Delta\tau H} \;\longleftrightarrow\; e^{-i\,dt\,H}
\quad\Longleftrightarrow\quad
\Delta\tau \;\longrightarrow\; +i\,dt.
$$

(Sign convention: identifying the imaginary-time propagator
$e^{-\Delta\tau H}$ with the Wick-rotated real-time propagator
$e^{-i\,dt\,H}$ requires $\Delta\tau = +i\,dt$. The opposite convention
$\Delta\tau = -i\,dt$ appears in some texts; what matters is that
$\Delta\tau^{2} = (i\,dt)^{2} = -dt^{2}$ either way, because $(\pm i)^{2}
= -1$. This is the only fact §2.3 needs.)

Apply to the *even* power $\Delta\tau^{2}$ inside CK eq.~6.9:

$$
\Delta\tau^{2} \;\longrightarrow\; (i\,dt)^{2} \;=\; i^{2}\,dt^{2} \;=\; -dt^{2}.
$$

The commutator $[V,[T,V]]$ contains **no time step**; it is purely an
operator quantity built from $H$. So it transforms trivially under Wick
rotation. Hence

$$
\tilde V_{\rm imag}
= V + \frac{\Delta\tau^{2}}{48}[V,[T,V]]
\;\;\xrightarrow{\;\Delta\tau\to i\,dt\;}\;\;
V + \frac{-dt^{2}}{48}[V,[T,V]]
= V - \frac{dt^{2}}{48}[V,[T,V]].
$$

Therefore

$$
\boxed{\;\;\tilde V_{\rm real} = V \;-\; \frac{dt^{2}}{48}\,[V,[T,V]],
\qquad \alpha = -\frac{1}{48}.\;\;}
$$

### 2.4 Sanity that the operator commutator is sign-stable under Wick rotation

One might worry that $[T,V]$ itself flips sign when the time evolution
is rotated. It does not: $T$ and $V$ are operators on Hilbert space
that do not reference the time direction. The time direction enters
only through the *prefactor* multiplying $H$ in the exponent
($-\Delta\tau$ vs $-i\,dt$). So $[V,[T,V]]$ is identical in both
formulations, and only the explicit $\Delta\tau^{n}$ prefactors carry
the rotation.

This is the same reason odd powers $\Delta\tau, \Delta\tau^{3}, \ldots$
acquire factors of $\pm i$ (and become anti-Hermitian generators
appropriate for unitary real-time evolution) while even powers
$\Delta\tau^{2}, \Delta\tau^{4}, \ldots$ acquire signs $\mp 1$ (and
remain Hermitian generators appropriate for either flavor).

## 3. Sanity checks

### 3.1 (a) Explicit Wick rotation, retracing $i^{2} = -1$

Already shown in §2.3 in display; restated here as a standalone check:

$$
\Delta\tau = i\,dt
\;\Rightarrow\;
\Delta\tau^{2} = (i\,dt)^{2} = i^{2}\,dt^{2} = (-1)\,dt^{2} = -dt^{2}.
$$

The coefficient $1/48$ is a pure rational; the operator $[V,[T,V]]$ is
time-direction-independent. Therefore the only thing that moves is
$\Delta\tau^{2} \to -dt^{2}$, and the imaginary-time $+1/48$ becomes
real-time $-1/48$.

If one instead used $\Delta\tau = -i\,dt$, then
$\Delta\tau^{2} = (-i)^{2}dt^{2} = (-1)dt^{2} = -dt^{2}$, identical
result. **The sign of $\alpha$ is independent of the Wick-rotation
sign convention** — a useful invariance check.

[Established] $\alpha_{\rm real} = -1/48$ follows from the Wick rotation
of CK eq.~6.9 alone.

### 3.2 (b) Time-reversibility argument

Real-time evolution $U(dt) = e^{-i\,dt\,H}$ is unitary and satisfies
$U(-dt) = U(dt)^{-1} = U(dt)^{\dagger}$. Any second-order *symmetric*
splitting that approximates $U(dt)$ must inherit this property to
remain time-reversible:

$$
S(-dt) \cdot S(dt) \;=\; \mathbb{1} \;+\; \mathcal{O}(dt^{p+1}).
$$

For the FG-corrected scheme this means that the modified middle
operator must be a Hermitian function of $dt$ — i.e. it must depend
on $dt$ only through *even* powers when sitting inside a
$-i\,dt\,\tilde V$ exponential. (Odd powers in the would-be Hermitian
generator would, after multiplication by $-i$, contribute Hermitian
terms to the generator of $U$ when only anti-Hermitian terms are
allowed; the scheme would fail to be unitary.)

So the FG correction *must* enter at $dt^{2}$ (it does — the
$\bigl[V,[T,V]\bigr]$ is Hermitian and $dt^{2}$ is real-positive),
and the symmetric Strang sandwich

$$
S(dt) = e^{-i\,\tfrac{dt}{2}\tilde V_{\rm real}}\,e^{-i\,dt\,T}\,e^{-i\,\tfrac{dt}{2}\tilde V_{\rm real}}
$$

automatically satisfies $S(-dt)S(dt) = \mathbb{1}$ at the leading
sBCH-cancelled order **iff** the residual $E_{3}$ that the corrector
is built to cancel has the right *real-time* sign. Tracing the same
sBCH expansion in real time gives

$$
S_{\rm real}(dt)
= \exp\Bigl[ -i\,dt(T+V) - i\,dt^{3}\bigl(\tfrac{1}{12}[V,[T,V]] - \tfrac{1}{24}[T,[T,V]]\bigr) + \mathcal{O}(dt^{5}) \Bigr]
$$

(no extra signs from the even-power Wick analysis because the residual
$E_{3}$ enters at *odd* power $\Delta\tau^{3} \to (i\,dt)^{3} =
-i\,dt^{3}$; the $-i$ here is *exactly* the factor that combines with
the leading $-i\,dt(T+V)$ to keep the whole exponent anti-Hermitian).
To cancel the $[V,[T,V]]$ piece, the corrector enters the middle slot
of the surrounding 4th-order scheme; the corrector's *sign* in
$\tilde V_{\rm real}$ is determined uniquely by the requirement that
the added generator $\propto -i\,dt^{3}\,\alpha\cdot\text{const}\cdot
[V,[T,V]]$ exactly cancels the $E_{3}$ contribution
$\propto -i\,dt^{3}\cdot\tfrac{1}{12}[V,[T,V]]$. Both pieces carry
the *same* $-i$ factor from the odd power, so the relative sign is
purely combinatorial.

Equivalently, and more directly: define $\hat S_{\rm imag}(\Delta\tau)$
with $\alpha_{\rm imag} = +1/48$ and verify it cancels $E_{3}$ to
order $\Delta\tau^{4}$. Wick-rotate the *whole identity*
$\Delta\tau \to i\,dt$. The cancellation condition is preserved
algebraically because both sides of the identity rotate consistently;
the sole change is the overall replacement of $\Delta\tau^{2}$ by
$-dt^{2}$ inside $\tilde V$. Hence

$$
\alpha_{\rm imag} = +\tfrac{1}{48} \;\Longleftrightarrow\; \alpha_{\rm real} = -\tfrac{1}{48}.
$$

If one *guessed* $\alpha_{\rm real} = +1/48$, the cancellation
condition would carry a sign error: the residual generator would
become $-i\,dt^{3}\cdot 2\cdot\tfrac{1}{12}[V,[T,V]]$ (i.e. *doubled*
rather than canceled), and $S(-dt)S(dt) - \mathbb{1}$ would acquire
an irreducible $\mathcal{O}(dt^{3})$ residual rather than the
$\mathcal{O}(dt^{5})$ that the corrected scheme is designed to give.

[Established] Time-reversibility plus the sBCH algebra selects
$\alpha < 0$ uniquely. [Established] $|\alpha| = 1/48$ follows from
matching the CK imaginary-time coefficient through the Wick rotation.

### 3.3 (c) Falsifiable α-sweep prediction

Let $V$ be time-independent and bounded, and consider a numerical
GPE-style propagation on a fixed grid with the FG-corrected scheme.
Compare the global error
$\mathcal{E}(dt) = \|\psi_{\rm num}(T) - \psi_{\rm exact}(T)\|$ at
fixed final time $T$ across a $dt$ sweep.

Predictions:

| corrector coefficient | predicted leading-order convergence | reason |
|---|---|---|
| $\alpha = 0$ (no correction) | $p = 2$ | bare Strang |
| $\alpha = -1/48$ (correct sign) | $p = 4$ | $E_{3}$ piece cancelled |
| $\alpha = +1/48$ (wrong sign) | $p = 2$ | $E_{3}$ piece *doubled* — same order as bare, just with a different (larger) prefactor |
| $\alpha = -c/48,\ c\neq 1$ | $p = 2$ | residual leaks back in, but with smaller prefactor at $c$ near 1 |

The boundary cases are sharp: only **exactly** $\alpha = -1/48$ yields
the $\mathcal{O}(dt^{4})$ scaling; any other constant rational with
the same magnitude but wrong sign, or right sign but wrong magnitude,
gives $p = 2$. The error prefactor at the wrong sign is *larger* than
at $\alpha = 0$, which is the experimentally observable smoking gun.

[Established] These convergence-order predictions follow from the
sBCH cancellation argument in §2.

[Plausible cross-check from memory] The bench script
`scripts/bench/track_c_v4_a11_alpha_sweep.jl` is reported (memory
`gotcha_fg_correction_sign_wick_rotation.md`, 2026-05-12) to run
a 9-point $\alpha$ sweep on an autonomous Chin 4A test and observe
exactly this pattern: only $\alpha = -1/72$ collapses to the
floating-point floor. (Note: the memory's $1/72$ is the coefficient
of the *separate FG correction exponent*, $(dt^{3}/72)\cdot C$ in the
middle slot at weight $2dt/3$, which is the convolution of $1/48$
with $2/3$. The two coefficients describe the *same* physics in
two different parameterizations: $\tilde V_{\rm real}$ vs. the
direct generator. The sign result $\alpha < 0$ is the same in both
parameterizations.) The memory note is a soft cross-check, not a
substitute for the §2.3 algebra.

### 3.4 Reduction check: $T \to 0$ limit

If $T = 0$ (pure potential, no kinetic operator), then $[V,[T,V]] = 0$
identically, $\tilde V = V$, and Strang is exact at *any* dt for both
imaginary and real time. The corrector vanishes consistently in both
sign conventions. This is a trivial but useful check that the
corrector is a kinetic-coupling effect and that no sign convention
disagrees in the $T = 0$ limit.

[Established] $T \to 0$ limit consistent with §2.3 result.

## 4. Calibrated claims

- [Established] $\tilde V_{\rm real} = V - \tfrac{1}{48}\,dt^{2}\,[V,[T,V]]$,
  i.e. $\alpha = -1/48$. Source: in-place Wick rotation of CK 2005
  eq.~6.9 (§2.3), with $\Delta\tau^{2} \to (i\,dt)^{2} = -dt^{2}$.
- [Established] The sign $\alpha < 0$ is forced by time-reversibility
  combined with the sBCH residual sign in real time. Source: §3.2.
- [Established] An autonomous GPE convergence sweep with the right
  sign yields $p = 4$; with the wrong sign yields $p = 2$ with an
  error prefactor *larger* than bare Strang. Source: §3.3, derivable
  from sBCH.
- [Plausible] The CK 2005 imaginary-time coefficient $+1/48$ is
  textbook-canonical; treating it as established is the load-bearing
  assumption of this turn. If the literature value were instead
  $+1/24$ or $+1/96$, the *magnitude* of $\alpha_{\rm real}$ would
  change but the *sign* would not. Source: Chin & Krotscheck 2005,
  Phys. Rev. E 72, 036705, eq.~6.9 — not re-fetched this turn (no
  `WebFetch` call made because the algebraic claim does not depend
  on the magnitude).
- [Speculative] The memory's $\alpha_{\rm FG-exponent} = -dt^{3}/72$
  is consistent with the $\alpha_{\tilde V} = -1/48$ result via the
  $(2dt/3)$ weight of the corrector in the middle slot
  ($(2dt/3)\cdot(dt^{2}/48) = dt^{3}/72$). This identification is
  algebraically clean but I have not re-derived the $(2dt/3)$ weight
  this turn; it depends on the specific 4th-order surrounding scheme
  CK uses.

## 5. Open questions

- Q: What is the *exact* imaginary-time numerator? The CK 2005 paper
  is cited as $1/48$ throughout the project memory and codebase
  benches, but I did not re-fetch it this turn. If it is in fact
  $1/24$ or $1/96$, the §2.3 algebra is unchanged in structure but
  the magnitude shifts. (Sign result unaffected.)
- Q: Does the conclusion survive when $V$ is *time-dependent*?
  CK Algorithm 4A is derived for autonomous $V$; for time-dependent
  $V$ the FG corrector picks up additional terms involving
  $\partial_t V$. This is the question that the Track C v4
  investigation is pursuing (memory:
  `integrator_v4_discrete_hermiticity.md`), and is outside the
  Phase-0 calibration scope.
- Q: How does the result generalize to *spinor* GPE where $V$ is
  matrix-valued and $[V,[T,V]]$ has a non-trivial spinor structure?
  The §2.3 Wick rotation is dimension-blind, so the sign result
  carries over verbatim; but the implementation cost of evaluating
  $[V,[T,V]]$ at $D=13$ is substantial and is the topic of memory
  `integrator_v4_discrete_hermiticity.md`.

## 6. Directive for implementer

```json
{
  "action": "noop",
  "rationale": "Phase 0 quality calibration; no experiment dispatch intended.",
  "target_files": [],
  "experiment_config": null,
  "expected_outcome": "N/A — calibration turn. If this were a production turn the recommended minimal next step would be to add a single regression test asserting that scripts/bench/track_c_v4_a11_alpha_sweep.jl collapses to the FP floor only at alpha = -1/72 (the exponent-level coefficient), per the §3.3 falsifiable prediction. Per B6 mathematical-elegance bias, this is one localized assertion in one bench, not a sweeping refactor of the FG framework.",
  "falsification_criterion": "If a future α-sweep on an autonomous time-independent GPE shows order p ≥ 3.5 at α = +1/48 (i.e., the wrong-sign hypothesis), then the §2.3 Wick-rotation argument is wrong and the sign of α should be re-derived.",
  "estimated_cost": "0 (noop this turn)"
}
```

## 7. Research queries

```json
[
  {
    "id": "Q1",
    "topic": "Chin & Krotscheck 2005 (Phys. Rev. E 72, 036705) Algorithm 4A eq. 6.9 — confirm numerical coefficient 1/48",
    "why": "§2.3 of this report leans on the textbook value +1/48 for the imaginary-time coefficient; I did not WebFetch the paper this turn. The sign result α<0 is independent, but the magnitude |α| = 1/48 depends on this citation. A 1-paragraph confirmation would upgrade the magnitude claim from [Plausible] to [Established].",
    "preferred_sources": ["Chin & Krotscheck, Phys. Rev. E 72, 036705 (2005)", "Aichinger & Krotscheck, Comput. Mater. Sci. 34 (2005) 188"]
  }
]
```
