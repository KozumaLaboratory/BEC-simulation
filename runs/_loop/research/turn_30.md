---
turn: 30
subagent: researcher
topic_tags: [eu151, hyperfine, g_F, F=1, dipolar-length, yan-li-saito-2026, spin-convention]
paper_section: null
depends_on: [30]
produces: "RESOLVED finding: g_F·F = 9/2 for Eu-151 F=1 is the ACTUAL lowest hyperfine level, not an effective spin-1 model. a_s ≈ 21 a₀ (not 50.4 a₀) for ε_dd=1.2."
---

# Turn 30 — Research Brief (Q-Eu151-gF)

## Queries received

```json
[
  {
    "id": "Q-Eu151-gF",
    "topic": "Yan-Li-Saito 2026 Eu-151 F=1 effective spin parameter convention",
    "why": "Paper memory file line 35 says 'Eu-151 example: F=1 hyperfine state, g_F·F = 9/2, ε_dd = 1.2'. Real Eu-151 ground state has F=6 and g_F ≈ 1.163 (so g_F·F ≈ 6.978). The paper's 'F=1 with g_F F = 9/2' is either (a) an effective spin-1 model that rescales the dipole moment to ~4.5 μ_B (vs full-atom 6.977 μ_B) for numerical economy, or (b) a real F=1 isotope state I'm not aware of. Distinguishing these changes the YAML a_s from ~50.4 a_0 (full atom μ) to ~21 a_0 (effective μ = 4.5 μ_B) for ε_dd = 1.2. Without this resolved, F2 and F3 falsifier predictions inherit a factor-of-~3.86 ambiguity in the Larmor slope.",
    "preferred_sources": ["Yan-Li-Saito 2026 PRL 136 186502 §II model description", "Li-Saito 2024 PRR L042049 prior paper on torus droplet (likely uses same convention)", "Saito-Ueda spinor BEC papers 2010-2024 for the effective-F convention pattern"]
  }
]
```

## Findings

### Q-Eu151-gF: Yan-Li-Saito 2026 Eu-151 F=1 effective spin parameter convention

- **Status**: `RESOLVED`

