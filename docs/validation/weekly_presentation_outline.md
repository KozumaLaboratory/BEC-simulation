# Weekly presentation outline — 2026-05-26 (final)

> **FROZEN 2026-05-26.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

6-slide structure per anko's 2026-05-26 framing.

**Main story:** Eu experimental protocol (L4 isotropic) is robustly
no-collapse; Matsui-style loss-free simulation qualitatively reproduces
the EdH cascade.

**Appendix (methodological):** In the artificial F=6 cigar collapse
stress regime, the arrest mechanism is the LHY closure, NOT K3.

**Next:** Barnett parameter-window identification + long-time LHY
stability.

Figures live in `docs/validation/figures/`.

---

## Slide 1 — Summary / claims

**Title:** Eu EdH simulation: validation status (2026-05-26)

**Main findings (experimental regime):**

1. **L4 isotropic Eu EdH is robustly no-collapse** across
   N = 64/96/128 (12 cells; ΔF_z = 0.00886 cross-grid converged).
2. **Matsui-style loss-free simulation qualitatively reproduces**
   the m=−6 → m=−5 → m=−4 EdH cascade with N conserved (Fig 2C target).

**Methodological appendix (artificial F=6 collapse stress regime):**

3. scalar LHY is insufficient at F=6 — indistinguishable from no LHY
   in the tested stress regime (4 cells confirm).
4. *proper spinor LHY closure* — meaning a spinor-branch-aware
   effective LHY EoS (polar_contact / icosahedral here), NOT scalar
   density LHY — produces stable_arrest at K3=0 with N(T)/N(0)=1.000.
   This is still an effective closure, not a full nonequilibrium
   F=6 BdG-LHY calculation.
5. K3 is **not required for arrest** once proper spinor LHY is
   included, and **mainly adds atom loss in this benchmark**.

**Why this matters:**

> External Ueda code comparison is BLOCKED_EXTERNAL. The 2026-05-26
> pivot is to build a self-contained validation chain (analytic /
> conservation / literature / reference-RHS / convergence) + start
> producing publishable claims for the experimental protocol.

---

## Slide 2 — L4 isotropic robust no-collapse (MAIN)

**Title:** L4 isotropic Eu EdH: cross-grid no-collapse at 64/96/128

**Figure:** `figures/fig1_l4_isotropic_grid_convergence.png`

**Talking points:**

- 12 cells: 3 grids × {HamOnly, K3, γ_dr, K3+γ_dr, K3+LHY (scalar), γ_dr}
- Peak density: 9.51 / 9.59 / 9.62 ×10⁻³ at N = 64/96/128 — cross-grid
  spread < 1.2% over 4× memory range
- No `collapse_onset` event in any of 12 cells
- N(T)/N(0): HamOnly = 1.0000 across grids; K3 = 0.9914 across grids
  (grid-independent K3 effect, < 1%)
- ⟨F_z⟩/N: −1.70 across all HamOnly cells; K3 perturbs by < 0.7%
- Prior "64³ → collapse" intuition was the pre-dealias-fix L4 anomaly
  (ΔF_z = 0.0147 vs converged 0.00886)

**Claim:**

> **At the L4 isotropic protocol (N = 30k, ω = (1,1,1), t = 10 ms),
> peak density saturates near 9.5×10⁻³ a_ho⁻³ across 64/96/128 — no
> collapse onset. K3, γ_dr, scalar LHY all contribute < 1% perturbations.
> The experiment does not need K3 to be stable.**

---

## Slide 3 — Matsui reproduction (MAIN)

**Title:** Matsui 2026 Eu EdH: loss-free simulation qualitatively
reproduces Fig 2C cascade

**Figures:**
- `figures/fig5_matsui_reproduction.png` (Fig 2C-like population
  trajectories at 5/40 ms)
- `figures/fig6_matsui_morphology_slices.png` (z=0 density slices,
  Fig 1-like morphology check)

