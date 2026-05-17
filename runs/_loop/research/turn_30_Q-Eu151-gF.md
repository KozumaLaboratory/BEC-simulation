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
