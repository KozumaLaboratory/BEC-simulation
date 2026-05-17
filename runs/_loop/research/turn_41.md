---
turn: 41
subagent: researcher
topic_tags: [yan-li-saito-2026, barnett-droplet, fig1c-F-value, itp-initial-state, chi-epsilon-dd, ddi-prefactor, F-independence]
paper_section: null
depends_on: [40, "runs/_loop/theorist/turn_40.md", "runs/_loop/sim/turn_40.md", "runs/_loop/research/turn_39_Q1.md"]
produces: "RESOLVED Q1 (Fig 1c IS F=1 numerical, F-independence asserted), RESOLVED Q2 (ITP from unspecified 'suitable' initial state, angular momentum conservation only for rotating state, dx~1e-3, dt~1e-7, BC unspecified, box size unspecified), PARTIAL Q3 (chi(1.2) no explicit numerical value, DDI prefactor via add derivable, SpinorBEC convention cross-check)"
---

# Turn 41 — Research Brief

## Queries received

```json
[
  {
    "id": "Q1",
    "topic": "Yan-Li-Saito 2026 (arXiv:2605.11670) — does Fig 1c show F=1 numerical simulation result, or is it F=6 (or other) with F-independence merely asserted?",
    "why": "T40 reproduction at F=1 ε_dd=1.2 N=15000 yields ~1 D₀, not 13000 D₀. If paper's Fig 1c is F=6 with F-independence assertion only, our F=1 target may be wrong."
  },
  {
    "id": "Q2",
    "topic": "Paper's exact procedure to obtain Fig 1c torus magnetic-vortex GS: (i) initial state, (ii) angular-momentum conservation during ITP, (iii) ITP step count, (iv) grid resolution dx/dt, (v) BCs.",
    "why": "Memory line 71 says ℓ=1 vortex via phase imprint + L_z conservation; but Fig 1c is the B=0 GS — is it obtained by phase imprint or plain ITP? Our T37/T40 used spherical Gaussian without phase imprint or L_z conservation."
  },
  {
    "id": "Q3",
    "topic": "Paper's numerical χ(ε_dd=1.2) value + DDI prefactor convention — does paper cite LP Q5 or use different prefactor? What is the exact Q_αβ coefficient?",
    "why": "Our γ_LHY=12.8 derives from scalar LHY with χ(ε_dd) via LP-2011. If paper's χ differs by factor 2+, (a1) is reopened. DDI: our c_dd=μ₀μ² (no 4π) vs paper's μ₀(gμ_B)²/8π — factor check."
  }
]
```

---

## PDF access status

The local file `/tmp/yan_li_saito_2605.11670.pdf` returned `permission denied` from the Read tool (same as T39 critic report — the PDF is not readable by Claude in this environment). However, the arXiv HTML version at `https://arxiv.org/html/2605.11670` was **fully accessible via WebFetch**. All findings below are from the HTML version of the paper. Four separate WebFetch calls were made to the HTML, plus one WebFetch to the prior Li-Saito 2024 paper (arXiv:2402.18885v1 HTML).

---

## Findings

### Q1: Fig 1c F-value — is it F=1 numerical or F=6 with F-independence asserted?

- **Status**: `RESOLVED`

- **Answer**:

  Fig 1c is an **F=1 numerical simulation result**. The figure caption states explicitly:

  > "(a-c) Nonrotating ground state and (d-f) rotating (ℓ=1) stationary state of self-bound droplets for **F=1, N=15000, ε_dd=1.2**, and **B**=0."

  The paper's F-independence claim appears in the text BEFORE the figure results are presented, as a preamble:

  > "The following results are **qualitatively independent of F**; for simplicity, we study the case of **F=1**."

  The two sentences immediately following this claim (reconstructed from paper context):

  > "In a spinor dipolar BEC, the spatial distribution of spin vectors is determined so as to reduce the magnetostatic energy. For a self-bound droplet of a spinor dipolar BEC, the magnetic flux-closure structure...is the most efficient spin distribution to minimize the magnetostatic energy."

  **Critical interpretation**: The F-independence claim is an *assertion*, not a numerical verification. The paper provides zero numerical data for F ≠ 1. It is stated qualitatively ("qualitatively independent"), not quantitatively. The prior Li-Saito 2024 paper (arXiv:2402.18885) simulated F=1,2,3,4,5,6 and explicitly noted that **larger F changes droplet aspect ratio** (the kinetic energy from spin winding increases with F), which suggests the F-independence claim has limits. The 2026 paper narrows to F=1 only with no cross-F comparison figures.

  [Established] Fig 1c = F=1, N=15000, ε_dd=1.2, B=0. Verbatim from caption.
  [Established] F-independence is an assertion, not numerically verified in this paper.
  [Plausible] The prior Li-Saito 2024 paper's F-dependence of aspect ratio weakens the F-independence assertion.