**Parameter set (matches Matsui paper):**

| | Matsui paper | Our YAML |
|---|---|---|
| N | 5 × 10⁴ | 50000 |
| Initial m_F | −6 | `m_minus_F` |
| Trap (ω_x,ω_y,ω_z)/2π | (110, 110, 130) Hz | `[1, 1, 1.18]` |
| Constraint | c0 + 36·c1 = 4πℏ²a_s/M | enforced |
| Best-fit | c1/c0 = 1/36 | `c1_ratio: 0.0278` |
| B weak | 2.6 nT | `Bz: -2.6e-5 Gauss` |
| DDI | full for dynamics | `secular: false` |
| Loss / LHY | not in Matsui simulation | both off |

**Findings:**

- 5 ms morphology: peak density essentially static, EdH cascade
  m=−6 → m=−5 (24%) → m=−4 (15%) by t=4ms. 32³/64³ agree to < 1%.
- 40 ms dynamics: m=−6 (79% → 44%) → m=−5 (16% → 27%) → m=−4 (4% → 22%)
  → m=0 (~7% at 20 ms) cascade visible. Total N = 0.99992 (loss-free
  conservation OK). Partial coherent recovery (m=−6 → 63% at 40 ms).
- All consistent with Matsui Fig 2C qualitative shape.

**Claim:**

> **At Matsui's experimental parameter set, our simulation
> qualitatively reproduces the Fig 2C EdH cascade (m=−6 → m=−5 →
> m=−4 → ... with partial coherent recovery) under Matsui's loss-free
> assumption. 32³ and 64³ grid converged for the spin-sector dynamics.**

**Caveats:** No quantitative digitised Fig 2C comparison yet.
Experiment-side reproduction (~40% atom loss at 40 ms) requires a
separate loss-on variant — next week's loss-phenomenology step.

---

## Slide 4 — F=6 stress-test: arrest is LHY-closure driven, not K3-driven (APPENDIX)

**Title:** F=6 collapse-arrest prediction is strongly model-dependent
at the LHY level

**Figure:** `figures/fig4_lhy_model_interference.png` (2×4 K3 × LHY
factorial)

**Talking points (2×4 K3 × LHY at cigar stress regime, t ≤ 30 ms):**

```
                        K3 = 0                 K3 = 200×proxy
LHY = off       :  ratio 2.33,  N=1.000    ratio 1.98,  N=0.347
LHY = scalar    :  ratio 2.36,  N=1.000    ratio 2.00,  N=0.347
LHY = polar     :  ratio 1.63,  N=1.000 ★  ratio 1.40,  N=0.825
LHY = icosa     :  ratio 1.60,  N=1.000 ★  ratio 1.33,  N=0.826
```

- scalar LHY ≡ no LHY at F=6 (confirmed in 4 cells)
- ★ **polar and icosahedral LHY alone, at K3=0**, produce
  `stable_arrest` with **N(T)/N(0) = 1.000** (lossless)
- Adding K3=200× to proper LHY: peak ratio drops marginally
  (1.63 → 1.40, 1.60 → 1.33) at the cost of 17.5% atom loss
- **K3 is not required for arrest** once proper LHY is present, and
  **mainly adds atom loss in this benchmark**

**Claim:**

> **In the F=6 cigar collapse stress regime, the arrest mechanism is
> the LHY closure, NOT K3. The question "does K3 arrest collapse?"
> is ill-posed at F=6 without first specifying which LHY closure is
> used. scalar density LHY is insufficient; spinor-branch-aware
> effective LHY closures (polar_contact / icosahedral) alone arrest
> the collapse losslessly.**

**Caveats:**

- polar_contact / icosahedral LHY are **effective model closures**
  tied to assumed local order parameters (polar phase / I_h F=6
  symmetric). They are NOT a full nonequilibrium F=6 BdG-LHY treatment.
