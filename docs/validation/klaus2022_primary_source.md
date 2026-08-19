# Klaus et al. 2022 — primary-source extraction and model selection

**Status:** gate-1 document for issue #345 (close the type-C gap on
"Klaus 2022 / magnetostirring vortex nucleation").
**Written before any compute**, per CLAUDE.md "Before computing — five gates".

Primary source, read in full (main text + Methods + Extended Data), not a
summary of it:

> **Lauritz Klaus**, Thomas Bland, Elena Poli, Claudia Politi, Giacomo
> Lamporesi, Eva Casotti, Russell N. Bisset, Manfred J. Mark, Francesca
> Ferlaino, *"Observation of vortices and vortex stripes in a dipolar
> Bose–Einstein condensate"*, **Nature Physics 18, 1453 (2022)**,
> doi:10.1038/s41567-022-01793-8, arXiv:2206.12265.

Local flattened copy of the full text used for the quotes below:
`scratchpad/klaus.txt` (from `ar5iv.labs.arxiv.org/html/2206.12265`). Every
quantity in §1 is quoted; nothing here is inferred from a campaign note.

---

## 0. The species is ¹⁶²Dy

> "We explore this protocol using a dipolar BEC of ¹⁶²Dy atoms."
> "We always consider ¹⁶²Dy, such that a_dd = 129.2 a₀."

`test/workflow/test_klaus_validation.jl` runs **Dy164**. That smoke is a
plumbing guard for the magnetostir wiring and is not claimed to be this
experiment, but the species is one of the things it does not share with the
paper — see §5.

## 1. Per-figure parameter table

Everything the paper states, split by figure, because the simulations do **not**
all use the same numbers. Nothing below is an average of the rows.

| | Fig. 1c (AR vs Ω) | Fig. 2 (vortex images) | Fig. 3b (𝒩ᵥ(t)) | Fig. 4a (stripe GS) | Fig. 4b–c (stripe dynamics) | Ext. Data Fig. 3 |
|---|---|---|---|---|---|---|
| a_s (sim) | 110 a₀ | 112 a₀ | 110 a₀ | 109 a₀ | 109 a₀ | 112 a₀ |
| (ω_⊥, ω_z)/2π sim | [50, 130] Hz | [50, 150] Hz | [50, 130] Hz | [50, 130] Hz | [50, 130] Hz | [50, 150] Hz |
| N (sim) | 15000 | 8000 | 10000 | 10000 | 10000 | 8000 |
| Ω | ramp to Ω_f, Ω̇ = 2π×50 Hz/s | 0.75 ω_⊥ | 0.75 ω_⊥ | 0.75 ω_⊥ (rotating frame) | 0.75 ω_⊥ | 0.75 ω_⊥ |
| \|B\| (exp) | 5.333(5) G | 5.333(5) G | 5.333(5) G | 5.323(5) G | 5.323(5) G | 5.333(5) G |
| protocol | 1 s ramp (dashed) / 2 s ramp (solid) | sudden start, hold t_Ω | sudden start, hold t_Ω | imaginary time with Ω L̂_z | 500 ms constant rotation | sudden start |

Common to all:

