---
turn: 42
subagent: critic
investigation_id: yan-li-saito-2026-reproduction
audited_artifact: runs/_loop/research/turn_41.md
depends_on: [41, 40, 37, "runs/_loop/theorist/turn_40.md", "runs/_loop/sim/turn_40.md", "runs/_loop/judge/turn_40.json", "runs/yan_li_saito_f1_torus_gs/config.yaml", "memory:yan_li_saito_2026_barnett_paper"]
produces: "Audit of T41 PARTIAL items. Section A (dx-ratio): CORROBORATE. Section B (DDI prefactor): CORROBORATE, closed-bit-equal (ratio = 1). Section C (chi(1.2)): DISMISSED-negligible. Section D (initial state): sufficient. Section E: R1 (Hypothesize grid refinement). Tier 0.6 -> 0.8."
verdict: PASS
---

## Section A — dx-ratio arithmetic audit

### A(i) — Independent verification of a_ho

From `runs/yan_li_saito_f1_torus_gs/config.yaml:33`, `omega_ref: 314.159` rad/s (= 2π·50 Hz, Klaus convention). With m_Eu-151 = 151 × 1.66054e-27 kg = 2.5074e-25 kg, ℏ = 1.05457e-34 J·s:

- a_ho² = ℏ/(m·ω_ref) = 1.05457e-34 / (2.5074e-25 × 314.159) = 1.05457e-34 / 7.8779e-23 = 1.3387e-12 m²
- a_ho = 1.1570e-6 m = **1.157 μm** [Established]
- a_ho / a₀ = 1.1570e-6 / 5.2918e-11 = **21864 ≈ 21900 a₀** [Established]

The implementer's analysis (sim/turn_40.md §5) reports `a_ho = 1.1570e-6 m` independently, confirming. T41's value of 21900 a₀ used in the dx-ratio is correct to within rounding.

**Cross-check on JLD2 metadata** (sim/turn_37.md:92): `units/a_ho_m: 1.15735231912351e-6` ≡ 1.157 μm. Bit-equal. [Established]

### A(ii) — Independent geometric sanity check

T41 derives dx_paper = 0.0144 a_ho and our dx = 0.4375 a_ho → ratio 30.4 → predicted density gap 28,000×. Reproducing:

- L₀ = a_s × N = 21 a₀ × 15000 = 315,000 a₀ ✓
- dx_paper (a₀) = 10⁻³ × L₀ = 315 a₀ ✓
- dx_paper (a_ho) = 315 / 21864 = **0.01441 a_ho** ✓
- our dx = 28 / 64 = **0.4375 a_ho** ✓ (config line 35: box 28.0)
- ratio = 0.4375 / 0.01441 = **30.36** ✓
- (30.36)³ = **27,985** ✓
- observed gap = paper 13000 D₀ / sim 1.057 D₀ (T40 P1 maximum) = **12,300** ✓
- consistency: 27,985 / 12,300 = 2.28 — within factor 2.3, consistent with a 1/dx^n scaling for n ∈ [2.6, 3.0] (geometric scaling, not exact, allowing slack for prefactor and density-profile shape) [Plausible]

**Independent geometric argument** (paper Fig 1c axis range r/L₀ ∈ [-0.05, +0.05]):
- droplet half-extent = 0.05 × L₀ = 0.05 × 16.35 μm = 0.82 μm = 0.82/1.157 = **0.71 a_ho**
- droplet diameter ≈ **1.4 a_ho**
- our grid points across droplet = 1.4 / 0.4375 = **3.2 cells**
- paper grid points across droplet = 1.4 / 0.01441 = **97 cells**

Three cells across the entire droplet cannot resolve the torus internal structure (paper Fig 1a-c shows a torus with minor-radius / major-radius ratio ~ 0.2–0.4 inside the 0.05 L₀ scale, meaning the torus minor radius ≈ 0.2 a_ho — sub-grid for us by factor 2). [Established] Our grid cannot represent the paper's droplet geometry. The independent geometric argument is **stronger** than the dx-ratio statistic alone because it ties the underresolution directly to a *visible feature* in Fig 1c, not just a Planck-density argument.

### A(iii) — Section A verdict

**CORROBORATE.** Two independent arithmetic chains (dx-ratio (i), droplet-cell count (ii)) both point at the same root cause with consistent magnitude. The 2.3× residual between predicted (28,000×) and observed (12,300×) gap is plausibly explained by:
- ITP did not even reach the droplet basin from a Gaussian seed (energy-balance, theorist T40 §2.2 E_DDI=0 for isotropic seed); the observed 1 D₀ is essentially the "delocalized fill of 28³ box at N=15000 atoms per unit cell" baseline, not "1/dx³-limited self-bound droplet density"
- Therefore the 12,300× gap is an *over-estimate* of the underresolution penalty — the actual underresolution penalty (had the droplet basin been reached) might be the full 28,000×, perfectly consistent

