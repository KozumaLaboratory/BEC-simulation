# §3.7 State-averaging fails generically across frameworks — narrative draft

**Status**: draft, 2026-05-11. Consolidates §3.3.2 + Force-Gradient v3
state-avg midpoint negative + parallels with MPS-4 multi-scale failure.

## §3.7.1 Motivation

Track A1.5 (Track C v3 attempt 1) and §3.3.2 in the Ch.3 framework all
flagged state-averaging — using `(ψⁿ + ψⁿ⁺¹)/2` as the mean-field source
for an integrator's potential evaluation — as a recurrent failure mode.
This section consolidates the finding across frameworks and shows that
the failure has a common formal structure.

## §3.7.2 The state-averaging operation

For a wavefunction ψ propagated by a linear (or linearised) Hamiltonian
H over time τ:

$$\frac{\psi^n + \psi^{n+1}}{2} = \frac{\psi^n + e^{-iH\tau}\psi^n}{2}
= \psi^n \cdot \frac{1 + e^{-iH\tau}}{2}
= \psi^n \cdot \cos(H\tau/2) \cdot e^{-iH\tau/2}$$

The state-average differs from the true midpoint $\psi^n e^{-iH\tau/2}$
by a factor $\cos(H\tau/2)$. Taylor expansion:

$$\cos(H\tau/2) = 1 - \frac{(H\tau)^2}{8} + \frac{(H\tau)^4}{384} - \cdots$$

The leading correction is **even-power-in-τ**: $-(H\tau)^2/8$.

## §3.7.3 Why even-power corrections break high-order recovery

High-order splitting / composition methods (Yoshida, MPS, modified
splitting) rely on the **odd-only** Taylor structure of the local error
of their symmetric base step:

$$S(\tau) = e^{-iH\tau} + a_3 \tau^3 + a_5 \tau^5 + \cdots$$

(No even-power terms when the base step is exactly time-reversal
symmetric.)

The Richardson/composition coefficients are designed to cancel the odd
powers: e.g., MPS-4 cancels $a_3 \tau^3$ via $T_4(h) = (4/3)S(h/2)^2
- (1/3)S(h)$. Yoshida-4 cancels $a_3$ via its 4-stage composition.

If the base step has **even-power** error contamination — from
state-averaging or from non-uniform MF evaluation — the Richardson
coefficients cannot cancel them. The composed method's order drops.

## §3.7.4 Three failure-mode instances

Three concrete instances of this generic failure mode are documented
in our framework:

### §3.7.4.a MPS-4 multi-scale (Track A failure, §3.3.1)

$T_4(h) = (4/3)\,S(h/2)^2 - (1/3)\,S(h)$ evaluates the midpoint MF at
*different time scales* in the two terms:
- $S(h)$ uses one midpoint at half of duration $h$ (= $h/2$)
- $S(h/2)^2$ uses two midpoints, one at $h/4$ and one at $3h/4$

The two scales don't correspond to the same point on the true solution
trajectory, so the implicit MF evaluations are not synchronised. The
resulting V step has a residual $\tau^2$ error that survives the
Richardson coefficient combination.

Verified empirically: MPS-4 on lab-path Rb87 collapses to order ~1 even
with the v3.1 Track A1 midpoint scheme (commit 0b0a822 bench).

### §3.7.4.b AVF state-averaged trap (Track A1.5 negative)

Predictor-corrector V step with MF source $(ψ_n + ψ_{n+1})/2$ (Picard
on $ψ_{n+1}$). Linear-H analysis: state-average differs from true
midpoint by $\cos(Hτ/2)$ factor with leading $-(Hτ)^2/8$ correction
— even-power. Yoshida-4 composition with this base step degrades from
order 4 to order 2 (verified, commit 63ad7c1).

Phase 5 long-time consequence: energy drift 14万× worse than
Y4-midpoint due to order-2 leading constant amplifying over time.

### §3.7.4.c Force-Gradient v3 state-avg midpoint Picard (Track C)

