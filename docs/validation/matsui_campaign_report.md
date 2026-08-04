# Matsui et al. (2026) — campaign report

Single entry point for what this campaign established, excluded, and could not
close. Matsui et al., *Science* **391**, 384 (2026) / arXiv:2504.17357; code and
data from Zenodo 17303925, CC-BY-4.0.

Every claim below carries its verification type. **A** = code correctness (our
code against theirs, or against itself). **B** = physics agreement (closed forms,
limits). **C** = model fidelity (against published experimental data). "Our code
reproduces their simulation" is A. "Their simulation misses their experiment" is
C. They are not interchangeable and no amount of A implies C.

Detail lives in the companion documents, listed in §7. This file is the summary
and the verdict.

---

## 1. What is settled: we reproduce their simulation (type A)

Three independent published datasets, agreeing at the level their own numerical
parameters could be expected to reproduce:

| dataset | observable | agreement |
|---|---|---|
| Fig. 4B, 45 fields | m = −6 population per field | per-field rms **1.1 %** |
| Fig. 4B | half-depth dip **width** | 12.740 vs 12.752 nT = **0.10 %** |
| `dataset_fig1/F.txt`, 5 ms | column density, 5 observables | **0.3–4 %** |
| Fig. 2C, 40 ms | 5 component populations | rms **0.0075** |

The Fig. 2C criterion (< 0.02) was recorded in the config before launch.

Two of these deserve emphasis:

- **The width is the offset-invariant number.** A dip *centre* moves under a
  field offset; a *width* does not. The paper quotes up to 10 nT of offset error
  on that axis, so the width is the only part of the dip comparison that is a
  measurement at all. Widths must be compared over **identical** abscissae — the
  same dataset gives 15.02, 13.07 or 11.79 nT depending on the window, and a
  half-step mismatch alone inflated an apparent disagreement from 0.10 % to
  1.04 %.
- **The depolarisation spread agrees to 0.3 %** (0.355 vs 0.356) — measured on
  column density on both sides, because `F.txt` is a y-integrated column and a
  y = 0 slice gives a different number. That spread is the quantity the paper
  names as the origin of the dip width.

## 2. Their shipped code differs from their paper in four places (type A)

Read out of `time.f90` and `setup_parameters`, not inferred:

| item | shipped code | paper |
|---|---|---|
| atom number | `Ntot = 3.5e4` | 5e4 |
| `c₁/c₀` | `cc1 = cc0 * 1.d-2/36.d0` = **1/3600** | `c₁ = (1/18)πℏ²a₁₂/M` ⇒ **1/36** |
| quadratic Zeeman | `ZeemanQ = 1.0` Hz, literal, never updated | not stated; ~10⁻⁶ Hz at 2.6 nT |
| `Ehf` (Eu branch) | `1.772d+9` = Na²³ hyperfine splitting | — |

`Ehf` is harmless: `ZeemanQ` is supplied directly, so `Ehf` never enters the q
calculation and has no other use.

**`N = 3.5e4` is the value their runs used**, while the published curves total
49999.9 — the run took 3.5e4 couplings and the output was normalised to 5e4 for
plotting. Six independent observables support this: transfer fraction, rms
radius, aspect ratio, m = −6 column fraction, depolarisation spread, and the
whole Fig. 2C time series. Every one degrades at 5e4 — the Fig. 2C rms goes from
0.0075 to 0.109.

**The shipped `c₁/c₀ = 1/3600` is excluded** by the 5 ms ring count in m = −4: it
produces one ring where the paper's Fig. 1E shows three.

## 3. What the parameters can and cannot be constrained to

| parameter | status | how |
|---|---|---|
| `N` | **3.5e4**, six observables | §2 |
| `c₁/c₀` | **0.0139 < r ≤ 0.0278**, no upper bound below r = 1.0 | ring count at 5 ms, resolution-independent across 32/64/128³ |
| `c₁/c₀` | **not the answer to the residual** | worse in *both* directions across a factor of 8 in r |
| `K₃` | **2.6e-28 cm⁶/s** for m ≠ −6, calibrated to 26 %/40 ms, zero free parameters | total-number decay |
| `q` | **unresolvable** at one field | §5 |

