# `full_bdg` ε_LHY is scheme-dependent for Eu F=6 at 50–80 µG

Measured 2026-07-30. **Consequence: the Eu texture campaign's phase ordering is a
mean-field statement. There is currently no route to a quotable
beyond-mean-field ordering in this regime.**

## What the code says about itself

`compute_spinor_lhy_table` (`:full_bdg`) checks the BdG spectrum of the uniform
mean field at the representative spinor and warns when a branch grows:

> FullBdG LHY: mean field is dynamically unstable (max Im ω = …). The zero-point
> sum drops the complex branches while the counterterms still subtract all 13 of
> them, so ε_LHY is scheme-dependent here. **This is a property of the state — the
> closed forms are no better.** Pick a mean-field-stable (F, c₀, c₁, q) point.

So this is not a `full_bdg` defect that switching to `polar_contact` /
`icosahedral` avoids. It is a statement about the state.

For `icosahedral` the door is shut harder still, and independently. As of
2026-07-30 `epsilon_LHY_F6_Ih` **returns NaN for `λ_spin < 0`, i.e. for `c₁ < 0`**,
and `_tabulate_lhy` turns a non-finite table into an `ArgumentError` at build time.
The closed form is `c₀^(5/2) + 3|λ_spin|^(5/2)`; the `|·|` had made it symmetric
under `c₁ → −c₁` and returned a real energy exactly where the spin-Goldstone branch
is dynamically unstable — the same instability this document is about, reached from
the other side. Measured then: `full_bdg` reports max Im ω = 2.8 at
(c₀=10, c₁=−0.2), and the closed form ran 0.4 / 2.1 / 11.0 % high at
c₁ = −0.05 / −0.1 / −0.2.

**`c₁ < 0` is the sign Eu F=6 production uses.** So `icosahedral` does not merely
inherit the scheme dependence — it now refuses to run at all here, and the
remaining option is `full_bdg`, which is what this document measures. Both doors
were found shut on the same day, by different routes:

| mode | status at Eu F=6, c₁ < 0, 50–80 µG |
|---|---|
| `icosahedral` | **errors at build time** — closed form invalid where the spin branch is unstable |
| `polar_contact` | ansatz is polar; inherits the scheme dependence by the warning's own statement |
| `full_bdg` | runs, but ε_LHY is scheme-dependent — measured below |

## The three escape routes, all closed

The warning names `(F, c₀, c₁, q)`. `F` is the atom. That leaves three.

### q — unreachable by 15 orders of magnitude

`q` scales as `Bz²`. At the campaign's fields:

| Bz | p (dimensionless) | q (dimensionless) |
|---|---:|---:|
| 50 µG | −7.40e-05 | **3.23e-16** |
| 60 µG | −8.88e-05 | 4.65e-16 |
| 70 µG | −1.04e-04 | 6.33e-16 |
| 80 µG | −1.18e-04 | **8.27e-16** |
| 1 G | −1.48 | 1.29e-07 |

Moving the table by 9.6 % (V(n=1): 46.09 → 50.52) took `q = 0.5`. The physical
`q` here is `~1e-16`. Reaching `q ~ 0.5` needs kilogauss, which is not this
experiment.

*Prerequisite for even asking:* until 2026-07-30 `_build_spinor_lhy` never passed
`zeeman` to the table builder, so every table was built at **zero field** and `q`
could not enter at all. Fixed with a gate; the fix restores correctness but does
not open this route.

### c₀, c₁ — not free parameters

These are Eu's scattering lengths. `c₁` can only move inside the uncertainty of
the 7 unknown channels; it is not a knob to be tuned until the state is stable.

### A stable state — not reached by converging

Every seed is unstable, and **converging does not null it**. One cell
(`Bz = 50 µG`, `c1_ratio = 0`, 16×16×32 smoke geometry, mean-field ITP, 4000
steps, `tol = 1e-9`):

| seed | max Im ω (seed) | max Im ω (after ITP) | factor | ITP converged? |
|---|---:|---:|---:|---|
| flower | 0.365 | 0.0688 | 5.3× | no |
| chiral_spin_vortex | 0.369 | 0.0771 | 4.8× | no |
| polar_core_vortex | 0.926 | 0.0735 | 12.6× | no |
| m_plus_F | 0.370 | 0.0880 | 4.2× | no |
| **polar** | 1.030 | **0.150** | 6.9× | **yes** |

Convergence buys a factor 4–13 and stops there. The threshold for the warning is
`1e-8 × scale`, so these remain seven orders inside the unstable region.

**The decisive row is `polar`.** It is the only one whose ITP actually converged,
and it has the *largest* residual growth rate. The other four are "after 4000
steps", not converged, so the trend alone would leave room for "converge harder
and it vanishes" — the one genuinely converged state rules that out.

Earlier numbers at the production geometry (32×32×64) were `max Im ω` ≈
1000–3900 across all 40 (Bz, c1, seed) cells. Those are **not** comparable with
the table above: the BdG problem is solved at the peak density, so a different
grid is a different problem. Same-grid comparison is the only valid one.

## What this does and does not establish

**Does:** for this atom, these fields and these scattering lengths, `ε_LHY` from
`full_bdg` carries a scheme dependence that no available knob removes, and the
closed forms inherit it by the code's own statement. A 40-point production run
would produce numbers that cannot be quoted as a beyond-mean-field result.

**Does not:** refute the mean-field ordering, or establish that the true
beyond-mean-field ordering differs. It says the current machinery cannot answer
the question here.

**Also observed, and explicitly not a refutation.** At the smoke geometry the
mean-field energy ordering is
`flower (8.876) < m_plus_F (9.458) < polar_core_vortex (9.871) < chiral_spin_vortex (9.897) < polar (11.416)`
— PCV third, not first. That is 16×16×32 with 4 of 5 ITPs unconverged, against a
production geometry of 32×32×64. It does **not** contradict "PCV wins at 50 µG";
it simply does not reproduce it at this resolution, and is recorded so the next
person does not have to rediscover the discrepancy.

## Status of the campaign claim

"PCV wins at 50 µG, uniform axial from 60 µG" stands as a **mean-field** result.
The beyond-mean-field cross-check it was waiting for is not blocked on compute —
it is blocked on the physics of the regime.

Three separate plumbing bugs had to be fixed before this could even be measured,
which is why the question looked open for so long:

| | |
|---|---|
| #179 | `find_ground_state_lbfgs` had no `spinor_lhy` kwarg — every `method: lbfgs` ground state ran mean-field |
| #201 (1) | `apply_step!` / `_grad_lhy!` could not carry a tabulated table onto a GPU |
| #201 (2) | `_build_spinor_lhy` never passed `zeeman`, so every BdG table was built at zero field |

## If someone wants to reopen this

The honest routes are physics changes, not knob changes:

- a **mean-field-stable** (F, c₀, c₁, q) point — a different atom, or fields
  large enough that `q` matters, or a regime where the competing textures are not
  near-degenerate;
- a scheme that does not drop complex branches while subtracting all `D`
  counterterms, i.e. a different treatment of the unstable modes rather than a
  different ansatz;
- accepting the scheme dependence and quoting a **bound** rather than an
  ordering, with the spread across schemes as the uncertainty.