Attempt to refine Force-Gradient midpoint MF via state-avg Picard
update $(ψ_n + ψ_{n+1})/2$ → REPRODUCED the AVF failure mode INSIDE the
Force-Gradient framework: order 2.92 (p=1, Strang predictor) → 2.00
(p=2, state-avg Picard). The cos(Hτ/2) bias is path-independent; it
breaks order recovery regardless of which 4th-order scheme it's
plugged into.

Verified in commit 0b0a822 bench. Subsequently disabled in
`split_step_forcegrad!` (commit 0b0a822); state-avg midpoint update is
NOT used by default.

## §3.7.5 Common formal structure

All three failures share:
1. A high-order scheme designed for odd-only τ expansion (MPS,
   Yoshida, modified splitting all rely on this).
2. A mid- or end-point MF estimation method that introduces an
   even-power $τ^2$ contamination.
3. Picard iteration on the contaminated estimate does NOT save the
   scheme — at fixed point, the cos(Hτ/2) bias persists.

The fix in each case: **avoid state-averaging entirely**. Use either:
- A Strang half-step predictor (Track A1 midpoint Picard): O(τ²)
  accurate but biased *odd-only*, so Yoshida composition recovers
  order 4.
- Implicit midpoint via iterative Strang re-prediction (Force-Gradient
  v3.1): same bias structure, no even-power contamination, but capped
  at predictor's structural order.
- True implicit midpoint with reflection $ψ_{n+1} = 2ψ_{mid} - ψ_n$:
  exactly midpoint-symmetric but destroys the operator-splitting
  structure (= different scheme entirely).

## §3.7.6 Theorem (informal): state-averaging is path-independently bad

**Claim**: For any high-order splitting/composition method whose order
recovery relies on odd-only Taylor cancellation, using state-averaging
`(ψⁿ + ψⁿ⁺¹)/2` as the mean-field source for the implicit midpoint
introduces an $O(τ^2)$ even-power contamination that the method cannot
absorb. The resulting global order drops to at most 2 regardless of
the nominal high-order construction.

Verified instances:
- MPS-4 with state-avg MF (≡ multi-scale Picard fixed point):
  order ~1 (Track A §3.3.1)
- Yoshida-4 over AVF state-avg trap: order 2 (§3.3.2)
- Force-Gradient + Picard on state-avg midpoint: order 2 (this section)

The theorem suggests that state-averaging is structurally incompatible
with the high-order splitting/composition framework on the lab path,
not specific to any particular method.

## §3.7.7 Implications for thesis Ch.3 + future work

State-averaging negative is a **load-bearing finding** for the thesis:

- It explains the systematic failure of MPS-4, AVF, and naive
  Force-Gradient Picard refinements
- It justifies the Y4-midpoint design choice (= predictor-corrector
  with Strang half-step, NOT state-avg)
- It is novel — neither Chin-Krotscheck 2005 nor Thalhammer 2026
  flags this explicitly; the joint negative result requires testing
  all three frameworks side-by-side

Future work direction: a formal proof of the §3.7.6 theorem for
general nonlinear $H[\psi]$ with bounded derivatives. Currently
the proof is empirical (three test instances on the lab path) plus
the linear-H Taylor argument for the cos(Hτ/2) bias.

## §3.7.8 §3.7 summary

State-averaging `(ψⁿ + ψⁿ⁺¹)/2` is a **generic anti-pattern** in
high-order splitting frameworks. It produces an $O(τ^2)$ even-power
bias that the framework's odd-only Richardson/composition coefficients
cannot remove. Documented in three distinct contexts (MPS-4, AVF
trap, Force-Gradient Picard) on the SpinorBEC lab path, all reducing
to the same formal mechanism.

This §3.7 plus §3.3 (Richardson cancellation fragility framework) plus
§3.5/§3.6 (Force-Gradient + modified splitting derivation) together
provide the **negative result + positive theorem + framework
unification** structure that anchors thesis Ch.3.