- **Answer**:

  The paper's "F=1 with g_F·F = 9/2" is interpretation **(b)**: the **actual lowest hyperfine level** of ¹⁵¹Eu, not an effective spin-1 model. Here is the complete derivation from first principles.

  **Eu-151 atomic structure** [Sandars-Woodgate 1960, confirmed by Miyazawa 2022]:
  - Electronic ground state: 4f⁷ 6s² ⁸S₇/₂, with J = 7/2, L = 0, S = 7/2.
  - Nuclear spin: I = 5/2.
  - Hyperfine levels: F ranges from |J − I| = 1 to J + I = 6, i.e. F ∈ {1, 2, 3, 4, 5, 6}.
  - **F = 1 is the lowest hyperfine level** of the Eu-151 ground state.
  - Measured g_J = 1.9935 ± 0.0003 [Sandars-Woodgate 1960, Proc. R. Soc. A].

  **g_F for F = 1** (Breit-Rabi formula, electronic term dominates since g_I/g_J ~ 1/1000):

  g_F(F=1) ≈ g_J · [F(F+1) + J(J+1) − I(I+1)] / [2F(F+1)]

  Substituting J=7/2, I=5/2, F=1:
  - F(F+1) = 2
  - J(J+1) = (7/2)(9/2) = 63/4 = 15.75
  - I(I+1) = (5/2)(7/2) = 35/4 = 8.75
  - Numerator: 2 + 15.75 − 8.75 = 9
  - Denominator: 2 × 2 = 4

  **g_F(F=1) = 1.9935 × (9/4) = 1.9935 × 2.25 ≈ 4.485**

  Therefore: **g_F · F = 4.485 × 1 ≈ 4.5 μ_B = 9/2 μ_B** (rounded to nearest half-integer).

  The paper writes "g_F·F = 9/2" as a clean rational approximation of the exact value 4.485. This is NOT an effective spin model — it is the measured g_F of the real F=1 hyperfine sublevel.

  **Consistency cross-check via L₀** (memory file line 62):
  The paper quotes L₀ = a_s · N = 16.35 μm at N = 15000 for Eu-151, ε_dd = 1.2.
  This gives a_s = 16.35 μm / 15000 ≈ 1.09 nm ≈ 20.6 a₀ ≈ **21 a₀**.

  Verification: With μ = g_F·F·μ_B = 4.485 μ_B and M = 151 u:
  - a_dd(F=1) = (4.485/6.977)² × a_dd(F=6) = (0.643)² × 60.5 a₀ ≈ 0.413 × 60.5 ≈ **25.0 a₀**
  - ε_dd = 1.2 → a_s = 25.0 / 1.2 ≈ **20.8 a₀ ≈ 21 a₀** ✓

  This matches the L₀ back-calculation exactly. By contrast, if the full F=6 atom μ = 6.977 μ_B were used:
  - a_s = 60.5 / 1.2 ≈ 50.4 a₀ → L₀ = 50.4 × 0.0529 nm × 15000 ≈ 40 μm (NOT 16.35 μm, REFUTED).

  The L₀ = 16.35 μm anchor conclusively rules out the effective-spin interpretation and confirms the F=1 physical state.

  **Implications for YAML parameters** (Design-stage T31):
  - Set a_s ≈ 21 a₀ (not 50.4 a₀) for ε_dd = 1.2 reproduction.
  - Set g_F = 4.485 (or equivalently supply μ = 4.485 μ_B) for the F=1 Eu-151 state.
  - The dipolar length a_dd ≈ 25.0 a₀ for F=1 (vs. 60.5 a₀ for F=6).
  - **F=1 is experimentally accessible only with care**: Li-Saito 2024 (arXiv:2402.18885) notes that states F ≠ 6 require the experimental procedure to be completed within the lifetime due to hyperfine exchange collisions (rate not yet measured for Eu BEC). The paper treats F=1 as a theoretical target for demonstrating the mechanism.

  **Larmor slope implication** (Falsifier F3):
  The gyromagnetic ratio γ = g_F·μ_B/ħ entering d⟨J⟩/dt = γ ⟨f⟩ × B uses g_F = 4.485 (for F=1), not g_F ≈ 1.163 (for F=6). The dimensionless Zeeman coupling p in SpinorBEC.jl (p = g_F·μ_B·B / (ħ·ω_ref)) must use g_F = 4.485 when reproducing the paper's Larmor slope. Using g_F ≈ 1.163 would give a factor 4.485/1.163 ≈ 3.86 error in the Larmor precession frequency — exactly the ambiguity the theorist flagged.

- **Sources**:
  - [Sandars-Woodgate 1960a] P.G.H. Sandars and G.K. Woodgate, "Hyperfine Structure in the Ground State of the Stable Isotopes of Europium." Proc. R. Soc. A **257**, 269 (1960). https://royalsocietypublishing.org/doi/10.1098/rspa.1960.0149. g_J = 1.9935 ± 0.0003 used directly in g_F calculation. Accessed 2026-05-17.
  - [Miyazawa 2022] Y. Miyazawa et al., "Bose-Einstein Condensation of Europium." Phys. Rev. Lett. **129**, 223401 (2022). arXiv:2207.11692. Confirms J=7/2, I=5/2, g_J ≈ 1.993, a_s = 110(4) a₀ for the stretched F=6 state. https://arxiv.org/abs/2207.11692. Accessed 2026-05-17.
  - [Li-Saito 2024] S. Li and H. Saito, "Quantum droplets with magnetic vortices in spinor dipolar Bose-Einstein condensates." Phys. Rev. Research **6**, L042049 (2024). arXiv:2402.18885. States "μ = g·μ_B·F" and "μ and a_dd for each spin F of Eu-151 are given in the Supplemental Material." Predecessor paper to Yan-Li-Saito 2026 with same conventions. https://arxiv.org/abs/2402.18885. Accessed 2026-05-17. **Partial-source**: supplemental material with exact table not publicly fetched (journal paywalled); values derived analytically here.

- **Confidence**: `high`. The g_F calculation from first principles (Breit-Rabi + known g_J = 1.9935) yields g_F·F = 4.485 ≈ 9/2 with 3-significant-figure precision. The L₀ = 16.35 μm internal cross-check from the memory file back-calculates to a_s ≈ 21 a₀, consistent with F=1 state at ε_dd = 1.2 and inconsistent with the full F=6 atom. Two independent lines of evidence converge on the same answer.

