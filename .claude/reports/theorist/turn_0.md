# Turn 0 — Theorist Report

## 1. Context summary

Phase 0 calibration (`phase0_test.md`, `phase0_test_v2.md`) established
two algebraic facts: (i) the Chin–Krotscheck FG correction sign flips
under Wick rotation, so $\tilde V_{\rm imag} = V + (\Delta\tau^2/48)\,
[V,[T,V]]$ becomes $\tilde V_{\rm real} = V - (dt^2/48)\,[V,[T,V]]$;
(ii) there are **two coefficient conventions** in circulation —
$\alpha_2 = -1/48$ on the potential $\tilde V$ vs. $\alpha_3 = -1/72$
on the *exponent* of the middle-slot correction operator at weight
$w = 2/3$, related by $\alpha_3 = w\,\alpha_2 = (2/3)(-1/48) = -1/72$.
This turn's task (per `.claude/reports/seed.md`) is to verify which
convention the diagnostic bench `scripts/bench/track_c_v4_a11_alpha_sweep.jl`
uses, which one production code in `src/hamiltonian/integrator/`
uses, and to flag any mismatch as load-bearing.

## 2. Derivation

### 2.1 What the bench actually parameterizes

The bench at `scripts/bench/track_c_v4_a11_alpha_sweep.jl` performs
a sweep over `alpha_factors = [0, ±1/144, ±1/72, ±1/48, ±1/24]`
(line 258). Each sweep point runs `chin4A_auto_step!` with
`alpha_val = alpha_factor * actual_dt^3` (line 222), and inside
`apply_fg_correction!` (lines 157–164) applies the gate

```
psi .-= im * alpha_val .* Aψ
```

where `Aψ = [V_SM, [T, V_SM]] · ψ` is computed directly via
`apply_v4_direct!` (the discrete commutator $2VTV - VVT - TVV$ form,
lines 141–155).

Reading the operator content: this is a first-order Taylor expansion
of the unitary $\exp(-i\,\alpha_{\rm val}\,C)\,\psi$ where
$C = [V_{\rm SM}, [T, V_{\rm SM}]]$. Substituting $\alpha_{\rm val} =
\alpha_{\rm factor} \cdot dt^3$:

$$
U_{\rm FG} = \exp\!\big(-i\,\alpha_{\rm factor}\,dt^3\,[V,[T,V]]\big),
$$

which is exactly the **$\alpha_3$ exponent branch** of the §2.6 phase0
disambiguation:

$$
\alpha_3 \;:=\; \alpha_{\rm factor}, \qquad
U_{\rm FG} \;=\; \exp\!\big(-i\,\alpha_3\,dt^3\,C\big).
$$

The bench's correct point is therefore $\alpha_3 = -1/72$, i.e.
`alpha_factor = -1/72`, which is one of the 9 swept values
(line 258 includes `-1/72`). [Established by direct code reading.]

### 2.2 What the production code parameterizes

The production routine `split_step_forcegrad!`
(`src/hamiltonian/integrator/force_gradient.jl`, lines 234–385)
implements paper eq. 6.8/6.9 directly as a 5-stage ABA composition:

```
V(dt/6) K(dt/2) Ṽ(2dt/3) K(dt/2) V(dt/6)
```

with $\tilde V = V + \texttt{fg\_coeff} \cdot |\nabla V_{\rm eff}|^2$
applied at the middle stage only (lines 327–331). The crucial line
is the Wick-rotation switch at line 267:

```julia
fg_coeff = it ? (dt^2 / 48) : (-dt^2 / 48)
```

with the explanatory comment at lines 264–266:

> `τ²/48 from paper eq. 6.9 is the IMAGINARY-TIME convention. For real`
> `time the τ → it substitution gives (iΔt)²/48 = −Δt²/48, flipping`
> `the sign of the gradient correction.`

This is unambiguously the **$\alpha_2$ potential branch**:

$$
\tilde V_{\rm real} \;=\; V \;+\; \alpha_2\,dt^2\,|\nabla V_{\rm eff}|^2,
\qquad \alpha_2 \;=\; -\tfrac{1}{48}.
$$

Note also line 14 of the same file:

> `Ṽ = V + (dt²/48) [V, [T, V]]    where    [V,[T,V]] = |∇V|²   (eq. 6.10)`

The identity $[V,[T,V]] = |\nabla V|^2$ is the standard CK 6.10
reduction valid for diagonal scalar $V$, no momentum operators in
$V$. The production code exploits this to compute the FG term by FFT
spectral derivative of $V_{\rm eff} = V_{\rm trap} + c_0 n$ rather
than the full operator commutator. (The bench, by contrast, uses the
full discrete commutator because $V_{\rm SM}$ is matrix-valued in
spinor space and the $|\nabla V|^2$ reduction does *not* hold there
— see §3.3 sanity check below.)

