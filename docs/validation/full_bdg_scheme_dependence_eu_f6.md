# The Eu F=6 LHY instability is entirely dipolar — and that names the fix

> **FROZEN 2026-08-19.** Describes the tree as of that date; not maintained.
> Its headline verdict has been **overturned** — read
> `docs/theory/lhy_scheme_selection_eu_f6.md` for the current statement. Frozen
> rather than kept LIVE because a document whose main conclusion no longer holds
> should not advertise itself as maintained, and because the measurements below
> remain a correct record of what was known on 2026-07-30.
>
> **Superseded in part, 2026-08-19 (#337).** Two things here have since been
> measured rather than argued, and both change the verdict:
>
> * the scheme dependence this document treats as an unbounded obstacle is
>   **≤ 6 % of ε_LHY** over `0 ≤ c_dd ≤ c_dd(Eu)`, and exactly 0 where the
>   spectrum is real. So "quote a bound rather than an ordering" — the third
>   honest route listed at the bottom of this file — is not a consolation prize,
>   it is a usable measurement with a known error bar;
> * the `q` escape-route table below was computed at 10⁻⁴ of the campaign's
>   field. It is corrected in place.
>
> Read `docs/theory/lhy_scheme_selection_eu_f6.md` for the current statement.
> Everything else here — that the instability is entirely dipolar, that
> converging does not null it, that `icosahedral` refuses at `c₁ < 0` — stands.


**Corrected 2026-07-30, same day.** The first version of this document concluded
"there is no usable LHY mode in this regime". That was too strong, and the
measurement that shows why took one extra column: **switch the DDI off and the
instability is exactly zero.**

| seed | max Im ω, DDI on | max Im ω, DDI off |
|---|---:|---:|
| flower | 0.365 | **0** |
| polar_core_vortex | 0.926 | **0** |
| m_plus_F | 0.370 | **0** |
| polar | 1.030 | **0** |

(texture ladder, N=50000, c₁=0, 50 µG, 16×16×32. Same on the `eu_k3_lhy` ladder:
`m_minus_F` gives 0.396 with DDI, 0 without.)

So this was never "Eu F=6 is beyond the machinery". The contact problem is
perfectly stable; **the dipolar term destabilises the spin branch**, at
`ε_dd = 0.5402`. And with the DDI off, `full_bdg` and the ansatz-matching closed
form agree to six significant figures — `V(n=3.7e-3)` = 0.380007 vs 0.380006 —
which is a clean cross-validation of both in the stable regime.

## Two prescriptions for the same physics, and only one is scheme-dependent

- **`full_bdg`** drops the complex branches from the zero-point sum while the
  counterterms still subtract all `D` of them. That is what its warning means by
  scheme-dependent, and it is why it flags these states.
- **the `*_dipolar` closed forms** use Petrov's prescription: `lima_pelster_Q5`
  zeros the integrand where `1 + ε_dd(3cos²θ − 1) < 0`, so the unstable angles are
  excluded rather than half-counted. At `ε_dd = 0.5402 < 1` this is inside its
  domain, and `fm_dipolar` returns a finite, well-defined value (0.553422) with no
  warning — checked, not silent.

**So the route is a `*_dipolar` closed form whose ansatz matches the state**, not
`full_bdg`.

## What that means per suite

**`eu_k3_lhy*` — has a valid route.** All twelve arms are `initial_state:
m_minus_F`, i.e. FM, and `c₁ < 0` makes FM the mean-field ground state, so the FM
ansatz matches the state. `fm_dipolar` is the correct target — not `full_bdg`,
which runs but is scheme-dependent at this dipolar strength, and not
`icosahedral`, which now refuses at `c₁ < 0`.

**The texture campaign — still blocked, for a different reason.** Its job is to
*compare five distinct textures*. Four of them (flower, csv, pcv, m_plus_F) have
`|⟨F⟩|/F = 1`, so `fm_dipolar` covers them — a pure direction texture is free,
ε_LHY being an SO(3) scalar for contact and moving ~0.25 % under DDI. But `polar`
has `|⟨F⟩|/F = 0` and needs `polar_dipolar`. Comparing an energy *ordering* across
two different closed forms is not the same measurement as ordering them under one
functional, and the only single functional covering all five is `full_bdg` — the
scheme-dependent one. That is the real obstacle, and it is about the comparison,
not about the atom.

---

## Original measurements (unchanged, re-scoped by the above)

# `full_bdg` ε_LHY is scheme-dependent for Eu F=6 at 50–80 µG

Measured 2026-07-30. **Consequence: the Eu texture campaign's phase ordering is a mean-field
statement, because no single LHY functional covers all five competing textures
without being scheme-dependent. Individual FM-magnitude states DO have a valid
route — see the correction above.**

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

### q — unreachable, but not by the margin this section claimed

**Corrected 2026-08-19 (#337).** The table below was computed at 10⁻⁴ of the
campaign's field. `linear_zeeman_p` takes **tesla**; the campaign YAML writes
`Bz: "4.4e-5 Gauss"` = 4.4e-9 T, and `julia --project=. scripts/cli.jl inspect`
on `config_texture_bscan.yaml` resolves `p = −0.651`, `q = +2.502e-08` there.
Every field label in the original was therefore 10⁴ too large — the row printed
as "1 G" is in fact 100 µG, which is why its numbers are the only ones that
survive unchanged. Corrected:

| Bz | p (dimensionless) | q (dimensionless) |
|---|---:|---:|
| 50 µG | **−0.7398** | **3.231e-08** |
| 60 µG | −0.8877 | 4.652e-08 |
| 70 µG | −1.036 | 6.331e-08 |
| 80 µG | **−1.184** | **8.270e-08** |
| 100 µG | −1.480 | 1.292e-07 |

Moving the table by 9.6 % (V(n=1): 46.09 → 50.52) took `q = 0.5`. The physical
`q` here is `~3e-8`, not `~1e-16`, so the margin is 8 orders and not 16.
Reaching `q ~ 0.5` still needs kilogauss, which is not this experiment.

**The conclusion survives, and is now measured rather than extrapolated.**
`bench/lhy_growth_vs_field.jl` sweeps the real field and the growth rate is flat:
3.667 → 3.883 → 3.891 (FM, m=+F) and 15.164 → 15.142 → 15.051 (polar) at
B = 0 / 44 / 100 µG. A linear Zeeman term shifts every branch and the chemical
potential together, so it does not gap the spin channel at all — which is a
better reason than "q is small", and one that would have held even if q had been
large. ε_LHY itself moves −2 % over the same range, so the zero-field tables the
2026-07-30 `zeeman`-passing defect produced were, in this regime, numerically
close to right.

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

## A4 (2026-07-31): the contact-regime agreement is a convergence, not a coincidence

The six-significant-figure agreement quoted above was measured at **one** point.
Lane A item A4 turned it into a convergence statement, because "agrees at one
density and one cutoff" and "the closed form is the exact limit" are different
claims and only the second one licenses the five papers that rest on it.

`bench/a4_lhy_closed_form_residual.jl` (job 8309441, cpu_4, 57 s) sweeps 13
cases — `polar_contact` at F = 1, 2, 6; `fm_contact` at F = 1, 2, 6;
`icosahedral` at F = 6 — over three densities and four BdG quadratures, contact
only. 156 rows.

| $k_{\max}$ | polar_contact | fm_contact | icosahedral |
|---|---:|---:|---:|
| 40 | 1.945e-3 | 1.917e-3 | 1.938e-3 |
| 60 | 5.861e-4 | 5.775e-4 | 5.839e-4 |
| 90 | 1.750e-4 | 1.724e-4 | 1.743e-4 |
| 140 | 4.666e-5 | 4.597e-5 | 4.649e-5 |

Fitted order $p = 2.96, 2.98, 2.99$ — **the same for all three families**, with
no plateau anywhere. At fixed $k_{\max} = 140$ the residual grows as
$1.5\times10^{-6} \to 9.0\times10^{-6} \to 4.67\times10^{-5}$ for
$n_0 = 0.3, 1, 3$, i.e. as $n^{3/2}$. So

$$\text{rel. residual} \;\simeq\; C\, n^{3/2} k_{\max}^{-3}.$$

That is the UV tail of the zero-point sum and nothing else. A fixed $k_{\max}$
is a *shallower* effective cutoff at higher density because the scale that
matters is $\sqrt{g n}$ — which is why `_lhy_quadrature` derives its cutoff from
`rtol` rather than taking one absolutely, and why the bench had to override that
derivation to measure the law at all.

**Three independent closed forms converging to `full_bdg` at the same order with
the same coefficient is a shared truncation error, not three coincidences.** The
closed forms are the exact limit here; there is no measurable method gap.

Consequences:

- A4's stated 1e-4 criterion is **met** — $9.0\times10^{-6}$ at $n_0 \le 1$,
  $k_{\max} = 140$. It is missed only at $n_0 = 3$ with $k_{\max} \le 90$, which
  is a quadrature setting, not physics.
- `_RTOL = 2e-3` in `test/oracles/test_lhy_full_bdg_closed_form_parity.jl` is
  ~40× looser than achievable. Its inline comment already blamed quadrature
  rather than method error and was right. The fix is **not** a hard-coded larger
  `k_max` but to let the `rtol`-derived cutoff do its job — which
  `derived cutoff scales with the stiffness, not absolutely` in that same file
  already covers.
- Scope, unchanged from the rest of this document: contact only. `full_bdg` has
  no mean-field-stable point in the Eu dipolar regime, and $\varepsilon_{LHY}$
  is scheme-dependent wherever $\mathrm{Im}\,\omega \neq 0$, so a parity number
  taken there would not mean anything. `icosahedral` is measured only at
  $\lambda_{\rm spin} > 0$; the closed form returns NaN on the $c_1 < 0$ branch
  by construction, and **that is the sign Eu production uses**.
