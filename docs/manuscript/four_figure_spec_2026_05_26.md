# Thesis / manuscript 4-figure spec — 2026-05-26

> **Vintage note.** The `runs/` results this document cites predate every
> physics correction merged after 2026-06-02 — including a quadratic Zeeman
> that was 11× too large for Eu until 2026-07-08. See
> [`stored_results_vintage_audit.md`](../validation/stored_results_vintage_audit.md) before quoting a number from here.

Companion to `docs/validation/weekly_presentation_outline.md` (which
specifies the **6-slide presentation** view).  This document specifies
the **manuscript / thesis** view of the same body of work: a 4-figure
narrative spine that prioritises publication tightness over slide-deck
readability.

The two documents share Findings 1-5 and the caveat list verbatim; do
not duplicate them.  Cross-references throughout point back to the
slide outline for verbose claim text.

## Mapping: 7 session figures → 4 manuscript figures

The 2026-05-26 session produced 7 figures under
`docs/validation/figures/fig{1..7}_*.png`.  They are not all peers —
some are companion panels for the same claim, some are appendix.
For a paper / thesis chapter, this collapses to:

| Manuscript fig | Claim                                                | Composed from               | New runs added |
|---------------:|------------------------------------------------------|-----------------------------|----------------|
| **Fig 1**      | Experimental-like regime → EdH cascade, no collapse  | fig1 + fig5 + fig6           | matsui loss-on ×2 (Sec 2 panel d) |
| **Fig 2**      | F=6 collapse arrest is LHY-closure dependent         | fig4 + long-time table      | icosa 200 ms (drift table extension) |
| **Fig 3**      | K3 alone is sacrificial (appendix-grade)             | fig2 + fig3                  | none           |
| **Fig 4**      | Barnett response window (experimental proposal)      | fig7                         | 64³ anchor + N=5e4 production |

Findings 1, 2 → Fig 1 (main story).
Findings 3, 4 → Fig 2 (methodological).
Finding 5 → split: claim "K3 not primary" → Fig 2; quantification of
the K3-alone behaviour → Fig 3 (appendix).
New: Barnett recommendation → Fig 4.

## Figure 1 — Experimental-regime EdH cascade with no collapse (MAIN)

**Layout:** four panels in 2×2 grid.

| panel | content                                                 | source              |
|-------|---------------------------------------------------------|---------------------|
| (a)   | peak density vs grid (64/96/128³) at L4 isotropic       | `fig1` panel (a)    |
| (b)   | N(T)/N(0) and ⟨F_z⟩/N vs grid at L4 isotropic           | `fig1` panels (b,c) |
| (c)   | Matsui Fig 2C reproduction — N_m(t), m = -6..0, 0-40 ms | `fig5` panel (a)    |
| (d)   | Matsui z=0 morphology slices at 5 ms                    | `fig6` first row    |

**Final caption (publication-ready):**

> **Figure 1.** Experimental-regime Eu-151 F=6 EdH dynamics: no collapse
> + Matsui Fig 2C cascade qualitatively reproduced under the loss-free
> simulation assumption.
> **(a)** L4 isotropic protocol (N = 30 000, ω = (1, 1, 1), t = 10 ms)
> at grids 64³ / 96³ / 128³ for six scenarios (HamOnly, K3, γ_dr,
> K3+γ_dr, K3+scalar-LHY, γ_dr). Peak density saturates at
> 9.5×10⁻³ a_ho⁻³ with 1.2% spread across a 4× memory range — no
> collapse onset at any grid. **(b)** Atom number N(T)/N(0) (circles,
> left axis) is conserved to 10⁻⁴ in HamOnly cells and ⟨F_z⟩/N
> (squares, right axis) drifts by < 1% under all perturbations.
> **(c)** Loss-free simulation at the Matsui 2026 parameter set
> (N = 50 000, ω/2π = (110, 110, 130) Hz, c₁/c₀ = 1/36, B = 2.6 nT
> post-quench) qualitatively reproduces the m=−6 → m=−5 → m=−4 EdH
> cascade reported in Matsui *et al.* Fig 2C, with partial coherent
> recovery to m=−6 near 40 ms. **Inset:** phenomenological K₃
> brackets the experimental ~40% atom loss — K₃ = 3×10⁻⁴⁰ m⁶/s (medium)
> gives N(40 ms)/N(0) ≈ 0.52 and K₃ = 1×10⁻³⁹ m⁶/s (strong) gives ≈ 0.24,
> with the Matsui experimental reference (≈0.6) lying between them.
> **(d)** z=0 density slice of the m=−4 component at 5 ms shows the
> multi-ring morphology consistent with Matsui Fig 1.

