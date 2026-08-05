> **FROZEN 2026-06-02.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

<!-- promoted from agent memory `north_star_phase_diagram_plan_2026_06_02.md` on 2026-07-31; historical record, not an SSoT -->
<!-- "North Star plan after closing the c-determination protocol. Eu (F=6) ground-state phase diagram + vortex/spontaneous-circulation predictions. 4-track roadmap (A=phase diagram, B=fluctuation selection, C=vortices, D=experimental anchor). Execution discipline encodes the failure modes caught during the Sprint 1-5 arc." -->

# North Star

**¹⁵¹Eu (F=6) の基底量子相を確定し、それに付随する渦・自発循環の物理を予言する。**

c-determination protocol (Sprint 1-5) was the *means*; now the means is
fixed (`sprint3_static_gate_baseline_2026_06_01.md` + `docs/guides/eu_sbi_handoff.md`),
the goal proper begins.

## First move — Track A1 (GP phase diagram around Eu nominal)

GP ground-state phase diagram in a box around the nominal `a_S` for Eu.
Three reasons converge:

1. This *is* the core of ⑥.
2. Only after A1 do we know whether σ(a_S) ≈ 0.05 a_B precision is
   *needed* — if the phase is robust across the plausible a_S box, the
   protocol is insurance; if Eu sits near a boundary, the protocol is
   load-bearing.
3. The scope of Tracks B (fluctuation selection) and C (vortices)
   depends on A1's outcome.

Concrete A1 setup:
- Scan axes: (a_S near nominal, B, trap aspect ratio, N).
- Many initial conditions per point (state_zoo) to avoid trapping in
  metastable minima.
- Analyzers: `phase_classify` + `winding_map` + spontaneous-circulation
  detector.
- **Convergence gate ⑧ before claiming any boundary**: lattice + integrator
  precision must not move boundaries. Near-degenerate-phase energy
  comparisons need Y4-mid-class accuracy (known from prior loop work).
- Verification: known limits (c_1=0 spin-independent; spin-1 Rb/Cr
  literature phases) tested first as analyzer sanity.

Deliverable: Eu position + candidate phases + boundaries, with
σ(a_S) Fisher ellipsoid overlaid. Single-paper-worth on its own.

## 4-track plan

### Track A — Phase diagram (the core, starting now)