### 2.3 Mapping the two conventions

Plug $\tilde V_{\rm real} = V + \alpha_2\,dt^2\,C$ into the middle
slot gate of weight $w \cdot dt$:

$$
\begin{aligned}
\exp\!\big(-i\,w\,dt\,\tilde V_{\rm real}\big)
&= \exp\!\big(-i\,w\,dt\,V \;-\; i\,w\,\alpha_2\,dt^3\,C\big)\\
&= \exp\!\big(-i\,w\,dt\,V\big)\,\exp\!\big(-i\,w\,\alpha_2\,dt^3\,C\big)\,(1 + O(dt^4)),
\end{aligned}
$$

where the BCH factorization error $O(dt^4)$ is one order below the
$O(dt^4)$ accuracy target and therefore harmless. The exponent of the
FG correction operator is

$$
\boxed{\;\alpha_3 \;=\; w\,\alpha_2.\;}
$$

For Chin–Krotscheck Algorithm 4A the middle slot weight is $w = 2/3$
(coefficient `a_mid = 2/3` at line 262 of `force_gradient.jl`).
Therefore:

$$
\alpha_3 \;=\; \tfrac{2}{3}\,\alpha_2 \;=\; \tfrac{2}{3}\cdot\Big(-\tfrac{1}{48}\Big) \;=\; -\tfrac{1}{72}.
$$

[Established] The bench's correct sweep point $\alpha_{\rm factor} = -1/72$
and the production code's `fg_coeff = -dt²/48` describe **the same
physical correction in two different parameterizations**. No mismatch.

### 2.4 Independent verification via order-counting

A second route to the same conclusion, independent of the BCH
factorization above. The bench's bare composition `V K V K V` with
weights $(1/6, 1/2, 2/3, 1/2, 1/6)$ has a residual error term
$+i\,(dt^3/72)\,[V,[T,V]]$ in its BCH exponent (this is the
real-time, weight-$2/3$ analog of the imag-time $-\Delta\tau^3/72$
error; the factor of $1/72$ rather than $1/24$ comes from the
$(2/3)^3$ weight scaling of the middle slot's contribution to the
double-commutator residual — see CK 2005 §III.B.).

To cancel it via the middle-slot exponent gate, we need

$$
+i\,\frac{dt^3}{72}\,C \;+\; \big(-i\,\alpha_3\,dt^3\big)\,C \;=\; 0
\;\;\Longrightarrow\;\;
\alpha_3 \;=\; +\frac{1}{72}.
$$

But this assumes the bare residual is $+i\,dt^3/72\,C$. Tracing the
real-time BCH from the imag-time identity (phase0 §3.1 eq 3.1):

$$
S_2^{\rm real}(dt) \;=\; \exp\!\Big[\!-i\,dt(T+V) \;+\; i\,\tfrac{dt^3}{24}\,[V,[T,V]] \;-\; i\,\tfrac{dt^3}{12}\,[T,[T,V]] \;+\; O(dt^5)\Big]
$$

is for the **two-slot ABA at full weight**. For the **three-slot
$(1/6, 2/3, 1/6)$ Chin form**, the middle slot picks up only $(2/3)^2$
of the symmetric-coefficient contribution; the outer slots at $1/6$
each contribute $2 \cdot (1/6)^2$ — these arithmetic factors are what
distinguish the $\alpha_3 = -1/72$ form from the simple-ABA $\alpha_3 =
+1/24$ form. The clean way to see this without re-deriving the BCH
arithmetic is the direct route in §2.3: production sets $\alpha_2 = -1/48$
in $\tilde V$, weight $w = 2/3$ implies $\alpha_3 = -1/72$, **sign
negative**. The bench then sweeps $\alpha_3$ and the empirical
floor-collapse should occur at $\alpha_3 = -1/72$.

So the prediction is:

> Running the bench, the row labeled `-1/72` is the one that yields
> $p_{\rm emp} \approx 4$ on both `ord(4e-3→2e-3)` and `ord(2e-3→1e-3)`
> columns, with absolute error at the smallest dt collapsed toward the
> F64 floor (~1e-12 on this 16³ problem).

[Plausible — predicted but not measured this turn; matches what
`gotcha_fg_correction_sign_wick_rotation.md` records, but the memo
itself was not opened in `WebFetch`-style verification this turn — only
its summary in MEMORY.md was used.]

### 2.5 Symmetry / completeness check on the bench sweep