- θ = 35° from ẑ, held fixed through the whole sequence ("the magnetic field
  unit vector, **B̂**, is tilted by an angle of θ = 35° with respect to the z
  axis during the whole sequence").
- a_dd = 129.2 a₀ (¹⁶²Dy). ⇒ ε_dd = a_dd/a_s = 1.174 (110 a₀) … 1.185 (109 a₀).
- Experimental trap: (ω_⊥, ω_z) = 2π×[50.8(2), 140(1)] Hz — **the simulations
  do not use the measured trap.** Ext. Data Fig. 3 quotes the measured
  ω_t = 2π×[50.7(1), 50.8(1), 129(1)] Hz against a simulation at (50, 50, 150).
- Experimental N ≈ 2×10⁴ condensed atoms after preparation; sims use a fixed
  8000 / 10000 / 15000 and do **not** model the observed atom loss.
- Initial noise: complex Gaussian on single-particle modes with
  ⟨|α_n|²⟩ = (e^{ε_n/k_BT} − 1)^{−1} + ½ at **T = 20 nK**, restricted to
  ε_n ≤ 2k_BT.
- LHY: γ_QF = (128ℏ²/3m)√(π a_s⁵) Re{𝒬₅(ε_dd)},
  𝒬₅ = ∫₀¹du (1 − ε_dd + 3u²ε_dd)^{5/2}  (Lima–Pelster).

### The numbers to be reproduced

**Registered, as of 2026-08-19, in `refs/klaus2022.toml`** — the second source
in a directory whose first file said to wait for one before treating it as a
registry. `ref(:klaus2022, :omega_c_over_omega_perp)` and friends are what
`scripts/klaus2022_reproduce.jl` now reads; the values below are the same
numbers with their prose. Gated by `test/validation/test_klaus2022_ref.jl`.

One consequence worth stating here rather than only in the TOML: every Klaus row
is `read_off`, because the paper ships no re-measurable data record. `arbitrates`
is derived as `measured && isempty(disqualified_by)`, so **none of these numbers
can arbitrate, and a type-C `Claim` against them is unconstructible.** This
document therefore records a *reproduction*, not a `Claim(:C)`. The distinction
is now enforced by a constructor instead of resting on how the sentence is
phrased.

| Quantity | Published value | Figure |
|---|---|---|
| Magnetostricted aspect ratio, no rotation | AR = 1.03 | Methods A.4 |
| Onset of rapid AR growth | ≈ 0.6 ω_⊥ | Fig. 1c |
| **Critical stirring frequency** | **Ω_c ≈ 0.74 ω_⊥** (AR collapses to ≈1) | Fig. 1c |
| Stripe-state ground-state AR | AR = 1.08 | Fig. 4a |
| **Number of vortex stripes** | **3** ("the vortices align along three stripes") | Fig. 4b2 |
| Stripe orientation | along B̂ ("the same orientation as set by the magnetic field") | Fig. 4b3 |
| FT of residuals, θ = 35° | discrete peak pair at the inter-stripe k | Fig. 4b3, c3 |
| FT of residuals, θ → 0° | **homogeneous ring** (no preferred orientation) | Fig. 4d3, e3 |
| First clear vortices | t_Ω = 314 ms | Fig. 2 |
| 𝒩ᵥ before instability | < 1 for t_Ω < 200 ms | Fig. 3b |
| 𝒩ᵥ saturation (experiment) | average ≈ 3, max 6 | Fig. 3b |

## 2. Systematic errors, stated before any residual

- **Field magnitude:** long-term stability ΔB = ±1 mG; shot-to-shot ΔB = ±5 mG.
- **Field magnitude vs azimuth:** "small deviations as a function of φ of
  Δ|B| < 20 mG, which **we did not correct**". Tilting to θ = 35° shifts |B| by
  ≈ 10 mG (this one *is* corrected).
- **Scattering length:** a_s = **111(9)** a₀ — a ±8 % systematic, and the
  paper says a_bg was "empirically fixed by measuring the magnetic field value
  at which the supersolid transition occurs and comparing it with the
  corresponding critical a_s predicted from simulations". **a_s is a fitted
  parameter, fitted against simulations of this same family.** It is therefore
  not available as a free knob for us, and no agreement obtained by tuning a_s
  within ±9 a₀ is evidence of anything.
- **Trap:** AR_trap < 1.006; deliberately smaller than the AR = 1.03
  magnetostriction it must not fake.
- **Atom number:** the bimodal fit "breaks down" once vortices/spirals appear,
  so the published N at late times is not measured.

**Consequence for the axis we scan.** ε_dd = a_dd/a_s inherits the whole ±8 %
a_s systematic: ε_dd = 1.174 ± 0.095. Any claimed effect of ε_dd smaller than
that spread is not a measurement. The **discrete** observables (stripe count,
ring-vs-peak in the FT) do not inherit it in the same way, which is exactly why
they arbitrate here and AR does not.

## 3. Is the published theory curve the same observable as the published data?

Asked because CLAUDE.md requires it, and the answer is **no for the vortex
number** — the single most citable number in the paper.

- **Fig. 1c (AR vs Ω): same observable, different system.** Theory runs
  (50, 130) Hz / N = 15000 against an experiment at (50.8, 140) Hz and N ≈ 2×10⁴
  decaying. The paper itself flags a residual: "The stability of the 1 s ramp
  exceeds the experimentally observed critical frequency", attributed to
  rotation asymmetries absent from the simulation. **The reference
  implementation does not reproduce Ω_c exactly either.**
- **Fig. 3b (𝒩ᵥ(t)): NOT the same observable as a raw simulation vortex count.**
  The theory line is produced by pushing the simulated density through a
  deliberate degradation — 2×2 binning, Gaussian white noise of variance 0.01,
  σ = 1 px blur — and then through the same detector as the experiment. The
  paper measures the gap this opens: between 600 and 700 ms the **detected**
  number is ≈ 9 while the **real** number of vortices in the same area is
  ≈ 33. Comparing our raw vortex count to the published 𝒩ᵥ ≈ 3 would be wrong
  by roughly an order of magnitude, in the direction that flatters a
  disagreement.
- **Fig. 4b/c (stripes): same observable**, and it is explicitly designed not
  to depend on resolving single vortices: "these observations do not rely on
  our ability to resolve individual vortices, as the stripes are an ensemble
  effect of many aligned vortices."

This is the CLAUDE.md "check the reference implementation against the data
before chasing a residual" gate, and it comes back: **the paper's own eGPE
misses the paper's own Ω_c on the high side, and its raw vortex count exceeds
its own detected count by ≈ 3.7×.** Neither gap is closable by a parameter.

## 4. Model selection — scalar eGPE, decided from three scale ratios

Numbers computed from this repo's own constants (`Dy162` in `ATOM_REGISTRY`,
`Units`, `compute_c_dd_dimless`, `scalar_lhy_coefficient`) at the Fig. 3b
parameters (a_s = 110 a₀, N = 10⁴, ω_ref = 2π×50 Hz). The computation is
`larmor_hierarchy` in `src/solvers/scalar_egpe.jl`, gated by
`test/validation/test_klaus_model_selection.jl` — the decision is *derived*,
not asserted here.

