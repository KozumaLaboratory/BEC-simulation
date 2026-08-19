# What the #361 DDI-block fix moved in quantities no test pins

> **FROZEN 2026-08-19.** A dated A/B between two commits, not a description of
> the tree. Reproduce with `runs/bdg_ddi_verdict_delta/measure_ungated.jl` at the
> two revisions named below.

#361 warned that correcting the coefficient would move existing verdicts and
asked for the diff. CI answered the gated half: with the fix in place every
physics gate passes unchanged — `test_level4_{f1,general_F}_phase_emergence.jl`,
`test_lhy_full_bdg_closed_form_parity.jl`, `test_bogoliubov_anchor.jl`,
`test_bdg_fd_hessian.jl`, `test_trapped_bdg_spectrum.jl`. The only red was
`docs/STATE.md`'s tier count. So the warning does not bind on anything the suite
asserts.

This file is the other half: the outputs that are consumed and never asserted.

**A/B.** `68b38dc7` (before) against `7e6770c2` (after), which differ by the fix
and its oracle and nothing else. Both measured on TSUBAME, job 8442687, one
process each, `node_o`. Fixture is production-shaped ¹⁵¹Eu: $F=6$,
$N = 5\times10^4$, $\omega_\text{ref} = 2\pi\cdot116$ Hz, `c1_ratio` $= 1/36$,
$c_\text{total} = 4813.403574$, $c_{dd} = 216.700165$, $n_0 = 3.313\times10^{-3}$
(Thomas-Fermi peak), zero field, seeds `stretched` ($m=+F$) and `polar` ($m=0$)
— the two the phase-diagram config uses.

**The negative control holds.** With `c_dd = 0` the `full_bdg` energy density is
bit-identical across the two revisions (`5.4885846139e+01` stretched,
`1.4745687026e+01` polar), so every difference below is the DDI block and nothing
else. Without that arm the deltas would not be evidence.

## Mean-field BdG: growth rates and the most unstable direction

`instability_angular_map`, 13 θ × 24 φ, `k_max = 6`, `n_k = 40`. This is what
`triple_point` consumes — it depends on the fix only through
`bogoliubov_spectrum.max_growth_rate` — and what `analyzers/stability.jl` reports.

| quantity | before | after | change |
|---|---:|---:|---|
| **stretched** max growth over directions | 3.5010 | 2.0307 | **−42 %** |
| **stretched** mean growth | 1.6155 | 1.0297 | −36 % |
| **stretched** most unstable direction | θ = 0.262 (15°) | θ = 1.571 (90°) | **axial → equatorial** |
| **stretched** lowest branch at k=1, k ∥ z | 3.4870 | 0.9360 | −73 % |
| **polar** max growth | 13.948 | 0.3708 | **−97 %** |
| **polar** mean growth | 5.972 | 0.3708 | −94 % |
| **polar** growth at k ∥ z | **exactly 0** | 0.3527 | the missing normal block |
| **polar** growth at k ⊥ z | 13.948 | 0.3527 | −97 % |

Three of these are qualitative rather than numerical.

**The most unstable direction moved from 15° to 90°** for the stretched state.
Any consumer that reads `most_unstable_direction` — the boundary tracer, the
`bogoliubov_mode` analyzer's mode extraction, a figure of the instability map —
was pointing at a different place on the sphere.

**The polar state had exactly zero growth along z and 13.9 across it.** That is
the signature of the defect rather than a physical anisotropy: with the normal
block missing, the polar instability was carried by the anomalous block alone.
After the fix the map is direction-independent to the printed digits (max = mean
= 0.3708), and 38× smaller.

**The magnitude fell in every case.** The old normal block was twice the correct
size on a polarized state and structurally wrong on a polar one, and both errors
inflated the growth rate — so any past "this configuration is dynamically
unstable" verdict from this instrument was biased toward instability, not away
from it.

## ε_LHY: not quotable at this fixture, by the code's own report

`full_bdg` ε_LHY with the DDI active moved −2.1 % (stretched, 86.231 → 84.418)
and +43 % (polar, 21.908 → 31.417). **Neither number is quotable**, because both
revisions print, at this fixture,

> FullBdG LHY: mean field is dynamically unstable (max Im ω = 3.6 / 2.03). The
> zero-point sum drops the complex branches while the counterterms still subtract
> all 13 of them, so ε_LHY is scheme-dependent here.

which is exactly the condition `docs/validation/full_bdg_scheme_dependence_eu_f6.md`
documents. A scheme-dependent value differencing by 43 % between two coefficient
conventions says nothing about either. What the same warning *does* report
cleanly is that the instability it measures fell with the fix: **max Im ω 3.6 →
2.03**, consistent with the growth-rate table.

Closing the ε_LHY question needs a mean-field-**stable** (F, c₀, c₁, q) point, not
this one. That is a separate measurement and it belongs with #337.

## What this does not cover

`triple_point`'s triple-point coordinates themselves, which would need its
L-BFGS boundary solves; the argument above is that its only channel from this fix
is `max_growth_rate`, quantified here. And the trapped instrument
`trapped_bdg_frequencies` (#339), whose disagreement opened #361, is not on `main`
yet — the closed-form anchor
(`test/oracles/test_dipolar_bogoliubov_anchor.jl`) settles the coefficient without
it, and #339's own `@test_broken` should turn into an unexpected pass when it
lands.