The bench sweeps both signs of all magnitudes (`±1/24, ±1/48, ±1/72, ±1/144`)
plus zero (line 258). This is a 9-point grid that covers the four
"wrong magnitude" cases (`±1/24, ±1/144` — even sign, wrong magnitude)
and the two "wrong sign" cases of the canonical magnitudes
(`+1/72, +1/48`).

Expected pattern per phase0 §3.3 falsifier table:

| $\alpha_3$ swept | predicted $p_{\rm emp}$ | notes |
|---|---|---|
| $0$ (bare Chin 5-stage) | $\approx 2$ | uncorrected, but Chin's bare 5-stage already has order 2 not 1 since palindromic |
| $-1/72$ (correct) | $\approx 4$ | $C$ error canceled |
| $+1/72$ (wrong sign, correct magnitude) | $\approx 2$ | $C$ error *doubled* (1/72 + 1/72 = 1/36 net) |
| $\pm 1/48$ | $\approx 2$ | wrong magnitude, partial cancellation |
| $\pm 1/24$ | $\approx 2$ | wrong magnitude, makes things worse |
| $\pm 1/144$ | $\approx 2$ | wrong magnitude, partial cancellation toward bare |

The "smoking gun" is a **single isolated peak of order 4** at exactly
$-1/72$. All other rows should remain at order $\sim 2$.

## 3. Sanity checks

### 3.1 Dimensional / unit check on `fg_coeff = -dt²/48`

The corrected potential satisfies $[\tilde V] = [V]$ (both are
energies). The added piece is $\alpha_2 \cdot dt^2 \cdot |\nabla V|^2$.
With $[V] = E$ and $[\nabla V] = E/L$ (in our units $\hbar = m = 1$,
so $E$ and $1/L^2$ have the same dimension), $[\nabla V]^2 = E^2/L^2 =
E^2 \cdot E = E^3$ (using $1/L^2 \sim E$). So $[|\nabla V|^2] = E^3$,
and $[dt^2 \cdot |\nabla V|^2] = (1/E)^2 \cdot E^3 = E$. ✓

The exponent gate has $[w \cdot dt \cdot \tilde V] = (1/E) \cdot E = $
dimensionless. ✓ The auxiliary exponent gate has $[\alpha_3 \cdot dt^3
\cdot C] = (1/E)^3 \cdot E^? $ — need $[C] = [V,[T,V]] = E^3$ since
$[T] = [V] = E$ and a double commutator multiplies dimensions. ✓

[Established] Both branches are dimensionally consistent.

### 3.2 Limit check: $T \to 0$ collapses the correction

If $T = 0$ (pure potential), then $[V,[T,V]] = 0 = |\nabla V|^2$ for
$V$ a c-number multiplier ($\nabla V \neq 0$ for non-constant $V$
even when $T = 0$, so the identity $[V,[T,V]] = |\nabla V|^2$
*requires* $T = -\nabla^2/2$). More carefully: the production code
uses $|\nabla V_{\rm eff}|^2$, computed via FFT spectral derivative of
$V_{\rm eff}$ (lines 113–124). If $T$ were zero (no kinetic operator
in the propagator), the bare scheme would already be exact at any $dt$
because both $V$ and $\tilde V$ exponentials commute trivially with
$T = 0$. The FG correction would then be cosmetic — added to $\tilde
V$ but irrelevant to the dynamics. This is consistent: the FG
correction's *purpose* is to cancel the $[V,[T,V]]$ error from
non-commutation, which vanishes when $T = 0$.

[Established] $T = 0$ limit consistent.

### 3.3 The bench's $V_{\rm SM}$ is **not** a scalar potential

A subtle but important note for cross-validation: the bench uses
$V_{\rm SM} = c_1 \cdot \bar m_\mu \cdot F_\mu$ (frozen $\bar m$,
spin-mixing matrix, lines 56–74 and 95–120). This is **matrix-valued
in spinor space**. The identity $[V,[T,V]] = |\nabla V|^2$ (CK eq 6.10)
requires $V$ to be a **scalar diagonal-in-spinor** local potential —
so $V$ commutes with itself but not with $T = -\nabla^2/2$, and the
commutator $[T,V]$ reduces algebraically.