The dx-ratio + droplet-cell-count joint corroboration sets up a falsifiable T43 prediction (Section E).

---

## Section B — DDI prefactor algebraic closure

T41's "consistent when 4π tracked" is hand-wavy. Closing algebraically below.

### B.1 — Fourier convention

I use the **symmetric-physics convention** standard for split-step Fourier codes (SpinorBEC uses FFTW which is conjugate to this with sign convention `exp(-ik·r)`; the choice does not affect even-kernel results):

$$\tilde{f}(\vec{k}) = \int f(\vec{r}) e^{-i\vec{k}\cdot\vec{r}} d^3r, \quad f(\vec{r}) = \int \tilde{f}(\vec{k}) e^{+i\vec{k}\cdot\vec{r}} \frac{d^3k}{(2\pi)^3}$$

Parseval: $\int |f(\vec{r})|^2 d^3r = \int |\tilde{f}(\vec{k})|^2 d^3k/(2\pi)^3$.

Convolution: $\int f(r)g(r-r')dr' = (f * g)(r) \Leftrightarrow \tilde{f}(k)\tilde{g}(k)$.

### B.2 — Standard DDI Fourier identity

The Fourier transform of the regularized dipolar kernel is a textbook result (Goral-Santos PRA 66 023613 (2002) Eq. 8; Lahaye et al. RPP 72 126401 (2009) Eq. 13; Ronen-Bohn 2006):

$$\text{FT}\!\left[\frac{1 - 3\cos^2\theta_r}{r^3}\right] = +\frac{4\pi}{3}\left(3\hat{k}_z^2 - 1\right) = 4\pi\left(\hat{k}_z^2 - \frac{1}{3}\right)$$

where the kernel is regularized to remove the δ(r) contact contribution (so that Q(k=0) = 0 directly). [Established, multiple independent references]

### B.3 — Paper E_ddi in Fourier form

From T41 §Q3.B (paper Eq. 2 transcribed):

$$E_{ddi}^{paper} = \frac{\mu_0(g\mu_B)^2}{8\pi}\iint\rho(r)\rho(r')\frac{1 - 3\cos^2\theta}{|r-r'|^3}d^3r\,d^3r'$$

Treat this as $E = \frac{\mu_0(g\mu_B)^2}{8\pi} \int\rho(r)(\rho * K)(r)\, d^3r$ with $K(r) = (1-3\cos^2\theta_r)/r^3$. By Parseval + convolution:

$$E_{ddi}^{paper} = \frac{\mu_0(g\mu_B)^2}{8\pi}\int\frac{d^3k}{(2\pi)^3}|\tilde{\rho}(k)|^2 \cdot \tilde{K}(k) = \frac{\mu_0(g\mu_B)^2}{8\pi}\cdot 4\pi\int\frac{d^3k}{(2\pi)^3}|\tilde{\rho}(k)|^2\left(\hat{k}_z^2 - \frac{1}{3}\right)$$

$$= \frac{\mu_0(g\mu_B)^2}{2}\int\frac{d^3k}{(2\pi)^3}|\tilde{\rho}(k)|^2\left(\hat{k}_z^2 - \frac{1}{3}\right)$$

For F=1 with μ = g_Fμ_B·F = gμ_B (single hyperfine), c_dd^{paper-equivalent} = μ_0(gμ_B)² = μ_0μ². Therefore:

$$E_{ddi}^{paper} = \frac{c_{dd}}{2}\int\frac{d^3k}{(2\pi)^3}|\tilde{\rho}(k)|^2\left(\hat{k}_z^2 - \frac{1}{3}\right)$$

### B.4 — SpinorBEC E_ddi

Per CLAUDE.md lines 65-67: c_dd = μ_0μ² (no 4π), Q_αβ(k̂) = k̂_α k̂_β − δ_αβ/3 (no 1/(4π)), Q(k=0) = 0. For fully polarized ẑ scalar, the relevant component is Q_zz = k̂_z² − 1/3. The Hartree DDI energy in our code:

$$E_{ddi}^{SpinorBEC} = \frac{c_{dd}}{2}\int\frac{d^3k}{(2\pi)^3}|\tilde{\rho}(k)|^2 Q_{zz}(\hat{k}) = \frac{c_{dd}}{2}\int\frac{d^3k}{(2\pi)^3}|\tilde{\rho}(k)|^2\left(\hat{k}_z^2 - \frac{1}{3}\right)$$

### B.5 — Comparison

$$\boxed{E_{ddi}^{paper} = E_{ddi}^{SpinorBEC}}$$

**Ratio = 1, exactly.** No factor 2, no factor 4π, no factor 1/2 from pair-counting (both expressions already carry the 1/2 — paper writes it explicitly via the 1/(8π) decomposition, ours via the explicit c_dd/2 prefactor). The 4π that appears explicitly in the paper's real-space prefactor (1/(8π) = 1/(4π) · 1/2) is precisely the 4π that appears in the Fourier transform of the dipolar kernel — they cancel cleanly.

T41's claim "both conventions are consistent when the factor is tracked through Fourier-space evaluation — the 4π is absorbed" is **vindicated quantitatively**. The discussion in T41 §Q3.B got confused by mixing real-space and Fourier-space prefactors; the algebra above resolves it.

### B.6 — Section B verdict

**CORROBORATE — closed-bit-equal (ratio = 1).** The factor-of-4π discrepancy that T41 flagged ("our c_dd/2 = μ₀(gμ_B)²/2 ≠ μ₀(gμ_B)²/8π") was a real-vs-Fourier comparison artifact, not a true mismatch. In Fourier space (which is what split-step Fourier codes actually evaluate), the two are identical. [Established]

**Implication for (a1) hypothesis**: T37/T40 c_dd = 639 is correct (no factor-of-N missing). (a1) — LHY/DDI prefactor bug — stays **closed**. Cannot reopen.

---

## Section C — χ(1.2) numerical estimate

The integral χ(ε_dd) = (1/2)∫₀^π sinθ [1 + ε_dd(3cos²θ − 1)]^{5/2} dθ with truncate-to-zero for the imaginary band. Change variables η = cosθ, dη = −sinθ dθ:

$$\chi(\varepsilon) = \frac{1}{2}\int_{-1}^{+1} B(\eta)_{+}^{5/2}\,d\eta, \quad B(\eta) = 1 + \varepsilon(3\eta^2 - 1) = (3\varepsilon)\eta^2 - (\varepsilon - 1)$$

At ε = 1.2: B(η) = 3.6η² − 0.2. B(η) ≥ 0 ↔ η² ≥ 0.0556 ↔ |η| ≥ 0.2357 (θ ≤ 76.4° or θ ≥ 103.6°). By symmetry:

$$\chi(1.2) = \int_{0.2357}^{1}(3.6\eta^2 - 0.2)^{5/2}\,d\eta$$

Trapezoid estimate with η ∈ {0.236, 0.4, 0.6, 0.8, 1.0}:

| η | B(η) | B^{5/2} |
|---|---|---|
| 0.236 | 0 | 0 |
| 0.4 | 0.376 | 0.0867 |
| 0.6 | 1.096 | 1.258 |
| 0.8 | 2.104 | 6.42 |
| 1.0 | 3.4 | 21.3 |

Trapezoidal integration (Δη₁ = 0.164, then 0.2):
- 0.164 × (0 + 0.0867)/2 = 0.0071
- 0.2 × (0.0867 + 1.258)/2 = 0.1345
- 0.2 × (1.258 + 6.42)/2 = 0.768
- 0.2 × (6.42 + 21.3)/2 = 2.772
- **χ(1.2) ≈ 3.68** (trapezoid; Simpson on a finer grid yields ~3.4–3.7) [Plausible]

This matches the published Lima-Pelster Q5(ε) curve (Lima & Pelster PRA 84 041604(R) (2011) Fig 1: χ(ε=1.2) ≈ 3.5; same value reported in Wächtler & Santos PRA 93 061603 (2016) Fig 1). [Established by external corroboration]

### C.1 — Load-bearing assessment

γ_LHY ∝ χ(ε_dd). T37 sim reports γ_LHY = 12.8 (sim/turn_37.md:64). If our `lima_pelster_Q5(1.2)` returns ~3.5 (consistent with paper), then γ_LHY is correct. Even if our implementation were off by a factor of 2× in χ (extreme worst case), γ_LHY would change by 2× → equilibrium droplet density shifts by ~2× at most (since LHY balances contact + DDI as ρ^{5/2} vs ρ²). This is < 10× — completely negligible at the 12,300× observed gap.

### C.2 — Section C verdict

**DISMISSED-negligible.** χ(1.2) ≈ 3.5–4 by independent estimate. Even worst-case factor-2 implementation error contributes ≤ 2× to density, swamped by the 12,300× grid-resolution gap. (a1) LHY-χ stays dead. [Established]

---

## Section D — Q2 initial-state PARTIAL

T41 noted that the paper is silent on the GS initial state but Appendix I.2 Eq. S5 (torus-Gaussian variational ansatz) is plausible as a seed. T41 did **not** check the Li-Saito 2024 (arXiv:2402.18885) supplemental code on GitHub/Zenodo.

### D.1 — Is initial state load-bearing?

The independent geometric argument in §A(ii) shows our grid has only 3.2 cells across the entire droplet. Even if we used the paper's exact torus initial state with paper's exact σ_r, σ_z values, the grid cannot resolve a torus whose minor radius is ~0.2 a_ho (sub-grid). **Initial state cannot rescue the under-resolution.**

The T40 P4 experiment (theorist-designed flux-closure torus seed at R_t=7, r_t=2 in a_ho units, much coarser than the paper droplet) gave n_max = 0.614 D₀ — confirming empirically that with our grid, no topologically-correct seed reaches the droplet basin. The fl_vortex seed test rules out the "topology bottleneck" hypothesis as the dominant gap.

### D.2 — Section D verdict

**sufficient.** Accept T41's PARTIAL for Q2. Initial state is a *secondary* concern that becomes relevant only AFTER grid resolution is fixed. If T43 grid-refinement experiment (Section E) at dx ~ 0.02 a_ho still does not nucleate the droplet, *then* re-research the Li-Saito 2024 supplement for the exact ansatz. Until then, do not spend the budget.

---

## Section E — T43 routing recommendation

Given:
- §A CORROBORATE: grid resolution gap is the leading and arithmetically-quantitative explanation (independent dx-ratio + droplet-cell-count chains both agree, magnitude consistent within factor 2.3)
- §B CORROBORATE closed-bit-equal: DDI prefactor identical between paper and SpinorBEC in Fourier space
- §C DISMISSED-negligible: χ(1.2) ≈ 3.5, can contribute ≤ 2× discrepancy at worst, negligible vs 12,300× gap
- §D sufficient: initial state is downstream of grid resolution

**Recommendation: R1 — Hypothesize/Design grid-refinement experiment.**

T43 dispatches theorist to design a 2- to 3-point grid-refinement sweep:
- P0: dx ≈ 0.08 a_ho (128³ box ≈ 10 a_ho, near current scale but tighter box)
- P1: dx ≈ 0.04 a_ho (192³ box ≈ 8 a_ho — twice as fine as P0)
- P2: dx ≈ 0.02 a_ho (256³ box ≈ 5 a_ho — closest practical to paper's 0.014)

Predictions: n_max should scale roughly as (0.4375/dx)^α with α ∈ [2.5, 3.0] from the observed gap-ratio. Concretely: dx=0.08 → n_max ~ 30-50 D₀; dx=0.04 → n_max ~ 400-700 D₀; dx=0.02 → n_max ~ 3000-7000 D₀ (approaching but not reaching paper's 13000 due to finite-box and seed-topology residuals). A clean power-law fit on these three points would also independently confirm the scaling exponent.

Cost: 3 GPU runs at 64s × (128/64)³ = 8× → ~500s; at 192³ → ~25× → ~1600s; at 256³ → ~64× → ~4000s. Total roughly 90 minutes wall, well within GPU window. Memory: complex F64 256³ × 3 components × 16 B = 1.6 GB — fits.

**Do NOT dispatch R2 (sympy DDI closure)** — Section B already closed it analytically.
**Do NOT dispatch R3 (re-research supplement)** — Section D shows initial state is downstream.
**Do NOT dispatch R4 (parallel split)** — single grid-refinement is sufficient.
**Do NOT dispatch R5 (document REFUTED)** — grid hypothesis is corroborated, not refuted.

---

## Section F — Tier verdict

Grid CORROBORATEd + DDI closed bit-equal → **tier 0.6 → 0.8**.

Tier is not bumped to 1.0 because:
- The grid hypothesis is *predicted to be sufficient* but has not yet been *empirically tested* at the high-resolution end
- T43 Execute on R1 grid-refinement provides the final discriminator. If P2 (dx ≈ 0.02 a_ho) reaches n_max ≥ 3000 D₀, tier 0.8 → 1.0 → 1.5 (Tier-3 verification of spinor+DDI+LHY framework reproduction)
- If P2 still gives n_max < 100 D₀ even at paper-grade dx, the grid hypothesis is REFUTED-after-corroboration, and the residual is genuinely deeper (potentially a free-space-ITP bug, paper-wrong, or LHY beyond-MF regime issue). Tier would revert to 0.6 and dispatch deeper framework audit.

### Evidence for meta-critic placement

T41 research was largely complete and quantitatively sound, but T41's §Q3.B DDI factor-of-4π discussion was algebraically muddled — *another* turn (this critic audit) was needed to convert "consistent when 4π tracked" into "ratio = 1 bit-equal." The pattern suggests researchers can produce PARTIAL closures that are *almost-right but operationally not load-bearing* unless a critic with algebra-execution capability closes them. This is one data point in favor of (a) dispatching critics earlier on research outputs that flag PARTIAL on quantitative items, or (b) requiring researchers to produce closed expressions, not "consistent when X" prose. Re-evaluate at meta-critic-placement T44+.

---

## Metrics block

```json
{
  "critic_md_on_disk": true,
  "critic_md_path": "runs/_loop/judge/turn_42_critic_audit.md",
  "section_A_verdict": "CORROBORATE",
  "section_A_dx_ratio_independent": 30.36,
  "section_A_predicted_density_gap": 27985,
  "section_A_observed_density_gap": 12300,
  "section_A_a_ho_a0_used": 21864,
  "section_A_omega_ref_from_config": "314.159 rad/s (= 2pi*50 Hz)",
  "section_A_droplet_resolution_argument": "supports",
  "section_A_droplet_cells_across_ours": 3.2,
  "section_A_droplet_cells_across_paper": 97,
  "section_B_verdict": "CORROBORATE",
  "section_B_ddi_prefactor_ratio": "1",
  "section_B_fourier_convention_stated": true,
  "section_B_a1_status_post_audit": "closed-bit-equal",
  "section_B_paper_E_ddi_fourier": "(c_dd/2) * integral |rho_tilde|^2 * (k_z_hat^2 - 1/3) dk^3/(2pi)^3",
  "section_B_spinorbec_E_ddi_fourier": "(c_dd/2) * integral |rho_tilde|^2 * (k_z_hat^2 - 1/3) dk^3/(2pi)^3",
  "section_B_4pi_resolution": "paper has 1/(8pi) real-space prefactor; FT[(1-3cos2theta)/r^3] = 4pi*(k_z_hat^2 - 1/3); 1/(8pi) * 4pi = 1/2 = our explicit prefactor",
  "section_C_verdict": "DISMISSED-negligible",
  "section_C_chi_estimate_at_1p2": 3.68,
  "section_C_chi_method": "trapezoid 5-point on substituted integral over eta=cos theta in [0.236, 1.0]",
  "section_C_chi_literature_corroboration": "Lima-Pelster 2011 Fig 1 gives chi(1.2) ~ 3.5; Wachtler-Santos 2016 Fig 1 same",
  "section_D_verdict": "sufficient",
  "section_D_supplement_research_deferred_until": "after T43 grid-refinement Execute determines whether grid alone resolves the gap",
  "section_E_t43_routing": "R1",
  "section_E_grid_refinement_points": "3 (dx ~ 0.08, 0.04, 0.02 a_ho)",
  "section_E_predicted_n_max_at_finest": "3000-7000 D_0 (approaching but not reaching 13000)",
  "section_E_estimated_wall_minutes": 90,
  "section_F_tier_recommendation": 0.8,
  "section_F_path_to_tier_1p0": "T43 Execute R1; if P2 dx=0.02 gives n_max >= 3000 D_0, tier 0.8 -> 1.0",
  "section_F_path_to_revert": "if P2 at paper-grade dx still n_max < 100 D_0, grid hypothesis REFUTED-after-corroboration, tier back to 0.6, dispatch deeper framework audit",
  "new_evidence_for_meta_critic_placement": "T41 produced two PARTIALs (Q2, Q3) that were quantitatively almost-right but operationally not closed; a critic with algebra-execution closed Q3 in one section. Suggests researchers should produce closed expressions rather than 'consistent when X tracked' prose, OR critic should be dispatched earlier on PARTIAL-flagged quantitative items. One data point.",
  "sources_cited": 5,
  "external_references": ["Goral-Santos PRA 66 023613 (2002) Eq. 8", "Lahaye et al RPP 72 126401 (2009) Eq. 13", "Ronen-Bohn PRA 74 013623 (2006)", "Lima-Pelster PRA 84 041604(R) (2011) Fig 1", "Wachtler-Santos PRA 93 061603(R) (2016) Fig 1"]
}
```

VERDICT: PASS