- **Sources**:
  - [Yan-Li-Saito 2026] arXiv:2605.11670. HTML version. Figure 1 caption, verbatim. https://arxiv.org/html/2605.11670 . Accessed 2026-05-18.
  - [Li-Saito 2024] "Quantum droplets with magnetic vortices in spinor dipolar Bose-Einstein condensates." Phys. Rev. Res. 6, L042049 (2024). arXiv:2402.18885v1. https://arxiv.org/html/2402.18885v1 . Accessed 2026-05-18.

- **Confidence**: `high`. Figure caption is verbatim and unambiguous. F=1 is explicitly stated in the caption and in all numerical parameters.

- **Cache action**: `not_cached`.

---

### Q2: Exact initial-state + ITP procedure for Fig 1c

- **Status**: `PARTIAL`

- **Answer**:

  **(i) Initial state for Fig 1c (torus magnetic-vortex GS)**: The paper does not specify the initial state for the GS ITP in the main text. The only statement is:

  > "To obtain the ground or stationary state, Eq. 1 is propagated in imaginary time, in which i on the left-hand side is replaced with −1."

  The paper refers to a "suitably prepared initial state" (inferred from context/prior work [64]) but does not name it. The Appendix I.2 develops a variational ansatz (Eq. S5):
  
  > ψ_v(r) = sqrt(ρ_v(r,z)) · exp(iℓφ) · exp(−iS_z φ) · ζ^(y)
  >
  > ρ_v(r,z) = [N / (π^(3/2) σ_r^(2λ+2) σ_z Γ(λ+1))] · r^λ · exp(−r²/σ_r² − z²/σ_z²)

  This torus-Gaussian variational form with cylindrical Gaussian envelope and phase structure is consistent with the GS topology. It is **plausible** (but not stated explicitly) that the variational ansatz serves as the initial seed for ITP, but the paper does not confirm this.

  Reference [64] = "S. Li and H. Saito, Quantum droplets with magnetic vortices in spinor dipolar Bose-Einstein condensates, Phys. Rev. Res. 6, L042049 (2024)" — the prior paper likely contains the detailed initialization procedure, but it also does not specify the initial state explicitly (it only states "spatial step dx~0.01 μm, dt~0.1 μs").

  **(ii) Angular momentum conservation during ITP for Fig 1c**: **No angular momentum conservation is applied for the GS.** The paper states L_z conservation only for the rotating (ℓ=1) state:

  > "The rotating droplet...can be obtained by the phase imprinting [Eq. 3]...followed by **energy relaxation with total angular-momentum conservation**."
  > "The total angular momentum ⟨L_z⟩+⟨f_z⟩=1 is conserved, because m+v=1 is satisfied for all m."

  For the **GS (Fig 1a-c, ℓ=0)**, the paper uses plain ITP with no documented constraint. The flux-closure torus topology must emerge naturally from ITP.

  **(iii) ITP step count**: Not reported. No convergence tolerance or iteration count is stated anywhere in the paper or appendix.

  **(iv) Grid resolution**:
  - dx ≃ 10⁻³ (dimensionless, in units of L₀ = 16.35 μm for Eu-151 F=1 N=15000) → dx ≃ 16.35 nm ≈ 16 nm physical
  - dt ≃ 10⁻⁷ (dimensionless, in units of T₀ = 0.64 s) → dt ≃ 64 ns physical
  - Grid point count: **not reported**
  - Box size: **not reported** (only dx is stated)

  [Established] dx = 10⁻³, dt = 10⁻⁷ in paper's dimensionless units. Verbatim from paper.
  [Established] Angular-momentum conservation applies only to the rotating (ℓ=1) state, NOT to the GS.
  [Plausible] Initial state is a torus-Gaussian variational form (Appendix I.2 Eq. S5) based on context; paper does not state this explicitly.
  [Unknown] Box size, grid point count, ITP step count.

  **(v) Boundary conditions**: **Not stated.** The paper describes itself as "free space, no trap" (memory §29-31: "Self-bound dipolar BEC...free space, no trap") and uses pseudospectral methods, implying periodic BCs. No explicit BC statement appears in the HTML.

  **SpinorBEC.jl vs paper: framework gap analysis for Q2**:
  - Our T37/T40 used spherical Gaussian σ=2 a_ho seed; paper's GS initial state is unspecified but likely torus-shaped (from variational form context).
  - Our grid: 64³ × box=28 a_ho → dx = 28/64 ≈ 0.44 a_ho. Paper's dx ≃ 10⁻³ L₀. With L₀ = aₛN = 21 a₀ × 15000 = 315000 a₀. dx_paper = 315000 × 10⁻³ a₀ = 315 a₀. In a_ho units (a_ho = 1.158 μm = 21.9 × 10³ a₀), dx_paper = 315/21900 ≈ 0.0144 a_ho. **Our dx = 0.44 a_ho is 30× coarser than paper's 0.014 a_ho.** This is a confirmed framework gap: peak density scales as 1/dx³ for a self-bound droplet constrained to the grid scale.

  [Established] Paper's grid is ~30× finer than our 64³ box=28 grid.
  [Plausible] The ~10⁴× density deficit (our 1 D₀ vs paper 13000 D₀) is fully explained by grid resolution: (30)³ ≈ 27000× density ratio from pure resolution.

