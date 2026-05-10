# Integrator modernization plan — verified against primary sources

**Status:** verification + smoke-test phase. NO implementation commits yet.
Last update: 2026-05-11.

## Context

After verifying that `_COMP_YOSHIDA_S6` matches Yoshida 1990 Solution A
and that the codebase's `cfet4_real_step_rotating!` is documented as
experimental, the order behavior of higher-order integrators under
`c1 ≠ 0 / c_dd ≠ 0` was empirically measured (see
`test/hamiltonian/test_integrator_order_meanfield.jl`):

```
config         Strang  Yoshida4   Yoshida6  CFET4 (experimental)
autonomous     2.00    4.00→3.88  5.08→floor 2.00 (always)
DDI active     2.00    3.01→1.19  1.00       1.96
full MF        2.00    3.08→1.21  1.00       1.96
```

Yoshida1990 was derived for separable autonomous H = T(p)+V(q)
(verified in [Yoshida 1990 abstract](https://ui.adsabs.harvard.edu/abs/1990PhLA..150..262Y));
self-consistent mean-field problems are outside that scope. Choi &
Vaníček ([arXiv:2006.16902](https://arxiv.org/abs/2006.16902), 2020)
document explicit splitting collapsing to first-order accuracy in
general nonlinear NLS settings.

This file records two parallel exploratory tracks that *might* enable
4th-order convergence for our spinor + DDI Hamiltonian.

---

## Status (2026-05-11 update)

* Track A (MPS-4 as drop-in on existing Strang): **parked, see below**
* Track A1 (midpoint-symmetrize lab Strang first, then MPS-4 / Y6 /
  Force-Gradient on top): the actually-actionable next step
* Track B (Thalhammer 2026 spinor + DDI extension): still scope of
  thesis Ch.3, dependent on A1 succeeding

---

## Track A — Multi-Product Splitting (Chin-Geiser 2010-11)

**Source:**
- Chin (2010) ["Multi-product splitting and Runge-Kutta-Nyström integrators"](https://link.springer.com/article/10.1007/s10569-010-9255-9), Celestial Mech. Dyn. Astron. 106, 391
- Chin & Geiser (2011) "Multi-product operator splitting", IMA JNA 31, 1552
- Chin ([arXiv:0809.3739](https://archive.org/details/arxiv-0809.3739)) "Any order imaginary time"

### Construction

For a Strang second-order step `S(h)`, the 4th-order MPS is

```
T_4(h) ψ  =  -1/3 · S(h) ψ  +  4/3 · S(h/2)² ψ
```

Higher orders by Richardson-Aitken-Neville extrapolation:

```
T_6(h) =   1/24 S(h)   - 16/15 S(h/2)²  + 81/40 S(h/3)³
T_8(h) = -1/360 S(h)   + 16/45 S(h/2)²  - 729/280 S(h/3)³ + 1024/315 S(h/4)⁴
```

### Properties

* **Positive coefficients in each `S(h/k)`** — every internal Strang
  substep takes positive time. Imaginary-time stable.
* **Linear combination of unitary operators** is NOT itself unitary →
  norm preserved only to the convergence order (O(h⁴) for T_4, etc.)
  rather than to machine precision. Bounded drift, not exact.
* **Quadratically growing substep count**: T_p needs ~p/2 separate
  Strang propagations of varying refinement. Memory and stream
  parallelism can hide the cost on GPU.
* **No special operator structure required** — drop-in replacement
  for any code path that already has a Strang step.

### Smoke-test results (rotating-basis 8³ F=1, T_final=0.2, 2026-05-11)

```
                    err@h=0.04      err@h=0.02      err@h=0.01    order
autonomous:
  Strang             6.7e-4         1.7e-4          4.1e-5         2.00
  Yoshida4           1.0e-5         6.5e-7          4.5e-8         4.00 → 3.88
  MPS-4              1.2e-6         7.5e-8          8.5e-9         3.95 → 3.14
full mean-field (c1=0.5, c_dd=0.3):
  Strang             7.0e-4         1.7e-4          4.3e-5         2.00
  Yoshida4           1.1e-5         7.2e-7          9.4e-8         3.96 → 2.94 ← MF degradation
  MPS-4              1.2e-6         8.0e-8          9.8e-9         3.94 → 3.03 ← retains order

norm drift after T=0.2 at h=0.02:
  Strang/Y4:   ~1e-14 (unitary)
  MPS-4:        4e-10 (bounded as O(h⁴) predicted)

cost per step (full MF, 8³ rotating-basis): 3 Strang substeps each, MPS-4 ≈ Yoshida4
```

### Take-away (rotating-basis path)

* MPS-4 is **~9× more accurate than Yoshida4 at the same step count and same step size** in our test problem
* MPS-4's order under mean-field stays at 3.0-3.9 across coarse-to-fine
  range; Yoshida4 drops to 2.9 by the finest dt
* Norm drift 4e-10 over T=0.2 — bounded as O(h⁴) predicted

### Lab-path test — surprising failure (2026-05-11)

Repeated the same MPS-4 construction on the lab path (Workspace +
split_step! / split_step_combined!), Rb87 F=1 D=3 with c0=50, c1=1,
c_dd=1, T=0.04:

```
                     err@h=4e-3  err@h=2e-3  err@h=1e-3  ord
split_step!          2.09e-5     5.23e-6     1.31e-6     2.00 ✓
split_step_combined! 2.09e-5     5.23e-6     1.31e-6     2.00 ✓
MPS-4 (combined)     1.08e-8     5.42e-9     2.79e-9     0.99 ✗
MPS-4 (split_step!)  5.42e-9     2.64e-9     1.35e-9     1.04 ✗
```

Both MPS-4 variants collapse to **global order ≈ 1** despite the
underlying Strang showing clean order 2. F=6 (Eu151) shows the same
pattern, ruling out spinor-coupling matrix non-commutativity.

**Diagnosis.** MPS-4's Richardson coefficients (-1/3, 4/3) cancel the
**odd-power** Taylor terms of a symmetric Strang local error
(τ³, τ⁵, …). For *truly* symmetric Strang there are no even-power
terms, so the cancellation goes through cleanly to order 4-5. The
lab-path V step is a nested Strang
`diag · SM · DDI · SM · diag` where each SM and DDI substep evaluates
the mean field `Φ_DDI[ψ]` and `c1⟨F⟩[ψ]` at substep ENTRY (frozen
midpoint). The two SM substeps thus evaluate Φ at *different* times
relative to the middle DDI substep — the inner Strang is no longer
exactly symmetric, and a τ² even-power term creeps into the V-step's
local error. Plain Strang iteration absorbs this τ² as a nominally
sub-dominant term (global error remains O(τ²) with a slightly larger
constant), but MPS-4's coefficients are calibrated to remove only
odd powers and so the τ² term survives the linear combination,
collapsing the result to order 1.

The rotating-basis path's V step has different structure (no
SM/DDI nesting; the rotating frame eliminates Larmor explicitly), so
its Strang is genuinely symmetric and MPS-4 works there.

### Note on absolute accuracy

Even at order 1, MPS-4 has a **dramatically smaller leading
constant** than Strang. At h=4e-3 the F=1 lab-path MPS-4 error is
5.4e-9 vs Strang 2.1e-5 — a 3850× absolute improvement at 3× cost.
Crossover with order-2 Strang occurs at h ≈ 6.5e-5; for production
dt ∈ [10⁻³, 5×10⁻³] MPS-4 still wins by orders of magnitude on
cost-per-accuracy grounds. This means the underlying machinery is
right; only the order-recovery is gated on fixing the time-reversal
asymmetry of the V step.

### Track A1 (recommended path before reattempting MPS / Y6 / Force-Gradient)

Replace `_half_potential_step!`'s nested Strang with a
**predictor-corrector midpoint** evaluation of `Φ_DDI` / `c1⟨F⟩`:

1. Predictor: from ψ_entry, advance half a substep with frozen
   ψ_entry mean field, get ψ_pred (rough midpoint estimate)
2. Compute `Φ_mid = Φ_DDI[ψ_pred]`, `⟨F⟩_mid = ⟨F⟩[ψ_pred]`
3. Corrector: re-do the substep using `Φ_mid` / `⟨F⟩_mid` instead
   of the entry-point values

Cost per V-step: roughly 2× (one predictor FFT + one corrector FFT
where there was only one before). Order: should restore true
symmetry, allowing odd-only Taylor expansion of the Strang local
error. Validation: rerun this diagnostic; MPS-4 order should jump
from 1 to 4. Yoshida6 should also recover (currently broken to
order 1 under MF, see `test/hamiltonian/test_integrator_order_meanfield.jl`).

If this works, MPS-4 / Yoshida4 / Yoshida6 / CFET4 / Force-Gradient
all become available on the lab path. Otherwise the diagnosis
stands but the cause is something other than symmetry-breaking
in the V step, and we need to look elsewhere.

### Diagnostic reproduction

* `scripts/bench/mps_smoke.jl` — rotating-basis F=1 (works ~order 4)
* `scripts/bench/mps4_lab_diagnostic.jl` — lab-path F=1/F=6 (collapses
  to order 1)

---

## Track B — Modified Splitting (Thalhammer & Thalhammer-Thurner 2026)

**Source:** [arXiv:2601.19838](https://arxiv.org/abs/2601.19838) (34 pages, January 2026)

### What the paper actually contains (verified by reading)

* J-component coupled GPE with **contact-only** interactions
  (eq. 11): `i ∂_t ψ_j = ∆_{α_j} ψ_j + V_j ψ_j + Σ_k ϑ_{jk} |ψ_k|² ψ_j`
* Modified splitting structure (eq. 18a-c): standard ABA composition
  but the V-step gets a `+ c_i τ² G` correction term, where G is
  the iterated commutator `[DF₂, [DF₂, DF₁]]` of Lie-derivatives
* Fourth-order example method (eq. 22):
  ```
  s = 3,  a = (0, 1/2, 1/2),  b = (1/6, 2/3, 1/6),  c = (0, -1/72, 0)
  ```
  Principal coefficients (a, b) all non-negative ⇒ stable in
  imaginary time. The τ² scaling on c kills the negative-coefficient
  problem
* Explicit `G_1` formula for J=2 case (eq. 19a-e): substantial — 30+
  terms involving `∇_{α_j} ψ̃_k · ∇ ψ̃_l ψ̃_m` triple products and
  `∆_{α_j} V_k` Laplacians of potentials and `(∆_{α_1} - ∆_{α_2}) ψ̃`
  cross-component Laplacian differences
* Both real-time (eq. 11) and imaginary-time (eq. 14) handled by the
  same scheme

### What the paper does NOT contain

* **Spinor / F=1/2/3 / matrix-valued F̂ structure**: not mentioned
  anywhere in 34 pages
* **DDI / dipolar / nonlocal interactions**: zero mentions of
  "DDI", "dipol", "long-range", or "nonlocal"
* **Explicit J=3+ formulas**: only J=2 worked out
* **Specific speedup numbers vs Yoshida4**: figures show curves but
  the claim of "500× smaller error coefficient" cited elsewhere is
  not in this paper — it likely comes from Chin's original 1997
  modified-potential paper for the linear case

### Adaptation cost for ¹⁵¹Eu (F=6, D=13) + DDI

To bring the Thalhammer 2026 framework to our system, three
extensions are needed:

1. **F₁ extension**: their F₁ = ∆_{α_j} + V_j is local diagonal in
   component index j. Ours has the same structure plus linear Zeeman
   p m_j (still local diagonal) and quadratic q m_j² (local diagonal).
   The local-diagonal property is preserved — **easy**

2. **F₂ extension** (the hard part):
    * Their F₂_j = Σ_k ϑ_{jk} |ψ_k|² ψ_j — scalar contact, diagonal in
      component index, real-symmetric ϑ matrix
    * Ours: F₂_j = c₀ |ψ|² ψ_j + c₁ Σ_{αβ} (F_α F_β)_{jk} ⟨F_β⟩ ψ_k
      + (DDI nonlocal)
    * The c₁ term couples components via spin matrices F̂ — **NOT a
      diagonal action**. Thalhammer's `(ϑ_{jk})` is real, ours has
      F-matrix structure
    * The DDI term involves an FFT convolution — **nonlocal** while
      Thalhammer's F₂ is purely pointwise multiplication. The
      iterated commutator [F₂, [F₂, F₁]] picks up nonlocal pieces
      from both `[T, V_DDI]` and `[V_DDI, V_contact]`

3. **Iterated commutator G derivation**: eq (19a-e) gives J=2
   contact-only G. For J=13 spinor + DDI, G has additional terms
   from spin-matrix non-commutativity (`[F_α, F_β] = i ε_{αβγ} F_γ`)
   and from kinetic-DDI cross terms. **Has to be derived from
   scratch** — not a translation, a derivation

### Estimated effort

The derivation in §3 of Thalhammer 2026 occupies ~3 pages for J=2
contact-only. F=6 (J=13) with full F̂ + DDI is plausibly **5-10×
larger** in algebraic complexity. Implementation + numerical
verification + spinor invariant checks (mass, magnetization, energy
conservation) is **修論 Ch.3 contribution** territory, not a
pull-request-sized task.

### Decision criteria

* If MPS-4 (Track A) gives us order 4 with acceptable norm drift
  on the lab path (16-48³ Eu) at production cost, it likely
  satisfies Phase-1 needs of the thesis without the Track-B
  derivation
* Track B is the path forward if MPS-4 has unfixable drawbacks
  (e.g., stream parallelism doesn't pan out or norm drift accumulates
  unacceptably for long-time integrations) OR if the thesis explicitly
  needs a tailored method as a publishable contribution
* Either way, the Thalhammer 2026 paper is **not a drop-in template**.
  Calling it "Phase 3 of a 2-3 month plan" was an underestimate of
  the spinor + DDI extension cost

---

## Recommended next steps (revised 2026-05-11)

1. **Track A1: Midpoint-symmetrize the lab-path V step.** Add a
   `_half_potential_step_midpoint!` variant that uses
   predictor-corrector evaluation of the mean field at substep
   midpoint. Cost ~2× per V step. Validation: MPS-4 order jumps from
   1 to 4 on the lab path, AND Y6 mean-field collapse should
   simultaneously fix (same root cause). 1-2 weeks effort.
2. After A1 succeeds, the original "Track A — MPS on top of Strang"
   becomes viable. Add it as an opt-in alternative to
   `split_step!` / `split_step_combined!`
3. Track B (Thalhammer extension to F=6 + DDI) is the thesis-Ch.3
   contribution path, dependent on having a properly symmetric
   inner V (= A1 done first)
4. If A1 fails or is too expensive, fall back to the current
   Strang + adaptive dt (no high-order). The thesis contribution
   moves elsewhere (Universal Structure Theorem, EdH selection rules,
   Flower phase analysis)

---

## Sources

* [Yoshida 1990, Phys. Lett. A 150, 262 — abstract](https://ui.adsabs.harvard.edu/abs/1990PhLA..150..262Y)
* [Chin 2010, Celest. Mech. Dyn. Astron. 106, 391](https://link.springer.com/article/10.1007/s10569-010-9255-9)
* [Chin & Geiser 2011, IMA J. Numer. Anal. 31, 1552](https://academic.oup.com/imajna/article/31/4/1552)
* [Chin arXiv:0809.3739 — any-order imaginary-time](https://archive.org/details/arxiv-0809.3739)
* [Alvermann & Fehske 2011, JCP 230, 5930 — arXiv:1102.5071](https://arxiv.org/abs/1102.5071)
* [Choi & Vaníček 2020, arXiv:2006.16902](https://arxiv.org/abs/2006.16902)
* [Chin 2007, arXiv:0710.0396 — NLS splitting instabilities](https://arxiv.org/abs/0710.0396)
* [Thalhammer & Thalhammer-Thurner 2026, arXiv:2601.19838 — modified splitting GPE](https://arxiv.org/abs/2601.19838)
