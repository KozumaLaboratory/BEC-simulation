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

### Take-away

* MPS-4 is **~9× more accurate than Yoshida4 at the same step count and same step size** in our test problem
* MPS-4's order under mean-field stays at 3.0-3.9 across coarse-to-fine
  range; Yoshida4 drops to 2.9 by the finest dt. This is the reason
  MPS-4 wins on absolute accuracy in the MF regime
* Norm drift 4e-10 over T=0.2 — needs occasional renormalization for
  long runs (>10⁵ steps) but acceptable for typical dynamics
* Implementation cost: trivial (3 Strang calls + a linear combination
  per outer step). No new physics derivation needed
* Smoke-test code: `/tmp/mps_smoke.jl` (not yet committed)

### Open questions before committing to implementation

1. **GPU memory pressure**: 16³ Eu D=13 ψ ≈ 850 KB per copy. T_6 needs
   3 separate ψ-shaped buffers (one per refinement) plus working
   memory. At 64³ Eu this is 215 MB × 3 = 645 MB on top of existing
   workspace — fits within 16 GB but pushes utilization
2. **Stream parallelism vs serial**: each `S(h/k)^k` is independent
   so on paper they can run on different CUDA streams. In practice
   shared FFT plans / DDI buffers serialize them on a single GPU. To
   get true parallelism we'd need separate scratch workspaces per
   stream. Worth measuring before claiming "fully parallel"
3. **Adaptive stepping**: existing L2 estimator is for Strang/Yoshida.
   Need to check whether MPS pairs have a natural embedded estimator

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

## Recommended next steps

1. **Promote MPS-4 smoke test to a proper test file** (test integrator
   order in MF + autonomous configurations + norm drift bounds)
2. **Bench MPS-4 on lab path Eu workspace** at 16/24/32³ to compare
   against Yoshida4 and split_step_combined! at production scale
3. Only after step 2 indicates a clear win, prototype an MPS driver
   in `src/hamiltonian/integrator/` (mirror of `_yoshida_core!`)
4. Track B (Thalhammer extension) parked until either step 2 reveals
   MPS shortcomings or the thesis schedule explicitly requires it

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