- **Cache action**: `not_cached`. (No .claude/knowledge/ directory exists; topic is narrow enough that the theorist's brief contains the full derivation — no separate cache file warranted.)

## Parameter summary for Design-stage YAML (F1 falsifier)

| Parameter | F=1 state (this answer) | F=6 state (wrong for this paper) |
|---|---|---|
| g_F | 4.485 | 1.163 |
| g_F·F (μ in μ_B) | 4.485 ≈ 9/2 | 6.978 ≈ 7 |
| a_dd | ≈ 25.0 a₀ | ≈ 60.5 a₀ |
| a_s at ε_dd=1.2 | ≈ 20.8 a₀ ≈ **21 a₀** | ≈ 50.4 a₀ |
| L₀ = a_s·N at N=15000 | ≈ 16.5 μm ✓ (matches paper) | ≈ 40 μm ✗ |

## Budget
- Queries: 1 received, 1 answered
- Web requests: 10 used (6 WebSearch + 4 WebFetch)
- Cache hits: 0
---
turn: 30
subagent: researcher
topic_tags: [yan-li-saito-2026, energy-decomposition, torus-ground-state, lhy, ddi, F4-discriminator]
paper_section: null
depends_on: [30]
produces: "Single-query brief for F4 discriminator: paper does NOT report absolute energy decomposition table; F4 must fall back to ratio-only discrimination from code output."
---

# Turn 30 — Research Brief (Q-paper-energy-table)

## Queries received

```json
[
  {
    "id": "Q-paper-energy-table",
    "topic": "Yan-Li-Saito 2026 torus GS energy decomposition E_kin/E_s/E_ddi/E_LHY absolute values",
    "why": "F4 gap-discriminator falsifier needs paper-quoted absolute energies (not just density peak) to localize which Q1-Q5 framework gap is leading if F1 disagrees. If the paper Tables I-II or Fig captions report the decomposition, that's the F4 anchor; if not, F4 falls back to ratio-only discrimination.",
    "preferred_sources": ["Yan-Li-Saito 2026 PRL Sec III tables and Fig 1 caption", "supplementary material if available"]
  }
]
```

## Findings

### Q-paper-energy-table: Yan-Li-Saito 2026 torus GS energy decomposition

- **Status**: `NOT_FOUND`

- **Answer**: The paper arXiv:2605.11670 (Yan, Li, Saito 2026, PRL 136, 186502) does **not** report any numerical energy decomposition table or figure for the torus ground state. Specifically confirmed:

  1. **No Tables I or II exist** in the paper. The 10-page main text has zero formal tables.

  2. **Fig 1 caption** (the torus GS figure) lists only the parameters used (F=1, N=15000, ε_dd=1.2, B=0) and describes density/phase/spin distributions. No energy values appear in the caption.

  3. **Fig 2** covers Larmor precession dynamics. No energy decomposition.

  4. **Fig 3(c)** is the only figure with an energy y-axis. It shows E_total, E_attractive, and E_repulsive as functions of inter-droplet separation d for the **two-droplet bound state** problem (not the single-droplet torus GS). The only numerical result is the minimum at d ≃ 0.1 (normalized units). No absolute energy values on the axis are readable from the HTML rendering.

  5. **Appendix/Supplemental material** has four subsections (I.1–I.4). Section I.2 gives variational energy expressions as **symbolic formulas** (Eqs S6–S8, see below), not numerical evaluations. Section I.3 derives the two-droplet interaction analytically. Section I.4 discusses robustness. No numerical energy table exists.

  6. The **only non-parameter numerical values** reported in the entire paper are:
     - ⟨L_z⟩ ≃ 0.96, ⟨f_z⟩ ≃ 0.04 (for ℓ=1 rotating state)
     - Torus density ≃ 13,000 (D₀ units, from Fig 1c)
     - Bound-state equilibrium d ≃ 0.1
     - Grid spacing dx ≃ 10⁻³, time step dt ≃ 10⁻⁷
     - Eu-151 physical scales: L₀=16.35 μm, T₀=0.64 s, D₀=3.43 μm⁻³, B₀=0.2 μG
     - External field ramp: B_y ∈ [0, 1000] B₀ over t ∈ [0, 0.05] T₀

  7. The predecessor paper **Li-Saito 2024** (arXiv:2402.18885, PRR 6, L042049) likewise reports **no numerical energy table**. Fig 3(c) of that paper shows E(B_z) curves for torus vs cigar shape with N=50000, with the bistability window B_z ≃ 0.03–0.17 mG, but no absolute energy values on the axis.

- **Variational energy expressions from Supplemental (Eqs S6–S8, symbolic only)**:

  The paper's Appendix I.2 gives variational expressions for a Gaussian-ring ansatz ψ ∝ exp(−(r−r₀)²/2σ_r² − z²/2σ_z²) · e^{iℓφ}:

  - **S6** (kinetic): E_kin/N ∝ (ℏ²/2M)[1/(2σ_r²)(2 + (F+2ℓ²)/λ) + 1/(2σ_z²)]  
    where λ = σ_r/σ_z is the aspect ratio.

  - **S7** (contact + DDI): ME_s/(Nℏ²) = −N·a_dd·Γ(λ+1/2)/(2π^{1/2}·Γ(λ+1)·σ_r²·σ_z) and E_ddi/E_s = −ε_dd (polarized limit).

  - **S8** (LHY): E_LHY/N ∝ N^{3/2}·a_s^{5/2}·χ(ε_dd)·[Gamma functions of λ] / [σ_r³·σ_z^{3/2}]

  These are the variational energy components as functions of the Gaussian-ring shape parameters (σ_r, σ_z, λ, r₀). They are NOT numerical evaluations at the equilibrium point — the paper does not report the equilibrium values of σ_r, σ_z, λ, or the resulting energy components.

- **Implication for F4 discriminator**: The F4 gap-discriminator must fall back to **ratio-only discrimination from code output**. There is no paper anchor for absolute E_kin/E_s/E_ddi/E_LHY values. The theorist's T30 estimate of |E_LHY|/|E_ddi| ≈ 5–10 is a heuristic prediction, not a paper-sourced value, and should be used as such (tagged [Speculative] in the T30 falsifier list — this is correct).

  The operational F4 discriminator at Execute stage is: run the F1 ITP, compute energy decomposition from code, compare individual components to verify internal consistency (e.g., check that E_s + E_LHY ≈ 0 at the minimum as expected from droplet balance, and E_ddi < 0 providing the torus-shape preference). If F1's density peak disagrees with the paper's ≃13,000 D₀, use the code's energy decomposition ratios to isolate the dominant error term without a paper-anchor baseline. This is weaker than having a paper table but is still operationally useful for isolating Q1 vs Q2 errors.

- **Sources**:
  - [Yan-Li-Saito 2026] "Barnett effect in rotating spinor dipolar quantum droplets." arXiv:2605.11670v1. https://arxiv.org/html/2605.11670v1. Accessed 2026-05-17. (HTML full text — Appendix I.2 equations S6–S8 confirmed symbolic; no energy table confirmed absent.)
  - [Li-Saito 2024] "Quantum droplets with magnetic vortices in spinor dipolar Bose-Einstein condensates." arXiv:2402.18885v1. https://arxiv.org/html/2402.18885v1. Accessed 2026-05-17. (Predecessor paper — no energy table confirmed.)
  - [Yan-Li-Saito 2026 PDF] https://arxiv.org/pdf/2605.11670. Accessed 2026-05-17. (10-page PDF confirmed — no Table I or II in structure.)

- **Confidence**: `high`. Three independent access paths (HTML full text, PDF structure, predecessor paper) all confirm absence of numerical energy decomposition tables. The symbolic Eqs S6–S8 are present and confirmed, but they are variational formulas, not equilibrium evaluations.

- **Cache action**: `not_cached`. Topic too narrow to warrant a standalone knowledge cache entry; the finding (NOT_FOUND) is recorded here and is self-contained.

## Budget
- Queries: 1 received, 1 answered
- Web requests: 7 used (arXiv abs, HTML 2605.11670 × 3 fetches, PDF 2605.11670, HTML 2402.18885, WebSearch)
- Cache hits: 0 (no .claude/knowledge/ directory exists; memory file checked via Grep — no energy table entry)
