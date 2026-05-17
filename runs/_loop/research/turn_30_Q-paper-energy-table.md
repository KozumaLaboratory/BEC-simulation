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