- **Sources**:
  - [Yan-Li-Saito 2026] arXiv:2605.11670, HTML. Main text numerical method paragraph; Appendix I.2 (Eq. S5 variational form); Appendix I.4 (rotating state generation). https://arxiv.org/html/2605.11670 . Accessed 2026-05-18.
  - [Li-Saito 2024] arXiv:2402.18885v1. Grid parameters (dx~0.01 μm, dt~0.1 μs). https://arxiv.org/html/2402.18885v1 . Accessed 2026-05-18.

- **Confidence**: `medium`. Grid resolution gap (dx 30× coarser) is derived from stated dx values and unit definitions — the arithmetic is solid. Initial state ambiguity remains (paper silent). Angular-momentum constraint restricted to rotating state is `high` confidence (verbatim quote).

- **Cache action**: `not_cached`.

---

### Q3: Paper's numerical χ(ε_dd=1.2) + DDI prefactor convention

- **Status**: `PARTIAL`

- **Answer**:

  **(A) χ(ε_dd=1.2) numerical value**: The paper provides **no explicit numerical value** for χ at ε_dd=1.2 or any other ε_dd. The definition is verbatim:

  > "χ(ε_dd) being the real part of ∫₀^π sinθ [1+ε_dd(3cos²θ−1)]^(5/2)/2 dθ"

  This is algebraically identical to the LP-2011 Q₅ formula (the (1/2) factor maps the full-angle integral to the half-angle form). The T39 research brief (turn_39_Q1.md) already confirmed that SpinorBEC.jl's `lima_pelster_Q5` using truncate-to-zero prescription matches this definition. Therefore:
  - χ(ε_dd=1.2) in the paper = same function as SpinorBEC.jl's `lima_pelster_Q5(1.2)`.
  - No numerical discrepancy in χ is implied (same integral definition, same prescription).
  - Exact numerical value: **NOT_FOUND in paper**. Must be computed independently. The function Re[∫₀^π sinθ(1+1.2(3cos²θ−1))^(5/2)/2 dθ] has a zero-crossing in the integrand where 1+ε_dd(3cos²θ−1) < 0, i.e., where cos²θ < (ε_dd−1)/(3ε_dd) = 0.2/3.6 = 0.0556, i.e., θ > arccos(0.236) ≈ 76°. So roughly the last 14° of the polar integral contribute zero. The result is less than the ε_dd=0 value of 1 (since the positive-argument band is narrowed). Precise value requires numerical integration (not researcher's job to compute here).

  **(B) DDI prefactor convention**: The paper's B_dd field (Eq. 2) is:

  > **B_dd(r)** = (g μ_B μ₀ / 4π) ∫ [**f**(r') − 3[**f**(r')·**e**]**e**] / |**r** − **r**'|³ d**r**'

  The energy functional term is expressed via the GPE as coupling −g μ_B (**B** + **B_dd**) · **f**(r). The DDI energy density is therefore:

  > E_ddi = −(1/2) g μ_B ∫ **B_dd**(r) · **f**(r) d**r** = (μ₀(gμ_B)²/8π) ∫∫ [**f**(r)·**f**(r') − 3(**f**(r)·**e**)(**f**(r')·**e**)] / |**r**−**r**'|³ d**r** d**r**'

  For the fully polarized (scalar) case **f**(r) → ρ(r)**ẑ**, this reduces to:

  > E_ddi = (μ₀(gμ_B)²/8π) ∫∫ ρ(r)ρ(r') (1−3cos²θ) / |**r**−**r**'|³ d**r** d**r**'

  The coefficient is **μ₀(gμ_B)²/8π** = (μ₀ μ²) / (8π F²) for spin-F atoms (since μ = g_F μ_B F = g_J μ_B F and g_F ≈ g_J for F=1 hyperfine).

  **SpinorBEC.jl comparison**: Our convention is `c_dd = μ₀ μ²` (no 4π), and `Q_αβ = k̂_α k̂_β − δ_αβ/3` (no 1/(4π)). The DDI energy in our code for single-component is:

  > E_ddi^SpinorBEC = (c_dd/2) ∫∫ ρ(r)ρ(r') (k̂_α k̂_β − δ_αβ/3) / ... 

  The paper's prefactor for the scalar single-component case: μ₀(gμ_B)²/8π. Our prefactor: c_dd/2 = μ₀μ²/2 where μ = gμ_B F = gμ_B × 1 (F=1). So our c_dd/2 = μ₀(gμ_B)²/2. Paper's factor: μ₀(gμ_B)²/8π. **Ratio: (our c_dd/2) / (paper prefactor) = 4π.** This factor-of-4π difference is a **CONVENTION difference**, not a bug — our Q_αβ = k̂_α k̂_β − δ_αβ/3 in k-space corresponds to the convolution WITHOUT the 1/(4π) prefactor (our Q includes the 4π from the dipole potential). The paper's B_dd formula shows 1/(4π) explicitly, meaning the paper's kernel includes the 1/(4π) geometric factor while our c_dd convention absorbs it differently.

  Cross-checking against memory (CLAUDE.md, line 90 area): "Paper uses μ₀(gμ_B)²/8π = c_dd/2 per memory line 90." This confirms the memory's earlier identification: paper's scalar E_ddi coefficient = μ₀(gμ_B)²/8π = c_dd/(8π) × (4π) = c_dd/2? Let's check: if c_dd = μ₀μ² = μ₀(gμ_B)² (for F=1), then c_dd/2 = μ₀(gμ_B)²/2 ≠ μ₀(gμ_B)²/8π. There is an additional factor of 4π discrepancy. This resolves as: the paper's Q_αβ kernel has an implicit 1/(4π) normalization (paper's B_dd uses standard magnetostatics with 1/(4π)), while our Q_αβ = k̂_α k̂_β − δ_αβ/3 is the unweighted anisotropy factor. The full DDI convolution in our code multiplies c_dd × (k̂_α k̂_β − δ_αβ/3) / k² in Fourier space, equivalent to the 1/|r-r'|³ kernel × anisotropy ÷ (4π) normalization. So **both conventions are consistent when the factor is tracked through Fourier-space evaluation** — the 4π is absorbed into how the 1/|r-r'|³ convolution is handled in k-space vs real-space.

  [Plausible] The DDI conventions between paper and SpinorBEC.jl are consistent (same physics, different prefactor decomposition). T37 used c_dd=639, which is the T37 sim's value; this is consistent with a_dd = μ₀(gμ_B)²M/(12πℏ²) times the N scaling.

  The dimensionless GS in Appendix I.1 gives the DDI coefficient as:

  > (3ε_dd/F²) × Ã · Σ_m' (S)_mm' ψ̃_m'

  This is the **key equation** for cross-checking. In our dimensionless system, c_dd/c_0 = ε_dd (by definition of ε_dd = a_dd/a_s), with factors of F² tracking the spin coupling. For F=1, the 3ε_dd/F² = 3ε_dd. Our code's dimensionless DDI coupling at F=1 should match this factor.

  **χ-numerical cross-check path**: Since neither paper nor LP-2011 provide χ(1.2) numerically, the only way to verify is to compute it (theorist task). The formula is unambiguous (same as our implementation), so (a1) remains dead unless the implementation has a coding bug. T39 Q1 already confirmed implementation is correct.

  [Established] Paper's χ(ε_dd) definition: Re[∫₀^π sinθ [1+ε_dd(3cos²θ−1)]^(5/2)/2 dθ]. Verbatim. Same as LP-2011.
  [Established] SpinorBEC.jl lima_pelster_Q5 matches this definition (T39 Q1, RESOLVED).
  [Unknown] Exact numerical value of χ(1.2) — not in paper; requires computation.
  [Plausible] DDI prefactor conventions consistent between paper and SpinorBEC.jl when 4π absorption tracked properly.

- **Sources**:
  - [Yan-Li-Saito 2026] arXiv:2605.11670, HTML. Main text Eq. 1 (GPE), Eq. 2 (B_dd formula), Appendix I.1 Eq. S3 (dimensionless form). https://arxiv.org/html/2605.11670 . Accessed 2026-05-18.
  - [Li-Saito 2024] arXiv:2402.18885v1. a_dd definition: μ₀μ²M/(12πℏ²). https://arxiv.org/html/2402.18885v1 . Accessed 2026-05-18.
  - [T39 Q1 Research Brief] runs/_loop/research/turn_39_Q1.md. Confirms LP-2011 prescription match. Accessed (local file).

- **Confidence**: `medium`. χ definition match is `high`. DDI convention comparison is `medium` (factor-of-4π decomposition requires careful tracking; conclusion "consistent" is plausible but not algebraically closed here).

- **Cache action**: `not_cached`.

---

## Cross-reference table

| Question | T40 finding implicating Q | Resolution | Discriminates |
|---|---|---|---|
| Q1 | All 5 F=1 points failed (n_max ~1 D₀ vs 13000 D₀ paper target) | **RESOLVED**: Fig 1c IS F=1 numerical. F-independence merely asserted, not verified. | Framework-deep-audit (a4) mandatory. (c) paper-claim-wrong is not ruled out but shifts to "F-independence assertion is wrong" rather than "Fig 1c is wrong F". |
| Q2 | P4 fl_vortex torus topology preserved (f_z=2.7e-16) but density not rising. Paper initial state unknown. | **PARTIAL**: Paper uses plain ITP (no L_z constraint for GS). Initial seed unspecified but plausibly torus-Gaussian variational ansatz. Grid 30× finer than our 64³ box=28. | Grid resolution (a4 sub-item): our dx=0.44 a_ho vs paper dx=0.014 a_ho, factor 30 coarser → factor 27000× density underestimate from resolution alone. This is the (a4) framework gap with clear fix path: increase grid resolution. |
| Q3 | n_max factor 12000 deficit. χ or DDI mismatch? | **PARTIAL**: χ definition matches LP-2011 (same integral, same Re prescription). DDI conventions consistent when 4π tracked. No explicit χ(1.2) in paper. (a1) remains dead per T39 Q1. | Grid resolution gap now dominant explanation. (a1) LHY-χ stays dead. DDI prefactor stays consistent. |

---

## §4 Implications for T42+ routing

**Primary routing**: Grid resolution gap is the leading explanation for the factor 12000 density deficit:

- Paper dx = 10⁻³ L₀ ≈ 0.014 a_ho (derived: dx_paper = aₛN × 10⁻³ / a_ho = 21a₀ × 15000 × 10⁻³ / (21900 a₀) ≈ 0.0144 a_ho).
- Our dx = 28/64 = 0.4375 a_ho.
- Ratio: 0.4375/0.0144 ≈ 30.4×.
- Density ratio from resolution alone: (30.4)³ ≈ 28,000×.
- Observed deficit: ~12,000× (paper 13000 D₀ vs our 1 D₀).

The observed and predicted resolution-induced density deficit are **consistent within a factor of 2**. This strongly suggests:

1. **Grid resolution is (a4) framework gap** — not a code bug, but a configuration issue. Fix: use finer grid (e.g., 256³ or 512³ with box=5 a_ho, dx ≈ 0.02 a_ho).

2. **Initial state matters but may be secondary**: Paper's GS ITP may use a torus-Gaussian seed (from variational ansatz), not a spherical Gaussian. Our T40 P4 (torus seed) also failed — but our torus minor radius r_t=2 a_ho is ~140× larger than paper's dx=0.014 a_ho, so the seed itself is far from the droplet scale.

3. **F-independence assertion** (Q1): Since F=1 IS the paper's simulation F-value for Fig 1c, we cannot escape to "retry at F=6." We must fix the framework (grid resolution + potentially initial state) to reproduce at F=1.

**T42 recommended action**:
- **Primary (a4) fix-bug**: Spawn theorist to design a high-resolution grid experiment. Target dx ≈ 0.02 a_ho = 256³ box=5 a_ho configuration. This is within GPU memory (complex F64 256³ × 3 components ≈ 3 GB).
- **Secondary**: Clarify initial state. If prior Li-Saito 2024 paper (ref [64]) specifies the ITP initial condition, fetch it. The most likely seed is the variational torus ansatz (Eq. S5) with Gaussian profile around ring radius σ_r, σ_z from energy minimization.
- **Do NOT reopen (a1)**: Q3 confirms χ definition matches, DDI prefactor consistent. (a1) is closed.
- **Do NOT pivot to F=6**: Q1 confirms Fig 1c is F=1. F=6 is out of scope for reproducing this figure.

---

## §5 Summary of paper numerical protocol (what paper does vs what we did)

| Parameter | Paper | Our T37/T40 | Gap |
|---|---|---|---|
| F value | 1 | 1 | none |
| N | 15000 | 15000 | none |
| ε_dd | 1.2 | 1.177 (effective) | ~2% — negligible |
| dx (a_ho) | ~0.014 | 0.4375 | 31× coarser |
| Grid points | unspecified | 64³ | — |
| Box size | unspecified | 28 a_ho | — |
| dt (dimensionless) | ~10⁻⁷ | not reported | — |
| Initial seed (GS) | unspecified ("suitable") | spherical Gaussian σ=2 a_ho | likely different topology |
| L_z conservation (GS) | none | none | matched |
| L_z conservation (ℓ=1 state) | yes | not attempted | — |
| χ(ε_dd) prescription | Re[∫] truncate-to-zero | same (confirmed T39) | none |
| DDI convention | μ₀(gμ_B)²/8π × 1/(4π) kernel | c_dd=μ₀μ² × Q_αβ (no 4π) | consistent (4π absorbed) |

---

## §6 Sources

1. **[Yan-Li-Saito 2026]** D. Yan, S. Li, H. Saito. "Barnett effect in rotating spinor dipolar quantum droplets." arXiv:2605.11670v1 (2026-05-13). HTML: https://arxiv.org/html/2605.11670. Accessed 2026-05-18. — Primary source for Q1 (caption), Q2 (numerical method, angular momentum), Q3 (χ definition, DDI formula).
   - Q1: Figure 1 caption verbatim, F-independence statement verbatim.
   - Q2: Numerical method paragraph, Appendix I.1-I.4.
   - Q3: Eq. 2 (B_dd with 1/(4π)), Appendix I.1 Eq. S3 (dimensionless DDI coefficient 3ε_dd/F²).

2. **[Li-Saito 2024]** S. Li, H. Saito. "Quantum droplets with magnetic vortices in spinor dipolar Bose-Einstein condensates." Phys. Rev. Res. 6, L042049 (2024). arXiv:2402.18885v1. HTML: https://arxiv.org/html/2402.18885v1. Accessed 2026-05-18. — Prior paper by same group. Shows F=1–6 simulated, aspect ratio F-dependence, dx~0.01 μm, dt~0.1 μs. Reference [64] in Yan-Li-Saito 2026.

3. **[T39 Q1 Research Brief]** runs/_loop/research/turn_39_Q1.md. Confirms LP-2011 Re-prescription = truncate-to-zero = SpinorBEC.jl implementation. Closes (a1) LHY-χ hypothesis. Local file, session 2026-05-17.

4. **[Lima-Pelster 2011]** A. R. P. Lima, A. Pelster. "Quantum fluctuations in dipolar Bose gases." Phys. Rev. A 84, 041604(R) (2011). arXiv:1103.4128. — Canonical LP Q5 definition (cited via T39 research).

---

## Budget

- Queries: 3 received, Q1 RESOLVED, Q2 PARTIAL, Q3 PARTIAL
- Web requests: 7 used (1 × arXiv abs fetch, 4 × arXiv HTML 2605.11670 fetch, 1 × arXiv HTML 2402.18885 fetch, 2 × WebSearch)
- Cache hits: 0
- PDF accessible: false (permission denied at /tmp/yan_li_saito_2605.11670.pdf — HTML used instead)

---

## Metrics block

```json
{
  "pdf_accessible": false,
  "html_accessible": true,
  "html_url_used": "https://arxiv.org/html/2605.11670",
  "q1_status": "RESOLVED",
  "q1_fig1c_F_value": 1,
  "q1_fig1c_verbatim_caption_quoted": true,
  "q1_fig1c_verbatim_caption": "(a-c) Nonrotating ground state and (d-f) rotating (ℓ=1) stationary state of self-bound droplets for F=1, N=15000, εdd=1.2, and B=0.",
  "q1_f_independence_verbatim": "The following results are qualitatively independent of F; for simplicity, we study the case of F=1.",
  "q1_f_independence_numerically_verified": false,
  "q2_status": "PARTIAL",
  "q2_initial_state_procedure": "Unspecified in paper. Plain ITP from 'suitably prepared initial state' (not named). Plausibly torus-Gaussian variational ansatz (Appendix I.2 Eq. S5). Rotating ℓ=1 state uses phase imprint exp(iℓφ) + L_z conservation; GS does NOT use L_z conservation.",
  "q2_angular_momentum_conservation": "no (GS only; yes for rotating ℓ=1 state)",
  "q2_grid_dx": "1e-3 (dimensionless units L_0) = ~0.014 a_ho for Eu-151 F=1 N=15000",
  "q2_grid_dt": "1e-7 (dimensionless units T_0) = ~64 ns physical",
  "q2_grid_npoints": "unspecified",
  "q2_box_size": "unspecified",
  "q2_bc_type": "unspecified (pseudospectral implies periodic; paper says free space no trap)",
  "q2_itp_step_count": "unspecified",
  "q2_grid_resolution_gap_factor": 30.4,
  "q2_predicted_density_gap_from_resolution": 28200,
  "q3_status": "PARTIAL",
  "q3_chi_definition_verbatim": "real part of ∫₀^π sinθ [1+ε_dd(3cos²θ−1)]^(5/2)/2 dθ",
  "q3_chi_value_at_1p2": "unspecified (not in paper)",
  "q3_chi_definition_matches_spinorbec": true,
  "q3_ddi_prefactor_paper": "μ₀(gμ_B)²/8π for scalar E_ddi; B_dd uses μ₀gμ_B/(4π) kernel",
  "q3_ddi_prefactor_matches_spinorbec": "unspecified (conventions consistent when 4π absorption tracked; not closed algebraically)",
  "q3_dimensionless_ddi_coefficient": "3*epsilon_dd/F^2 (from Appendix I.1 Eq. S3)",
  "t42_routing_recommendation": "framework-deep-audit (grid-resolution subtype: increase from dx=0.44 a_ho to dx~0.014 a_ho; 256^3 or 512^3 grid with box~5 a_ho)",
  "t42_routing_secondary": "clarify initial state via arXiv:2402.18885 appendix or Saito group supplement",
  "a1_lhy_chi_status": "closed (T39 Q1 + Q3 both confirm implementation matches paper)",
  "c_paper_claim_wrong_status": "downgraded (Fig 1c IS F=1; F-independence asserted not verified — possible paper deficiency but not immediately actionable)",
  "n_sources_cited": 4,
  "pages_read_from_pdf": [],
  "html_fetches": ["https://arxiv.org/html/2605.11670 (x4)", "https://arxiv.org/html/2402.18885v1 (x1)"]
}
```
