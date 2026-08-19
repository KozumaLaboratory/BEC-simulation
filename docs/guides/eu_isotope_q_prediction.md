# ¹⁵¹Eu vs ¹⁵³Eu — the one prediction that needs no scattering length

> **FROZEN 2026-08-19.** A record of what was measured on that date, not a maintained
> document. The claims that must survive the code moving are gated instead, in
> `test/analysis/test_isotope_q_map.jl`; the measurements are reproducible from the
> drivers in §4. Live sources: `CLAUDE.md`, `docs/index.md`, and the code.
>
> **Status: §1–§3 are the pre-registration.** They were written **before any
> compute** and fix the axes, the systematics and the rejection criteria. §4 is the
> instrument, §5 the measurements with each row naming the run that produced it, §6
> the verdict. Issue: #341 stage 1. Stage 2 (the two-component spinor engine) is
> deliberately **not** started here — whether it is justified is §6's job to answer.
>
> **Read §6 first if you want the number to hand the experiment.**

## 1. What is being delivered, and why it is worth the compute

The two stable europium isotopes share an electronic ground state (⁸S₇/₂), so they
share `g_J`, `μ`, `g_F` and the F=6 quadratic-Zeeman geometry factor. They do **not**
share the hyperfine splitting:

| | ¹⁵¹Eu | ¹⁵³Eu | ratio |
|---|---|---|---|
| Δ_hf (F=6 ↔ F=5) | 121.0 MHz | 53.1 MHz | 2.279 |
| q/h at 1 G | 1421.5 Hz | 3239.1 Hz | **2.2787** |
| g_F, μ, q-geometry | identical | identical | 1 |

Because `q = (g_J μ_B B)² · q_geom / Δ_hf`, the ratio is **exactly** Δ₁₅₁/Δ₁₅₃ at every
field, and it descends from *measured* hyperfine constants (Sandars & Woodgate 1960,
tabulated in Zaremba-Kopczyk, Żuchowski & Tomza, PRA **98**, 032704 (2018), Table I).
No scattering length enters. The falsifiable statement is therefore:

> **Whatever field a q-driven feature sits at in ¹⁵¹Eu, the same feature sits at
> 1/√2.2787 = 0.6625× that field in ¹⁵³Eu** — a 34 % shift, from measured hyperfine
> constants alone.

The whole content of stage 1 is turning that sentence into something a lab can act on,
which means answering three questions the sentence does not:

1. **Where does q matter at all?** A ratio between two numbers that are both eight
   orders of magnitude below every other term in the Hamiltonian is not a prediction.
2. **Is the 34 % shift resolvable under the field systematic**, and is the *residual*
   (the part of the ratio that is not 0.6625) resolvable? These have different answers
   and conflating them would be the mistake this campaign exists to avoid.
3. **How much of the ratio survives not knowing a_S(¹⁵³Eu)?** The registry value is a
   placeholder equal to ¹⁵¹Eu's measured 110(4) a₀; no ¹⁵³Eu measurement exists.

### 1.1 Where q matters — settled before the scan, because it moves the axes

At the production Eu point (N = 5×10⁴, ω_ref = 691.15 rad/s ⇒ ω/2π = 110 Hz,
a_s = 110 a₀, c₁/c₀ = 1/36):

