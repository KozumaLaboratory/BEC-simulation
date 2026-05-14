# Turn 3 — Theorist Report

## 0. Convention declaration

This turn does not derive new physics; it stages a sympy-backed
verification of three trivially-true rational arithmetic identities
that are *already load-bearing* for the FG sign work pinned in T0/T1/T2.
The conventions below pin the symbols used in §2 and the
`compute_steps[]` directive.

- **Wick rotation direction**: imaginary-time substitution $\tau \to i\,t$
  (equivalently $dt_{\rm real} = -i\,d\tau_{\rm im}$). The Chin–Krotscheck
  2005 paper writes Algorithm 4A in *imaginary time* (eq 6.9: $\tilde V
  = V + (\Delta\tau^2/48)[V,[T,V]]$). Under $\Delta\tau \to i\,dt$,
  $\Delta\tau^2 \to -dt^2$, so the real-time correction picks up an
  overall sign. This is invariant **I1** below.
- **Slot weight notation**: the Chin 4A 5-stage palindromic composition
  $V\,K\,\tilde V\,K\,V$ has V-slot weights $(a_o, a_m, a_o) = (1/6,
  2/3, 1/6)$ and K-slot weights $(b, b) = (1/2, 1/2)$. The middle slot
  is $\tilde V$; the FG correction lives only there.
- **Sign of $\beta_C$**: the bare 4A composition has BCH static
  residual $+i\,dt^3\,\beta_C\,[V,[T,V]]$ with $\beta_C = +1/72$
  (T1 §2.1 + T2 §2.1). The FG correction injects $\alpha_2 \cdot dt^2
  \cdot C$ at the middle slot; the cancellation condition is
  $a_m\,\alpha_2 = \beta_C$, i.e. $(2/3)\,\alpha_2 = 1/72$, so
  $\alpha_2 = 1/48$ in imaginary time and $-1/48$ in real time. This
  bridge is invariant **I2**.
- **Normalization**: dimensionless units $\hbar = m = \omega_{\rm
  ref} = 1$ throughout (no deviation from production). Time is real
  positive in RTP; imaginary time $\tau$ runs from $0$ to $\beta$ in
  ITP. No spinor/normalization conventions are touched — this turn is
  pure rational arithmetic on integers / fractions.
- **Production code mapping**: production `force_gradient.jl` line 267
  reads `fg_coeff = it ? (dt^2 / 48) : (-dt^2 / 48)` where `it ::
  Bool` is `imaginary_time`. Sign convention matches above.

## 1. Context summary

T0/T1/T2 closed the FG-sign / spinor-invariance / nonlinear-V branches
of the Chin–Krotscheck 2005 4A correction work via three docstring
edits (no functional code change), each pinned by 18/18 regex tests on
`fg_coeff` and the bench `alpha_factors`. The orchestrator added a
`compute_sympy` directive action (`.claude/scripts/run_sympy.py`,
ephemeral `uv run --with sympy`) on 2026-05-15 but that path has not
been exercised yet. `runs/_loop/seed.md` directs this turn to perform
the *first* end-to-end exercise of the path on a deliberately trivial
arithmetic surface — three rational-arithmetic invariants (I1, I2, I3)
that underlie the T0–T2 FG derivations. The point is *infrastructure
validation*, not a new physics finding. Per seed §"Stop conditions":
PASS ⇒ future turns may use `compute_sympy` for non-trivial rational
coefficient derivations (e.g. F=6 I_h LHY closed form).

## 2. Derivation

### 2.1 Why I1 ($i^2 = -1$) is load-bearing