**The ring count is the instrument that worked.** A count carries no error bar
and no calibration; it rejected the shipped `c₁` in one run and was identical
across three grids. Twenty-four continuous-observable arms decided nothing. Note
the trap that cost a day: `Ψ₋₅ ∝ z·ρ·e^{−iφ}` has a node at z = 0, so integrating
along z destroys the structure and returns one ring for every `c₁`. The paper's
three rings are in a **side** view.

`c₀` and `c₁` are not independent — `a_s` fixes both through
`c₀ + 36c₁ = c_total` — so any `c1_ratio` arm moves `c₀` too and both must be
quoted. The `r = −1/36` pole, where `c₀` flips sign, is far from every value used
here but sits inside the schema's allowed range.

## 4. Their model misses their experiment, and it is not a parameter (type C)

**Fig. 4B.** Per-field residuals against the experiment: rms **15.1σ** for us,
**14.4σ** for their published curve, and the two residual patterns are
**correlated at 0.9705**. Both over-transfer near resonance (−37σ at +1.8 nT) and
under-transfer in the wings (+12σ at +8.8 nT). No single mechanism fixes both
signs; the best a loss model achieves is 15.1 → 11.3σ. Widths: 12.740 (ours) and
12.752 (theirs) against **11.800 ± 0.279** experimental.

**Fig. 2C.** In absolute atom number, 1–40 ms:

| component | their sim vs experiment | ours vs experiment |
|---|---|---|
| m = −6 | 0.0942 | 0.0926 |
| m = −5 | 0.053 | 0.0473 |
| m = −4 | 0.129 | 0.1497 |
| m = −3 | 0.043 | 0.0497 |
| m = −2 | 0.158 | 0.1667 |

That is the paper's own split: m = −5 and m = −3 agree, m = −4 and m = −2 do not,
and the paper attributes the latter to its model being loss-free.

**The loss confirms exactly that split and cannot fix m = −6.** Adding the
calibrated `K₃` improves m = −4 by 23 % and m = −2 by 31 % — the two components the
paper names — and makes m = −6 **6 % worse**. The reason is structural: atoms leave
m = −6 by *transfer* and only become vulnerable afterwards, so loss raises the
m = −6 *fraction* while lowering its *count*. A larger `K₃` widens the gap.

Of the 0.4297 total deficit at 40 ms, **0.0 % is in m = −6** — the experiment holds
0.0236 *more* m = −6 than the loss-free model. That is the paper's statement
("three-body collisions involving atoms **not** in the m = −6 component") made
quantitative, and it was readable off the published file without any run.

## 5. The stopping point: the field systematic dominates

`q` looked like the answer. At B = 2.6 nT, setting q = 0 (the physical value, vs
their literal 1 Hz) improves m = −6's rms from 0.0926 to 0.0726.

It is not measurable. `q` also shifts the resonance **position** — 0.68 nT per
Hz — so that arm changed the detuning too. Bracketing q = 0 across that shift:

| B [nT] | 1.92 | 2.60 | 3.28 |
|---|---|---|---|
| m = −6 rms | 0.1142 | **0.0726** | 0.1080 |

The observable moves **0.0416 over 1.36 nT of field**. The `q` effect being
interpreted is **0.0200 — 48 % of that** — and the published offset error on the
field axis is **±10 nT**, 7.4× the range scanned.

**A single-field time series cannot constrain any of these parameters.** The
systematic binds the axis held *fixed*, not only the one being scanned. It had
been written down correctly for the *dip* comparison — which is why the width,
not the centre, is what §1 quotes — and a single-field cut through that dip
inherits the offset with nothing to average it out.

