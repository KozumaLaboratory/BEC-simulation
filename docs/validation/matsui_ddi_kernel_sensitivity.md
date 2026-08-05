# The Fig. 4B dip centre is set by the DDI kernel treatment, not by the couplings

> **FROZEN 2026-07-31.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Session S-A6 follow-up, 2026-07-31. Producing commit `34040527`, UGE 8307517
task 9, exit 0, 100 points. Type A (code-to-code sensitivity) except where
marked.

## The question

After PR #204, two discrepancies with Matsui et al.'s published simulation
survived every cheap explanation (resolution, ramp shape, loss, ground-state
choice, field jitter):

- dip centre **−2.138 nT** against their **−2.549** — ours 16 % smaller
- `N_{−6}` **~20 % lower at every field** — ours transfers more

Those point opposite ways. Both scale with `c_dd·n`, so a coupling or density
error moves them **together**. Something was raising the off-diagonal drive
relative to the diagonal shift.

## The couplings are exact — that is now measured, not derived

`scripts/validation/matsui_static_ddi_compare.jl`, no dynamics:

| | theirs, reduced to our units | ours | ratio |
|---|---|---|---|
| DDI coefficient | 211.021419 | **211.021446** | **1.000000** |
| contact `c_total` | 4687.2663 | **4687.2663** | 1.000000 |

Their `cdd = 1e-7 (g_F μ_B/ħ)² · 2mN/aHO` times their `4π` kernel, divided by the
`2√2` that maps their length unit onto ours, reproduces
`compute_c_dd_dimless` to **seven significant figures**. The `μ₀/4π` ↔ `4π`
cancellation of §0.3.3 and the `√2` of row 8.1 are verified end to end
numerically, not just algebraically. Rows 3.2/3.3 and 4.1–4.6 are closed.

Scale check: `c_dd·n_peak = 0.751 ħω_ref = 5.08 nT`, against measured dip
centres of 2.1–2.6 nT. The offset **is** the dipolar mean field, at the right
order, in both codes.

## The factorial

25 fields (−10 … +2 nT) × `trunc_radius` ∈ {auto, none} × `padded` ∈ {true,
false}. Centre from the parabolic vertex; the corrupted `point_001` is dropped.

| arm | centre [nT] | min `N_{−6}` | `N(−5 nT)` | `N(0 nT)` |
|---|---|---|---|---|
| auto + padded — **our default** | −2.138 | 9760.1 | 11629.3 | 11162.9 |
| auto + unpadded | −2.148 | 9774.8 | 11634.0 | 11177.8 |
| none + padded | −2.148 | 9958.5 | 11807.8 | 11286.8 |
| **none + unpadded — bare periodic** | **−2.484** | 10228.2 | 11841.2 | 11641.6 |
| *Matsui simulation* | *−2.549* | — | *13929.6* | *14358.1* |

**The centre is a kernel-treatment effect.** Turning off both image controls
moves it −2.138 → −2.484, closing **84 %** of the 0.41 nT gap. The couplings did
not change; nothing else did either.

**And it moves the centre without moving the transfer.** Across the four arms the
centre swings 16 % while the minimum population swings 4.8 %. That is exactly the
predicted signature — the `k=0` bin and the long-wavelength mollifier touch only
the **diagonal** component (their `DD1(0) = DD2(0) = 0`), so they shift the
resonance without changing the off-diagonal drive.

## What this does and does not settle

**Settled:** the two discrepancies are *separate*. The centre gap is the dipolar
kernel's image/long-wavelength treatment. The ~20 % population gap is not — even
the bare arm gives 11841 against their 13930 at −5 nT, still 15 % apart. Chasing
them as one number was wrong.

**Not settled — and the direction matters:** our default is the *more accurate*
kernel. Padding plus the spherical cutoff removes the periodic images exactly;
the physical system is a cloud in free space. Matsui's dynamics **does** pad
(`sn = 2` in `time.f90`), which nominally corresponds to arm 3 (−2.148), yet
their published centre sits at −2.549, past even our bare-periodic arm. So the
mechanism is not pinned down: what is established is the **sensitivity**, not
which side is right. Two candidates:

1. Their padding samples the *analytic* continuum kernel on the padded grid
   rather than the DFT of the truncated real-space kernel, so it is not
   image-free — it lands somewhere between bare-periodic and free-space, and
   their box (36.2 a_ho) differs from ours (16 a_ho), which changes where.
2. Something else in their long-wavelength treatment, e.g. `DD0(k=0) = −4π/3`
   against our `0` — bounded at 5×10⁻³ nT for *their* box in §0.3.3, but that
   bound scales as `1/V_pad` and was never evaluated for theirs vs ours jointly.

**If it is (1), our −2.14 nT is the better number for this model and their
−2.55 carries a ~0.35 nT kernel artefact.** The experiment cannot arbitrate: its
field axis carries a stated offset error of up to 10 nT.

## Next

- Reproduce their padded convolution exactly (analytic kernel sampled on the
  `sn = 2` grid, no cutoff) as a fourth kernel mode, and re-run. That
  distinguishes candidate 1 from candidate 2 in one arm.
- The ~20 % transfer excess is untouched by all of this and is now the separate
  open question.
