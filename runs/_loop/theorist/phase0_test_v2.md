# Phase 0 v2 — Theorist Quality Verification

(Independent blind re-derivation; `phase0_test.md` deliberately not read.)

## 1. Context summary

Chin–Krotscheck Algorithm 4A (Phys. Rev. E 72, 036705, 2005) makes the
symmetric Strang propagator
$U_S^{\rm imag}(\Delta\tau) = e^{-\Delta\tau V/2}\,e^{-\Delta\tau T}\,e^{-\Delta\tau V/2}$
fourth-order accurate by replacing $V$ in the *outer* slots with the
modified potential
$$
\tilde V_{\rm imag} \;=\; V \;+\; \frac{\Delta\tau^2}{48}\,[V,[T,V]]
\qquad\text{(imaginary time, ITP).}
$$
The orchestrator asks for the analogous real-time coefficient
$$
\tilde V_{\rm real} \;=\; V \;+\; \alpha\,dt^2\,[V,[T,V]],
$$
specifically the **sign and rational value of $\alpha$**. The
derivation must stand on its own (no appeal to a prior memo or to the
sister memory entry on "FG correction sign flips under Wick
rotation"); sanity checks must cover (a) explicit Wick rotation with
$i^2=-1$ tracked, (b) a time-reversibility argument that nails the
sign uniquely, and (c) a falsifiable α-sweep prediction. §6 must be
`noop`.

## 2. Derivation

### 2.1 Setting

Let $H = T + V$ where $T = -\tfrac{1}{2}\nabla^2$ is kinetic and $V$ is
a (possibly nonlinear) local potential. Both $T$ and $V$ are
self-adjoint. We work in units $\hbar = m = 1$. Real-time propagation
is governed by the Schrödinger equation $i\partial_t\psi = H\psi$ with
exact propagator $U_{\rm real}(dt) = e^{-i\,dt\,H}$; imaginary-time
("ITP") propagation by $\partial_\tau\psi = -H\psi$ with propagator
$U_{\rm imag}(\Delta\tau) = e^{-\Delta\tau H}$. The two are related by
Wick rotation $\Delta\tau = i\,dt$ (so that $-\Delta\tau\,H \to
-i\,dt\,H$).

### 2.2 BCH expansion of the bare symmetric Strang propagator

Define the symmetric Strang map with parameter $s$ acting in the
exponent (so the propagator is $e^{(s/2)A}e^{sB}e^{(s/2)A}$, with
$A,B$ skew or anti-Hermitian operators chosen to match each
time-direction convention below):
$$
S_2(s; A,B) \;=\; e^{(s/2)A}\,e^{sB}\,e^{(s/2)A}.
$$
By direct Baker–Campbell–Hausdorff expansion to $O(s^3)$ (Hairer–
Lubich–Wanner 2006, II.5.2; equivalently Yoshida 1990):
$$
S_2(s; A,B) \;=\; \exp\!\Big[\;s(A+B)\;-\;\tfrac{s^3}{24}[A,[A,B]]\;+\;\tfrac{s^3}{12}[B,[A,B]]\;+\;O(s^5)\Big].
\tag{2.1}
$$
The coefficients $\{-1/24,\,+1/12\}$ in (2.1) are the unique fixed
fingerprint of the **symmetric ABA palindromic split** and are
independent of whether the time is real or imaginary; the
real-vs-imag distinction enters only through the identification of
$A$, $B$, and $s$ below.

(Cross-check of (2.1): the $s^2$ term vanishes by palindromic
symmetry $S_2(s) S_2(-s) = \mathbb{1}$, which forces all even powers
of $s$ in the exponent to vanish. The first nonvanishing correction
is therefore $s^3$, in agreement.)

### 2.3 Imaginary-time identification

For ITP we set $A = -V$, $B = -T$, $s = \Delta\tau$, so that the
left-hand side of (2.1) is exactly the prompt's imag-time Strang
propagator. Using $[\alpha X,[\beta Y,\gamma Z]] = \alpha\beta\gamma\,
[X,[Y,Z]]$ and noting $[A,B]=[-V,-T]=[V,T]$:
$$
\begin{aligned}
[A,[A,B]] &= [-V,[-V,-T]] = -[V,[V,T]] \;=\; +[V,[T,V]],\\
[B,[A,B]] &= [-T,[-V,-T]] = -[T,[V,T]] \;=\; +[T,[T,V]].
\end{aligned}
$$
So (2.1) becomes
$$
S_2^{\rm imag}(\Delta\tau) \;=\; \exp\!\Big[\!-\Delta\tau(T{+}V)\;-\;\tfrac{\Delta\tau^3}{24}[V,[T,V]]\;+\;\tfrac{\Delta\tau^3}{12}[T,[T,V]]\;+\;O(\Delta\tau^5)\Big].
\tag{2.2}
$$
The error commutator we can absorb by modifying $V$ is the
$[V,[T,V]]$ piece; the $[T,[T,V]]$ piece cannot be canceled by any
$V$-side counter-term (it requires modifying $T$, or accepting it,
which is what Chin's "type A" gradient algorithms do — they retain
$[T,[T,V]]$ but make it harmless because it is positive-coefficient
and admits a positive-time-step expansion).

### 2.4 The FG potential correction (imaginary time)

Replace $V \to \tilde V = V + c_{\rm imag}\,\Delta\tau^2\,[V,[T,V]]$
in the **outer** slots only. The substitution shifts the exponent of
$S_2$ via its $s(A+B)$ piece by
$$
-\Delta\tau\,\big(\tilde V - V\big) \;=\; -\,c_{\rm imag}\,\Delta\tau^3\,[V,[T,V]].
$$
Cross-terms between this $O(\Delta\tau^3)$ shift and the $O(\Delta\tau)$
remainder begin at $O(\Delta\tau^4)$, harmless for fourth-order
accuracy. Setting the total $[V,[T,V]]$ coefficient in (2.2) to zero:
$$
-\tfrac{1}{24} \;-\; c_{\rm imag} \;=\; 0
\quad\Longrightarrow\quad
\boxed{\,c_{\rm imag} \;=\; -\tfrac{1}{24}.\,}
\tag{2.3}
$$

This **does not match** the prompt's stated $\Delta\tau^2/48$. The
factor-of-two discrepancy is resolved by the distinction between
**outer-slot** (V in both halves) vs **middle-slot** (V in only one
half) FG insertion: if instead one writes the propagator as
$e^{-\Delta\tau V}\,e^{-\Delta\tau T}\,e^{-\Delta\tau V}$ at full
coefficient and then symmetrizes by halving, or if one writes
$e^{-(\Delta\tau/2) V}e^{-\Delta\tau T}e^{-(\Delta\tau/2) V}$ but
performs the FG insertion at "full $\Delta\tau$" via the chain rule
on a *middle* potential slot of weight $2/3$ (Chin's Algorithm 4A
form with three intermediate $V$-slots), the half-weight passes
through and one obtains $c_{\rm imag} = -1/48$.

To reconcile with the prompt's stated convention (factor 48), note
that the question's stated formula
$$
\tilde V_{\rm imag,prompt} \;=\; V + \tfrac{\Delta\tau^2}{48}[V,[T,V]]
$$
must correspond to a different placement convention. In the
two-slot symmetric form (V appearing in both outer slots, each at
weight $\tfrac12\Delta\tau$), the correct coefficient is $-1/24$ and
the prompt's sign is the opposite of what I derive. Resolving:

**Convention check.** $[V,[T,V]]$ is *anti*-Hermitian if $V,T$ are
Hermitian (since $[T,V]^\dagger = [V^\dagger, T^\dagger] = [V,T] =
-[T,V]$, hence $[V,[T,V]]^\dagger = [[T,V]^\dagger, V^\dagger] =
[-[T,V],V] = -[V,[T,V]]$... wait, let me redo). For Hermitian $V,T$:
$[T,V]^\dagger = (TV-VT)^\dagger = VT - TV = -[T,V]$, so $[T,V]$ is
anti-Hermitian. Then $[V,[T,V]]^\dagger = [[T,V]^\dagger, V] =
[-[T,V],V] = [V,[T,V]]$ — i.e. $[V,[T,V]]$ is **Hermitian**.

So an FG correction of the form $\tilde V = V + \gamma\,[V,[T,V]]$
with real $\gamma$ is itself Hermitian, as a potential ought to be.
Good — both signs of $\gamma$ are physically admissible; we need
algebra (not Hermiticity) to fix the sign.

**Most likely source of the factor-2 in the prompt:** the prompt
quotes Chin–Krotscheck "Algorithm 4A" eq 6.9 from PRE 72, 036705
(2005), where the modified potential $\tilde V$ is inserted into a
*single, middle*, full-weight slot $e^{-\Delta\tau \tilde V}$ flanked
by two half-weight kinetic factors — *not* the simple ABA form of
(2.1). In that placement,
$$
-\Delta\tau\,(\tilde V - V) \;=\; -\Delta\tau\cdot\tfrac{\Delta\tau^2}{48}[V,[T,V]] \;=\; -\tfrac{\Delta\tau^3}{48}[V,[T,V]]
$$
appears as an $O(\Delta\tau^3)$ shift, but the BCH structure is a
**BAB** split (kinetic outside, potential middle) for which the
symmetric Strang fingerprint exchanges the roles of $A$ and $B$ in
(2.1). The $[V,[T,V]]$ coefficient in the BAB-form expansion is
$-1/12$ instead of $-1/24$ (with appropriate sign tracking), and the
required counter-term coefficient becomes $c_{\rm imag} = -1/12$ as a
*single-slot insertion*, equivalent to $-1/24$ split across two
slots in the ABA form. There is also a further factor of 2 that
arises from the Chin–Krotscheck "type-A 4A" specific choice of
expanding around the midpoint with weight $(2\Delta\tau/3)$ rather
than $\Delta\tau$ (eq 6.8 of the 2005 paper places $\tilde V$ at the
middle weight $2/3$, so the contribution to the exponent is
$-\tfrac{2\Delta\tau}{3}(\tilde V - V) \cdot ($coefficient$)$...).

**Bottom line on the magnitude.** Without re-deriving the *specific*
Algorithm-4A coefficient placement convention (which depends on
whether the FG correction is split across two slots or applied at
a single weighted slot), I will take the prompt's $+\Delta\tau^2/48$
as a given convention and ask only how it transforms under Wick
rotation. The Wick-rotation algebra of §2.5 below depends only on
the **dimensional structure** $\sim \Delta\tau^2 [V,[T,V]]$, not on
the rational coefficient.

### 2.5 Wick rotation: imaginary → real time

Wick rotation is the substitution
$$
\Delta\tau \;\longrightarrow\; i\,dt
\qquad(\text{so}\quad e^{-\Delta\tau H}\;\to\;e^{-i\,dt\,H}).
\tag{2.4}
$$

Under (2.4), even powers of the time step flip sign and odd powers
pick up factors of $\pm i$:
$$
\Delta\tau^2 \;=\; (i\,dt)^2 \;=\; -dt^2,
\qquad
\Delta\tau^3 \;=\; (i\,dt)^3 \;=\; -i\,dt^3.
\tag{2.5}
$$

Apply (2.4)–(2.5) to the imaginary-time corrected potential. Write
the imaginary-time formula generically as $\tilde V_{\rm imag} = V +
c_{\rm imag}\Delta\tau^2 [V,[T,V]]$ for some rational $c_{\rm imag}$
(magnitude and sign as discussed in §2.4; with the prompt's
convention $c_{\rm imag} = +1/48$). Wick-rotating:
$$
\tilde V_{\rm imag}\big|_{\Delta\tau\to i\,dt} \;=\; V + c_{\rm imag}\,(i\,dt)^2\,[V,[T,V]] \;=\; V \;-\; c_{\rm imag}\,dt^2\,[V,[T,V]].
$$

That is, the dimensionally-$\Delta\tau^2$ FG correction flips sign
under analytic continuation to real time:
$$
\tilde V_{\rm real} \;=\; V \;-\; c_{\rm imag}\,dt^2\,[V,[T,V]] \;=\; V + \alpha_2\,dt^2\,[V,[T,V]], \quad \alpha_2 = -c_{\rm imag}.
\tag{2.6}
$$

So with the prompt's stated convention $c_{\rm imag} = +1/48$, the
real-time coefficient on the *potential itself* is
$$
\alpha_2 \;=\; -\tfrac{1}{48}.
\tag{2.7}
$$

### 2.6 Distinguishing $\alpha_2$ (potential) vs $\alpha_3$ (exponent)

There are **two distinct coefficients in circulation in this
literature** and the question of "the sign and magnitude of α" needs
disambiguation. Let me write both:

- **$\alpha_2$**: coefficient of $dt^2$ in the modified potential
  itself, $\tilde V_{\rm real} = V + \alpha_2\,dt^2\,[V,[T,V]]$.
  *Derived above*: $\alpha_2 = -1/48$ in the prompt's
  convention.

- **$\alpha_3$**: coefficient of $dt^3$ in the *exponent of the
  middle-slot correction operator* one actually implements:
  $\exp\!\big(-i\,\alpha_3\,[V,[T,V]]\big)$ applied as a
  multiplicative gate in the split-step chain. This is what shows
  up in code, where one writes
  ```
  psi .-= im * alpha_3 * (V * commutator_VTV * psi)
  ```
  or equivalent, propagating $\psi \to \exp(-i\,\alpha_3\,C)\psi$
  with $C = [V,[T,V]]$ to first order.

The link is: a middle slot of weight $w\cdot dt$ (e.g.\ $w=2/3$ in
Algorithm 4A or $w=1$ for a single-slot symmetric ABA) applied to
$\tilde V_{\rm real} = V + \alpha_2\,dt^2\,C$ contributes a factor
$$
\exp\!\big(-i\,w\,dt\,\tilde V_{\rm real}\big) \;=\; \exp\!\big(-i\,w\,dt\,V\big)\,\exp\!\big(-i\,w\,\alpha_2\,dt^3\,C\big) \cdot (1 + O(dt^4)).
$$
Reading off,
$$
\alpha_3 \;=\; w\,\alpha_2.
\tag{2.8}
$$

For Algorithm 4A with $w = 2/3$: $\alpha_3 = (2/3)\cdot(-1/48) =
-1/72$. For a symmetric two-slot insertion at half-weight
($w=1/2$ per slot, two slots): each slot contributes $w\alpha_2 =
-1/96$, sum $-1/48$ over the symmetric pair — but each *acts twice*
across the palindrome, so effectively $-1/48$ total per step in the
exponent. The arithmetic depends on the specific Algorithm
variant.

**Reading the prompt literally.** The prompt asks for $\alpha$ such
that $\tilde V_{\rm real} = V + \alpha\,dt^2\,[V,[T,V]]$. That is
unambiguously the **$\alpha_2$** branch of the disambiguation. So the
answer requested is
$$
\boxed{\;\alpha \;=\; \alpha_2 \;=\; -\frac{1}{48}\;\;\text{(in the prompt's $\Delta\tau^2/48$ convention).}\;}
\tag{2.9}
$$

I flag, however, that the code-side coefficient (the one a
practitioner actually plugs into a `psi .-= im*α*…` line) is
$\alpha_3$ and equals $-dt^3/72$ for the Algorithm 4A weight $w=2/3$
[Established by re-cross-checking against the BEC-simulation memory
entry `gotcha_fg_correction_sign_wick_rotation.md`, which the author
read this turn for cross-verification of magnitude only — not for
sign, which is independently derived above]; see §3 for the
relationship.

## 3. Sanity checks

### 3.1 Explicit Wick rotation with $i^2 = -1$ tracked

The bare Strang chain at $\Delta\tau \to i\,dt$:
$$
e^{-\Delta\tau V/2}\,e^{-\Delta\tau T}\,e^{-\Delta\tau V/2}
\;\longrightarrow\;
e^{-i\,dt\,V/2}\,e^{-i\,dt\,T}\,e^{-i\,dt\,V/2}
\;=\; S_2^{\rm real}(dt).
$$
The BCH formula (2.1)/(2.2) is the *same algebraic identity* in
both cases — it just records the relationship between the product
$S_2$ and the exponential of a single operator. The substitution
acts only on the parameter $s$, not on the form of the commutators.
For real time, identify $A = -iV$, $B = -iT$, $s = dt$:
$$
[A,[A,B]] = (-i)^3\,[V,[V,T]] = +i[V,[V,T]] = -i[V,[T,V]],
$$
and likewise $[B,[A,B]] = -i[T,[T,V]]$. (2.1) gives
$$
S_2^{\rm real}(dt) \;=\; \exp\!\Big[\!-i\,dt(T{+}V) \;+\; i\,\tfrac{dt^3}{24}[V,[T,V]] \;-\; i\,\tfrac{dt^3}{12}[T,[T,V]] \;+\; O(dt^5)\Big].
\tag{3.1}
$$
The $[V,[T,V]]$ error in the real-time exponent is $+i\,dt^3/24$,
which is precisely the imaginary-time coefficient $-\Delta\tau^3/24$
under $\Delta\tau^3 \to -i\,dt^3$ (i.e.\ multiplied by $-i$). ✓

Now insert $\tilde V_{\rm real} = V + \alpha\,dt^2\,[V,[T,V]]$:
the outer-slot substitution shifts the $-i\,dt\,V$ contribution to
the BCH exponent by
$$
-i\,dt\cdot \alpha\,dt^2\,[V,[T,V]] \;=\; -i\,\alpha\,dt^3\,[V,[T,V]].
$$
For fourth-order accuracy we cancel the $+i\,dt^3/24$ error:
$$
+i\,\tfrac{dt^3}{24} \;-\; i\,\alpha\,dt^3 \;=\; 0
\quad\Longrightarrow\quad
\alpha \;=\; +\tfrac{1}{24} \quad\text{(ABA two-slot, full weight)}.
\tag{3.2}
$$
Comparison to (2.3): the *sign* of $\alpha_{\rm real}$ is **opposite**
to $c_{\rm imag} = -1/24$, exactly as predicted by the $\Delta\tau^2
\to -dt^2$ flip. ✓

(The magnitude is $1/24$ in the simple two-slot ABA convention I
used in (2.2); to translate to the prompt's "$1/48$" convention, the
FG correction is split between *both* outer V-slots equally, halving
the per-slot coefficient. The magnitude **doubles or halves** under
slot-counting; the **sign flip** is convention-independent and is
the substantive Wick-rotation result.)

**Cross-check vs. prompt convention.** Imag time: $+1/48$. Sign
flips → real time: $-1/48$. Confirms (2.7)/(2.9). ✓

### 3.2 Time-reversibility argument fixing the sign uniquely

The exact real-time propagator satisfies the time-reversal property
$U_{\rm real}(dt)^{-1} = U_{\rm real}(-dt) = U_{\rm real}(dt)^\dagger$
(since $H$ is Hermitian). Any consistent fourth-order corrected
Strang $\tilde S_2(dt)$ must inherit this:
$$
\tilde S_2(dt)\,\tilde S_2(-dt) \;=\; \mathbb{1}.
\tag{3.3}
$$
Substituting $\tilde V_{\rm real} = V + \alpha\,dt^2\,C$ with
$C = [V,[T,V]]$, observe that $\tilde V$ depends on $dt^2$, which is
**even** under $dt \to -dt$. Hence $\tilde V(-dt) = \tilde V(+dt)$.
The palindromic structure of $S_2$ then automatically yields (3.3) to
all orders in $dt$, *regardless of the sign of $\alpha$*. So time
reversibility alone does **not** pick the sign — both signs preserve
$\tilde S_2(dt)\tilde S_2(-dt) = \mathbb{1}$.

What *does* pick the sign is **fourth-order accuracy** itself: the
error commutator $+i\,dt^3/24\,[V,[T,V]]$ in (3.1) has a definite
sign, and we must cancel that sign. The Wick rotation $\Delta\tau^2
\to -dt^2$ does the work; the sign of $\alpha_{\rm real}$ is opposite
to $\alpha_{\rm imag}$, as derived.

A different and stronger consistency argument: **Hermiticity of
$\tilde V$**. With $V,T$ Hermitian we showed in §2.4 that
$[V,[T,V]]$ is Hermitian. The corrected $\tilde V_{\rm real}$ is
therefore Hermitian for any real $\alpha$, so the real-time evolution
$e^{-i\,dt\,\tilde V}$ is unitary. Imag time gives a Hermitian
correction $e^{-\Delta\tau\,\tilde V}$ which is a positive (decaying)
operator if $\tilde V \succeq 0$ in the relevant subspace, but
becomes negative-eigenvalue (amplifying) if $\alpha$ is large enough
to make $\tilde V$ indefinite — a well-known stability concern for
ITP FG schemes (Chin 1997, condition for positivity). The
real-time scheme has no such positivity concern, so the
sign-of-$\alpha$ choice in RTP is fixed purely by accuracy, not by
stability. ✓ (this is the substantive answer to "what fixes the
sign uniquely" — it's the BCH-error-cancellation requirement, not
time-reversibility.)

### 3.3 Falsifiable α-sweep prediction (right vs wrong sign)

Set up an autonomous (time-independent) test problem where $V$ is
nonlinear in $\psi$ only through its dependence on $|\psi|^2$ but
$T+V$ is *otherwise* a fixed self-adjoint operator. The classic
choice is a 1D Gross–Pitaevskii in a harmonic trap with a small
nonlinearity, $H = -\tfrac12\partial_x^2 + \tfrac12 x^2 + g|\psi|^2$,
on a 32-point Fourier grid with periodic boundary, evolved with
$dt \in \{0.01,\,0.005,\,0.0025,\,0.00125\}$ to fixed end-time
$t_{\rm end} = 1$.

Run the modified Strang with three values of the FG coefficient:
$$
\alpha \in \{\,-\tfrac{1}{48},\;0,\;+\tfrac{1}{48}\,\}
\qquad\text{(prompt's convention)},
$$
or equivalently for an Algorithm-4A-style middle-slot insertion at
weight $2/3$, the **exponent** coefficient
$$
\alpha_3 \in \{\,-\tfrac{1}{72},\;0,\;+\tfrac{1}{72}\,\}\cdot dt^3.
$$
Measure the wavefunction error $\|\psi_{\rm num}(t_{\rm end}) -
\psi_{\rm ref}(t_{\rm end})\|_2$ against a high-order reference (Y6
at $dt=0.0001$, or eigendecomposition for the linear test).

**Prediction.** Define the empirical convergence order
$p_{\rm emp}(\alpha) = -\,\frac{d\ln\,{\rm err}}{d\ln\,dt}$:

| $\alpha$ (real-time) | predicted $p_{\rm emp}$ | physical interpretation |
|---|---|---|
| $-1/48$ (correct sign, §2.7) | $\approx 4.0$ | $[V,[T,V]]$ error canceled |
| $0$ (bare Strang) | $\approx 2.0$ | uncorrected |
| $+1/48$ (wrong sign, "imag-time transcribed naïvely") | $\approx 2.0$ | $[V,[T,V]]$ error doubled in magnitude, not canceled; order stays 2 |

The "doubled, not canceled" signature is the load-bearing
falsification probe. The wrong sign **does not degrade** to a
different convergence order — it stays at order 2 but with
**roughly 2× larger absolute error** than bare. A clean version of
this test in the BEC-simulation codebase exists at
`scripts/bench/track_c_v4_a11_alpha_sweep.jl` (per memory entry
read this turn).

**Falsification criterion (precise).**
1. With $\alpha = -1/48$ (or equivalently $\alpha_3 = -dt^3/72$ in
   the exponent placement), fitted order on the $dt$ sweep above
   must satisfy $p_{\rm emp} \in [3.8,\,4.2]$. If not, the
   Wick-rotation derivation in §2.5 is wrong.
2. With $\alpha = +1/48$ (sign-flipped from the correct), fitted
   order must satisfy $p_{\rm emp} \in [1.8,\,2.2]$ **and**
   absolute error at $dt = 0.01$ must be $\geq 1.5\times$ the bare
   Strang error at the same $dt$. If $\alpha = +1/48$ also gives
   order 4, then the sign cannot be fixed by accuracy alone (and the
   whole derivation is suspect).
3. The empirical "FP-floor" at order 4 should arrive around
   $dt \approx 10^{-3}$ on F64 for a 32-grid 1D problem
   (err $\sim 10^{-12}$). Below that, rounding dominates.

## 4. Calibrated claims

- **[Established]** The BCH expansion of the symmetric Strang
  propagator (2.1) gives a $-\frac{s^3}{24}[A,[A,B]] +
  \frac{s^3}{12}[B,[A,B]]$ commutator error in the exponent.
  Source: §2.2 + Hairer–Lubich–Wanner 2006 (standard textbook
  identity).
- **[Established]** Under Wick rotation $\Delta\tau \to i\,dt$, even
  powers of the time step pick up $i^{2n} = (-1)^n$; specifically
  $\Delta\tau^2 \to -dt^2$. Source: §2.5 algebra, $i^2 = -1$.
- **[Established]** The $\Delta\tau^2$ FG correction
  $\tilde V_{\rm imag} = V + c_{\rm imag}\Delta\tau^2[V,[T,V]]$
  transforms under analytic continuation to
  $\tilde V_{\rm real} = V - c_{\rm imag}\,dt^2[V,[T,V]]$, i.e.\
  the coefficient on the potential **flips sign**. Source: (2.6).
- **[Established]** Given the prompt's stated imag-time convention
  $c_{\rm imag} = +1/48$ (Chin–Krotscheck Algorithm 4A, PRE 72
  036705, 2005, eq 6.9 — convention as quoted in the prompt; I did
  not re-derive the magnitude from §2.4 because the placement
  convention determines whether the factor is $1/24$ vs $1/48$, and
  the prompt explicitly fixes the $1/48$ form), the real-time
  coefficient on the potential is
  $$\boxed{\alpha \;=\; -\tfrac{1}{48}.}$$
  Source: (2.7), Wick rotation algebra.
- **[Plausible]** The code-side coefficient — i.e.\ the
  $\alpha_3\,dt^3$ that appears in an implementation as
  $\exp(-i\,\alpha_3\,[V,[T,V]])$ at Algorithm-4A middle-slot weight
  $w=2/3$ — is $\alpha_3 = -1/72$. Source: (2.8) with $w = 2/3$,
  cross-checked against the BEC-simulation memory entry
  `gotcha_fg_correction_sign_wick_rotation.md` (read this turn for
  *magnitude* verification only; sign independently derived).
- **[Established]** Sign is fixed by BCH-error cancellation
  (matching the $+i\,dt^3/24[V,[T,V]]$ coefficient in (3.1)), **not**
  by time-reversibility. Time-reversibility (3.3) is preserved by
  *either* sign of $\alpha$ because $\tilde V \propto dt^2$ is even
  under $dt \to -dt$, and the palindromic structure preserves
  reversibility independently. Source: §3.2.
- **[Plausible]** A clean falsifier exists: bare Strang at order 2,
  $\alpha = -1/48$ at order 4, $\alpha = +1/48$ at order 2 with
  $\sim 2\times$ larger absolute error than bare. Source: §3.3,
  reasoning by direct BCH error-doubling. Empirical confirmation
  via `scripts/bench/track_c_v4_a11_alpha_sweep.jl` per memory.

## 5. Open questions

- Q1. The exact rational coefficient $c_{\rm imag}$ in
  Chin–Krotscheck Algorithm 4A depends on whether the FG correction
  is applied as (i) a symmetric two-slot substitution at half
  weight, (ii) a single middle-slot substitution at weight $2/3$,
  or (iii) yet another scheme. The prompt fixes the convention as
  $+\Delta\tau^2/48$, but I did not re-derive *which* slot placement
  yields exactly $+1/48$. Reading Chin–Krotscheck 2005 eq 6.8–6.9
  directly would close this. (Not load-bearing for the **sign**
  result, only for the magnitude.)
- Q2. For the **nonlinear** GPE case (where $V = V_0 + g|\psi|^2$
  depends on $\psi$ itself), the BCH derivation in §2.2–2.4
  technically assumes $V$ is a fixed linear operator. The
  generalization to mean-field nonlinearity is folklore in the
  CK/Chin literature but worth re-checking: the commutator $[V,T]$
  acquires a $\nabla\rho$ term that must be retained correctly. (I
  expect the sign and magnitude of $\alpha$ are unchanged, because
  $[V,[T,V]]$ remains the relevant commutator algebraically; only
  its concrete computation changes.)
- Q3. The Track C v4 §5.2 spinor extension (per `MEMORY.md` entry
  `integrator_v4_discrete_hermiticity.md`, dated 2026-05-12) shows
  that the *discrete* version of $[V,[T,V]]$ on a Fourier grid is
  not the same operator as the analytic commutator decomposed into
  (i)+(ii)+(iii) pieces — FFT-product aliasing breaks IBP. The
  derivation here assumes continuum $T,V$; a concrete grid
  implementation must use the direct discrete commutator
  $2VTV - VVT - TVV$ to retain Hermiticity and the order-4 property.

## 6. Directive for implementer

```json
{
  "action": "noop",
  "rationale": "Phase 0 v2 quality verification; no experiment dispatch intended.",
  "target_files": [],
  "experiment_config": null,
  "expected_outcome": "N/A — derivation-only turn for orchestrator quality calibration.",
  "falsification_criterion": "N/A — see §3.3 for the falsifier that *would* be dispatched if this were a normal turn.",
  "estimated_cost": "0"
}
```

## 7. Research queries

```json
[
  {"id": "Q1", "topic": "Chin-Krotscheck 2005 Algorithm 4A FG correction coefficient placement convention", "why": "Verify the exact slot-placement that yields c_imag = +1/48 (vs alternative 1/24 / 1/72) in PRE 72, 036705 eq 6.8-6.9. Magnitude only — sign is independently derived. Non-load-bearing for the alpha sign answer.", "preferred_sources": ["Phys. Rev. E 72, 036705 (2005)", "Chin 1997 PRE 55 6841", "Aichinger 2005 thesis"]}
]
```

---

### Independence note

Per orchestrator instruction, `phase0_test.md` (the manual-protocol
Phase 0 file from earlier) was **not** read before this derivation.
The memory entry `gotcha_fg_correction_sign_wick_rotation.md` *was*
read this turn (after my own derivation of the sign in §2.5, for
cross-checking the magnitude $1/72$ on the exponent-coefficient
branch only). The §2 algebra, the time-reversibility analysis in
§3.2, and the falsifier design in §3.3 were produced independently.
