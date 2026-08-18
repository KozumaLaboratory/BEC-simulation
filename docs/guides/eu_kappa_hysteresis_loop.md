# The κ-dependent hysteresis loop in weak-field ¹⁵¹Eu — one number for the demagnetisation experiment

> **Status: campaign in progress (opened 2026-08-18).** §1–§3 were written BEFORE
> any compute and are the pre-registration: the axes, the systematics, and the
> rejection criteria. §4 onward is filled in from measurements as they land, and
> every row there names the run that produced it. Predecessor:
> `docs/guides/eu_adiabatic_protocol.md` (FROZEN 2026-07-28) — read it for how the
> prediction was established; read this for the loop width.

## 1. What is being delivered, and why it is worth the compute

The transition **order is set by the trap oblateness** κ = ω_z/ω_⊥, with a
tricritical point near κ_tc ≈ 0.95. The falsifiable statement is a comparison the
lab already has the apparatus for:

> **The same field ramp at two trap aspect ratios gives a hysteresis loop at
> κ ≳ 1 and none at κ ≤ 0.9.** No scattering length has to be known.

The predecessor campaign measured that loop with **one end open**. At κ = 1.8 the
falling leg converted sharply at 27.4 µG, but the rising leg's flower branch
survived every rate out to the edge of the scanned window, so the loop was
reported as **[≈27, > 100] µG** — a bound, not a width. Three further defects made
the two sides not directly comparable:

| defect | why it matters |
|---|---|
| the legs spanned **different windows** ([65,100] rising, [64,20] falling) | the 64→65 µG horizontal break in the figure is missing data; a width cannot be read across it |
| κ = 1.8 ran at pin ε = 0.001 and its κ = 0.8 control at ε = 0.002 | the loop was attributed to κ while the symmetry-breaking field also moved by 2× |
| the rate scan was indexed by τ over **asymmetric spans** | at fixed τ a wider span is a *faster* ramp, so two legs at "the same τ" were at different rates |
| loop width at **one grid** (32³) | the width is a spinodal separation, and spinodals are where mean field is most resolution-sensitive |

This campaign closes all four and reports a single width with its uncertainty, plus
the Stern-Gerlach signature and the shielding requirement.

**Two numbers that are easy to mis-quote, and this document must not:** there is
**no universal transition field** (the band is 40–62 µG and rises with κ, so a
spherical trap swept through 40 µG measures a *crossover* and sees no hysteresis by
construction), and **58–60 µG is saturation, not a transition** (E and dE/dB are
smooth there; χ = −dF_z/dB collapses 0.11 → 0.002).

## 2. Axes, and the settings held fixed

Every axis carries **at least two points**, so each one's effect on the loop width
is measured rather than assumed. That is the sensitivity table, laid out before the
scan rather than after it.

| axis | points | what it separates |
|---|---|---|
| ramp rate | 6, spanning ~2.5 decades | lag vs bistability vs crossover — the verdict |
| κ | 1.8 and 0.9 | whether the loop is attributable to κ at all |
| grid | 32³ and 64³ | resolution sensitivity of the spinodal separation |
| pin ε | 0.002 and 0.02 (0.135 and 1.35 µG) | the shielding requirement |
| dt | 0.002 and 0.001 at the fastest rate | that the fastest arm is still resolved in time |
| τ → ∞ | static branch continuation | the lag-free limit the rate scan must saturate to |

Held fixed, and load-bearing:

- **`split_step_midpoint!`**, not plain Strang: with DDI active the mean field is
  frozen at the V-step boundary, making plain Strang *first order in time*, which a
  long ramp accumulates.
- **Orszag 2/3 dealiasing OFF.** At 32³ / box 24 the cutoff is k = 2.62 while the
  occupied band reaches k ≈ √(2µ) ≈ 4.3, so the filter removes physically occupied
  modes: |ψ|² bleeds ≈ 3×10⁻⁶ per step, ≈ 17 % over a long ramp. Off, the drift is
  5×10⁻¹³. It stays off at 64³ too (where the cutoff *would* clear the band) so the
  two grids differ in one thing only.
- **dt = 0.002**, **box 24**, **unpadded DDI**, **q = 0**, **LHY off**.
- **One pin for everything: ε = 0.002 p-units = 0.1352 µG.** Each seed is converged
  at that ε and the ramp holds it, so the seed is stationary at t = 0 and the pin
  doubles as the residual transverse lab field.
- **Seed/preset epoch assertion** on every seed: a state from another parameter
  epoch is not stationary, and the rate scan would be measuring that transient.

### Why unpadded DDI, when padded is the more accurate kernel