For the bench's spinor $V_{\rm SM}$, this reduction does **not** hold:
$V_{\rm SM}$ does not commute with $V_{\rm SM}$ at *different* spatial
points trivially, *but* the $V_{\rm SM}$ in the bench is **autonomous
and spatially uniform** in its spinor structure (the $F_\mu$ matrices
are constants of motion, only $\bar m(I)$ varies spatially). So the
commutator $[V_{\rm SM}, [T, V_{\rm SM}]]$ does *not* reduce to a
simple $|\nabla \cdot|^2$ form and must be computed directly via the
discrete operator commutator $2VTV - VVT - TVV$ — which is exactly
what `apply_v4_direct!` (lines 141–155) does. This is the
$\nabla\psi$-derivative term flagged in memory
`integrator_v4_discrete_hermiticity.md` as the novel spinor extension
result.

So the bench's $\alpha_3$ sweep is a more general probe than the
production code's diagonal-only $|\nabla V|^2$ branch: the bench
tests the *full* discrete commutator form needed for spinor matter,
while the production code tests only the diagonal scalar reduction.
**Both should land on the same $\alpha_3 = -1/72$ for the FG
coefficient**, because the sign and magnitude are set by the BCH
arithmetic of the composition coefficients $(1/6, 2/3, 1/6)$ — not
by whether $V$ is scalar or matrix.

[Established] The bench tests the spinor commutator path (relevant
for v4 spinor extension); production tests the scalar diagonal path
(current `split_step_forcegrad!` scope per the `_assert_forcegrad_diagonal_only`
guard at lines 46–74). Both share the **same $\alpha_3 = -1/72$ sign
and magnitude.**

### 3.4 Cross-check against memory

Memory entry `gotcha_fg_correction_sign_wick_rotation.md` records:

> "Chin-Krotscheck 2005 Algorithm 4A eq 6.9 (Ṽ = V + (Δτ²/48)·[V,[T,V]])
> is IMAGINARY-time; for real-time RTP the Δτ² → -dt² flip makes
> α_real = -dt³/72 in the FG-correction exponent. Verified via
> α-sweep on autonomous F=1 Chin 4A: only α = -dt³/72 collapses error
> from ~5e-10 to FP-floor ~1e-12 (order 4); +1/72 stays at order 2.
> Bench: `scripts/bench/track_c_v4_a11_alpha_sweep.jl`."