| Scale | Value at Klaus parameters |
|---|---|
| Larmor ω_L/2π (B = 5.333 G, g_J = 1.24, J = 8) | **9.256 MHz** |
| Mean field μ/h (contact TF, ε_dd = 1.17 ⇒ DDI comparable) | **526 Hz** |
| Trap ω_⊥/2π, ω_z/2π | 50, 130 Hz |
| Stir Ω/2π = 0.75 ω_⊥ | 38 Hz |

Ratios: **ω_L / μ = 1.8×10⁴**, **ω_L / ω_⊥ = 1.9×10⁵**, **ω_L / Ω = 2.4×10⁵**.

The spin therefore follows B̂(t) adiabatically with a non-adiabatic admixture of
order μ/ℏω_L ≈ 6×10⁻⁵, and |Ψ(r,t)⟩ = ψ(r,t)·|B̂(t)⟩_J to that accuracy. The
correct model is the scalar eGPE with a B̂(t)-tilted dipolar kernel — **which is
also the model the paper itself solves** (its Eq. 4 has no spin index).

Cost of the alternative, stated so the decision is not a preference:

- Spinor path in the lab frame: `p/ω_ref = 1.85×10⁵`, `p·F = 1.48×10⁶`, so the
  Zeeman substep needs `dt < π/(p·F) = 2.1×10⁻⁶` against a trap-scale
  `dt ≈ 2×10⁻³` — **≈ 950× more steps**, times **17 components** (J = 8) ≈
  1.6×10⁴× the scalar cost, to compute a spin sub-cycle that the adiabatic
  limit averages away.
- Spinor path in the rotating basis (`kind: rotating_basis`) removes the dt
  penalty but keeps the 17 components, and it *requires* `secular_ddi=true`
  (`ArgumentError` otherwise) — the secular limit **is** the adiabatic
  elimination. It would compute the same physics at ≥17× the cost, through a
  different Hamiltonian than the paper's.

**Decision: scalar eGPE.** Recorded before compute; if it is wrong, the failure
mode is a wrong Ω_c and a missing stripe structure, both visible in the
acceptance gates below.

## 5. What the existing smoke test is, and is not

`test/workflow/test_klaus_validation.jl` runs Dy164, 16×16×8, 500 ITP steps,
B_z = 0.819 G with a 4.52 ω_ref transverse drive, and asserts
`vortex_count >= 0` plus norm drift < 5 %. Against §1 it differs in species,
field magnitude, trap, atom number, stirring frequency, grid and duration, and
its assertions cannot fail on physics. Its own header says so. It is kept as a
plumbing regression guard for the spinor magnetostir path and is **not** the
type-C gate; it is not evidence about this paper in either direction.

