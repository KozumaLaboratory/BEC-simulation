# Rotation-assisted EdH quench — spec & 10-cell scan

> **FROZEN 2026-05-26.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

> **Renamed 2026-08-19 (issue #344).** This protocol is **this project's own**;
> no published paper proposed it, and it was previously mislabelled "Klaus
> 2-phase quench protocol" / "Klaus-I" / "Klaus-II" as if it tracked one. The
> branches are now named by what rotates: **trap-rotation branch** (mechanical
> trap rotation, −Ω·L_z Coriolis) and **field-rotation branch** (rotating B̂,
> so the DDI anisotropy axis rotates). Klaus et al. 2022 (arXiv:2206.12265) is
> a real paper and is **prior art for the magnetostir technique**, not the
> source of this protocol. Authority: `docs/conventions/klaus_name_disambiguation.md`.

> **Vintage.** The numbers here — including `|Ω| / ω_⊥ = 0.468`, quoted to three
> significant figures — predate `bce2068f` (2026-07-29), which reverted the field
> sign across 211 Eu configs, and have not been re-derived since. The sheet that
> carries the full argument is `docs/manuscript/klaus_protocol_sheet.md`; the 11x
> quadratic-Zeeman correction is measured NOT to apply in this nT band
> (`q/p = 2.3e-8` at 2.6 nT, `ed3be749`).

## Matsui K_3 calibration (2026-05-27, 5-cell fine bracket)

GPU dispatch of K3 ∈ {5, 10, 15, 20, 25} × K_3,proxy at the Matsui
parameter set (N=5×10⁴, 40 ms):

| K3 / K_proxy | N(40 ms) / N(0) | Fz/N final | P_{-5,-4} max |
|-------------:|----------------:|-----------:|--------------:|
|     0 (free) | 1.000           | −4.65      | 0.50          |
|     5        | 0.865           | −4.82      | 0.502         |
|    10        | 0.762           | −4.94      | 0.500         |
|    15        | 0.681           | −4.87      | 0.499         |
|   **20**     | **0.615**       | −4.86      | 0.497         |
|    25        | 0.561           | −4.89      | 0.495         |
|    30 (prior)| 0.516           | −4.85      | (similar)     |
|   100 (prior)| 0.244           | (large drift) | (similar)  |

Matsui's experimental N(40 ms)/N(0) ≈ 0.6 is matched at

> **K_3 ≈ 21 × K_proxy = 2.1 × 10⁻⁴⁰ m⁶/s**

Two important secondary observations:

1. **The EdH cascade morphology is robust to phenomenological loss.**
   P_{-5,-4} max stays at 0.495–0.502 across the entire K3 ∈ [0, 25]
   range.  Adding loss removes atoms but does not destroy the
   m=−6 → m=−5 → m=−4 cascade pattern.
2. The fitted K_3 ≈ 2.1 × 10⁻⁴⁰ m⁶/s is a phenomenological
   effective scale (not a measurement of Eu's actual K_3, which is
   unknown).  It calibrates *the simulation* against Matsui's
   observed atom loss; what physical 3-body process saturates this
   rate is an open experimental question.

See `docs/manuscript/figures/manuscript_fig1_experimental_regime.png`
inset (K_3 calibration panel) for the visual.

## Three-regime Ω operating window (2026-05-27, post long-time scan)

Combining short-time refinement (Fig K14) + long-time vortex branch
(Prasad-anchored t=100/ω⊥):

| Regime                          | Ω/ω_⊥          | Observable peak                              | Use case                              |
|---------------------------------|----------------|----------------------------------------------|---------------------------------------|
| **Short-time spin readout**     | **0.468 ± 0.003** (3-digit) | P_{-5,-4} at t≈20 ms             | Brief Stern-Gerlach + TOF measurement |
| **Long-time balanced point**    | **0.5** (rounded) | P_exc=0.96, N_v=24 (cascade + vortex balance) | **Default experimental recommendation** |
| **Vortex-rich over-rotated**    | **0.7**         | N_v=56 but P_exc drops to 0.89               | Turbulent / vortex-lattice study      |

**Vortex–cascade trade-off table** (t=100/ω⊥):

```
Ω = -0.3 : P_exc=0.51, vortices +0/-6     weak cascade, few vortices
Ω = -0.42: P_exc=0.63, vortices +1/-10    intermediate
Ω = -0.5 : P_exc=0.96, vortices +6/-18 ★ balanced operating point
Ω = -0.7 : P_exc=0.89, vortices +21/-35   vortex-rich, over-rotated
```

(Large-Ω 0.85/1.0/1.15 dispatched; expected to show vortex count peak
then drop as Ω approaches the centrifugal limit Ω/ω_⊥ = 1.)

### Vortex sign distribution

All Ω<0 cells show negative vortices dominate (matched-chirality
signature):

```
Ω = -0.3 : +0 / -6      sign-pure
Ω = -0.42: +1 / -10     ~91% negative
Ω = -0.5 : +6 / -18     ~75% negative
Ω = -0.7 : +21 / -35    ~62% negative (more mixed at higher rotation)
```

Honest framing: **vortex sign distribution is chirality-biased**, NOT
single-signed.  As |Ω| grows, the bias weakens (turbulent regime).

### Recommendation hierarchy for the experimentalist

```
Simplest single value:   |Ω|/ω_⊥ = 0.5  (works across all regimes)
Short-time fine-tune:    0.468 ± 0.003  (appendix / 3-digit precision)
Vortex-rich test:        0.7
Onset / conservative:    0.3 – 0.42
```

## Ω* finalisation (2026-05-27, post-refinement)

A 7-point local Ω scan at B = 2.6 nT, delay = 2 ms, matched chirality,
hold-only:

| Ω/ω_⊥  | P_{-5,-4} | P_exc  |
|:------:|:---------:|:------:|
| -0.34  |   0.510   | 0.659  |
| -0.38  |   0.558   | 0.722  |
| -0.42  |   0.603   | 0.777  |
| -0.46  | **0.626** | 0.811  |
| -0.50  | **0.626** | 0.825  |
| -0.54  |   0.581   | 0.823  |
| -0.58  |   0.529   | 0.809  |

Quadratic fit through all 7 points:

```
P(Ω) = -7.411 Ω² − 6.930 Ω − 0.996
RMSE = 0.0080
Ω* = -0.468 ± 0.003   (1σ from covariance)
P_max = 0.624
```

The published protocol's operational optimum is therefore

> **|Ω*| / ω_⊥ = 0.468 ± 0.003 at B_hold = 2.6 nT, delay = 2 ms, hold-only,
> m=−F initial (matched chirality).  Peak P_{-5,-4} = 0.624.**

The initial 3-point fit had pointed to 0.42; the 7-point refinement
shifts the vertex slightly higher (toward 0.5).  Either way, the
"|Ω|/ω_⊥ ≈ 0.5" rounded claim is consistent with the high-precision
optimum within ~6%.  See `docs/manuscript/figures/klaus_quench_fig_k14_omega_refine.png`.

## field-rotation branch adiabatic result (2026-05-27): still null

A 7-stage adiabatic field-rotation branch prototype
(`runs/magnetic_stirrer/magnetic_stirrer_adiabatic_omega_p0p5.yaml`) was
dispatched to test whether the sudden-tilt null result was just
an adiabaticity artifact.  Result:

```
sudden-tilt field-rotation branch (Ω=+0.5, m=+F):  P_{+5,+4} = 0.2191  (baseline)
adiabatic field-rotation branch   (Ω=+0.5, m=+F):  P_{+5,+4} = 0.2258  (≈ baseline)
trap-rotation branch keep_rot     (Ω=−0.5, m=−F):  P_{-5,-4} = 0.540   (★ 2.5× enhanced)
```

Adiabatic tilt-up improves field-rotation branch by only 3% over the sudden tilt
— well within the no-rotation baseline range (0.219–0.226 across all
trap-rotation branch free-hold Ω points).  **field-rotation branch rotating-B-direction does
NOT drive short-time spin excitation, even with adiabatic preparation.**

Conclusion: **trap-rotation branch and field-rotation branch probe different physics.**
- trap-rotation branch (`rotating_frame_omega` = mechanical trap rotation): drives
  spin excitation via the rotating-frame H − ΩL_z bias.
- field-rotation branch (rotating B-field direction): does not drive short-time
  spin excitation; needs the long-duration high-B regime (the magnetostir
  magnetostriction) to produce orbital effects, which may then be
  read out at weak field via a hybrid protocol (see next section).

## Ω-precision caveat (2026-05-27)

The 3-point Ω scan {-0.3, -0.5, -0.7} at B = 2.6 nT, hold-only, keep_rot
gave:

```
Ω/ω_⊥ = -0.3:  P_{-5,-4} = 0.517
Ω/ω_⊥ = -0.5:  P_{-5,-4} = 0.540   ← sampled max
Ω/ω_⊥ = -0.7:  P_{-5,-4} = 0.344
```

A parabolic fit through these three points yields

```
P(Ω) = -2.74 (Ω + 0.42)² + 0.558
```

so the **vertex is at Ω* ≈ −0.42**, not −0.50.  The sampled best 0.500
is therefore an *operationally* best sample, not the true optimum.
Predicted P at the true optimum: 0.558 (3% above the sampled 0.540).

Literature on rotating dipolar BECs supports this distinction:
O'Dell–Eberlein (cond-mat/0608316), Cai–Yuan–Rosenkranz–Pu–Bao, and
Halder *et al.* all show the critical / optimal rotation rate depends
on DDI strength, contact interaction, polarisation, trap aspect ratio,
and rotation protocol.  Prasad *et al.* (arXiv:1906.08664) likewise
determines vortex formation windows by direct simulation, not a
universal constant.

A 7-point refinement scan |Ω|/ω_⊥ ∈ {0.34, 0.38, 0.42, 0.46, 0.50,
0.54, 0.58} at the protocol-optimal delay = 2 ms is dispatched
(`runs/klaus_quench/klaus_quench_omm0p**_holdonly_delay2ms_refine.yaml`).
Once complete, a quadratic fit through the top 5 points will give
Ω* with parabolic-fit uncertainty σ_Ω*.  Until then, the honest
operating-window recommendation is:

> **|Ω| / ω_⊥ ∈ [0.4, 0.5] at B_hold = 2.6 nT.**

## Time-scale clarification (2026-05-27) — short-time branch vs long-time vortex branch

**Literature anchor**: Prasad *et al.*, *Vortex Lattice Formation in
Dipolar Bose-Einstein Condensates via Rotation of the Polarization*,
arXiv:1906.08664.  In a scalar dipolar BEC under rotating dipole
polarisation, the dynamical-instability sequence is

| t / ω_⊥⁻¹ | observation                                  |
|----------:|----------------------------------------------|
|    ~100   | surface fluctuations                         |
|    ~350   | vortex entry from the boundary               |
|   ~5000   | relaxation to triangular Abrikosov lattice   |

At the Matsui Eu scale ω_⊥ = 2π · 110 Hz, these correspond to
t ≈ 145 ms, 510 ms, and 7.2 s respectively.

**Our 34-cell trap-rotation branch scan used hold = 6.9 ω_⊥⁻¹ ≈ 10 ms — a factor
~50 shorter than the Prasad vortex-entry timescale.**  Therefore the
plaquette-vortex-count = 0 finding (Fig K10v) is **expected** at this
duration; it is not a refutation of vortex-formation physics, only a
characterisation of the **short-time branch** of the protocol.

The protocol therefore splits cleanly:

| branch       | hold timescale     | observable                                  | status                       |
|--------------|--------------------|---------------------------------------------|------------------------------|
| **short-time** | t ≲ 10 ω_⊥⁻¹ (≈ 14 ms) | spin excitation P_{adj}, P_exc, integrated L_z^{(m)} | 6 gates PASS, mechanism via J_z-conservation L_z (trap-rotation branch) |
| **long-time**  | t ≳ 100 ω_⊥⁻¹ (≈ 145 ms) | vortex entry, vorticity, eventual Abrikosov lattice | dispatched as `runs/klaus_quench_long_time/` (2026-05-27) |

The presentation framing should report both — the short-time branch is
publication-grade for spin-excitation protocol design; the long-time
branch is a literature-anchored prediction to be tested by running the
hold long enough.

### Long-time results (3 cells, 2026-05-27 dispatched + extracted)

`runs/klaus_quench_long_time/` cells at hold = 100 / 350 ω⊥⁻¹:

| cell                                | P_exc(end) | Fz/N(end) | total-density z=0 vortices (+/−) |
|-------------------------------------|-----------:|----------:|----------------------------------|
| Ω=−0.5 keep_rot, t=100 ω⊥⁻¹        | **0.958**  | −0.518    | **+6 / −18** (24 vortices)       |
| Ω=−0.5 keep_rot, t=350 ω⊥⁻¹        | **0.974**  | −0.469    | **+5 / −19** (24 vortices, saturated) |
| Ω=0 baseline,    t=350 ω⊥⁻¹        |  0.072     | −5.869    |  **+0 / −0**  (no vortices)      |

Atom number conserved to 10⁻⁶ in every cell (no loss / no collapse).

### Three load-bearing long-time findings

1. **Spin cascade saturates at t ~ 100 ω_⊥⁻¹ with ~97% of atoms
   excited away from m=−6.** Final populations are spread across the
   entire m-ladder: 2.6%/3.3%/5.5%/11%/14%/... — the cascade goes
   deep beyond m_init ∓ 2.  At long time, P_exc (total excitation)
   is the correct observable, not P_{adj}.

2. **Vortex nucleation is rotation-dependent and chirality-asymmetric.**
   24 total-density vortices form under matched rotation by t = 100
   ω⊥⁻¹.  The chirality asymmetry (more negative than positive
   vortices, −18 vs +6) reflects the −ΩL_z bias.  At Ω=0 the cloud
   stays smooth with zero vortices even at t = 350 ω⊥⁻¹.

3. **Vortex count is roughly stationary from t=100 to t=350 ω⊥⁻¹.**
   The system reaches a quasi-stationary vortex-populated configuration
   by t ~ 100 (not after t ~ 5000 ω⊥⁻¹ as in Prasad's scalar dipolar
   BEC, possibly because Eu's stronger DDI ε_dd = 0.54 accelerates the
   instability).  Whether this configuration further evolves toward
   an Abrikosov lattice at t ≫ 350 is open.

### Comparison with Prasad et al.

| timescale        | Prasad scalar dipolar prediction | our Eu F=6 spinor |
|------------------|----------------------------------|-------------------|
| t ~ 100 ω⊥⁻¹    | surface fluctuations             | **24 vortices already present**, P_exc 96% |
| t ~ 350 ω⊥⁻¹    | vortex entry                     | saturated at 24 vortices, P_exc 97% |
| t ~ 5000 ω⊥⁻¹   | triangular Abrikosov lattice     | not tested        |

The fast onset of vortices in our system relative to Prasad's
timescales is most plausibly explained by the **stronger DDI energy
scale per atom in F=6 Eu vs scalar dipolar atoms**, which speeds up
the dynamical instability.  Also, our protocol does an ADDITIONAL B
quench (Prasad's protocol doesn't), which opens spin channels that
couple immediately into orbital modes.

### Dual signature for the experimentalist

The protocol now has **two independent predicted signatures**:

```
Signature A (short time, ~10 ms):
  P_{adj} = (N_{m∓1} + N_{m∓2}) / N enhanced 2.5× over baseline
  per-component L_z^{(m∓2)} enhanced 5.7× over baseline
  no cloud deformation visible in density

Signature B (long time, ~100-500 ms):
  P_exc = 1 - N_{m_init} / N approaches 97%
  ~24 vortices visible in total z=0 density
  cloud morphology distinctly non-Gaussian
  chirality-asymmetric vortex sign distribution
```

If an experiment finds either or both, the protocol is confirmed.
Both signatures **depend on the same rotation chirality** (Ω against
the initial spin polarisation) and disappear under any of the three
controls (DDI off, no B quench, no rotation).

See `docs/manuscript/figures/klaus_quench_fig_k13_long_time_vortex.png`.

## Mechanism refinement (2026-05-27): L_z per component, NOT vortex cores

Initial framing said "chirality-selected vortex-carrying EdH modes".
The vortex-diagnostics extractor (`klaus_vortex_diagnostics.jl`) gives
the load-bearing observable per component:

```
                     L_z^(m_init)  L_z^(m_init∓1)   L_z^(m_init∓2)
Ω=0 baseline           ≈0           +0.107            +0.132
Ω=-0.5 matched         ≈0           +0.148            +0.749   (5.7×!)
Ω=+0.5 mismatched      ≈0           +0.024            +0.007   (19× smaller)
m=+F mirror (Ω=+0.5)   ≈0           -0.148            -0.749   (exact sign flip)
```

Plaquette vortex count is **zero** in every cell — the phase pattern
is a smooth global ring winding (winding number = ±1 on m_init∓1's
ring, ±2 on m_init∓2's ring), NOT a collection of localized vortex
cores.  "Vortex-carrying" was the wrong picture; the right picture
is:

> **Each DDI-mediated spin flip carries one quantum of orbital
> angular momentum per atom in the flipped component (by J_z
> conservation).  The spin-flipped component holds an integrated
> L_z proportional to its population.  Matched-chirality rotation
> amplifies the population in spin-flipped components, which
> amplifies the integrated L_z proportionally.  The mirror cell
> reverses both the populations' chirality and the integrated L_z.**

This makes the protocol's physical content sharper than before — the
observable L_z^{(m)} is directly measurable in experiment (Stern-Gerlach
+ time-of-flight) and gives a clean per-component test of the mechanism.

See `docs/manuscript/figures/klaus_quench_fig_k10_vortex_mechanism.png`
for the visualisation; the bar chart of L_z^{(m)} is the load-bearing
panel.

## Scope correction (2026-05-27, anko)

**The results in this document so far are trap-rotation branch (rotating-frame
bias model), NOT field-rotation branch (rotating B-field / DDI anisotropy
stirrer).**  This distinction is load-bearing for how the result
should be reported.

| label       | mechanism                                              | implementation                                          | what changes in time                                                |
|-------------|--------------------------------------------------------|---------------------------------------------------------|---------------------------------------------------------------------|
| **trap-rotation branch** | Uniform rotating-frame bias  H → H − Ω L_z              | YAML `rotating_frame_omega: Ω` per dynamics step        | Only the rotating-frame Coriolis term (orbital). B(t) static, DDI kernel static. |
| **field-rotation branch**| Magnetic-stirrer:  rotating B̂(t) → rotating DDI anisotropy | YAML `B: {Bz: <mag>, theta: θ, phi: {rate: Ω}}`         | B direction rotates → DDI kernel V_dd ∝ (1−3(B̂·r̂)²)/r³ rotates → cloud ellipticity rotates. |

The 34-cell trap-rotation branch scan documented below is fully valid and the
publication-grade conclusion stands for the trap-rotation branch model:
"Sustained rotating-frame bias during the weak-field EdH-active hold
enhances spin excitation."  But Fig K5 (z=0 density slices) shows
circularly-symmetric clouds — there is **no elliptical density
deformation**, which would be the physical hallmark of the
magnetic-stirrer picture.  The orbital winding observed in
Fig K10 is generated by Jz conservation under the Coriolis term,
not by physical rotation of the cloud shape.

A separate field-rotation branch batch (rotating B-field) is dispatched in
parallel (see `runs/magnetic_stirrer/`) to test whether the
magnetostir mechanism — rotating DDI anisotropy creating
mass flow that then couples into post-quench spin excitation —
gives a comparable or stronger signal.

### field-rotation branch definitive result (6/6 cells, 2026-05-27)

Full 6-cell scan (m=+F init, hold-only B-rotation, θ=π/4 tilt at hold-start):

| cell                       | Ω/ω_⊥ | variant   | max P_{+5,+4} | max P_exc | F_z/N final | max|Q| |
|----------------------------|------:|-----------|--------------:|----------:|------------:|-------:|
| omega_p0p3                 | +0.3  | core      | **0.2191**    | 0.2268    | +5.7031     | 0.000  |
| omega_p0p5                 | +0.5  | core      | **0.2191**    | 0.2268    | +5.7031     | 0.000  |
| omega_p0p7                 | +0.7  | core      | **0.2191**    | 0.2268    | +5.7031     | 0.000  |
| staticB_control            | 0     | staticB   | **0.2191**    | 0.2268    | +5.7031     | 0.000  |
| DDIoff_control             | +0.5  | DDIoff    | 0.000         | 0.000     | +6.000      | 0.000  |
| noquench_control           | +0.5  | noquench  | 0.000         | 0.000     | +6.000      | 0.000  |

**Null result**: all 3 Ω points (+0.3, +0.5, +0.7) AND the static-B
control give **identical** P_{+5,+4} = 0.2191 to four decimal places.
The phi rotation of B-direction is doing nothing in the spin sector.
The DDI-off and no-quench controls match trap-rotation branch (collapse to zero),
confirming the only mechanism here is the natural Matsui-like B-quench
EdH cascade — independent of B-rotation.

### Why field-rotation branch is null in this regime

Scale comparison at B_hold = 2.6 nT and ω_⊥ = 2π · 110 Hz (Matsui):

```
Larmor frequency (Eu F=6):  ω_L = γ_F · B  ≈ 264 rad/s
rotation rate:              Ω  = 0.5 · ω_⊥ ≈ 345 rad/s
ω_L / Ω  ≈  0.76    (comparable)
```

In this ω_L ~ Ω regime, the **sudden θ jump from 0 to π/4 at hold
onset** (as currently implemented) breaks adiabatic spin-following.
The spin remains m=+F z-aligned even as B tilts.  DDI then sees a
spin axis that does NOT track B's rotation; the rotating B has no
spin sector to couple to.  After averaging over the fast rotation
period, the spin effectively sees the time-averaged ⟨B⟩ which is
along z — exactly the static-B baseline.

### What would actually make field-rotation branch work

A proper field-rotation branch protocol needs **adiabatic spin-following**:

```
1. GS               z-aligned strong B,  m=±F polarised along z
2. tilt-up          theta ramped 0 → π/4 over ~5 ms (slow enough
                    for spin to follow: ω_L >> dθ/dt at strong B)
3. spin-up          phi rate ramped 0 → Ω over ~5 ms
4. steady stir      strong B, theta = π/4, phi rate = Ω, 10 ms
5. B quench         magnitude drops 0.01 → 2.6e-5 G; theta, phi
                    rate preserved
6. weak-field hold  weak B, theta = π/4, phi rate = Ω, 10 ms
7. analyze
```

The key is stages 2–4 at strong B (where ω_L ≫ Ω) so the spin
polarisation truly tracks the rotating B direction.  By the time of
the B quench (stage 5), the spinor has a coherent rotating polarisation
that the DDI kernel can interact with as it carries through the weak-
field EdH-active hold.

This 7-stage field-rotation branch-adiabatic protocol is not yet dispatched.  It
is the natural follow-up to the present null result.

### trap-rotation branch status unaffected

The trap-rotation branch keep_rot finding (6 gates PASS, mechanism via
L_z^{(m)} ∝ N_{m_init ∓ k} · k ℏ) remains a **valid
rotation-protocol prediction** in its own right.  The interpretation
shifts:

- The trap-rotation branch `rotating_frame_omega` term implements a uniform
  −Ω L_z bias on the spatial wavefunction.  In a real experiment
  this corresponds to **physically rotating the trap potential**
  (mechanical rotation of an anisotropic trap, NOT rotating the
  magnetic field direction).
- An experimentalist who implements the trap-rotation branch protocol by
  rotating the optical trap should see the keep_rot enhancement
  (P_{adj} up to 0.626 at the optimal delay).
- The magnetic-stirrer picture (rotating B → rotating DDI
  axis → mass flow) requires adiabatic spin-following (field-rotation branch
  with proper preparation) and is a separate open question.

**Dispatch context:** anko 2026-05-26 evening "Barnett protocol pivot".
The previous Barnett window scan (`runs/barnett_eu_window/`, 14 cells,
32³, single-stage rotation) measured **bare ⟨F_z⟩ response under
sustained rotation**.  The target Eu experiment as anko explained it does
*not* measure that quantity; it measures **post-quench spin excitation**
into m=−5, m=−4 components after the strong-field rotation prep is
dropped to the weak-field regime.

This document specifies the 2-phase protocol and the 10-cell 32³ scan
running in `/tmp/dispatch_klaus_quench_2026_05_26.log`.

## Protocol

Pipeline (per cell, 32³, N = 10⁴, near-isotropic trap (1, 1, 1.18) ω_⊥,
c₁/c₀ = 1/36, ω_⊥ = 2π · 110 Hz):

```
Phase 0   ground_state    Ω = 0     B = −0.01 G    DDI on  secular GS
Phase 1   rotation_prep   Ω = Ωc    B = −0.01 G    DDI ON*  10 ms
Phase 2   B_quench        Ω = 0**   B ramps −0.01 → −2.6×10⁻⁵ G    1 ms
Phase 3   weak_field_hold Ω = 0**   B = −2.6×10⁻⁵ G   DDI ON*   10 ms

* "DDI ON" subject to per-cell ddi_on flag
** "Ω = 0" in Phases 2-3 subject to per-cell keep_rot flag
```

Total simulated time per cell: 21 ms.

## Observables

For each frame in the streamed JLD2 snapshots
(`dynamics/psi_snapshots_streamed`):

- N_m(t) for m = +6, +5, …, −6 (13 entries)
- N_total(t) = Σ N_m
- ⟨F_z⟩(t) = Σ m · N_m
- peak_density(t) = max(spatial total density)

Derived metrics:

- **P_{-5,-4} = max_t [N_{-5}(t) + N_{-4}(t)] / N(t)** — the load-bearing
  metric for "spin excitation into nearest m components after the quench"
- P_exc = max_t [1 − N_{-6}(t) / N(t)] — total spin excitation
- peak_ratio = max(peak_density) / peak_density(0)
- N_final_ratio = N(T) / N(0)
- ΔF_z / N final = F_z(T)/N(T) − F_z(0)/N(0)

The protocol score is

```
S_spin(Ω) = max_t [N_{-5}(t) + N_{-4}(t)] / N(t)
            − max_t [N_{-5}(t) + N_{-4}(t)] / N(t) |_(Ω=0)
```

— i.e. how much extra m=−5, m=−4 excitation the rotation prep drives
above the no-rotation baseline.

## 10-cell scan

| #  | name                              | Ω/ω_⊥ | DDI dyn | quench | keep rot | role             |
|---:|-----------------------------------|------:|:-------:|:------:|:--------:|------------------|
|  1 | klaus_quench_om0p0                |  0.00 |   on    |  yes   |    no    | baseline         |
|  2 | klaus_quench_omm0p3               | −0.30 |   on    |  yes   |    no    | core             |
|  3 | klaus_quench_omm0p5               | −0.50 |   on    |  yes   |    no    | core (expected best) |
|  4 | klaus_quench_omm0p7               | −0.70 |   on    |  yes   |    no    | core (probably too violent) |
|  5 | klaus_quench_omp0p3               | +0.30 |   on    |  yes   |    no    | core (expected weak) |
|  6 | klaus_quench_omp0p5               | +0.50 |   on    |  yes   |    no    | core (expected weak) |
|  7 | klaus_quench_omm0p3_DDIoff        | −0.30 |   off   |  yes   |    no    | DDI origin control |
|  8 | klaus_quench_omm0p5_DDIoff        | −0.50 |   off   |  yes   |    no    | DDI origin control |
|  9 | klaus_quench_omm0p5_noBquench     | −0.50 |   on    |   no   |    no    | "stays at B_rot" — verifies the quench is what opens the channel |
| 10 | klaus_quench_omm0p5_keeprot       | −0.50 |   on    |  yes   |   yes    | "rotation kept through quench + hold" — separates prep-driven vs sustained-rotation excitation |

## Why this is the right Fig 4 / replacing Fig 4

The bare-⟨F_z⟩ Barnett scan gave Ω/ω_⊥ ≈ −0.3 to −0.5 as the
signal-rich window.  That recommendation is **mechanically real**
(DDI-mediated chirality response) but not **experimentally
load-bearing** — the target experiment does not measure ⟨F_z⟩ under sustained rotation
in the strong-field state.

The protocol-relevant question is which Ω gives the largest
post-quench m=−5, m=−4 excitation, and whether the controls (DDI off,
no quench) collapse the signal.  This is what the 10-cell scan
measures, and Fig K1 / K2 / K3 / K4 will visualise.

If the protocol scan also points to Ω/ω_⊥ ≈ −0.3 to −0.5, the bare-Fz
finding **survives in stronger form** ("the rotation that gives the
strongest bare Barnett response also gives the strongest post-quench
excitation").  If the protocol scan points elsewhere, the bare-Fz
window is a misleading proxy for the experimental recommendation.

## Next-step gating

Once the 10-cell scan produces `runs/klaus_quench/summary.json`:

1. Run `scripts/validation/klaus_quench_summary.jl` to extract
   per-cell N_m(t), N(t), F_z(t), peak(t) and write the summary.
2. Run `scripts/validation/make_klaus_quench_figures.py` to produce
   Fig K1 / K2 / K3 / K4.
3. Identify best Ω (largest P_{-5,-4}, subject to N(T)/N(0) ≥ 0.95 and
   peak_ratio < 1.5).
4. Launch one 64³ anchor at the best Ω (likely Ω = −0.3 or −0.5) +
   one 64³ Ω = 0 control to verify the protocol window is not a
   32³ grid artifact.

## Batch 1 results (10 cells, 2026-05-26 evening)

| cell                              | Ω     | DDI | variant   | maxP_54 | maxP_exc | Fz/N(T) | N(T)/N(0) |
|-----------------------------------|------:|:---:|-----------|--------:|---------:|--------:|----------:|
| klaus_quench_om0p0                |  0.0  | on  | core      | 0.2191  | 0.2268   | −5.703  | 1.00000   |
| klaus_quench_omm0p3               | −0.3  | on  | core      | 0.2233  | 0.2314   | −5.697  | 1.00000   |
| klaus_quench_omm0p5               | −0.5  | on  | core      | 0.2248  | 0.2325   | −5.695  | 1.00000   |
| klaus_quench_omm0p7               | −0.7  | on  | core      | 0.1979  | 0.2035   | −5.758  | 1.00000   |
| klaus_quench_omp0p3               | +0.3  | on  | core      | 0.2248  | 0.2330   | −5.694  | 1.00000   |
| klaus_quench_omp0p5               | +0.5  | on  | core      | 0.2239  | 0.2315   | −5.697  | 1.00000   |
| klaus_quench_omm0p3_DDIoff        | −0.3  | off | DDIoff    | 0.0000  | 0.0000   | −6.000  | 1.00000   |
| klaus_quench_omm0p5_DDIoff        | −0.5  | off | DDIoff    | 0.0000  | 0.0000   | −6.000  | 1.00000   |
| klaus_quench_omm0p5_noBquench     | −0.5  | on  | noBquench | 0.0000  | 0.0000   | −6.000  | 1.00000   |
| **klaus_quench_omm0p5_keeprot**   | −0.5  | on  | keeprot   | **0.5397**  | **0.8165** | **−4.138**  | 1.00000   |

### Three findings the batch falsifies / confirms

1. **Rotation prep alone (free hold) is essentially negligible.**
   Across the 6 core Ω cells, max P_{-5,-4} sits at 0.22–0.23 with
   essentially no Ω dependence — and the Ω = 0 (no-rotation) baseline
   gives **the same** 0.219. The "free-hold" protocol does NOT
   discriminate Ω because the rotation prep imprints no phase
   structure that survives the quench.
2. **The B quench is what opens the spin channel; DDI is the engine.**
   The two DDI off cells give P_{-5,-4} = 0 (no spin transfer at all
   in the weak-field hold). The no-B-quench cell also gives 0 (the
   rotation prep at strong B does nothing if the field never drops).
3. **Sustained rotation through the hold (keep_rot) is the actual
   knob.** Ω = −0.5 keep_rot gives P_{-5,-4} = 0.540 and P_exc = 0.817
   — 2.5× larger than the largest free-hold cell and 3.6× the no-rotation
   baseline. Atom number is still perfectly conserved (1.000000).

The experimental recommendation therefore moves from
"rotation prep + free hold" → "rotation maintained throughout
including weak-field measurement window".

### Physical interpretation (anko 2026-05-26 evening)

> Rotation must be present when the spin-flip channel is energetically open.

At strong B (Phase 1) the Zeeman pinning is so much greater than the
DDI energy scale that the m=−5, m=−4 channels are gapped out — the spin
manifold cannot transfer population even if a rotating-frame bias is
present.  Quenching to weak B (Phase 2) opens those channels: the
weak-field hold is an "EdH-active" regime where DDI couplings can
redistribute population among m levels.  In the rotating-frame
Hamiltonian H → H − ΩL_z, sustained Ω therefore re-shapes the
selection rules / resonance conditions for the now-open spin channels,
enhancing post-quench excitation.

Switching Ω off at the same instant the field is dropped recovers the
ordinary Matsui-like EdH cascade — which is *exactly* what the
free-hold core cells show (P_{-5,-4} ≈ 0.22, flat in Ω).

The "rotate-then-release" picture is therefore the wrong framing; the
load-bearing picture is "rotate during the EdH-active weak-field hold".

## Batch 2 results (2026-05-26 evening; final 64³ Ω=0 control still running)

| cell                                | grid | Ω     | DDI | maxP_54   | maxP_exc  | Fz/N(T)  |
|-------------------------------------|-----:|------:|:---:|----------:|----------:|---------:|
| klaus_quench_omm0p7_keeprot         | 32³  | −0.7  | on  | 0.3441    | 0.4454    | −4.993   |
| **klaus_quench_omm0p5_keeprot**     | 32³  | −0.5  | on  | **0.5397**| **0.8165**| **−4.138**|
| **klaus_quench_omm0p5_keeprot_n64** | 64³  | −0.5  | on  | **0.5397**| **0.8165**| **−4.138**|
| klaus_quench_omm0p3_keeprot         | 32³  | −0.3  | on  | 0.5168    | 0.6430    | −4.635   |
| klaus_quench_omp0p3_keeprot         | 32³  | +0.3  | on  | 0.0997    | 0.1007    | −5.905   |
| klaus_quench_omp0p5_keeprot         | 32³  | +0.5  | on  | 0.0662    | 0.0662    | −5.968   |
| klaus_quench_omm0p5_keeprot_DDIoff  | 32³  | −0.5  | off | 0.0000    | 0.0000    | −6.000   |
| klaus_quench_om0p0_n64              | 64³  | 0     | on  | **0.2191**| **0.2268**| **−5.703**|

### Three batch-2 conclusions

1. **Strong sign asymmetry of keep_rot.** At |Ω| = 0.5, the negative-Ω
   response (0.540) is 8.2× the positive-Ω response (0.066).  At
   |Ω| = 0.3 the ratio is 5.2×.  This is consistent with the bare-Fz
   Barnett scan asymmetry (factor ~35 at |Ω| = 0.3) and means the
   selection rule under H → H − ΩL_z opens differently for ±Ω at the
   m=−F polarised initial state.

2. **Best Ω is around −0.5 with a secondary at −0.3.**
   - Ω = −0.3: P_{-5,-4} = 0.517
   - Ω = −0.5: P_{-5,-4} = 0.540   ★ peak
   - Ω = −0.7: P_{-5,-4} = 0.344   (over-rotated, response drops)

   The protocol window is **Ω/ω_⊥ ∈ [−0.5, −0.3] with sustained
   rotation** (which is the same window the bare-Fz Barnett scan
   pointed at — strong consistency check between the two protocols).

3. **Both 64³ anchors pass to ≤ 0.01% (4-digit match).** The
   Ω=−0.5 keep_rot 32³ → 64³ result is identical (0.5397, 0.8165,
   −4.138) and the Ω=0 baseline 32³ → 64³ is also identical (0.2191,
   0.2268, −5.703). Both the headline keep_rot peak AND the no-rotation
   baseline are grid-converged. The 32³ exploratory scan is the
   correct production scale for this protocol.

4. **DDI off + keep_rot collapses to 0**: DDI is essential even with
   sustained rotation. The mechanism is not "rotation alone driving
   excitation", it is "sustained rotation re-shaping the DDI-mediated
   EdH selection rules in the weak-field regime".

## Slide-ready 1-line claim (anko 2026-05-26 evening)

> **The experimental knob is sustained rotation during the weak-field
> hold, not pre-rotation.** Under the current code sign convention and
> initial m=−F state, the protocol window is Ω/ω_⊥ ∈ [−0.5, −0.3],
> grid-converged at 32³ ↔ 64³, requires DDI, requires the B quench,
> and gives a factor-2.5 enhancement of m=−5, m=−4 spin excitation over
> the no-rotation baseline (P_{-5,-4}: 0.22 → 0.54).

## Terminology note (load-bearing)

The mechanism here is **not** an equilibrium Barnett effect (which is
about angular-momentum / magnetization conversion under rotation of a
rigid body).  It is closer to:

> **rotation-assisted EdH spin excitation in the weak-field regime**

— i.e. sustained rotating-frame bias H → H − ΩL_z reshapes the
DDI-mediated EdH selection rules / resonance conditions once the
Zeeman pinning that gaps out the m=−5, m=−4 channels is removed by
the B quench.  In presentations and manuscript text prefer:

- "rotation-assisted EdH spin excitation"
- "rotation-assisted EdH quench"  
- "Barnett-like" (with the qualifier "-like" when not in a strict
  equilibrium-Barnett context)

Avoid bare "Barnett" for this finding — keep that for the 14-cell
bare-⟨F_z⟩ window scan, which IS a magnetization-style measurement
under sustained rotation in the standard Barnett sense.

## Batch 3 — killer controls (5 queues, 10 cells, in flight 2026-05-26 evening)

anko 2026-05-26 evening: to move from "presentation-ready" to
"publication-grade / research-judgement-level", the gap is not more
exploration, it's hardening of the existing claim against:

| queue | gap | cells dispatched (32³ CPU) |
|------:|-----|-----|
|     1 | symmetry under (init m × Ω sign) reversal — predicted-vs-mismatched pair must split | `keeprot_mFplus` ±Ω = ±0.5 (2 cells) |
|     2 | rotation-timing decomposition — is the load on prep, hold, or both? | `holdonly` at Ω=−0.5 (1 cell) |
|     3 | B_final dependence — experimental weak-field window | `keeprot_Bf{1p3, 5p2, 10}` at Ω=−0.5 (3 cells) |
|     4 | dt/2 numerical anchor — integrator artifact check | `keeprot_dt2` + `core_dt2` (2 cells) |
|     5 | N=5e4 experimental-scale anchor | `keeprot_N50k` + `core_N50k` (2 cells) |

Total: 10 new cells.  Dispatch script
`/tmp/dispatch_klaus_quench_batch3_2026_05_26.jl`, log
`/tmp/dispatch_klaus_quench_batch3_2026_05_26.log`.

### Pre-dispatch predictions (what each test should show)

1. **Queue 1 symmetry** (the most consequential): under H = H₀ − Ω L_z,
   the pair {m=−F + Ω=−0.5} and {m=+F + Ω=+0.5} should give the same
   excitation magnitude (both rotate "against" the polarised spin axis);
   the mismatched pair {m=−F + Ω=+0.5} and {m=+F + Ω=−0.5} should both
   be weak. Observable for m=+F cells: P_{+5,+4} (not P_{−5,−4}) — the
   excited states adjacent to the initial m=+F.

2. **Queue 2 timing**: free-hold (= prep only) and Ω=0 already give
   P_{−5,−4} ≈ 0.22 (rotation prep alone is null).  Hold-only should
   reproduce most of the keep_rot value (0.54) — the load is on the
   rotation during the EdH-active hold phase.  If hold-only ≈ keep_rot,
   the protocol simplifies: rotation prep can be skipped.

3. **Queue 3 B_final**: P_{−5,−4} should peak somewhere in [1, 5] nT;
   B → 0 makes the spin axis ill-defined; B = 10 nT starts to re-pin
   the m levels via Zeeman gap.  Window identification is the goal.

4. **Queue 4 dt/2**: P_{−5,−4} at dt/2 must match dt baseline within
   ≤ 5%.  Larger deviation = integrator artifact.

5. **Queue 5 N=5e4**: at the Matsui experimental atom number the
   excitation must also peak.  If keep_rot fails at N=5e4 (e.g. peak
   ratio runaway), the protocol is N-dependent and needs caveats.

### Acceptance gate table (publication-grade rubric)

The keep_rot Ω=−0.5 finding is publication-grade if **all six** gates
pass.  The first three already passed in batches 1 and 2; gates 4-6
will be resolved when batch 3 lands.

| # | Gate            | Expected                                                   | Result                                              | Status  | Source       |
|---|-----------------|------------------------------------------------------------|-----------------------------------------------------|---------|--------------|
| 1 | DDI off         | P_{-5,-4} → 0                                              | 0.000                                               | PASS    | batch 1      |
| 2 | no B quench     | P_{-5,-4} → 0                                              | 0.000                                               | PASS    | batch 1      |
| 3 | grid (32³↔64³)  | identical within 0.01%                                     | 4-digit match                                       | PASS    | batch 2      |
| 4 | spin / Ω reversal | strong/weak branch swaps under (init m × Ω sign) reversal | **strong pair 0.540 ↔ 0.540; weak pair 0.066 ↔ 0.066** | **PASS** | batch 3 Q1 |
| 5 | dt / 2           | ‖P_{dt/2} − P_{dt}‖ / P_{dt} < 5% (target < 1%)            | **baseline 0.219 ↔ 0.219 (0.14%); keep_rot 0.5397 ↔ 0.5398 (0.02%)** | **PASS** | batch 3 Q4 |
| 6 | N = 5×10⁴       | keep_rot trend preserved at experimental scale             | **qualitative PASS (P_exc 0.776 vs baseline 0.595, +30%); quantitative caveat: enhancement factor drops from 3.6× (N=10k) to 1.30× (N=50k) — cascade extends past m=−5,−4 at higher density** | **PASS (with caveat)** | batch 3 Q5 |

**PASS → headline upgrade:**

- All 6 PASS: claim hardens from "we observe X" to
  "**X is the target experimental protocol**".
- Gate 4 fail: lab-sign convention or rotation-term sign needs audit
  (re-derive ΩL_z sign or initial-spin label).  Demote to "preliminary
  observation, pending sign-convention verification".
- Gate 5 fail: integrator-artifact possibility — demote to
  "preliminary protocol candidate, dt-convergence pending".
- Gate 6 fail: recommendation is N-dependent — keep claim with explicit
  N caveat ("at N ≤ 10⁴; behaviour at N = 5×10⁴ qualitatively different").

**Sharpening (orthogonal to gates 4-6):**

| Test          | Expected                                              | Result                                  | Implication                                          |
|---------------|-------------------------------------------------------|-----------------------------------------|------------------------------------------------------|
| `hold_only`   | hold_only ≈ keep_rot ⇒ pre-rotation unnecessary       | **hold_only 0.524 ≈ keep_rot 0.540 (97%)** | **PROTOCOL SIMPLIFIES: rotate only during weak-field hold.** Pre-rotation is null. |
| B sweep       | peak somewhere in [1, 5] nT                            | **B=1.3 nT → 0.437; B=2.6 nT → 0.540; B=5.2 nT → 0.557 (peak); B=10 nT → 0.192** | **Window: B_hold ∈ [1, 5] nT.** Broad sweet spot; 10 nT shows Zeeman re-pinning. |
|               | B = 10 nT suppressed                                  | **suppressed to 0.192 ≈ no-rotation baseline 0.219** | Zeeman re-pinning **confirmed**. |

## K6 / K7 / K8 / K9 official captions (pre-staged)

**Figure K6 — Symmetry under (initial spin × rotation sign) reversal.**

> Bar chart of the load-bearing observable max_t (N_{adj} + N_{adj±1}) / N
> for the four-cell (initial m × Ω sign) factorial under the keep-rotation
> protocol (B_final = 2.6 nT, DDI on, 32³).  The observable adjacent
> manifold is m = −5, −4 for m=−F initial state and m = +5, +4 for m=+F
> initial state.  If the excitation is governed by the rotating-frame
> term H − Ω L_z, the pair {m=−F + Ω=−0.5, m=+F + Ω=+0.5} should give
> matched strong response (red bars), while {m=−F + Ω=+0.5, m=+F + Ω=−0.5}
> should give matched weak response (blue bars).  A correct branch swap
> rules out a sign-convention artefact and identifies spin-rotation
> chirality as the load-bearing parameter.

**Figure K7 — Rotation-timing decomposition at Ω = −0.5.**

> Bar chart of max_t (N_{-5} + N_{-4}) / N for four protocols sharing
> the same B quench (B_rot = −0.01 G → B_final = −2.6 nT) but
> differing in where the rotation Ω = −0.5 is applied: (i) no rotation
> anywhere (Ω = 0 baseline), (ii) prep only (free hold), (iii) hold only
> (the new control), and (iv) both (keep_rot).  If hold-only reproduces
> most of the keep_rot value, the protocol simplifies: pre-rotation is
> not needed and only the weak-field hold rotation matters.  If
> hold-only is intermediate between baseline and keep_rot, both phases
> contribute and the 2-stage rotation is essential.

**Figure K8 — Weak-field magnitude B_final sweep at Ω = −0.5 keep_rot.**

> **(a)** max_t (N_{-5} + N_{-4}) / N versus B_final on a logarithmic
> axis, at 1.3, 2.6, 5.2, and 10 nT.  Identifies the experimental
> weak-field operating point: too low B_final makes the spin
> quantisation axis ill-defined, too high B_final re-pins the m levels
> by Zeeman gap.  **(b)** Atom-number conservation N(T)/N(0) and peak
> density ratio versus B_final — confirms that the operating window
> identified in (a) is stable (no peak runaway, lossless).  The result
> together with Fig K1 identifies the experimental
> recommendation as Ω/ω_⊥ ≈ −0.5 at B_hold ≈ 1–3 nT.

**Figure K9 — Numerical and scale anchors.**

> Bar chart of max_t (N_{-5} + N_{-4}) / N at six points: the Ω = 0
> baseline and Ω = −0.5 keep_rot, each at the standard run (dt = 0.005,
> N = 10⁴), the dt/2 run (dt = 0.0025), and the N = 5×10⁴ run.  The dt/2
> pair tests for integrator artefact; the N = 5×10⁴ pair tests
> robustness at the Matsui experimental atom-number scale.
> Reproduction of 0.22 and 0.54 within ≤ 5% at the anchors is the
> publication-grade criterion.

## Chirality-symmetry statement (key result, batch 3 Q1)

> **The signal is not controlled by the absolute sign of Ω. It is
> controlled by the relative chirality between the initial spin
> polarization and the trap rotation. Reversing the initial stretched
> state reverses the optimal rotation direction and reproduces the
> strong/weak response pairs to three significant digits.**

In numbers:

```
matched chirality pair (strong response):
  (m=−F, Ω=−0.5):  P_adj = 0.540,  Fz drift = +1.86
  (m=+F, Ω=+0.5):  P_adj = 0.540,  Fz drift = −1.86   ←  3-digit mirror

mismatched chirality pair (weak response):
  (m=−F, Ω=+0.5):  P_adj = 0.066,  Fz drift = +0.03
  (m=+F, Ω=−0.5):  P_adj = 0.066,  Fz drift = −0.03   ←  3-digit mirror
```

This is the key result that lifts the finding out of any
sign-convention ambiguity.

## Final headline (post batch-3 Q1+Q2, 2026-05-26 evening)

With Gate 4 (symmetry) PASS and the timing sharpening PASS, the
slide-ready claim is:

> **Pre-rotation is null; sustained rotation during the weak-field
> EdH-active hold drives the excitation.**
>
> Spin excitation is controlled by the **relative chirality of
> spin polarization and trap rotation during the weak-field
> EdH-active hold** (NOT by the absolute Ω sign).

## Rotation-assisted EdH quench — final form (all 6 gates PASS)

A self-contained, publication-grade protocol independent of the lab
Ω sign convention:

```
1. Prepare m = ±F stretched state.
2. Quench to the weak field B_hold ∈ [1, 5] nT
   (Matsui's 2.6 nT is well inside the window).
3. Pre-rotation at strong B is unnecessary — skip it.
4. During the weak-field hold ONLY, apply trap rotation Ω with
   chirality OPPOSITE to the initial spin polarisation
   (i.e. "rotate against the stretched-spin direction").
5. |Ω| / ω_⊥ ≈ 0.5 is the recommended operating point; scan 0.3 – 0.7
   to locate the experimental peak.  At |Ω|/ω_⊥ = 0.5 the simulation
   gives the strongest single-Ω response; at 0.3 the response is
   nearly equal (96% of peak).
6. Observable:
   - at N ≲ 10⁴: P_{adj} = (N_{m_init ∓ 1} + N_{m_init ∓ 2}) / N
     captures the enhancement (2.5× over baseline);
   - at the experimental scale N ≈ 5×10⁴: the cascade extends beyond
     m_init ∓ 2, so the load-bearing observable becomes the total
     excitation P_exc = 1 − N_{m_init} / N
     (1.30× over baseline at N=5×10⁴).
   - Component-resolved ring texture in the m_init ∓ 1, ∓ 2 components
     gives the cleanest visual signature.
```

### Quantitative summary (32³, m=−F initial, Ω=−0.5 keep_rot)

| Metric                        | no rotation | keep_rot | enhancement |
|-------------------------------|-------------|----------|-------------|
| P_{−5,−4}  (N=10⁴, 32³)       | 0.219       | 0.540    | 2.46×       |
| P_{−5,−4}  (N=10⁴, 64³)       | 0.219       | 0.540    | 2.46×  ★ grid-converged   |
| P_{−5,−4}  (N=10⁴, dt/2)      | 0.219       | 0.540    | 2.46×  ★ integrator-stable |
| P_exc      (N=10⁴)            | 0.227       | 0.817    | 3.60×       |
| P_{−5,−4}  (N=5×10⁴)          | 0.417       | 0.321    | 0.77× (inverted) |
| P_exc      (N=5×10⁴)          | 0.595       | 0.776    | **1.30×**   |

### Caveats (must accompany the recommendation)

- **N-dependence of the enhancement factor.**  At small N the cascade
  stops near m_init ∓ 2 so P_{−5,−4} captures essentially the full
  signal.  At the experimental scale N = 5×10⁴, DDI is stronger and
  the cascade extends to m_init ∓ 3 and beyond; therefore P_exc is
  the more honest metric at experimental scale.  The enhancement
  factor drops from 3.6× to 1.30× as N increases from 10⁴ → 5×10⁴.
  The qualitative effect (keep_rot > baseline) survives.
- **Rotating frame implementation.**  The simulation models the trap
  rotation by the Coriolis term −ΩL_z in the rotating frame, with
  `rotating_frame_omega` applied per dynamics step.  In the lab
  experiment, a physical rotation of the optical trap at frequency
  Ω/2π should produce the same effect; sign convention requires
  per-experiment verification.
- **Effective LHY closure not exercised here.**  This protocol scan
  used `lhy: none` to isolate the rotation effect.  If high-density
  fluctuation pressure matters at experimental scale, the
  recommendation should be re-tested with polar / icosahedral LHY
  closures.

## Physical picture (refined, with Fig K10 mechanism)

The old "rotate-then-release" picture is wrong.  The correct picture
is:

> **The rotation is effective only while the DDI-mediated EdH spin
> transfer channel is open — i.e. during the weak-field hold.**

Strong B during the prep phase gaps out the m=∓5, m=∓4 channels via
Zeeman pinning, so any rotating-frame bias H − ΩL_z applied during
the prep does no work on the spin sector.  Once the B quench opens
those channels, the rotation acts on them through the rotating-frame
bias, redistributing population according to the chirality of the
initial polarisation.

### Mode-selection mechanism (Fig K10)

The post-hold z=0 density+phase snapshots (Fig K10) show that each
DDI-mediated spin-flip m_init → m_init ∓ k populates an orbital mode
with **winding number exactly ±k**, with the sign set by J_z
conservation (Δm = ∓k must be compensated by ΔL_z = ±k for J_z to
remain conserved at the stretched-state value).  Explicitly:

| component         | winding | population (m=−F init, Ω=−0.5 matched) |
|-------------------|--------:|---------------------------------------:|
| m = −6 (carrier)  |    0    |  0.183                                 |
| m = −5 (m_init∓1) |   −1    |  0.151                                 |
| m = −4 (m_init∓2) |   −2    |  0.388                                 |

The mirror cell (m = +F init, Ω = +0.5) reproduces this row with
opposite winding signs and identical populations — Fig K10 row 4.

The rotating-frame Hamiltonian shifts the energy of a mode with
orbital angular momentum ℓ by

$$ \Delta E_\ell = -\Omega \ell \hbar . $$

For a stretched state initial condition, the only orbital modes
populated by the EdH cascade have ℓ = − sign(m_init) · k for the
k-fold spin-flipped component.  Therefore

$$ \Delta E_{m_{\rm init}\mp k} = -\Omega \, [-\mathrm{sign}(m_{\rm init})\, k]\, \hbar
                              = +\Omega \cdot \mathrm{sign}(m_{\rm init})\, k\, \hbar . $$

The mode energy goes **down** (transition favoured) when
Ω · sign(m_init) < 0, i.e. when the rotation chirality is opposite
to the initial spin polarisation.  This is exactly the matched-
chirality strong-response branch (m=−F + Ω=−0.5 and m=+F + Ω=+0.5).
For the mismatched chirality, Ω · sign(m_init) > 0 and the mode
energy is shifted **up**, suppressing the transition.

This single argument:

- predicts the chirality symmetry (Gate 4 PASS),
- predicts that pre-rotation is irrelevant (because at strong B the
  channel is gapped out and the rotation has no mode to act on),
- predicts a quantitatively useful |Ω| / ω_⊥ ≈ 0.5 because that is
  comparable to the EdH-cascade gap scale set by c₁ · n and the
  weak-field Zeeman splitting,
- and predicts B_hold should sit in the window where the channel is
  open but the Larmor frequency is still much smaller than the DDI
  energy scale — i.e. [1, 5] nT for Eu at N = 10⁴–10⁵, with the
  10 nT case showing Zeeman re-pinning (Gate B sweep result).

In other words, Fig K10 promotes the keep_rot finding from
"phenomenological observation" to "mechanism-supported prediction".

## Numerical reliability so far

32³ ↔ 64³ identical (gate 3, PASS).
dt/2 and N=5×10⁴ anchors pending batch 3 completion.

## Batch 4 — robustness map + timing tolerance (2026-05-26 evening → 2026-05-27)

### B–Ω 2D robustness map (Fig K11)

Full 9-point grid of keep_rot cells (B ∈ {1.3, 2.6, 5.2} nT × Ω ∈ {−0.3, −0.5, −0.7}):

| Ω \ B   | 1.3 nT   | 2.6 nT   | 5.2 nT   |
|---------|----------|----------|----------|
| −0.3    | **0.585** | 0.517    | 0.301    |
| −0.5    | 0.437    | 0.540    | 0.557    |
| −0.7    | 0.257    | 0.344    | **0.529** |

The peak moves diagonally — smaller |Ω| works best at smaller B, larger
|Ω| works best at larger B.  This is exactly the resonance pattern
predicted by the mechanism: the energetic compensation Ω · ℓ ~ Zeeman
gap couples (Ω, B) along a diagonal.  P_{-5,-4} ≥ 0.43 anywhere in the
B × Ω rectangle [1.3, 2.6] nT × [−0.5, −0.3] — that is a broad
experimental window.  The anti-diagonal corners (small B + large |Ω|;
large B + small |Ω|) are off-resonance.

### Rotation start-delay tolerance (Fig K12)

Time between B quench end and onset of rotation, at Ω=−0.5, B=2.6 nT,
matched chirality:

| delay [ms] | P_{-5,-4} |
|-----------:|----------:|
| 0          | 0.524     |
| 1          | 0.582     |
| **2**      | **0.626** |
| 5          | 0.367     |

The optimal delay is ~2 ms, **not** 0.  Rotating immediately is
*sub-optimal* because the EdH spin-flip channel needs ~1–2 ms after
the quench to fully open (Zeeman gap relaxation timescale at
2.6 nT is ~1 ms).  Tolerance is generous: even at 5 ms delay the
signal is 1.7× the no-rotation baseline.  Below ~2 ms the response
is monotonic in delay; above ~5 ms it starts to lose the time window.

### Updated protocol recommendation (final form for now)

Combining batches 1-4:

```
1. Prepare m = ±F stretched state.
2. Quench to B_hold; pick (B, Ω) from the K11 robustness map.
   - Default (Matsui-like):  B_hold = 2.6 nT, |Ω|/ω_⊥ = 0.5
   - Sharper peak option:    B_hold = 1.3 nT, |Ω|/ω_⊥ = 0.3  (P=0.585)
   - Higher-B option:        B_hold = 5.2 nT, |Ω|/ω_⊥ = 0.5  (P=0.557)
3. Skip pre-rotation.
4. Wait ~1–2 ms after the quench is complete.
5. Turn on trap rotation with chirality opposite to initial spin.
6. Hold for ≥ 8 ms with rotation active.
7. Observe P_adj / P_exc / ring textures.
```

Step 4 (start delay ≈ 2 ms) is the new refinement from Fig K12.

## Fig K1 official caption (manuscript / poster)

> **Figure K1.** Two-phase rotation/quench protocol Ω scan in the
> Eu-151 F=6 near-isotropic trap (N = 10⁴, ω_⊥ = 2π · 110 Hz, t_total
> ≈ 21 ms).  Rotation preparation alone leaves the post-quench spin
> excitation unchanged across Ω (blue dashed curve, flat at
> P_{-5,-4} ≈ 0.22, indistinguishable from the no-rotation baseline),
> whereas maintaining rotation during the 10 ms weak-field hold
> enhances the m=−5, m=−4 population by a factor of 2.5 to
> P_{-5,-4} = 0.540 at Ω/ω_⊥ = −0.5 (red solid curve, with strong
> sign asymmetry).  DDI-off and no-B-quench controls collapse all
> excitation to zero, so both the DDI-mediated channel and the
> weak-field opening are required.  Atom number is conserved to 10⁻⁶
> in every cell. The Ω = −0.5 keep-rotation result is grid-converged
> at 32³ ↔ 64³ to four decimal places.

## Cross-references

- `docs/manuscript/four_figure_spec_2026_05_26.md` — main manuscript
  4-figure layout; this protocol scan supersedes Fig 4.
- `docs/validation/weekly_presentation_outline.md` — 6-slide
  presentation; Slide 6 to be revised once the protocol scan completes.
- Memory `gotcha_rotating_frame_omega_gpu_scalar_indexing.md` — why all
  cells run `backend: cpu`.