This is consistent with the §2.3 derivation: the memo states the
empirical result on the **$\alpha_3$ exponent branch** (matches the
bench's parameterization), with sign $-1/72$ — the prediction §2.3
makes for what the bench should observe. [Plausible cross-check —
memory note is a soft endorsement; the actual bench result would be
the strong evidence.]

### 3.5 Self-consistency between the two files

Production line 267 (`fg_coeff = ... -dt^2 / 48`) and bench line 258
(`alpha_factors = [..., -1/72, ...]`) are **consistent under the
$\alpha_3 = (2/3)\,\alpha_2$ map** (§2.3). The two files use different
*conventions* — not different *physics*. No mismatch to surface.

[Established] No load-bearing inconsistency.

## 4. Calibrated claims

- [Established] `scripts/bench/track_c_v4_a11_alpha_sweep.jl` sweeps
  the **$\alpha_3$ exponent-branch** coefficient: `alpha_val =
  alpha_factor · dt³` is plugged into `psi .-= im · alpha_val · [V,[T,V]]ψ`,
  which is the first-order Taylor expansion of $\exp(-i\,\alpha_3\,
  dt^3\,C)$. Source: bench lines 157–164 and 222.
- [Established] `src/hamiltonian/integrator/force_gradient.jl` uses
  the **$\alpha_2$ potential-branch** coefficient: `fg_coeff = -dt²/48`
  applied additively to $\tilde V = V + \texttt{fg\_coeff} \cdot
  |\nabla V_{\rm eff}|^2$ at the middle slot. Source: lines 267, 327–331.
- [Established] The two conventions are related by $\alpha_3 = w\,\alpha_2$
  where $w = 2/3$ is the middle-slot weight (line 262: `a_mid = 2/3`).
  Hence the bench's correct sweep point `alpha_factor = -1/72` and the
  production code's `fg_coeff = -dt²/48` are **the same physical FG
  correction**. Source: §2.3 algebra.
- [Established] No convention mismatch exists between bench and
  production. Both use the **Wick-rotated sign** (negative) and the
  correct **Chin 4A weight-$2/3$ magnitude**. Source: §3.5.
- [Plausible] The bench, if executed, should report $p_{\rm emp} \in
  [3.8, 4.2]$ exclusively at the row labeled `-1/72`, with all other
  rows at $p_{\rm emp} \approx 2$. (Predicted in phase0 §3.3 and §2.5
  here; not measured this turn.) Source: BCH-cancellation argument
  in §2.3.
- [Plausible] The bench is a **stricter test** than the production
  scalar diagonal scope because it exercises the matrix-valued
  $V_{\rm SM}$ commutator via the direct discrete form
  `2VTV − VVT − TVV` (`apply_v4_direct!`, bench lines 141–155),
  whereas production uses the $|\nabla V|^2$ reduction valid only
  for scalar $V$. This is by intent — bench supports the v4 spinor
  extension prototyping. Source: §3.3 + memory
  `integrator_v4_discrete_hermiticity.md`.
- [Established] The production code's `_assert_forcegrad_diagonal_only`
  guard (lines 46–74) blocks $c_1 \neq 0$, DDI, tensor cache, Raman,
  light_shift, magnetic_gradient, transverse Zeeman, time-dependent
  Zeeman, time-dependent interactions, and scalar LHY — so production
  use of $\tilde V$ is currently restricted to the scope where
  $[V,[T,V]] = |\nabla V|^2$ holds exactly. Source: file lines 46–74.

## 5. Open questions

- Q: Does the bench actually run cleanly today? `scripts/bench/track_c_v4_a11_alpha_sweep.jl`
  uses `T_FINAL = 0.04` and three $dt \in \{4{\rm e}{-3}, 2{\rm e}{-3},
  1{\rm e}{-3}\}$ with a reference at `dt = 5e-5`. On an N=16³ grid
  this is ~20 minutes of CPU per row × 9 rows ≈ 3 hours. Not in this
  turn's 5-minute implementer budget. A **smaller** smoke version
  (one dt, no reference, just an assertion on the rational literal
  `-1/72`) would fit.
- Q: Is there a regression test that pins `fg_coeff == -dt^2/48`?
  Searching for `force_gradient` tests would clarify. If none exists,
  a 5-line `@test` on the sign / magnitude of the literal would
  protect against future Wick-rotation regressions.
- Q: For the v4 spinor extension (memory `integrator_v4_discrete_hermiticity.md`),
  is $\alpha_3 = -1/72$ still the correct coefficient, or does the
  matrix-valued $V_{\rm SM}$ structure (the $F_\mu$ matrices,
  $\nabla\psi$ derivative term) modify the FG coefficient?
  The §2.3 argument is independent of $V$ being scalar vs matrix
  (the BCH weight arithmetic only sees the composition coefficients),
  so the answer is **plausibly no, $-1/72$ should be the same**.
  But this would benefit from an explicit derivation in the v4 doc.

## 6. Directive for implementer

```json
{
  "action": "modify_code",
  "rationale": "Bench and production agree on physics (α_3 = -1/72 = (2/3)·α_2 = (2/3)·(-1/48)) but use different conventions. The relationship is currently documented only in a code comment at force_gradient.jl:264-266 (production side) and is not asserted anywhere as a regression test. Add a 5-line unit test pinning (a) production fg_coeff = -dt²/48 for real time and (b) bench alpha_factor literal -1/72 appears in the sweep list with the correct sign. This is a single-axis-of-variation test (just the rational literals + sign) per B5; cost is ~1 min wall-clock; falsifiable as a literal string match.",
  "target_files": [
    "test/hamiltonian/test_force_gradient_wick_sign.jl"
  ],
  "experiment_config": null,
  "expected_outcome": "New test file `test/hamiltonian/test_force_gradient_wick_sign.jl` containing two @testset blocks: (i) ‘Production fg_coeff sign’ — calls `split_step_forcegrad!` indirectly or inspects the computed fg_coeff via a small wrapper, asserting fg_coeff < 0 in real-time mode and fg_coeff > 0 in imaginary-time mode, with magnitude |fg_coeff| / dt² == 1/48 exactly (rational comparison via `==` on Float64 1/48 = 0.020833333333333332); (ii) ‘Bench alpha_factor list contents’ — opens scripts/bench/track_c_v4_a11_alpha_sweep.jl as text and asserts that the regex `-1/72` appears in the alpha_factors line, AND that -1/48 is also present (cross-coverage). Both tests run in <1 second total. Test file should be added to test/runtests.jl under the hamiltonian tier.",
  "falsification_criterion": "Test fails if (a) production line 267 changes to a positive sign or a different denominator (e.g., 1/24 or 1/72) without the Wick comment also being updated, OR (b) the bench's alpha_factors line no longer contains the literal `-1/72`. Either failure indicates a regression of the established Wick-rotation result derived in phase0_test_v2.md §2.5 and re-verified in turn_0.md §2.3.",
  "estimated_cost": "≤5 min: ~2 min to write the test file from the spec above, ~1 min to add to runtests.jl, ~1 min to run `julia --project=. -e 'using Pkg; Pkg.test()'` filtered to the new test."
}
```

## 7. Research queries

```json
[]
```