## 6. Rejection criteria — written here, before launch

Both runs are declared rejected-or-accepted by these, and by nothing decided
afterwards. They live as the `ACCEPT` constants at the top of
`scripts/klaus2022_reproduce.jl`, which is also what applies them and what
writes the verdict — so the criterion cannot drift from the thing that enforces
it. (An earlier draft of this section promised two `runs/*.yaml` files carrying
`rejection_criterion:` blocks. Those were never written: a schema slot nothing
reads is the failure mode `metadata:` was deleted for, and the criterion is
only real where it is executed.)

**Run A — Ω_c from the aspect-ratio ramp (Fig. 1c).**
Single 1 s linear ramp Ω: 0 → ω_⊥ at Ω̇ = 2π×50 Hz/s, reading AR(t) → AR(Ω).

- **Accept** if the AR maximum followed by collapse to AR < 1.1 occurs at
  Ω_c/ω_⊥ ∈ [0.68, 0.86].
  The window is the published 0.74 ± 0.06, where 0.06 is not a statistical bar
  — it is the paper's own theory-vs-experiment gap on this quantity (their 1 s
  ramp is stable past the experimental Ω_c). Claiming tighter than the
  reference implementation's own residual would be claiming to have measured
  something the paper did not.
- **Reject the model selection** if no AR collapse occurs for Ω ≤ ω_⊥, or if AR
  never exceeds 1.3 before collapsing. Either says the magnetostirring is not
  driving the surface instability, which is a model-choice failure, not a
  parameter one.
- Not worth pursuing further than: Ω_c to ±0.02 ω_⊥. Below that the trap
  anisotropy the paper did not model (AR_trap < 1.006) and the 20 mG uncorrected
  azimuthal field ripple both bite.
- **Pre-registered null:** the magnetostricted AR at Ω = 0 must come out at
  1.03 ± 0.01. If it does not, the DDI kernel/tilt plumbing is wrong and Ω_c is
  uninterpretable regardless of where it lands.

**Run B — vortex stripes (Fig. 4b).**
500 ms constant rotation at Ω = 0.75 ω_⊥, a_s = 109 a₀, N = 10⁴, θ = 35°,
noise-seeded.

- **Accept** if the residual-image FT shows a **discrete peak pair** (not a
  ring) whose axis lies within **±20°** of B̂'s in-plane projection, and the
  stripe count from the peak wavevector is **3 ± 1**.

  *Re-registered 2026-08-18, before the run that is judged by it.* The original
  form of "peak pair" was `max/mean` of a 180-bin angular histogram over the
  annulus, thresholded at 2.0. That statistic **reads 6.8 on white noise**: the
  annulus holds a few hundred k-points, so each bin has ~2 counts and
  `max/mean` measures shot noise. It was caught by a synthetic negative control
  (`test/analysis/test_vortex_stripes.jl`), not by a production number, and the
  replacement thresholds below are set from the synthetic fixtures, not from
  any Klaus run. The first production stripes arm reported 12.5 under the
  broken statistic; that number is discarded, not reinterpreted.

  The replacement is the unbinned axis order parameter
  `|Σ w e^{2iφ}| / Σ w` over the annulus, whose null on isotropic power is
  `1/√N`. Accept requires **all** of:
  - `axis_order ≥ 5 × 1/√N` (fixtures: 6.75× for stripes, 3.06× for the same
    holes scattered);
  - `axis_order ≥ 1.6 ×` the value on the **t = 0 frame** — the magnetostricted,
    vortex-free ground state, whose envelope is elongated along B̂ exactly like
    a stripe pattern. Without this leg an ellipse passes as a stripe phase;
  - `radial_prominence ≥ 1.5` — a real peak in |k| rather than a flat annulus.
    Needed because `k_peak`, a power-weighted mean over a bounded window,
    returns roughly the window centre for a featureless spectrum;
  - axis within ±20° of B̂, and stripe count 3 ± 1.
- **Reject** if the FT is a homogeneous ring at θ = 35° — that is the paper's
  own θ = 0° control (Fig. 4d3) appearing where it must not, and it means the
  DDI anisotropy is not reaching the vortex arrangement.
