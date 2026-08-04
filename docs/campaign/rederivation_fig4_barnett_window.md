# Figure 4 re-derived: the ±Ω asymmetry does not reproduce

> **FROZEN 2026-08-01.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

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

## Settled 2026-08-02: ±Ω was never a symmetry operation

The question "which dataset is right" dissolves. Neither measures chirality,
because the pair being compared is not related by a symmetry.

`barnett_eu_window` drives the rotation through `rotating_frame_omega` — a
rotating *frame*, not the sinusoidal Bx/By field of `eu_barnett_rotfield_clean`
that [[mistake_barnett_chirality_arms_not_mirror_images_2026_07_28]] was about. For
a rotating frame the reflection in any plane containing z sends

    Ω_z → −Ω_z,   B_z → −B_z,   F_z → −F_z,   L_z → −L_z

because Ω and B are **both axial**. The committed ±Ω pair holds `Bz` fixed at +z
and flips only Ω, so it is not a reflection of anything.

**The true mirror holds to six digits.** Running
`(Ω = +0.5, Bz < 0, m = +F)` — the reflection of the committed
`(Ω = −0.5, Bz > 0, m = −F)` — TSUBAME job 8316097:

| run | Ω | Bz | F_z(0) | ΔF_z |
|---|---:|---|---:|---:|
| `barnett_eu_omm0p5_DDIon` | −0.5 | +z | −6.0000 | **+0.084327** |
| `mirror_omp0p5_Bzneg` | +0.5 | **−z** | +6.0000 | **−0.084327** |

Exact sign reversal, identical magnitude. **The code respects the reflection
symmetry.** Nothing is wrong with the solver, and nothing was wrong with either
dataset's arithmetic.

What was wrong is the comparison. The stored figure's 85× separation between
Ω = ±0.3 and this re-derivation's near-equality are both measurements of a
non-symmetry pair — they can take any value without saying anything about
chirality. That the two datasets disagree so violently is a statement about the
2026-06/07 corrections, not about a physical asymmetry.

This lands in the same place as #217, which made the conversion efficiency the
converged quantity rather than raw ΔF_z.

**Consequence for Fig 4: the panel as specified has no well-defined observable.**
It should not be redrawn from either dataset. A chirality figure needs mirror
pairs — (Ω, B_z) flipped together — and by construction those give exactly
antisymmetric ΔF_z, so the interesting quantity has to be something else.

## What this does NOT establish

**Which dataset is right.** Both are internally consistent; the stored one was
produced before the 2026-06 integrator corrections, the 2026-07-08 q fix and the
DDI padding default, and this re-run has none of that as a control. The section
above supersedes this: the question does not have an answer, because neither
number measures the quantity the figure names.

> **CORRECTED 2026-08-02.** This paragraph originally read: *"±Ω is not the mirror
> operation here: `SinusoidalWaveform` is a sine, so mirroring requires negating
> `By` as well."* **That is wrong for this suite.** It transplanted
> `mistake_barnett_chirality_arms_not_mirror_images_2026_07_28`, which is about
> `eu_barnett_rotfield_clean` — a suite that builds a rotating field from
> sinusoidal `Bx`/`By` waveforms. `barnett_eu_window` uses a rotating **frame**
> (`rotating_frame_omega`) with a static axial `Bz`, so the mirror negates **`Bz`**,
> not `By`. Measured above: the (Ω, B_z) mirror is exact to six digits.
>
> The conclusion the wrong reasoning reached — that ±Ω was never a clean chirality
> test — happens to be right, which is why it survived review. **Right answer,
> wrong mechanism, and it named the wrong field to negate**, so anyone acting on
> it would have run a second meaningless pair.

The Barnett arc is also being actively rewritten (#217 established the conversion
efficiency as the converged quantity; #219 retracted the superseded rotating-field
study), so Fig 4's question was already being superseded from that direction.

## Status of the figure

Fig 4 as drawn shows a strong ±Ω asymmetry that the current code does not
reproduce — and the asymmetry was never a chirality measurement in the first
place, because ±Ω at fixed `Bz` is not a reflection.

**It should not be redrawn from either dataset.** The true mirror, (Ω, B_z)
flipped together, is exactly antisymmetric by construction — verified to six
digits — so it carries no information either. A chirality figure needs a different
observable; #217's conversion efficiency is the candidate already on the table.