The bare periodic kernel carries a 2–5 % dipolar field error that is flat in
resolution and **anisotropic** (the square lattice of periodic images breaks
rotational symmetry), which is uncomfortable on a campaign whose whole subject is
the trap aspect ratio. It is used anyway, for one reason: the ramp drivers and the
existing converged states are unpadded, and a seed converged under a different
kernel is **not stationary** under the ramp that consumes it — that transient would
contaminate every arm. Consistency inside the campaign is what a loop width needs.

The size of the systematic is known and is common-mode in the difference the result
is read from (measured 2026-08-06): the total energy moves 4.1×10⁻³ between
kernels, but both branches move together and B_eq shifts **0.20 µG = 0.33 %**;
⟨F⊥⟩ is a functional of ψ alone and agrees per state to 0.3 %. A future epoch that
re-converges *everything* padded is the clean fix and is out of scope here.

## 3. Rejection criteria — written down before launch

Fixed in advance, so the interpretation is not chosen after the runs finish.

1. **A loop width is reported as a number only if** both legs convert *inside* the
   common window at ≥ 2 rates. If either leg does not convert, the result is a
   **lower bound** and must be labelled with which end is open. This is the
   predecessor's exact failure and it may not be repeated silently.
2. **Conversion is read as depth, never as a slope ratio.** A branch conversion
   moves ⟨F⊥⟩ by ≈ 2; canting along one branch moves it by ≤ 1. Threshold: the
   largest change in ⟨F⊥⟩ across any 8 µG window, in the direction the branch
   change must go, ≥ 1.5. A ratio like peak ÷ median |dF⊥/dB| divides by the
   typical slope and is rejected: it scored the κ = 0.8 *crossover control* 10.2 on
   a span of 0.76 — above the genuine κ = 1.8 conversion's 8.0 on a span of 2.92.
   `scripts/eu_hysteresis/loop_width.jl` refuses to report until it has passed a
   synthetic step it must detect and three curves it must not (whole-window
   canting, that small-bump ratio trap, pure noise).
3. **The verdict is named from the rate scan, not from one ramp.** Width shrinking
   toward zero as the ramp slows ⇒ dynamical lag. Width saturating ⇒ bistability,
   and the plateau *is* the mean-field spinodal separation. No conversion at any
   rate ⇒ crossover. Saturation means ≤ 10 % change between the two slowest rates.
   Two converged minima with a barrier are **bistability and not by themselves a
   first-order transition** — ferromagnet coercivity is the counter-example.
4. **The κ = 0.9 control must show depth < 1.5 at every rate.** If it converts, the
   prediction that the loop is attributable to κ has failed, and that is the
   reported result.
5. **64³ agrees if the loop width matches 32³ within 15 %.** Otherwise the
   disagreement is itself the number, reported as such.
6. **A static cell may not mark a spinodal if its order parameter is still moving.**
   |∇E| does not certify a minimum on this soft manifold — 3.6×10⁻⁴ was once 0.59
   off in ⟨F⊥⟩ — so every cell is polished a second time and cells with
   |Δ⟨F⊥⟩| > 0.02 are excluded. A cell whose L-BFGS `stop_reason` is `max_steps`
   (still descending when it ran out of iterations) is excluded too; one that
   stopped at the line search's energy-comparison floor is not.
7. **An unconverged reference is worse than none**, because it looks like a number.
   Every seed reaches the library gate |∇E| ~ 1e-5 via the ε ladder; a fixed pin
   stalls at ~1e-2 here, four orders above it.

## 4. Instruments

| what | where |
|---|---|
| static branch continuation → spinodals, τ→∞ target | `scripts/eu_hysteresis/branch_continuation.jl` |
| rate scan, both legs over one window | `scripts/eu_adiabatic_ramp_protocol.jl` (`AR_RATES`, `AR_SEED_*_FILE`) |
| loop width by conversion depth, with its controls | `scripts/eu_hysteresis/loop_width.jl` |
| figures | `scripts/viz_eu_adiabatic_ramp.py` (`--branches`, `--prefix`) |
| TSUBAME submission | `scripts/eu_hysteresis/submit_{smoke,branch,ramp}.sh` |

Run the smoke before any production launch; it renders every path in ≤ 2 h on an
H100 and ends with a negative control that must refuse.

## 5. Results

*(filled in as runs land; each row names its run directory)*

## 6. Limits

- **T = 0 mean field, no thermal or technical noise.** The measured loop is an
  **upper bound** on what an experiment sees: noise and finite temperature nucleate
  the stable branch early and narrow the loop.
- **LHY off** (#337). The F=6 dipolar-spinor ε_LHY has no usable implementation at
  the production sign; the seeds were converged without it, so the campaign is
  internally consistent and inherits that model limitation.
- **Unpadded DDI**, as argued in §2.
- **The pin is far below a realistic residual field** (0.135 µG). §2's ε axis
  measures the loop's sensitivity to that; see also #340 for the shielding
  specification proper.
- The parent campaign's phase labels are mean-field-only and provisional.