- **Control that must also pass:** repeating with the field spiralled to θ = 0°
  must turn the peak pair into a ring. A stripe signal that survives θ → 0 is
  an artefact of the analysis, not the physics. This is the positive/negative
  control pair; without it a "peak" proves nothing.
- **Not** judged on: the absolute vortex count. Per §3 that observable is
  detector-limited in the publication, and comparing our raw count to it is a
  known ≈3.7× error.
- **Not** measured with the `vortex_detect` analyzer either. That one counts
  plaquette phase winding, which is a different observable from the paper's
  (a density-hole count on a blurred image) and is unreliable above |ℓ| = 1
  because a multiply-charged core aliases across neighbouring plaquettes. The
  stripe analysis here reads only the column density — never the phase — which
  is what makes it comparable to Fig. 4b at all. Detector calibration, with the
  pattern that must NOT be found paired to every pattern that must:
  `test/analysis/test_vortex_stripes.jl`.

## 6b. Result of the pre-registered null: it FAILED, and what that turned out to mean

**Measured 2026-08-18.** At the paper's stated parameters (¹⁶²Dy, a_s = 110 a₀,
θ = 35°, λ = 2.6, N = 10⁴) the ground state's in-plane aspect ratio is

| configuration | AR_xy |
|---|---|
| 64²×32, box 16 a_ho, plain FFT | 1.1486 |
| 96²×48 and 128²×64, same box | 1.1486 (identical to 5 digits) |
| 128²×64, 2× ITP steps | 1.1486 (step-converged) |
| 160²×80, box 20 a_ho | 1.1340 |
| 64²×32, box 16, zero-padded (2,2,2) | **1.1272** |

against the paper's **AR = 1.03**. The null in §6 said this must land in
[1.02, 1.04]. It does not, by roughly 4× in (AR − 1).

The null was written as a proxy: "if it does not, the DDI kernel/tilt plumbing
is wrong". That inference has since been tested directly, with sharper
instruments than the null itself, and **it is refuted**:

1. **Amplitude.** The scalar tilted kernel and the repository's independently
   gated spinor 6-FFT DDI convolution give the same E_dd to `rtol = 1e-10` on
   the same anisotropic density, for B̂ ∥ ẑ, B̂ ∥ x̂ and B̂ at 35°. Gated by
   `test/oracles/test_dipolar_magnetostriction_magnitude.jl`.
2. **Nulls.** AR_xy = 1.0000 at θ = 0 and 1.0000 at ε_dd = 0 — exactly, not to
   a tolerance.
3. **Magnitude against physics outside this repo.** The deformation is anchored
   to the exact dipolar Thomas-Fermi solution of O'Dell/Giovanazzi/Eberlein
   (`dipolar_tf_aspect_ratio`), which fixes κ = R_⊥/R_z from (ε_dd, λ) alone.
4. **Convergence and the periodic-image systematic** are both bounded above,
   at 0 % and 1.9 % respectively — an order of magnitude below the gap.
5. **Time-of-flight does not explain it.** Releasing the trap and expanding for
   the paper's 3 ms moves AR_xy the wrong way, 1.149 → 1.170.

So the gap is not plumbing. Read as a parameter statement, **AR = 1.03 at
θ = 35° corresponds to ε_dd ≈ 0.26** on our AR(ε_dd) curve (measured: 1.0344 at
ε_dd = 0.293), or to **θ ≈ 16°** at the published ε_dd = 1.174 (measured:
1.0484 at 20°). Both are ~4–5× from values the paper states repeatedly and
unambiguously. We cannot reconcile them, and this document does not pretend to.

**What this changes about the verdict, stated explicitly so it is not a
threshold moved after seeing the answer.** The §6 threshold is NOT relaxed:
the ar-ramp arm records `ar_static_verdict = FAIL` and it stays failed. What
does change is the *consequence* §6 attached to it — "Ω_c is uninterpretable" —
because that consequence was justified by the plumbing hypothesis alone, and
that hypothesis has now been measured and rejected by five independent
instruments. The remaining arms are therefore judged on their own
pre-registered thresholds, on the **discrete** observables (Ω_c, stripe count,
stripe axis, ring-vs-peak), which is what §6 declared them on in the first
place. The AR discrepancy is carried forward as an open, quantified
disagreement rather than being explained away.

## 6c. Run A result — Ω_c