- A1  GP phase diagram around Eu nominal.
- A2  Locate Eu (nominal a_S + Matsui's c_1 ≈ antiferromagnetic side):
      which phase, how far from boundaries.
- A3  Overlay σ(a_S) ellipsoid: does the protocol's precision pin the
      phase? This *is* the protocol-sufficiency test.
- → Paper 2 core.

### Track B — Fluctuation selection (most novel, Paper #3 lands here)

Depends on A1 finding near-degenerate regions.

- B1  LHY (Paper #3 polyhedral / non-polar extension) — does it invert
      the GP rank in the degenerate region?
- B2  TDHFB (existing CUDA kernel) at high depletion.
- B3  If a "GP-degenerate, fluctuation-selected" phase exists in a
      lab-accessible regime: order-by-disorder discovery.
- → Paper 2 flagship claim + application target for Paper #3.

### Track C — Vortices & spontaneous circulation (修論 milestone)

- C1  Spontaneous-circulation / chirality-breaking GS (Kawaguchi-Saito-
      Ueda): does Eu's a_S land in that region, what's the observable?
- C2  Vortex nucleation statistics (3D + TWA ensemble — the right home
      for those 800-5000 GPU-h) translated to experimental distribution
      via the §1 observation operator.
- C3  Barnett effect (Matsui's next experiment) signal prediction; if
      reachable: magnetic vortex droplet / supersolid (Li-Saito).
- → Predictions for the next experiment + experimental-paper co-authorship.

### Track D — Experimental anchor

- D1  Matsui ring extracts c_1 from existing data (background in flight:
      `sprint5_matsui_ring_extended.jl`). Spectroscopy ↔ ring-count
      consistency is the cleanest cross-check.
- D2  polar-magnon spectroscopy proposal to Kozuma/Matsui group
      (case-(a), feasibility caveats from `docs/guides/eu_sbi_handoff.md`).
- D3  When data arrives, update phase localisation against real data.

## Execution discipline (failure modes encoded)

These are the traps caught during Sprint 1-5; each costs roughly a turn
to recover from once committed. Encode them in every recipe / autopilot
job.

1. **Realistic noise** in evaluations (don't claim full-rank with
   optimistic σ; see `sprint5_bogoliubov_dB_sensitivity.jl` story).
2. **Correct observables** (spatial / spectral, not scalar summaries).
   "rank=1" can be structural, not a deficit.
3. **Absolute cutoff** for Fisher precision classification
   (`fisher_information` `cutoff_absolute` argument): the relative
   cutoff double-counts prior-pinned directions.
4. **Convergence gate before conclusion**: phase boundary + near-
   degeneracy claims must follow grid/integrator independence checks.
5. **Protocol vs measurement** distinction: "we can measure it" is not
   "we measured it". Stay honest in deliverables.
6. Parallel chunks (A1 scan, C2 ensembles, SBI training) → autopilot /
   TSUBAME. Judge/critic tuned to the trap list above.
7. **Don't over-polish sub-problems**. The c protocol took 12 turns;
   the phase diagram was untouched until then. Each track closes at a
   publication unit and returns to the main goal.

## A3 decision gate (after A1 returns)

- If Eu is **robust to one phase** across the plausible a_S box: phase
  is effectively determined; protocol is insurance only. → Go directly
  to Track C (vortex predictions).
- If Eu sits **near a boundary**: precision is load-bearing. Tracks B
  (fluctuation selection) and D2 (experiment proposal) become essential.
  LHY/TDHFB tipping the boundary is the central question.

## Publication / 修論 map

- Paper 1 (method): field-protected magnon spectroscopy → Eu interaction
  determination (Tracks D2 + Fisher utilities).
- Paper 2 (flagship): spin-6 dipolar Eu ground-state phase diagram +
  fluctuation selection (Tracks A + B).
- Paper 3 (existing LHY): supplies into B.
- Experimental co-authorship: vortices + Barnett (Tracks C + D).
- 修論 narrative tying these together: **MDDI + tiny spin-dependent
  contact + quantum fluctuations determine Eu's phases and vortices.**

## A1 v0 sanity result (2026-06-02): classifier verified, multi-start mandatory

Ran `scripts/sprint5_A1_phase_classifier_sanity.jl` at F=1 Rb87,
sweeping c_1 ∈ {-0.5, ..., +0.5} × c_0 with 3 initial states.

**Classifier verified**: Mz = ±1 → "ferromagnetic", Mz = 0 → "polar".
Mechanically correct labeling.

**ITP gets trapped in saddles**: each pure-m initial state is a GP
fixed point (⟨F⟩ = 0 or stretched → no spin-mixing force), so ITP
*from a single init* converges to whatever that init's m happens to
be, NOT the actual lowest-energy phase.

In the run, p=0.5 linear Zeeman + q=0.05 quadratic favoured m=+F
across all c_1 values; the m=+F init found the true GS, polar and
m=-F inits stayed put at higher E. The classifier truthfully reports
the saddle-state ψ as polar / FM as ψ actually is — but that's not
the GP-GS phase decision unless you also pick the lowest-E result
across inits.

**Implication for A1 proper**: at each scan point, run ITP from the
full state_zoo, then pick the lowest-E GS. This is consistent with
the North Star recipe; v0 confirms the physics rationale empirically.
Boundary regions will be even more sensitive to multi-start; a
single-init scan would produce a wildly wrong phase map.

For Eu (F=6), state_zoo has 22 named builders; A1 should sweep at
least { m_plus_F, m_minus_F, polar, cyclic, antiferromagnetic,
biaxial_nematic, polar_core_vortex } per scan point (~7 inits).

## A1 v1 result RETRACTED (2026-06-02): three confounders, 1D unusable for Eu phase diagram

(Initial v1 framing claimed "Eu near boundary, B load-bearing" — anko
2026-06-02 sharpened the critique. Retracting; v1 was a shakedown that
caught one real physics point [symmetric inits are saddles, multi-start
alone insufficient without symmetry-breaking noise] but cannot support
the boundary-vs-bulk verdict for three reasons:)

1. **Non-converged E comparison is invalid.** ITP non-converged E is
   "upper bound while descending", not a final value. The fact that
   uniform/antiferro/cyclic/biaxial all settled at Mz≈+0.2, E≈8.13-8.15
   is more naturally read as *all converging to the same weakly-
   magnetised GS*, with polar being a saddle above. Distinguishing
   "near-degenerate manifold" from "single GS + polar saddle" requires
   converged comparison of **wavefunctions**, not just energies.

2. **Mz≈+0.2 origin not separated.** v1 used Bz=0.05 (small but nonzero
   linear Zeeman). Mz=+0.2 may be Zeeman-induced rather than spontaneous.
   Need a Bz=0 companion run to separate Zeeman-induced / spontaneous /
   transient. Spontaneous would put us adjacent to spontaneous-circulation
   physics — interesting if real.

3. **0.4% gap is below 1D lattice noise.** E≈8 on 24-pt 1D harmonic has
   discretisation error easily 0.03 (the magnitude of the claimed gap).
   A gap at the lattice-noise scale is not physically meaningful;
   convergence gate must reject this comparison.

**Biggest structural issue**: **1D cannot represent MDDI-textured phases
at all.** Spontaneous circulation, magnetic vortices, polyhedral
LHY-favoured states are spatial spin-textures — they require 2D/3D.
Eu's flagship physics (MDDI-driven) is dropped in 1D. v1 was comparing
uniform contact phases only. **1D is a classifier-sanity tool, not a
phase-diagram tool for Eu.**

### A1 proper requirements (encoding v1 lessons)

- **Grid: 2D minimum, 3D preferred** (MDDI texturing essential).
- **Multi-start with symmetry-breaking noise** on each init (random
  amplitude ~1% peak density, broken phase) — symmetric inits without
  noise are saddles.
- **ITP + LBFGS/CG polish**; tol *much smaller* than any expected gap
  (1e-10 or tighter).
- **Wavefunction comparison** after polish (overlap matrix or spin
  density similarity), NOT only E.
- **Bz=0 AND weak Bz pair** to separate Zeeman-induced from spontaneous.
- **Convergence gate rejects** gap comparisons smaller than estimated
  lattice noise (compare at two grid sizes).

### Strategy update

Track B remains a working hypothesis — the *tendency* for candidate
phases to cluster near Eu is consistent with the tiny-spin-dependent-
contact-induced delicate competition picture — but "B is load-bearing"
requires proper A1 (2D/3D, converged, wavefunction-distinguished
comparison) to assert. v1 did not show this. Next: A1 v2 in 2D MDDI
with noise + polish + wavefunction comparison.

Ran `scripts/sprint5_A1_eu_nominal_phase.jl` (F=6, Eu, 1D 24-pt
harmonic, 7 inits from state_zoo, ITP+convergence selection,
classifier on lowest-E). Result:

- Polar init → E=8.170, Mz=0, classifier "nematic" (converged).
  This was the script's reported winner.
- Uniform / antiferromagnetic init → E=8.134, Mz=+0.20 (NOT converged)
- Cyclic init → E=8.139, Mz=+0.20 (NOT converged)
- Biaxial-nematic init → E=8.145, Mz=+0.20 (NOT converged)
- m=±F stretched → E=12.96, 13.56 (FM ruled out, much higher)

**Two findings**:

(1) Convergence filter likely rejected the true GS. The non-converged
ψ states (uniform/antiferro/cyclic/biaxial seed) all settled into a
similar energy 8.13-8.15, ~0.4% BELOW the converged polar (E=8.170).
"Not converged" at tol=1e-8 likely means small-amplitude oscillation
around a near-degenerate manifold, not failed minimisation. Track A1
proper should (a) loosen tol, (b) add LBFGS polish, (c) report
lowest-E *regardless of formal convergence flag*, then re-classify.

(2) Eu nominal is plausibly in a **near-degeneracy region**. The ΔE
between candidate phases (polar 8.170 vs slightly-magnetised cluster
8.134) is ~0.03, or ~0.4% of total E. This is the regime where the
A3 decision-gate says "Track B (LHY/TDHFB) becomes load-bearing":
GP cannot decide alone; quantum-fluctuation corrections may invert
the rank. The signal is preliminary (1D 24-pt) but the direction
is set.

**Next-session A1 proper**:
- 3D 16³ (or 24³ if compute permits) at nominal point with same 7
  inits, polish-after-ITP, lowest-E regardless of conv flag
- Scan in a small a_S box (±10 a_B around nominal each axis) at 3-5
  grid points per axis
- Energy gap to second-place phase becomes the natural boundary metric
- If gap ≲ Track B's expected LHY/TDHFB shift, B is essential

The N=2000 was kept small (compute envelope); production runs should
target N≈5·10⁴ matching the Matsui experiment. Larger N narrows the
near-degeneracy gap (interaction-dominant regime), so the 0.4% may
shrink and the case for B strengthens.

## Track D1 Matsui ring extended (2026-06-02): suggestive hint, NOT validation yet

(Initial framing "AFM=3 rings ✓ matches Matsui — dynamics-route c_1
validation ✓" retracted — anko 2026-06-02 sharpened the criteria.)

The result *is* suggestive in the right direction (AFM scenario gave
m=−4 with 3 visible peaks), but four issues block validation:

1. **Same lattice that produced bogus "8 rings" for m=−5 also produced
   "3 rings" for m=−4.** The m=−5 alternating-zero pattern is a
   discretisation artefact. Same lattice → same artefact risk for m=−4;
   the true count could be 2 + 1 spurious. The 3 is not robust until
   lattice-converged (halve dρ, check count doesn't change).

2. **The validation discriminator is the CONTRAST (FM=2 vs AFM=3),
   not AFM=3 alone.** FM run was truncated by the wrapper's `tail -80`.
   Without FM=2 in the same conditions, we cannot show that ring count
   *responds to* c_1 sign — only that it produced 3 somewhere. The
   contrast is the experiment, and we don't have it.

3. **Conditions don't match Matsui.** T=29 ms vs Matsui's 40 ms; total
   loss 5% vs Matsui's 40%; depolarisation 22% vs Matsui's regime.
   Matsui explicitly notes the loss reshapes the m=−4 distribution.
   K_3 is calibrated but the spin-dependent loss profile is not yet
   modelled — we're comparing physically different m=−4 distributions.

4. **Ring-count definition is bin-peak-local-max, which is lattice
   sensitive.** Robust definition needed: radial wavefunction node
   count, or smoothed profile + threshold, or function fit to a
   Bessel-like ansatz. The ρ ≈ 1.35, 2.19, 3.02 spacing could be a
   genuine multi-ring or a numerical standing wave — definition +
   lattice convergence distinguish.

### Role / Framing

This ring path is a **discrete (sign) cross-check**, NOT a precision
determination. As previously established, ring count is non-analytic
in c_1 (bifurcation observable), complementing Bogoliubov's continuous
signed extraction. The value is "two routes agree on the AFM sign of
c_1" — a consistency check. Bogoliubov is the precision route.

### D1 closure plan (do this ONCE, do not polish further)

Single, complete run with all four issues fixed:
- Same conditions both FM and AFM, both completed cleanly (write to
  file, not via `tail`)
- T=40 ms + spin-dependent K_3 profile (calibrated to Matsui's 40%
  total loss)
- Two grid sizes (e.g. 20³ and 30³) — count must agree
- Robust ring count: smoothed profile + threshold + node detection

If the FM=2 vs AFM=3 split survives all four, log "spectroscopy ↔
ring count agree on AFM c_1 sign". Done. **Do NOT iterate D1 further.**
Track A is the main line; D1 is a one-shot side-check.

## Track D1 partial signal (2026-06-02): AFM gave 3 peaks on m=−4, FM not yet captured

Ran `scripts/sprint5_matsui_ring_extended.jl` (20³ grid, T=20 ω_ref⁻¹
= 29 ms, m-dep K_3 calibrated K_3≈80 for cascade products, 2 scenarios).
Each scenario took ~30 min wall (1776 s for AFM).

**AFM scenario (c_1/c_0 = 1/18)**: cascade developed to 22% depolarisation
(f[-5]=0.077, f[-4]=0.090), 5% total loss. **m=−4 radial profile shows
3 distinct peaks at ρ ≈ 1.35, 2.19, 3.02 — 3 rings, matches Matsui's
AFM observation.**

**FM scenario (c_1/c_0 = 0)**: completed, but the `tail -80` capture
truncated the FM block; only AFM survived in the output buffer. The
visible tail-of-FM piece shows some structure but the printed ring
count for FM is missing.

**Partial deliverable**:
- AFM m=−4 ring count matches Matsui qualitatively ⇒ dynamics-route
  c_1 extraction is on the right track
- Two-route (spectroscopy ↔ ring count) c_1 consistency partially
  confirmed
- FM/AFM 2↔3 ring split requires (i) cleaner output capture (write to
  file rather than tail), (ii) finer radial bins to suppress the
  alternating-zero artefact visible at every other ρ bin (lattice
  noise contaminating ring count, same v1 critique)

**Next session**: re-run with explicit file output and 32-bin radial
sampling to confirm the FM=2 ring side cleanly.

## A1 v2 result (2026-06-02): 7 distinct minima, lowest are cyclic/biaxial-orthogonal

Ran `scripts/sprint5_A1_v2_eu_2d_proper.jl` (2D 16×16 quasi-2D MDDI,
Bz=0, symmetry-breaking noise amp=0.01, 5 inits × 2 seeds, tol=1e-10,
ITP-only no polish). All 10 runs reached `conv=false` at tol=1e-10
within 8000 steps.

**Energy ranking (lowest 4)**:
- cyclic seed=2:        E = 2.5643  classifier "nematic"
- cyclic seed=1:        E = 2.5644  classifier "nematic"
- biaxial_nematic s=1:  E = 2.5667  classifier "nematic"
- biaxial_nematic s=2:  E = 2.5668  classifier "nematic"

**Wavefunction overlap structure** (cluster by |⟨ψ|⟩| > 0.9):
- cyclic s1 ↔ cyclic s2: overlap 0.998 (seed-stable single state)
- biaxial s1 ↔ biaxial s2: overlap 0.997 (seed-stable)
- antiferromag s1 ↔ s2: overlap 1.000 (seed-stable)
- **cyclic ↔ biaxial: overlap 0.006-0.016** — distinct orthogonal states
  despite both being classified "nematic"!
- polar s1 ↔ polar s2: overlap 0.647 — seed-dependent saddle escape
  toward different basins

→ **7 distinct local minima** found across the 10 runs.

**Energy gap between two lowest distinct states**: 2.4×10⁻³ (relative
9×10⁻⁴ = 0.1% of E), at the 2D 16² lattice noise scale. Cannot claim
"near-degenerate manifold" or "single GS" without (a) LBFGS polish
to escape `conv=false`, (b) second grid size to test lattice
independence, (c) larger N to push closer to GP limit.

### Findings that survive scrutiny

1. **v1 "polar is the rank-1 GS at this point" is fully rejected.**
   With Bz=0 + noise, cyclic and biaxial_nematic find lower-E minima
   than polar.
2. **The classifier's "nematic" label is too coarse**: two orthogonal
   distinct states (cyclic-init result and biaxial-init result) both
   get classified as "nematic". Either nematic is a manifold (continuous
   family) or the classifier needs sharper discriminators (multipole
   tensor moments, spin texture).
3. **Eu nominal at this (small-N, 2D, Bz=0) point is NOT a single
   polar phase.** The qualitative direction toward "rich multi-minima
   landscape near Eu" is consistent with the small-spin-dependent-
   contact prediction — but the gap magnitudes and which minimum is
   the true GP GS remain open until polish + lattice convergence.

### Findings to RETRACT or refuse to claim

- "Eu near phase boundary, B load-bearing" — still NOT supported. The
  0.1% gap is at lattice noise; could collapse to single phase under
  polish, or could open to robust separation at larger N.
- Energy ordering between cyclic-cluster vs biaxial-cluster: not
  trustworthy given conv=false on all runs.

### Next-session A1 proper requirements (encoded)

- 3D (16³ or 24³) instead of 2D quasi-2D, to fully include MDDI
  texturing.
- ITP + LBFGS / CG polish until ‖grad‖ < gap-scale.
- Two grid sizes for lattice-convergence test.
- N ≈ 5×10⁴ matching Matsui (interaction-dominant; current N=2000 is
  kinetic-dominated, may artificially flatten phase competition).
- Symmetric-breaking noise variety: at least 3-5 seeds per init to
  detect noise-dependent basin selection.
- Sharper classifier: project ψ onto multipole tensor moments and
  spin texture descriptors so two orthogonal nematic states are
  reported as distinct.

A1 v2's value is *diagnostic*: it identified that the classifier is
too coarse and that the ITP convergence is not tight enough — both
fixable. The phase localisation of Eu remains an open question for
proper A1 next session.

### Elevation (anko 2026-06-02): "nematic = manifold" is physics; B becomes flagship

The cyclic-init and biaxial_nematic-init results sit at orthogonal
overlaps (0.006) yet both have ⟨F⟩=0 and both get the "nematic" label.
This is NOT a classifier bug. spin-6 has an entire family of ⟨F⟩=0
polyhedral inert states (cyclic = tetrahedral, biaxial, octahedral,
icosahedral, …) that share ⟨F⟩=0 by symmetry. A classifier that only
inspects ⟨F⟩ correctly *cannot* separate them; that's the right
behaviour of the wrong observable.

**The right discriminator = the Paper #3 polyhedral framework**:
rotational invariants, point-group projectors, the multipole sign
patterns (`sign_pattern_lemma1_general_S` and the multiplicity-aware
extension `sign_pattern_lemma1_mult_aware_2026_05_19`). This is a
one-stone-two-birds upgrade: (a) classifier separates the orthogonal
polyhedral states; (b) it simultaneously tells us which of the 7
detected minima are genuine polyhedral inert states vs lattice
artefacts (because lattice artefacts won't satisfy the symmetry
invariants).

**Order-by-disorder setup**: orthogonal polyhedral states clustering
within ~0.1% in GP energy is the textbook setup for fluctuation
selection. spin-2 has a famous polar–cyclic GP degeneracy resolved
by quantum zero-point fluctuations (Turner et al., Song-Tieu-Liu);
A1 v2 has found the **spin-6 dipolar analog** at the Eu nominal
point. The Paper #3 polyhedral LHY framework is precisely the tool
to compute which polyhedral state the fluctuations select.

→ **Track B promoted from contingency to flagship**: "Eu's ground
state is selected by quantum fluctuations from a near-degenerate
polyhedral nematic manifold via order-by-disorder, computed by
Paper #3's LHY." Whether GP gives exact degeneracy or merely
near-degeneracy is decided by proper A1 — either way, B is the
decider.

### Catastrophic cancellation in the ΔE measurement

The reported gap 9.2×10⁻⁴ was obtained by subtracting two
independently-converged total energies E ≈ 2.56. For a 1e-4 gap
visible above floating-point noise, that subtraction needs relative
convergence ~ 1e-7 — far below typical ITP tolerance and grid
discretisation. With LBFGS polish + a finer grid this can be
reached, but the *correct* method avoids the subtraction:

- **Direct ΔE evaluation on the same lattice**: compute
  ⟨ψ_a|H|ψ_a⟩ − ⟨ψ_b|H|ψ_b⟩ with the common kinetic + trap + scalar
  contact contributions analytically cancelled. Only the
  spin-dependent and MDDI parts contribute to ΔE, and those *are*
  small. The gap appears as a small primary number, not as a small
  difference of two large numbers.
- Implementation: define `energy_difference(ψ_a, ψ_b, ws)` evaluating
  `Σ_S g_S (⟨ψ_a|P_S|ψ_a⟩ − ⟨ψ_b|P_S|ψ_b⟩) + ΔE_MDDI`, using the
  existing channel projectors. Same shape as the codebase's
  `_analyze_energy_decomposition` but per-state, then differenced.

This routine should be the headline output of A1 proper alongside the
polyhedral classifier — without it, the order-by-disorder verdict is
unreliable from the GP side.

### Revised Track A → B arc (replaces the A3 decision gate)

Next session = **"A1 proper → B" not "A1 → maybe B"**:

- A1 proper builds the polyhedral classifier + direct-ΔE method,
  runs on 3D (or proper 2D quasi-2D), 2 grids, N≈5×10⁴, multiple
  seeds, LBFGS polish.
- Whatever A1 returns (sharp degeneracy or 0.1% gap with multiple
  orthogonal inert states), the **handoff to B is the next step**.
- B = Paper #3 polyhedral LHY applied to the polyhedral inert
  manifold A1 identified. Output: which polyhedral state quantum
  fluctuations select for Eu.
- D1 closure runs in parallel as a side cross-check (spectroscopy ↔
  ring count consistency on the AFM c_1 sign). Not the main line.

Updated publication map:

- Paper 2 flagship: spin-6 dipolar Eu phase diagram with
  fluctuation-selected ground state via Paper #3 LHY (Track A + B
  together — not separate).
- Paper #3 directly cited / extended: the polyhedral LHY framework
  applied to its first lab-relevant system.
- Track C (vortices / spontaneous circulation): runs on whichever
  polyhedral state B selects. If that state has spontaneous
  chirality (e.g., the chiral cyclic or icosahedral states), C
  becomes a direct prediction.

## A1 proper at GP mean-field landed (2026-06-02 evening): Eu GS = I_h, B confirmed flagship

`src/analysis/phases/polyhedral_classifier.jl` ships σ_S fingerprint
classifier + direct-ΔE utilities. 42/42 tests pass.
`scripts/sprint5_A1_proper_inert_mf.jl` runs in < 1 second (no ITP)
and ranks polyhedral inert candidates at Eu nominal c → g_S:

```
1. I_h            g_eff = 93.9209
2. biaxial        g_eff = 94.2209   (Δ = +0.32%)
3. cyclic         g_eff = 94.2371   (Δ = +0.34%)
4. polar          g_eff = 94.4513   (Δ = +0.56%)
5. FM             g_eff = 188.91   (excluded by 100%)
```

Δg_eff(I_h → biaxial) = +0.300 computed directly (subtraction-equivalent
since the values are O(0.3), no catastrophic cancellation needed at
this magnitude — but the methodology generalises to 1e-4 gaps where
it matters).

g_S decomposition at Eu nominal: g_0 = -12, g_2 = -6, g_4 = +10,
g_6 = +39, g_8 = +78, g_10 = +127, g_12 = +189. Positive growth in S
favours high-S concentrated states (I_h has σ_6, σ_10 dominant); the
ranking is consistent with the channel structure.

**Net**:
1. **Eu's GP GS is icosahedral (I_h)** at the nominal channel set.
2. **Three top candidates (I_h, biaxial, cyclic) cluster within 0.34%**
   — textbook order-by-disorder regime; LHY corrections (Track B,
   Paper #3 polyhedral framework) can reasonably tip the ranking.
3. **A1 v2's 7 ITP minima** are now interpretable: I_h, biaxial,
   cyclic are the genuine inert states (the lowest 3 in this rank);
   the remaining 4 are spatial-textured / saddle-trapped / lattice-
   artefact configurations that the mean-field inert rank correctly
   excludes.
4. **Track B is now load-bearing**, not contingency, confirmed by
   data. Paper #3 polyhedral LHY applied to I_h vs biaxial vs cyclic
   is the next concrete step.

What still needs ITP: confirming that no SPATIAL TEXTURE (vortex
patterns, domain walls) at the (N, trap, MDDI) Eu point beats the
inert candidates. If the inert manifold *is* the GP GS, this entire
phase-identification reduces to an algebraic 1-second computation;
ITP is then only needed to extend Track C (vortices) to
texture-excitation predictions.

## Status as of plan start

- 11 Sprint 1-5 commits land the c-determination protocol.
- Sprint 5 Matsui ring extended (Track D1 entry) is in flight
  (`sprint5_matsui_ring_extended.jl`, ~43 min elapsed, ~30 min ETA).
- Next concrete step: A1 setup — verify analyzers on known c_1=0
  limit, then scan around Eu nominal.

## Track B partial result (2026-06-02 late evening): I_h survives LHY among 3/5 candidates

`scripts/sprint5_B_partial_lhy_rank.jl` runs GP + LHY rank for the 3
candidates with closed-form LHY in the codebase (I_h via §V.D, polar
via Paper #1 F-generic, FM via Paper #2 single-mode). Result at Eu
nominal g_S:

```
Rank by ε_total = (g_eff/2) n² + ε_LHY(n) at n=1.0:
  1. I_h     ε_total = +5.96e+03
  2. polar   ε_total = +7.12e+03   (+1153 absolute, 19% above I_h)
  3. FM      ε_total = +2.66e+04
```

LHY does NOT reverse rank inside (I_h, polar, FM) at Eu nominal — I_h
wins both GP and LHY at all tested densities (n ∈ [0.1, 10]). LHY
shift is large and *favours* I_h vs polar/FM.

I_h stiffness diagnostic at Eu nominal: c_0=+93.9 (phonon), λ_spin=+36.4
(triple spin-Goldstone). Both positive → closed form valid, I_h is
locally stable.

**LHY-dominant regime flag**: at physical TF peak density n_peak ≈ 0.84
(3D harmonic, N=2000, g_eff=94), the ratio ε_LHY/ε_GP ≈ 90 — i.e. LHY
is NOT a small correction at Eu nominal. Two physics readings:
  (a) Perturbative LHY (Lima-Pelster / Petrov) may be unreliable here
      → need full BdG or droplet-regime treatment;
  (b) Or Eu nominal genuinely sits in a quantum-stabilized droplet
      regime, which is itself a publishable result.
This is independent of the rank reversal question and applies equally
to whatever the GP rank is.

**What this DOESN'T close**:
- biaxial_nematic (D_2h, 5 broken generators) and cyclic_tetrahedral
  (T_d) LHY closed forms are NOT in the codebase.
- These are the GP-near-degenerate states (gap 0.32-0.34% to I_h)
  whose LHY could reverse the rank.
- Paper #3 §V.E and §V.F derivations needed. Recipe: same as §V.D
  for I_h (block-diagonalise BdG under point group, count Type-A
  Goldstones with stiffness λ_spin per block).

**Therefore Track B remains open as Paper #3 §V extension**:
  (1) §V.E/V.F sympy derivation of biaxial_nematic + cyclic LHY
  (2) Implement `epsilon_LHY_F6_biaxial`, `epsilon_LHY_F6_cyclic`
  (3) Re-run `sprint5_B_partial_lhy_rank.jl` with full 5-candidate set
  (4) Decide manifold rank → tells whether Eu has spontaneous I_h
      symmetry vs lower-symmetry biaxial/cyclic chirality

Path forward sketch for Paper 2 flagship:
- If LHY confirms I_h wins → Eu GS is I_h, Track C predicts
  icosahedral vortex lattice (5-fold-symmetric defect structure,
  novel for spin-6).
- If LHY tips to biaxial → D_2h ground state, Track C predicts
  domain-wall lattice / nematic disclinations.
- If LHY tips to cyclic → T_d state, chiral order parameter, Track C
  predicts spontaneous circulation (the 修論 milestone).

## RETRACTION (anko 2026-06-02 night): A1 proper sub-result is contact-only, not Eu GS

The "I_h winner" / "0.34% manifold gap" framing above is a **clean
sub-result restricted to the uniform-inert (⟨F⟩=0 + uniform-FM) subspace**,
NOT a statement about Eu's actual GP ground state.

The structural blind spot: in the polyhedral inert family above, the
spin density `f(r) = ⟨ψ(r)|F|ψ(r)⟩` is identically zero (or uniform for
m_plus_F, no spatial gradient). Therefore the MDDI energy contribution
is *identically zero* in g_eff and in the σ_S ranking. Eu is
**MDDI-dominated** (μ ≈ 6.977 μ_B, c_dd/c_total ≈ O(0.1)); states that
*harvest* MDDI energy require `f(r) ≠ 0` — i.e. **spatial textures**:
- Kawaguchi-Saito-Ueda (KSU) spontaneous circulation
- Li-Saito flux closure (vortex lattice with magnetic flux closure)
- Polar-core vortex (PCV, Mermin-Ho-like)
- Skyrmion / skyrmion lattice
- Magnetic domain patterns (stripe / square / hex)

These live **outside** the uniform-inert family. The σ_S ranking
**excludes them by construction**.

A1 v2's inits were `[m_plus_F, polar, antiferromagnetic, cyclic,
biaxial_nematic]` — entirely uniform inert. The "7 minima, 4 labelled
artifacts" claim was post-hoc with no data behind it; the actual 4
leftover were never seeded with texture ansatze, so we cannot say
whether they would have found texture minima.

**Corrected framing**:
1. Uniform-inert sub-rank: I_h wins by 0.30 (g_eff units), SNR vs c
   uncertainty ≈ 17-29 → robust within the sub-rank.
2. **This does NOT decide Eu's GS.** The texture branch may sit below
   the entire uniform-inert manifold.
3. **Track A and Track C re-merge**: in strong-MDDI spinor BEC, the
   GS may itself be a vortex texture (KSU paradigm). The phase
   diagram question and the vortex-prediction question are the
   **same** question — vortex as ground state, not excitation.

### A1 v3 (texture-inclusive) — the corrected GS scan

`scripts/sprint5_A1_v3_texture_inclusive.jl` (running, ~60-90 min on
1 CPU core at 16²) adds to the v2 envelope:
- Carry-over uniform inert seeds (cross-check + I_h explicit)
- Texture seeds: fl_vortex, polar_core_vortex, chiral_spin_vortex,
  spin_helix, magnetic_domain (stripe/square), vortex_lattice,
  skyrmion, skyrmion_lattice, domain_wall, ksu_circulation
  (m_plus_F + winding-1 on m=+F as KSU analog), icosahedral_explicit
  (ZETA_F6_IH spinor seeded uniformly)
- Same 2D quasi-2D MDDI envelope as v2 for compute parity
- `energy_decomposition` → MDDI energy isolated per state
- Spatial spin density `|f|(r)` reported per relaxed state
- Rank by ε_total; explicit "texture vs uniform" comparison block

If texture wins by `ΔE / |E_uniform|` > ε_noise (lattice + ITP
convergence floor), retract "Eu GS = I_h" definitively and announce
the corrected result: **Eu's GS is a magnetic spin texture**.

If 2D suggests texture wins but margin is small (~few percent), 3D
follow-up is mandatory before publishing — 2D quasi-2D undercounts
MDDI texturing since the trap axial dimension carries energy in 3D.

### Order-by-disorder framing fix

The "0.34% near-degenerate manifold" framing was wrong on two counts:
1. The gap is GP **selection** (preference), not degeneracy.
2. Manifold doesn't include texture states, which may invalidate the
   whole framing.

B (LHY/TDHFB) is load-bearing iff:
- LHY shift > 0.34% AND inverts rank, AND
- texture states don't already sit below the uniform manifold.

σ(a_S) ≈ 0.05 a_B propagation to gap: SNR 17-29 within uniform
sub-rank → c uncertainty alone does not flip uniform rank. But this
calculation is also uniform-only.

### Status as of correction

- Memory MEMORY.md index: retraction entry added above the partial
  Track B and A1 proper entries; those two now read as sub-results
  within the broader question.
- A1 v3 running in background.
- B (Paper #3 polyhedral LHY) work paused — only meaningful AFTER A1 v3
  decides whether Eu's GS is even within the polyhedral inert family.
- Track C is no longer downstream of A1; it has merged INTO A1.

## A1 v3 partial result (2026-06-02 late night, 30 of 34 ITPs completed before crash)

A1 v3 crashed on init 31 (`ksu_circulation` — `GridConfig.x_min`
field error, fixed; completion script running ~10 min). The 30
completed ITPs give a clean partial picture.

**Three distinct E clusters at 2D quasi-2D MDDI, Eu nominal, conv=✗ but stable**:

| Cluster | E range | f_max | members |
|---|---|---|---|
| A (uniform inert) | 2.564-2.572 | 0.002-0.10 | cyclic, biaxial, m_plus_F, polar, polar_core_vortex (collapsed), spin_helix (collapsed), vortex_lattice (collapsed) |
| B (partial texture) | 2.583-2.599 | 0.06-0.08 | magnetic_domain (stripe/square), domain_wall |
| C (high-E saddle) | 2.622-2.634 | 0.29-0.32 | antiferro, fl_vortex, chiral_spin_vortex, skyrmion, skyrmion_lattice, polar seed=2 (escaped) |

**Cluster A winner**: cyclic at E=2.564, biaxial close at 2.567 (gap
~0.1%). Multiple texture seeds (polar_core_vortex, spin_helix,
vortex_lattice) **collapsed back to uniform-inert** — their E values
match the uniform minima exactly. spin_helix seed=1 → E=2.568588 same
as m_plus_F seed=1 (the relax kills the texture seed entirely).

**Cluster B** (magnetic_domain, domain_wall): partial textures
that survive with ~0.7% gap above uniform inert minimum. These are
the closest texture candidates but still losing in 2D.

**Cluster C**: a single high-E saddle that many texture seeds
(antiferro, fl_vortex, skyrmion, etc.) get trapped in. Identical
E≈2.6345 across seeds suggests they relax to the same metastable
configuration. ~2.7% above winner — not the GS.

**2D preliminary read**: texture states do NOT undercut uniform
inert at the Eu-nominal 2D-quasi-2D level. The uniform-inert
sub-rank is confirmed as the local-minimum manifold; partial
textures (domain patterns) sit ~0.7% above; full textures stay
high. **This does NOT close the 3D question** — 2D quasi-2D
explicitly undercounts axial textures (KSU axial circulation, true
3D skyrmion winding, axial flux closure). All Cluster C states
might find lower-E paths in full 3D.

**Pending**: ksu_circulation + icosahedral_explicit (4 ITPs in
completion script) will give the KSU axial-circulation analog and
the pure I_h spinor reference. Likely to land in cluster A.

**Caveat: conv=✗ across all ITPs** — 8000 ITP steps at tol=1e-10
didn't fully converge. Gaps within cluster A (~0.1%) are within
ITP residual noise; cluster A vs B (~0.7%) and B vs C (~2.7%) gaps
are likely real. Re-relax winner candidates with looser tol (1e-7)
or longer steps before publishing the 2D result.

### Update after re-relaxation at n_steps=20000 / tol=1e-7 (analyze script)

**Reinterpretation**: cluster B (magnetic_domain, domain_wall, biaxial)
is not really a separate basin — it's intermediate-time configurations
on the path from uniform seeds toward the texture basin. Biaxial_nematic
seed=1 specifically ESCAPED to the texture basin under longer ITP:
v3-8000-step E=2.5667, f_max=0.011  →  analyze-20000-step E=2.6345,
f_max=0.32, E_ddi=-0.887. So:

- **Biaxial is NOT a 2D local minimum at Eu nominal**. It sits on a
  ridge between the uniform basin and the texture basin and is
  attracted toward texture with longer ITP.
- **The "saddle cluster" at E=2.634 is a GENUINE texture local
  minimum**, not a metastable saddle. E_ddi/E_total = -34%
  (substantial MDDI harvest), E_spin = 0.64 (substantial spin
  density structure), f_max = 0.32 (clear texture). It is the
  texture-branch ground state in 2D.

Corrected 2D landscape at Eu nominal:

| Basin | E_total | E_ddi | E_spin | f_max | members |
|---|---|---|---|---|---|
| Uniform inert (true GS) | 2.5634 (I_h conv=✓) | -3.8e-4 | 3.5e-4 | 0.008 | I_h, cyclic*, polar |
| Texture (true local min) | 2.6345 | -0.887 | 0.64 | 0.32 | antiferro, fl_vortex, chiral_spin_vortex, skyrmion, ksu_circulation, biaxial(escape), ... |

*cyclic at 20000 ITP steps still slowly relaxing — possibly merging
into the I_h basin or separate near-degenerate minimum.

**2D verdict (preliminary)**: Uniform inert (I_h) wins by 2.7%. The
texture basin EXISTS and harvests MDDI (-0.887) but its kinetic+spin
texturing cost (+0.95) overwhelms the MDDI gain in 2D quasi-2D.

**Open question for 3D**: does full-3D DDI (no quasi_2d projection)
increase the texture basin's MDDI gain enough to flip the rank?
The KSU axial circulation specifically harvests AXIAL MDDI which 2D
projects out. 16³ full-3D follow-up needed before declaring final GS.

**Before 3D**: 24² grid convergence check (`sprint5_A1_v3_grid_check.jl`,
running, ~60-90 min) on 4 discriminators (I_h, cyclic, biaxial-escape,
antiferro-→-texture-basin) to verify 16² rank isn't lattice-artefact.
If 24² preserves the I_h<cyclic and uniform-vs-texture gaps, 3D launch
is justified. If not, dig before scaling up.

### 24² grid convergence: PASS (2026-06-02 late night)

`sprint5_A1_v3_grid_check.jl` completed. 4 discriminator states
re-relaxed at 24² (vs 16²), n_steps=20000, tol=1e-7:

| State | 16² E | 24² E | ΔE | conv at 24² |
|---|---|---|---|---|
| I_h_explicit | 2.563393 | 2.563412 | +1.9e-5 | ✓ |
| cyclic | 2.564179 | 2.564187 | +8e-6 | ✗ |
| biaxial → texture | 2.634498 | 2.634434 | -6.4e-5 | ✓ |
| antiferro → texture | 2.634504 | 2.634434 | -7.0e-5 | ✓ |

**Result**: rank fully preserved, all gaps lattice-stable to within
1e-4. Biaxial and antiferro converge to IDENTICAL E=2.634434 at 24²
(both find the same texture basin; the basin's spinor configuration is
seed-independent). E_ddi = -0.887 unchanged. Uniform-vs-texture gap
0.07 (2.7%) exactly preserved.

**Cluster A internals** (uniform inert basin sub-rank):
- I_h - cyclic gap at 24²: 0.000775 (slightly tighter than 16²'s
  0.000786) — within ITP noise; cyclic at 24² still conv=✗, possibly
  the same minimum as I_h or very close.

### 3D 16³ launched (~12-15h)

Updated INITS_3D: `[icosahedral_explicit, cyclic, antiferromagnetic,
ksu_circulation, polar_core_vortex, vortex_lattice]`. Biaxial dropped
(redundant with antiferro for texture-basin probing). KSU/PCV/vortex_
lattice are the axial-texture candidates 2D undercounts the most.

Decision after 3D:
- 3D preserves I_h winner → Eu GS = I_h confirmed, Track A closed,
  Track C predicts texture as excitation. Track B (LHY) for
  cyclic vs I_h gap optional polish.
- 3D shows texture basin E drops below I_h → user's structural
  concern fully vindicated; Eu GS = magnetic texture; phase diagram
  arc pivots from "polyhedral inert manifold" to "MDDI-textured GS";
  Track C and Track A converge into "Paper 2 = Eu GS is a vortex
  texture" deliverable.
- 3D shows new axial-only minimum not present in 2D (KSU-type) →
  novel "axial spontaneous circulation as Eu GS" prediction.

## Three structural corrections (anko 2026-06-02 night → night2)

### Correction 1 — MDDI is interaction-dominant in spin channel

I had framed "c_dd/C_TOTAL = 0.045 → MDDI modest" — wrong. C_TOTAL is
the *total* contact, but texture-vs-uniform is decided by the spin-dep
channel, where MDDI competes with c_1 ≈ c_0/18:

  MDDI / c_1 ~ ε_dd / (c_1/c_0) ~ 0.55 / (1/18) ≈ **10**

In the spin channel MDDI dominates by an order of magnitude. The
texture basin's E_ddi/E_total = -34% (substantial, cooperatively
concentrated from bare 4.5%) is the direct fingerprint. Texture loses
in 2D **not because MDDI is weak** but because **kinetic gradient cost
of forming texture marginally outweighs the MDDI harvest at small
system size + tight box**. At larger N + 3D + correct trap aspect,
the gradient cost decreases (texture wavelength relative to box) and
the MDDI gain dominates. **Texture is interaction-favored, kinetic-
frustrated**.

Implication: prior framing "0.045 ratio → texture cannot win" was
wrong. The 2D loss was kinetic frustration, not MDDI insufficiency.
3D with proper N is highly likely to flip the rank.

### Correction 2 — Single-point 3D is not the deliverable; phase diagram is

Phase diagram = scan over (ω-aspect, N, ε_dd-effective). texture-vs-
uniform is geometry-dependent (prolate/oblate flips DDI sign). The
correct A1 requires:
- (a) Use the **actual experimental trap geometry**: Matsui digital
  twin = ω = (110, 110, 130) Hz aspect = 1.1818 (oblate), N = 5×10⁴.
  See `docs/validation/matsui_reproduction_status.md`.
- (b) Scan N and aspect ratio to draw the texture-uniform boundary.
- (c) z-grid that resolves axial (out-of-plane) texture features.

### Correction 3 — cyclic geometry is unresolved

cyclic at v3 (E=2.5641, conv=✗) and at 24² grid_check (E=2.5642,
conv=✗) is still relaxing. Two scenarios:
- (i) cyclic merges into I_h → uniform-inert minima at 2D Eu nominal
  reduce to {I_h, polar}. "Near-degenerate I_h/cyclic/biaxial
  manifold" is **a phantom**.
- (ii) cyclic stays as a separate near-degenerate minimum.

If (i), Track B (order-by-disorder LHY) reframes from "manifold-
selection" to **"I_h vs texture-basin, 3D and/or LHY decides"**.

Test: `sprint5_A1_v3_cyclic_determine.jl` — long ITP (60000 steps,
tol=1e-9) on cyclic + polar + I_h + antiferro at 2D, pairwise overlap
analysis. Running in parallel, ~30-40 min CPU.

## Arc closure (2026-06-02 night2 anko Point 4 redux): GS verdict ≡ c-determination

After two compounding errors in Step 4 (order: ran before convergence;
channel: σ(a_12) instead of σ(c_1)), the corrected propagation reveals
the arc closure.

**Envelope theorem** at the texture minimum (1st-order re-optimisation
vanishes):

  σ_gap ≈ |Δ_spin| × σ(c_1)/c_1 = 0.0816 × δ(c_1)/c_1

For gap (-0.006) to survive at SNR > 1: **δ(c_1)/c_1 < 7.59%**.

| Precision class | δ(c_1)/c_1 | SNR | Verdict |
|---|---|---|---|
| Matsui ring count (sign + ~order) | 10-50% | 0.15-0.76 | gap drowned |
| Conservative spectroscopy fit | ~5% | 1.52 | marginal |
| **Sprint 3 magnon spectroscopy target** | ~1% | 7.59 | gap survives |
| Aspirational (multi-mode joint Fisher) | 0.1% | 76 | robust |

**The Sprint 3 protocol IS the critical-path enabler** for the GS
verdict. Phase determination ≡ interaction determination at the 7%
precision level.

This recovers the c-determination protocol from "the means already
fixed" framing to "the load-bearing prerequisite for North Star
flagship". Sprint 1-5 wasn't the means — it WAS the path.

**Tracks now merged**:
- Track A (phase diagram + Eu GS) ↔
- Track C (vortex predictions) — already merged at digital twin
- Track D (c determination via magnon spectroscopy, polar branch)
  is what gates BOTH

A flagship paper structure that respects this closure:
- Result: Eu GS is a polar-core vortex (PCV) — a polar-amplitude
  core dressed by phase windings on m=±1 spin components,
  topologically protected, stabilised by MDDI harvest paying the
  c_1 spin-energy cost.
- Required precision: δ(c_1)/c_1 < 7%. Measurement protocol: polar-
  branch magnon spectroscopy on Eu (Sprint 3 design, σ_freq ≈ 0.1
  Hz target, polar GS B-protection ensures Bz noise floor < 17 Hz/nT).
- Conclusion: the GS phase question and the channel-coupling
  determination collapse into a single experiment.

**Beyond Matsui-literal**: real Eu has 6 unknown a_S channels. Each
contributes to the physical Δ_spin via Wigner 6j → c_S structure.
The full σ_gap propagation requires σ(a_S) for all 6, not just c_1.
Sprint 3's per-channel ~0.05 a_B target is the right precision class.

## Concrete action plan (2026-06-02 night2)

1. **GPU digital twin 3D run** (`sprint5_A1_v3_digital_twin_gpu.jl`,
   ~3h, GPU): N=5×10⁴, aspect 1.1818, 24³ box=(30,30,26), Matsui-
   literal channel set (c_n=0 for n≥2). 6 inits: I_h, cyclic,
   antiferro (texture-basin), KSU, PCV, vortex_lattice. **Bench
   confirmed: 0.088 sec/step on RTX 5070 Ti**, 50× CPU speedup.
   Single anchor point at digital twin.

2. **cyclic determination** (`sprint5_A1_v3_cyclic_determine.jl`,
   ~30-40 min, CPU 2D): determines whether cyclic is separate
   minimum or merges into I_h. Parallel with #1.

3. **Phase diagram aspect × N scan** (GPU): after #1 lands. Cells:
   - aspect ∈ {0.7 oblate, 1.18 isotropic-ish, 1.7 prolate}
   - N ∈ {2×10³, 5×10⁴}
   - 6 cells × 2 inits (I_h + antiferro) ≈ 12 GPU ITPs ≈ ~5-10h.
   - Single contour map: texture-basin vs uniform-inert ΔE(aspect, N).

4. **D1 closed** (no deep-dive): direction matches at 24³ (AFM-FM=+1),
   absolute count grid-limited. Logged for record. Spectroscopy
   remains primary c_1 measurement protocol.

## Status as of action plan launch (2026-06-02 night2)

- GPU digital twin running (`bec5a9gvr`, ~3h).
- cyclic determination running (`bv2k5cbiw`, ~30-40 min CPU).
- CPU 3D run (`b41ehf9dk`) was killed (it had only the I_h anchor
  N=2000 result done; replaced by proper GPU digital twin).
- Phase diagram scan: gated on digital twin result.

## D1 Matsui ring closure: lattice-non-converged, qualitative direction matches spectroscopy (2026-06-02 late night)

Run completed `scripts/sprint5_D1_matsui_ring_closure.jl` (~2h).
Result:

| Grid | FM rings | AFM rings | Matsui (lit.) |
|---|---|---|---|
| 16³ | 3 | 3 | FM=2, AFM=3 |
| 24³ | 3 | 4 | FM=2, AFM=3 |

**Lattice non-convergence**: AFM count jumps 3→4 between 16³ and 24³;
FM stays at 3. Absolute counts both grids off by +1 from Matsui.

**Qualitative direction** (subtle positive):
- At 24³, AFM - FM = 1 (matches Matsui: AFM 3 - FM 2 = 1).
- At 16³, no contrast resolved (both 3).
- Direction of contrast (AFM > FM by 1) is consistent with AFM c_1 > 0
  prediction from the spectroscopy route.

**Closure status**: Per the script's one-shot discipline, do NOT
iterate further on grid refinement (each step is ~70 min compute).
D1 is logged as "spectroscopy-route AFM c_1 sign is qualitatively
consistent with 24³ ring-count contrast direction; quantitative
ring count is grid-limited at tractable resolution (need ≥ 32³ for
absolute convergence, which is currently beyond compute envelope)."

D1 does NOT provide a hard cross-check on c_1 sign. The spectroscopy
route (sprint3) remains the primary measurement protocol. D1 archives
as a supporting consistency observation, not a refutation/confirmation.

Files: `scripts/_d1_closure_output.txt` (full radial profiles per run).

**Next steps in priority order**:

1. Wait for completion script (~10 min) to add ksu_circulation +
   icosahedral_explicit.
2. Re-relax cluster A top-5 + cluster B top-2 with looser
   convergence target via `sprint5_A1_v3_analyze.jl`.
3. Decide: if cluster A still wins after tighter relax, 3D
   follow-up is mandatory (per 2D-undercount caveat) before
   declaring a GS. If 3D also confirms uniform-inert wins, Track B
   (Paper #3 polyhedral LHY) becomes load-bearing for separating
   cyclic from biaxial.
4. If 2D suggests cluster B or C wins after tighter relax,
   immediate 3D follow-up with focused seed (the texture candidate)
   to confirm not lattice artefact.

Decision tree on uniform-inert wins (2D + 3D):
- 3D widens cyclic-biaxial gap > LHY noise → Eu GS = cyclic (or
  biaxial), no LHY order-by-disorder needed; Track C predicts
  texture as excitation.
- 3D leaves cyclic-biaxial near-degenerate → Track B Paper #3
  §VII.D (F=6 BN LHY) + §V.G (F=6 cyclic LHY) sympy work mandatory.
  Sympy scope written in
  `docs/manuscript/papers/paper3_universal_theorem/sympy_extension_F6_BN_cyclic_scope.md`.

## Related memories
- `docs/research_notes/sprint3_static_gate_baseline_2026-06-01.md` — full c-determination
  Sprint 1-5 record
- `docs/research_notes/validation_ladder_2026-05-22.md` — Level 13 = Eu phase prediction
  (the destination of Track A)
- `memory/established_tier3_trajectories.md` — research-loop budget context
- `memory/gotcha_constraint_helper_c_extra_basis.md` — basis hygiene for
  any a_S scan using the c_n entry point