- "Stable" means stable in the simulated 30 ms window. Long-time
  metastability beyond this window is being tested via the 50/100/
  200 ms LHY stability ladder (Task #26, running).
- This is a stress-test regime (cigar, not the experimental geometry).
  Whether the experiment ever enters such a regime is a separate
  question — the L4 isotropic Slide 2 result says no.

---

## Slide 5 — K3-alone behaviour (APPENDIX context for Slide 4)

**Title:** K3-alone dose-response: needs ~200× literature proxy to
arrest, at severe atom-loss cost

**Figures (small, supplementary):**
- `figures/fig2_k3_sweep_cigar.png` (10-point K3 dose-response, K3 only)
- `figures/fig3_class_map.png` (categorical K3-alone class map)

**Talking points:**

- With LHY off (so K3 is the only candidate stabilizer), 10-point
  K3 sweep at cigar regime: K3 = 0, 1, 3, 10, 30, 100, 150, 200, 250, 300
- K3 ≤ 100×: "delay" only (peak still doubles)
- K3 ≥ 200×: "sacrificial_arrest" (peak < doubles, but ≥ 65% atoms gone)
- K3-alone operational transition ≈ 150–200× (confirmed at 96³ anchor)
- No clean `stable_arrest` cell exists in the K3-alone sweep
- This is why Slide 4 matters: K3 alone can only sacrificially arrest;
  proper LHY achieves lossless arrest without K3

**Claim:**

> **K3 alone is a sub-critical density manager: it requires ~200×
> literature-proxy value to arrest, and arrest at that level is
> "sacrificial" (~65–75% atom loss). The Slide 4 finding subsumes
> this: clean arrest comes from LHY closure, not from K3.**

---

## Slide 6 — Next

**Title:** Klaus/Barnett parameter window + long-time LHY stability

**Two parallel investigations launched this session:**

### Klaus rotation protocol — experimental recommendation (post 2026-05-26 evening pivot)

**Headline (slide-ready):**

> **The experimental knob is sustained rotation during the weak-field
> hold, not pre-rotation.**  Window: Ω/ω_⊥ ∈ [−0.5, −0.3], grid-converged
> 32³ ↔ 64³, requires DDI, requires B quench.  Mechanism is
> rotation-assisted EdH spin excitation in the weak-field regime —
> NOT an equilibrium Barnett effect.

**Klaus 2-phase quench scan, 17 cells (`runs/klaus_quench/`):**

| protocol                           | P_{-5,-4} | P_exc  |
|------------------------------------|-----------|--------|
| Ω = 0 (no rotation, free hold)     | 0.219     | 0.227  |
| Ω = -0.5 free hold (prep only)     | 0.225     | 0.233  |
| **Ω = -0.5 keep rotation 32³**     | **0.540** | **0.817**  |
| **Ω = -0.5 keep rotation 64³**     | **0.540** | **0.817**  |
| Ω = -0.5 DDI off                   | 0.000     | 0.000  |
| Ω = -0.5 no B quench               | 0.000     | 0.000  |
| Ω = -0.5 keep rot + DDI off        | 0.000     | 0.000  |
| Ω = -0.3 keep rot                  | 0.517     | 0.643  |
| Ω = -0.7 keep rot                  | 0.344     | 0.445  |
| Ω = +0.3 keep rot                  | 0.100     | 0.101  |
| Ω = +0.5 keep rot                  | 0.066     | 0.066  |

**Three take-home points:**

1. Rotation preparation alone leaves the post-quench excitation flat
   in Ω at P_{-5,-4} ≈ 0.22 — rotation prep imprints no phase
   structure that survives the quench.
2. Sustained rotation through the weak-field hold gives a 2.5× spin
   excitation enhancement, with strong sign asymmetry (8.2× ratio at
   |Ω| = 0.5).
3. Both DDI and the B quench are required: removing either collapses
   the response to zero.  The mechanism is "Ω reshapes DDI-mediated
   EdH selection rules in the weak-field regime".

**Headline figure:** `docs/manuscript/figures/klaus_quench_fig_k1.png`
(free-hold flat curve overlaid with keep-rotation peaked curve).
Captioned in `docs/manuscript/klaus_quench_protocol_spec_2026_05_26.md`.

### Supplementary: bare-⟨F_z⟩ Barnett window (14-cell scan, prior framing)

9 Ω points (DDI on) + 5 Ω points (DDI off control) at Eu near-isotropic
geometry, N = 1e4, t = 14.5 ms.

**DDI off (5 controls):** ΔF_z/N ≈ 1e-12 (machine ε) at all 5 Ω
values — Barnett origin verified as DDI-driven.

**DDI on (9 cells), sign-asymmetric response curve:**

```
Ω/ω_⊥    ΔFz/N       peak ratio
-0.9     +0.245      1.000
-0.7     +1.284      1.000
-0.5     +1.771      1.293
-0.3     +2.115 ★    1.318   (peak Barnett response)
 0.0     +0.059      1.568
+0.3     +0.025      1.388
+0.5     +0.054      1.186
+0.7     +0.017      1.114
+0.9     +0.032      1.136
```

**Updated recommendation (from preliminary "Ω ≈ 0.5"):**

- **Peak Barnett response at Ω/ω_⊥ ≈ -0.3 to -0.5** (anti-parallel
  rotation w.r.t. initial m=-F spin)
- Positive Ω regime gives only marginal response (< 0.06 vs +2.12 at
  Ω=-0.3 — factor of ~35 asymmetry)
- All 14 cells stable: N(T)/N(0) = 1.000, peak ratio ≤ 1.57
- Recommended experimental window (**under the current code's Ω sign
  convention and initial m=−F state**): **Ω/ω_⊥ ∈ [-0.5, -0.3]**,
  near-isotropic trap, B = 2.6 nT, N = 1e4 scan → N = 5e4 target.
  Translation to lab convention requires the sign mapping to be
  verified per-experiment.

### Long-time LHY stability (Task #26)

3-stage ladder testing whether the Slide 4 "stable_arrest" survives
beyond the 30 ms simulated window:

```
Stage 1: polar + icosa LHY, 50 ms,  K3=0   (running, GPU 64³)
Stage 2: same, 100 ms   ← gate on Stage 1 plateau
Stage 3: same, 200 ms   ← gate on Stage 2 plateau
Branch:  if drift, 96³ + dt/2 + seed × 3 controls
```

If 200 ms still clean: the Slide 4 claim hardens. If drift appears:
the "lossless stable arrest" wording is downgraded to "metastable in
30 ms window" honestly.

### Subsequent ladder (next week)

- Loss-on Matsui variant (~40% atom loss at 40 ms experiment match)
- Spinor contact rotation (Ω vs F_z, L_z, J_z under DDI off/on)
- Klaus protocol with full parameter sweep

**Stop chasing:**

- ~~"K3 explains Eu collapse"~~ — replaced by LHY closure story
- ~~Cigar geometry as Eu experiment proxy~~ — stress-test only
- ~~pre-dealias 64³ anomaly~~ — already fixed

**Cross-code validation candidates (effort-budgeted):**

- FORTRESS spin-1 contact cross-check (multi-day install effort;
  see `docs/validation/fortress_cross_check_scope.md`)
- Matsui supplementary parameters (Kozuma / Miyazawa Science Tokyo
  contact via paper)
- Bao+Cai scalar dipolar GP tabulated benchmarks (clean DDI kernel test)

## References

- `docs/validation/self_contained_validation_report.md` — full
  validation chain + 5 findings consolidation
- `docs/validation/matsui_reproduction_status.md` — Matsui
  reproduction parameter set + Fig 2C reproduction status
- `docs/validation/ueda_status.md` — BLOCKED_EXTERNAL declaration
- `docs/validation/figures/{fig1..fig6}.png` — 6 figures