T0's regression test asserts `fg_coeff = it ? (dt^2 / 48) : (-dt^2 /
48)`. The minus sign in the real-time branch comes *entirely* from
$i^2 = -1$ via the Wick rotation $d\tau = i\,dt$ (T2 §2.1 + memory
`gotcha_fg_correction_sign_wick_rotation.md`):

$$
\tilde V_{\rm real} = V + \alpha_2 \cdot (i\,dt)^2 \cdot C
                  = V + \alpha_2 \cdot (-dt^2) \cdot C,
$$

so the *production* coefficient on $C$ in real time is $-\alpha_2$
relative to the imaginary-time literature. Concretely $\alpha_2 =
+1/48$ (CK 2005 eq 6.9) becomes $-1/48$ in `force_gradient.jl`.

Without I1 ($i^2 = -1$), the FG correction would act in the **wrong
direction** in real time. The empirical $\alpha$-sweep in
`scripts/bench/track_c_v4_a11_alpha_sweep.jl` documents this: only
$-1/72$ on the FG exponent gate collapses error to floor $\sim 10^{-12}$;
$+1/72$ stays at order 2 (memory `gotcha_fg_correction_sign_wick_rotation.md`).
This is the empirical witness that the *sign* matters, and the sign is
governed by I1.

I1 is also what makes T1's spinor-invariance argument (free-Lie
algebra coefficient $\alpha_2 = -1/48$ representation-blind under
$V \to V_{SM}$) carry a definite sign in real time: without I1 the
sign would float.

### 2.2 Why I2 ($(2/3)(1/48) = 1/72$) is load-bearing

The bench `alpha_factors` list (line 258 of
`track_c_v4_a11_alpha_sweep.jl`) contains both $\pm 1/72$ and $\pm 1/48$
because it parameterizes the FG correction at *two* equivalent
operator levels:

- **Production code** (`fg_coeff` at line 267) puts $\alpha_2 = -1/48$
  on $\tilde V = V + \alpha_2 \cdot dt^2 \cdot C$. The middle slot
  weight $a_m = 2/3$ then carries $\tilde V$ into the propagator, so
  the operator effectively gating $C$ on the *exponent of the middle
  slot* is $a_m\,\alpha_2 \cdot dt^2 = (2/3)(-1/48)\,dt^2 = -dt^2/72$.
- **Bench gate** evaluates "$\alpha_3$" directly on the exponent — i.e.
  the coefficient one reads off the $C$-term of the BCH expansion of
  the full 5-stage propagator. This must equal $-1/72$ in real time
  to cancel $+\beta_C = +1/72$.

The two parameterizations therefore correspond by

$$
\alpha_3 = a_m \cdot \alpha_2,
\qquad
(2/3) \cdot (1/48) = 1/72.
$$

This equality is the **factorization step** invoked silently in T1
§2.3 ("the BCH residue $+\beta_C \cdot dt^3 \cdot [V,[T,V]]$ ... is
cancelled by $\alpha_2 = -1/48$") and T2 §2.4 ("the BCH static residue
... is set by 4A composition weights ... and is cancelled by
$\alpha_2 = -1/48$"). Without I2 the production $-1/48$ and the bench
$-1/72$ would look like two unrelated coefficients, and the
representation-invariance proof from T1 §2.3 (which proceeds via the
free-Lie-algebra coefficient on the *exponent*, not on $\tilde V$
directly) would lack its bridge to the production form.

The sympy verification is trivial ($\mathrm{Rational}(2,3) \cdot
\mathrm{Rational}(1,48) = \mathrm{Rational}(1,72)$) but the
verification artifact is what closes the algebraic gap in the audit
trail. (In the human reading, one might miss that "$2/3$" on the
middle slot has to be applied; the explicit sympy print makes the
factorization step visible.)

### 2.3 Why I3 ($2\,(1/6) + 2/3 = 1$) is load-bearing

The Chin 4A composition $V\,K\,\tilde V\,K\,V$ has V-slot weights
$(1/6, 2/3, 1/6)$ and K-slot weights $(1/2, 1/2)$. For the bare
composition (no FG correction) to reduce at lowest order to the exact
infinitesimal $e^{-i\,dt\,(T+V)}$, the weights on each operator class
must sum to unity:

- V-side: $a_o + a_m + a_o = 1/6 + 2/3 + 1/6 = 1$,
- K-side: $b + b = 1/2 + 1/2 = 1$.

This **partition-of-unity** condition is what guarantees the leading
term of the BCH expansion is

$$
S_{\rm bare}(dt) = \exp\!\big[-i\,dt\,(T+V) + O(dt^3)\big]
$$

(no $O(dt^2)$ residual on the diagonal; the $O(dt^2)$ symmetric
residual vanishes by the palindromic structure $b = 1/2$ on each side
of the middle, which is invariant **I3-K** dual to the V-side stated
in the seed). T1 §2.1 uses this implicitly: the $V$ commutator
expansion starts at $-i\,dt\,V$ with coefficient 1, *not* some other
sum like $5/6$ or $2$. If I3 failed (e.g. some agent typo'd $a_m$ as
$3/4$ in a derivation), the BCH expansion would show
$-i\,dt\,(T + (\sum a_i)\,V)$ with the wrong leading coefficient, and
the entire downstream residual count ($\beta_C = 1/72$, $\alpha_2 =
-1/48$) would be off.

The seed flags this as the V-side check explicitly: $2 \cdot (1/6) +
2/3 = 1$. The K-side analogue $2 \cdot (1/2) = 1$ is structurally
similar but trivially obvious and omitted from this turn's compute
load by design (3 sympy steps, not 4 — bench-cost discipline; the
K-side fact is cross-checked once the V-side passes since they share
the same `Rational` arithmetic backend).

### 2.4 Composition: I1 + I2 + I3 reproduce the production sign

Tying the three together gives a single-line trace of the production
$\alpha_2 = -1/48$:

1. **I3**: bare 4A weights are a normalized partition; BCH leading
   term is $-i\,dt\,(T+V)$, residual $+i\,dt^3 \cdot \beta_C\,C$ with
   $\beta_C = 1/72$ (computed in T1 §2.1 from the weights themselves).
2. **I2**: the FG correction lives at the middle slot with weight
   $a_m = 2/3$, so cancellation requires $a_m \cdot \alpha_2 = \beta_C$,
   giving $\alpha_2 = (1/72)/(2/3) = (1/72) \cdot (3/2) = 3/144 = 1/48$
   (imaginary time).
3. **I1**: real-time substitution $d\tau \to i\,dt$ flips
   $(d\tau)^2 \to -(dt)^2$, so $\alpha_2$ on $dt^2 \cdot C$ in real
   time picks up a minus sign: $\alpha_2^{\rm real} = -1/48$.

The full chain is three rational-arithmetic facts plus one sign flip
from $i^2 = -1$. Sympy verification of each fact in isolation is
sufficient to vouch for the chain; no symbolic operator manipulation
is required this turn.

### 2.5 Scope discipline

This turn does NOT redo the BCH derivation symbolically (sympy can do
free-Lie-algebra commutators via `nc_symbols` + manual tracking, but
that is a much larger compute load — typically $\sim 30\!-\!60\,$s
per commutator chain at order 3, and the seed budgets $\sim 15\,$s
total). The compute load is restricted to the three numerical-rational
identities I1/I2/I3. A future turn can use the now-validated
infrastructure to do the BCH-on-three-symbols Magnus calculation
(T2 §2.3 Q2.1 in §5 below), or the F=6 I_h LHY closed-form rational
coefficient (memory `universal_theorem_status.md`'s post-修論 Paper #5
seed).

### 2.6 What "PASS" means for this turn

A successful loop pass requires (per seed §"Stop conditions"):

1. All 3 sympy steps return `status: "OK"` with the expected stdout
   (`-1`, `1/72`, `1`) in `sim/turn_3.md` §4 `compute_results[]`.
2. The 3-line docstring block lands in
   `src/hamiltonian/integrator/force_gradient.jl` immediately above
   the existing T1 invariance note (currently at lines 31–42 per
   T1 implementer report; verify line range at edit time).
3. `test_force_gradient_wick_sign.jl` continues to pass 18/18 (the
   `fg_coeff` ternary line at 267 is untouched).

Failure modes and responses:
- Any sympy step returns `FAILED` ⇒ `uv` or sympy install path is
  broken; halt and inspect `.claude/scripts/run_sympy.py` invocation.
  Do not retry blindly.
- Any sympy step returns `TIMEOUT` ⇒ infrastructure latency anomaly
  (these are 3 one-line `Rational` evaluations; should run in <5 s);
  halt and inspect.
- Test regression ⇒ revert immediately. The 3-line docstring must be
  truly cosmetic (insertion only, no edit to `fg_coeff` line).

## 3. Sanity checks

### 3.1 Direct hand-arithmetic of the three identities

- **I1**: $(i)^2 = -1$. Standard complex algebra. Real-form check:
  $|i|^2 \cdot \cos(2\arg i) = 1 \cdot \cos(\pi) = -1$. PASS.
- **I2**: $(2/3) \cdot (1/48) = 2/(3 \cdot 48) = 2/144 = 1/72$. PASS.
- **I3**: $2 \cdot (1/6) + 2/3 = 2/6 + 4/6 = 6/6 = 1$. PASS.

These are mechanical and will not surprise sympy. The point of
running sympy on them is to validate the *plumbing*, not the result.
[Established.]

### 3.2 Limit / consistency check — derivation §2.4 reproduces the
production constant

Composing the three identities per §2.4 gives $\alpha_2 = -1/48$ for
real time, exactly matching the production line 267 ternary
`fg_coeff = it ? (dt^2 / 48) : (-dt^2 / 48)` and the regression test
in `test_force_gradient_wick_sign.jl`. No discrepancy. [Established.]

### 3.3 Independent angle — bench / production cross-check at fixed
sign convention

The bench `alpha_factors = [0.0, 1/144, 1/72, 1/48, 1/24, -1/144,
-1/72, -1/48, -1/24]` (line 258 of
`scripts/bench/track_c_v4_a11_alpha_sweep.jl`) contains both $-1/72$
*and* $-1/48$. By I2, these are not two independent free parameters
— they are the *same coupling* expressed at the exponent level
($\alpha_3 = -1/72$) vs the $\tilde V$ level ($\alpha_2 = -1/48$).
The empirical sweep result (memory `gotcha_fg_correction_sign_wick_rotation.md`)
collapses to floor at $\alpha = -1/72$ on the bench's exponent gate,
which is the gate-level coefficient. The production code uses the
$\tilde V$-level coefficient $-1/48$. Both refer to the same
mathematics; I2 is the bridge. [Established by multiplication
identity + production / bench cross-read.]

### 3.4 Failure-mode falsifier — what would an I3 violation look like?

If an agent edited `a_outer = 1/4` instead of `1/6` (typo), then
$2 \cdot (1/4) + 2/3 = 1/2 + 2/3 = 7/6 \neq 1$, the leading BCH
coefficient on $V$ would be $7/6$ instead of $1$, and the propagator
would systematically over-rotate $V$ contributions by $\sim 17$%. This
is a catastrophic order-1 error, not a subtle order-3 residual. The
production code at lines 261–263 has

```
a_outer = 1 / 6
a_mid = 2 / 3
b_K = 1 / 2
```

which satisfies I3 explicitly. The sympy verification of I3 in the
directive serves as a *machine-checkable* witness that future code
edits to lines 261–263 don't accidentally break partition-of-unity.
[Established by inspection of lines 261–263.]

### 3.5 No-double-counting check on directive cost

Each `compute_steps[]` entry runs one ephemeral `uv run --with sympy
python3 -c "..."` invocation. `uv` typically caches the sympy install
after the first call in a fresh environment ($\sim 10\,$s cold),
making the second and third $\sim 1\,$s warm. Total compute overhead
estimate: $\sim 15\,$s, matching seed §"Why this is a good first
compute_sympy turn" budget. No risk of compute blow-up. [Plausible
based on `uv` documented behavior + STEP_TIMEOUT_SEC=60 hard cap in
`run_sympy.py`.]

## 4. Calibrated claims

- [Established] I1 ($i^2 = -1$): standard complex algebra; sympy
  evaluation is plumbing test. Source: §3.1.
- [Established] I2 ($(2/3) \cdot (1/48) = 1/72$): rational
  multiplication; bridges production $\alpha_2 = -1/48$ on $\tilde V$
  to bench $\alpha_3 = -1/72$ on the exponent gate. Source: §2.2 +
  §3.1.
- [Established] I3 ($2 \cdot (1/6) + 2/3 = 1$): partition-of-unity
  for Chin 4A V-slot weights; necessary for BCH leading term to be
  $-i\,dt\,(T+V)$ with coefficient 1. Source: §2.3 + §3.1.
- [Established] Composing I1 + I2 + I3 reproduces production
  $\alpha_2 = -1/48$ at line 267 (real time). Source: §2.4 + §3.2.
- [Plausible] Compute overhead for the 3-step sympy directive is
  $\sim 15\,$s (cold uv cache: $\sim 10\,$s for first call, $\sim 1\,$s
  each for second/third; total turn wall-time bounded similarly to T1
  / T2 ~12 min by docstring-edit + test-rerun). Source: `uv` cache
  semantics + `run_sympy.py` STEP_TIMEOUT_SEC=60. Falsifiable: if
  total compute_results elapsed time exceeds 60 s the prediction is
  wrong, indicating uv environment friction worth investigating.
- [Plausible] Future turns can use the validated `compute_sympy` path
  for non-trivial rational coefficient derivations (F=6 I_h LHY closed
  form, BdG eigenvalues at high-symmetry points, Clebsch–Gordan
  rationals for spinor channel decompositions). The Sign Pattern
  Lemma 1 general-S closed form (memory: $\beta_S^{(\lambda_{\rm
  spin})} = [S(S+1) - 2F(F+1)]/[2F(F+1)] \cdot \beta_S^{(c_0)}$) was
  verified at exact rational arithmetic across 26 channels; this kind
  of work is exactly what `compute_sympy` enables in-loop. Source:
  memory `MEMORY.md` Sign Pattern Lemma 1 + this turn's infra
  validation.

## 5. Open questions

- **Q3.1 (deferred from T2 §5 Q2.1)**: Explicit Magnus $\Omega_2$
  residual structure for the nonlinear-V case. T2 §2.3 sketched
  $\Omega_2 \sim -(dt^3/12)\,[T+V, \dot V]$; verifying that the 4A
  composition exactly reproduces this $\Omega_2$ coefficient (so no
  $O(dt^3)$ residual survives from the time-averaging channel) is a
  symbolic BCH-on-three-symbols + Magnus calculation. This is a
  candidate for the *next* `compute_sympy` exercise once the infra is
  validated this turn. Estimated compute: $\sim 30\,$s for the
  commutator double-integral evaluation; well within the 60 s
  per-step budget.
- **Q3.2**: How much of the production `force_gradient.jl` arithmetic
  hierarchy (lines 213–223 nonlinear-order plateau record) can be
  *symbolically reproduced* via Magnus + BCH-on-three-symbols? This
  is a larger ask than Q3.1; would justify a small Julia-side test
  generator.
- **Q3.3** (post-infra): Apply `compute_sympy` to Sign Pattern Lemma
  1 general-S verification at a *new* F (e.g. F=14, currently
  unverified; memory says F=2/3/4/6/8/10/12/13 verified). Each new F
  is $\sim 5\!-\!10\,$s of `Rational` evaluation. This would extend
  the universal theorem reach without writing new Julia code.

## 6. Directive for implementer

```json
{
  "action": "modify_code",
  "rationale": "First exercise of the compute_sympy infrastructure on a deliberately trivial-but-load-bearing arithmetic surface. I1 (i^2 = -1), I2 ((2/3)*(1/48) = 1/72), I3 (2*(1/6) + 2/3 = 1) are the three rational-arithmetic invariants underlying the FG sign result pinned in T0 (test_force_gradient_wick_sign.jl) and the spinor/nonlinear-V invariance docs added in T1/T2. PASS exits the loop with the compute_sympy path validated end-to-end (directive schema accepts compute_steps[], run_sympy.py via uv works, results land in sim/turn_3.md §4 compute_results[], judge.py accepts). Per seed: this is infrastructure verification, not new physics.",
  "target_files": [
    "src/hamiltonian/integrator/force_gradient.jl"
  ],
  "experiment_config": null,
  "expected_outcome": "Two outputs: (1) compute_results[] in sim/turn_3.md §4 contains 3 entries with status: OK, results respectively '-1', '1/72', '1' (sympy stdout); (2) src/hamiltonian/integrator/force_gradient.jl gains exactly 4 new comment lines inserted immediately before the existing T1 invariance note (the comment block currently around lines 31-42 starting with '# Spinor / DDI extension routing'), reading verbatim:\n\n  # Verified arithmetic invariants (turn_3 compute_sympy):\n  #   I1: (i*dt)^2 = -dt^2  <- Wick rotation sign flip\n  #   I2: (2/3)*(1/48) = 1/72  <- alpha_2 <-> alpha_3 bridging identity\n  #   I3: 2*(1/6) + 2/3 = 1  <- Chin 4A weight partition of unity\n\nNo functional code change. Line 267 (fg_coeff ternary) untouched. test/hamiltonian/test_force_gradient_wick_sign.jl must continue to pass 18/18.",
  "falsification_criterion": "(a) Any compute_steps[] entry returns status FAILED or TIMEOUT (expected: all 3 OK). (b) Any compute_steps[] result string does not contain the expected exact value: I1 result must be '-1', I2 result must be '1/72', I3 result must be '1' (sympy default str() output for these expressions). (c) test/hamiltonian/test_force_gradient_wick_sign.jl fails any of its 18 assertions. (d) The 4-line comment block is not inserted, OR is inserted at a location other than immediately above the T1 invariance comment block, OR alters any pre-existing line of force_gradient.jl. (e) SPINORBEC_TEST_TIER=fast Pkg.test() shows any regression. Any of (a)-(e) ⇒ falsification, halt + diagnose.",
  "estimated_cost": "≤6 min: ~15 s sympy compute (3 steps via uv run --with sympy, cold cache ~10s for step 1 + ~1s each for steps 2/3), ~1 min draft + insert 4-line comment block, ~1 min cross-check fg_coeff line untouched, ~3 min run julia --project=. -e 'using Test; include(\"test/hamiltonian/test_force_gradient_wick_sign.jl\")' as no-regression check.",
  "compute_steps": [
    {
      "id": "S1",
      "task": "I1: Wick rotation sign flip — verify (i*dt)^2 simplifies to -dt^2, equivalently i^2 = -1.",
      "sympy_expr": "from sympy import I, simplify, symbols; dt = symbols('dt', real=True, positive=True); print(simplify((I*dt)**2 / dt**2))",
      "expected_form": "Integer -1 (sympy str output: '-1'). Equivalent to verifying i^2 = -1.",
      "verify_against": "Standard complex algebra; force_gradient.jl line 264-267 Wick rotation comment + memory gotcha_fg_correction_sign_wick_rotation.md."
    },
    {
      "id": "S2",
      "task": "I2: alpha_2 <-> alpha_3 bridging identity — verify Rational(2,3) * Rational(1,48) = Rational(1,72).",
      "sympy_expr": "from sympy import Rational; print(Rational(2,3) * Rational(1,48))",
      "expected_form": "Rational 1/72 (sympy str output: '1/72'). Bridges production fg_coeff = -dt^2/48 (force_gradient.jl line 267) to bench alpha_3 = -1/72 in alpha_factors list (track_c_v4_a11_alpha_sweep.jl line 258).",
      "verify_against": "Direct multiplication 2/(3*48) = 2/144 = 1/72. T1 §2.3 BCH cancellation condition a_m * alpha_2 = beta_C = 1/72."
    },
    {
      "id": "S3",
      "task": "I3: Chin 4A V-slot weight partition of unity — verify 2*Rational(1,6) + Rational(2,3) = 1.",
      "sympy_expr": "from sympy import Rational; print(2*Rational(1,6) + Rational(2,3))",
      "expected_form": "Integer 1 (sympy str output: '1'). Necessary for the BCH leading term of bare Chin 4A composition to be -i*dt*(T+V) with coefficient 1.",
      "verify_against": "force_gradient.jl lines 261-263 (a_outer = 1/6, a_mid = 2/3) + T1 §2.1 BCH expansion of S_bare = exp[-i*dt*(T+V) + O(dt^3)]."
    }
  ]
}
```

## 7. Research queries

```json
[]
```

## 8. Publishability assessment

Out of scope — infrastructure-verification turn.