Single 1 s ramp, 128²×64 over a 16 a_ho box, N = 15000, a_s = 110 a₀, θ = 35°,
1.6×10⁵ steps, 113 min. Norm drift 4.6×10⁻¹¹.

| | published | this work |
|---|---|---|
| onset of rapid AR growth | ≈ 0.6 ω_⊥ | 0.49–0.59 ω_⊥ |
| **AR maximum, i.e. Ω_c** | **0.74 ω_⊥** | **0.751 ω_⊥** raw, **0.759** period-averaged |
| peak AR | ~1.4 (Fig. 1c) | 2.36 |
| L_z injection onset | — | Ω = 0.62 ω_⊥, rising to L_z ≈ 10ℏ |
| AR at Ω = 0 | 1.03 | 1.177 (see §6b) |

**The threshold agrees to 1.5–2.6 %**, and the agreement does not depend on the
reduction: 0.751 from the raw AR, 0.759 after averaging over one rotation period
as the paper does ("to mitigate influences of trap anisotropies on the AR, a full
period at the final rotation frequency is probed"). That is the discrete-ish
quantity this arm was for — an instability threshold carries no calibration and
no error bar of its own. Worth noting that the paper's *own* 1 s-ramp simulation
is stable past its experimental Ω_c ("we partly attribute this discrepancy to
asymmetries of the rotation in the experiment"), so we sit on the same side of
0.74 that their simulation does, and by less.

Figure: `figures/klaus2022_ar_ramp.png` (raw + period-averaged, with the
published Ω_c and the un-reproduced AR = 1.03 marked).

**The pre-registered verdict is nevertheless `REJECT`, and stays recorded as
`REJECT`.** §6 defined Ω_c as "the AR maximum *followed by collapse to
AR < 1.1*". The collapse leg never fires, because AR starts at 1.177 rather
than the 1.03 the paper states — the same failure as §6b, propagated into a
threshold that was calibrated against it. The AR-maximum reading above is
therefore **post-hoc** on this run: it is the quantity the paper's own sentence
identifies ("suddenly, at Ω_c ≈ 0.74 ω_⊥, the AR abruptly collapses"), it is
baseline-free, and it was inside the pre-registered [0.68, 0.86] window — but
it was not the reducer declared before launch, and this document does not
promote it to one retroactively. `test_klaus2022_vortex_stripes.jl` pins both:
the recomputed AR-maximum location *and* the failed pre-registered verdict, so
neither can be quietly dropped.

## 6d. Runs B and C result — vortex stripes and the θ→0 control

128²×64, box 16 a_ho, N = 10⁴, a_s = 109 a₀, Ω = 0.75 ω_⊥, θ = 35°, T = 20 nK
Wigner seed carrying **3.2 % of N**. Stripes: 500 ms (44 min). Control: 600 ms
then θ spiralled 35° → 0 over 100 ms (60 min). Norm drift ≤ 3.5×10⁻¹¹.

| quantity | stripes (θ = 35°) | control (θ = 0°) | published |
|---|---|---|---|
| axis order / isotropic null | **4.67** | **1.04** | peak pair vs ring |
| axis order / vortex-free t=0 frame | **3.99** | 0.89 | — |
| axis vs B̂'s in-plane projection | **5.9°** | 33.5° (random) | "same orientation as set by B" |
| stripe count across the cloud | **3.43** | 3.62 (meaningless at the null) | **3** |
| radial prominence | 1.52 | 1.75 | — |

One negative result about the instrument, recorded because it was assumed the
other way round when the threshold was written: **`radial_prominence` does not
discriminate stripes from a smooth ellipse.** The vortex-free t = 0 frame reads
2.05 against the turbulent late state's 1.52 — a clean elliptical residual is
*more* single-scale than a turbulent one. It answers "is there a peak in |k| at
all", and the discrimination is carried entirely by
`axis_order / baseline` and by the θ→0 control.

**The control is the sharpest result.** At θ = 0 the order parameter sits at
`1.04 ×` its own isotropic null and the axis is random — that *is* Fig. 4d3's
homogeneous ring, and it is the strongest available form of the statement,
because the null is known analytically rather than assumed. Against it the
θ = 35° arm carries a 4.5× larger axis order aligned to within 6° of the field.
Together with the stripe count (3.43 vs a published 3) that is the published
structure: **vortices arranged in stripes along B̂, and no such arrangement once
the field is brought parallel to the rotation axis.**

The two arms share their seed and their protocol up to the ramp, so this is a
**paired** comparison — the curves are identical until t = 188.5 and diverge only
where θ moves. Figure: `figures/klaus2022_stripes.png`.

Both arms nevertheless return `REJECT` on their pre-registered composites, and
both stay recorded as `REJECT`:

- **Stripes** fails one leg: 4.67× null against a 5× threshold. The order
  parameter is strongest early (9× null over 0–100 ms, the spiral phase) and
  decays through the run. That is what the paper describes too — "turbulent
  dynamics ensue … this turbulence, however, inhibits the creation of a vortex
  lattice on these timescales" — and its Fig. 4c stripe signal is an **ensemble
  average of 115 frames between 700 ms and 1.1 s in the rotating frame**, not
  one realization at 500 ms. We under-ran the paper's own analysis window. A
  higher threshold met by a longer, ensembled run is the follow-up; raising the
  claim on this data is not.
- **Control** fails a threshold that was **unsatisfiable as written**: "≤ 0.6 ×
  the t = 0 baseline". The baseline is itself only 1.17× the null, so 0.6 ×
  baseline is 0.7 × null — *below the noise floor*, which nothing can reach.
  That is the degenerate-knob error in its own criterion, and it is recorded
  rather than re-registered: the thresholds were already re-registered once
  (§6, stripes), and doing it twice would make them a description of the answer.

**Window correction, and why it was not a goalpost move.** The control's
pre-registered window was "the last 20 % of the run", which for a 600 ms hold
plus a 100 ms spiral still contains 40 ms **at the full 35° tilt** — it does not
implement the control §6 declares. `scripts/klaus2022_reanalyse.jl` re-derives
both windows from the saved frames and reports both (on that contaminated
window the control reads 2.52× null, i.e. an axis that is really the tilted
segment leaking in). The same script reproduces the run's own reduction on the
pre-registered window to 1e-6, which is what makes it trustworthy. Each arm
persists its column-density frames, precisely so a window or metric change costs
seconds — the first stripe metric had to be replaced and that cost a 45-minute
re-run because only the reduced numbers had been kept. They land at

```
runs/klaus2022/{stripes,control}_frames.jld2
```

**and they are local, not in the repository** (48 MB, and `*.jld2` is
gitignored — which is also why that path is fenced here rather than written as
a citation: an untracked path makes a citation gate answer differently on the
machine that ran it and in CI). What *is* committed is
`klaus2022_results.json`: the reduced per-frame series, both windows, the
thresholds and the provenance. So the gate re-applies the criteria without a
run, but re-deriving a *new* metric needs either the local frames or a 1.7 h
re-run. The gate's `frames_path` assertion checks that a path was recorded, not
that the file is present on your machine.

## 6e. Summary of the type-C comparison

| published quantity | ours | agreement |
|---|---|---|
| Ω_c ≈ 0.74 ω_⊥ | 0.751 (raw) / 0.759 (period-averaged) | **1.5–2.6 %** |
| onset of rapid AR growth ≈ 0.6 ω_⊥ | 0.49–0.59 | ✓ |
| vortices in stripes along B̂ | axis to 5.9°, 4.0× the vortex-free baseline | ✓ |
| 3 stripes | 3.43 | **within 1** |
| θ → 0 ⇒ homogeneous ring | order parameter at 1.04× its null | ✓ |
| magnetostricted AR = 1.03 | **1.16** | ✗ **unexplained** |

Type **C** for the first five rows. The sixth is an open disagreement, bounded
by five independent instruments against our own implementation (§6b), and it is
the most likely common cause of both threshold misses: a cloud that is 4× more
deformed than the paper's is a cloud whose surface modes and stripe spacing are
not quite the paper's either.

## 7. What this cannot settle

- Nothing here constrains a_s: it was fitted in the source against simulations
  of this same family (§2).
- The paper's atom loss is not modelled (by them or by us), so the *late-time*
  vortex-number saturation is out of scope for both.
- Agreement on Ω_c and stripe structure is type-**C** evidence for the scalar
  eGPE path *in the fast-Larmor adiabatic regime*. It says nothing about the
  spinor path, which is what ¹⁵¹Eu production uses.
