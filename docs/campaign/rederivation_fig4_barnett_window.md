# Figure 4 re-derived: the ±Ω asymmetry does not reproduce

**2026-08-01, TSUBAME job 8314495 (cpu_16), 16 of 16 configs completed, none
threw.** Re-runs every committed `runs/barnett_eu_window/*.yaml` against the
stored summary of 2026-05-26 — one of the 230 that predate every correction and
carry no producing commit.

`runs/barnett_eu_window/`'s `summary.json` — the configs are tracked, the summary
was never committed — is the data behind **Fig 4** of
`four_figure_spec_2026_05_26.md`.

## ΔF_z = F_z(end) − F_z(0), the spin driven out of m = −6

| Ω | stored | re-derived |
|---:|---:|---:|
| −0.3 | **2.1145** | 0.0414 |
| +0.3 | 0.0248 | 0.0414 |
| −0.5 | **1.7705** | 0.0843 |
| +0.5 | 0.0542 | 0.0843 |
| −0.7 | **1.2836** | 0.2189 |
| +0.7 | 0.0168 | 0.2187 |
| −0.9 | 0.2454 | 0.2524 |
| +0.9 | 0.0317 | 0.2859 |
| 0.0 | 0.0588 | 0.0390 |

Two things changed at once.

**The asymmetry is gone.** The stored data separates ±Ω by a factor of **85 at
Ω = ±0.3** and 33 at ±0.5. The re-derived data is symmetric: ±0.3 agree to four
decimals (0.0414 both), ±0.5 likewise (0.0843), ±0.7 to 0.0002, ±0.9 to 13 %.

**The Ω-dependence reversed.** On the stored negative branch ΔF_z *falls* with
|Ω| — 2.11 → 1.77 → 1.28 → 0.25. Re-derived it *rises* — 0.041 → 0.084 → 0.219 →
0.25. The two curves meet only at |Ω| = 0.9.

## Internal checks pass

- **All four `DDIoff` cells give ΔF_z = 0.0000 exactly.** Without DDI there is no
  spin-orbit channel and F_z must be conserved; it is, to every digit printed.
  Stored and re-derived agree here.
- **n32 and n64 agree to four decimals** at Ω = −0.3 (0.0414 both), so the
  re-derived numbers are not a resolution artifact.
- `N50k` is a real outlier: ΔF_z = **1.683**, forty times the N = 10⁴ value at the
  same Ω. Atom number matters far more than Ω does in the re-derived data.

## What this does NOT establish

**Which dataset is right.** Both are internally consistent; the stored one was
produced before the 2026-06 integrator corrections, the 2026-07-08 q fix and the
DDI padding default, and this re-run has none of that as a control.

**That any chirality claim is settled.** ±Ω is *not* the mirror operation here:
`mistake_barnett_chirality_arms_not_mirror_images_2026_07_28` records that
`SinusoidalWaveform` is a sine, so mirroring requires negating `By` as well.
A ±Ω asymmetry therefore was never a clean chirality test in either dataset — the
stored figure's 85× and this re-run's near-symmetry are both measurements of
something less specific than "chirality".

The Barnett arc is also being actively rewritten (#217 established the conversion
efficiency as the converged quantity; #219 retracted the superseded rotating-field
study), so Fig 4's question may be superseded independently of which number is
correct.

## Status of the figure

Fig 4 as drawn shows a strong ±Ω asymmetry that the current code does not
reproduce. It should not be redrawn from either dataset until the mirror
operation is fixed — negate `By` with Ω — and the result is checked against #217's
conversion-efficiency framing.