| B | p (dimensionless) | q₁₅₁ (dimensionless) | q₁₅₃ − q₁₅₁ | |c₁| n_peak |
|---|---|---|---|---|
| 25 µG | 0.370 | 8.1×10⁻⁹ | 1.0×10⁻⁸ | 0.332 |
| 68.4 µG (the #335 spinodal) | 1.012 | 6.0×10⁻⁸ | 7.7×10⁻⁸ | 0.332 |
| 100 µG | 1.480 | 1.3×10⁻⁷ | 1.7×10⁻⁷ | 0.332 |
| **160 mG** | 2372 | **0.332** | 0.425 | 0.332 |

**The entire weak-field campaign is q-blind.** In the µG band where #335, #340 and the
adiabatic-protocol work live, q is 6–7 orders of magnitude below the spin interaction,
and the *isotope difference in q* is smaller still. Two isotopes run at the same µG
field are the same system to 7 digits, and no amount of resolution recovers a
difference that small. That is a result, not an obstacle: **every weak-field Eu result
in this repository transfers to ¹⁵³Eu unchanged**, and the isotope pair is useless as a
q probe there.

The competitor is whichever spin-dependent term stabilizes a magnetized state against
q's pull toward m = 0. Two candidates, both order-one at the same place: the contact spin
channel |c₁| n_peak = 0.332, and the dipolar shape anisotropy, a geometry-dependent
fraction of c_dd n_peak = 1.08. So the boundary is expected in
**q ∈ [0.3, 1.1] ⇒ B₁₅₁ ∈ [0.16, 0.29] G**, and locating it inside that decade is what
the scan is for.

q reaches the spin-interaction scale at **B ≈ 0.16 G for ¹⁵¹Eu and 0.106 G for ¹⁵³Eu** —
three and a half decades above the weak-field band. That is where stage 1 must measure,
and it is a different physical regime: p ≈ 2372, i.e. a Larmor frequency 2372× the trap
frequency (≈ 261 kHz), which puts the system deep in the **secular** dipolar regime
(`make_workspace`'s own advisory threshold is ω_L/(c_dd⟨n⟩) > 100; here it is ≈ 2000).
Spin-changing collisions are Zeeman-suppressed, magnetization is conserved on the
experiment's timescale, and the linear term contributes a constant `−p·m_z` inside a
fixed-m_z sector. **The measurement is therefore a fixed-magnetization one at m_z = 0,
with q as the only live Zeeman knob** — the standard spinor-quench geometry, not the
weak-field demagnetization geometry.

### 1.2 What the isotope actually changes in the dimensionless Hamiltonian

Internal units are ℏ = m = ω_ref = 1, so the mass cannot appear directly; it enters only
through the dimensionless couplings via a_ho = √(ℏ/mω_ref). At fixed (N, ω_ref, a_s):

| quantity | scaling | ¹⁵³/¹⁵¹ |
|---|---|---|
| a_ho | m^(−1/2) | 0.99343 |
| c_total = 4π(a_s/a_ho)N | m^(+1/2) | **1.00661** |
| c_dd = Nμ₀μ²/(ℏω a_ho³) | m^(+3/2) | **1.01996** |
| ε_dd = c_dd/c_total | m | 1.01326 |
| q at fixed B | 1/Δ_hf | **2.27872** |

So the isotope is **exactly three numbers**. This is a checkable structural claim, not a
reading of the physics, and §4 gates it: if the isotope enters anywhere else in the
compiled Hamiltonian, the collapse below is not the whole story.

## 2. Axes — every one carries at least two points

| axis | points | what it separates |
|---|---|---|
| **q** (through B) | scan across the boundary, ≥ 9 points per arm | the location of the q-driven feature — the deliverable |
| **isotope** | ¹⁵¹Eu, ¹⁵³Eu | the 34 % shift itself |
| **c₁/c₀** | 1/36 (AFM, Buchachenko) and −0.015 (FM side) | whether the *ratio* depends on the unknown spin channel. If it does, the prediction is not a_S-free and §6 must say so |
| **a_s(¹⁵³Eu)** | 110 a₀ (= ¹⁵¹Eu, the control) and ±10 %, ±30 % | how much of the prediction survives the unmeasured isotope shift. **This is the axis the issue demands and it is not optional** |
| **grid** | 48³ and 64³ (box fixed) | the boundary is a level crossing; crossings are where resolution bites |
| **DDI** | secular on, and off | whether the feature is contact-driven or dipole-driven — they scale differently with mass (1.007 vs 1.020), so this is also the error bar on the collapse residual |
| **pin ε** | 0.001 and 0.002 (transverse, p-units) | #335's finding was that *the pin was the controlling variable, not κ* — doubling a 0.068 µG residual halved the response. A transition located with one pin is not located |

**Two amendments made before any compute, recorded rather than quietly applied:**

1. **κ = 1.8 (oblate), not the spherical κ = 1 first written here.** A *spherical* cloud
   has no dipolar shape anisotropy — the demagnetizing factor is isotropic — so at κ = 1
   the magnetized state has no dipolar stabilization and, on the AFM side (c₁ > 0, Eu's
   expected sign), both c₁ and q drive toward polar and there is no competition and no
   boundary to find. The q-driven boundary needs an easy-plane, which oblateness supplies
   and which is #335's geometry, so the two campaigns sit in the same trap.
2. **A pin axis was added** for the reason in the table row above.

Held fixed and load-bearing:

- **N = 5×10⁴, ω_ref = 2π × 110 Hz, κ = 1.8.** κ is #335's axis, not this one; scanning it
  here would make the boundary a surface and the ratio unreadable.
- **m_z = 0 sector, p = 0.** Justified in §1.1: at p ≈ 2372 the linear term is a constant
  inside the sector and the physics is q's. Setting `B: {p: 0.0, q: <value>}` is the
  faithful encoding, not a simplification — and it is the only encoding that does not
  silently make the fully-stretched state the answer at every field.
- **Both isotopes at a_s = 110 a₀ in the primary arms.** This is a **control, not a
  placeholder abuse**: holding a_S equal is exactly what isolates q. Every absolute field
  quoted below is conditional on a_S; the a_s-perturbation axis measures how conditional.
- **L-BFGS, not ITP**, for the boundary arms. ITP's fixed point is displaced by dt in
  stiff regimes and reports a small `dpsi` while sitting at the wrong energy
  (memory: `gotcha_itp_fixed_point_displaced_by_dt_in_droplet_regime`). A boundary
  located by comparing two energies cannot use a solver whose energy is dt-dependent.
- **Two seeds per point** (transverse-magnetized and polar), min-energy wins. A
  first-order boundary is invisible to a single seed.

**Not run, and named so the gap is visible rather than implied away:** the ¹⁵¹Eu/¹⁵³Eu
*mixture* (that is stage 2, and §6 decides whether it is justified); κ; finite
temperature; and the F=5 manifold (the second-order treatment of q assumes it stays
unpopulated, which p ≈ 2372 × ℏω_ref = 261 kHz ≪ 53.1 MHz comfortably satisfies for both
isotopes — the ratio Δ_hf/ℏω_L is 460 for ¹⁵¹Eu and 203 for ¹⁵³Eu, so the perturbative q
is good to ≲ 0.5 % on both, and *that* is the floor on any claim about the collapse
residual).

## 3. Systematics, stated before the residuals

| systematic | size | what it binds |
|---|---|---|
| absolute field offset | ±10 nT = ±0.1 mG (the value published with the Matsui weak-field data) | any absolute B_c |
| relative field calibration | 1 % assumed (no published number at 0.1 G; a coil calibrated at the µG level is not calibrated at 0.1 G) | the **ratio** of the two isotopes' boundary fields |
| 2nd-order q truncation | ≲ 0.5 %, larger for ¹⁵³Eu (§2) | the collapse residual |
| a_s(¹⁵³Eu) unknown | unbounded; probed at ±10 %, ±30 % | the residual, and possibly the ratio itself |

Consequences, written down now so they cannot be discovered conveniently later:

- **The 34 % shift is resolvable by a wide margin.** At B₁₅₁ ≈ 160 mG the two boundaries
  are ≈ 54 mG apart: 540× the absolute offset systematic, and ≈ 24σ under a 1 % relative
  calibration on each isotope.
- **The residual is not.** The mass corrections move the collapse factor from 0.6625 to
  somewhere in **0.663–0.668** (0.1 % if the boundary is set by |c₁|n, 0.8 % if by c_dd n —
  §5 measures which). Both are below the 1.4 % ratio error from a 1 % per-isotope
  calibration, and comparable to the q-truncation floor. **This campaign will not claim
  to have predicted a measurable mass correction**, and if a scan comes back saying the
  residual is 0.5 % that is a null against the systematic, not a finding.
- Therefore the deliverable is the **34 % shift** and its a_S-robustness, and the residual
  is reported only as the theoretical width of the prediction.

### 3.1 Rejection criteria — the verdict is decided by these, not chosen afterwards

1. **The map is confirmed** iff the numerically located boundary fields satisfy
   `B₁₅₃/B₁₅₁ ∈ [0.655, 0.675]` (0.6625 ± 2 %, i.e. the analytic value widened by four
   times the largest mass correction). Outside that window, the isotope enters somewhere
   beyond the three numbers of §1.2 and §4's structural gate has missed it.
2. **The prediction is deliverable as a discrete measurement** iff some integer-valued
   observable (number of m_F levels above 5 % population — #335's Stern-Gerlach count —
   or the polyhedral phase label) differs across the boundary and agrees between the two
   isotopes after the 0.6625 rescaling. If only continuous observables move, the
   prediction is a curve-fit and must be reported as such.
3. **The prediction is a_S-free** iff `B₁₅₃/B₁₅₁` stays inside the same ±2 % window when
   a_s(¹⁵³Eu) is moved by ±10 %. At ±30 % it may leave; that is quantified, not a failure.
4. **The prediction is worth handing to the lab** iff the boundary separation exceeds
   20× the absolute field systematic. (It is 540× by the §1.1 estimate; the criterion
   exists so that a boundary landing at an unexpectedly low field is rejected
   automatically rather than argued about.)
5. **Stage 2 is justified** iff stage 1 answers 1–4 affirmatively *and* the mixture adds a
   question those answers cannot reach. Confirming 1–4 is not by itself an argument for
   building a 13+13-component engine.

If criterion 1 fails, the deliverable becomes "the isotope is not three numbers" and the
first thing to fix is the code, not the physics.

## 4. Instrument

- `scripts/eu_isotope_q/q_boundary.jl` — the ground-state scan. Per (isotope, c₁ ratio,
  a_s perturbation, grid) arm, an L-BFGS ground state at each q from three seeds
  (transverse / polar / flower), emitting ⟨F_z²⟩ — the quantity q multiplies — beside
  the energy, because "q is inert here" and "q is not reaching the Hamiltonian" are
  indistinguishable in E alone and were confused for an hour on 2026-08-19 (§5.6).
  It **refuses** a transverse pin together with a nonzero q, for the reason in §5.6.
- `scripts/eu_isotope_q/magnon_gap.jl` — the k=0 BdG spectrum vs q for both isotopes.
  Reduces each spectrum to an effective quadratic Zeeman `q_eff` by **consensus fit**
  over the |m| ≥ 2 magnons, and refuses to report one when fewer than four of the five
  expected modes agree. Gated by an exact positive control before it reports anything:
  the F=1 polar magnon `ω = √(q(q + 2c₁n₀))`, plus the negative control that the same
  branch is gapless at q = 0.
- `test/analysis/test_isotope_q_map.jl` (ci tier) — the claims as a gate: the exact q
  ratio, the two mass ratios, the field-axis quadratic Zeeman, the `q·m²` magnon
  exactness, and a differential test that the isotope reaches the energy through nothing
  else. The last two carry negative controls; the first version of the differential test
  was blind and the control is what said so (§5.7).

Amendment made after the first smoke, recorded rather than quietly applied: **the pin
axis of §2 was retired.** A transverse pin does not weakly break the symmetry when q ≠ 0
— it moves the quadratic Zeeman onto a different axis (§5.6). Symmetry breaking comes
from the seed set instead, and a third seed (`flower`) was added, since min-energy over
more seeds is strictly better.

## 5. Measurements

### 5.1 The isotope map — three numbers, one of them exact

Gated by `test/analysis/test_isotope_q_map.jl`.

| quantity | ¹⁵³Eu / ¹⁵¹Eu | source |
|---|---|---|
| **q at fixed B** | **2.278719397363465** | Δ₁₅₁/Δ₁₅₃, measured hyperfine constants |
| c_total | 1.0066088 | √(m₁₅₃/m₁₅₁) |
| c_dd | 1.0199576 | (m₁₅₃/m₁₅₁)^{3/2} |
| ε_dd | 1.0132612 | m₁₅₃/m₁₅₁ |
| q/h at 1 G | 1421.4758 → 3239.1445 Hz | — |

The q ratio holds to 1e-14 at every field and contains no scattering length. The
field-collapse factor is √2.278719 = 1.5095428: ¹⁵³Eu sees ¹⁵¹Eu's q at 0.66245× the
field.

### 5.2 Where q matters — the weak-field campaign is q-blind

q reaches |c₁|n at B = 0.160 G (¹⁵¹Eu) / 0.106 G (¹⁵³Eu), against q ≈ 6×10⁻⁸ at the
68.4 µG spinodal of #335 (§1.1 table). **Six to seven orders of magnitude separate the
two regimes**, so every weak-field Eu result in this repository transfers to ¹⁵³Eu
unchanged, and the isotope pair is useless as a q probe there.

### 5.3 Ground state, AFM side (Eu's expected sign) — q is inert, exactly

`figs/eu_isotope_q/Eu151_c1+0.0278_as1.00_k1.8_g16.tsv`, κ=1.8, DDI secular, three seeds.

All seeds converge to the **m = 0 polar state at every q** from 0.05 to 2 (B = 0.062 to
0.393 G): E = 11.0492784545 identically, ⟨F_z²⟩ = 0, one populated level. Because
⟨F_z²⟩ = 0 the quadratic Zeeman contributes exactly nothing, so **the energy is
q-independent to 1e-10 and the two isotopes have identical ground states at the same
field**. There is no boundary on this side to collapse, and rejection criterion 1 is not
testable here — not because the measurement failed, but because the observable does not
exist.

The transverse seed at q = 0.05 costs +0.035 over polar and relaxes into it; the
polar-vs-magnetized gap is set by c₁F²n/2 ≈ 5.8, an order above anything q does before
B ≈ 1 G.

¹⁵³Eu at 32³ over a **factor 240 in q** (0.05 → 12, i.e. B = 0.041 → 0.64 G;
`figs/eu_isotope_q/Eu153_c1+0.0278_as1.00_k1.8_g32_iso.tsv`) says the same thing more
sharply: every seed lands on **E = 11.0769571608, identical in all twelve digits**, with
⟨F_z²⟩ ≤ 3×10⁻¹⁹. Nothing about the quadratic Zeeman is visible in the ground state of
either isotope, and that is the whole reason the deliverable moved to the excitations.

### 5.4 Ground state, FM side — a boundary, continuous, at ~1.3 G

`figs/eu_isotope_q/Eu151_c1-0.0150_as1.00_k1.8_g32_wide.tsv` (32³, 14 q points, every
cell converged).

| q | B [G] | ⟨F_⊥⟩ | ⟨F_z²⟩ | levels ≥ 5 % |
|---|---|---|---|---|
| 0.05 | 0.062 | 5.953 | 2.724 | 5 |
| 0.64 | 0.223 | 5.803 | 1.530 | 5 |
| 2.30 | 0.422 | 5.301 | 0.784 | 3 |
| 8.23 | 0.798 | 3.610 | 0.255 | 3 |
| 15.58 | 1.098 | 1.195 | 0.0379 | 1 |
| 29.50 | 1.511 | 1.2×10⁻⁸ | 1.5×10⁻¹⁷ | 1 |

A **continuous** transition: the in-plane magnetization decays smoothly and dies between
q = 15.6 and 29.5, i.e. B₁₅₁ ∈ [1.10, 1.51] G. The level count is discrete and moves
(5 → 3 → 1), so criterion 2 is satisfiable on this side. But q_c is set by |c₁|n and c₁ is
unmeasured — the *location* is a drawing of parameter space, not a prediction.

**The collapse, measured (criterion 1).** The same 14-point q grid run for ¹⁵³Eu
(`figs/eu_isotope_q/Eu153_c1-0.0150_as1.00_k1.8_g32_wide.tsv`) tracks ¹⁵¹Eu to
~1×10⁻³ in ⟨F_⊥⟩ at every point and dies in the same bracket. Scanning a **common q
grid** rather than a common field is what makes this a test: the exactly-known factor
2.278719 is not folded in and then divided back out, so what is left is the mass
correction alone. Locating q_c by the ⟨F_⊥⟩ contour, log-interpolated:

| ⟨F_⊥⟩ contour | q_c(¹⁵¹Eu) | q_c(¹⁵³Eu) | ratio | ⇒ B₁₅₃/B₁₅₁ |
|---|---|---|---|---|
| 3.0 | 9.674 | 9.742 | 1.00695 | 0.66475 |
| 2.5 | 11.041 | 11.126 | 1.00775 | 0.66501 |
| 2.0 | 12.600 | 12.708 | 1.00855 | 0.66528 |
| 1.5 | 14.379 | 14.514 | 1.00935 | 0.66554 |

**0.6648–0.6655 against the pre-registered acceptance window [0.655, 0.675]** — passes,
with a measured residual of +0.35…+0.47 % over the naive 0.66245. That residual sits
inside the 0.663–0.668 band §3 predicted from the 0.66 % / 2.0 % coupling corrections,
and §3 also said in advance that it is **below the 1.4 % ratio error a 1 % per-isotope
field calibration would carry**, so it is not claimed as a measurable prediction.

The q_c ratio drifts monotonically with the contour (1.0070 → 1.0094) because the
transition is continuous: "where it dies" is a property of the curve **and** of the
threshold chosen, the same window-dependence that once faked a physics gap here. Quote
the contour with any q_c.

### 5.5 The magnon spectrum — where the prediction actually lives

`figs/eu_isotope_q/magnon_c1+0.0278_as1.00_ddi1_n0.0050_x0.tsv`.

The polar ground state's k=0 excitations, with the DDI on at c_dd = 211:

- **|m| = 2…6: ω = q·m² exactly**, residual ≤ 5×10⁻¹⁴. No interaction shift at all —
  `F·F` connects m = 0 only to m = ±1, so five of the six magnon branches are bare Zeeman
  splittings even in a 13-component dipolar condensate.
- **|m| = 1** is the exception: interaction-gapped at Δ₀ = 6.813 (n₀ = 0.005), shifting as
  Δ₀ + q.

Hence, at the **same field**, ω₁₅₃/ω₁₅₁ = **2.278719 exactly** for every |m| ≥ 2 branch —
a 128 % frequency difference with no scattering length in it. At ω_ref = 2π·110 Hz the
m = 6 magnon is 510 Hz (¹⁵¹Eu) against 1163 Hz (¹⁵³Eu) at 0.1 G.

**a_s sensitivity (criterion 3), measured:** scaling a_s by 1.3 — far beyond any plausible
isotope shift — leaves the ratio at 2.278719 and the interaction offset at 1.3×10⁻¹⁴. The
prediction is a_S-free, not merely a_S-insensitive.

**The caveat that survives, and it is the best part of the result.** The exactness is a
property of the c₀/c₁ truncation, and Eu has *seven unknown even channels*. A rank-2
channel has no such selection rule: it adds an **isotope-independent** offset δ, so the
modes stay ∝ m² with q → q + δ.

| c₂ | δ | ratio at 0.01 G | 0.05 G | 0.1 G | 0.3 G | 1 G |
|---|---|---|---|---|---|---|
| 0 | 1×10⁻¹⁴ | 2.278719 | 2.278719 | 2.278719 | 2.278719 | 2.278719 |
| 6.5 (0.1 c₁) | −2.273×10⁻⁴ | 2.5516 | 2.2878 | 2.2810 | 2.2790 | 2.2787 |
| 65 (= c₁) | −2.273×10⁻³ | breaks down | 2.3755 | 2.3016 | 2.2812 | 2.2789 |

δ is **linear in c₂** and **identical for the two isotopes to four digits**, which turns
the caveat into a measurement:

> Measuring both isotopes at one field gives two equations for two unknowns.
> `q₁₅₁ = (q_eff,₁₅₃ − q_eff,₁₅₁)/(r_q − 1)` and `δ = q_eff,₁₅₁ − q₁₅₁`, with
> r_q = 2.278719 known exactly. **The pair measures the field with no magnetometer, and
> measures the higher-rank channel combination δ that no single isotope can see.**

The inversion recovers q₁₅₁ to **0.00 %** at every field and every c₂ tested, including
the cells where the naive ratio is 12 % off. It fails only where q + δ < 0 for one isotope
(c₂ = c₁ at 0.01 G), and the instrument reports that as −119 % rather than absorbing it.

### 5.6 Two instrument findings that cost time and are worth the space

**The quadratic Zeeman follows the field axis.** The implemented operator is
`−(b·F) + q(b̂·F)²`, not `q F_z²`; `q F_z²` is the b̂ = ẑ special case. The first scan set
p = 0 with a small transverse pin for symmetry breaking, which put b̂ **in the plane**: the
ground state relaxed to the nematic along x (⟨F_z²⟩ = 21 = F(F+1)/2, Zeeman energy
5×10⁻¹²) and the whole scan read "q does nothing" — indistinguishable from a dead code
path, and diagnosed only by printing ⟨F_z²⟩ next to the energy. The physics is right; the
file header of `terms/zeeman.jl` and this repository's `CLAUDE.md` both stated the ẑ case
unqualified, and both now say so. `q_boundary.jl` refuses the combination.

**`converged = true` at 2.4 % above the minimum — and it is a shoulder, not a stall.**
In the FM arm the polar branch stopped at E = 20.0970 with
`converged=true, stop_reason=tol, |∇E| = 6.07×10⁻⁷` at tol = 1e-6. The identical seed and
config with tol = 1e-12 passes straight through: by step 300 it is at **19.6079**, where
the transverse and flower seeds also land, and it ends there at |∇E| = 3.5×10⁻⁷ reporting
`converged=false, line_search_stalled`. So the descent **transiently dips below 1e-6 on a
flat shoulder** half a percent of the total energy above the minimum, and the criterion —
which is exactly `grad_norm < tol`, correctly implemented — fires there.

Two things follow, and they point opposite ways. `converged = true` means *the gradient
got small*, which on this landscape is not the same as *this is the ground state*; and the
run that IS at the ground state reports `converged = false`, because L-BFGS floors out on
an energy-gated line search (the driver says so at `driver.jl:549`). **Neither flag can be
read as the verdict.** This is the 2026-08-06 lesson (*a small gradient is not the right
minimum*) at a gradient three orders smaller, with the extra twist that the flag is
inverted between the wrong answer and the right one.

**No conclusion here rests on an energy comparison between seeds**: §5.4's transition is
read from ⟨F_⊥⟩ and the level count, and §5.3's null from ⟨F_z²⟩ = 0, both
seed-independent. The affected numbers are the FM arm's polar-branch energies, which
should read 19.6079.

### 5.7 What the negative controls caught

The first version of the differential test ("the isotope reaches the energy through
nothing else") passed while measuring nothing: it used a cubic box, `init_psi` builds its
Gaussian from `box/8` per axis, and a uniformly magnetized **spherical** cloud has exactly
zero dipolar energy — so c_dd could be moved 2 % with no effect, and the test would have
passed with the entire DDI path deleted. The box is now anisotropic. Recorded because the
test would otherwise be quoted as evidence for a claim it could not see.

## 6. Verdict

**The prediction stage 1 delivers, and it is not the one the issue expected.**

> At the same magnetic field, the |m| ≥ 2 Zeeman magnons of an F=6 europium condensate sit
> at **2.278719× higher frequency in ¹⁵³Eu than in ¹⁵¹Eu** — exactly, from measured
> hyperfine constants, with no scattering length anywhere in it. At 0.1 G that is 510 Hz
> against 1163 Hz for the m = 6 branch. Measuring both isotopes at one field inverts for
> the field itself **and** for the higher-rank channel offset δ that neither isotope
> reveals alone.

Against the criteria pre-registered in §3.1:

1. **The map is confirmed, and the field collapse with it.** The isotope is exactly three
   numbers, gated, with a negative control. On the FM side the measured collapse is
   **B₁₅₃/B₁₅₁ = 0.6648–0.6655** against the pre-registered window [0.655, 0.675] (§5.4).
   On Eu's expected AFM side the criterion is not testable at all — there is no
   ground-state boundary to collapse, because q does nothing there (§5.3) — and the FM
   boundary's absolute location depends on the unmeasured c₁. The collapse also survives
   in the form that matters most, the magnon ratio, where it is exact rather than
   0.4 % off.
2. **Deliverable as a discrete measurement: partly.** The FM boundary moves a level count
   5 → 3 → 1. The AFM side offers no discrete observable, because it offers no
   q-dependence at all. The magnon deliverable is a *frequency ratio*, which the
   pre-registration ranked below a discrete count and which is, for this measurement,
   better: it needs no calibration of anything but time.
3. **a_S-free: yes, and measured** — a_s ×1.3 leaves the ratio unchanged (§5.5). The
   residual dependence is on the unknown higher-rank channels, quantified, and invertible
   rather than merely tolerable.
4. **Worth handing to the lab: yes.** A frequency ratio of 2.279 against 1 is not
   marginal, and the field systematic enters both isotopes identically.
5. **Stage 2 (the ¹⁵¹Eu–¹⁵³Eu mixture engine) is NOT justified by these results.**
   Nothing in stage 1 needs two components: the deliverable is a single-species
   measurement performed twice. A 13+13-component engine with inter-species DDI and
   inter-species spin-spin — a new subsystem across four layers, on a Workspace whose type
   parameters would multiply — buys nothing stage 1 could not reach, and every *mixture*
   observable (miscibility, double supersolid, mixed droplet) is governed by inter-species
   scattering lengths of which **zero are measured**. The issue's own framing holds: that
   is a drawing of parameter space, not a prediction.

**What would change this verdict.** A measurement of δ — which stage 1 shows the isotope
pair itself can deliver — constrains the higher-rank channels. If that also constrains the
inter-species channels, the mixture becomes predictive rather than parametric and stage 2
gets an argument it does not currently have (#342's dependency map).

**Do not quote from this document:** any absolute field for the FM boundary (§5.4) as a
prediction — it is conditional on the unmeasured c₁; the FM arm's polar-branch energies
(§5.6); or a_s(¹⁵³Eu) as anything but a placeholder equal to ¹⁵¹Eu's measured value.