**What is left is model deficiency, not a parameter.** Their simulation misses
their experiment by the same amount ours does, in the same direction, correlated
at 0.97. Nothing on our side closes that, and nothing in the published data
distinguishes candidate mechanisms below the systematic.

## 6. Measured and rejected

Each of these was a candidate explanation, and each was closed with a number
rather than an argument.

| candidate | effect | verdict |
|---|---|---|
| spin-dependent 3-body loss on the 5 ms dip | width −0.016 nT | only 4.7 % of the loss has acted by 5 ms |
| unpadded DDI kernel | centre 0.0187 nT | below the 0.005 nT criterion set before the run |
| field jitter at 1 nT | none resolvable | — |
| ramp-knot transient (3.6 nT during ramp) | predicted +0.0245 nT, **measured −0.0002** | a DC-equivalent average is not what a resonance responds to |
| integrator `dt` | 0.0001 nT | the first estimate, 0.040 nT, came from a save grid that missed the final step |
| custom sysimage | 8.7 % *slower* | CUDA is both a `[deps]` entry and the `[extensions]` trigger |

## 7. Corrections issued during this campaign

Recorded because each was expensive and each has a structural preventive now in
`CLAUDE.md`.

1. **Fitted the experiment without reading the paper.** 24 × 45-point GPU scans,
   ~3 h, every premise wrong — atom number, thermal fraction, the provenance of
   `c1_ratio`, the loss mechanism, the origin of the width, and a 10 nT
   systematic on the field axis. All six were in Results and Appendices D/E.
   → gate 1.
2. **Normalised away the quantity under test.** The experimental CSV carries
   absolute atom numbers; row-normalising divided out the measured decay and
   inflated m = −6's discrepancy from 0.094 to 0.263, making the best-agreeing
   component look like the worst. → §4, and the normalisation rule in `CLAUDE.md`.
3. **Compared widths across mismatched windows.** Their grid is 0.5 nT inside
   ±10 and 1 nT outside; a half-step offset turned 0.10 % into 1.04 %.
4. **Read a residual at one point on an axis with a large systematic.** §5. Six
   GPU arms to establish that nothing there was resolvable. → gate 3.
5. **Integrated the ring count along z**, killing the very node that carries the
   structure. Returned one ring for every `c₁`.
6. **Patched a parameter at one of two sites.** `c1_ratio` and later `Bz`: the
   effective field comes from the *scan override*, and the inline pipeline value
   is overwritten. Both are now asserted at generation time.

## 8. Companion documents

| file | content |
|---|---|
| `matsui_experiment_parameters.md` | the paper's own numbers, quoted — read this before any type-C claim |
| `matsui_reproduction_status.md` | the reproduction ladder and its history |
| `matsui_residual_root_cause.md` | the Fig. 4B residual, per-field, with the σ decomposition |
| `matsui_fig2c_absolute_numbers.md` | Fig. 2C: reproduction, the normalisation correction, the loss arm, the sensitivity table |
| `matsui_ddi_kernel_sensitivity.md` | the dip centre is set by the DDI kernel treatment, not the couplings |
| `matsui_published_state_comparison.md` | `dataset_fig1/F.txt` is their own 5 ms output; how to read it |
| `matsui_author_query_draft.md` | the questions only the authors can answer |
| `runs/matsui_fit/README.md` | every arm, live and retracted, with what it measured |

## 9. What would move this forward

Not runs. The two things that would are:

- **The authors' answers** to the four code/paper discrepancies in §2 —
  specifically whether `ZeemanQ = 1.0` Hz and `Ntot = 3.5e4` are the values
  behind the published figures. `matsui_author_query_draft.md` is written.
- **An observable invariant under a 10 nT field offset.** The width is one and it
  already agrees to 0.10 % between the two simulations. A ring or vortex count in
  the experimental images would be another, and would not need the field axis at
  all.

Anything measured at a single field, against a residual smaller than the field
systematic, will reproduce §5.