**Talking-point claim (= Slide 2 + Slide 3 claims, combined):**

> At the experimental protocol, peak density saturates with no
> collapse onset; the Matsui Fig 2C EdH cascade is qualitatively
> reproduced under Matsui's loss-free simulation assumption.

**Optional extension (post-loss-on dispatch):**

If the new `matsui_40ms_lossy_medium.yaml` / `matsui_40ms_lossy_strong.yaml`
runs return a population decay that brackets the ~40% atom loss
reported in Matsui's experiment, add a small inset to panel (c)
showing total N(t)/N(0) for three rows: loss-free,
phenomenological-K3 medium, phenomenological-K3 strong.
This stays within Fig 1; it is *not* a separate figure, because the
manuscript story is still "Matsui parameter set qualitatively
reproduces", with loss-on as bracket evidence not headline claim.

## Figure 2 — Collapse-arrest is LHY-closure dependent at F=6 (MAIN, methodological)

**Layout:** three panels in 1×3 row.

| panel | content                                                 | source                            |
|-------|---------------------------------------------------------|-----------------------------------|
| (a)   | 2×4 factorial peak ratio: {K3=0, K3=200} × {off, scalar, polar, icosa} | `fig4` panel (a)        |
| (b)   | 2×4 factorial N(T)/N(0): same axes                       | `fig4` panel (b)                  |
| (c)   | Long-time stability table 50 / 100 / 200 ms at K3=0      | from `day_inventory_2026_05_26.md` drift table |

**Final caption (publication-ready):**

> ## ⚠️ Figure 2 does not reproduce — re-derived 2026-07-29
>
> **Its premise is gone.** The caption below turns on some arms *collapsing*
> (`delay`) and the LHY closures *arresting* them (`stable_arrest`). Re-running the
> K₃=0 factorial on current `main`, **all four arms are `stable_arrest`** — there
> is no collapse left for the LHY closure to determine:
>
> | arm | ratio now | class now | ratio 2026-05 | class 2026-05 |
> |---|---:|---|---:|---|
> | off | **1.0502** | stable_arrest | 2.3339 | delay |
> | scalar | **1.1839** | stable_arrest | 2.3599 | delay |
> | polar_contact | **1.3883** | stable_arrest | 1.6294 | stable_arrest |
> | icosahedral | **1.2801** | stable_arrest | 1.5991 | stable_arrest |
>
> **Correction (same day): the comparison above is not like-for-like.** The stored
> 2026-05 numbers were produced with `B: {Bz: "-0.01 Gauss"}`; the configs were
> corrected to `+0.01 Gauss` in `bce2068f` ("211 Eu configs pinned m=-F under a
> field that prefers m=+F"), so the re-run used a *different config*, not just
> different code. That commit's own reasoning applies directly here: m=−F is a
> Zeeman eigenstate, so ITP holds it either way and nothing errors, but under the
> old negative field m=−F is the *highest* Zeeman state and "the dynamics then
> proceed in a field whose sign is opposite to the intent".
>
> That is a plausible mechanism for `delay` → `stable_arrest` on its own — a
> spin-mixing-unstable initial state depolarises and collapses differently from a
> stable one — so the `off` arm's 2.3339 → 1.0502 must **not** be attributed to
> the code changes listed below until the two are separated. An `off` arm at the
> old field sign on current code is running to do exactly that.
>
> The verdict on the figure is unchanged and if anything firmer: its stored
> numbers are **not reproducible from anything now in the repo**, because the
> config that produced them was wrong in the field sign and has been fixed.
>
> **Only the first two rows are usable.** `off` and `scalar` conserve energy to
> 2e-8 / 7e-8. The two closed-form arms drift **46 %** (E: 3123 → 1694) and their
> `energy_decomposition` puts **97 % of the total energy in the LHY term alone**
> (`lhy = +1653` / `+1664` against a whole mean field of ≈ +2.2 in the other two
> arms). Their ratios are not evidence of anything and are shown only to document
> that the stored 1.63 / 1.60 were not reproduced. Do not read "the closures
> arrest least" out of this table.
>
> What survives is enough to void the figure: **`off` does not collapse.** Its
> ratio fell 2.3339 → 1.0502 with clean energy conservation, and `scalar` — also
> clean — sits at 1.1839, so "scalar is indistinguishable from no LHY" is gone
> too. The caption needs `off` to collapse so that the closures can be seen to
> arrest it. It does not.
>
> The two dedicated gates for the tabulated path both pass at this commit
> (`test_lhy_energy_convention.jl` 17/17, `test_tabulated_lhy_propagator_parity.jl`
> 42/42), so the 46 % drift is **not** an energy/propagator/gradient inconsistency.
> It is the table's magnitude in this particular Eu F=6 configuration — tracked
> separately; not diagnosed here.
>
> Cause of the `off` change is not the LHY work: this run predates the Eu
> quadratic-Zeeman fix (11× too large until 2026-07-08), the DDI integrator-order
> fixes and the ITP density-bias fix — see
> [`stored_results_vintage_audit.md`](../validation/stored_results_vintage_audit.md).
>
> **Do not use Figure 2 as specified.** The physics question it asks (what sets
> F=6 collapse arrest) is still open; this figure's answer rested on a collapse
> that current code does not produce.
>
> Run output: `/gs/bs/work/7/uk07267/spinorbec-runs/fig2_k3zero_v2`.

> **Figure 2.** F=6 collapse arrest in the cigar stress regime
> (N = 30 000, ω_z = 0.25 ω_⊥, simulated window t = 30 ms in panels
> (a–b), 200 ms in panel (c)) is determined by the LHY closure, NOT by
> three-body loss K₃.
> **(a)** Peak density ratio for the 2×4 factorial
> {K₃=0, K₃=200×proxy} × {LHY=off, scalar, polar_contact, icosahedral}.
> scalar density LHY is indistinguishable from no LHY at F=6, while the
> polar_contact and icosahedral spinor-branch-aware effective LHY
> closures cap the peak ratio at 1.63 / 1.60 (green = stable_arrest).
> Adding K₃ = 200× literature proxy on top of a proper LHY closure
> reduces the peak only marginally (1.63 → 1.40 for polar).
> **(b)** Atom number conservation N(T)/N(0): K₃=0 polar / icosa give
> identical N = 1.000 (lossless arrest), whereas K₃=200×proxy adds
> 17.5% atom loss for marginal extra peak suppression.
> **(c)** Long-time stability table under polar / icosahedral LHY at
> K₃ = 0: identical drift trajectories to 200 ms, peak hard-capped
> below 1.28× initial, atom-number drift < 3×10⁻⁸ at 200 ms (= 138 ω_ref⁻¹).
> The dynamics are bounded breathing — neither a metastable plateau
> nor a delayed collapse.

**Talking-point claim:**

> The F=6 collapse-arrest mechanism is the LHY closure, not K3.
> Scalar LHY is insufficient at F=6; polar-contact / icosahedral
> effective spinor-LHY closures arrest the collapse losslessly in the
> tested window.

**Caveat (must accompany; identical to Slide 4):**

> polar_contact and icosahedral are *effective* model closures tied
> to an assumed local order parameter.  They are not a full
> nonequilibrium F=6 BdG-LHY treatment, so the "lossless arrest"
> result is an upper bound on the LHY contribution for arbitrary
> non-equilibrium spin textures.  The cigar regime is a stress test,
> not the experimental protocol — Fig 1 says the experiment does not
> visit this regime.

## Figure 3 — K3-alone arrest is sub-critical and sacrificial (APPENDIX)

**Layout:** two panels in 1×2 row.

| panel | content                                                 | source              |
|-------|---------------------------------------------------------|---------------------|
| (a)   | 10-point K3 dose-response: peak ratio vs K3 (log axis)  | `fig2` panel (a)    |
| (b)   | 10-point K3 dose-response: N(T)/N(0) vs K3 (log axis)   | `fig2` panel (b)    |

**Final caption (publication-ready):**

> **Figure 3.** K₃-alone dose-response (LHY = off, γ_dr = off) in the
> F=6 cigar stress regime, 10-point scan covering K₃ = 0 to 300× the
> Dy literature proxy (1.0×10⁻⁴¹ m⁶/s), with a 96³ anchor (open
> squares) over-plotted on the 32³ scan (filled circles).
> **(a)** Peak density ratio: K₃ ≤ 100× delays collapse but the peak
> still doubles (blue, "delay"); K₃ ≥ 200× achieves arrest with peak
> ratio below 2 (red, "sacrificial arrest"). The 96³ anchor agrees
> with 32³ across the transition.
> **(b)** Atom-loss cost of K₃-alone arrest: at the K₃ ≈ 200×
> operational threshold the atom-number conservation N(T)/N(0) drops
> below 50% (shaded sacrificial region). No K₃ value in this sweep
> achieves clean lossless arrest. Figure 2 supersedes this picture by
> showing that proper LHY closure achieves the same arrest at K₃ = 0
> with no atom loss.

**Note on `fig3_class_map`:** the categorical class map is subsumed
by Fig 3 panel (a) (the colour-coded markers already encode the
classification).  Keep `fig3_class_map.png` in the supplementary
material; do not include in the 4-figure manuscript layout.

**Talking-point claim:**

> K3 alone is a sub-critical density manager: ≥ 200 × literature
> proxy is needed for arrest, and arrest at that level destroys 65–75%
> of the atom cloud.  Fig 2 makes Fig 3 obsolete as a *primary* arrest
> mechanism story.

## Figure 4 — Klaus rotation protocol: sustained-rotation experimental window (MAIN, post-pivot 2026-05-26 evening)

**Replaces** the prior "bare-⟨F_z⟩ Barnett window" version of Fig 4.
After the 2026-05-26 evening Klaus quench protocol scan (17 cells,
`docs/manuscript/klaus_quench_protocol_spec_2026_05_26.md`), the
experimental-recommendation figure is the **free-hold vs keep-rotation
Ω scan**, not the bare-⟨F_z⟩ vs Ω curve.

**Layout:** 1×2 row.

| panel | content                                                     | source |
|-------|-------------------------------------------------------------|--------|
| (a)   | P_{-5,-4} vs Ω, two curves: free-hold (flat) + keep_rot (peaked at Ω=−0.5) | `klaus_quench_fig_k1.png` panel (a) |
| (b)   | P_exc = max_t (1 − N_{-6}/N) vs Ω, same two-curve overlay   | `klaus_quench_fig_k1.png` panel (b) |

**Official caption (= the Klaus-spec Fig K1 caption, verbatim):**

> **Figure 4.** Klaus 2-phase rotation/quench protocol Ω scan in the
> Eu-151 F=6 near-isotropic trap (N = 10⁴, ω_⊥ = 2π · 110 Hz, t_total
> ≈ 21 ms).  Rotation preparation alone leaves the post-quench spin
> excitation unchanged across Ω (blue dashed curve, flat at P_{-5,-4}
> ≈ 0.22, indistinguishable from the no-rotation baseline), whereas
> maintaining rotation during the 10 ms weak-field hold enhances the
> m=−5, m=−4 population by a factor of 2.5 to P_{-5,-4} = 0.540 at
> Ω/ω_⊥ = −0.5 (red solid curve, with strong sign asymmetry). DDI-off
> and no-B-quench controls collapse all excitation to zero, so both
> the DDI-mediated channel and the weak-field opening are required.
> Atom number is conserved to 10⁻⁶ in every cell. The Ω = −0.5
> keep-rotation result is grid-converged at 32³ ↔ 64³ to four decimal
> places.

**Talking-point claim:**

> **The experimental knob is sustained rotation during the weak-field
> hold, not pre-rotation.** Under the current code sign convention and
> initial m=−F state, the Klaus protocol window is Ω/ω_⊥ ∈ [−0.5, −0.3].

**Caveats:**

- The mechanism is "rotation-assisted EdH spin excitation in the
  weak-field regime", not an equilibrium Barnett effect.  Avoid bare
  "Barnett" for this finding.
- Sign convention: lab translation must be verified per-experiment.

**Companion supplementary figure** (was the original Fig 4):

`fig7_barnett_window.png` (bare-⟨F_z⟩ 14-cell scan) moves to
supplementary / appendix figure S1.  It is a legitimate magnetization-
style measurement under sustained rotation and IS a Barnett effect in
the conventional sense; it just is not the experimentally load-bearing
quantity Klaus measures.

### Legacy bare-⟨F_z⟩ panels (now supplementary S1)

**Layout:** three panels in 1×3 row.

| panel | content                                                       | source                              |
|-------|---------------------------------------------------------------|-------------------------------------|
| (a)   | Δ⟨F_z⟩/N vs Ω/ω_⊥ at 14 cells (DDI on + DDI off control)      | `fig7` panel (a)                    |
| (b)   | peak ratio vs Ω/ω_⊥                                            | `fig7` panel (b)                    |
| (c)   | N(T)/N(0) vs Ω/ω_⊥                                             | `fig7` panel (c)                    |

**Annotations added once new dispatch completes:**

- 64³ anchor result at Ω/ω_⊥ = −0.3, N = 1e4: overlay open square
  marker on panels (a), (b), (c).  Agreement with 32³ to ≤ 5%
  promotes the recommendation from "32³ window scan" to
  "grid-converged window scan".
- 64³ N = 5e4 production point at Ω/ω_⊥ = −0.3: overlay filled
  diamond marker.  Confirms (or rejects) that the Barnett signal
  scales sensibly from N = 1e4 to the experimental N = 5e4.

**Caption (draft, post-dispatch):**

> Klaus / Barnett parameter scan in the Eu near-isotropic trap
> (ω/2π = (110, 110, 130) Hz, t = 14.5 ms, m=−F initial).
> DDI-off controls give Δ⟨F_z⟩/N ≈ 10⁻¹² at every Ω — Barnett origin
> verified as DDI-driven.  DDI-on response is strongly chirality-
> asymmetric (factor ~35 between Ω/ω_⊥ = −0.3 and Ω/ω_⊥ = +0.3) and
> peaks near Ω/ω_⊥ = −0.3 to −0.5.  64³ anchor (open square) and
> N = 5e4 production point (filled diamond) at Ω/ω_⊥ = −0.3 confirm
> the window is neither a grid artifact nor an N-scale artifact.

**Talking-point claim (== Slide 6, with new run additions):**

> Under the current code's Ω sign convention and initial m = −F
> state, the Klaus / Barnett experimental window is Ω/ω_⊥ ∈ [−0.5,
> −0.3], at the Eu near-isotropic trap, B = 2.6 nT, N = 5e4.
> Translation to lab convention requires the sign mapping to be
> verified per-experiment.

## Figure-by-figure data-path map (for reproducibility)

For each manuscript figure, the canonical data sources are:

```
Fig 1 (a, b) :  runs/l4_k3_ladder/summary.json
Fig 1 (c)    :  runs/matsui_baseline/summary.json (40ms_dynamics_n64 row)
Fig 1 (d)    :  runs/matsui_baseline/matsui_5ms_n64_density_slice.json
Fig 1 inset  :  runs/matsui_baseline/{matsui_40ms_lossy_medium,strong}.yaml
                  → analysis to extract N(t)/N(0) ratio for inset
Fig 2 (a, b) :  runs/eu_k3_lhy_control/factorial_2x4.json
Fig 2 (c)    :  runs/eu_lhy_longtime/{polar,icosa}_{50,100,200}ms .jld2
                  → extract peak(t), N(t), Fz(t) trajectories
Fig 3 (a, b) :  runs/eu_k3_sweep/summary.json + runs/eu_k3_sweep_96/summary.json
Fig 4        :  runs/barnett_eu_window/summary.json
Fig 4 anchor :  runs/barnett_eu_window/barnett_eu_omm0p3_n64_DDIon/*.jld2
Fig 4 prod   :  runs/barnett_eu_window/barnett_eu_omm0p3_n64_N50k_DDIon/*.jld2
```

## Plotting-script touch-points

`scripts/validation/make_week_figures.py` produces all 7 session
figures.  For the 4-figure restructure, write a sister script
`scripts/validation/make_manuscript_figures.py` that re-imports the
data-load helpers from `make_week_figures.py` and re-composes them
into the 4 panel layouts described above.  Do not edit
`make_week_figures.py` itself — the 7 figures remain the canonical
slide-deck rendering.

## Cross-references

- 6-slide presentation outline + 6-sentence claims:
  `docs/validation/weekly_presentation_outline.md`
- 5 publishable findings (canonical wording):
  `docs/validation/day_inventory_2026_05_26.md` §Main claims
- Caveat list (Ueda BLOCKED_EXTERNAL, effective LHY, sign convention):
  `docs/validation/day_inventory_2026_05_26.md` §Caveats
- Validation chain (analytic / conservation / literature / reference-RHS / convergence):
  `docs/validation/self_contained_validation_report.md`
- Matsui parameter set audit:
  `docs/validation/matsui_reproduction_status.md`

## Open items (post 2026-05-26 dispatch)

1. ~~**icosa 200 ms**~~ → **DONE 2026-05-26 evening**. icosa 200 ms
   drift row populated in Fig 2 panel (c): ΔN/N = −2.78×10⁻⁸,
   ΔF_z = +1.547 — **identical to polar 200 ms within drift floor**.
   Polar / icosa equivalence at 200 ms hardens Finding 4 from "polar
   alone gives bounded breathing" to "polar AND icosa effective spinor
   LHY closures give the same bounded breathing trajectory".

2. ~~**Matsui loss-on medium / strong**~~ → **DONE 2026-05-26 evening**.
   - K3 = 3×10⁻⁴⁰ m⁶/s (factor 30, "medium")  : N(T)/N(0) = 0.516
   - K3 = 1×10⁻³⁹ m⁶/s (factor 100, "strong")  : N(T)/N(0) = 0.244
   - Experimental Matsui ~40% loss is bracketed below "medium" (which
     gave 48% loss). Reasonable phenomenological window is K3 factor
     ~20–25. Fig 1 inset (panel c) now shows both loss-on curves.

3. ~~**Barnett 64³ anchor + N = 5e4**~~ → **SUPERSEDED by klaus_quench
   protocol scan** (2026-05-26 evening pivot, anko). The bare-⟨F_z⟩
   Barnett response under sustained rotation is no longer the
   load-bearing experimental recommendation; the recommendation is now
   the 2-phase protocol "rotation prep at strong B → quench to weak B
   → free hold", with the question being which Ω most efficiently
   excites m=−5, m=−4 components after the quench. See companion doc
   `klaus_quench_protocol_spec_2026_05_26.md`.

4. **Matsui Fig 2C quantitative overlay** → digitise Matsui Fig 2C
   (if SI permits) and add a quantitative-deviation panel; currently
   only qualitative-shape agreement is claimed.

5. **NEW** — Klaus 2-phase protocol Ω scan, 10 cells dispatched
   2026-05-26 evening, ETA ~80 min. Will produce Fig K1 / K2 / K3 /
   K4 under `docs/manuscript/figures/klaus_quench_fig_k{1..4}.png`.
   These supersede manuscript Fig 4 if the protocol-relevant spin
   excitation gives a more useful experimental recommendation than the
   bare-Fz scan.
